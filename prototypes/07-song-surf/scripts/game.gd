extends Node2D

## Menu → run → result. The run is exactly as long as the song: it starts when
## the music starts and ends when it ends, so the frame comes for free.
##
## The one rule the player has to read: **the song is a wave moving through the
## terrain at a fixed speed, and you ride just in front of it.** Fall behind and
## only diving catches it again. Run too far ahead and you are out in dead water,
## slowing down. So the skill is not going fast — it is holding your speed to
## the song's.
##
## Measured with tools/surf_bot.gd before settling (numbers in the design notes):
##   - a pull toward the playhead in both directions made holding the button
##     forever the best strategy. The game played itself.
##   - a push inside the pocket did the same, more mildly. It stays as an
##     export (`wave_push`) but defaults to 0.
##   - dead water alone is what separates a player who controls their speed
##     from one who does not, on every song tried.
##
## Announced three ways at once, because a rule that is only on screen was not
## enough in 03–05:
##   - a glowing line in the world, where the music is right now
##   - the sound itself: fall behind and it goes muffled, as if it were playing
##     in the next room; race ahead and it goes thin
##   - a meter: the share of the song you have spent on the wave

const DebugOverlay := preload("res://scripts/debug_overlay.gd")
const TerrainView := preload("res://scripts/terrain_view.gd")
const SONG_DIR := "res://songs"

## The pocket, in seconds of lag: from this far behind the wave...
@export var pocket_behind := 0.25
## ...to this far in front of it. Lag is negative when you are ahead.
@export var pocket_ahead := 0.6
## Push inside the pocket, px/s². 0 by measurement — see the note at the top.
@export var wave_push := 0.0
## Drag once you are past the pocket, px/s² per second beyond it.
@export var dead_water := 300.0
@export var px_per_second := 520.0

enum State { MENU, RUN, RESULT }

var state := State.MENU
var songs: Array[String] = []
var selected := 0
var song: Song
var surfer: Surfer
var camera: Camera2D
var terrain: Node2D
var player: AudioStreamPlayer
var song_time := 0.0
var lag := 0.0
var sync_time := 0.0
var lowpass_hz := 20500.0
var highpass_hz := 10.0
## True when driven by tools/surf_bot.gd: no audio clock to follow.
var headless := false

var _lowpass: AudioEffectLowPassFilter
var _highpass: AudioEffectHighPassFilter
var _background: ColorRect
var _title: Label
var _meter: Label
var _banner: Label


func _ready() -> void:
	headless = DisplayServer.get_name() == "headless"

	var bg_layer := CanvasLayer.new()
	bg_layer.layer = -1
	add_child(bg_layer)
	_background = ColorRect.new()
	_background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg_layer.add_child(_background)

	terrain = TerrainView.new()
	terrain.game = self
	add_child(terrain)

	surfer = Surfer.new()
	add_child(surfer)
	surfer.visible = false

	camera = Camera2D.new()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 5.0
	add_child(camera)

	player = AudioStreamPlayer.new()
	add_child(player)
	_lowpass = AudioEffectLowPassFilter.new()
	_highpass = AudioEffectHighPassFilter.new()
	AudioServer.add_bus_effect(0, _lowpass)
	AudioServer.add_bus_effect(0, _highpass)
	_apply_filters(0.0)

	var hud := CanvasLayer.new()
	add_child(hud)
	_title = _label(hud, 16, Control.PRESET_TOP_LEFT, Vector2(16, 12))
	_title.grow_horizontal = Control.GROW_DIRECTION_END
	_meter = _label(hud, 20, Control.PRESET_CENTER_TOP, Vector2(0, 12))
	_banner = _label(hud, 20, Control.PRESET_CENTER, Vector2.ZERO)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var overlay := DebugOverlay.new()
	overlay.game = self
	overlay.position = Vector2(16, 44)
	overlay.add_theme_font_size_override(&"font_size", 13)
	overlay.modulate.a = 0.0
	hud.add_child(overlay)

	_scan_songs()
	_show_menu()


func _scan_songs() -> void:
	songs.clear()
	for f in DirAccess.get_files_at(SONG_DIR):
		if f.ends_with(".json"):
			songs.append(SONG_DIR.path_join(f))
	songs.sort()


func _show_menu() -> void:
	state = State.MENU
	player.stop()
	surfer.visible = false
	_apply_filters(0.0)
	if songs.is_empty():
		_banner.text = "\n".join([
			"SONG SURF",
			"",
			"no songs yet. from prototypes/07-song-surf:",
			"python3 tools/analyse_song.py ~/Music/your_song.mp3",
		])
		return
	var lines := ["SONG SURF", "", "the ground is the song. ride it.", ""]
	for i in songs.size():
		var name := songs[i].get_file().get_basename()
		lines.append(("▸  " if i == selected else "    ") + name)
	lines.append_array(["", "↑ ↓ pick    SPACE go",
		"", "hold SPACE: dive down the hills    let go: fly off them",
		"surf just in front of the glowing line — that is where the music is"])
	_banner.text = "\n".join(lines)


