extends Node2D

## The maze, what the player remembers of it, and how it changes behind them.
##
## Three layers, kept apart on purpose:
##
##   cells       what the maze actually is. Collision agrees with this, always.
##   memory      what the player last SAW. Only ever updated by looking.
##   light       how brightly each cell is lit this frame, 0..1.
##   correction  how recently the lantern caught a memory being wrong, 1..0.
##
## `correction` is the one the prototypes were missing. Without it the maze
## rearranges itself in total silence: the player is fooled and never finds out,
## which reads as confusion rather than as a mechanic.

signal reached_exit
signal found_oil(remaining: int)
signal was_fooled(total: int)

enum { WALL, FLOOR, UNKNOWN }

const COLS := 23
const ROWS := 13
const CELL := 48.0

@export_group("Lantern")
## Radius in cells at a full wick, and at a spent one. Sight shrinking as the
## wick burns is the pressure curve: the maze does not get harder, you get less
## able to read it.
@export var radius_full := 4.6
@export var radius_empty := 2.1
@export var falloff := 1.4

@export_group("Change")
## Attempted changes per second. Low, because the filters below mean almost
## every change that survives them is one the player will actually run into:
## measured, 41 changes produced 35 moments of being caught out. Raising this is
## how you get chaos, not tension.
@export var mutation_rate := 0.45
## A cell must be at least this far off on top of being unlit, so nothing
## rearranges itself right under the player's nose.
@export var min_distance := 1.6
## ...and at most this far beyond the lantern's edge. This is the important one.
## Measured: with no upper bound, the maze changed in cells the player had
## glimpsed once from across a gap and would never walk near again — 15 changes
## produced 0 moments of being caught out, while a dozen contradictions sat
## unvisited at the end of the run. Changes now happen just around the corner,
## where the walls make a blind spot and the player is about to look.
@export var reach_beyond := 3.0
## Only change cells the player looked at within this many seconds. A cell seen
## once, early, from across a gap is one they will probably never stand near
## again, and changing it produces a contradiction nobody is ever present for.
## Recency is the best available proxy for "they are coming back to this".
@export var recency := 14.0
@export var mutation_enabled := true

@export var player_path: NodePath

var cells: PackedInt32Array
var memory: PackedInt32Array
var light: PackedFloat32Array
var correction: PackedFloat32Array
var last_seen: PackedFloat32Array
## Cells the player has physically walked through, as opposed to merely seen
## from somewhere. These are the ones worth changing.
var walked: PackedByteArray
var _walked_list: Array[Vector2i] = []

var start_cell := Vector2i(1, 1)
var exit_cell := Vector2i(COLS - 2, ROWS - 2)
var oil_cells: Array[Vector2i] = []

var changes := 0
var fooled := 0
var seen_count := 0
var running := false
## 0..1, drives the lantern radius. The game owns the clock; the maze only reads it.
var wick := 1.0

var _player: Node2D
var _walls: StaticBody2D
var _shapes := {}
var _debt := 0.0
var _clock := 0.0
var _target_wall_ratio := 0.0


func _ready() -> void:
	_player = get_node_or_null(player_path) as Node2D
	_walls = StaticBody2D.new()
	_walls.name = "Walls"
	_walls.collision_layer = 1
	_walls.collision_mask = 0
	add_child(_walls)
	rebuild()


func rebuild() -> void:
	_generate()
	_place_oil()
	_rebuild_collision()
	memory.resize(cells.size())
	memory.fill(UNKNOWN)
	light.resize(cells.size())
	light.fill(0.0)
	correction.resize(cells.size())
	correction.fill(0.0)
	last_seen.resize(cells.size())
	last_seen.fill(-999.0)
	walked.resize(cells.size())
	walked.fill(0)
	_walked_list.clear()
	_clock = 0.0
	changes = 0
	fooled = 0
	seen_count = 0
	wick = 1.0
	_target_wall_ratio = _wall_ratio()
	if _player:
		_player.global_position = cell_center(start_cell)
		if _player is CharacterBody2D:
			(_player as CharacterBody2D).velocity = Vector2.ZERO
	_look()


