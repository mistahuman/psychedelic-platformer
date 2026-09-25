class_name Grappler
extends CharacterBody2D

## The ground half is player.gd from 01–03, copied and trimmed: run, jump,
## asymmetric gravity, jump cut, coyote time, jump buffer. The air half is new.
##
## One button. On the ground it jumps. In the air, a fresh press hooks the best
## anchor in range and holding it keeps you on the rope; letting go releases you
## with whatever velocity the swing gave you. The rope is rigid: it never gets
## longer than it was when it caught, but it can go slack.

signal hooked(anchor: Vector2)
signal released(speed: float)
signal fell

@export_group("Movement")
@export var max_speed := 280.0
@export var ground_acceleration := 2400.0
@export var ground_friction := 2800.0
@export var air_acceleration := 900.0
## Air friction is low on purpose: a release has to carry.
@export var air_friction := 60.0

@export_group("Jump")
@export var jump_velocity := 520.0
@export var gravity := 1250.0
@export var fall_gravity_multiplier := 1.4
@export var jump_cut_multiplier := 0.45
@export var max_fall_speed := 1200.0

@export_group("Feel assists (set to 0 to A/B test)")
@export var coyote_time := 0.10
@export var jump_buffer_time := 0.10

@export_group("Rope")
@export var hook_range := 360.0
@export var min_rope := 60.0
## How much an anchor ahead of you is preferred over a nearer one behind, in px.
@export var forward_bias := 120.0
## Tangential acceleration from holding a direction while hanging.
@export var pump_acceleration := 500.0
## Multiplier on velocity at the moment of release. 1.0 is honest physics.
@export var release_boost := 1.0
## Hard cap, so a runaway swing cannot tunnel through a platform.
@export var max_swing_speed := 1500.0

@export_group("Respawn")
@export var fall_threshold_y := 820.0

## Filled by the course.
var anchors: PackedVector2Array = PackedVector2Array()

var is_hooked := false
var anchor := Vector2.ZERO
var rope_length := 0.0
var target := Vector2.INF

var _respawn_point := Vector2.ZERO
var _coyote_timer := 0.0
var _jump_buffer_timer := 0.0
var _facing := 1.0
var _catch_flash := 0.0


func _ready() -> void:
	_respawn_point = global_position


func _physics_process(delta: float) -> void:
	var direction := Input.get_axis(&"move_left", &"move_right")
	if not is_zero_approx(direction):
		_facing = signf(direction)

	if is_hooked:
		_swing(direction, delta)
	else:
		_read_jump_buffer(delta)
		_try_hook()
		if not is_hooked:
			_apply_gravity(delta)
			_apply_horizontal(direction, delta)
			_try_jump()
			move_and_slide()
			_update_coyote(delta)

	if is_on_floor():
		var collision := get_last_slide_collision()
		if collision and collision.get_collider() is Node and (collision.get_collider() as Node).has_meta(&"spawn"):
			_respawn_point = (collision.get_collider() as Node).get_meta(&"spawn")

	target = Vector2.INF if is_hooked or is_on_floor() else _best_anchor()
	_catch_flash = maxf(_catch_flash - delta * 4.0, 0.0)
	if global_position.y > fall_threshold_y:
		fell.emit()
		respawn()
	queue_redraw()


func _swing(direction: float, delta: float) -> void:
	if not Input.is_action_pressed(&"jump"):
		_release()
		return

	velocity.y += gravity * delta
	var radial := (global_position - anchor).normalized()
	var tangent := Vector2(-radial.y, radial.x)
	if not is_zero_approx(direction):
		if tangent.x * direction < 0.0:
			tangent = -tangent
		# Pumping only helps below the anchor; above it, it would be a jetpack.
		if radial.y > 0.0:
			velocity += tangent * pump_acceleration * absf(direction) * delta

	# Rigid rope: drop any velocity that would take us further than its length.
	var taut := global_position.distance_to(anchor) >= rope_length - 0.5
	var outward := velocity.dot(radial)
	if taut and outward > 0.0:
		velocity -= radial * outward
	velocity = velocity.limit_length(max_swing_speed)

	move_and_slide()

	var offset := global_position - anchor
	if offset.length() > rope_length:
		global_position = anchor + offset.normalized() * rope_length


