extends SceneTree

## Saves one frame of the scene to a PNG, to look at what cannot be judged
## from a compiler: light, shadows, framing.
##
##   godot --path . --disable-vsync -s tools/screenshot.gd -- /tmp/rolla.png

var _frames := 0


func _initialize() -> void:
	root.add_child(load("res://scripts/controls.gd").new())
	root.add_child(load("res://scenes/main.tscn").instantiate())


func _process(_delta: float) -> bool:
	_frames += 1
	if _frames < 90:
		return false
	var args := OS.get_cmdline_user_args()
	root.get_texture().get_image().save_png(args[0] if args else "screenshot.png")
	return true
