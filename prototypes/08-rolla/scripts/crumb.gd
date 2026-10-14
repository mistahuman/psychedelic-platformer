extends RigidBody3D

## A crumb out of the grinder. Not grabbable: it gets onto the sheet by being
## shaken over it, and is gone for good if it falls off the table. A box, not
## a sphere: spheres roll off the sheet at the slightest tilt.


func _physics_process(_delta: float) -> void:
	if global_position.y < -0.6:
		queue_free()
