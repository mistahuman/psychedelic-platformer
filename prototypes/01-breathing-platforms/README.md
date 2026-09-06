# 01 — Breathing platforms

**Question:** is jumping on vertically oscillating platforms fun (rhythm,
timing) or frustrating (eaten jumps, falls that don't feel like your fault)?

> **Answered — closed, not iterated on.** The feel is fine, but moving blocks
> are a done-to-death staple and not the direction we want. Kept as reference
> for the character controller and the moving-platform plumbing. See the
> playtest verdict in [`../../docs/design-notes.md`](../../docs/design-notes.md).

## Playing it

Open **this folder** as a Godot 4 project (Import → select
`prototypes/01-breathing-platforms/`), then F5.

| Key | Action |
|---|---|
| `A` / `D` or `←` / `→` | run |
| `Space` (or `W` / `↑`) | jump — held = higher jump |
| `R` | immediate respawn |

Goal: from the left ledge, cross the 4 colored platforms to the landing ledge on
the right (the teal rectangle is the checkpoint). Falling off the bottom returns
you to the last safe point — the platforms do **not** reset, they keep cycling.

## What to watch during the test

- The **C → D** jump (green → orange) is the nastiest: depending on phase it may
  require waiting. Rhythm, or dead time?
- **B**'s amplitude (blue, 85 px) is right at the edge of the jump height.
- Standing still on a descending platform: does the character stay glued, or
  vibrate?

## Knobs

Everything is an `@export`, tunable from the inspector **while the game runs**
(Remote → node → Inspector).

On the `Player` node: `max_speed`, `jump_velocity`, `gravity`,
`fall_gravity_multiplier`, `jump_cut_multiplier`, `coyote_time`,
`jump_buffer_time`.

> Try setting `coyote_time` to **0**: it's the most informative A/B test in this
> prototype.

On each `Platform*`: `amplitude`, `frequency` (Hz), `phase_offset`, `horizontal`,
`size`, `color`.

## Files

```
project.godot                       autoload + gravity + viewport
scenes/main.tscn                    the single playable scene
scenes/player.tscn                  CharacterBody2D + ColorRect
scenes/breathing_platform.tscn      AnimatableBody2D + ColorRect
scripts/player.gd                   movement, jump, respawn
scripts/breathing_platform.gd       the sine wave
scripts/checkpoint.gd               Area2D updating the respawn point
scripts/controls.gd                 autoload: key bindings
```

The technical rationale (why `AnimatableBody2D`, why `floor_snap_length`) is in
[`../../docs/design-notes.md`](../../docs/design-notes.md).
