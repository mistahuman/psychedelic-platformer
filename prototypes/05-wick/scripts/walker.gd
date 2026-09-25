extends CharacterBody2D

## Top-down walker. Circle collision: a box catches on every corner of a 48 px
## grid and makes the maze feel worse than it is.

@export var max_speed := 235.0
@export var acceleration := 2200.0
@export var friction := 2600.0

var frozen := true

## Steps are paced by distance covered, not by a timer, so they stay in step
## with the character when it accelerates and decelerates.
const STEP_DISTANCE := 38.0
var _since_step := 0.0
var _left_foot := true


func _physics_process(delta: float) -> void:
	if frozen:
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
		move_and_slide()
		return
	var direction := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	if direction.is_zero_approx():
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
	else:
		velocity = velocity.move_toward(direction * max_speed, acceleration * delta)
	move_and_slide()
	_footsteps(delta)


func _footsteps(delta: float) -> void:
	_since_step += velocity.length() * delta
	if _since_step < STEP_DISTANCE:
		return
	_since_step = 0.0
	_left_foot = not _left_foot
	Sound.play(
		&"step_a" if _left_foot else &"step_b",
		-13.0,
		randf_range(0.94, 1.07)
	)
