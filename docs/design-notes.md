# Design notes

Decision log. One section per prototype: the question it answers, the technical
choices and why, what is still open.

---

## Prototype 01 — Breathing platforms

**Question:** is jumping on vertically oscillating platforms fun (rhythm,
timing, "breathing") or frustrating (imprecision, eaten jumps, falls that don't
feel like your fault)?

### Oscillation

```
position = base + amplitude * sin(TAU * frequency * t + phase_offset)
```

- **`base` is the node's editor position**, read once in `_ready()`. Move the
  platform in the editor and the oscillation follows. No hardcoded coordinates.
- **Frequency in Hz, not rad/s** (the script multiplies by `TAU`). "0.3" reads
  as "one cycle every ~3 seconds", which is the unit you think in while
  balancing rhythm. "1.88 rad/s" is not.
- **`t` is a local accumulator** (`_time += delta`), not
  `Time.get_ticks_msec()`. Each platform owns its clock, so one can be paused,
  reset or slowed down without touching the others — useful for the planned
  variants.
- **Updated in `_physics_process`, not `_process`.** A physics body must move in
  step with the physics server, otherwise the character standing on it sees a
  position different from the one it collides against, and jitters.
- **All four platforms differ in frequency, amplitude and phase**
  (0.33 / 0.22 / 0.45 / 0.58 Hz), with frequencies that are not integer
  multiples of each other, so the combined pattern does not repeat quickly.
  That's the point: we want to see whether it reads as "alive" or as "unfair".

### Carrying the player

Three possible approaches:

1. **Reparent** the player to the platform on landing. Works, but pollutes the
   node tree, breaks global transforms, and has to be undone by hand.
2. **Manually copy the platform's delta** into the player. Works until there are
   two platforms, or a rotating one, or a frame where contact is lost.
3. **Let the engine do it** — what we picked.

The canonical Godot 4 way:

- The platform is an **`AnimatableBody2D`** (not `StaticBody2D`: it wouldn't
  move as far as physics is concerned; not `CharacterBody2D`: that's for
  controlled bodies that collide themselves). `AnimatableBody2D` exists exactly
  for script-driven bodies that must carry or push other bodies.
- With **`sync_to_physics = true`** the engine derives the body's velocity by
  comparing positions between physics steps.
- The player is a `CharacterBody2D`: **`move_and_slide()` adds the velocity of
  the platform it stands on** (`get_platform_velocity()`). Not a single line in
  the player script mentions platforms. Switching a platform to
  `horizontal = true` already works.

Two details separating "stands on it" from "stands on it well":

- **`floor_snap_length = 16.0`** on the player. When a platform moves down the
  floor briefly escapes from under the feet; without snapping the character
  enters free fall and bounces every frame. 16 px is generous: the platforms'
  peak vertical speed here is ~170 px/s, i.e. ~2.8 px per frame at 60 fps.
- **`velocity.y = 0` while `is_on_floor()`**, so gravity doesn't accumulate
  frame after frame and force the snap to fight it.

`platform_on_leave` is left at its default (`ADD_VELOCITY`): jumping off a
rising platform carries its push. That's a feel choice, not a technical
requirement — if playtesting shows it's unpredictable, switch it to
`ADD_UPWARD_VELOCITY` or `DO_NOTHING` in the player's inspector.

### Jump feel

Deliberately classic: no double jump, no power-ups. Two concessions only, both
exported and **zeroable for an A/B comparison during playtesting**:

- **coyote time (0.10 s)** — close to mandatory with descending platforms:
  without it, every frame where the platform slips out from under you eats the
  jump, and it feels like the game's fault.
- **jump buffer (0.10 s)** — a jump pressed just before landing stays queued.

Plus asymmetric gravity (falling 1.4x the rise) and jump cut on key release: a
more readable arc when aiming at a moving target.

### Respawn

As dumb as possible, per spec: below `fall_threshold_y` (780) the character
reappears at the last safe point. No screens, no level reset — the platforms
keep oscillating, so you don't lose your place in their cycle. `R` forces a
respawn for fast iteration.

The respawn point starts at the initial position and is updated by a checkpoint
`Area2D` (one only, on the landing ledge). Adding more is a matter of
duplicating the node.

### Input

Actions (`move_left`, `move_right`, `jump`, `respawn`) are registered at runtime
by an autoload (`scripts/controls.gd`) rather than in `project.godot`'s InputMap.
Reason: in a prototype, bindings in a readable, diffable text file beat the
serialized blob. The script only registers an action if it doesn't already
exist, so it steps aside the day we move them into the editor.

### To evaluate in playtesting

- Is amplitude 85 px on PlatformB too much? The jump peaks at ~108 px.
- The nastiest jump is C -> D: in the worst phase alignment that's ~195 px of
  height difference, meaning **you have to wait**. Rhythm, or dead time?
- Do the desynced frequencies read as "alive" or as "random"?
- Coyote time at 0: how much worse does it actually get?

### Still undecided

- Camera (a single fixed screen for now, everything visible).
- What happens when two platforms cross each other.
- Whether the oscillation should react to the player (breathing that speeds up)
  — a candidate for prototype 02/03.
