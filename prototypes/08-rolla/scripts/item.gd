extends RigidBody3D

## A thing on the table. Knows its name and who is holding it, lights up when
## a hand is over it, comes back where it started after falling off the edge,
## and — if it `shakes` — reports being shaken while held.

signal shaken(item: RigidBody3D)

const TUNING := preload("res://tuning.tres")

@export var label := "thing"
## Welded things stay level in the hand; the rest hang from a pin and swing.
@export var weld := false
@export var max_holders := 1
## Whether shaking it while held does something (papers, grinder, lighter).
@export var shakes := false

var holders: Array[Node3D] = []
var _heading := Vector3.ZERO      # last direction the holding hand was steered
var _reversals: Array[float] = []  # when it changed direction, in seconds
var _prev_target := Vector3.ZERO
var _spawn: Transform3D

static var _glow: StandardMaterial3D


func _ready() -> void:
	_spawn = global_transform
	if _glow == null:
		_glow = StandardMaterial3D.new()
		_glow.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		_glow.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_glow.albedo_color = Color(1.0, 1.0, 0.65, 0.75)


func can_take() -> bool:
	return holders.size() < max_holders


func is_held() -> bool:
	return not holders.is_empty()


func add_holder(hand: Node3D) -> void:
	holders.append(hand)
	_prev_target = hand.target


func remove_holder(hand: Node3D) -> void:
	holders.erase(hand)


## How far a hand at `point` is from this thing, flat. The nearest one wins.
func grab_distance(point: Vector3) -> float:
	return Vector2(global_position.x - point.x, global_position.z - point.z).length()


## Shaking is the player wiggling the hand: count how often the hand's target
## changes direction in the last shake_window seconds. The target, not the
## body: a heavy thing on a spring barely moves when wiggled fast, but the
## wiggle is still plainly a wiggle.
func _count_reversals(delta: float) -> void:
	var target: Vector3 = holders[0].target
	var flat := (target - _prev_target) / delta
	_prev_target = target
	flat.y = 0.0
	if flat.length() < TUNING.shake_speed:
		return
	var now := Time.get_ticks_msec() / 1000.0
	if flat.dot(_heading) < 0.0:
		_reversals.append(now)
	_heading = flat.normalized()
	while not _reversals.is_empty() and now - _reversals[0] > TUNING.shake_window:
		_reversals.pop_front()
	if _reversals.size() >= TUNING.shake_reversals:
		_reversals.clear()
		shaken.emit(self)


func set_lit(lit: bool) -> void:
	for mesh: MeshInstance3D in find_children("*", "MeshInstance3D", true, false):
		mesh.material_overlay = _glow if lit else null


func _physics_process(delta: float) -> void:
	if shakes and is_held():
		_count_reversals(delta)
	if global_position.y < -0.6:
		global_transform = _spawn
		linear_velocity = Vector3.ZERO
		angular_velocity = Vector3.ZERO
