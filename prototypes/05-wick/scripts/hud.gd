extends CanvasLayer

## The screens. A title that states the rule, a wick bar that states the stakes,
## and an ending that says what just happened to you in numbers.

@export var game_path: NodePath
@export var maze_path: NodePath

@onready var _title: Control = $Title
@onready var _ending: Control = $Ending
@onready var _title_text: Label = $Title/Text
@onready var _ending_title: Label = $Ending/Heading
@onready var _ending_text: Label = $Ending/Text
@onready var _wick_fill: ColorRect = $Wick/Fill
@onready var _fooled: Label = $Fooled

var _game: Node
var _maze: Node2D
var _fooled_flash := 0.0

const WICK_WIDTH := 320.0


func _ready() -> void:
	_game = get_node_or_null(game_path)
	_maze = get_node_or_null(maze_path) as Node2D
	if _game:
		_game.state_changed.connect(_on_state)
	if _maze:
		_maze.was_fooled.connect(_on_fooled)
	_title_text.text = "\n".join([
		"You are somewhere with a lantern and no map.",
		"The door is in the far corner — you can see it glowing.",
		"",
		"What the lantern reaches is true.",
		"Everything else on screen is only what you remember,",
		"and the place does not hold still when you look away.",
		"",
		"WASD or arrows to walk.        Any key to begin.",
	])
	_on_state(0)


func _process(delta: float) -> void:
	_fooled_flash = maxf(_fooled_flash - delta * 1.6, 0.0)
	if _game == null:
		return
	var ratio: float = _game.wick_ratio()
	_wick_fill.size.x = WICK_WIDTH * ratio
	# The bar goes from warm to red as it runs out; the colour is the warning,
	# not a number the player has to read.
	_wick_fill.color = Color(1.0, 0.78, 0.32).lerp(Color(0.95, 0.30, 0.32), 1.0 - ratio)
	_fooled.modulate.a = _fooled_flash
	if _maze:
		_fooled.text = "the maze moved   %d" % _maze.fooled


func _on_fooled(_total: int) -> void:
	_fooled_flash = 1.0


func _on_state(_state: int) -> void:
	if _game == null:
		return
	_title.visible = _game.state == _game.State.TITLE
	_ending.visible = _game.state in [_game.State.ESCAPED, _game.State.BURNT_OUT]
	$Wick.visible = _game.state == _game.State.PLAYING
	if not _ending.visible or _maze == null:
		return
	if _game.state == _game.State.ESCAPED:
		_ending_title.text = "You got out."
	else:
		_ending_title.text = "The wick went out."
	_ending_text.text = "\n".join([
		"time            %.0f seconds" % _game.elapsed,
		"the maze moved  %s behind you" % _times(_maze.changes),
		"it fooled you   %s" % _times(_maze.fooled),
		"you saw         %d%% of it" % int(_maze.explored_ratio() * 100.0),
		"oil found       %d of 3" % _game.oil_taken,
		"",
		"R to go back in.",
	])


func _times(n: int) -> String:
	return "once" if n == 1 else "%d times" % n
