# Design notes

Decision log. One section per prototype: the question it answers, the technical
choices and why, what is still open.

---

## Prototype 01 — Breathing platforms

**Question:** is jumping on vertically oscillating platforms fun (rhythm,
timing, "breathing") or frustrating (imprecision, eaten jumps, falls that don't
feel like your fault)?

### Oscillation

```
position = base + amplitude * sin(TAU * frequency * t + phase_offset)
```

- **`base` is the node's editor position**, read once in `_ready()`. Move the
  platform in the editor and the oscillation follows. No hardcoded coordinates.
- **Frequency in Hz, not rad/s** (the script multiplies by `TAU`). "0.3" reads
  as "one cycle every ~3 seconds", which is the unit you think in while
  balancing rhythm. "1.88 rad/s" is not.
- **`t` is a local accumulator** (`_time += delta`), not
  `Time.get_ticks_msec()`. Each platform owns its clock, so one can be paused,
  reset or slowed down without touching the others — useful for the planned
  variants.
- **Updated in `_physics_process`, not `_process`.** A physics body must move in
  step with the physics server, otherwise the character standing on it sees a
  position different from the one it collides against, and jitters.
- **All four platforms differ in frequency, amplitude and phase**
  (0.33 / 0.22 / 0.45 / 0.58 Hz), with frequencies that are not integer
  multiples of each other, so the combined pattern does not repeat quickly.
  That's the point: we want to see whether it reads as "alive" or as "unfair".

### Carrying the player

Three possible approaches:

1. **Reparent** the player to the platform on landing. Works, but pollutes the
   node tree, breaks global transforms, and has to be undone by hand.
2. **Manually copy the platform's delta** into the player. Works until there are
   two platforms, or a rotating one, or a frame where contact is lost.
3. **Let the engine do it** — what we picked.

The canonical Godot 4 way:

- The platform is an **`AnimatableBody2D`** (not `StaticBody2D`: it wouldn't
  move as far as physics is concerned; not `CharacterBody2D`: that's for
  controlled bodies that collide themselves). `AnimatableBody2D` exists exactly
  for script-driven bodies that must carry or push other bodies.
- With **`sync_to_physics = true`** the engine derives the body's velocity by
  comparing positions between physics steps.
- The player is a `CharacterBody2D`: **`move_and_slide()` adds the velocity of
  the platform it stands on** (`get_platform_velocity()`). Not a single line in
  the player script mentions platforms. Switching a platform to
  `horizontal = true` already works.

Two details separating "stands on it" from "stands on it well":

- **`floor_snap_length = 16.0`** on the player. When a platform moves down the
  floor briefly escapes from under the feet; without snapping the character
  enters free fall and bounces every frame. 16 px is generous: the platforms'
  peak vertical speed here is ~170 px/s, i.e. ~2.8 px per frame at 60 fps.
- **`velocity.y = 0` while `is_on_floor()`**, so gravity doesn't accumulate
  frame after frame and force the snap to fight it.

`platform_on_leave` is left at its default (`ADD_VELOCITY`): jumping off a
rising platform carries its push. That's a feel choice, not a technical
requirement — if playtesting shows it's unpredictable, switch it to
`ADD_UPWARD_VELOCITY` or `DO_NOTHING` in the player's inspector.

### Jump feel

Deliberately classic: no double jump, no power-ups. Two concessions only, both
exported and **zeroable for an A/B comparison during playtesting**:

- **coyote time (0.10 s)** — close to mandatory with descending platforms:
  without it, every frame where the platform slips out from under you eats the
  jump, and it feels like the game's fault.
- **jump buffer (0.10 s)** — a jump pressed just before landing stays queued.

Plus asymmetric gravity (falling 1.4x the rise) and jump cut on key release: a
more readable arc when aiming at a moving target.

### Respawn

As dumb as possible, per spec: below `fall_threshold_y` (780) the character
reappears at the last safe point. No screens, no level reset — the platforms
keep oscillating, so you don't lose your place in their cycle. `R` forces a
respawn for fast iteration.

The respawn point starts at the initial position and is updated by a checkpoint
`Area2D` (one only, on the landing ledge). Adding more is a matter of
duplicating the node.

