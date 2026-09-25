# psychedelic-platformer — Claude Code context

Godot 4 / GDScript. Right now this is **a prototype repo**:

- **`prototypes/`** — five closed attempts, kept as a record, and **06 grapple**, the
  one being tested. 05 Wick was built as "the game" in `game/`, played, not liked,
  and demoted on 2026-09-25.
- **`game/`** — does not exist at the moment. It comes back when an idea earns it.

Started 2026-09-06. The repo name is stale: it is not a platformer any more.

## What went wrong with the method, and what replaced it

The original method was: one prototype, one design question, played, then a dated
verdict. It produced four prototypes and one playtest. Three of the four were judged
at the desk, which is not the method — it is the method's paperwork.

When they were finally all played, the verdict was that **none of them was legible**:
no beginning, no end, and no moment where the game tells you the mechanic just fired.
The notes had been asking whether each mechanic was *good* while the real problem was
that the player could not perceive it at all.

So the unit of work changed. **Not "one question per prototype" but "one playable
thing with a beginning and an end".** Wick is that. The rules below still hold for
anything genuinely exploratory, but they are no longer the default mode of the repo.

### The old method, still useful for side experiments

1. One prototype = **one design question**, written at the top of its README.
2. It is a **standalone Godot project** under `prototypes/NN-slug/`, with its own
   `project.godot`. Prototypes never import from each other — code that carries over
   is *copied*, and the copy is free to diverge.
3. It gets **played**, then a verdict goes into `docs/design-notes.md` with a date.
   A prototype is closed by its verdict, not by being finished.
4. A closed prototype is **not iterated on**. If the answer is "wrong direction", the
   tuning questions it left open are moot — do not reopen them.
5. The next prototype starts from what the verdict opened up, not from the previous
   prototype's backlog.

Corollary that has already bitten once: when a prototype's feel is fine but the
*concept* is a dead end (01), that is a successful prototype. Do not try to rescue it.

## Where things live

- `docs/design-notes.md` — the decision log, one section per prototype: the question,
  the technical choices **and why**, the playtest verdict, what carries over, what the
  next prototype should attack. This is the memory of the project. Read it before
  proposing anything.
- `prototypes/NN-slug/README.md` — how to play that one: keys, goal, debug keys, what
  to watch during the test. Player-facing, not architectural.
- Rationale never goes in commit messages, and architecture never goes in a README.

## Running

`make list`, `make run P=04`, `make edit P=04`, `make clean`.

Godot 4.7.2 lives at `~/.local/bin/godot` (official binary, no system package —
replace the file to upgrade). The Makefile takes `GODOT=` if it ever moves.

**The machine is native Ubuntu 24.04 on Wayland with an AMD Radeon 780M**: Mesa
radeonsi, OpenGL 4.6, and Vulkan 1.4 / Forward+ both verified. The WSLg + llvmpipe
software-rendering constraint recorded in 01 and 02 does not apply — 01 and 02 are on
GL Compatibility for historical reasons, 03 is on Forward+ and leaves its full-screen
shader on by default. **Do not carry that constraint into new prototypes.**

Prototypes can be smoke-tested without a window:
`godot --headless --path prototypes/NN-slug --quit` runs one frame and surfaces every
parse and runtime error.

## Prototype conventions

- **Placeholder art only** — `ColorRect` and flat colours. No assets until a feel is settled.
- **One playable scene.** No menus, no level system, no game over, no audio.
- **Every feel parameter is an `@export`,** tunable while the game runs.
- **Prototypes tune themselves.** From 02 on, tuning happens through an in-game debug
  overlay and function keys, not the editor's Remote inspector. The reason first given
  was WSLg window focus; the reason it stays is better — the overlay keeps the tuning
  in the same window as the feel being tuned, and it is what a playtester can use.
- Input actions are registered at runtime by a `controls.gd` autoload rather than in
  `project.godot`'s InputMap, so bindings stay diffable. It only registers an action that
  does not already exist.
- **Export paths, not nodes.** `@export var x: Node2D` filled in with
  `x = NodePath("..")` in a hand-authored `.tscn` silently stays null — no error, the
  feature just does nothing. Export a `NodePath` and resolve it with `get_node_or_null()`
  in `_ready()`. This bit 03 and 04 both; see the note under 04 in the design notes.

