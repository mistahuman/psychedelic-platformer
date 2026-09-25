extends Node

## Registers input actions at runtime. Actions already present in the project's
## InputMap are left untouched. Debug keys live in scripts/debug_overlay.gd.
## "jump" is the only button: jump on the ground, hook in the air.

const BINDINGS := {
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"jump": [KEY_SPACE, KEY_W, KEY_UP],
	"restart": [KEY_R],
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
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	InputMap.action_add_event(&"jump", click)
