# 06 — Grapple

**Question:** is hook, swing, let go fun on its own — does timing the release
feel like a skill you get better at, with one button?

Side view, back to the platformer controller. Pits between the platforms and
anchors in the air. Press in the air to catch the ringed anchor, hold to hang,
let go to fly. The swing is honest physics, so where you land is decided by
the moment you let go.

The course is short on purpose — about 15 seconds when it goes well — and has a
clock, so the thing to do after reaching the flag is to go again, faster.

## Playing it

Open **this folder** as a Godot 4 project, then F5. Or `make run P=06` from the
repo root.

| Key | Action |
| --- | --- |
| `A` `D` or arrows | run; **while hanging, pump the swing** |
| `Space` (or `W`, `↑`, left click) | jump on the ground |
| `Space` again in the air, **held** | hook the ringed anchor and hang |
| release `Space` | let go |
| `R` | restart the run |

Falling into the pit puts you back on the last platform you stood on, and
counts a fall. The clock keeps running.

## Reading the screen

| What you see | What it means |
| --- | --- |
| Gold ring + dashed line | the anchor a press would catch right now |
| Gold dot | anchor in range |
| Grey dot | anchor out of range |
| Red strip at the bottom | the pit |
| Teal flag | the end |

## Debug keys

Hidden at start so the first run is played rather than read. `F1` shows it.

| Key | Action |
| --- | --- |
| `F1` | show/hide the overlay |
| `,` `.` | hook range down / up |
| `[` `]` | pump strength down / up |
| `-` `=` | release boost down / up (1.00 is honest physics) |
| `9` `0` | air control down / up |
| `7` `8` | gravity down / up |

## What to watch during the test

- **The one question:** after three or four runs, are you letting go at a
  better moment than on the first? If the release never starts to feel like a
  skill, the prototype has answered no.
- Does the ring ever pick an anchor you did not want? If a miss feels like the
  game's fault, that is the targeting, not the swing — note where.
- Pumping (`A`/`D` while hanging) is needed for the higher platform in the
  middle. Did you discover it, or did you need the title screen to tell you?
- Is it too fast? A good release reaches 900–1000 px/s. `7` for lower gravity
  slows the whole thing down without changing its shape.
- `-` / `=`: does a little release boost feel better, or like cheating?

## Measuring

`tools/course_bot.gd` plays the course headless with a fixed policy and
reports how far it got. It is a ruler, not a player:

```bash
godot --headless --path . --fixed-fps 60 -s tools/course_bot.gd -- 0.8
```

The argument is the angle past vertical, in radians, at which it lets go.

## Files

```
scripts/course.gd          layout tables, clock, title and flag
scripts/player.gd          ground controller from 01–03 + the rope
scripts/controls.gd        bindings; jump and hook share one button
scripts/debug_overlay.gd   in-game tuning
tools/course_bot.gd        headless ruler
```

Why the rope is rigid, why one button, and what the bot found are in
[`../../docs/design-notes.md`](../../docs/design-notes.md).
