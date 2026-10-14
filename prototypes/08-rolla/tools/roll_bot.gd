extends SceneTree

## Headless ruler for the whole loop: sheet, crumbs, filter, roll, seal, light.
## Plays through the real input actions with a fixed, dumb policy and prints
## what happened at each step. Not a player model — a way to check that every
## step can be done, and to read the numbers it produces.
##
##   godot --headless --path . --fixed-fps 120 -s tools/roll_bot.gd
##
## Optional arguments: rolling stroke length in seconds (default 0.2),
## "sloppy" to roll with the right hand a beat late, and "shots=<dir>" to save
## a frame at each step (needs a window: drop --headless, add --disable-vsync).

var main: Node3D
var L: RigidBody3D
var R: RigidBody3D
var time := 0.0
var stroke := 0.2
var sloppy := false
var shots := ""


func _initialize() -> void:
	root.add_child(load("res://scripts/controls.gd").new())
	seed(7)
	main = load("res://scenes/main.tscn").instantiate()
	root.add_child(main)
	var args := OS.get_cmdline_user_args()
	seed(7)  # same run every time, so a change shows up as a change
	if args.size() > 0 and args[0].is_valid_float():
		stroke = float(args[0])
	sloppy = "sloppy" in args
	for arg in args:
		if arg.begins_with("shots="):
			shots = arg.trim_prefix("shots=")
	L = main.get_node("HandL")
	R = main.get_node("HandR")
	_run()


func _physics_process(delta: float) -> bool:
	time += delta
	return time > 120.0


func _run() -> void:
	await _wait(0.5)
	var message := ""

	# 1 — sheet
	await _go({R: _at(main.get_node("Papers"))})
	await _grab(R)
	await _go({R: Vector3(0.1, 0.15, 0.05)})
	_log("carried the papers; sheet already? %s" % (main.sheet != null))
	await _shake(R, func(): return main.sheet != null, 4.0)
	if main.sheet == null:
		return _end("no sheet after shaking")
	await _wait(1.0)
	await _go({R: Vector3(0.5, 0.15, 0.3)})
	_release(R)
	var sheet: RigidBody3D = main.sheet
	await _wait(1.0)
	_log("sheet lies at %v" % sheet.global_position)

	# 2 — crumbs
	await _go({L: _at(main.get_node("Grinder"))})
	await _grab(L)
	await _go({L: _over(sheet, 0.0)})
	await _shake(L, func(): return sheet.crumbs_showing() >= 12, 6.0)
	_log("crumbs on the sheet: %d (spawned %d)" % [sheet.crumbs_showing(), get_nodes_in_group("crumb").size()])
	await _go({L: Vector3(-0.5, 0.15, 0.3)})
	_release(L)

	# 3 — filter
	await _go({R: _at(main.get_node("Filter"))})
	await _grab(R)
	await _go({R: _over(sheet, 0.1)})
	await _go({R: _over(sheet, 0.1) - Vector3(0, 0.07, 0)})  # lower before letting go
	await _wait(1.0)
	_log("filter over %v, hand %v, goal %v, sheet basis x %v" % [main.get_node("Filter").global_position, R.global_position, _over(sheet, 0.1), sheet.global_transform.basis.x])
	_release(R)
	await _wait(1.0)
	_log("filter lies at %v in the sheet's frame" % sheet.to_local(main.get_node("Filter").global_position))

	# 4 — roll
	await _go({L: _over(sheet, -0.08), R: Vector3(0.35, 0.15, 0.25)})
	await _grab(L)
	await _wait(0.8)
	await _go({R: _over(sheet, 0.08)})
	await _grab(R)
	_log("both hands on it: crumbs %d, filter %s" % [sheet.crumbs, sheet.has_filter])
	var t0 := time
	var forward := true
	while not sheet.rolled() and time - t0 < 20.0 and is_instance_valid(sheet):
		await _stroke(forward)
		forward = not forward
	if not is_instance_valid(sheet):
		return _end("torn while rolling")
	_log("rolled %d%% in %.1fs, neat %d%%, crumbs left %d" % [
		sheet.progress * 100, time - t0, sheet.neatness() * 100, sheet.crumbs])

	# 5 — seal
	var mouth: Vector3 = main.mouth
	await _go({L: mouth + Vector3(-0.08, 0.045, 0), R: mouth + Vector3(0.08, 0.045, 0)}, 4.0)
	await _wait(1.5)
	_log("at the mouth: middle %.3f m away, sealed %s" % [sheet.middle_position().distance_to(mouth), sheet.sealed])
	if not sheet.sealed:
		return _end("not sealed")

	# 6 — light: left hand lets go and fetches the lighter
	_release(L)
	await _go({L: L.target + Vector3(0, 0.12, 0)})  # lift clear of the sheet first
	await _go({R: Vector3(0.22, 0.2, 0.3)})  # tip reachable, out of the lighter's way
	_log("R parked: body %v target %v, sheet %v basis x %v, tip %v" % [R.global_position, R.target, sheet.global_position, sheet.global_transform.basis.x, sheet.tip_position()])
	var lighter: RigidBody3D = main.get_node("Lighter")
	while L.held != lighter and time < 100.0:
		await _go({L: _at(lighter) + Vector3(0, 0.15, 0)})
		await _go({L: _at(lighter)})
		await _grab(L)
		if L.held != lighter:
			_release(L)
			_log("lighter at %v, hand at %v, under %s" % [lighter.global_position, L.global_position, L.under])
			await _wait(0.3)
	var t1 := time
	while not sheet.lit and time - t1 < 30.0:
		if not lighter.flame_on():
			await _shake(L, func(): return lighter.flame_on(), 3.0)
		var flame_offset: Vector3 = lighter.flame_position() - L.global_position
		await _go({L: Vector3(L.target.x, 0.38, L.target.z)}, 1.0)  # up, clear of the right hand
		await _go({L: Vector3(0, 0.38 - sheet.tip_position().y, 0) + sheet.tip_position() - flame_offset}, 1.5)
		flame_offset = lighter.flame_position() - L.global_position
		await _go({L: sheet.tip_position() - flame_offset}, 1.5)
		_log("flame %s, %.3f m from the tip (tip %v, flame %v)" % [lighter.flame_on(), lighter.flame_position().distance_to(sheet.tip_position()), sheet.tip_position(), lighter.flame_position()])
		await _wait(0.5)
	_end("LIT" if sheet.lit else "not lit, sheet sealed %s" % sheet.sealed)


