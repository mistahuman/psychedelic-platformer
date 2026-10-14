extends "res://scripts/item.gd"

## Shake it to strike. Most strikes are a click; some give a flame for a
## couple of seconds.

var flame_left := 0.0

@onready var _flame: Node3D = $Flame


func strike() -> bool:
	if randf() < TUNING.strike_chance:
		flame_left = TUNING.flame_time
		return true
	return false


func flame_on() -> bool:
	return flame_left > 0.0 and is_held()


func flame_position() -> Vector3:
	return _flame.global_position


func _physics_process(delta: float) -> void:
	super(delta)
	flame_left = maxf(flame_left - delta, 0.0)
	_flame.visible = flame_on()
