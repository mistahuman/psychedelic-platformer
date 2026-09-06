extends Node

## How much the rendering is allowed to lie, 0..1.
## Rises while the player moves, falls while the player stands still on ground.

var rise_rate := 0.28
var decay_rate := 0.75
var drift_enabled := true

var level := 0.0
var calm := false

var _time := 0.0


func _process(delta: float) -> void:
	_time += delta
	var rate := -decay_rate if calm else rise_rate
	level = clampf(level + rate * delta, 0.0, 1.0)


func drift_strength() -> float:
	return level if drift_enabled else 0.0


func elapsed() -> float:
	return _time


func reset() -> void:
	level = 0.0
