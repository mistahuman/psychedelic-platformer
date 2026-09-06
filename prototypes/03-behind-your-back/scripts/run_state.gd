extends Node

## The two legs of a run. The whole prototype is built on crossing the same
## corridor twice: once to learn it, once to find out it did not stay learnt.
##
## The timings are the measurement. If the return leg is much slower AND that
## felt tense, the mechanic works. If it is much slower and felt like a chore,
## it does not. That is the verdict this prototype has to produce.

enum Leg { OUTBOUND, RETURN, DONE }

signal leg_changed(leg: Leg)

var leg := Leg.OUTBOUND
var outbound_time := 0.0
var return_time := 0.0


func _process(delta: float) -> void:
	match leg:
		Leg.OUTBOUND:
			outbound_time += delta
		Leg.RETURN:
			return_time += delta


func reach_beacon() -> void:
	if leg != Leg.OUTBOUND:
		return
	leg = Leg.RETURN
	leg_changed.emit(leg)


func reach_goal() -> void:
	if leg != Leg.RETURN:
		return
	leg = Leg.DONE
	leg_changed.emit(leg)


func reset() -> void:
	leg = Leg.OUTBOUND
	outbound_time = 0.0
	return_time = 0.0
	leg_changed.emit(leg)
