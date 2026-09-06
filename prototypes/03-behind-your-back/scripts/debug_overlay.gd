extends Label

## In-game tuning. Convention since prototype 02: prototypes tune themselves,
## no editor round-trip.

## Paths, resolved in _ready(). A bare `@export var gaze: CanvasItem` looks
## tidier, but a NodePath written by hand into the .tscn does not populate it —
## it stays null and F2 and F5 silently do nothing.
@export var gaze_path: NodePath
@export var player_path: NodePath

var gaze: CanvasItem
var player: Node2D


func _ready() -> void:
	gaze = get_node_or_null(gaze_path) as CanvasItem
	player = get_node_or_null(player_path) as Node2D


func _process(_delta: float) -> void:
	var leg_name: String = ["OUTBOUND", "RETURN", "DONE"][Run.leg]
	text = "\n".join([
		"leg          %s" % leg_name,
		"out / back   %.1fs / %.1fs" % [Run.outbound_time, Run.return_time],
		"mutation     %s   chance %.2f" % [
			"on" if Observer.mutation_enabled else "OFF", Observer.mutation_chance
		],
		"margin       %d px" % int(Observer.margin),
		"changes      %d" % Observer.mutations,
		"",
		"F1 overlay   F2 gaze edge   F3 mutation on/off",
		"[ ] margin   , . chance   R respawn   F5 restart run",
	])


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match (event as InputEventKey).physical_keycode:
		KEY_F1:
			modulate.a = 0.0 if modulate.a > 0.5 else 1.0
		KEY_F2:
			if gaze:
				gaze.visible = not gaze.visible
		KEY_F3:
			Observer.mutation_enabled = not Observer.mutation_enabled
		KEY_BRACKETLEFT:
			Observer.margin = maxf(Observer.margin - 40.0, 0.0)
		KEY_BRACKETRIGHT:
			Observer.margin += 40.0
		KEY_COMMA:
			Observer.mutation_chance = clampf(Observer.mutation_chance - 0.1, 0.0, 1.0)
		KEY_PERIOD:
			Observer.mutation_chance = clampf(Observer.mutation_chance + 0.1, 0.0, 1.0)
		KEY_F5:
			Run.reset()
			Observer.reset()
			if player and player.has_method(&"respawn"):
				player.set_respawn_point(Vector2(180.0, 545.0))
				player.respawn()
