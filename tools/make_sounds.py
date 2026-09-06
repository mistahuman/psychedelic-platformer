#!/usr/bin/env python3
"""Generates every sound in game/audio/ from scratch.

No sourced assets: the whole palette is a few sine waves, filtered noise and
envelopes. Committed as a script rather than only as .wav files so the sounds
can be re-tuned rather than replaced — change a number here, run it, hear it.

    python3 tools/make_sounds.py

Looping sounds (drone, door, heartbeat) only use frequencies that are integer
multiples of 1/duration, so the waveform meets itself exactly at the seam and
loops without a click. That constraint is why the frequencies look odd.
"""

import math
import os
import random
import struct
import wave

RATE = 44100
OUT = os.path.join(os.path.dirname(os.path.dirname(os.path.abspath(__file__))), "game", "audio")


def write(name, samples):
    peak = max(abs(s) for s in samples) or 1.0
    if peak > 1.0:
        samples = [s / peak for s in samples]
    path = os.path.join(OUT, name)
    with wave.open(path, "w") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(b"".join(
            struct.pack("<h", int(max(-1.0, min(1.0, s)) * 32000)) for s in samples
        ))
    print("  %-16s %5.2fs" % (name, len(samples) / RATE))


def sine(buf, freq, amp, start=0.0, dur=None, phase=0.0):
    a = int(start * RATE)
    b = len(buf) if dur is None else min(len(buf), a + int(dur * RATE))
    for i in range(a, b):
        buf[i] += amp * math.sin(2 * math.pi * freq * (i - a) / RATE + phase)


def decay(buf, tau, start=0.0):
    a = int(start * RATE)
    for i in range(a, len(buf)):
        buf[i] *= math.exp(-(i - a) / (tau * RATE))


def noise(n, cutoff, seed=0):
    """White noise through a one-pole low-pass. cutoff is 0..1 (1 = untouched)."""
    rng = random.Random(seed)
    out, y = [], 0.0
    for _ in range(n):
        y += cutoff * (rng.uniform(-1.0, 1.0) - y)
        out.append(y)
    return out


def blank(seconds):
    return [0.0] * int(seconds * RATE)


# --- the room ---------------------------------------------------------------

def drone():
    """8 s seamless bed. Detuned low sines beating slowly against each other:
    the beat is what makes a held tone feel uneasy rather than restful."""
    d = 8.0
    buf = blank(d)
    for freq, amp in [(55.0, 0.30), (55.125, 0.26), (82.5, 0.11), (110.0, 0.07), (164.5, 0.03)]:
        sine(buf, freq, amp)
    for i in range(len(buf)):
        # One full LFO cycle across the loop, so the seam lands at the same value.
        buf[i] *= 0.55 + 0.45 * (0.5 - 0.5 * math.cos(2 * math.pi * i / len(buf)))
    return [s * 0.34 for s in buf]


def door_hum():
    """4 s seamless. Warmer and higher than the drone so it reads as a promise
    rather than as part of the room. Played positionally from the exit."""
    d = 4.0
    buf = blank(d)
    for freq, amp in [(110.0, 0.30), (165.0, 0.20), (220.0, 0.12), (330.0, 0.05)]:
        sine(buf, freq, amp)
    for i in range(len(buf)):
        buf[i] *= 0.7 + 0.3 * math.sin(2 * math.pi * i / len(buf))
    return [s * 0.5 for s in buf]


def heartbeat():
    """1 s loop, two thumps. Starts when the wick gets low; the tempo of dread
    without needing a number on screen."""
    buf = blank(1.0)
    for at, amp in [(0.0, 1.0), (0.30, 0.72)]:
        thump = blank(0.22)
        sine(thump, 58.0, amp)
        sine(thump, 41.0, amp * 0.6)
        decay(thump, 0.045)
        a = int(at * RATE)
        for i, s in enumerate(thump):
            if a + i < len(buf):
                buf[a + i] += s
    return [s * 0.55 for s in buf]


# --- the player -------------------------------------------------------------

def step(seed, pitch):
    """Soft scuff: a filtered noise burst with a little body under it."""
    buf = blank(0.14)
    n = noise(len(buf), 0.16, seed)
    for i in range(len(buf)):
        buf[i] = n[i] * 0.9
    sine(buf, pitch, 0.5)
    decay(buf, 0.026)
    return [s * 0.30 for s in buf]


# --- the mechanic -----------------------------------------------------------

def caught():
    """The signature sound: the moment the lantern catches your memory being
    wrong. A tritone, which never resolves, snapped off short — plus a downward
    scrape underneath. It has to land as 'something is off', not as a reward."""
    buf = blank(0.55)
    sine(buf, 622.0, 0.55, dur=0.30)
    sine(buf, 880.0, 0.45, dur=0.30)
    sine(buf, 311.0, 0.30, dur=0.35)
    decay(buf, 0.085)

    scrape = blank(0.4)
    n = noise(len(scrape), 0.5, 7)
    for i in range(len(scrape)):
        t = i / RATE
        f = 900.0 * math.exp(-3.2 * t) + 120.0
        scrape[i] = 0.30 * math.sin(2 * math.pi * f * t) + 0.16 * n[i]
    decay(scrape, 0.12)
    for i, s in enumerate(scrape):
        buf[i] += s

    # A single short echo: the maze is a big empty place.
    delay = int(0.085 * RATE)
    for i in range(len(buf) - 1, delay - 1, -1):
        buf[i] += buf[i - delay] * 0.28
    return [s * 0.5 for s in buf]


def oil():
    """Warm and rising. The only unambiguously good thing that happens."""
    buf = blank(0.7)
    for freq, at in [(392.0, 0.0), (523.25, 0.045), (659.25, 0.09), (783.99, 0.135)]:
        part = blank(0.7 - at)
        sine(part, freq, 0.4)
        sine(part, freq * 2, 0.12)
        decay(part, 0.20)
        a = int(at * RATE)
        for i, s in enumerate(part):
            if a + i < len(buf):
                buf[a + i] += s
    return [s * 0.42 for s in buf]


def escaped():
    """Resolves. Slow attack so it feels like relief rather than a fanfare."""
    buf = blank(2.2)
    for freq, amp in [(146.83, 0.34), (220.0, 0.26), (293.66, 0.22), (440.0, 0.14), (587.33, 0.09)]:
        sine(buf, freq, amp)
    for i in range(len(buf)):
        t = i / RATE
        buf[i] *= min(1.0, t / 0.25) * math.exp(-t / 1.5)
    return [s * 0.5 for s in buf]


def burnt_out():
    """The wick going out: everything slides down and stops."""
    buf = blank(2.0)
    n = noise(len(buf), 0.25, 3)
    for i in range(len(buf)):
        t = i / RATE
        f = 320.0 * math.exp(-1.5 * t) + 32.0
        buf[i] = 0.45 * math.sin(2 * math.pi * f * t) + 0.20 * n[i] * math.exp(-t * 1.2)
    for i in range(len(buf)):
        buf[i] *= math.exp(-(i / RATE) / 0.85)
    return [s * 0.55 for s in buf]


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    print("writing to", OUT)
    write("drone.wav", drone())
    write("door.wav", door_hum())
    write("heartbeat.wav", heartbeat())
    write("step_a.wav", step(11, 78.0))
    write("step_b.wav", step(29, 68.0))
    write("caught.wav", caught())
    write("oil.wav", oil())
    write("escaped.wav", escaped())
    write("burnt_out.wav", burnt_out())
