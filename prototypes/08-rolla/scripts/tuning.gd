extends Resource

## Every feel parameter, in one place: the hands, the rolling, the lighter.
## The one instance is res://tuning.tres, shared by everything, so a change
## here (or a line added to that file, or a debug key) applies everywhere.

@export_group("Arm")
## How fast the point the hand is trying to reach moves, m/s.
@export var target_speed := 0.55
## Spring pulling the hand to its target. Higher = snappier, less lag.
@export var stiffness := 80.0
## Brake on the hand's speed. Low = it overshoots and swings; ~18 = no wobble.
@export var damping := 6.0
## Cap on the pull, m/s². Stops a far-away target from firing the hand like a gun.
@export var max_accel := 40.0
## Box the target is kept inside (table top is y = 0, the mouth is near z = 0.45).
@export var reach_min := Vector3(-0.65, 0.05, -0.40)
@export var reach_max := Vector3(0.65, 0.40, 0.48)

@export_group("Grab")
## How fast the hand dips onto the lit-up thing while the grip is held, m/s.
@export var dip_speed := 0.6
## How long a dip may last before the hand gives up and comes back up, s.
@export var dip_timeout := 0.8
## Newtons the fingers can carry. Jerk a heavy thing harder than this and it drops.
@export var hold_force := 9.0

@export_group("Shake")
## Always-on tremor, metres added to the target. The base noise of the hands.
@export var tremor := 0.003
## Shaking a held thing (papers, grinder, lighter) is steering its hand back
## and forth: this many changes of direction within shake_window seconds.
@export var shake_reversals := 4
@export var shake_window := 1.0
## Target speed, m/s, below which the hand counts as not being steered.
@export var shake_speed := 0.05

@export_group("Rolling")
## Metres of back-and-forth, both hands together, from flat sheet to rolled.
@export var roll_distance := 1.2
## Most of one stroke that counts: rolling is back AND forth, not a long push.
@export var stroke_cap := 0.12
## Out-of-step movement between the hands, in metres, that makes it 0% neat.
@export var twist_max := 1.0
## Every this much out-of-step movement, a crumb falls out.
@export var leak_every := 0.12
## How much further apart than when you took hold the hands may pull before it tears.
@export var tear_slack := 0.06
## Seconds a rolled one stays rolled without being sealed.
@export var seal_time := 12.0
## Where it falls back to when it comes undone.
@export var undone_to := 0.7
## Seconds at the mouth to seal it.
@export var lick_time := 0.8

@export_group("Lighter")
## Chance that one shake of the lighter gives a flame instead of a click.
@export var strike_chance := 0.35
## How long a flame lasts, s.
@export var flame_time := 2.5
## Seconds of flame on the tip to light it.
@export var light_time := 1.0