# --- helpers --------------------------------------------------------------

func _at(item: Node3D) -> Vector3:
	return Vector3(item.global_position.x, 0.15, item.global_position.z)


func _over(sheet: Node3D, along: float) -> Vector3:
	var p := sheet.to_global(Vector3(along, 0, 0))
	return Vector3(p.x, 0.15, p.z)


## Steers each hand's target to its goal through the input actions.
func _go(goals: Dictionary, timeout := 6.0) -> void:
	var t0 := time
	while time - t0 < timeout:
		var arrived := true
		for hand in goals:
			arrived = _steer(hand, goals[hand]) and arrived
		if arrived:
			break
		await physics_frame
	for hand in goals:
		_steer(hand, Vector3(hand.target.x, hand.carry_height, hand.target.z))
	await _wait(0.6)


func _steer(hand: Node3D, goal: Vector3) -> bool:
	var off: Vector3 = goal - Vector3(hand.target.x, hand.carry_height, hand.target.z)
	_axis(hand, "_left", "_right", off.x)
	_axis(hand, "_fwd", "_back", off.z)
	_axis(hand, "_down", "_up", off.y)
	return off.length() < 0.012


func _axis(hand: Node3D, negative: String, positive: String, value: float) -> void:
	Input.action_release(hand.side + negative)
	Input.action_release(hand.side + positive)
	if absf(value) > 0.006:
		Input.action_press(hand.side + (positive if value > 0.0 else negative))


func _grab(hand: Node3D) -> void:
	Input.action_press(hand.side + "_grip")
	var t0 := time
	while time - t0 < 2.0 and (hand.held == null or hand.target.y < hand.carry_height - 0.005):
		await physics_frame
	_log("%s: %s" % [hand.side, hand.last_event])


func _release(hand: Node3D) -> void:
	Input.action_release(hand.side + "_grip")


func _shake(hand: Node3D, until: Callable, timeout: float) -> void:
	var t0 := time
	var left := true
	while time - t0 < timeout and not until.call():
		Input.action_release(hand.side + ("_right" if left else "_left"))
		Input.action_press(hand.side + ("_left" if left else "_right"))
		left = not left
		await _wait(0.1)
	Input.action_release(hand.side + "_left")
	Input.action_release(hand.side + "_right")
	_log("%s shook for %.1fs" % [hand.side, time - t0])


func _stroke(forward: bool) -> void:
	var action := "_fwd" if forward else "_back"
	Input.action_press("l" + action)
	if sloppy:
		await _wait(stroke * 0.5)
	Input.action_press("r" + action)
	await _wait(stroke * (0.5 if sloppy else 1.0))
	Input.action_release("l" + action)
	if sloppy:
		await _wait(stroke * 0.5)
	Input.action_release("r" + action)


func _wait(seconds: float) -> void:
	var t0 := time
	while time - t0 < seconds:
		await physics_frame


func _log(text: String) -> void:
	print("%6.2fs  %s" % [time, text])
	if shots != "":
		root.get_texture().get_image().save_png("%s/%05.1f.png" % [shots, time])


func _end(result: String) -> void:
	await _wait(2.0)
	_log("RESULT %s" % result)
	if main.done:
		print(main.get_node("HUD/Result").text)
	quit()
