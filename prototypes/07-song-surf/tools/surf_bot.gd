extends SceneTree

## Headless ruler: surfs a song with a fixed policy and reports how much of it
## was spent in sync. The point is the gap between policies — if never pressing
## scores as well as diving well, the button does not matter and neither does
## the game.
##
##   godot --headless --path . --fixed-fps 60 -s tools/surf_bot.gd -- <policy> [song-index]
##
## Policies:
##   never     never press
##   always    hold the whole time
##   slopes    hold while the ground ahead runs downhill, let go when it rises
##   sync      as slopes, but only while behind the playhead: speed control

var game: Node2D
var policy := "slopes"
var index := 0
var frame := 0
var worst_lag := 0.0
var pull := -1.0


func _initialize() -> void:
	root.add_child(load("res://scripts/controls.gd").new())
	var args := OS.get_cmdline_user_args()
	if args.size() > 0:
		policy = args[0]
	if args.size() > 1:
		index = int(args[1])
	if args.size() > 2:
		pull = float(args[2])
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)


func _process(_delta: float) -> bool:
	frame += 1
	if frame == 2:
		game.start(index)
		if pull >= 0.0:
			game.wave_push = pull
		return false
	if frame < 2 or game.state != game.State.RUN:
		if frame > 2 and game.state == game.State.RESULT:
			_report()
			quit()
		return false

	var s: Surfer = game.surfer
	var hold := false
	match policy:
		"always":
			hold = true
		"slopes":
			# Look a little ahead: by the time you feel the slope it is late.
			var ahead := s.position.x + s.velocity.x * 0.08
			hold = game.song.slope_at(ahead) < -0.05
		"sync":
			var ahead := s.position.x + s.velocity.x * 0.08
			hold = game.song.slope_at(ahead) < -0.05 and game.lag > -0.2
	if hold:
		Input.action_press(&"dive")
	else:
		Input.action_release(&"dive")
	worst_lag = maxf(worst_lag, absf(game.lag))
	if OS.get_environment("BOT_TRACE") != "" and frame % 300 == 0:
		print("  t %5.1fs   lag %+.2f   speed %4d   sync %3d%%" % [
			game.song_time, game.lag, int(s.velocity.length()), roundi(game.sync_percent())])
	return false


func _report() -> void:
	var s: Surfer = game.surfer
	print("%-7s push %3d  %-30s sync %3d%%   worst |lag| %.1fs   perfect %d   longest flight %.1fs" % [
		policy, int(game.wave_push), game.song.title.left(30), roundi(100.0 * game.sync_time / game.song.duration),
		worst_lag, s.perfect_landings, s.best_air])
