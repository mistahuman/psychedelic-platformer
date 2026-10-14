# 08 — Rolla

**Question:** is fighting two clumsy physical hands funny, or just annoying?

First person, seated at a table. Two hands that are never placed, only pulled:
each one chases a point you move, on a spring, so it lags, overshoots and
swings. With them you prepare one from scratch and light it — sheet, crumbs,
filter, roll, seal, light — and get a score. Nothing stops you doing it badly.

## Playing it

Open **this folder** as a Godot 4 project, then F5. Or `make run P=08` from the
repo root.

| | Left hand | Right hand |
| --- | --- | --- |
| move over the table | `W` `A` `S` `D` | arrows (or `I` `J` `K` `L`) |
| carry lower / higher | `Q` / `E` | `PgDn` / `PgUp` (or `U` / `O`) |
| grab | hold `Space` (or left `Shift`) | hold `Enter` (or `;`, right `Shift`) |

`R` starts over. `Tab` is the debug overlay.

**Grabbing is a claw machine.** Move a hand over a thing until it lights up,
then hold the grip: the hand dips, closes on it, and comes back up with it.
Keep holding to carry, let go to drop.

**Shaking** is wiggling a hand left-right fast while it holds something.

## The steps

The list in the top-left ticks them off and says what to do next.

1. **Sheet** — shake the papers. A sheet falls out.
2. **Crumbs** — shake the grinder over the sheet. They scatter; what lands on
   the sheet counts.
3. **Filter** — lay it on one end of the sheet.
4. **Roll** — grab the sheet with both hands, one per end, then move both
   forward and back together (`W`/`S` with `↑`/`↓`). Out of step it gets less
   neat and crumbs fall out. Pull the hands apart and it tears.
5. **Seal** — bring it to your mouth, the pink spot, before it comes undone.
6. **Light** — let go with one hand, take the lighter, shake it until it
   flames (it mostly clicks), and hold the flame on the tip.

Whatever is lying on the sheet when a hand picks it up is taken in. Score:
5 per crumb (up to 30), 50 for the filter, up to 100 for neatness, and a time
bonus that runs out at 4 minutes.

A gamepad is wired but **untested** — none was connected when this was built:
sticks move the hands, `L1`/`R1` held + stick changes height, `L2`/`R2` grab,
`Start` resets, `Select` is the overlay.

## Debug keys

Hidden at start. `Tab` shows each hand's height, the load on its fingers, what
is under it, what it holds and why it last let go, plus a marker on the point
each hand is being pulled to.

| Key | Action |
| --- | --- |
| `Tab` | show/hide the overlay |
| `1` `2` | stiffness down / up |
| `3` `4` | damping down / up |
| `5` `6` | hold force down / up |
| `7` `8` | tremor down / up |

## Tuning

Every feel parameter is an `@export` in `scripts/tuning.gd`, grouped (arm,
grab, shake, rolling, lighter), each with a comment. There is one shared
instance, `tuning.tres`: change a default in the script, or override it by
adding a line such as `damping = 10.0` under `[resource]` in `tuning.tres`.

The ones to try first:

- `damping` (6) — the wobble of the hands. 3 is drunk, 18 does not overshoot.
- `roll_distance` (1.2 m) — how many strokes a roll takes (about ten).
- `twist_max` (1.0 m) — how forgiving neatness is about the hands being out of step.
- `strike_chance` (0.35) — how often the lighter catches.

## What to watch during the test

- Is it clear what to do next, and what a grip will take?
- Rolling with two hands on one keyboard: a skill, or a chore?
- When something goes wrong, do you laugh or sigh?
- Which keys did you actually use.

## Measuring

Two headless rulers, not players:

```bash
# one item picked up and carried across the table
godot --headless --path . --fixed-fps 120 -s tools/grab_bot.gd -- grinder
# the whole loop, sheet to lit; "0.3" = stroke length, "sloppy" = right hand late
godot --headless --path . --fixed-fps 120 -s tools/roll_bot.gd -- 0.2 sloppy
```

`roll_bot.gd` with `shots=<dir>` (and a window: `--disable-vsync` instead of
`--headless`) saves a frame at every step. `tools/screenshot.gd` saves one
frame of the opening scene.

## Files

```
tuning.tres                the one shared set of parameters
scripts/tuning.gd          what those parameters are
scripts/hand.gd            spring to the target, claw grab, pin or weld, slip
scripts/item.gd            a thing: holders, lit when under a hand, shaking, respawn
scripts/sheet.gd           flat → rolled → sealed → lit; takes in, leaks, tears
scripts/lighter.gd         strike and flame
scripts/crumb.gd           a crumb
scripts/main.gd            spawning, mouth, lighting, steps, score
scripts/controls.gd        bindings, keyboard and gamepad
scripts/debug_overlay.gd   readout and tuning keys
scenes/                    main, hand, table, items/ — all hand-written text
tools/                     grab_bot.gd, roll_bot.gd, screenshot.gd
```

Why the grab is a claw, how shaking is detected, and what the bots found are
in [`../../docs/design-notes.md`](../../docs/design-notes.md).
