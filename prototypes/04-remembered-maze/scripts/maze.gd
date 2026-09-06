extends Node2D

## The maze: the grid, how it is generated, how it is allowed to change, and
## what the player currently believes about it.
##
## Three layers of truth live here, and keeping them apart is the whole point:
##
##   cells   what the maze actually is right now. Collision agrees with this.
##   memory  what the player last SAW. Never updated except by looking.
##   light   how brightly each cell is lit this frame, 0..1.
##
## The prototype is the gap between the first two.

signal reached_exit

enum { WALL, FLOOR, UNKNOWN }

@export_group("Grid")
## Both must be odd: the generator carves on odd coordinates and keeps an outer
## wall ring, so even sizes lose a row and a column to the border.
@export var cols := 23
@export var rows := 13
@export var cell_size := 48.0

@export_group("Lantern")
## Sight radius in cells. Walls block it — around a corner is already blind.
@export var light_radius := 4.2
## Below this the light fades out rather than ending on a hard circle.
@export var light_falloff := 1.4

@export_group("Mutation")
## Attempted changes per second. Most attempts are rejected.
@export var mutation_rate := 2.5
## A cell must be at least this many cells away before it may change, on top of
## being unlit. Without it the maze rearranges itself just past the lantern and
## reads as though it is being done AT you rather than behind you.
@export var min_distance := 3.0
@export var mutation_enabled := true

@export var player_path: NodePath

var cells: PackedInt32Array
var memory: PackedInt32Array
var light: PackedFloat32Array

var start_cell := Vector2i(1, 1)
var exit_cell := Vector2i(1, 1)
var mutations := 0
var seen_count := 0

var _player: Node2D
var _walls: StaticBody2D
var _shapes := {}
var _mutation_debt := 0.0
var _target_wall_ratio := 0.0
var _finished := false


func _ready() -> void:
	_player = get_node_or_null(player_path) as Node2D
	_walls = StaticBody2D.new()
	_walls.name = "Walls"
	_walls.collision_layer = 1
	_walls.collision_mask = 0
	add_child(_walls)
	rebuild()


## Fresh maze, fresh memory, player back at the start.
func rebuild() -> void:
	_generate()
	_rebuild_collision()
	memory.resize(cells.size())
	memory.fill(UNKNOWN)
	light.resize(cells.size())
	light.fill(0.0)
	mutations = 0
	seen_count = 0
	_finished = false
	_target_wall_ratio = _wall_ratio()
	if _player:
		_player.global_position = cell_center(start_cell)
		if _player is CharacterBody2D:
			(_player as CharacterBody2D).velocity = Vector2.ZERO
	_look()


func send_player_to_start() -> void:
	if _player == null:
		return
	_player.global_position = cell_center(start_cell)
	if _player is CharacterBody2D:
		(_player as CharacterBody2D).velocity = Vector2.ZERO


func _process(delta: float) -> void:
	_look()
	if mutation_enabled:
		_mutation_debt += mutation_rate * delta
		while _mutation_debt >= 1.0:
			_mutation_debt -= 1.0
			_try_mutate()
	_check_exit()


# --- the grid ---------------------------------------------------------------

func index(x: int, y: int) -> int:
	return y * cols + x


func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < cols and c.y < rows


func cell_center(c: Vector2i) -> Vector2:
	return global_position + Vector2(
		(float(c.x) + 0.5) * cell_size, (float(c.y) + 0.5) * cell_size
	)


func cell_at(world: Vector2) -> Vector2i:
	var local := world - global_position
	return Vector2i(int(floor(local.x / cell_size)), int(floor(local.y / cell_size)))


func player_cell() -> Vector2i:
	if _player == null:
		return start_cell
	return cell_at(_player.global_position)


## Cells whose remembered state no longer matches the truth. This is the number
## the prototype is really about: how much of what you believe is already wrong.
func stale_count() -> int:
	var n := 0
	for i in cells.size():
		if memory[i] != UNKNOWN and memory[i] != cells[i]:
			n += 1
	return n


# --- generation -------------------------------------------------------------

## Recursive backtracker on odd coordinates: a perfect maze, exactly one route
## between any two cells. Mutation then erodes that property, which is fine —
## what has to hold is connectivity, and that is checked per change.
func _generate() -> void:
	cells.resize(cols * rows)
	cells.fill(WALL)
	var stack: Array[Vector2i] = [start_cell]
	cells[index(start_cell.x, start_cell.y)] = FLOOR
	var directions := [Vector2i(2, 0), Vector2i(-2, 0), Vector2i(0, 2), Vector2i(0, -2)]
	while not stack.is_empty():
		var current: Vector2i = stack.back()
		var options: Array[Vector2i] = []
		for d in directions:
			var next: Vector2i = current + d
			if next.x <= 0 or next.y <= 0 or next.x >= cols - 1 or next.y >= rows - 1:
				continue
			if cells[index(next.x, next.y)] == WALL:
				options.append(next)
		if options.is_empty():
			stack.pop_back()
			continue
		var chosen: Vector2i = options[randi() % options.size()]
		# Carve the wall between the two cells as well as the cell itself.
		var between: Vector2i = current + (chosen - current) / 2
		cells[index(between.x, between.y)] = FLOOR
		cells[index(chosen.x, chosen.y)] = FLOOR
		stack.append(chosen)
	exit_cell = Vector2i(cols - 2, rows - 2)
	cells[index(exit_cell.x, exit_cell.y)] = FLOOR