func _process(delta: float) -> void:
	for i in correction.size():
		if correction[i] > 0.0:
			correction[i] = maxf(correction[i] - delta * 1.1, 0.0)
	if not running:
		return
	_clock += delta
	var here := player_cell()
	if in_bounds(here) and walked[index(here.x, here.y)] == 0:
		walked[index(here.x, here.y)] = 1
		_walked_list.append(here)
	_look()
	_collect_oil()
	if mutation_enabled:
		_debt += mutation_rate * delta
		while _debt >= 1.0:
			_debt -= 1.0
			_try_change()
	if player_cell() == exit_cell:
		running = false
		reached_exit.emit()


func light_radius() -> float:
	return lerpf(radius_empty, radius_full, clampf(wick, 0.0, 1.0))


# --- grid -------------------------------------------------------------------

func index(x: int, y: int) -> int:
	return y * COLS + x


func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < COLS and c.y < ROWS


func cell_center(c: Vector2i) -> Vector2:
	return global_position + Vector2((float(c.x) + 0.5) * CELL, (float(c.y) + 0.5) * CELL)


func cell_at(world: Vector2) -> Vector2i:
	var local := world - global_position
	return Vector2i(int(floor(local.x / CELL)), int(floor(local.y / CELL)))


func player_cell() -> Vector2i:
	if _player == null:
		return start_cell
	return cell_at(_player.global_position)


func explored_ratio() -> float:
	return float(seen_count) / float(COLS * ROWS)


# --- generation -------------------------------------------------------------

func _generate() -> void:
	cells.resize(COLS * ROWS)
	cells.fill(WALL)
	var stack: Array[Vector2i] = [start_cell]
	cells[index(start_cell.x, start_cell.y)] = FLOOR
	var steps := [Vector2i(2, 0), Vector2i(-2, 0), Vector2i(0, 2), Vector2i(0, -2)]
	while not stack.is_empty():
		var current: Vector2i = stack.back()
		var options: Array[Vector2i] = []
		for d in steps:
			var next: Vector2i = current + d
			if next.x <= 0 or next.y <= 0 or next.x >= COLS - 1 or next.y >= ROWS - 1:
				continue
			if cells[index(next.x, next.y)] == WALL:
				options.append(next)
		if options.is_empty():
			stack.pop_back()
			continue
		var chosen: Vector2i = options[randi() % options.size()]
		var between: Vector2i = current + (chosen - current) / 2
		cells[index(between.x, between.y)] = FLOOR
		cells[index(chosen.x, chosen.y)] = FLOOR
		stack.append(chosen)
	cells[index(exit_cell.x, exit_cell.y)] = FLOOR


## Oil goes in the half of the maze furthest from the start, so refuelling is a
## detour with a decision attached rather than something you trip over.
func _place_oil() -> void:
	oil_cells.clear()
	var candidates: Array[Vector2i] = []
	for y in ROWS:
		for x in COLS:
			var c := Vector2i(x, y)
			if cells[index(x, y)] != FLOOR or c == start_cell or c == exit_cell:
				continue
			if Vector2(c - start_cell).length() < 6.0:
				continue
			candidates.append(c)
	candidates.shuffle()
	for i in mini(3, candidates.size()):
		oil_cells.append(candidates[i])


func _wall_ratio() -> float:
	var walls := 0
	for v in cells:
		if v == WALL:
			walls += 1
	return float(walls) / float(cells.size())


# --- sight ------------------------------------------------------------------

func _look() -> void:
	light.fill(0.0)
	var origin := player_cell()
	if not in_bounds(origin):
		return
	var r := light_radius()
	var reach := int(ceil(r + falloff))
	var world: Vector2 = _player.global_position if _player else cell_center(origin)
	for dy in range(-reach, reach + 1):
		for dx in range(-reach, reach + 1):
			var c := Vector2i(origin.x + dx, origin.y + dy)
			if not in_bounds(c):
				continue
			var distance := world.distance_to(cell_center(c)) / CELL
			if distance > r + falloff:
				continue
			if not _line_clear(origin, c):
				continue
			var amount := 1.0 - clampf((distance - r) / falloff, 0.0, 1.0)
			if amount <= 0.0:
				continue
			var i := index(c.x, c.y)
			light[i] = maxf(light[i], amount)
			_learn(i)


