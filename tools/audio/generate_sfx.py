#!/usr/bin/env python3
"""Procedural retro SFX + chiptune loops for Rogue Fish (pure python, no deps).

Usage: python3 tools/audio/generate_sfx.py  -> assets/audio/sfx/*.wav
"""
from __future__ import annotations

import math
import os
import random
import struct
import wave

SR = 22050
ROOT = os.path.normpath(os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", ".."))
OUT = os.path.join(ROOT, "assets", "audio")


def write(name, samples, sub="sfx", sr=SR):
    path = os.path.join(OUT, sub, name + ".wav")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    peak = max(1e-6, max(abs(s) for s in samples))
    gain = min(1.0, 0.9 / peak)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s * gain)) * 32000)) for s in samples))


def env_adsr(n, a=0.005, d=0.05, s=0.6, r=0.1):
    a_n, d_n, r_n = int(a * SR), int(d * SR), int(r * SR)
    out = []
    for i in range(n):
        if i < a_n:
            v = i / max(1, a_n)
        elif i < a_n + d_n:
            v = 1 - (1 - s) * (i - a_n) / max(1, d_n)
        elif i > n - r_n:
            v = s * (n - i) / max(1, r_n)
        else:
            v = s
        out.append(v)
    return out


def osc(kind, phase):
    p = phase % 1.0
    if kind == "sine":
        return math.sin(p * math.tau)
    if kind == "square":
        return 1.0 if p < 0.5 else -1.0
    if kind == "pulse":
        return 1.0 if p < 0.25 else -1.0
    if kind == "saw":
        return 2 * p - 1
    if kind == "tri":
        return 4 * abs(p - 0.5) - 1
    return 0.0


def tone(dur, f0, f1=None, kind="square", vol=0.5, a=0.005, d=0.05, s=0.7, r=0.08, vib=0.0, curve=1.0):
    n = int(dur * SR)
    e = env_adsr(n, a, d, s, r)
    out = []
    ph = 0.0
    f1 = f0 if f1 is None else f1
    for i in range(n):
        t = i / n
        f = f0 + (f1 - f0) * (t ** curve)
        if vib:
            f *= 1 + vib * math.sin(i / SR * math.tau * 6)
        ph += f / SR
        out.append(osc(kind, ph) * e[i] * vol)
    return out


def noise(dur, vol=0.5, a=0.002, d=0.05, s=0.5, r=0.1, lp=0.5, seed=1):
    rnd = random.Random(seed)
    n = int(dur * SR)
    e = env_adsr(n, a, d, s, r)
    out = []
    y = 0.0
    for i in range(n):
        x = rnd.uniform(-1, 1)
        k = lp if not callable(lp) else lp(i / n)
        y += (x - y) * k
        out.append(y * e[i] * vol)
    return out


def mix(*tracks, offsets=None):
    offsets = offsets or [0] * len(tracks)
    n = max(len(t) + int(o * SR) for t, o in zip(tracks, offsets))
    out = [0.0] * n
    for t, o in zip(tracks, offsets):
        s = int(o * SR)
        for i, v in enumerate(t):
            out[s + i] += v
    return out


def seq(*parts):
    out = []
    for p in parts:
        out.extend(p)
    return out


