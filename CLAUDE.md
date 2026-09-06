# psychedelic-platformer — Claude Code context

A 2D platformer in Godot 4 / GDScript, **working title**. Nothing here is the game:
the repo is a sequence of throwaway prototypes, each one answering a single design
question by being played. The game gets assembled later, from whatever survives.

Started 2026-09-06. No engine or stack decision beyond Godot 4 — the rest is open.

## The method

This is the part to respect; the code is downstream of it.

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
carrying **in any side-view prototype**. Changing it is a decision, not a tweak.

04 is top-down and does not use it at all — no gravity, no jump, no floor. That is a
genre change, not a tweak either: whether this project is still a platformer is a
question for after 04's verdict.

Same for the respawn (threshold on `y` + a checkpoint `Area2D`) and, when something has
to carry the player, `AnimatableBody2D` + `sync_to_physics` rather than reparenting or
copying deltas by hand.

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

**Two prototypes are now built and unplayed.** That is one more than the method
tolerates: the next session plays them and writes verdicts before anything else is
built.
