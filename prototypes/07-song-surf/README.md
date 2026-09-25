# 07 — Song surf

**Question:** is surfing your own song fun — does holding your speed to the
music feel like riding it, or like watching a meter?

Pick a song you like. It becomes a landscape: the valleys fall on the beat and
the hills are as tall as the song is loud, so a quiet verse is a gentle roll and
the chorus is a mountain range. Hold to dive down the hills, let go to fly off
them — the gesture is *Tiny Wings*.

The music is a wave moving through that landscape at a fixed speed, and you ride
just in front of it. Let it pass you and the song goes muffled, as if it were
playing in the next room. Run too far ahead and it goes thin, and you slow down
in dead water. The run lasts exactly as long as the song.

## Adding songs

Songs are yours, not the repo's: `songs/` is gitignored. From this folder:

```bash
python3 tools/analyse_song.py ~/Music/mp3/some_song.mp3
```

Needs `ffmpeg`, nothing else. It writes `songs/<name>.ogg` and
`songs/<name>.json` in a few seconds. Songs with a steady beat work best: pop,
dance, rock. A song that changes tempo or has no drums will get hills that
drift off the kick.

## Playing it

Open **this folder** as a Godot 4 project, then F5. Or `make run P=07` from the
repo root.

| Key | Action |
| --- | --- |
| `↑` `↓` | pick a song |
| `Space` / `Enter` | go |
| `Space` (or left click), **held** | dive: heavy on the way down |
| release `Space` | light: fly off the crest |
| `R` / `Esc` | back to the song list |

## Reading the screen

| What you see | What it means |
| --- | --- |
| Glowing vertical line | where the music is right now — ride just in front of it |
| "on the wave" | you are in the pocket |
| "the wave passed you" | behind: dive to catch up. The song sounds muffled |
| "too far ahead" | out in dead water: ease off. The song sounds thin |
| Warm, tall hills | loud part of the song |
| Cyan ring on landing | a perfect landing along a downslope |

## Debug keys

Hidden at start. `F1` shows it.

| Key | Action |
| --- | --- |
| `F1` | show/hide the overlay |
| `[` `]` | dive strength down / up |
| `,` `.` | gravity down / up |
| `9` `0` | minimum speed down / up |
| `-` `=` | song speed in px/s — takes effect on the next run |

## What to watch during the test

- **The one question:** does it feel like the song is carrying you, or like you
  are managing a number? Play one song you love and one you do not care about.
  If the difference is not felt, the "your songs" hook is not doing anything.
- Do you *hear* falling behind before you read it? The muffling is meant to be
  the main signal, not the text.
- Are you landing in the valleys on the kick? That is what being on the wave
  should feel like. If it never lines up, the beat tracking is off for that
  song — note which.
- The skill is holding speed, not maximising it. Does that read, or does
  "too far ahead" feel like being punished for playing well?

## Measuring

`tools/surf_bot.gd` surfs a song headless with a fixed policy and reports the
share of the song spent on the wave:

```bash
godot --headless --path . --fixed-fps 60 -s tools/surf_bot.gd -- sync 0
```

Policies: `never`, `always`, `slopes` (dive on every downslope), `sync` (dive
on downslopes only when not ahead). The second argument is the song index in
the menu. A third overrides the in-pocket push.

## Files

```
scripts/song.gd            the song as terrain: pure functions of x
scripts/surfer.gd          Tiny Wings physics against that function
scripts/game.gd            menu, run, result, the wave, the audio filters
scripts/terrain_view.gd    draws the visible hills, and the playhead
scripts/debug_overlay.gd   in-game tuning
tools/analyse_song.py      mp3 → ogg + beats and loudness (ffmpeg, no numpy)
tools/surf_bot.gd          headless ruler
```

Why the wave only slows you down and never pushes, and what the bot measured,
are in [`../../docs/design-notes.md`](../../docs/design-notes.md).
