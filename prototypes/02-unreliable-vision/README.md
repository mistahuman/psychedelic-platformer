# 02 — Unreliable vision

**Question:** when the rendering lies about where the geometry is, is that a
mechanic you can learn to play against — or is it just noise that makes the game
feel broken?

Prototype 01 moved the *level*. This one leaves the level bolted down and moves
its *image*. The collision shapes never budge; the rectangles you see drift away
from them, and the longer you keep moving the further they drift. **Stand still
on the ground and the world snaps back to the truth.**

That's the loop being tested: rush and the world lies to you, pause and it
stops. Cost of information is time.

## Playing it

Open **this folder** as a Godot 4 project, then F5.

| Key | Action |
|---|---|
| `A` / `D` or `←` / `→` | run |
| `Space` (or `W` / `↑`) | jump |
| `R` | respawn (also resets the lie to 0) |

Goal: cross the four platforms to the teal checkpoint on the right.

## Debug keys (in-game, no editor needed)

| Key | Action |
|---|---|
| `F1` | show/hide the overlay |
| `F2` | full-screen haze shader on/off — **off by default** |
| `F3` | drift on/off — the A/B test |
| `[` `]` | drift amount down / up |
| `,` `.` | how fast the lie builds up |

The haze (screen warp + chromatic aberration) is off by default because under
WSLg you're on software rendering — if it drops the framerate, leave it off. The
mechanic doesn't depend on it.

## What to watch during the test

- **F3 back and forth** while playing. With drift off it's a trivial platformer;
  with drift on, is the difference *interesting* or just *annoying*?
- Do you actually start standing still to read the level, or do you just brute
  force it? If you never use the calm mechanic, the mechanic doesn't exist.
- Does missing a jump feel like being tricked (good) or cheated (bad)?
- `]` a few times until it's absurd: where's the line between disorienting and
  unplayable?

## Files

```
scripts/perception.gd         autoload: how much the rendering may lie, 0..1
scripts/drifting_platform.gd  static collision, drifting ColorRect
scripts/player.gd             carried over from 01, feeds Perception.calm
scripts/debug_overlay.gd      in-game tuning
shaders/haze.gdshader         optional full-screen warp
```
