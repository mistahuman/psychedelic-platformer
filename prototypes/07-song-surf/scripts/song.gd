class_name Song
extends RefCounted

## A song as terrain. Everything here is a pure function of x (or of song time,
## which is x / px_per_second): the ground is never stored as geometry, so there
## is nothing to stream, cache or keep in step with the music.
##
## The shape:
##   - valleys fall on the beat grid, every `beats_per_hill` beats, picked so a
##     hill is a comfortable width at the surfing speed. When you are in sync
##     with the song, you hit the bottom of every valley on the kick.
##   - each hill's height comes from how loud that stretch of the song is, so a
##     quiet verse is a gentle roll and the chorus is a mountain range.
##   - between valleys the profile is a raised cosine, so slope is continuous
##     everywhere — no kinks for the physics to snag on.

const LEAD_IN := 1.5  # seconds of flat ground before the first valley

var title := ""
var audio_path := ""
var duration := 0.0
var bpm := 0.0
var beats := PackedFloat64Array()
var envelope_hz := 10.0
var loudness := PackedFloat32Array()
var low := PackedFloat32Array()

var px_per_second := 520.0
var min_height := 50.0
var max_height := 300.0
var height_scale := 1.0
var beats_per_hill := 2
## Steepest slope any hill may have (rise over run). Loud stretches of a slow
## song made hills of up to 59° otherwise, and the speed all went into going
## up and down instead of along.
var max_slope := 0.9

## Valley times, and one height per hill between them.
var valleys := PackedFloat64Array()
var heights := PackedFloat32Array()


static func load_json(path: String) -> Song:
	var text := FileAccess.get_file_as_string(path)
	var data: Variant = JSON.parse_string(text)
	if not data is Dictionary:
		return null
	var s := Song.new()
	s.title = data.get("title", path.get_file())
	s.audio_path = path.get_base_dir().path_join(data.get("audio", ""))
	s.duration = data.get("duration", 0.0)
	s.bpm = data.get("bpm", 120.0)
	s.beats = PackedFloat64Array(data.get("beats", []))
	s.envelope_hz = data.get("envelope_hz", 10.0)
	s.loudness = PackedFloat32Array(data.get("loudness", []))
	s.low = PackedFloat32Array(data.get("low", []))
	return s


## Call after changing px_per_second or the height settings.
func build() -> void:
	var beat_s := 60.0 / maxf(bpm, 1.0)
	# The hill width closest to ~720 px at the current speed.
	var best := 1
	for n in [1, 2, 4, 8]:
		if absf(beat_s * n * px_per_second - 720.0) < absf(beat_s * best * px_per_second - 720.0):
			best = n
	beats_per_hill = best

	valleys = PackedFloat64Array()
	var i := 0
	while i < beats.size():
		if beats[i] >= LEAD_IN:
			valleys.append(beats[i])
		i += beats_per_hill if valleys.size() > 0 else 1
	# Mastered pop sits near the top of its range almost all the time, so stretch
	# this song's own quiet-to-loud span across the full range of hill heights.
	var ranked := Array(loudness)
	ranked.sort()
	var floor_l: float = ranked[int(ranked.size() * 0.10)] if ranked.size() > 0 else 0.0
	var ceil_l: float = ranked[int(ranked.size() * 0.97)] if ranked.size() > 0 else 1.0
	heights = PackedFloat32Array()
	for k in range(valleys.size() - 1):
		var loud := _mean(loudness, valleys[k], valleys[k + 1])
		var n := clampf(inverse_lerp(floor_l, maxf(ceil_l, floor_l + 0.01), loud), 0.0, 1.0)
		var h := lerpf(min_height, max_height, pow(n, 1.4)) * height_scale
		# The raised cosine's steepest slope is pi * height / width.
		var width := (valleys[k + 1] - valleys[k]) * px_per_second
		heights.append(minf(h, max_slope * width / PI))


## Height of the ground above the baseline at world x. Positive is up.
func height_at(x: float) -> float:
	var t := x / px_per_second
	var k := hill_index(t)
	if k < 0:
		return 0.0
	var u := (t - valleys[k]) / (valleys[k + 1] - valleys[k])
	return heights[k] * (1.0 - cos(TAU * u)) * 0.5


## d(height)/dx. Positive means the ground rises to the right.
func slope_at(x: float) -> float:
	var t := x / px_per_second
	var k := hill_index(t)
	if k < 0:
		return 0.0
	var span := valleys[k + 1] - valleys[k]
	var u := (t - valleys[k]) / span
	return heights[k] * PI * sin(TAU * u) / (span * px_per_second)


## Index of the hill containing song time t, or -1 on the flat parts.
func hill_index(t: float) -> int:
	if valleys.size() < 2 or t < valleys[0] or t >= valleys[valleys.size() - 1]:
		return -1
	var lo := 0
	var hi := valleys.size() - 1
	while hi - lo > 1:
		var mid := (lo + hi) / 2
		if valleys[mid] <= t:
			lo = mid
		else:
			hi = mid
	return lo


func loudness_at(t: float) -> float:
	return _sample(loudness, t)


func low_at(t: float) -> float:
	return _sample(low, t)


## 1.0 on a beat, decaying to 0 before the next one. For pulsing visuals.
func beat_pulse(t: float) -> float:
	var beat_s := 60.0 / maxf(bpm, 1.0)
	if beats.is_empty() or t < beats[0]:
		return 0.0
	var since := fmod(t - beats[0], beat_s)
	return exp(-since * 9.0)


func end_x() -> float:
	return duration * px_per_second


func _sample(arr: PackedFloat32Array, t: float) -> float:
	if arr.is_empty():
		return 0.0
	var f := clampf(t * envelope_hz, 0.0, arr.size() - 1.001)
	var i := int(f)
	return lerpf(arr[i], arr[i + 1], f - i)


func _mean(arr: PackedFloat32Array, t0: float, t1: float) -> float:
	var a := clampi(int(t0 * envelope_hz), 0, arr.size() - 1)
	var b := clampi(int(t1 * envelope_hz), a + 1, arr.size())
	var acc := 0.0
	for j in range(a, b):
		acc += arr[j]
	return acc / (b - a)
