extends Node

## Owns the only thing this prototype cares about: what the camera can currently
## see. The world is allowed to change outside this rectangle and nowhere else.
##
## The rect comes from the camera, not from the player. With position smoothing
## the two disagree for a fraction of a second, and that fraction is exactly
## where a platform would visibly pop.

## How far outside the view a platform must be before it may change, in pixels.
## This is the safety margin against the camera swinging back: too small and the
## player catches the world lying, which breaks the whole contract.
var margin := 160.0

## The A/B switch. Off, this is a plain platformer on a flat row of platforms.
var mutation_enabled := true

## Chance that a platform actually re-rolls when it gets the opportunity.
## Below 1.0 some platforms stay put and act as landmarks — without them the
## return leg reads as a new random level rather than as the same level, changed.
var mutation_chance := 0.6

var view_rect := Rect2()
var mutations := 0


func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_2d()
	if camera == null:
		view_rect = Rect2()
		return
	# get_visible_rect() on the viewport, not get_viewport_rect() on the camera:
	# the latter is a CanvasItem helper and reported a square rect here.
	var extent := get_viewport().get_visible_rect().size / camera.zoom
	view_rect = Rect2(camera.get_screen_center_position() - extent * 0.5, extent)


## True while any part of the rect is on screen, or within the safety margin.
func can_see(rect: Rect2) -> bool:
	if view_rect.size == Vector2.ZERO:
		return true
	return view_rect.grow(margin).intersects(rect)


func reset() -> void:
	mutations = 0
