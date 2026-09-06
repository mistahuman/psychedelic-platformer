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

### Playtest verdict — 2026-09-06

Tested on Godot 4.7.2 (Linux/WSLg, software rendering).

**The feel is fine.** Better than expected for a first prototype: not
frustrating, the jump reads, landing on a moving target works. So the original
question — fun or frustrating? — is answered, and it isn't the blocker.

**But the mechanic is a dead end.** Moving blocks are a done-to-death
platformer staple, and this isn't the direction the game is looking for. The
oscillation reads as "a platform that moves", not as anything the working title
promises. No amount of tuning amplitude, frequency or phase changes that: the
problem is the concept, not the numbers.

Consequence: **do not iterate on this prototype.** The specific open questions
(PlatformB's amplitude, the C -> D wait, coyote time at 0) are moot — they'd be
tuning something we're not going to build.

### What carries over

The mechanic is dead, the plumbing is not. Reusable as-is in the next
prototypes:

- `scripts/player.gd` — the character, with tuning that already feels right.
- The `AnimatableBody2D` + `sync_to_physics` approach, for anything that has to
  carry the player.
- Threshold respawn + checkpoint area.

### Open for prototype 02

The thing to attack is that oscillation was applied to the **level geometry**.
Candidates that move it elsewhere:

- Move it to **perception**: geometry stays mechanically honest, the rendering
  of it breathes. Visual instability, stable collisions.
- Move it to **existence**: platforms don't travel, they phase in and out on a
  cycle. Rhythm without movement.
- Move it to **the player**: gravity, scale or control response breathes rather
  than the world.

Undecided regardless of direction: camera (a single fixed screen for now).

---

## Prototype 02 — Unreliable vision

**Question:** when the rendering lies about where the geometry is, is that a
mechanic you can learn to play against, or just noise that makes the game feel
broken?

Direct answer to 01's verdict: the oscillation moves from the level geometry to
the *image* of the level geometry.

### The mechanic

- Platforms are `StaticBody2D`. **The collision shapes never move.**
- Each platform's `ColorRect` is offset from the real position by a per-platform
  two-axis sine, scaled by a global `Perception.level` (0..1).
- `Perception.level` rises while the player moves or is airborne, and falls
  roughly 2.7x faster while the player stands still on the ground.

So: moving costs you information, standing still buys it back. The player can
always get the truth — at the price of time. That's the loop worth testing;
without the calm mechanic this would just be a screen effect.

### Why visual offset rather than a screen-space shader

The shader route (warp the whole frame) is the obvious reading of
"psychedelic", but it's the weaker test:

- It lies about *everything* uniformly, so there's nothing specific to learn.
- Full-screen fragment work is expensive on the target setup (WSLg, no GPU
  passthrough, llvmpipe software rendering), and a stuttering prototype poisons
  a feel test for reasons that have nothing to do with design.

Offsetting the visuals costs nothing, and lies about exactly one thing — where
a platform is — which is the thing the player has to reason about. The
full-screen shader (`shaders/haze.gdshader`, warp + chromatic aberration, three
texture samples) is there as flavor on top, **off by default**, toggled with F2.

`BackBufferCopy` in `copy_mode = 2` sits before the haze `ColorRect` so
`hint_screen_texture` is populated regardless of renderer.

### In-game debug overlay

Prototype 01's tuning plan relied on the editor's Remote inspector, which turned
out to be awkward in practice: under WSLg the game and the editor are separate X
windows, keyboard focus has to be switched by hand, and the tab is easy to miss.
Replaced with an in-game overlay and function keys (`scripts/debug_overlay.gd`).
**Convention from here on: prototypes tune themselves, no editor round-trip.**

### Carried over from 01

`player.gd` unchanged except for one line feeding `Perception.calm`. The
character controller is settled; it is not what these prototypes are testing.

### To evaluate in playtesting

- F3 (drift on/off) mid-run: is the difference interesting, or just annoying?
- Does the player actually stop to read the level? If the calm mechanic goes
  unused, it doesn't exist and the whole design collapses to a screen effect.
- Does a missed jump feel like being tricked (good) or cheated (bad)?
- Where is the line, on `]`, between disorienting and unplayable?

### Open

- Does the lie need to be *learnable* (a fixed pattern per platform, which it
  currently is) or would randomness be better? Current bet: learnable.
- Should the player's own body drift too? Current bet: no — losing trust in your
  own position is the fastest way to make a platformer unplayable.
