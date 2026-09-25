extends Label

## In-game tuning. Convention since prototype 02: prototypes tune themselves,
## no editor round-trip. Hidden at start so the first run is played, not read.

var course: Node2D


func _process(_delta: float) -> void:
	var p: Grappler = course.player
	text = "\n".join([
		"speed        %d px/s" % int(p.velocity.length()),
		"rope         %s" % ("%d px" % int(p.rope_length) if p.is_hooked else "—"),
		"hook range   %d" % int(p.hook_range),
		"pump         %d" % int(p.pump_acceleration),
		"release x    %.2f" % p.release_boost,
		"air control  %d" % int(p.air_acceleration),
		"gravity      %d" % int(p.gravity),
		"",
		"F1 overlay   , . range   [ ] pump   - = release boost",
		"9 0 air control   7 8 gravity   R restart",
	])


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var p: Grappler = course.player
	match (event as InputEventKey).physical_keycode:
		KEY_F1:
			modulate.a = 0.0 if modulate.a > 0.5 else 1.0
		KEY_COMMA:
			p.hook_range = maxf(p.hook_range - 40.0, 80.0)
		KEY_PERIOD:
			p.hook_range += 40.0
		KEY_BRACKETLEFT:
			p.pump_acceleration = maxf(p.pump_acceleration - 100.0, 0.0)
		KEY_BRACKETRIGHT:
			p.pump_acceleration += 100.0
		KEY_MINUS:
			p.release_boost = maxf(p.release_boost - 0.05, 0.5)
		KEY_EQUAL:
			p.release_boost += 0.05
		KEY_9:
			p.air_acceleration = maxf(p.air_acceleration - 150.0, 0.0)
		KEY_0:
			p.air_acceleration += 150.0
		KEY_7:
			p.gravity = maxf(p.gravity - 100.0, 300.0)
		KEY_8:
			p.gravity += 100.0
