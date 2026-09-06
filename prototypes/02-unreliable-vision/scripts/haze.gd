extends ColorRect

## Off by default: on software rendering a full-screen shader can cost more
## than it's worth. F2 toggles it.


func _process(_delta: float) -> void:
	var mat := material as ShaderMaterial
	if mat:
		mat.set_shader_parameter(&"intensity", Perception.level)
