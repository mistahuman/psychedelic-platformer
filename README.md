# psychedelic-platformer

_(working title)_

A 2D platformer in **Godot 4 / GDScript**. This is a prototype repo: every
folder under `prototypes/` is a standalone Godot project, playable in a couple
of minutes, built to answer **one design question**.

```
psychedelic-platformer/
├── prototypes/
│   ├── 01-breathing-platforms/   platforms oscillating on a sine wave
│   └── ...
├── docs/
│   └── design-notes.md           decisions taken, and why
└── README.md
```

## Opening a prototype

Each prototype has its own `project.godot`. In Godot: **Import** → pick the
prototype folder (not the repo root) → **Run** (F5).

## Prototypes

| # | Folder | Question |
|---|---|---|
| 01 | [`01-breathing-platforms`](prototypes/01-breathing-platforms/) | Is jumping on oscillating platforms fun or frustrating? |

## Conventions

- **Placeholder art only**: `ColorRect` and flat colors. No final assets until
  the feel is settled.
- Each prototype is **one playable scene**. No menus, no level system, no game
  over.
- Every feel parameter is an `@export`, tunable from the inspector **while the
  game runs**.
- Decisions go in [`docs/design-notes.md`](docs/design-notes.md), not in commit
  messages.
