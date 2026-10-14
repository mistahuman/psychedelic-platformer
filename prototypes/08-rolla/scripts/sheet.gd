extends "res://scripts/item.gd"

## The sheet, from flat to lit. Crumbs and the filter lying on it are taken in
## whenever a hand takes hold of it. Then moving both hands forward and
## back together rolls it; out of step it gets less neat and leaks crumbs;
## pulling the hands apart tears it. Rolled, it must be sealed at the mouth
## before it comes undone, and only a sealed one lights.

signal spilled(at: Vector3, count: int)
signal torn(sheet: RigidBody3D)
signal undone(sheet: RigidBody3D)

const LENGTH := 0.24
const WIDTH := 0.07
const MOVING := 0.03  # m/s of target speed that counts as a hand moving

var progress := 0.0    ## 0 flat, 1 rolled
var twist := 0.0       ## metres of out-of-step movement so far
var crumbs := 0        ## taken in
var has_filter := false
var filter_end := 1.0  ## which end the filter is on, along local x
var sealed := false
var lit := false
var undone_in := 0.0   ## seconds until a rolled, unsealed one comes undone

var _apart := 0.0      # distance between the hands' targets when both took hold
var _prev_targets: Array[Vector3] = []
var _stroke := 0.0
var _stroke_dir := 0.0
var _leaked := 0.0
var _flat_shape: Shape3D
var _tube_shape := CylinderShape3D.new()

@onready var _shape: CollisionShape3D = $Shape
@onready var _flat: MeshInstance3D = $Flat
@onready var _tube: MeshInstance3D = $Tube
@onready var _fill: MeshInstance3D = $Fill
@onready var _filter: MeshInstance3D = $FilterEnd
@onready var _ember: MeshInstance3D = $Ember
@onready var _smoke: CPUParticles3D = $Smoke


func _ready() -> void:
	super()
	_flat_shape = _shape.shape
	_tube_shape.radius = 0.009
	_tube_shape.height = LENGTH


func rolled() -> bool:
	return progress >= 1.0


func neatness() -> float:
	return clampf(1.0 - twist / TUNING.twist_max, 0.0, 1.0)


## Crumbs taken in plus crumbs lying on it right now, for the HUD.
func crumbs_showing() -> int:
	var count := crumbs
	if not rolled():
		for crumb in get_tree().get_nodes_in_group("crumb"):
			if _on_me(crumb.global_position):
				count += 1
	return count


func tip_position() -> Vector3:
	return to_global(Vector3(-filter_end * LENGTH / 2.0, 0.0, _tube_z()))


func middle_position() -> Vector3:
	return to_global(Vector3(0.0, 0.0, _tube_z()))


func light() -> void:
	lit = true
	_smoke.emitting = true


## Grabbing near either end must find the sheet, not the filter lying on it.
func grab_distance(point: Vector3) -> float:
	var local := to_local(point)
	return Vector2(maxf(absf(local.x) - LENGTH / 2.0, 0.0), maxf(absf(local.z) - WIDTH / 2.0, 0.0)).length()


func add_holder(hand: Node3D) -> void:
	# Take in what lies on it before the dip lifts it and things slide off:
	# picking it up is folding it around them.
	if not rolled():
		_take_in()
	super(hand)
	if holders.size() == 2:
		_apart = holders[0].target.distance_to(holders[1].target)
		_prev_targets = [holders[0].target, holders[1].target]


func _take_in() -> void:
	for crumb in get_tree().get_nodes_in_group("crumb"):
		if _on_me(crumb.global_position):
			crumbs += 1
			crumb.queue_free()
	for filter in get_tree().get_nodes_in_group("filter"):
		if has_filter or filter.is_held() or not _on_me(filter.global_position):
			continue
		var x := to_local(filter.global_position).x
		if absf(x) > LENGTH / 2.0 - 0.05:
			has_filter = true
			filter_end = signf(x)
			filter.queue_free()


func _on_me(point: Vector3) -> bool:
	var local := to_local(point)
	# Generous by a couple of centimetres: the dip of the hand that takes hold
	# nudges the sheet, and what was on the edge a moment ago still counts.
	return absf(local.x) < LENGTH / 2.0 + 0.02 and absf(local.z) < WIDTH / 2.0 + 0.02 \
			and local.y > -0.02 and local.y < 0.06


func _physics_process(delta: float) -> void:
	super(delta)
	if holders.size() == 2 and not sealed:
		_roll(delta)
	if rolled() and not sealed and not lit:
		undone_in -= delta
		if undone_in <= 0.0:
			progress = TUNING.undone_to
			undone.emit(self)
	_show()


func _roll(delta: float) -> void:
	# Read the player's input through the targets, not the bodies: the bodies
	# are welded to the same sheet and cannot disagree much.
	var a: Vector3 = (holders[0].target - _prev_targets[0]) / delta
	var b: Vector3 = (holders[1].target - _prev_targets[1]) / delta
	_prev_targets = [holders[0].target, holders[1].target]

	if holders[0].target.distance_to(holders[1].target) > _apart + TUNING.tear_slack:
		_tear()
		return
	if rolled():
		return

	if absf(a.z) > MOVING or absf(b.z) > MOVING:
		twist += absf(a.z - b.z) * delta
		while twist - _leaked >= TUNING.leak_every and crumbs > 0:
			_leaked += TUNING.leak_every
			crumbs -= 1
			spilled.emit(middle_position(), 1)

	if absf(a.z) > MOVING and absf(b.z) > MOVING and signf(a.z) == signf(b.z):
		var together := (a.z + b.z) / 2.0
		if signf(together) != _stroke_dir:
			_stroke_dir = signf(together)
			_stroke = 0.0
		var gain := minf(absf(together) * delta, maxf(TUNING.stroke_cap - _stroke, 0.0))
		_stroke += gain
		progress = minf(progress + gain / TUNING.roll_distance, 1.0)
		if rolled():
			undone_in = TUNING.seal_time


func _tear() -> void:
	for hand in holders.duplicate():
		hand.let_go("tore")
	spilled.emit(global_position, crumbs)
	torn.emit(self)
	queue_free()


func _tube_z() -> float:
	return -WIDTH / 2.0 + WIDTH * progress


func _show() -> void:
	var z := _tube_z()
	_flat.visible = not rolled()
	_flat.scale.z = maxf(1.0 - progress, 0.001)
	_flat.position.z = z + WIDTH * (1.0 - progress) / 2.0
	_tube.visible = progress > 0.0
	_tube.position.z = z
	var thickness := lerpf(0.3, 1.0, progress)
	_tube.scale = Vector3(thickness, 1.0, thickness)
	_fill.visible = crumbs > 0 and progress < 0.5
	_fill.scale.x = minf(crumbs / 20.0, 1.0)
	_filter.visible = has_filter
	_filter.position = Vector3(filter_end * (LENGTH / 2.0 - 0.015), 0.0, z)
	_ember.visible = lit
	_ember.position = Vector3(-filter_end * LENGTH / 2.0, 0.0, z)
	_smoke.position = _ember.position

	var want_tube := rolled()
	if want_tube != (_shape.shape == _tube_shape):
		_shape.shape = _tube_shape if want_tube else _flat_shape
		_shape.transform = Transform3D(Basis.from_euler(Vector3(0, 0, PI / 2)), Vector3(0, 0, z)) \
				if want_tube else Transform3D.IDENTITY
