extends Node3D

## The table and the steps. Spawns the sheet when the papers are shaken and
## crumbs when the grinder is, seals at the mouth, lights from the flame,
## shows where you are in the six steps, and scores the result.

const SHEET := preload("res://scenes/items/sheet.tscn")
const CRUMB := preload("res://scenes/items/crumb.tscn")
const TUNING := preload("res://tuning.tres")
const MAX_CRUMBS := 60
const MOUTH_RADIUS := 0.09
const FLAME_REACH := 0.06

## Best score survives a reset because a static belongs to the script, not the scene.
static var best := -1

@export var camera_aim := Vector3(0.0, 0.0, -0.05)
@export var mouth := Vector3(0.0, 0.22, 0.45)

var sheet: RigidBody3D
var clock := 0.0
var running := false
var done := false
var _licking := 0.0
var _burning := 0.0
var _message_left := 0.0

@onready var _hands: Array[Node] = [$HandL, $HandR]
@onready var _lighter: RigidBody3D = $Lighter
@onready var _mouth: MeshInstance3D = $Mouth
@onready var _steps: Label = $HUD/Steps
@onready var _message: Label = $HUD/Message
@onready var _result: Label = $HUD/Result


func _ready() -> void:
	$Camera.look_at(camera_aim)
	_mouth.global_position = mouth
	$Papers.shaken.connect(_on_papers_shaken)
	$Grinder.shaken.connect(_on_grinder_shaken)
	_lighter.shaken.connect(_on_lighter_shaken)


func _process(delta: float) -> void:
	if Input.is_action_just_pressed("reset"):
		get_tree().reload_current_scene()
		return
	_message_left -= delta
	_message.modulate.a = clampf(_message_left, 0.0, 1.0)
	if done:
		return
	if not running:
		running = _hands.any(func(h): return h.linear_velocity.length() > 0.05)
	else:
		clock += delta
	if sheet != null:
		_seal(delta)
		_light(delta)
	_mouth.visible = sheet != null and sheet.rolled() and not sheet.sealed
	_show_steps()


func _seal(delta: float) -> void:
	if not sheet.rolled() or sheet.sealed:
		_licking = 0.0
		return
	if sheet.middle_position().distance_to(mouth) < MOUTH_RADIUS:
		_licking += delta
		if _licking >= TUNING.lick_time:
			sheet.sealed = true
			_say("Sealed.")
	else:
		_licking = 0.0


func _light(delta: float) -> void:
	if not _lighter.flame_on() or not sheet.rolled():
		return
	if _lighter.flame_position().distance_to(sheet.tip_position()) > FLAME_REACH:
		return
	if not sheet.sealed:
		_say("Seal it first: to your mouth.")
		return
	_burning += delta
	if _burning >= TUNING.light_time:
		sheet.light()
		_finish()


func _finish() -> void:
	done = true
	var crumb_points := mini(sheet.crumbs, 30) * 5
	var filter_points := 50 if sheet.has_filter else 0
	var neat_points := roundi(sheet.neatness() * 100.0)
	var time_points := maxi(240 - int(clock), 0)
	var total := crumb_points + filter_points + neat_points + time_points
	var record := total > best
	best = maxi(best, total)
	_result.text = "Lit.\n\ncrumbs  %d × 5 = %d\nfilter  %d\nneat  %d%%  = %d\ntime  %s  → %d\n\nscore  %d%s\n\nR to roll another" % [
		sheet.crumbs, crumb_points, filter_points, neat_points, neat_points,
		_time(clock), time_points, total, "   best yet" if record else "   (best %d)" % best]
	_result.visible = true


func _on_papers_shaken(papers: RigidBody3D) -> void:
	if sheet != null:
		_say("One sheet at a time.")
		return
	sheet = SHEET.instantiate()
	add_child(sheet)
	var at := papers.global_position + Vector3(0.0, -0.05, 0.0)
	sheet.global_position = Vector3(at.x, maxf(at.y, 0.02), at.z)  # never inside the table
	sheet.rotate_y(randf_range(-0.3, 0.3))
	sheet.spilled.connect(_spill)
	sheet.torn.connect(func(_s): sheet = null; _say("Torn. Shake the papers for another."))
	sheet.undone.connect(func(_s): _say("It came undone. Roll it again."))
	_say("A sheet.")


func _on_grinder_shaken(grinder: RigidBody3D) -> void:
	if get_tree().get_nodes_in_group("crumb").size() >= MAX_CRUMBS:
		_say("The grinder is empty.")
		return
	var at := grinder.global_position + Vector3(0.0, -0.05, 0.0)  # clear of its bottom
	_spill(Vector3(at.x, maxf(at.y, 0.02), at.z), 3)


func _on_lighter_shaken(lighter: RigidBody3D) -> void:
	_say("Flame." if lighter.strike() else "click.")


func _spill(at: Vector3, count: int) -> void:
	for i in mini(count, MAX_CRUMBS - get_tree().get_nodes_in_group("crumb").size()):
		var crumb: RigidBody3D = CRUMB.instantiate()
		add_child(crumb)
		crumb.global_position = at + Vector3(randf_range(-0.015, 0.015), 0.0, randf_range(-0.015, 0.015))


func _show_steps() -> void:
	var s = sheet  # untyped: its methods live in sheet.gd
	var rolled: bool = s != null and s.rolled()
	var lines := PackedStringArray([
		_step(s != null, "sheet", "", "shake the papers"),
		_step(s != null and s.crumbs > 0, "crumbs", str(s.crumbs_showing()) if s else "", "shake the grinder over the sheet"),
		_step(s != null and s.has_filter, "filter", "", "on one end of the sheet"),
		_step(rolled, "rolled", "%d%%  neat %d%%" % [s.progress * 100, s.neatness() * 100] if s else "",
				"both hands on it, then W/S with ↑/↓ together"),
		_step(s != null and s.sealed, "sealed", "%d s" % ceili(s.undone_in) if rolled and not s.sealed else "",
				"to your mouth, the pink spot"),
		_step(s != null and s.lit, "lit", "", "shake the lighter, flame on the tip"),
		"",
		"      " + _time(clock),
	])
	_steps.text = "\n".join(lines)


func _step(ok: bool, name: String, value: String, how: String) -> String:
	return "%s  %-7s %-16s %s" % ["[x]" if ok else "[  ]", name, value, "" if ok else how]


func _say(text: String) -> void:
	if _message.text == text and _message_left > 1.0:
		return
	_message.text = text
	_message_left = 2.0


func _time(seconds: float) -> String:
	return "%d:%02d" % [int(seconds) / 60, int(seconds) % 60]
