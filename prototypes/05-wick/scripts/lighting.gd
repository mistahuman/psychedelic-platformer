extends ColorRect

## Owns the lantern layer: builds the per-cell visibility texture each frame and
## hands it to shaders/lantern.gdshader, which does the smoothing.

@export var maze_path: NodePath
@export var game_path: NodePath

var _maze: Node2D
var _game: Node
var _image: Image
var _texture: ImageTexture
var _time := 0.0
var _flicker := 1.0


func _ready() -> void:
	_maze = get_node_or_null(maze_path) as Node2D
	_game = get_node_or_null(game_path)
	if _maze == null:
		return
	# Two channels: how lit a cell is, and whether it has ever been seen.
	_image = Image.create(_maze.COLS, _maze.ROWS, false, Image.FORMAT_RGF)
	_texture = ImageTexture.create_from_image(_image)
	(material as ShaderMaterial).set_shader_parameter("light_map", _texture)


func _process(delta: float) -> void:
	if _maze == null or _image == null:
		return
	_time += delta
	for y in _maze.ROWS:
		for x in _maze.COLS:
			var i: int = _maze.index(x, y)
			var value: float = _maze.light[i]
			var seen := 0.0 if _maze.memory[i] == _maze.UNKNOWN else 1.0
			_image.set_pixel(x, y, Color(value, seen, 0.0))
	_texture.update(_image)

	# A flame is never steady, and it gets less steady as the wick runs down —
	# so the unease arrives through the light itself rather than through the bar.
	var wick := 1.0
	if _game:
		wick = _game.wick_ratio()
	var unrest := lerpf(0.035, 0.16, 1.0 - wick)
	var target := 1.0 - unrest * (0.5 + 0.5 * sin(_time * 11.0 + sin(_time * 4.3) * 2.0))
	_flicker = lerpf(_flicker, target, 0.35)

	var shader := material as ShaderMaterial
	shader.set_shader_parameter("flicker", _flicker)
	shader.set_shader_parameter("time_seed", _time)
