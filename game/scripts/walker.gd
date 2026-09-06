extends CharacterBody2D

## Top-down walker. Circle collision: a box catches on every corner of a 48 px
## grid and makes the maze feel worse than it is.

@export var max_speed := 235.0
@export var acceleration := 2200.0
@export var friction := 2600.0

var frozen := true


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