func start(index: int) -> void:
	selected = index
	song = Song.load_json(songs[index])
	if song == null:
		_banner.text = "could not read %s" % songs[index]
		return
	song.px_per_second = px_per_second
	song.build()
	surfer.song = song
	surfer.reset(0.0, px_per_second)
	surfer.visible = true
	song_time = 0.0
	sync_time = 0.0
	lag = 0.0
	_banner.text = ""
	state = State.RUN
	if not headless:
		var stream := AudioStreamOggVorbis.load_from_file(ProjectSettings.globalize_path(song.audio_path))
		player.stream = stream
		player.play()
	camera.position = surfer.position
	camera.reset_smoothing()


func _process(delta: float) -> void:
	match state:
		State.MENU:
			if not songs.is_empty():
				if Input.is_action_just_pressed(&"menu_up"):
					selected = posmod(selected - 1, songs.size())
					_show_menu()
				elif Input.is_action_just_pressed(&"menu_down"):
					selected = posmod(selected + 1, songs.size())
					_show_menu()
				elif Input.is_action_just_pressed(&"start"):
					start(selected)
		State.RUN:
			if Input.is_action_just_pressed(&"back"):
				_show_menu()
				return
			_advance(delta)
		State.RESULT:
			if Input.is_action_just_pressed(&"start"):
				start(selected)
			elif Input.is_action_just_pressed(&"back"):
				_show_menu()
	_update_view(delta)


## One frame of a run. Public so the bot can drive it at a fixed step.
func _advance(delta: float) -> void:
	song_time = _clock(delta)
	surfer.holding = Input.is_action_pressed(&"dive")
	surfer.wave_accel = _wave_accel(lag)
	surfer.step(delta)
	lag = song_time - surfer.position.x / px_per_second
	if on_wave():
		sync_time += delta
	_apply_filters(lag)
	if song_time >= song.duration or (not headless and not player.playing and song_time > 1.0):
		_finish()


func on_wave() -> bool:
	return lag <= pocket_behind and lag >= -pocket_ahead


func _wave_accel(l: float) -> float:
	if l > pocket_behind:
		return 0.0
	if l >= -pocket_ahead:
		return wave_push
	return -dead_water * minf(-l - pocket_ahead, 1.5)


func _clock(delta: float) -> float:
	if headless or not player.playing:
		return song_time + delta
	var t := player.get_playback_position() + AudioServer.get_time_since_last_mix() \
			- AudioServer.get_output_latency()
	# The mix clock moves in chunks; never let the song run backwards.
	return maxf(t, song_time)


func _apply_filters(lag_s: float) -> void:
	# Behind: the song recedes into the next room. Ahead: it goes thin.
	var behind := maxf(lag_s - pocket_behind, 0.0)
	var ahead := maxf(-lag_s - pocket_ahead, 0.0)
	lowpass_hz = clampf(20500.0 * exp(-behind * 3.2), 300.0, 20500.0)
	highpass_hz = clampf(10.0 * exp(ahead * 4.5), 10.0, 2500.0)
	_lowpass.cutoff_hz = lowpass_hz
	_highpass.cutoff_hz = highpass_hz


func _finish() -> void:
	state = State.RESULT
	player.stop()
	_apply_filters(0.0)
	var pct := 100.0 * sync_time / maxf(song.duration, 0.001)
	_banner.text = "\n".join([
		song.title,
		"",
		"on the wave  %d%%" % roundi(pct),
		"perfect landings  %d      longest flight  %.1fs" % [surfer.perfect_landings, surfer.best_air],
		"",
		"SPACE again    R songs",
	])


func sync_percent() -> float:
	return 100.0 * sync_time / maxf(song_time, 0.001)


func _update_view(delta: float) -> void:
	var t := song_time if state == State.RUN else 0.0
	var pulse := song.beat_pulse(t) if song and state == State.RUN else 0.0
	var lowv := song.low_at(t) if song and state == State.RUN else 0.0
	# The background breathes with the bass and drifts through the hues with the song.
	var hue := fmod(0.72 + t * 0.004, 1.0)
	_background.color = Color.from_hsv(hue, 0.55, 0.07 + 0.10 * lowv + 0.05 * pulse)

	if state == State.RUN or state == State.RESULT:
		var p := surfer.position
		var high := maxf(-p.y, 0.0)
		var needed := maxf(high + 260.0, 560.0)
		var zoom := clampf(620.0 / needed, 0.4, 1.0)
		camera.zoom = camera.zoom.lerp(Vector2(zoom, zoom), minf(delta * 3.0, 1.0))
		camera.position = Vector2(p.x + 300.0 / camera.zoom.x, minf(p.y * 0.6, -120.0) + 60.0)

	if state == State.RUN:
		_title.text = song.title
		var state_word := "on the wave"
		if lag > pocket_behind:
			state_word = "the wave passed you  %.1fs" % lag
		elif lag < -pocket_ahead:
			state_word = "too far ahead  %.1fs" % -lag
		_meter.text = "%s      %d%%" % [state_word, roundi(sync_percent())]
	else:
		_title.text = ""
		_meter.text = ""
	terrain.queue_redraw()


func _label(parent: Node, size: int, preset: Control.LayoutPreset, offset: Vector2) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override(&"font_size", size)
	parent.add_child(label)
	label.set_anchors_and_offsets_preset(preset)
	label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	label.grow_vertical = Control.GROW_DIRECTION_BOTH
	label.position += offset
	return label