def sfx():
    write("bite", mix(noise(0.12, 0.7, d=0.03, s=0.3, r=0.06, lp=0.35, seed=2), tone(0.08, 320, 90, "square", 0.35, s=0.4)))
    write("crunch", mix(noise(0.16, 0.8, d=0.04, s=0.4, r=0.08, lp=0.6, seed=3), noise(0.08, 0.6, lp=0.9, seed=4), offsets=[0, 0.05]))
    write("gulp", seq(tone(0.09, 220, 520, "sine", 0.7, s=0.8, r=0.03), tone(0.06, 180, 120, "sine", 0.5)))
    write("hit", mix(noise(0.08, 0.6, d=0.02, s=0.3, r=0.04, lp=0.45, seed=5), tone(0.07, 180, 70, "square", 0.3)))
    write("crit", mix(noise(0.1, 0.6, lp=0.7, seed=6), tone(0.14, 900, 1500, "pulse", 0.25, s=0.5)))
    write("hurt", mix(tone(0.22, 420, 120, "saw", 0.45, s=0.6, r=0.1), noise(0.12, 0.4, lp=0.3, seed=7)))
    write("bubble", tone(0.09, 500, 1300, "sine", 0.6, a=0.001, s=0.5, r=0.04, curve=0.6))
    write("zap", mix(noise(0.18, 0.5, lp=0.95, s=0.4, seed=8), tone(0.18, 1400, 300, "square", 0.25, vib=0.3)))
    write("spine", noise(0.1, 0.5, lp=lambda t: 0.9 - t * 0.7, a=0.001, s=0.4, seed=9))
    write("sonar", tone(0.5, 1250, 1180, "sine", 0.55, a=0.002, d=0.08, s=0.35, r=0.35))
    write("whirl", noise(0.5, 0.4, lp=lambda t: 0.08 + 0.2 * math.sin(t * math.pi * 3) ** 2, a=0.1, s=0.7, r=0.2, seed=10))
    write("explosion", mix(noise(0.45, 0.9, d=0.1, s=0.4, r=0.3, lp=lambda t: 0.5 - t * 0.45, seed=11), tone(0.3, 120, 40, "tri", 0.5)))
    write("pickup", tone(0.06, 1300, 1800, "pulse", 0.25, a=0.001, s=0.5, r=0.03))
    write("pearl", seq(tone(0.07, 1568, None, "tri", 0.4, s=0.6), tone(0.14, 2093, None, "tri", 0.4, s=0.6, r=0.1)))
    write("heal", seq(*[tone(0.06, f, None, "tri", 0.35) for f in (523, 659, 784, 1046)]))
    write("level_up", seq(*[tone(0.07, f, None, "square", 0.3, s=0.6) for f in (523, 659, 784, 1046, 1318)], tone(0.25, 1568, None, "square", 0.3, s=0.6, r=0.2)))
    write("card", mix(tone(0.12, 880, 1760, "pulse", 0.3, s=0.5), noise(0.08, 0.2, lp=0.8, seed=12)))
    write("click", tone(0.035, 900, 700, "square", 0.25, a=0.001, s=0.4, r=0.01))
    write("evolve", mix(seq(*[tone(0.09, 262 * 2 ** (k / 6), None, "tri", 0.35) for k in range(12)]),
                        noise(1.0, 0.15, lp=0.95, a=0.3, s=0.5, r=0.4, seed=13)))
    write("wave", seq(tone(0.3, 220, 233, "saw", 0.4, vib=0.02, s=0.8), tone(0.5, 196, 185, "saw", 0.4, vib=0.02, s=0.8, r=0.25)))
    write("boss_roar", mix(noise(1.3, 0.8, a=0.08, d=0.3, s=0.6, r=0.6, lp=lambda t: 0.1 + 0.1 * math.sin(t * 20) ** 2, seed=14),
                           tone(1.2, 90, 55, "saw", 0.5, vib=0.08, a=0.1, s=0.7, r=0.5)))
    write("boss_die", mix(noise(1.4, 0.9, d=0.4, s=0.4, r=0.8, lp=lambda t: 0.6 - t * 0.5, seed=15),
                          tone(1.2, 300, 40, "square", 0.3, s=0.6, r=0.6)))
    write("death", seq(*[tone(0.14, f, f * 0.95, "square", 0.3, s=0.7) for f in (392, 330, 262, 196)], tone(0.5, 131, 90, "square", 0.3)))
    write("chest", mix(noise(0.2, 0.5, lp=0.2, seed=16), seq(tone(0.1, 0, None), *[tone(0.08, f, None, "pulse", 0.3) for f in (784, 988, 1175, 1568)])))
    write("dash", noise(0.2, 0.5, lp=lambda t: 0.15 + t * 0.5, a=0.01, s=0.6, r=0.1, seed=17))
    write("warning", seq(tone(0.12, 880, None, "square", 0.3), tone(0.05, 0, None), tone(0.12, 880, None, "square", 0.3)))
    write("inflate", tone(0.3, 200, 700, "sine", 0.5, curve=0.5))
    write("ink", noise(0.3, 0.5, lp=0.12, a=0.01, s=0.6, r=0.2, seed=18))
    write("thorn", mix(noise(0.06, 0.5, lp=0.9, seed=19), tone(0.06, 1800, 1200, "square", 0.2)))


# Music lives in tools/audio/compose_music.py.


if __name__ == "__main__":
    sfx()
    print("audio done")