func _wall_ratio() -> float:
	var walls := 0
	for v in cells:
		if v == WALL:
			walls += 1
	return float(walls) / float(cells.size())


# --- what the player can see ------------------------------------------------

## Recomputed every frame. The line of sight is traced from cell centres, but the
## brightness falls off from the player's real position, so the light does not
## step from cell to cell as you walk.
func _look() -> void:
	light.fill(0.0)
	var origin := player_cell()
	if not in_bounds(origin):
		return
	var reach := int(ceil(light_radius + light_falloff))
	var world := _player.global_position if _player else cell_center(origin)
	for dy in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			var c := Vector2i(origin.x + dx, origin.y + dy)
			if not in_bounds(c):
				continue
			var distance := world.distance_to(cell_center(c)) / cell_size
			if distance > light_radius + light_falloff:
				continue
			if not _line_clear(origin, c):
				continue
			var amount := 1.0 - clampf(
				(distance - light_radius) / light_falloff, 0.0, 1.0
			)
			if amount <= 0.0:
				continue
			var i := index(c.x, c.y)
			light[i] = maxf(light[i], amount)
			if memory[i] == UNKNOWN:
				seen_count += 1
			memory[i] = cells[i]


## Bresenham between cell centres. A wall blocks sight past itself but is lit
## itself — otherwise the walls you are standing next to would be invisible.
func _line_clear(from: Vector2i, to: Vector2i) -> bool:
	var dx := absi(to.x - from.x)
	var dy := absi(to.y - from.y)
	var sx := 1 if from.x < to.x else -1
	var sy := 1 if from.y < to.y else -1
	var err := dx - dy
	var c := from
	while c != to:
		var double_err := err * 2
		if double_err > -dy:
			err -= dy
			c.x += sx
		if double_err < dx:
			err += dx
			c.y += sy
		if c == to:
			return true
		if cells[index(c.x, c.y)] == WALL:
			return false
	return true


# --- change -----------------------------------------------------------------

## One attempted change. Most attempts fail, and that is by design: the filters
## are what keep this from being a random level generator.
func _try_mutate() -> void:
	# Push back towards the density the maze was generated with, or it drifts
	# into either an open field or a solid block over a long run.
	var opening := _wall_ratio() > _target_wall_ratio
	var candidate := _pick_candidate(opening)
	if candidate.x < 0:
		return
	var i := index(candidate.x, candidate.y)
	var was: int = cells[i]
	cells[i] = FLOOR if was == WALL else WALL
	if not _connected(player_cell(), exit_cell):
		cells[i] = was
		return
	_apply_collision(candidate)
	mutations += 1


func _pick_candidate(opening: bool) -> Vector2i:
	var wanted := WALL if opening else FLOOR
	var origin := player_cell()
	# A bounded number of darts rather than shuffling the whole grid: cheap, and
	# failing to find one this tick simply means nothing changes this tick.
	for _attempt in 24:
		var c := Vector2i(
			1 + randi() % maxi(cols - 2, 1), 1 + randi() % maxi(rows - 2, 1)
		)
		if not in_bounds(c) or c.x >= cols - 1 or c.y >= rows - 1:
			continue
		if c == start_cell or c == exit_cell:
			continue
		var i := index(c.x, c.y)
		if cells[i] != wanted:
			continue
		if light[i] > 0.0:
			continue
		if Vector2(c - origin).length() < min_distance:
			continue
		return c
	return Vector2i(-1, -1)


## Breadth-first over floor cells. The maze may rearrange itself however it
## likes as long as the exit is still reachable from where the player is
## standing — that is the maze equivalent of prototype 03's jump arithmetic,
## and unlike a jump arc it can simply be checked.
func _connected(from: Vector2i, to: Vector2i) -> bool:
	if not in_bounds(from) or not in_bounds(to):
		return false
	if cells[index(from.x, from.y)] == WALL:
		return false
	var visited := {}
	var queue: Array[Vector2i] = [from]
	visited[from] = true
	var neighbours := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	while not queue.is_empty():
		var current: Vector2i = queue.pop_front()
		if current == to:
			return true
		for d in neighbours:
			var next: Vector2i = current + d
			if not in_bounds(next) or visited.has(next):
				continue
			if cells[index(next.x, next.y)] == WALL:
				continue
			visited[next] = true
			queue.append(next)
	return false


# --- collision --------------------------------------------------------------

func _rebuild_collision() -> void:
	for shape in _shapes.values():
		shape.queue_free()
	_shapes.clear()
	for y in rows:
		for x in cols:
			if cells[index(x, y)] == WALL:
				_apply_collision(Vector2i(x, y))


## Collision follows `cells` exactly, always. Nothing in this prototype is ever
## drawn where it cannot be touched — the lie is in the memory, not the world.
func _apply_collision(c: Vector2i) -> void:
	var solid := cells[index(c.x, c.y)] == WALL
	if solid == _shapes.has(c):
		return
	if not solid:
		_shapes[c].queue_free()
		_shapes.erase(c)
		return
	var shape := RectangleShape2D.new()
	shape.size = Vector2(cell_size, cell_size)
	var node := CollisionShape2D.new()
	node.shape = shape
	node.position = cell_center(c) - global_position
	_walls.add_child(node)
	_shapes[c] = node


func _check_exit() -> void:
	if _finished or _player == null:
		return
	if player_cell() == exit_cell:
		_finished = true
		reached_exit.emit()
