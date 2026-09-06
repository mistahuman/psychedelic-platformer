# 04 — Remembered maze

**Question:** if almost everything is always unseen, does "the world changed"
stop being noticeable at all?

Top-down maze, lit by a short lantern. It rearranges itself only where you
cannot see — and **the map in your head does not update.** The cells you have
already visited stay drawn, dimmed, exactly as you last saw them. When a wall
moves behind you, your memory keeps showing the old one until you walk back and
look.

That gap between what you remember and what the lantern finds is the whole
prototype. Nothing marks it for you.

## Playing it

Open **this folder** as a Godot 4 project, then F5.

| Key | Action |
| --- | --- |
| `W` `A` `S` `D` or arrows | walk |
| `R` | back to the start (the maze keeps its current shape) |

Find the teal exit in the far corner. There is no jump: this is the first
prototype where the carried-over platformer controller does not apply.

## Reading the screen

| What you see | What it means |
| --- | --- |
| Bright walls | inside the lantern — **true right now** |
| Dim walls | remembered from an earlier visit — **may already be wrong** |
| Black | never seen |
| Teal square | the exit |

## Debug keys

| Key | Action |
| --- | --- |
| `F1` | show/hide the overlay |
| `F3` | **mutation on/off — the A/B test** |
| `F4` | paint every cell you remember wrongly. **Testing only** — it gives away the answer |
| `[` `]` | lantern radius down / up |
| `,` `.` | changes per second down / up |
| `F5` | a completely new maze |

`wrong` in the overlay is the number of cells whose remembered state no longer
matches reality: how much of what you believe is already false. Watch it climb
while you walk, then press `F4` to see where.

## What to watch during the test

- **The core risk, stated up front:** a lantern this small means almost the whole
  maze is always eligible to change, and a world that changes everywhere is
  indistinguishable from a world with no rules. The drawn memory is the intended
  answer to that. Does it actually work — do you *catch* the maze having moved,
  or does it just feel arbitrary?
- `F3` off for a run. A static maze with a small lantern is already tense.
  Is the mutation adding tension, or just adding time?
- When you walk into a wall your map says is not there: **discovery, or bug?**
  If it reads as a bug, the prototype has failed and it is worth knowing early.
- `[` to shrink the lantern, `]` to grow it. There is a radius at which the
  memory stops being useful and one at which the mutation stops being felt. The
  interesting design lives between them.
- Does the exit ever feel unreachable? It never is — every change is rejected
  unless the exit is still reachable from where you stand — but *feeling* trapped
  is a different thing from being trapped, and it is the feeling that matters.

## Files

```
scripts/maze.gd            grid, generation, mutation, connectivity, memory
scripts/maze_view.gd       draws lit / remembered / unknown
scripts/walker.gd          top-down character (not player.gd)
scripts/controls.gd        bindings, no jump
scripts/debug_overlay.gd   in-game tuning
```

Why a flood fill guards every change, why the wall density is held steady, and
why memory is a separate layer from truth are in
[`../../docs/design-notes.md`](../../docs/design-notes.md).
