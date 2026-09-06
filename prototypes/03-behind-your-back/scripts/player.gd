extends CharacterBody2D

## Classic platformer character: run, jump, fall. No double jump, no power-ups.
## Carried unchanged from prototypes 01 and 02 — the controller is settled, it is
## not what these prototypes test. Only the Perception hooks were dropped.

signal respawned(point: Vector2)

@export_group("Movement")
@export var max_speed := 280.0
@export var ground_acceleration := 2400.0
@export var ground_friction := 2800.0
@export var air_acceleration := 1700.0
@export var air_friction := 700.0

@export_group("Jump")
@export var jump_velocity := 520.0
@export var gravity := 1250.0
## Gravity multiplier while falling. Keeps the arc readable.
@export var fall_gravity_multiplier := 1.4
## Upward velocity is cut by this much when the jump key is released early.
@export var jump_cut_multiplier := 0.45
@export var max_fall_speed := 1200.0

@export_group("Feel assists (set to 0 to A/B test)")
@export var coyote_time := 0.10
@export var jump_buffer_time := 0.10

@export_group("Respawn")
@export var fall_threshold_y := 900.0
@export var respawn_height_offset := 40.0

var _respawn_point := Vector2.ZERO
var _coyote_timer := 0.0
var _jump_buffer_timer := 0.0


func _ready() -> void:
	_respawn_point = global_position


func _physics_process(delta: float) -> void:
	_read_jump_buffer(delta)
	_apply_gravity(delta)
	_apply_horizontal(delta)
	_try_jump()
	move_and_slide()
	_update_coyote(delta)
	_check_fall()

	if Input.is_action_just_pressed(&"respawn"):
		respawn()


func _apply_gravity(delta: float) -> void:
	if is_on_floor():
		velocity.y = 0.0
		return
	var g := gravity
	if velocity.y > 0.0:
		g *= fall_gravity_multiplier
	velocity.y = minf(velocity.y + g * delta, max_fall_speed)


func _apply_horizontal(delta: float) -> void:
	var direction := Input.get_axis(&"move_left", &"move_right")
	var accel := ground_acceleration if is_on_floor() else air_acceleration
	var decel := ground_friction if is_on_floor() else air_friction
	if is_zero_approx(direction):
		velocity.x = move_toward(velocity.x, 0.0, decel * delta)
	else:
		velocity.x = move_toward(velocity.x, direction * max_speed, accel * delta)


func _read_jump_buffer(delta: float) -> void:
	if Input.is_action_just_pressed(&"jump"):
		_jump_buffer_timer = jump_buffer_time
	else:
		_jump_buffer_timer = maxf(_jump_buffer_timer - delta, 0.0)

	if Input.is_action_just_released(&"jump") and velocity.y < 0.0:
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


func _check_fall() -> void:
	if global_position.y > fall_threshold_y:
		respawn()


func respawn() -> void:
	global_position = _respawn_point
	velocity = Vector2.ZERO
	_coyote_timer = 0.0
	_jump_buffer_timer = 0.0
	respawned.emit(_respawn_point)


func set_respawn_point(point: Vector2) -> void:
	_respawn_point = point + Vector2(0.0, -respawn_height_offset)
