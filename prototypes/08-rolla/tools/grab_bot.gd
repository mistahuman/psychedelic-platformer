extends SceneTree

## Headless ruler for the hands: plays one pick-and-place through the real
## input actions and reports what happened. Not a player model — a way to
## check that every thing can be picked up and carried, and to read the
## forces involved.
##
##   godot --headless --path . --fixed-fps 120 -s tools/grab_bot.gd -- grinder
##
## Argument: which item (papers, lighter, filter, grinder, crumb1…6). The bot
## uses the hand on that side of the table and carries the thing to DROP_AT.

const TIMEOUT_S := 20.0
const CARRY_HEIGHT := 0.15
const DROP_AT := Vector3(0.0, 0.0, -0.2)

var hand: RigidBody3D
var item: RigidBody3D
var phase := 0
var time := 0.0
var phase_time := 0.0
var peak_load := 0.0
var last_event := ""


func _initialize() -> void:
	root.add_child(load("res://scripts/controls.gd").new())
	var main: Node3D = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	var args := OS.get_cmdline_user_args()
	item = main.get_node((args[0] if args else "lighter").capitalize().replace(" ", ""))
	# The hand on the item's side: reaching across bumps into the other one.
	# (Not global_position: nothing is inside the tree yet.)
	hand = main.get_node("HandL" if item.position.x < 0.0 else "HandR")


func _physics_process(delta: float) -> bool:
	time += delta
	phase_time += delta
	peak_load = maxf(peak_load, hand.load_n)
	if hand.last_event != last_event:
		last_event = hand.last_event
		print("%5.2fs  %s" % [time, last_event])
	if time > TIMEOUT_S:
		return _report("TIMEOUT in phase %d" % phase)

	match phase:
		0:  # over the item, then let the swing die
			var p := item.global_position
			if _steer(Vector3(p.x, CARRY_HEIGHT, p.z)) and phase_time > 1.5:
				_next()
		1:  # hold the grip: the hand dips, grabs, comes back up
			Input.action_press(hand.side + "_grip")
			if hand.held == item and hand.global_position.y > CARRY_HEIGHT - 0.03:
				_next()
			elif phase_time > 2.0:
				return _report("never grabbed (under the hand: %s)" % hand.under)
		2:  # carry it over
			if hand.held == null:
				return _report("lost it on the way")
			if _steer(Vector3(DROP_AT.x, CARRY_HEIGHT, DROP_AT.z)) and phase_time > 1.0:
				_next()
		3:  # let go, see where it lands
			Input.action_release(hand.side + "_grip")
			if phase_time > 1.5:
				var off := item.global_position - DROP_AT
				return _report("landed %.0f cm from the spot" % (Vector2(off.x, off.z).length() * 100.0))
	return false


## Presses the movement actions toward a point; true once the target is there.
func _steer(goal: Vector3) -> bool:
	var off: Vector3 = goal - Vector3(hand.target.x, hand.carry_height, hand.target.z)
	_axis("_left", "_right", off.x)
	_axis("_fwd", "_back", off.z)
	_axis("_down", "_up", off.y)
	return off.length() < 0.02


func _axis(negative: String, positive: String, value: float) -> void:
	for action in [negative, positive]:
		Input.action_release(hand.side + action)
	if absf(value) > 0.01:
		Input.action_press(hand.side + (positive if value > 0.0 else negative))


func _next() -> void:
	phase += 1
	phase_time = 0.0


func _report(result: String) -> bool:
	print("RESULT %s: %s  (%.1fs, peak load %.1f N)" % [item.label, result, time, peak_load])
	return true
