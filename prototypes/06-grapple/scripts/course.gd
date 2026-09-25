extends Node2D

## One course, left to right, built from the tables below so the layout stays
## diffable. It has a start, a flag and a clock: prototypes 01–05 taught that a
## sandbox with no end is unreadable, so even this one gets a frame.
##
## Each stretch of the course teaches one thing, in order:
##   1. one anchor over one gap           — hook, swing, let go
##   2. two anchors, no floor between     — let go of one, catch the next
##   3. three anchors, wider apart        — release on the upswing to carry
##   4. a platform higher than you start  — pump the swing to gain height
##   5. the long run to the flag          — all of it, at speed

const DebugOverlay := preload("res://scripts/debug_overlay.gd")

## [x_from, x_to, y_top]. Every platform is a checkpoint.
const PLATFORMS := [
	[0, 320, 600],
	[760, 1000, 600],
	[1880, 2080, 560],
	[3560, 3760, 500],
	[4280, 4500, 420],
	[6020, 6500, 600],
]
const ANCHORS := [
	Vector2(520, 300),
	Vector2(1250, 290),
	Vector2(1600, 290),
	Vector2(2420, 260),
	Vector2(2860, 210),
	Vector2(3300, 250),
	Vector2(4020, 260),
	Vector2(4860, 220),
	Vector2(5300, 260),
	Vector2(5720, 220),
]
const START := Vector2(140, 580)
const FLAG_X := 6300.0
const WORLD_RIGHT := 6500
const DANGER_Y := 740.0

const INK := Color(1.0, 0.85, 0.5)
const PLATFORM_COLOR := Color(0.36, 0.3, 0.52)
const FLAG_COLOR := Color(0.35, 0.95, 0.8)

var player: Grappler
var best_time := INF

var _started := false
var _finished := false
var _time := 0.0
var _falls := 0
var _hooks := 0
var _clock: Label
var _banner: Label


func _ready() -> void:
	for p in PLATFORMS:
		_add_platform(p[0], p[1], p[2])
	# Walls at both ends. A good release clears the last platform entirely.
	_add_wall(-40.0)
	_add_wall(WORLD_RIGHT)
	_add_flag()

	player = Grappler.new()
	player.name = "Player"
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(20, 30)
	shape.shape = rect
	player.add_child(shape)
	var body := ColorRect.new()
	body.size = rect.size
	body.position = -rect.size / 2.0
	body.color = Color(0.95, 0.95, 1.0)
	body.show_behind_parent = true
	player.add_child(body)
	player.position = START
	player.anchors = PackedVector2Array(ANCHORS)
	player.floor_snap_length = 16.0
	add_child(player)
	player.hooked.connect(func(_a: Vector2) -> void: _hooks += 1)
	player.fell.connect(func() -> void: _falls += 1)

	var camera := Camera2D.new()
	camera.limit_left = 0
	camera.limit_right = WORLD_RIGHT
	camera.limit_top = -60
	camera.limit_bottom = 760
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 6.0
	player.add_child(camera)

	var hud := CanvasLayer.new()
	add_child(hud)
	_clock = _label(hud, 22)
	_clock.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_clock.position.y = 16.0
	_banner = _label(hud, 20)
	_banner.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.text = "\n".join([
		"GRAPPLE",
		"",
		"SPACE  jump",
		"SPACE again in the air  hook the ringed anchor — hold it",
		"let go  fly",
		"A / D while hanging  pump the swing",
		"",
		"reach the flag",
	])

	var overlay := DebugOverlay.new()
	overlay.course = self
	overlay.position = Vector2(16, 16)
	overlay.add_theme_font_size_override(&"font_size", 13)
	overlay.modulate.a = 0.0
	hud.add_child(overlay)


func _process(delta: float) -> void:
	if not _started and (Input.is_action_pressed(&"jump")
			or not is_zero_approx(Input.get_axis(&"move_left", &"move_right"))):
		_started = true
		_banner.text = ""
	if _started and not _finished:
		_time += delta
		if player.global_position.x >= FLAG_X and player.is_on_floor():
			_finish()
	if Input.is_action_just_pressed(&"restart"):
		restart()

	_clock.text = "%s    falls %d" % [_format(_time), _falls]
	queue_redraw()


func _finish() -> void:
	_finished = true
	var record := _time < best_time
	best_time = minf(best_time, _time)
	_banner.text = "\n".join([
		"FLAG",
		"",
		"%s    %d falls    %d hooks" % [_format(_time), _falls, _hooks],
		"new best" if record else "best  %s" % _format(best_time),
		"",
		"R  go again",
	])


func restart() -> void:
	_started = false
	_finished = false
	_time = 0.0
	_falls = 0
	_hooks = 0
	_banner.text = ""
	player.reset_to(START)


func _draw() -> void:
	# The pit. Anything below this line is a fall.
	draw_rect(Rect2(0, DANGER_Y, WORLD_RIGHT, 60), Color(0.55, 0.12, 0.25, 0.35))
	for a: Vector2 in ANCHORS:
		var in_range := a.distance_to(player.global_position) <= player.hook_range
		var c := INK if in_range else Color(0.55, 0.5, 0.7)
		draw_circle(a, 7.0, c)
		if player.is_hooked and a == player.anchor:
			draw_circle(a, 11.0, Color(INK, 0.5))


func _add_platform(x_from: float, x_to: float, y_top: float) -> void:
	var body := StaticBody2D.new()
	var size := Vector2(x_to - x_from, 40.0)
	body.position = Vector2(x_from, y_top) + size / 2.0
	body.set_meta(&"spawn", Vector2((x_from + x_to) / 2.0, y_top - 20.0))
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = size
	shape.shape = rect
	body.add_child(shape)
	var visual := ColorRect.new()
	visual.size = size
	visual.position = -size / 2.0
	visual.color = PLATFORM_COLOR
	body.add_child(visual)
	add_child(body)


func _add_wall(x: float) -> void:
	var body := StaticBody2D.new()
	body.position = Vector2(x + 20.0, 300.0)
	var shape := CollisionShape2D.new()
	var rect := RectangleShape2D.new()
	rect.size = Vector2(40.0, 1400.0)
	shape.shape = rect
	body.add_child(shape)
	add_child(body)


func _add_flag() -> void:
	var y_top: float = PLATFORMS[-1][2]
	var pole := ColorRect.new()
	pole.size = Vector2(4, 90)
	pole.position = Vector2(FLAG_X, y_top - 90.0)
	pole.color = FLAG_COLOR
	add_child(pole)
	var cloth := ColorRect.new()
	cloth.size = Vector2(40, 26)
	cloth.position = Vector2(FLAG_X + 4.0, y_top - 90.0)
	cloth.color = FLAG_COLOR
	add_child(cloth)


func _label(parent: Node, size: int) -> Label:
	var label := Label.new()
	label.add_theme_font_size_override(&"font_size", size)
	label.grow_horizontal = Control.GROW_DIRECTION_BOTH
	label.grow_vertical = Control.GROW_DIRECTION_BOTH
	parent.add_child(label)
	return label


static func _format(t: float) -> String:
	return "%d:%05.2f" % [int(t) / 60, fmod(t, 60.0)]
