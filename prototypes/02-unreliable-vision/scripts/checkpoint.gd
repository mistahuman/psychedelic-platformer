extends Area2D

## Entering this area makes its position the player's new respawn point.

@export var color_idle := Color(0.35, 0.85, 0.75, 0.35)
@export var color_active := Color(0.35, 0.85, 0.75, 0.8)

var _active := false


func _ready() -> void:
	_refresh()
	body_entered.connect(_on_body_entered)


func _on_body_entered(body: Node2D) -> void:
	if not body.has_method(&"set_respawn_point"):
		return
	body.set_respawn_point(global_position)
	if not _active:
		_active = true
		_refresh()


func _refresh() -> void:
	var rect := get_node_or_null(^"ColorRect") as ColorRect
	if rect:
		rect.color = color_active if _active else color_idle
