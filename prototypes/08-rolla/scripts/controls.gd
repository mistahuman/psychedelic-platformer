extends Node

## Registers input actions at runtime. Actions already present in the project's
## InputMap are left untouched. Tuning keys live in scripts/debug_overlay.gd.
##
## Each hand has the same seven actions, prefixed l_ / r_. Deliberately
## over-bound for the first play: prune once it is clear which keys get used.

# [keycode, location]: location tells left Shift from right Shift.
const KEYS := {
	"l_left": [KEY_A], "l_right": [KEY_D], "l_fwd": [KEY_W], "l_back": [KEY_S],
	"l_up": [KEY_E], "l_down": [KEY_Q],
	"l_grip": [KEY_SPACE, [KEY_SHIFT, KEY_LOCATION_LEFT]],
	"r_left": [KEY_LEFT, KEY_J], "r_right": [KEY_RIGHT, KEY_L],
	"r_fwd": [KEY_UP, KEY_I], "r_back": [KEY_DOWN, KEY_K],
	"r_up": [KEY_PAGEUP, KEY_O], "r_down": [KEY_PAGEDOWN, KEY_U],
	"r_grip": [KEY_ENTER, KEY_SEMICOLON, [KEY_SHIFT, KEY_LOCATION_RIGHT]],
	"reset": [KEY_R],
	"debug": [KEY_TAB],
}

# Gamepad, wired but untested (no pad was connected when this was written).
# Stick = plane, shoulder held + stick = height, trigger = grip.
const PAD_AXES := {
	"l_left": [JOY_AXIS_LEFT_X, -1.0], "l_right": [JOY_AXIS_LEFT_X, 1.0],
	"l_fwd": [JOY_AXIS_LEFT_Y, -1.0], "l_back": [JOY_AXIS_LEFT_Y, 1.0],
	"l_grip": [JOY_AXIS_TRIGGER_LEFT, 1.0],
	"r_left": [JOY_AXIS_RIGHT_X, -1.0], "r_right": [JOY_AXIS_RIGHT_X, 1.0],
	"r_fwd": [JOY_AXIS_RIGHT_Y, -1.0], "r_back": [JOY_AXIS_RIGHT_Y, 1.0],
	"r_grip": [JOY_AXIS_TRIGGER_RIGHT, 1.0],
}
const PAD_BUTTONS := {
	"l_mod": JOY_BUTTON_LEFT_SHOULDER, "r_mod": JOY_BUTTON_RIGHT_SHOULDER,
	"reset": JOY_BUTTON_START, "debug": JOY_BUTTON_BACK,
}


func _enter_tree() -> void:
	for action in KEYS:
		for key in KEYS[action]:
			var event := InputEventKey.new()
			if key is Array:
				event.physical_keycode = key[0]
				event.location = key[1]
			else:
				event.physical_keycode = key
			_add(action, event)
	for action in PAD_AXES:
		var event := InputEventJoypadMotion.new()
		event.axis = PAD_AXES[action][0]
		event.axis_value = PAD_AXES[action][1]
		_add(action, event)
	for action in PAD_BUTTONS:
		var event := InputEventJoypadButton.new()
		event.button_index = PAD_BUTTONS[action]
		_add(action, event)


func _add(action: String, event: InputEvent) -> void:
	if not InputMap.has_action(action):
		InputMap.add_action(action, 0.2)
	InputMap.action_add_event(action, event)
