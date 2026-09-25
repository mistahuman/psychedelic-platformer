extends Node2D

## Draws only the stretch of ground the camera can see, straight from the song's
## height function. Each hill is its own polygon so it can take its own colour:
## loud hills are hot, quiet ones are cool, and the one the music is on right
## now lights up.

var game: Node2D

const STEP := 8.0


func _draw() -> void:
	var song: Song = game.song
	if song == null or game.state == game.State.MENU:
		return
	var cam: Camera2D = game.camera
	var half := get_viewport_rect().size / cam.zoom / 2.0
	var x0 := cam.get_screen_center_position().x - half.x - STEP
	var x1 := cam.get_screen_center_position().x + half.x + STEP
	var bottom := cam.get_screen_center_position().y + half.y + 10.0
	var now_hill := song.hill_index(game.song_time)
	var pulse := song.beat_pulse(game.song_time)

	# One polygon per hill (or per flat stretch), cut at the valleys.
	var x := x0
	while x < x1:
		var k := song.hill_index(x / song.px_per_second)
		var seg_end := x1
		if k >= 0:
			seg_end = minf(song.valleys[k + 1] * song.px_per_second, x1)
		elif song.valleys.size() > 0 and x < song.valleys[0] * song.px_per_second:
			seg_end = minf(song.valleys[0] * song.px_per_second, x1)
		seg_end = maxf(seg_end, x + STEP)
		var pts := PackedVector2Array()
		var top := PackedVector2Array()
		var sx := x
		while sx < seg_end:
			top.append(Vector2(sx, -song.height_at(sx)))
			sx += STEP
		top.append(Vector2(seg_end, -song.height_at(seg_end)))
		pts.append_array(top)
		pts.append(Vector2(seg_end, bottom))
		pts.append(Vector2(x, bottom))
		var c := _hill_color(song, k, k == now_hill, pulse)
		draw_colored_polygon(pts, c)
		draw_polyline(top, c.lightened(0.35), 3.0, true)
		x = seg_end

	# The playhead: where the music is right now.
	if game.state == game.State.RUN:
		var px := float(game.song_time) * song.px_per_second
		var ground := -song.height_at(px)
		var a := 0.45 + 0.5 * pulse
		draw_line(Vector2(px, ground - 900.0), Vector2(px, ground), Color(0.6, 1.0, 0.95, a * 0.5), 6.0)
		draw_line(Vector2(px, ground - 900.0), Vector2(px, ground), Color(0.85, 1.0, 1.0, a), 2.0)
		draw_circle(Vector2(px, ground), 7.0 + 5.0 * pulse, Color(0.85, 1.0, 1.0, a))


func _hill_color(song: Song, k: int, current: bool, pulse: float) -> Color:
	if k < 0:
		return Color(0.18, 0.14, 0.28)
	var n := inverse_lerp(song.min_height * song.height_scale,
			maxf(song.max_height * song.height_scale, 1.0), song.heights[k])
	# Cool violet for quiet, hot magenta-orange for loud.
	var c := Color.from_hsv(lerpf(0.72, 0.98, n), lerpf(0.45, 0.75, n), lerpf(0.30, 0.55, n))
	if current:
		c = c.lightened(0.12 + 0.18 * pulse)
	return c
