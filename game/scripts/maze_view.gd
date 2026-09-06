extends Node2D

## Draws the maze in three registers. The difference between them is the game:
##
##   lit         what the lantern reaches. True right now.
##   remembered  what you saw last time. Drawn dim, and possibly already false.
##   unknown     not drawn at all.
##
## Plus the one thing the prototypes never had: when the lantern catches a
## remembered cell being wrong, that cell FLASHES as it is overwritten. Without
## it the maze changes in silence and the player never learns the rule.

@export var maze_path: NodePath = ^".."

@export_group("Colours")
@export var wall_lit := Color(0.70, 0.55, 0.98)
@export var wall_remembered := Color(0.27, 0.22, 0.40)
@export var floor_lit := Color(0.15, 0.12, 0.25)
@export var floor_remembered := Color(0.09, 0.07, 0.15)
@export var correction_color := Color(1.0, 0.45, 0.72)
@export var exit_color := Color(0.40, 0.95, 0.80)
@export var oil_color := Color(1.0, 0.78, 0.32)

var maze: Node2D
var _time := 0.0


func _ready() -> void:
	maze = get_node_or_null(maze_path) as Node2D


func _process(delta: float) -> void:
	_time += delta
	queue_redraw()


func _draw() -> void:
	if maze == null:
		return
	var cell: float = maze.CELL
	var size := Vector2(cell, cell)

	for y in maze.ROWS:
		for x in maze.COLS:
			var i: int = maze.index(x, y)
			var remembered: int = maze.memory[i]
			if remembered == maze.UNKNOWN:
				continue
			var at := Vector2(float(x), float(y)) * cell
			var amount: float = maze.light[i]
			var truth: int = maze.cells[i]
			# Lit cells are drawn from the truth, unlit ones from memory. That
			# one substitution is the whole mechanic.
			var shown := truth if amount > 0.0 else remembered
			var dim := wall_remembered if shown == maze.WALL else floor_remembered
			var bright := wall_lit if shown == maze.WALL else floor_lit
			var colour := dim.lerp(bright, amount)
			var flash: float = maze.correction[i]
			if flash > 0.0:
				colour = colour.lerp(correction_color, flash * 0.85)
			draw_rect(Rect2(at, size), colour)

	_draw_oil(cell, size)
	_draw_exit(cell, size)


func _draw_oil(cell: float, size: Vector2) -> void:
	for c in maze.oil_cells:
		var i: int = maze.index(c.x, c.y)
		if maze.memory[i] == maze.UNKNOWN:
			continue
		var amount: float = maze.light[i]
		var at := Vector2(c as Vector2i) * cell
		var pulse := 0.75 + 0.25 * sin(_time * 3.4)
		draw_rect(
			Rect2(at + size * 0.3, size * 0.4),
			Color(oil_color, lerpf(0.30, 1.0, amount) * pulse)
		)


## The door is drawn even where the player has never been. Being lost is meant
## to be about the route, not about the objective — the prototypes were unclear
## about both at once, and that reads as having no goal at all.
func _draw_exit(cell: float, size: Vector2) -> void:
	var c: Vector2i = maze.exit_cell
	var i: int = maze.index(c.x, c.y)
	var amount: float = maze.light[i]
	var seen: bool = maze.memory[i] != maze.UNKNOWN
	var at := Vector2(c) * cell
	var pulse := 0.62 + 0.38 * sin(_time * 2.0)
	# Visible even through unexplored dark: being lost should be about the route,
	# not about the objective. At 0.18 it read as a grey smudge and the player
	# had nothing to aim at at all.
	var alpha := lerpf(0.45 * pulse, 1.0, amount) if seen else 0.40 * pulse
	draw_rect(Rect2(at + size * 0.18, size * 0.64), Color(exit_color, alpha))
