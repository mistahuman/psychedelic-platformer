@tool
extends StaticBody2D

## The collision shape never moves. Only the ColorRect does, by an amount
## proportional to Perception.level. Standing still makes it tell the truth.

@export var size := Vector2(120.0, 24.0):
	set(value):
		size = value
		_apply_look()

@export var color := Color(0.95, 0.42, 0.72):
	set(value):
		color = value
		_apply_look()

@export_group("Drift")
## Max visual offset from the real position, in pixels.
@export var max_drift := Vector2(26.0, 18.0)
## Cycles per second, per axis.
@export var speed := Vector2(0.7, 1.1)
@export var phase := Vector2(0.0, 1.6)

var _rect: ColorRect


func _ready() -> void:
	add_to_group(&"drifting_platform")
	_apply_look()


func _process(_delta: float) -> void:
	if Engine.is_editor_hint() or _rect == null:
		return
	var t := Perception.elapsed()
	var offset := Vector2(
		max_drift.x * sin(TAU * speed.x * t + phase.x),
		max_drift.y * sin(TAU * speed.y * t + phase.y)
	) * Perception.drift_strength()
	_rect.position = -size * 0.5 + offset


func _apply_look() -> void:
	if not is_node_ready():
		return
	_rect = get_node_or_null(^"ColorRect") as ColorRect
	if _rect:
		_rect.size = size
		_rect.position = -size * 0.5
		_rect.color = color
	var col := get_node_or_null(^"CollisionShape2D") as CollisionShape2D
	if col and col.shape is RectangleShape2D:
		# Duplicate, or every instance would share the scene's single shape.
		var shape := (col.shape as RectangleShape2D).duplicate() as RectangleShape2D
		shape.size = size
		col.shape = shape
