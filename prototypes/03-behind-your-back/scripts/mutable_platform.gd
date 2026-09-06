@tool
extends StaticBody2D

## A platform that occupies one of several positions, and swaps between them
## only while it is off camera.
##
## The contract, and the whole point of prototype 03: collision and rendering
## always agree. Unlike prototype 02, what you see is never a lie — it is just
## not necessarily what you left there.

@export var size := Vector2(150.0, 24.0):
	set(value):
		size = value
		_apply_look()

@export var color := Color(0.95, 0.42, 0.72):
	set(value):
		color = value
		_apply_look()

@export_group("Mutation")
## Offsets from the editor position. Index 0 is where the platform starts, so
## the level as authored is the level as first seen.
@export var variants := PackedVector2Array([Vector2.ZERO]):
	set(value):
		variants = value
		_variant = 0
		_apply_variant()

## Landmarks set this to false: they anchor the level so the changes read as
## changes rather than as noise.
@export var can_mutate := true

var _base := Vector2.ZERO
var _variant := 0
## Set while on screen. A platform gets exactly one re-roll per trip off camera,
## so it cannot keep shuffling in place while the player is elsewhere.
var _armed := false


func _ready() -> void:
	add_to_group(&"mutable_platform")
	_base = position
	_apply_look()
	_apply_variant()


func _physics_process(_delta: float) -> void:
	if Engine.is_editor_hint():
		return
	if Observer.can_see(world_rect()):
		_armed = true
		return
	if _armed:
		_armed = false
		_try_mutate()


func world_rect() -> Rect2:
	return Rect2(global_position - size * 0.5, size)


func variant_index() -> int:
	return _variant


func _try_mutate() -> void:
	if not can_mutate or not Observer.mutation_enabled:
		return
	if variants.size() < 2:
		return
	if randf() > Observer.mutation_chance:
		return
	var next := _variant
	while next == _variant:
		next = randi() % variants.size()
	# A platform sitting just past the margin can mutate *into* the view: the
	# offset it takes is added to a position that was only barely outside. That
	# would be a visible pop, which is precisely the thing this prototype
	# promises never happens. Check the destination, not just the origin.
	var destination := Rect2(
		get_parent().to_global(_base + variants[next]) - size * 0.5, size
	)
	if Observer.can_see(destination):
		return
	_variant = next
	_apply_variant()
	Observer.mutations += 1


func _apply_variant() -> void:
	if not is_node_ready() or variants.is_empty():
		return
	position = _base + variants[clampi(_variant, 0, variants.size() - 1)]


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
