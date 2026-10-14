extends Label

## In-game readout and tuning. Hidden at start; Tab (or Select) shows it,
## together with the two markers for where each hand is being pulled.

# key: [property of the tuning resource, factor]
const TUNE := {
	KEY_1: ["stiffness", 0.9], KEY_2: ["stiffness", 1.1],
	KEY_3: ["damping", 0.9], KEY_4: ["damping", 1.1],
	KEY_5: ["hold_force", 0.9], KEY_6: ["hold_force", 1.1],
	KEY_7: ["tremor", 0.8], KEY_8: ["tremor", 1.25],
}

var _hands: Array[Node] = []


func _ready() -> void:
	_hands = get_tree().get_nodes_in_group("hand")
	_set_shown(false)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("debug"):
		_set_shown(not visible)
	elif visible and event is InputEventKey and event.pressed and TUNE.has(event.physical_keycode):
		var change: Array = TUNE[event.physical_keycode]
		var tuning: Resource = _hands[0].tuning
		tuning.set(change[0], tuning.get(change[0]) * change[1])


func _set_shown(shown: bool) -> void:
	visible = shown
	for hand in _hands:
		hand.target_marker.visible = shown


func _process(_delta: float) -> void:
	if not visible:
		return
	var lines := PackedStringArray()
	for hand in _hands:
		lines.append("%s  height %.2f  load %4.1f N  under %-8s holding %-8s  %s" % [
			hand.side.to_upper(), hand.carry_height, hand.load_n,
			hand.under.label if hand.under else "-",
			hand.held.label if hand.held else "-", hand.last_event])
	var t: Resource = _hands[0].tuning
	lines.append("")
	lines.append("1/2 stiffness %.0f   3/4 damping %.1f   5/6 hold force %.1f N   7/8 tremor %.4f   %d fps" % [
		t.stiffness, t.damping, t.hold_force, t.tremor, Engine.get_frames_per_second()])
	text = "\n".join(lines)
