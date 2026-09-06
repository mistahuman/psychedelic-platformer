extends Area2D

## The two ends of the corridor. The beacon turns the run around; the goal only
## accepts you on the way back. Together they are the reason you have to walk
## through the level a second time — which is the only way the mechanic is ever
## experienced.

enum Role { BEACON, GOAL }

@export var role := Role.BEACON
@export var color_idle := Color(0.35, 0.85, 0.75, 0.25)
@export var color_active := Color(0.35, 0.85, 0.75, 0.8)

var _reached := false


func _ready() -> void:
	Run.leg_changed.connect(_on_leg_changed)
	body_entered.connect(_on_body_entered)
	_refresh()


func _on_body_entered(body: Node2D) -> void:
	match role:
		Role.BEACON:
			# Doubles as the checkpoint: falling on the way back should not send
			# you all the way to the start, and the far ledge is the safe point.
			if body.has_method(&"set_respawn_point"):
				body.set_respawn_point(global_position)
			Run.reach_beacon()
		Role.GOAL:
			Run.reach_goal()


func _on_leg_changed(_leg: Run.Leg) -> void:
	_refresh()


func _refresh() -> void:
	match role:
		Role.BEACON:
			_reached = Run.leg != Run.Leg.OUTBOUND
		Role.GOAL:
			# Dark until it can actually be used, so the outbound leg has one
			# unambiguous direction and no one wanders back early.
			_reached = Run.leg == Run.Leg.DONE
	var rect := get_node_or_null(^"ColorRect") as ColorRect
	if rect == null:
		return
	if role == Role.GOAL and Run.leg == Run.Leg.OUTBOUND:
		rect.color = Color(color_idle.r, color_idle.g, color_idle.b, 0.08)
	else:
		rect.color = color_active if _reached else color_idle
