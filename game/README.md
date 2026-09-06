# Wick

A small game. You are somewhere dark with a lantern, and the door is in the far
corner. The maze rearranges itself where you cannot see, and the map in your
head does not update — so the walls drawn on screen outside the lantern are your
memory, not the truth.

The wick burns down. When it goes out, so do you.

## Playing it

Any key to start. `WASD` or arrows to walk. `R` to go back in.

| What you see | What it means |
| --- | --- |
| Bright walls | inside the lantern — true right now |
| Dim walls | remembered from earlier — may already be wrong |
| A cell flashing pink | the lantern just caught your memory being wrong |
| Amber pulse | oil: it buys wick back |
| Teal pulse in the corner | the door — visible from anywhere, and it hums |

Play it with sound on. The maze getting away with something has its own noise,
and the wick running low starts a heartbeat before the bar looks alarming.

A run takes two or three minutes.

## Tuning

How often the maze should manage to catch you out is a feel question, and the
value shipped is a starting guess. Mid-run:

| Key | Action |
| --- | --- |
| `F3` | the maze stops changing / starts again |
| `[` `]` | changes per second, down / up |

`F3` off is the honest baseline: the same maze, a shrinking lantern, and nothing
lying to you.

## Run

```bash
make game           # from the repo root
```

or `godot --path game`.

## Sound

Every sound is generated from sine waves, filtered noise and envelopes by
[`../tools/make_sounds.py`](../tools/make_sounds.py) — no sourced assets. Re-run
it to re-tune them:

```bash
python3 tools/make_sounds.py
```

## Where this came from

Four prototypes under `prototypes/`, of which this keeps one idea: a world that
only changes where you are not looking. What the prototypes never had — and why
they were unreadable — is in [`../docs/design-notes.md`](../docs/design-notes.md).
