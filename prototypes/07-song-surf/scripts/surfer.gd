class_name Surfer
extends Node2D

## Tiny Wings physics against an analytic ground. No physics engine: the ground
## is a function, so contact is "is y below the ground at x", and the response
## is to keep only the part of the velocity that runs along the slope.
##
## That one rule produces the whole game. Land along a downslope and you lose
## almost nothing; land against an upslope and the normal part of your velocity
## is thrown away. Holding makes you heavy: heavy on the way down gains speed,
## light on the way up keeps it, and a hill's crest launches you on its own.
##
## World coordinates: the baseline is y = 0, the ground is at y = -height.

signal landed(quality: float)

@export var gravity := 900.0
## Gravity multiplier while holding. The whole skill lives in this number.
@export var dive_multiplier := 3.2
## Below this horizontal speed you are pushed along anyway, so a mistake costs
## time rather than ending the run.
@export var min_speed := 220.0
@export var max_speed := 2200.0
@export var ground_drag := 0.04

## Acceleration along the direction of travel from the wave, px/s². Set by the
## game each frame: positive in the pocket, zero behind, negative far ahead.
var wave_accel := 0.0

var song: Song
var velocity := Vector2.ZERO
var grounded := false
var holding := false
var air_time := 0.0
var best_air := 0.0
var perfect_landings := 0
var _landing_flash := 0.0


func reset(x: float, speed: float) -> void:
	position = Vector2(x, -song.height_at(x))
	velocity = Vector2(speed, 0.0)
	grounded = true
	air_time = 0.0
	best_air = 0.0
	perfect_landings = 0


func step(delta: float) -> void:
	# Substeps: a fast surfer crosses a whole valley in a few frames otherwise.
	var steps := 4
	var h := delta / steps
	for _i in steps:
		_substep(h)
	_landing_flash = maxf(_landing_flash - delta * 3.0, 0.0)
	if not grounded:
		air_time += delta
		best_air = maxf(best_air, air_time)
	rotation = lerp_angle(rotation, velocity.angle(), minf(delta * 14.0, 1.0))
	queue_redraw()


func _substep(h: float) -> void:
	var g := gravity * (dive_multiplier if holding else 1.0)
	velocity.y += g * h
	if grounded and velocity.length() > 1.0:
		velocity += velocity.normalized() * wave_accel * h
	position += velocity * h

	var ground := -song.height_at(position.x)
	if position.y >= ground:
		position.y = ground
		var slope := song.slope_at(position.x)
		var tangent := Vector2(1.0, -slope).normalized()
		var along := velocity.dot(tangent)
		if not grounded:
			# How well the landing matched the slope: 1 is perfectly along it.
			var quality := clampf(along / maxf(velocity.length(), 1.0), 0.0, 1.0)
			if quality > 0.97 and slope < -0.15:
				perfect_landings += 1
				_landing_flash = 1.0
			landed.emit(quality)
			air_time = 0.0
		velocity = tangent * along * (1.0 - ground_drag * h)
		grounded = true
	elif position.y < ground - 1.0:
		grounded = false

	if velocity.x < min_speed:
		# A hard floor, scaled along the current direction so it never fights
		# the slope: a push that only adds x loses to gravity on a steep climb.
		if grounded and velocity.x > 1.0:
			velocity *= min_speed / velocity.x
		elif grounded:
			velocity = Vector2(1.0, -song.slope_at(position.x)).normalized() * min_speed
		else:
			velocity.x = min_speed
	velocity = velocity.limit_length(max_speed)


func _draw() -> void:
	var body := Color(1.0, 0.95, 0.85)
	if holding:
		body = Color(1.0, 0.7, 0.45)
	# A teardrop pointing along the velocity (the node itself is rotated).
	draw_circle(Vector2.ZERO, 13.0, body)
	draw_colored_polygon(PackedVector2Array([Vector2(8, -9), Vector2(24, 0), Vector2(8, 9)]), body)
	if _landing_flash > 0.0:
		draw_arc(Vector2.ZERO, 18.0 + 30.0 * (1.0 - _landing_flash), 0.0, TAU, 40,
				Color(0.5, 1.0, 0.9, _landing_flash), 3.0, true)
