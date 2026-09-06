extends Label

## In-game tuning, so there's no need for the editor's Remote inspector.

@export var haze: CanvasItem

var _drift_scale := 1.0
var _base_drift: Dictionary = {}


func _ready() -> void:
	for platform in get_tree().get_nodes_in_group(&"drifting_platform"):
		_base_drift[platform] = platform.max_drift


func _process(_delta: float) -> void:
	text = "\n".join([
		"lie level   %.2f   %s" % [Perception.level, "CALM" if Perception.calm else "MOVING"],
		"drift       %s  x%.2f" % ["on" if Perception.drift_enabled else "OFF", _drift_scale],
		"haze        %s" % ["on" if haze and haze.visible else "off"],
		"rise/decay  %.2f / %.2f" % [Perception.rise_rate, Perception.decay_rate],
		"",
		"F1 overlay   F2 haze   F3 drift on/off",
		"[ ] drift amount   , . rise rate   R respawn",
	])


func _unhandled_input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match (event as InputEventKey).physical_keycode:
		KEY_F1:
			modulate.a = 0.0 if modulate.a > 0.5 else 1.0
		KEY_F2:
			if haze:
				haze.visible = not haze.visible
		KEY_F3:
			Perception.drift_enabled = not Perception.drift_enabled
		KEY_BRACKETLEFT:
			_set_drift_scale(_drift_scale * 0.8)
		KEY_BRACKETRIGHT:
			_set_drift_scale(_drift_scale * 1.25)
		KEY_COMMA:
			Perception.rise_rate = maxf(Perception.rise_rate - 0.05, 0.0)
		KEY_PERIOD:
			Perception.rise_rate += 0.05


func _set_drift_scale(value: float) -> void:
	_drift_scale = clampf(value, 0.0, 8.0)
	for platform in _base_drift:
		platform.max_drift = _base_drift[platform] * _drift_scale