## Looking at a cell writes the truth into memory. If what was there before was
## a memory that had gone stale, that is the moment the player is entitled to
## find out — flash it, count it, and say so.
func _learn(i: int) -> void:
	if memory[i] == UNKNOWN:
		seen_count += 1
	elif memory[i] != cells[i]:
		if OS.has_environment("WICK_DEBUG"): print("  CAUGHT at index ", i)
		correction[i] = 1.0
		fooled += 1
		was_fooled.emit(fooled)
	memory[i] = cells[i]
	last_seen[i] = _clock


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


func _collect_oil() -> void:
	if _player == null:
		return
	var here := player_cell()
	for i in oil_cells.size():
		if oil_cells[i] == here:
			oil_cells.remove_at(i)
			found_oil.emit(oil_cells.size())
			return


# --- change -----------------------------------------------------------------

func _try_change() -> void:
	var opening := _wall_ratio() > _target_wall_ratio
	var candidate := _pick(opening)
	if candidate.x < 0:
		return
	var i := index(candidate.x, candidate.y)
	var was: int = cells[i]
	cells[i] = FLOOR if was == WALL else WALL
	if not _connected(player_cell(), exit_cell):
		cells[i] = was
		return
	_apply_collision(candidate)
	changes += 1
	if OS.has_environment("WICK_DEBUG"): print("  changed ", candidate, " seen=", memory[i] != UNKNOWN, " mem=", memory[i], " now=", cells[i])


## Enumerates the eligible cells rather than sampling for them. The eligible set
## is a handful of cells hugging the player's own path, so throwing random darts
## at the whole grid found one about a third of the time and starved the change
## rate to a sixth of what it should be. Walking the walked set is both correct
## and cheaper.
func _pick(opening: bool) -> Vector2i:
	var wanted := WALL if opening else FLOOR
	var origin := player_cell()
	var limit := light_radius() + reach_beyond
	var candidates: Array[Vector2i] = []
	var offsets := [
		Vector2i.ZERO, Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)
	]
	for w in _walked_list:
		for d in offsets:
			var c: Vector2i = w + d
			if c.x <= 0 or c.y <= 0 or c.x >= COLS - 1 or c.y >= ROWS - 1:
				continue
			if c == start_cell or c == exit_cell or c in oil_cells or c in candidates:
				continue
			var i := index(c.x, c.y)
			if cells[i] != wanted or light[i] > 0.0 or memory[i] == UNKNOWN:
				continue
			if _clock - last_seen[i] > recency:
				continue
			var distance := Vector2(c - origin).length()
			if distance < min_distance or distance > limit:
				continue
			candidates.append(c)
	if candidates.is_empty():
		return Vector2i(-1, -1)
	return candidates[randi() % candidates.size()]


func _touches_walked(c: Vector2i) -> bool:
	for d in [Vector2i.ZERO, Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var n: Vector2i = c + d
		if in_bounds(n) and walked[index(n.x, n.y)] == 1:
			return true
	return false


## The maze may rearrange itself however it likes, as long as the way out still
## exists from where the player is standing. Cheap to check on a grid this size,
## and it is the difference between a mechanic and a betrayal.
func _connected(from: Vector2i, to: Vector2i) -> bool:
	if not in_bounds(from) or not in_bounds(to):
		return false
	if cells[index(from.x, from.y)] == WALL:
		return false
	var visited := {from: true}
	var queue: Array[Vector2i] = [from]
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
	for y in ROWS:
		for x in COLS:
			if cells[index(x, y)] == WALL:
				_apply_collision(Vector2i(x, y))


func _apply_collision(c: Vector2i) -> void:
	var solid := cells[index(c.x, c.y)] == WALL
	if solid == _shapes.has(c):
		return
	if not solid:
		_shapes[c].queue_free()
		_shapes.erase(c)
		return
	var shape := RectangleShape2D.new()
	shape.size = Vector2(CELL, CELL)
	var node := CollisionShape2D.new()
	node.shape = shape
	node.position = cell_center(c) - global_position
	_walls.add_child(node)
	_shapes[c] = node
