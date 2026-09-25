# psychedelic-platformer

_(working title)_

A 2D game in Godot 4 — a platformer up to prototype 03, top-down from 04 to 05,
side view again from 06.
Prototype repo: each folder under `prototypes/` is a standalone Godot project,
playable in a couple of minutes, built to answer one design question. The final
game does not exist yet — it gets assembled from the mechanics that survive.

## Stack

Godot 4.7 · GDScript

## Run

```bash
make list             # the prototypes and their questions
make run P=06         # open the prototype in Godot
make edit P=06        # open it in the editor
```

Needs Godot 4.7 on `PATH`, or `GODOT=/path/to/godot`. Without `make`: in Godot,
**Import** → pick the prototype folder (not the repo root) → **Run** (F5).

## Prototypes

| #   | Folder                                                                | Question                                                                | Verdict                             |
| --- | --------------------------------------------------------------------- | ----------------------------------------------------------------------- | ----------------------------------- |
| 01  | [`01-breathing-platforms`](prototypes/01-breathing-platforms/)         | Is jumping on oscillating platforms fun or frustrating?                 | Fine to play, wrong direction — closed |
| 02  | [`02-unreliable-vision`](prototypes/02-unreliable-vision/)             | Is rendering that lies about the geometry a mechanic, or just noise?    | Set aside unplayed — self-contained |
| 03  | [`03-behind-your-back`](prototypes/03-behind-your-back/)               | The level changes only where you can't see it: tension, or annoyance?   | Played: not legible                 |
| 04  | [`04-remembered-maze`](prototypes/04-remembered-maze/)                 | If almost everything is unseen, is a change still noticeable at all?    | Played: not legible                 |
| 05  | [`05-wick`](prototypes/05-wick/)                                       | Does the same idea work once it has a frame, an ending and sound?       | Played: not liked — closed          |
| 06  | [`06-grapple`](prototypes/06-grapple/)                                 | Hook, swing, let go: does timing the release feel like a skill?         | Played: nice, not convinced         |

Each prototype's README has its keys and what to watch while testing. The
decisions, and the playtest verdicts that close a prototype, are in
[`docs/design-notes.md`](docs/design-notes.md).
