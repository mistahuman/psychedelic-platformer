extends Label

## In-game tuning. Convention since prototype 02: prototypes tune themselves,
## no editor round-trip. Hidden at start so the first run is played, not read.
## Terrain settings take effect on the next run (SPACE on the result screen).

var game: Node2D


func _process(_delta: float) -> void:
	var s: Surfer = game.surfer
	var song: Song = game.song
	text = "\n".join([
		"lag          %+.2fs" % game.lag,
		"speed        %d px/s" % int(s.velocity.length()),
		"filters      low %d Hz   high %d Hz" % [int(game.lowpass_hz), int(game.highpass_hz)],
		"bpm          %s" % ("%.1f   %d beats per hill" % [song.bpm, song.beats_per_hill] if song else "—"),
		"",
		"dive x       %.1f" % s.dive_multiplier,
		"gravity      %d" % int(s.gravity),
		"min speed    %d" % int(s.min_speed),
		"song speed   %d px/s   (next run)" % int(game.px_per_second),
		"",
		"F1 overlay   [ ] dive   , . gravity   9 0 min speed   - = song speed",
	])


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	var s: Surfer = game.surfer
	match (event as InputEventKey).physical_keycode:
		KEY_F1:
			modulate.a = 0.0 if modulate.a > 0.5 else 1.0
		KEY_BRACKETLEFT:
			s.dive_multiplier = maxf(s.dive_multiplier - 0.2, 1.0)
		KEY_BRACKETRIGHT:
			s.dive_multiplier += 0.2
		KEY_COMMA:
			s.gravity = maxf(s.gravity - 100.0, 200.0)
		KEY_PERIOD:
			s.gravity += 100.0
		KEY_9:
			s.min_speed = maxf(s.min_speed - 40.0, 0.0)
		KEY_0:
			s.min_speed += 40.0
		KEY_MINUS:
			game.px_per_second = maxf(game.px_per_second - 40.0, 200.0)
		KEY_EQUAL:
			game.px_per_second += 40.0
