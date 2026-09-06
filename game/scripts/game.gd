extends Node

## Beginning, middle, end. This is what every prototype was missing: they
## dropped you into a sandbox with a help label and never told you what had
## happened, so the mechanic read as confusion rather than as a rule.

signal state_changed(state: State)

enum State { TITLE, PLAYING, ESCAPED, BURNT_OUT }

## Seconds of wick at a full lantern. Long enough to get lost once.
const WICK_SECONDS := 80.0
## What one flask of oil gives back.
const OIL_SECONDS := 22.0

@export var maze_path: NodePath
@export var player_path: NodePath

var state := State.TITLE
var seconds_left := WICK_SECONDS
var elapsed := 0.0
var oil_taken := 0

var _maze: Node2D
var _player: Node2D


func _ready() -> void:
	_maze = get_node_or_null(maze_path) as Node2D
	_player = get_node_or_null(player_path) as Node2D
	if _maze:
		_maze.reached_exit.connect(_on_escaped)
		_maze.found_oil.connect(_on_oil)
	_enter(State.TITLE)


func _process(delta: float) -> void:
	if state != State.PLAYING:
		return
	elapsed += delta
	seconds_left -= delta
	if _maze:
		_maze.wick = clampf(seconds_left / WICK_SECONDS, 0.0, 1.0)
	if seconds_left <= 0.0:
		seconds_left = 0.0
		_enter(State.BURNT_OUT)


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match state:
		State.TITLE:
			start()
		State.ESCAPED, State.BURNT_OUT:
			if (event as InputEventKey).physical_keycode in [KEY_R, KEY_SPACE, KEY_ENTER]:
				start()
	_tuning(event as InputEventKey)


## Two keys kept for tuning by hand, because how often the maze should catch you
## out is a feel question that no harness can settle. Not shown on the title.
func _tuning(key: InputEventKey) -> void:
	if _maze == null:
		return
	match key.physical_keycode:
		KEY_F3:
			_maze.mutation_enabled = not _maze.mutation_enabled
		KEY_BRACKETLEFT:
			_maze.mutation_rate = maxf(_maze.mutation_rate - 0.15, 0.0)
		KEY_BRACKETRIGHT:
			_maze.mutation_rate += 0.15


func start() -> void:
	seconds_left = WICK_SECONDS
	elapsed = 0.0
	oil_taken = 0
	if _maze:
		_maze.rebuild()
		_maze.running = true
	_enter(State.PLAYING)


func wick_ratio() -> float:
	return clampf(seconds_left / WICK_SECONDS, 0.0, 1.0)


func _on_escaped() -> void:
	_enter(State.ESCAPED)


func _on_oil(_remaining: int) -> void:
	oil_taken += 1
	# Capped at the starting wick: oil buys you back time, it does not let you
	# hoard a lantern brighter than the one you began with.
	seconds_left = minf(seconds_left + OIL_SECONDS, WICK_SECONDS)


func _enter(next: State) -> void:
	state = next
	if _maze:
		_maze.running = state == State.PLAYING
	if _player:
		_player.frozen = state != State.PLAYING
	state_changed.emit(state)
