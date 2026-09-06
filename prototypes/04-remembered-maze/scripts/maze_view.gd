extends Node2D

## Draws the maze in three registers, and the whole prototype is in the
## difference between them:
##
##   lit         what the lantern reaches right now. Always true.
##   remembered  what you saw last time you were here. Possibly a lie by now.
##   unknown     not drawn at all.
##
## Nothing marks a remembered cell as stale. Finding that out is the game.
## `F4` overrides that for testing only.

## Resolved in _ready(). A bare `@export var maze: Node2D` looks tidier, but a
## NodePath written by hand into the .tscn does not populate it — it stays null
## and the whole view silently draws nothing.
@export var maze_path: NodePath = ^".."

var maze: Node2D

@export_group("Colours")
@export var wall_lit := Color(0.72, 0.55, 0.98)
@export var wall_remembered := Color(0.30, 0.24, 0.44)
@export var floor_lit := Color(0.16, 0.13, 0.26)
@export var floor_remembered := Color(0.10, 0.08, 0.16)
@export var exit_color := Color(0.45, 0.92, 0.82)
@export var stale_color := Color(0.98, 0.35, 0.45)

## Debug only: paint every cell whose memory disagrees with the truth.
var show_stale := false


func _ready() -> void:
	maze = get_node_or_null(maze_path) as Node2D


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	if maze == null:
		return
	# maze is a plain Node2D as far as the type system is concerned, so every
	# property read off it is a Variant and needs an explicit annotation.
	var cell: float = maze.cell_size
	var size := Vector2(cell, cell)
	for y in maze.rows:
		for x in maze.cols:
			var i: int = maze.index(x, y)
			var remembered: int = maze.memory[i]
			if remembered == maze.UNKNOWN:
				continue
			var at := Vector2(float(x), float(y)) * cell
			var amount: float = maze.light[i]
			var truth: int = maze.cells[i]

			# Unlit cells are drawn from memory, lit cells from the truth. That
			# single line is the mechanic.
			var shown := truth if amount > 0.0 else remembered
			var base := (
				wall_remembered if shown == maze.WALL else floor_remembered
			)
			var top := wall_lit if shown == maze.WALL else floor_lit
			draw_rect(Rect2(at, size), base.lerp(top, amount))

			if show_stale and remembered != truth:
				draw_rect(Rect2(at + size * 0.25, size * 0.5), stale_color)

	var exit_index: int = maze.index(maze.exit_cell.x, maze.exit_cell.y)
	if maze.memory[exit_index] != maze.UNKNOWN:
		var at := Vector2(maze.exit_cell as Vector2i) * cell
		var amount: float = maze.light[exit_index]
		draw_rect(
			Rect2(at + size * 0.2, size * 0.6),
			Color(exit_color, lerpf(0.35, 1.0, amount))
		)