func _release() -> void:
	is_hooked = false
	velocity *= release_boost
	_coyote_timer = 0.0
	released.emit(velocity.length())


func _try_hook() -> void:
	if not Input.is_action_just_pressed(&"jump"):
		return
	if is_on_floor() or _coyote_timer > 0.0:
		return
	var best := _best_anchor()
	if best == Vector2.INF:
		return
	is_hooked = true
	anchor = best
	rope_length = maxf(global_position.distance_to(anchor), min_rope)
	_jump_buffer_timer = 0.0
	_catch_flash = 1.0
	hooked.emit(anchor)


## Nearest anchor above you and in range, with a thumb on the scale for the one
## ahead. "Ahead" is where you are moving, or where you last pointed.
func _best_anchor() -> Vector2:
	var heading := _facing
	if absf(velocity.x) > 40.0:
		heading = signf(velocity.x)
	var best := Vector2.INF
	var best_score := INF
	for a in anchors:
		var d := a - global_position
		if d.y > -20.0:
			continue
		var dist := d.length()
		if dist > hook_range or dist < min_rope:
			continue
		var score := dist - heading * signf(d.x) * forward_bias
		if score < best_score:
			best_score = score
			best = a
	return best


func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		velocity.y = 0.0
		return
	var g := gravity
	if velocity.y > 0.0:
		g *= fall_gravity_multiplier
	velocity.y = minf(velocity.y + g * delta, max_fall_speed)


func _apply_horizontal(direction: float, delta: float) -> void:
	var accel := ground_acceleration if is_on_floor() else air_acceleration
	var decel := ground_friction if is_on_floor() else air_friction
	if is_zero_approx(direction):
		velocity.x = move_toward(velocity.x, 0.0, decel * delta)
	elif is_on_floor() or absf(velocity.x) < max_speed or signf(velocity.x) != direction:
		# In the air, steering may slow a fast release but never speed it past a run.
		velocity.x = move_toward(velocity.x, direction * max_speed, accel * delta)


func _read_jump_buffer(delta: float) -> void:
	if Input.is_action_just_pressed(&"jump"):
		_jump_buffer_timer = jump_buffer_time
	else:
		_jump_buffer_timer = maxf(_jump_buffer_timer - delta, 0.0)

	if Input.is_action_just_released(&"jump") and velocity.y < 0.0 and velocity.y > -jump_velocity * 1.01:
		velocity.y *= jump_cut_multiplier


func _try_jump() -> void:
	if _jump_buffer_timer <= 0.0 or _coyote_timer <= 0.0:
		return
	velocity.y = -jump_velocity
	_jump_buffer_timer = 0.0
	_coyote_timer = 0.0


func _update_coyote(delta: float) -> void:
	if is_on_floor():
		_coyote_timer = coyote_time
	else:
		_coyote_timer = maxf(_coyote_timer - delta, 0.0)


func respawn() -> void:
	global_position = _respawn_point
	velocity = Vector2.ZERO
	is_hooked = false
	_coyote_timer = 0.0
	_jump_buffer_timer = 0.0


func reset_to(point: Vector2) -> void:
	_respawn_point = point
	respawn()


func _draw() -> void:
	if is_hooked:
		var end := to_local(anchor)
		draw_line(Vector2.ZERO, end, Color(1.0, 0.85, 0.5), 2.0, true)
		if _catch_flash > 0.0:
			draw_circle(end, 10.0 + 14.0 * _catch_flash, Color(1.0, 0.85, 0.5, _catch_flash * 0.6))
	elif target != Vector2.INF:
		# The anchor a press would catch. Without this the choice is invisible
		# and every miss reads as the game's fault.
		var t := to_local(target)
		draw_arc(t, 17.0, 0.0, TAU, 32, Color(1.0, 0.85, 0.5, 0.9), 2.0, true)
		draw_dashes(Vector2.ZERO, t)


func draw_dashes(from: Vector2, to: Vector2) -> void:
	var length := from.distance_to(to)
	var step := 14.0
	var dir := (to - from) / length
	var s := 0.0
	while s < length - 20.0:
		draw_line(from + dir * s, from + dir * minf(s + 6.0, length), Color(1.0, 0.85, 0.5, 0.25), 1.0)
		s += step
