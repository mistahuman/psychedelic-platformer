extends CharacterBody2D

## Top-down walker. Deliberately not player.gd: there is no gravity, no jump and
## no floor here, so the settled platformer controller has nothing to say.
## The collision shape is a circle — a box catches on every corner of a 48 px
## grid and makes the maze feel worse than it is.

@export var max_speed := 235.0
@export var acceleration := 2200.0
@export var friction := 2600.0


func _physics_process(delta: float) -> void:
	var direction := Input.get_vector(&"move_left", &"move_right", &"move_up", &"move_down")
	if direction.is_zero_approx():
		velocity = velocity.move_toward(Vector2.ZERO, friction * delta)
	else:
		velocity = velocity.move_toward(direction * max_speed, acceleration * delta)
	move_and_slide()
