extends RigidBody3D

## One hand. A rigid body that is never placed, only pulled: a spring drags it
## toward a target the player moves, so it lags, overshoots and swings.
##
## Grabbing is a claw machine: whatever is under the hand lights up; hold the
## grip and the hand dips onto it, closes, and comes back up with it. Let go
## of the grip and it drops. The clumsiness is in the arm, not in the fingers.
## Most things hang from a pin and swing; welded ones (sheet, lighter) stay level.

const Tuning := preload("res://scripts/tuning.gd")
const SKIN := Color(0.86, 0.66, 0.52)
const FINGER_OPEN_X := 0.0575
const FINGER_SHUT_X := 0.02
## Hand height that puts the fingertips around a thing's middle.
const DIP_ABOVE := 0.04

## "l" or "r": the prefix of this hand's input actions.
@export var side := "l"
@export var tuning: Tuning

var target: Vector3          ## where the hand is being pulled to
var carry_height := 0.0      ## the height the player chose; dips return to it
var held: RigidBody3D
var under: RigidBody3D       ## the thing a grip would go for, lit up
var load_n := 0.0            ## newtons the fingers are carrying right now
var last_event := ""         ## for the debug overlay

var _joint: Joint3D
var _held_prev_velocity: Vector3
var _dipping := 0.0          # seconds into a dip, 0 when not dipping
var _spent := false          # this press already grabbed or missed
var _fingers := 0.0          # 0 open, 1 shut: looks only
var _time := randf() * 10.0  # so the two hands do not shake in step
var _material := StandardMaterial3D.new()

@onready var _grab_area: Area3D = $GrabArea
@onready var _column: Area3D = $Column
@onready var _finger_a: MeshInstance3D = $FingerMeshA
@onready var _finger_b: MeshInstance3D = $FingerMeshB
@onready var target_marker: MeshInstance3D = $TargetMarker


func _ready() -> void:
	target = global_position
	carry_height = target.y
	_material.albedo_color = SKIN
	for mesh: MeshInstance3D in [$PalmMesh, _finger_a, _finger_b]:
		mesh.material_override = _material


func _physics_process(delta: float) -> void:
	_time += delta
	_move_target(delta)
	_find_under()
	_grip(delta)
	_pull_toward_target()
	_check_hold(delta)
	_show(delta)


func _move_target(delta: float) -> void:
	var plane := Input.get_vector(side + "_left", side + "_right", side + "_fwd", side + "_back")
	var lift := Input.get_axis(side + "_down", side + "_up")
	# Gamepad: holding the shoulder button turns the stick's up/down into height.
	if Input.is_action_pressed(side + "_mod"):
		lift = -plane.y
		plane.y = 0.0
	var step := tuning.target_speed * delta
	carry_height = clampf(carry_height + lift * step, tuning.reach_min.y, tuning.reach_max.y)
	target.x += plane.x * step
	target.z += plane.y * step
	if _dipping == 0.0:
		target.y = carry_height
	target = target.clamp(tuning.reach_min, tuning.reach_max)


## The nearest free thing straight below the hand, measured flat.
func _find_under() -> void:
	if under != null and not is_instance_valid(under):
		under = null  # taken into the sheet, or torn
	var nearest: RigidBody3D = null
	var nearest_distance := INF
	if held == null:
		for body in _column.get_overlapping_bodies():
			if not body.is_in_group("item") or not body.can_take() or self in body.holders:
				continue
			var distance: float = body.grab_distance(global_position)
			if distance < nearest_distance:
				nearest = body
				nearest_distance = distance
	if nearest != under:
		if under != null:
			under.set_lit(false)
		if nearest != null:
			nearest.set_lit(true)
		under = nearest


func _grip(delta: float) -> void:
	var pressed := Input.is_action_pressed(side + "_grip")
	if not pressed:
		_spent = false
		_dipping = 0.0
		if held != null:
			let_go("let go of")
		return
	if held != null or _spent:
		return
	if under == null and _dipping == 0.0:
		_spent = true
		last_event = "closed on nothing"
		return

	# Dip toward the lit-up thing until it is between the fingers.
	_dipping += delta
	var floor_y := under.global_position.y + DIP_ABOVE if under else tuning.reach_min.y
	target.y = move_toward(target.y, maxf(floor_y, tuning.reach_min.y), tuning.dip_speed * delta)
	if under and under in _grab_area.get_overlapping_bodies():
		_grab(under)
	elif _dipping > tuning.dip_timeout:
		_spent = true
		_dipping = 0.0
		last_event = "missed"


func _grab(body: RigidBody3D) -> void:
	held = body
	held.add_holder(self)
	held.set_lit(false)
	under = null
	_spent = true
	_dipping = 0.0
	_held_prev_velocity = held.linear_velocity
	load_n = 0.0
	# A pin lets the thing hang from the fingers and swing; a 6DOF joint with
	# its default limits (all locked) is a weld.
	_joint = Generic6DOFJoint3D.new() if held.weld else PinJoint3D.new()
	add_child(_joint)
	_joint.global_position = _grab_area.global_position
	_joint.node_a = get_path()
	_joint.node_b = held.get_path()
	last_event = "grabbed " + held.label


func _pull_toward_target() -> void:
	# The shake goes through the same spring as everything else, so it looks
	# like a hand, not a glitch.
	var wobble := Vector3(sin(_time * 17.0), sin(_time * 19.0 + 1.0), sin(_time * 23.0 + 2.0)) * tuning.tremor
	var accel := (target + wobble - global_position) * tuning.stiffness
	accel -= linear_velocity * tuning.damping
	apply_central_force(accel.limit_length(tuning.max_accel) * mass)


func _check_hold(delta: float) -> void:
	if held == null or held.weld:
		return
	# The joint does not report its force, so estimate it: whatever is making
	# the thing accelerate differently from free fall is coming through the fingers.
	var accel := (held.linear_velocity - _held_prev_velocity) / delta
	_held_prev_velocity = held.linear_velocity
	var raw := held.mass * (accel - held.get_gravity()).length()
	load_n = lerpf(load_n, raw, 0.2)  # smoothed: one bump is not a slip
	if load_n > tuning.hold_force:
		let_go("dropped")


func let_go(how: String) -> void:
	last_event = how + " " + held.label
	held.remove_holder(self)
	held = null
	_joint.queue_free()
	_joint = null
	load_n = 0.0


func _show(delta: float) -> void:
	var shut := held != null or Input.is_action_pressed(side + "_grip")
	_fingers = move_toward(_fingers, 1.0 if shut else 0.0, 8.0 * delta)
	var x := lerpf(FINGER_OPEN_X, FINGER_SHUT_X if held == null else FINGER_OPEN_X - 0.015, _fingers)
	_finger_a.position.x = -x
	_finger_b.position.x = x
	target_marker.global_position = target
