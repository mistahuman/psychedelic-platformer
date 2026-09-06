# 03 — Behind your back

**Question:** when the level rearranges itself only where you cannot see it, is
turning around tension — or just annoyance?

Prototype 01 moved the level while you watched. Prototype 02 moved the *picture*
of the level and lied to you. This one does neither: **what is on screen is
always true.** Collision and rendering agree, always. The level only ever changes
outside the camera, and only once per trip off screen.

So there is nothing to distrust while you are looking. The distrust is about
everywhere else.

## Playing it

Open **this folder** as a Godot 4 project, then F5.

| Key | Action |
| --- | --- |
| `A` / `D` or `←` / `→` | run |
| `Space` (or `W` / `↑`) | jump |
| `R` | respawn at the last checkpoint |

Run right along the corridor to the **teal beacon**, then come back to the
**amber goal** where you started. The goal is dark until the beacon is reached —
there is only ever one direction to go.

The corridor is about three screens wide, with a grey ledge halfway that never
changes and doubles as a checkpoint. The outbound leg is a plain platformer:
nothing has been off screen yet, so nothing has changed. The return leg is the
prototype.

## Debug keys

| Key | Action |
| --- | --- |
| `F1` | show/hide the overlay |
| `F2` | gaze edge (screen vignette) on/off |
| `F3` | **mutation on/off — the A/B test** |
| `[` `]` | safety margin down / up |
| `,` `.` | mutation chance down / up |
| `F5` | restart the run from the start |

`mutation chance` is how likely a platform is to actually re-roll when it gets
the chance. It is deliberately below 1.0: the platforms that stay put are
landmarks, and without them the return leg reads as a *different level* rather
than as *the same level, changed*. Push it to 1.0 and see whether that reading
falls apart.

`margin` is how far off screen a platform must be before it may change. Drop it
towards 0 and you will start catching the world in the act, which is the one
thing this prototype promises never happens.

## What to watch during the test

- **F3 on and off across the return leg.** With mutation off it is the same
  corridor twice, which is boring on purpose. Is "on" tense, or just tiring?
- Do you find yourself **walking backwards, keeping the level in view**? If you
  do, that is the mechanic working — and it is also the thing that would have to
  become a real verb in a full game.
- When you land somewhere unexpected, is it a **"huh, it moved"** or a
  **"what, again"**?
- The overlay times both legs. A slower return is expected; the question is
  whether it was slow because you were being careful (tension) or because you
  were waiting around (annoyance).
- Watch the timer at the mid ledge. It is the only fixed thing in the corridor:
  does arriving there feel like relief?

## Files

```
scripts/observer.gd           autoload: what the camera can see, and the margin
scripts/mutable_platform.gd   a platform that only moves off screen
scripts/run_state.gd          autoload: the two legs and their timings
scripts/waypoint.gd           the beacon and the goal
scripts/player.gd             carried unchanged from 01 and 02
scripts/checkpoint.gd         carried from 02, on the mid ledge
scripts/debug_overlay.gd      in-game tuning
shaders/gaze.gdshader         the screen edge, where the rules change
```

The reachability arithmetic behind the level layout, and why the mutation
happens on leaving rather than on entering, are in
[`../../docs/design-notes.md`](../../docs/design-notes.md).
