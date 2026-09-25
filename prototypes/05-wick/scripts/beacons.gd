extends Node2D

## The door and the oil, drawn ON TOP of the lantern layer so they shine through
## the dark. Everything else in the maze is subject to the light; these two are
## the exceptions, deliberately: the door is the one thing the player is always
## allowed to know, and oil is worth crossing the map for.

@export var maze_path: NodePath = ^".."

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
	_draw_oil(cell, size)
	_draw_exit(cell, size)


func _draw_oil(cell: float, size: Vector2) -> void:
	for c in maze.oil_cells:
		var i: int = maze.index(c.x, c.y)
		if maze.memory[i] == maze.UNKNOWN:
			continue
		var amount: float = maze.light[i]
		var at := Vector2(c as Vector2i) * cell
		var pulse := 0.72 + 0.28 * sin(_time * 3.4)
		var strength := lerpf(0.42, 1.0, amount) * pulse
		draw_rect(Rect2(at - size * 0.1, size * 1.2), Color(oil_color, 0.14 * strength))
		draw_rect(Rect2(at + size * 0.3, size * 0.4), Color(oil_color, strength))


func _draw_exit(cell: float, size: Vector2) -> void:
	var c: Vector2i = maze.exit_cell
	var i: int = maze.index(c.x, c.y)
	var amount: float = maze.light[i]
	var seen: bool = maze.memory[i] != maze.UNKNOWN
	var at := Vector2(c) * cell
	var pulse := 0.78 + 0.22 * sin(_time * 2.0)
	var strength := (0.92 if seen else 0.70) * pulse
	draw_rect(Rect2(at - size * 0.5, size * 2.0), Color(exit_color, 0.07 * strength))
	draw_rect(Rect2(at - size * 0.2, size * 1.4), Color(exit_color, 0.15 * strength))
	draw_rect(Rect2(at + size * 0.18, size * 0.64), Color(exit_color, lerpf(strength, 1.0, amount)))
