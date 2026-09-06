extends Label

## In-game tuning. Convention since prototype 02: prototypes tune themselves.

## Paths rather than node exports: see the note in maze_view.gd.
@export var maze_path: NodePath
@export var view_path: NodePath

var maze: Node2D
var view: Node2D

var _time := 0.0
var _escaped_at := -1.0


func _ready() -> void:
	maze = get_node_or_null(maze_path) as Node2D
	view = get_node_or_null(view_path) as Node2D
	if maze:
		maze.reached_exit.connect(_on_reached_exit)


func _process(delta: float) -> void:
	if _escaped_at < 0.0:
		_time += delta
	if maze == null:
		return
	var explored := 100.0 * float(maze.seen_count) / float(maze.cols * maze.rows)
	text = "\n".join([
		"time         %.1fs%s" % [_time, "   ESCAPED" if _escaped_at >= 0.0 else ""],
		"explored     %d%%" % int(explored),
		"wrong        %d cells" % maze.stale_count(),
		"changes      %d" % maze.mutations,
		"mutation     %s   %.1f/s" % [
			"on" if maze.mutation_enabled else "OFF", maze.mutation_rate
		],
		"lantern      %.1f cells" % maze.light_radius,
		"",
		"F1 overlay      F3 mutation on/off",
		"F4 reveal what you remember wrongly",
		"[ ] lantern     , . change rate",
		"R back to start    F5 new maze",
	])


func _on_reached_exit() -> void:
	_escaped_at = _time


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match (event as InputEventKey).physical_keycode:
		KEY_F1:
			modulate.a = 0.0 if modulate.a > 0.5 else 1.0
		KEY_F3:
			if maze:
				maze.mutation_enabled = not maze.mutation_enabled
		KEY_F4:
			if view:
				view.show_stale = not view.show_stale
		KEY_BRACKETLEFT:
			if maze:
				maze.light_radius = maxf(maze.light_radius - 0.4, 0.8)
		KEY_BRACKETRIGHT:
			if maze:
				maze.light_radius += 0.4
		KEY_COMMA:
			if maze:
				maze.mutation_rate = maxf(maze.mutation_rate - 0.5, 0.0)
		KEY_PERIOD:
			if maze:
				maze.mutation_rate += 0.5
		KEY_R:
			if maze:
				maze.send_player_to_start()
		KEY_F5:
			if maze:
				maze.rebuild()
			_time = 0.0
			_escaped_at = -1.0
