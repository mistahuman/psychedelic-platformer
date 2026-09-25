extends Node

## Registers input actions at runtime. Actions already present in the project's
## InputMap are left untouched. Debug keys live in scripts/debug_overlay.gd.
## "dive" is the only button that matters while surfing.

const BINDINGS := {
	"dive": [KEY_SPACE],
	"start": [KEY_SPACE, KEY_ENTER],
	"menu_up": [KEY_UP, KEY_W],
	"menu_down": [KEY_DOWN, KEY_S],
	"back": [KEY_ESCAPE, KEY_R],
}


func _enter_tree() -> void:
	for action_name in BINDINGS:
		if InputMap.has_action(action_name):
			continue
		InputMap.add_action(action_name, 0.5)
		for keycode in BINDINGS[action_name]:
			var event := InputEventKey.new()
			event.physical_keycode = keycode
			InputMap.action_add_event(action_name, event)
		if action_name == "dive":
			var click := InputEventMouseButton.new()
			click.button_index = MOUSE_BUTTON_LEFT
			InputMap.action_add_event(action_name, click)