### Input

Actions (`move_left`, `move_right`, `jump`, `respawn`) are registered at runtime
by an autoload (`scripts/controls.gd`) rather than in `project.godot`'s InputMap.
Reason: in a prototype, bindings in a readable, diffable text file beat the
serialized blob. The script only registers an action if it doesn't already
exist, so it steps aside the day we move them into the editor.

### Playtest verdict — 2026-09-06

Tested on Godot 4.7.2 (Linux/WSLg, software rendering).

**The feel is fine.** Better than expected for a first prototype: not
frustrating, the jump reads, landing on a moving target works. So the original
question — fun or frustrating? — is answered, and it isn't the blocker.

**But the mechanic is a dead end.** Moving blocks are a done-to-death
platformer staple, and this isn't the direction the game is looking for. The
oscillation reads as "a platform that moves", not as anything the working title
promises. No amount of tuning amplitude, frequency or phase changes that: the
problem is the concept, not the numbers.

Consequence: **do not iterate on this prototype.** The specific open questions
(PlatformB's amplitude, the C -> D wait, coyote time at 0) are moot — they'd be
tuning something we're not going to build.

### What carries over

The mechanic is dead, the plumbing is not. Reusable as-is in the next
prototypes:

- `scripts/player.gd` — the character, with tuning that already feels right.
- The `AnimatableBody2D` + `sync_to_physics` approach, for anything that has to
  carry the player.
- Threshold respawn + checkpoint area.

### Open for prototype 02

The thing to attack is that oscillation was applied to the **level geometry**.
Candidates that move it elsewhere:

- Move it to **perception**: geometry stays mechanically honest, the rendering
  of it breathes. Visual instability, stable collisions.
- Move it to **existence**: platforms don't travel, they phase in and out on a
  cycle. Rhythm without movement.
- Move it to **the player**: gravity, scale or control response breathes rather
  than the world.

Undecided regardless of direction: camera (a single fixed screen for now).

---

## Prototype 02 — Unreliable vision

**Question:** when the rendering lies about where the geometry is, is that a
mechanic you can learn to play against, or just noise that makes the game feel
broken?

Direct answer to 01's verdict: the oscillation moves from the level geometry to
the *image* of the level geometry.

### The mechanic

- Platforms are `StaticBody2D`. **The collision shapes never move.**
- Each platform's `ColorRect` is offset from the real position by a per-platform
  two-axis sine, scaled by a global `Perception.level` (0..1).
- `Perception.level` rises while the player moves or is airborne, and falls
  roughly 2.7x faster while the player stands still on the ground.

So: moving costs you information, standing still buys it back. The player can
always get the truth — at the price of time. That's the loop worth testing;
without the calm mechanic this would just be a screen effect.

### Why visual offset rather than a screen-space shader

The shader route (warp the whole frame) is the obvious reading of
"psychedelic", but it's the weaker test:

- It lies about *everything* uniformly, so there's nothing specific to learn.
- Full-screen fragment work is expensive on the target setup (WSLg, no GPU
  passthrough, llvmpipe software rendering), and a stuttering prototype poisons
  a feel test for reasons that have nothing to do with design.

> **Correction, 2026-09-06.** That second reason was wrong, or has stopped being
> true. The machine is native Ubuntu 24.04 on Wayland with an AMD Radeon 780M:
> Mesa radeonsi, OpenGL 4.6, and Vulkan 1.4 / Forward+ both verified running.
> There is no WSLg and no llvmpipe. The shader budget that argument spent does
> not need spending — prototype 03 runs on Forward+ and leaves its full-screen
> pass on by default. The *first* reason still stands on its own, and it is the
> better one: a uniform lie teaches the player nothing.

Offsetting the visuals costs nothing, and lies about exactly one thing — where
a platform is — which is the thing the player has to reason about. The
full-screen shader (`shaders/haze.gdshader`, warp + chromatic aberration, three
texture samples) is there as flavor on top, **off by default**, toggled with F2.

`BackBufferCopy` in `copy_mode = 2` sits before the haze `ColorRect` so
`hint_screen_texture` is populated regardless of renderer.

### In-game debug overlay

Prototype 01's tuning plan relied on the editor's Remote inspector, which turned
out to be awkward in practice: under WSLg the game and the editor are separate X
windows, keyboard focus has to be switched by hand, and the tab is easy to miss.
Replaced with an in-game overlay and function keys (`scripts/debug_overlay.gd`).
**Convention from here on: prototypes tune themselves, no editor round-trip.**

### Carried over from 01

`player.gd` unchanged except for one line feeding `Perception.calm`. The
character controller is settled; it is not what these prototypes are testing.

### To evaluate in playtesting

- F3 (drift on/off) mid-run: is the difference interesting, or just annoying?
- Does the player actually stop to read the level? If the calm mechanic goes
  unused, it doesn't exist and the whole design collapses to a screen effect.
- Does a missed jump feel like being tricked (good) or cheated (bad)?
- Where is the line, on `]`, between disorienting and unplayable?

### Open

- Does the lie need to be *learnable* (a fixed pattern per platform, which it
  currently is) or would randomness be better? Current bet: learnable.
- Should the player's own body drift too? Current bet: no — losing trust in your
  own position is the fastest way to make a platformer unplayable.

---

## Prototype 03 — Behind your back

**Question:** when the level rearranges itself only where you cannot see it, is
turning around tension — or just annoyance?

### Why 02 was set aside before being played

Called on 2026-09-06, at the desk rather than on the pad, and worth recording as
a judgement rather than a verdict: **02's calm mechanic does not change the
world, it changes your reading of the world.** Mechanically its level is four
`StaticBody2D` that never move. The calm is a meter you manage, and "stand still
and the truth returns" is fiction laid on top of a resource, not a thing the
level does. That is the sense in which it is self-contained: it cannot grow into
anything, because nothing in the world is at stake.

02 is left in the repo, built and unplayed. If it is ever played, the thing to
find out is whether the calm gets *used* — that answer would still be worth
having, and it is cheap now that Godot runs locally.

### What "the world changes" was narrowed to

Four readings were on the table: the world reacts to your passage; it changes
where you are not looking; two overlaid worlds you switch between; platforms that
exist intermittently. **Picked: changes where you are not looking.**

The reason it beats the others for this project specifically: it is the only one
that **keeps the screen honest**. 01 moved the geometry, 02 moved the picture of
the geometry and lied. Both spend the player's trust. This one spends none — what
is rendered is always exactly what you will collide with — and puts the
instability entirely in what you remember. For a game whose working title
promises unreliability, buying that unreliability without ever cheating the
player in the moment is the more interesting trade.

### The camera is no longer undecided

01 and 02 both left this open and both ran on a single fixed screen. "Off camera"
is meaningless on a fixed screen, so 03 settles it by force:

- **Horizontally scrolling `Camera2D`,** child of the player, `limit_*` set to
  the level bounds, `position_smoothing_speed = 6.0`.
- The corridor is **~3 screens wide** and is crossed **twice**: out to a beacon,
  back to a goal that stays dark until the beacon is touched. Backtracking is not
  a level-design flourish here, it is the only way the mechanic is ever
  experienced. A single crossing would be a plain platformer.

### The rule, precisely

- A platform holds one of several **variants**: offsets from its editor position.
  Index 0 is the authored one, so the level as designed is the level as first
  seen.
- It may re-roll **only while entirely outside the camera rect grown by a margin**
  (default 160 px), and **at most once per trip off screen** — it arms itself
  when visible and disarms when it rolls. Without the arming it would keep
  shuffling in place while the player is elsewhere, which is a different and much
  cheaper mechanic.
- The **destination is checked too, not just the origin.** A platform sitting just
  past the margin can pick an offset that lands it back inside the view; that
  would be a visible pop, the one thing the prototype promises never happens. If
  the destination is visible, it does not move.
- `mutation_chance` defaults to **0.6**, not 1.0. The platforms that stay put are
  landmarks. Without them the return leg reads as a *different level* rather than
  as *the same level, changed*, and the whole effect collapses into a random
  level generator. This is the knob most likely to be wrong.

The view rect comes from the **camera**, not the player: with position smoothing
the two disagree for a fraction of a second, and that fraction is exactly where a
platform would be caught moving. Note also that `get_visible_rect()` on the
viewport is the correct source — `get_viewport_rect()` on the camera is a
`CanvasItem` helper and reported a square rect.

### Level arithmetic

The variants have to stay inside the jump, or the world can rearrange itself into
an impassable corridor and the prototype tests frustration instead of tension.
From the settled controller (`jump_velocity` 520, rise gravity 1250, fall gravity
1750, `max_speed` 280):

- apex **108 px**, reached at 0.416 s; total airtime back to the same height
  0.767 s, so a flat gap allows about **215 px** of travel.
- for a landing **80 px higher**, the arc is above that line between t = 0.204 s
  and t = 0.596 s — a horizontal budget of **167 px**.
- the layout spends at most **149 px** of it: 85 px of gap (150 px platforms on a
  235 px pitch), plus 36 px worst-case horizontal variant offset, plus the 28 px
  of player width between the two landing edges.

Hence the variant envelope: **±40 px vertical, ±18 px horizontal**, and all bases
on the same `y`. Every base at the same height also means that with mutation off
(`F3`) the level is a flat, boring row — **the level's shape is entirely the
product of the mechanic**, which makes the A/B test honest.

A static grey ledge sits halfway, never mutates, and carries a checkpoint. It is
the landmark and the breather, and it keeps a fall on the return leg from costing
the whole leg.

### Measurement

`run_state.gd` times both legs separately and the overlay shows them. That is the
data the verdict needs: a slower return is expected, but slower-because-careful
and slower-because-waiting are opposite answers to the question, and the timer
plus the memory of the run distinguishes them.

### The gaze edge

`shaders/gaze.gdshader` is a cheap vignette on a `CanvasLayer`, **on by default**
— unlike 02's haze, which was off. The screen border is where the rules change in
this prototype, so being able to feel it is mechanical, not decorative. It costs
one `length()` per pixel and the machine turned out to have a real GPU (see the
correction under 02), so there is no reason to hide it behind a toggle other than
the A/B, which `F2` provides.

### To evaluate in playtesting

- `F3` across the return leg. Mutation off is the same corridor twice, boring on
  purpose. Is on *tense* or *tiring*?
- Does the player start **walking backwards to keep the level in view**? If so
  the mechanic works — and that instinct is a verb a full game would have to
  make real rather than merely tolerate.
- Unexpected landing: "huh, it moved" or "what, again"?
- `mutation_chance` at 1.0: does the "same level, changed" reading survive?
- `margin` towards 0: how obvious does the cheat have to get before it is felt?

### Open

- **Random or learnable?** Currently a fresh random roll each time. 02 bet on
  learnable and never got tested. Here randomness is arguably right — the point is
  discovery on return, not pattern memorisation — but a fixed per-platform
  sequence would make mastery possible. Untested either way.
- **Disappearing platforms** were deliberately left out. They are the most
  striking version of "the world changed", but guaranteeing the corridor stays
  crossable stops being arithmetic and starts being a solver. One question per
  prototype.
- Vertical space is unused. The corridor is a horizontal line; the mechanic has
  nothing to say about it yet.

---

## Prototype 04 — Remembered maze

**Question:** if almost everything is always unseen, does "the world changed"
stop being noticeable at all?

### Why a maze, and why this is not a new question

03's rule was kept; only the vehicle changed. In a corridor, "what you cannot
see" is just "what is off screen": a small set, emptied by walking. A maze
supplies blind space for free — every corner is one, two steps away — and the
getting lost and the doubling back that 03 had to manufacture with a beacon and a
goal are native to the form.

The cost is that this is no longer a platformer. `player.gd` does not carry: no
gravity, no jump, no floor. `walker.gd` replaces it, with a **circle** collision
shape, because a box catches on every corner of a 48 px grid and makes the maze
feel worse than it is. Whether the project as a whole is still a platformer is a
question for after the verdict, not before it.

### The risk this prototype accepts

A short lantern means nearly the whole maze is always eligible to change. Taken
alone that is the same failure as setting 03's `mutation_chance` to 1.0, in a
harsher form: **a world that changes everywhere is indistinguishable from a world
with no rules.** If the player cannot notice a change, the change may as well not
happen, and the mechanic evaporates into atmosphere.

### The answer to it: memory is drawn

Three layers, deliberately kept apart in `maze.gd`:

```
cells    what the maze actually is. Collision agrees with this, always.
memory   what the player last SAW. Only ever updated by looking.
light    how brightly each cell is lit this frame, 0..1.
```

Unlit-but-visited cells are drawn **from `memory`**, dimmed. Lit cells are drawn
from `cells`. That single substitution in `maze_view.gd` is the mechanic: the
map in your head is on the screen, it is stale, and it stays stale until you walk
back and look. The change becomes noticeable not because it is signposted but
because **you are holding the old version in your hand while you find the new
one.**

Nothing marks a stale cell. `F4` does, for testing only — it gives the answer
away and must not become a feature by accident.

`stale_count()` — cells whose memory disagrees with truth — is surfaced in the
overlay as `wrong`. It is the closest thing this prototype has to a measurement:
how much of what the player believes is false at this instant.

### Connectivity is checkable, unlike a jump arc

03 had to guarantee traversability by arithmetic, hand-tuning the variant
envelope against the jump arc so no combination could produce an impossible gap.
A maze does not need that: **propose the change, flood fill, keep it only if the
exit is still reachable from the cell the player is standing in.** The grid is
23x13, so a BFS per attempted change is free.

This is a better shape for the same problem, and worth remembering if the
mechanic survives: prefer worlds whose validity can be *tested* over worlds whose
validity has to be *proven in advance*.

Two further filters, both load-bearing:

- A cell must be **unlit and at least `min_distance` cells away**. Unlit alone is
  not enough — changes happening just past the lantern read as being done *at*
  you rather than behind you.
- **Wall density is held at the value it was generated with.** Each attempt
  prefers opening if the maze has drifted denser and closing if it has drifted
  sparser. Without it a long run erodes into an open field or silts up into a
  block; either way the maze stops being a maze.

Most attempts are rejected, and that is the design. The filters are what separate
this from a random level generator.

### Generation

Recursive backtracker on odd coordinates: a perfect maze, exactly one route
between any two cells. Mutation erodes that property immediately — opening a wall
creates a loop — and that is fine. Perfection is the starting condition, not an
invariant. The invariant is connectivity, and it is checked per change.

### Bug worth recording: node exports in hand-written scenes

`@export var maze: Node2D` with `maze = NodePath("..")` written by hand into the
`.tscn` **does not resolve** — the property stays null, silently. The view drew
nothing and the overlay rendered an empty string, with no error anywhere.

**Prototype 03 had the same bug and it went unnoticed**: its `F2` (gaze edge) and
`F5` (restart run) did nothing at all. Both are now fixed the way `maze.gd`
already did it for the player: export a `NodePath` and resolve it with
`get_node_or_null()` in `_ready()`.

Convention from here: in a hand-authored scene, **export paths, not nodes.**

### To evaluate in playtesting

- Does the drawn memory actually do its job — do you *catch* the maze having
  moved, or does it read as arbitrary?
- `F3` off. A static maze with a small lantern is already tense. Is the mutation
  adding tension, or only adding time?
- Walking into a wall your map denies: discovery, or bug? If it reads as a bug,
  this fails and it is worth knowing early.
- `[` and `]`. There is a lantern radius at which memory stops being useful and
  one at which mutation stops being felt. The design lives between them, and
  finding that band is most of what this playtest is for.
- Does the exit ever *feel* unreachable? It never is. Feeling trapped and being
  trapped are different, and only the first one matters here.

### Open

- **No line-of-sight memory of *when*.** Every remembered cell looks equally
  fresh. Fading memory by age would tell the player where to distrust — probably
  too helpful, but it is the obvious next knob.
- The maze is one screen. Scrolling would make the unseen set much larger and is
  the natural place to go if the lantern radius turns out to want to be small.
- No reason to walk back yet. 03 manufactured one; here backtracking happens only
  when you hit a dead end. If the verdict is "did not notice", the first thing to
  try is a there-and-back objective, not a bigger lantern.

---

## Wick — the game the prototypes were feeding

**Not a prototype.** It lives in `game/`, not `prototypes/`, and it is the first
thing here with a beginning, a middle and an end.

### The verdict that produced it, 2026-09-06

All four prototypes were played. The verdict was blunt and it was right:
**"non c'è un inizio e una fine, non si capisce nulla di nessuno."**

That is a harsher failure than the one the design notes had been circling. The
notes kept asking whether each mechanic was *good*. The actual problem was that
none of them was *legible*. In 03 the platforms move off camera — and the player
has no way of learning that they moved, so the experience is not surprise, it is
confusion. In 04 the maze changes and updates the memory silently. Four sandboxes
with a help label in the corner, and no moment in any of them where the game says
*that just happened*.

The concept survives the verdict; the presentation never existed. Recorded so it
is not re-learned: **a mechanic the player cannot perceive is not a subtle
mechanic, it is an absent one.**

### What was actually missing

1. **A frame.** A title that states the rule in five lines, and an ending that
   says in numbers what just happened to you. The prototypes had neither, so
   there was nothing to understand or to have understood.
2. **Confirmation at the moment of the mechanic.** When the lantern relights a
   cell and finds the memory of it was wrong, that cell now **flashes pink** and
   a counter ticks. This is the single most important addition in the whole
   project: it converts an invisible rule into an event.
3. **Stakes and an end condition.** The wick burns down over 80 seconds and the
   lantern radius shrinks with it, so the maze does not get harder — you get less
   able to read it. Three flasks of oil buy time back, capped at a full wick.
4. **A visible objective.** The door is drawn even through unexplored dark. Being
   lost should be about the route; the prototypes made it about the goal as well,
   and two unknowns at once reads as having no goal at all.

### Which cells are allowed to change, and how that was found

Decided by measurement rather than by taste — and the measurement lied for
several rounds before it told the truth, which is the more useful half of the
story.

A headless harness walks the solved route out and back twice and reports how
often the player is caught out. Early rounds all reported **zero catches**, no
matter how the filters were tuned, while a dozen contradictions sat unvisited at
the end of every run. The conclusion drawn from that — that changes were landing
in places the player never returns to — was **wrong**, or at least unproven: the
harness walked onto the exit cell on its first lap, which ends the run, freezes
the maze and turns laps two through four into no-ops. Every comparison made
against it was a comparison between two frozen mazes.

With the harness stopping three cells short of the exit, the same build scored
**41 changes, 35 of them caught.** The filters were not failing. The ruler was.

What the filters ended up being, in order of how much each one matters:

- **Only cells the player has already seen.** There is no memory to contradict
  otherwise, so the change cannot be perceived and may as well not happen.
- **Only cells touching one the player has actually walked through.** A maze
  sends you back down your own corridors sooner or later, and finding the
  corridor you came in by has become a wall is the moment this game exists to
  produce. Merely *seen* includes cells glimpsed once from across a gap, which
  is a much weaker bet.
- **Only cells looked at in the last 14 seconds**, and **only within about three
  cells beyond the lantern's edge** — around the corner, in the blind spot the
  walls make, rather than somewhere across the maze.
- Never lit, never the start, the exit or an oil cell, and never a change that
  breaks the flood fill from the player to the door.

Candidates are **enumerated**, not sampled. Throwing 24 random darts at a 23x13
grid to find one of a handful of eligible cells succeeded about a third of the
time and starved the change rate to a sixth of what it should have been.

Together these are so effective that the change rate had to come **down** hard —
from 2.2/s to **0.45/s**. At the old rate the maze rearranged itself roughly once
a second in the player's face, which is chaos, not tension. At 0.45 a run of
heavy backtracking scores about seven changes and seven catches.

### On tuning this by hand

That last number is a floor and a guess, not a setting. The harness walks the
same route repeatedly, which maximises catches; a real player exploring new
ground will be caught out less often. **How often the maze should get you is a
feel question no harness can settle**, so `F3` toggles the change on and off
mid-run and `[` / `]` move the rate, undocumented on the title screen.

### Kept from the prototypes

- The three layers (`cells` / `memory` / `light`) and the one substitution in
  `maze_view.gd` that draws unlit cells from memory. That is still the mechanic.
- Connectivity by flood fill before every change is committed.
- Wall density held at the generated value.
- Circle collision on the walker.

### Open

- No audio. A sound at the moment of a correction would probably do more than any
  further visual work.
- The catch rate still depends on how much the player backtracks, and nothing
  currently *makes* them backtrack except dead ends and oil. If playtesting says
  the mechanic fires too rarely, that is the lever — not the mutation rate.
- One maze size, one difficulty, no progression.

---

## Wick — the presentation pass, 2026-09-07

Played, and the verdict was "not bad, but this is still a prototype to me".
Correct, and unlike the earlier rounds the reasons were nameable rather than a
feeling. Two of them.

### No audio at all

The strongest single tell there is. A silent game reads as a tech demo whatever
is on the screen. More importantly here, sound is not decoration: the moment the
lantern catches a memory being wrong is the whole point of the game, and it was
being announced by a flash in the corner of the eye and nothing else.

Everything is generated by `tools/make_sounds.py` — sine waves, filtered noise
and envelopes, no sourced assets. It is committed as a script rather than only as
`.wav` files so the sounds can be re-tuned instead of replaced.

What each sound is doing:

- **drone** — two low sines detuned by an eighth of a hertz, beating slowly
  against each other. The beat is what makes a held tone uneasy rather than
  restful. It is the room.
- **caught** — a tritone, which never resolves, snapped off short, with a
  downward scrape underneath and one short echo. It has to land as *something is
  wrong*, never as a reward.
- **heartbeat** — starts under 28% wick. The warning is a sound that begins, not
  a number to be watching.
- **door** — a warm hum, played from an `AudioStreamPlayer2D` at the exit, so it
  gets louder as you approach. Between the glow and the hum the objective is
  knowable from anywhere: being lost is meant to be about the route.
- **steps** — paced by distance travelled rather than by a timer, so they stay in
  step with the character through acceleration.

Looping needed care: a `.wav` imported by Godot does not loop, and there is no
way to say otherwise from a hand-written project, so `sound.gd` duplicates the
stream and sets `loop_mode` and the loop points itself. The looping sounds only
use frequencies that are integer multiples of `1/duration`, so the waveform meets
itself at the seam without a click — which is why their frequencies look odd
(55.125 Hz rather than 55).

### The light was not light

The bigger of the two. Visibility was applied as a per-cell alpha, so the lantern
was a mosaic of 48 px squares. It read as a diagram of a maze, not as a place.

Line of sight has to be computed per cell — it is a grid raycast — so the fix was
not to compute it differently but to **stop rendering it directly**: the per-cell
values go into a 23x13 two-channel texture and a full-screen shader samples it
with bilinear filtering. Interpolating between cell centres on the GPU is what
turns the mosaic into a light, for the cost of 299 `set_pixel` calls a frame.

That inverted the drawing. The maze is now drawn at **full brightness** and the
lantern layer takes light away again, so "remembered" is dark because it is
unlit rather than because it is painted a second colour. One palette instead of
two, and closer to how it should read.

The second texture channel is the part that was not obvious. With only
visibility, explored-but-unlit cells went almost black — and **the remembered map
is the game**, so burying it left a pinhole and nothing to contradict. The green
channel carries "has this ever been seen", and gives those cells a floor on
their brightness. Bilinear filtering on that channel also gives the explored
region a soft edge for free.

Flicker is driven by the wick: a steady 3.5% at a full lantern rising to 16% as
it runs out, so the unease arrives through the light rather than through the bar.

### What did not get done

**Structure.** One maze, one attempt, no progression, no record. That is the
remaining gap between this and a finished thing, and it is a design question
rather than a polish one — which is why it was left rather than guessed at.

---

## Wick — verdict, 2026-09-25: demoted to prototype 05

Played after the presentation pass, and the verdict was **"così com'è non mi
piace"** — not "it needs structure", which is what the notes above expected, but
a rejection of the thing as it stands. No specific reason was given, and none is
invented here. Moved from `game/` to `prototypes/05-wick/`, with its sound script
moving into it, so it stays playable (`make run P=05`) and standalone like the
other four.

What this closes: the "world that changes where you cannot see" line, which ran
through 03, 04 and Wick. Three builds of the same idea, the last one legible,
framed and with sound, and it still did not land. That is enough to stop
iterating on it — per the rules above, its open questions (structure, catch rate,
backtracking) are now moot.

What survives is method, not mechanic: legibility first, a beginning and an
end, a moment on screen for every rule, sound as part of the mechanic, and
measuring with a harness where a question is measurable.

Also considered and dropped the same day, before any code: a **tilt-maze** (the
bar-top wooden labyrinth — tilt the board, roll the ball past the holes).
Legible and framed by nature, but it was set aside as a direction.

`game/` is empty until the next idea earns it.

---

## 06 — Grapple, 2026-09-25

**Question:** is hook, swing, let go fun on its own — does timing the release
feel like a skill you get better at, with one button?

Picked from a brainstorm of verb-first ideas. The diagnosis behind the list:
01–05 each started from a *concept* (a world that breathes, lies, changes behind
you) and then went looking for a way to play it. This one starts from a *verb*
that is already fun in other games, and asks only whether it is fun here.

### Technical choices, and why

- **Side view, and `player.gd` comes back.** The ground half is the controller
  from 01–03, trimmed. Two changes: air friction dropped from 700 to 60, because
  a release has to carry; and air steering can slow a fast release but never
  push it past running speed, or holding a direction would erase the swing.
- **One button.** Jump on the ground, a fresh press in the air hooks, holding
  it keeps you on the rope, letting go releases. Walking off an edge and
  pressing inside coyote time still jumps, which is the right way round.
- **Instant attach, no projectile.** A hook that travels adds a second timing
  on top of the one being tested.
- **Rigid rope that can go slack.** Outward velocity is removed only when the
  rope is taut, and position is snapped back if it drifts past the length.
  Swinging over the top of the anchor is therefore possible, and so far fine.
- **Pumping** is tangential acceleration from the held direction, only below
  the anchor — above it, it would be a jetpack.
- **The target is shown.** A gold ring and a dashed line on the anchor a press
  would catch, recomputed every frame: nearest above you and in range, with a
  120 px thumb on the scale for the one ahead. Without it the choice is
  invisible and every miss reads as the game's fault — the lesson from 03–05.
- **A frame from day one:** title card, clock, fall counter, flag, best time,
  `R` to go again. The course has five stretches, each teaching one thing:
  one swing, a chain of two, a chain of three, a platform you have to pump up
  to, and the run to the flag.
- The layout is two tables in `course.gd`, not a hand-authored `.tscn`.

### What the bot found

`tools/course_bot.gd` plays headless with a fixed policy — run right, jump at
edges, hook the ringed anchor when falling, pump with the motion, let go at a
fixed angle past vertical — and reports platforms reached.

| Release angle | Result |
| --- | --- |
| 0.50 rad | stuck after platform 2, 32 falls in 120 s |
| 0.65 rad | stuck after platform 3, 49 falls |
| **0.80 rad** | **flag in 15.1 s, 0 falls, 9 hooks** |
| 0.95 rad | stuck after platform 2, 22 falls |

Two things this says. The course is passable. And **no single release angle
works everywhere except by luck** — the bot passes at one angle and fails
either side of it, which is the evidence that the release is a decision
rather than a formality. A human changes the angle per swing; the bot cannot.
Whether making that decision *feels* good is what the playtest is for.

It also found a bug before any human did: the first good release cleared the
last platform and left the world on the right. There are now walls at both
ends.

### Open

- Everything about feel. Unplayed at the time of writing.
- Anchor selection on a crowded screen — the course never puts two good
  candidates close together, so the bias is untested.
- No audio. A rope-catch sound and a whoosh on release are the obvious two, and
  after 05 there is a script for making them.

### First play, 2026-09-25

**"Carino però non sono molto convinto, manca davvero di tante cose."** Nice,
not convinced, a lot missing. Not a rejection like Wick's, and not a
confirmation either: the verb is pleasant but the prototype is too bare to
carry it. What exactly is missing was not named — the next step is to name it
before building anything, rather than guessing and adding features.
