extends Node2D

## Draws the maze cells, and nothing else. Two registers:
##
##   lit         drawn from the truth — this is what you will collide with
##   remembered  drawn from memory — what you saw last time, possibly stale
##   unknown     not drawn
##
## Everything is drawn at full brightness. The dimming is the lantern layer's
## job (scripts/lighting.gd), which is what lets it be smooth instead of a
## per-cell mosaic. So "remembered" ends up dark because it is unlit, not
## because it is painted a different colour — which is both simpler and closer
## to how it should read.
##
## The one thing that never dims is the correction flash: when the lantern
## catches a remembered cell being wrong, that cell has to be seen.

@export var maze_path: NodePath = ^".."

@export_group("Colours")
@export var wall_color := Color(0.62, 0.50, 0.92)
@export var floor_color := Color(0.17, 0.14, 0.27)
@export var correction_color := Color(1.0, 0.42, 0.70)

var maze: Node2D


func _ready() -> void:
	maze = get_node_or_null(maze_path) as Node2D


func _process(_delta: float) -> void:
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
			var lit: bool = maze.light[i] > 0.02
			var shown: int = maze.cells[i] if lit else remembered
			var colour := wall_color if shown == maze.WALL else floor_color
			var flash: float = maze.correction[i]
			if flash > 0.0:
				colour = colour.lerp(correction_color, flash * 0.9)
			draw_rect(Rect2(Vector2(float(x), float(y)) * cell, size), colour)
