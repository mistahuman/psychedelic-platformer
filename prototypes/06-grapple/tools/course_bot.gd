extends SceneTree

## Headless ruler for the course: plays it with a fixed, dumb policy and reports
## how far it got. Not a player model — a way to check the course is passable
## and that the release is actually a decision.
##
##   godot --headless --path . --fixed-fps 60 -s tools/course_bot.gd -- 0.8
##
## The argument is the release angle in radians: the bot lets go once the rope
## has swung that far forward of vertical while rising. Everything else is
## fixed: run right, jump at edges, hook the ringed anchor when falling, pump
## the way it is moving, never hook while over a platform.

const TIMEOUT_S := 120.0

var course: Node2D
var p: Grappler
var frame := 0
var holding := false
var held_frames := 0
var release_angle := 0.8
var reached := {}


func _initialize() -> void:
	root.add_child(load("res://scripts/controls.gd").new())
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		release_angle = float(args[0])
	course = load("res://scenes/main.tscn").instantiate()
	root.add_child(course)


func _physics_process(_delta: float) -> bool:
	if p == null:
		p = course.player
		Input.action_press(&"move_right")
		return false
	frame += 1
	held_frames += 1
	var pos := p.global_position

	if p.is_on_floor():
		for i in course.PLATFORMS.size():
			var pl: Array = course.PLATFORMS[i]
			if pos.x >= pl[0] and pos.x <= pl[1]:
				if not reached.has(i):
					reached[i] = frame / 60.0
				if pos.x > pl[1] - 25:
					_press()
	elif not p.is_hooked:
		if holding:
			# Hold a jump briefly, then let go so the next press is a fresh one.
			if held_frames > 3 and p.velocity.y > -80.0:
				_let_go()
		elif p.target != Vector2.INF and p.target.x > pos.x - 40.0 \
				and p.velocity.y > -80.0 and not _over_platform(pos):
			_press()
	else:
		var off := pos - p.anchor
		var angle := atan2(off.x, off.y)
		Input.action_release(&"move_right")
		Input.action_release(&"move_left")
		Input.action_press(&"move_right" if p.velocity.x >= 0.0 else &"move_left")
		if angle > release_angle and p.velocity.x > 0.0 and p.velocity.y < 0.0:
			_let_go()
			Input.action_release(&"move_left")
			Input.action_press(&"move_right")

	if course._finished or frame > 60 * TIMEOUT_S:
		print("release %.2f rad   %s   %.2fs   falls %d   hooks %d   platforms %s" % [
			release_angle, "FLAG" if course._finished else "stuck",
			course._time, course._falls, course._hooks, reached.keys()])
		quit()
	return false


func _over_platform(pos: Vector2) -> bool:
	for pl: Array in course.PLATFORMS:
		if pos.x >= pl[0] - 10 and pos.x <= pl[1] and pos.y < pl[2]:
			return true
	return false


func _press() -> void:
	Input.action_press(&"jump")
	holding = true
	held_frames = 0


func _let_go() -> void:
	Input.action_release(&"jump")
	holding = false