## Settled, and not what the prototypes are testing

`scripts/player.gd` — the character controller. Classic jump, no double jump, asymmetric
gravity (fall 1.4x), jump cut on release, coyote time and jump buffer at 0.10 s,
`floor_snap_length = 16`. It carried from 01 to 03 essentially unchanged and should keep
carrying **in any side-view prototype** — 06 copies its ground half and adds the
rope. Changing it is a decision, not a tweak.

04 is top-down and does not use it at all — no gravity, no jump, no floor. That is a
genre change, not a tweak either: whether this project is still a platformer is a
question for after 04's verdict.

Same for the respawn (threshold on `y` + a checkpoint `Area2D`) and, when something has
to carry the player, `AnimatableBody2D` + `sync_to_physics` rather than reparenting or
copying deltas by hand.

## Working on anything with a beginning and an end

Learned on Wick (05), and they hold for whatever comes next.

- **Legibility first.** A mechanic the player cannot perceive is not subtle, it is
  absent. Every rule the game has must have a moment on screen where it announces
  itself — for the maze changing, that is the pink flash and the counter.
- **Decide by measuring where you can.** Which cells are allowed to change was settled
  by a headless harness that walks the route and counts how often the player is
  actually caught out, not by taste. The first version scored zero. See the table in
  the design notes.
- **Smoke-test after every edit:** `godot --headless --path <project> --quit`. Skipping it
  once cost several minutes chasing a hang that was a one-line type-inference error.
- **Assert what you cannot perceive.** Audio cannot be heard from here and lighting
  cannot be judged from a compiler, so both were checked by driving the running game:
  a screenshot for the light, and a printed list of which players were actually
  playing for the sound. "It compiles" is not "it works" for anything sensory.
- **New `.wav` files need an import pass** before they can be loaded:
  `godot --headless --path <project> --import`. Without it, `load()` returns null and the
  only clue is "No loader found for resource".
- Sounds are generated by `prototypes/05-wick/tools/make_sounds.py`, committed as a
  script so they can be re-tuned rather than replaced. No sourced assets anywhere in this repo.

## Status

- 01 breathing platforms — **closed 2026-09-06.** Feel fine, concept a dead end.
- 02 unreliable vision — built, **never played, set aside 2026-09-06.** Judged at the
  desk: the calm mechanic changes the player's *reading* of the world, not the world,
  so it cannot grow. Left in the repo. If it is ever played, the question still worth
  an answer is whether the calm actually gets used.
- 03 behind your back — built, **untested.** The level rearranges itself only off
  camera; what is on screen is always true. Verdict pending an actual playtest.
- 04 remembered maze — built, **untested.** Same rule as 03 in a better vehicle:
  top-down maze, short lantern, and the player's remembered map drawn on screen and
  left to go stale. Top-down, so no jump.

The camera stopped being an open question at 03: "off camera" needs a scrolling one,
so the corridor is ~3 screens wide and crossed twice. 04 went back to a single fixed
screen — there the lantern, not the camera, is what bounds sight.

- **Wick** — built 2026-09-06, playable start to finish. All four prototypes were
  played and found unreadable; Wick is the answer to that, keeping only the one idea
  worth keeping.
- **Wick, presentation pass** — 2026-09-07. Judged still prototype-grade, and the two
  reasons were nameable: no audio at all, and light that was per-cell alpha, so the
  lantern read as a mosaic of squares rather than as a light. Both fixed. What is
  still missing for a finished thing is **structure**: one maze, one attempt, no
  progression and no record.
- **Wick, verdict** — 2026-09-25. Played and not liked as it stands, with no
  specific reason given. Moved to `prototypes/05-wick/`. That closes the "world
  that changes where you cannot see" line (03, 04, 05) — do not reopen it.
  A tilt-maze (the bar-top wooden labyrinth) was considered the same day and
  dropped before any code.

- 06 grapple — built 2026-09-25, **played the same day: nice, not convinced, "a lot
  missing".** Hook, swing, let go, one button. First
  prototype that starts from a verb rather than a concept, and first with a frame
  (title, clock, flag) from day one. Carries the ground half of `player.gd`.
  A headless bot (`tools/course_bot.gd`) confirmed the course is passable and that
  only some release angles work.

Next: name what 06 is missing before adding anything.
