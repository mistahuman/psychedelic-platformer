#!/usr/bin/env python3
"""Turns a song into the data the terrain is built from.

    python3 tools/analyse_song.py ~/Music/some_song.mp3     # from prototypes/07-song-surf

Writes songs/<slug>.ogg (what the game plays) and songs/<slug>.json (what it
builds the hills from). songs/ is gitignored: the songs are yours, not the repo's.

No numpy, no librosa. ffmpeg does the decoding and the filtering, this does the
arithmetic, which is light because everything happens on 10 ms envelopes rather
than on samples:

  - loudness: RMS of the full signal per 10 ms frame, normalised to 0..1
  - low:      RMS of the signal under 150 Hz (kick and bass), same scale
  - tempo:    autocorrelation of the positive change in `low` over 70-180 BPM
  - beats:    the phase of that grid which lands on the most onset energy, then
              refined by fitting a line through the actual onset peaks near
              each grid beat — a 0.1% tempo error is 0.2 s of drift by the end

Tempo tracking assumes one steady tempo. Pop, dance and rock are fine; a song
that speeds up or has no drums will get a grid that drifts, and the hills will
stop landing on the kick. Good enough to find out whether the idea is fun.
"""

import json
import math
import os
import re
import struct
import subprocess
import sys

RATE = 8000
HOP = 80  # 10 ms
FRAME_S = HOP / RATE
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))


def decode(path, filt=None):
    cmd = ["ffmpeg", "-v", "error", "-i", path, "-ac", "1", "-ar", str(RATE)]
    if filt:
        cmd += ["-af", filt]
    cmd += ["-f", "s16le", "-"]
    raw = subprocess.run(cmd, check=True, capture_output=True).stdout
    return struct.unpack("<%dh" % (len(raw) // 2), raw)


def envelope(samples):
    out = []
    for i in range(0, len(samples) - HOP + 1, HOP):
        acc = 0
        for s in samples[i:i + HOP]:
            acc += s * s
        out.append(math.sqrt(acc / HOP))
    return out


def normalise(values):
    ranked = sorted(values)
    top = ranked[int(len(ranked) * 0.97)] or 1.0
    return [min(v / top, 1.0) for v in values]


def smooth(values, radius):
    out, acc, n = [], 0.0, 0
    window = []
    for v in values:
        window.append(v)
        acc += v
        if len(window) > 2 * radius + 1:
            acc -= window.pop(0)
        out.append(acc / len(window))
    # centre the moving average
    return out[radius:] + [out[-1]] * radius


def tempo(onset):
    best_lag, best = 0, -1.0
    scores = {}
    lo, hi = int(60 / 180 / FRAME_S), int(60 / 70 / FRAME_S) + 1
    for lag in range(lo, hi + 1):
        s = 0.0
        for i in range(len(onset) - lag):
            s += onset[i] * onset[i + lag]
        scores[lag] = s
        if s > best:
            best, best_lag = s, lag
    # parabolic refinement: a 10 ms grid is too coarse over three minutes
    a, b, c = scores.get(best_lag - 1, best), best, scores.get(best_lag + 1, best)
    denom = a - 2 * b + c
    shift = 0.5 * (a - c) / denom if denom else 0.0
    return (best_lag + shift) * FRAME_S


def phase(onset, period):
    best_off, best = 0.0, -1.0
    steps = 40
    for k in range(steps):
        off = period * k / steps
        s, t = 0.0, off
        while t < len(onset) * FRAME_S:
            i = int(t / FRAME_S)
            s += max(onset[max(i - 1, 0):i + 2])
            t += period
        if s > best:
            best, best_off = s, off
    return best_off


def refine(onset, period, offset, duration):
    """Least-squares fit of beat k -> time through the strongest onset near each
    grid beat, weighted by its strength. Two passes, the window shrinking."""
    for window in (0.08, 0.04):
        n = int((duration - offset) / period)
        sw = sk = st = skk = skt = 0.0
        for k in range(n):
            t = offset + k * period
            lo = max(int((t - window) / FRAME_S), 0)
            hi = min(int((t + window) / FRAME_S) + 1, len(onset))
            if hi <= lo:
                continue
            i = max(range(lo, hi), key=lambda j: onset[j])
            w = onset[i]
            if w <= 0.0:
                continue
            # the rise happens inside the frame, so its middle is the best guess
            tk = (i + 0.5) * FRAME_S
            sw += w; sk += w * k; st += w * tk; skk += w * k * k; skt += w * k * tk
        det = sw * skk - sk * sk
        if det <= 0.0:
            break
        period = (sw * skt - sk * st) / det
        offset = (st - period * sk) / sw
    while offset - period >= 0.0:
        offset -= period
    return period, offset


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    src = os.path.expanduser(sys.argv[1])
    stem = os.path.splitext(os.path.basename(src))[0]
    slug = re.sub(r"[^a-z0-9]+", "-", stem.lower()).strip("-")[:48]

    full = normalise(envelope(decode(src)))
    low = normalise(envelope(decode(src, "lowpass=f=150,lowpass=f=150")))
    onset = [max(low[i] - low[i - 1], 0.0) for i in range(1, len(low))] + [0.0]

    period = tempo(onset)
    offset = phase(onset, period)
    duration = len(full) * FRAME_S
    period, offset = refine(onset, period, offset, duration)
    beats = []
    t = offset
    while t < duration:
        beats.append(round(t, 4))
        t += period

    # 10 Hz is plenty for hill heights, and keeps the json small.
    loud = smooth(full, 25)[::10]
    lows = smooth(low, 25)[::10]

    os.makedirs(os.path.join(ROOT, "songs"), exist_ok=True)
    ogg = os.path.join(ROOT, "songs", slug + ".ogg")
    subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", src, "-vn", "-c:a", "libvorbis", "-q:a", "5", ogg], check=True)
    data = {
        "title": stem.replace("_", " "),
        "audio": slug + ".ogg",
        "duration": round(duration, 3),
        "bpm": round(60 / period, 2),
        "beats": beats,
        "envelope_hz": 10,
        "loudness": [round(v, 3) for v in loud],
        "low": [round(v, 3) for v in lows],
    }
    with open(os.path.join(ROOT, "songs", slug + ".json"), "w") as f:
        json.dump(data, f)
    print("%s  %.1f s  %.1f bpm  %d beats" % (slug, duration, data["bpm"], len(beats)))


if __name__ == "__main__":
    main()
