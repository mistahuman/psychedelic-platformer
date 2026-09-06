extends Node

## Registers input actions at runtime. Actions already present in the project's
## InputMap are left untouched.

const BINDINGS := {
	"move_left": [KEY_A, KEY_LEFT],
	"move_right": [KEY_D, KEY_RIGHT],
	"jump": [KEY_SPACE, KEY_W, KEY_UP],
	"respawn": [KEY_R],
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
