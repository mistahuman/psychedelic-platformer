@tool
extends AnimatableBody2D

## Platform oscillating along one axis:
##     position = base + amplitude * sin(TAU * frequency * t + phase_offset)
## Base is wherever the node sits in the editor.

@export var size := Vector2(140.0, 24.0):
	set(value):
		size = value
		_apply_look()

@export var color := Color(0.95, 0.42, 0.72):
	set(value):
		color = value
		_apply_look()

@export_group("Oscillation")
## Max displacement from the base position, in pixels.
@export_range(0.0, 400.0, 1.0) var amplitude := 60.0
## Full cycles per second. 0.25 means one cycle every 4 seconds.
@export_range(0.0, 3.0, 0.01) var frequency := 0.3
## Starting phase, in radians. Keeps platforms out of sync with each other.
@export_range(0.0, 6.28, 0.01) var phase_offset := 0.0
@export var horizontal := false
@export var preview_in_editor := false

var _base_position := Vector2.ZERO
var _time := 0.0


func _ready() -> void:
	_apply_look()
	_base_position = position
	_apply_offset()


func _physics_process(delta: float) -> void:
	if Engine.is_editor_hint() and not preview_in_editor:
		return
	_time += delta
	_apply_offset()


func _apply_offset() -> void:
	var wave := amplitude * sin(TAU * frequency * _time + phase_offset)
	var displacement := Vector2(wave, 0.0) if horizontal else Vector2(0.0, wave)
	# Assigning position is what sync_to_physics expects: the physics server
	# derives the body's velocity from it, and riders inherit that velocity.
	position = _base_position + displacement


func _apply_look() -> void:
	if not is_node_ready():
		return
	var rect := get_node_or_null(^"ColorRect") as ColorRect
	if rect:
		rect.size = size
		rect.position = -size * 0.5
		rect.color = color
	var col := get_node_or_null(^"CollisionShape2D") as CollisionShape2D
	if col and col.shape is RectangleShape2D:
		# Duplicate, or every instance would share the scene's single shape.
		var shape := (col.shape as RectangleShape2D).duplicate() as RectangleShape2D
		shape.size = size
		col.shape = shape
