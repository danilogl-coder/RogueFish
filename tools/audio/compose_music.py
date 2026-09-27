"""RogueFish soundtrack composer: a small synth + sequencer in numpy.

Renders every music track of the game to OGG Vorbis (seamless loops):

  menu            "Maré Mansa"      G lydian, 90 bpm, lush pads and a music-box bell
  explore_base    "Recife Vivo"     D major, 118 bpm, calm layer (always playing)
  explore_drive   "Recife Vivo"     same grid, drums/bass/saw-lead layer faded in
                                    by danger (waves, combo): adaptive music
  boss            "Mandíbulas"      A harmonic minor, 140 bpm, heroic and driving
  final           "Devorador"       D phrygian dominant, 120 bpm, choir + ostinato
  stingers        level-up (in D), victory fanfare, defeat, fusion

Design notes (see docs/DESIGN.md, "Música"):
  * one hook per track, repeated and varied (A A' B C) so it sticks;
  * tension -> release: section C lifts to the top of the range, a drum fill
    and a riser lead back to the hook;
  * adaptive layering instead of track switching during a run: the calm and
    the drive stems share tempo and length and play in sync;
  * reward sounds are in the key of the gameplay track (D major);
  * soft timbres, gentle high end and 60+ second loops against fatigue.

Usage: python3 tools/audio/compose_music.py [track ...]
"""
from __future__ import annotations

import math
import os
import sys

import numpy as np
import soundfile as sf
from scipy import signal

SR = 32000
OUT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "audio", "music")
RNG = np.random.default_rng(7)

NOTE = {n: i for i, n in enumerate(["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"])}
FLAT = {"Db": "C#", "Eb": "D#", "Gb": "F#", "Ab": "G#", "Bb": "A#"}


def midi(name: str) -> int:
    n, o = name[:-1], int(name[-1])
    n = FLAT.get(n, n)
    return NOTE[n] + (o + 1) * 12


def hz(m: float) -> float:
    return 440.0 * 2 ** ((m - 69) / 12)


# ================================================================ DSP bits
def env_adsr(n, a, d, s, r, gate):
    """ADSR with the release starting at `gate` samples."""
    t = np.arange(n) / SR
    g = gate / SR
    e = np.where(t < a, t / max(a, 1e-4), s + (1 - s) * np.exp(-(t - a) / max(d, 1e-4)))
    rel_start = np.interp(g, t, e) if gate < n else e[-1]
    e = np.where(t > g, rel_start * np.exp(-(t - g) / max(r, 1e-4)), e)
    return e


def _blep(t, dt):
    y = np.zeros_like(t)
    m = t < dt
    x = t[m] / dt[m] if np.ndim(dt) else t[m] / dt
    y[m] = x + x - x * x - 1
    m2 = t > 1 - dt
    x2 = (t[m2] - 1) / (dt[m2] if np.ndim(dt) else dt)
    y[m2] = x2 * x2 + x2 + x2 + 1
    return y


def phase_of(freq):
    return np.cumsum(freq / SR) % 1.0


def saw(freq):
    ph = phase_of(freq)
    return 2 * ph - 1 - _blep(ph, freq / SR)


def square(freq, pw=0.5):
    ph = phase_of(freq)
    dt = freq / SR
    s1 = 2 * ph - 1 - _blep(ph, dt)
    ph2 = (ph + pw) % 1.0
    s2 = 2 * ph2 - 1 - _blep(ph2, dt)
    return (s1 - s2) * 0.5


def sine(freq):
    return np.sin(2 * np.pi * phase_of(freq))


def tri(freq):
    ph = phase_of(freq)
    return 1 - 4 * np.abs(ph - 0.5)


def lowpass(x, fc, q=0.707):
    fc = min(fc, SR * 0.45)
    b, a = signal.iirfilter(2, fc / (SR / 2), btype="low", ftype="butter")
    return signal.lfilter(b, a, x)


def highpass(x, fc):
    b, a = signal.iirfilter(2, fc / (SR / 2), btype="high", ftype="butter")
    return signal.lfilter(b, a, x)


def bandpass(x, lo, hi):
    b, a = signal.iirfilter(2, [lo / (SR / 2), min(hi, SR * 0.45) / (SR / 2)], btype="band", ftype="butter")
    return signal.lfilter(b, a, x)


def noise(n):
    return RNG.uniform(-1, 1, n)


def vibrato(n, f, depth_semi=0.12, rate=5.5, delay=0.18):
    t = np.arange(n) / SR
    ramp = np.clip((t - delay) / 0.25, 0, 1)
    return f * 2 ** (depth_semi * ramp * np.sin(2 * np.pi * rate * t) / 12)


# ============================================================ instruments
def inst_pad(f, n, gate, bright=1800.0):
    out = np.zeros(n)
    for det in (-0.11, 0.0, 0.12):
        out += saw(np.full(n, f * 2 ** (det / 12)))
    out = lowpass(out / 3, bright)
    return out * env_adsr(n, 0.35, 0.8, 0.8, 0.7, gate)


def inst_pluck(f, n, gate, damp=0.996, tone=4200.0):
    """Karplus-Strong pluck (harp / kalimba feel)."""
    p = max(2, int(round(SR / f)))
    burst = lowpass(noise(p), tone)
    x = np.zeros(n)
    x[:p] = burst
    a = np.zeros(p + 2)
    a[0] = 1.0
    a[p] = -damp * 0.5
    a[p + 1] = -damp * 0.5
    y = signal.lfilter([1.0], a, x)
    return y * env_adsr(n, 0.001, 0.4, 0.9, 0.15, gate) * 0.8


def inst_bell(f, n, gate, ratio=3.5, index=2.2, decay=0.9):
    t = np.arange(n) / SR
    ienv = index * np.exp(-t / 0.35)
    mod = np.sin(2 * np.pi * f * ratio * t)
    car = np.sin(2 * np.pi * f * t + ienv * mod)
    e = np.exp(-t / decay) * np.clip(t / 0.003, 0, 1)
    e *= np.where(t > gate / SR + 0.4, np.exp(-(t - gate / SR - 0.4) / 0.2), 1.0)
    return car * e


def inst_epiano(f, n, gate):
    return inst_bell(f, n, gate, ratio=1.0, index=1.4, decay=1.4)


def inst_lead(f, n, gate, cutoff=3600.0, vib=0.12):
    fr = vibrato(n, f, vib)
    x = 0.55 * saw(fr) + 0.35 * saw(fr * 1.004) + 0.35 * square(fr * 0.5, 0.35)
    bright = lowpass(x, cutoff)
    dark = lowpass(x, cutoff * 0.35)
    fe = np.exp(-np.arange(n) / SR / 0.18)
    y = dark + (bright - dark) * (0.45 + 0.55 * fe)
    return y * env_adsr(n, 0.008, 0.25, 0.75, 0.12, gate) * 0.55


def inst_softlead(f, n, gate):
    """Flute-ish square with breath: the calm layer's melody."""
    fr = vibrato(n, f, 0.1, 5.0, 0.25)
    x = lowpass(square(fr, 0.42), 2400) + 0.05 * bandpass(noise(n), 1500, 5000)
    return x * env_adsr(n, 0.03, 0.3, 0.8, 0.15, gate) * 0.5


def inst_bass(f, n, gate, cutoff=700.0):
    x = 0.6 * sine(np.full(n, f)) + 0.5 * lowpass(saw(np.full(n, f)), cutoff)
    fe = np.exp(-np.arange(n) / SR / 0.07)
    x = x + 0.25 * lowpass(saw(np.full(n, f)), cutoff * 3) * fe
    return x * env_adsr(n, 0.004, 0.2, 0.85, 0.06, gate) * 0.7


def inst_sub(f, n, gate):
    return sine(np.full(n, f)) * env_adsr(n, 0.02, 0.3, 0.9, 0.2, gate) * 0.6


def inst_choir(f, n, gate):
    x = np.zeros(n)
    for det in (-0.15, -0.05, 0.05, 0.15):
        x += saw(vibrato(n, f * 2 ** (det / 12), 0.08, 4.5 + det * 4, 0.1))
    ah = bandpass(x, 600, 900) + 0.7 * bandpass(x, 1050, 1350) + 0.25 * bandpass(x, 2300, 2700)
    return ah * env_adsr(n, 0.4, 0.6, 0.85, 0.8, gate) * 0.35


def inst_brass(f, n, gate):
    fr = vibrato(n, f, 0.08, 5.0, 0.3)
    x = saw(fr) + 0.6 * saw(fr * 1.003)
    t = np.arange(n) / SR
    cut = 600 + 2600 * np.clip(t / 0.09, 0, 1)
    y = lowpass(x, 3200) * np.clip(t / 0.09, 0.25, 1) + lowpass(x, 700) * (1 - np.clip(t / 0.09, 0, 1))
    del cut
    return y * env_adsr(n, 0.03, 0.3, 0.8, 0.2, gate) * 0.45


def inst_ostinato(f, n, gate):
    x = saw(np.full(n, f)) + 0.5 * square(np.full(n, f * 2), 0.3)
    return lowpass(x, 1400) * env_adsr(n, 0.004, 0.08, 0.5, 0.05, gate) * 0.5


INSTR = {"pad": inst_pad, "pluck": inst_pluck, "bell": inst_bell, "epiano": inst_epiano, "lead": inst_lead,
         "softlead": inst_softlead, "bass": inst_bass, "sub": inst_sub, "choir": inst_choir,
         "brass": inst_brass, "ostinato": inst_ostinato}


# ================================================================== drums
def dr_kick(v=1.0):
    n = int(0.45 * SR)
    t = np.arange(n) / SR
    f = 48 + 120 * np.exp(-t / 0.028)
    x = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 0.3)
    x[:96] += noise(96) * np.linspace(0.6, 0, 96)
    return np.tanh(x * 1.6) * 0.9 * v


def dr_softkick(v=1.0):
    return lowpass(dr_kick(v), 900) * 0.8


def dr_snare(v=1.0):
    n = int(0.3 * SR)
    t = np.arange(n) / SR
    body = np.sin(2 * np.pi * 185 * t) * np.exp(-t / 0.06)
    nz = highpass(noise(n), 1400) * np.exp(-t / 0.12)
    return (0.5 * body + 0.8 * nz) * 0.6 * v


def dr_clap(v=1.0):
    n = int(0.35 * SR)
    t = np.arange(n) / SR
    e = np.zeros(n)
    for k in range(3):
        s = int(k * 0.011 * SR)
        e[s:] += np.exp(-(t[: n - s]) / 0.012)
    e += 0.6 * np.exp(-t / 0.13)
    return bandpass(noise(n), 900, 2600) * e * 0.5 * v


def dr_hat(v=1.0, open_=False):
    n = int((0.35 if open_ else 0.06) * SR)
    t = np.arange(n) / SR
    x = highpass(noise(n), 7000) * np.exp(-t / (0.14 if open_ else 0.022))
    return x * 0.35 * v


def dr_shaker(v=1.0):
    n = int(0.09 * SR)
    t = np.arange(n) / SR
    e = np.clip(t / 0.012, 0, 1) * np.exp(-t / 0.035)
    return highpass(noise(n), 5000) * e * 0.3 * v


def dr_rim(v=1.0):
    n = int(0.08 * SR)
    t = np.arange(n) / SR
    return (np.sin(2 * np.pi * 1700 * t) * 0.5 + bandpass(noise(n), 2000, 6000)) * np.exp(-t / 0.018) * 0.35 * v


def dr_tom(v=1.0, f0=160):
    n = int(0.45 * SR)
    t = np.arange(n) / SR
    f = f0 * (0.6 + 0.4 * np.exp(-t / 0.08))
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 0.22) * 0.7 * v


def dr_crash(v=1.0):
    n = int(2.2 * SR)
    t = np.arange(n) / SR
    metal = sum(np.sin(2 * np.pi * fr * t) for fr in (3150, 4390, 5870, 7120)) * 0.08
    x = (highpass(noise(n), 3500) + metal) * np.exp(-t / 0.9)
    return x * 0.3 * v


def dr_riser(seconds):
    n = int(seconds * SR)
    t = np.arange(n) / SR
    x = noise(n)
    out = np.zeros(n)
    blocks = 16
    for b in range(blocks):
        s, e = b * n // blocks, (b + 1) * n // blocks
        lo = 400 + 5000 * (b / blocks) ** 2
        out[s:e] = bandpass(x[s:e], lo, lo * 2.2)
    return out * (t / seconds) ** 2 * 0.35


DRUM = {"K": dr_kick, "k": dr_softkick, "S": dr_snare, "C": dr_clap, "h": dr_hat,
        "o": lambda v=1.0: dr_hat(v, True), "s": dr_shaker, "r": dr_rim, "X": dr_crash,
        "T": lambda v=1.0: dr_tom(v, 190), "t": lambda v=1.0: dr_tom(v, 130)}


# ============================================================ sequencing
class Song:
    """A song on a 16th-note grid. Voices are rendered to named buses."""

    def __init__(self, bpm: float, bars: int, tail=2.5):
        self.bpm = bpm
        self.bars = bars
        self.step = 60.0 / bpm / 4
        self.length = int(round(bars * 16 * self.step * SR))
        self.n = self.length + int(tail * SR)
        self.buses: dict[str, np.ndarray] = {}
        self.kicks: list[int] = []

    def pos(self, step: float) -> int:
        return int(round(step * self.step * SR))

    def bus(self, name):
        if name not in self.buses:
            self.buses[name] = np.zeros((self.n, 2))
        return self.buses[name]

    def add(self, busname, start, mono, vol=1.0, pan=0.0):
        b = self.bus(busname)
        e = min(self.n, start + len(mono))
        if e <= start:
            return
        l = math.cos((pan + 1) * math.pi / 4)
        r = math.sin((pan + 1) * math.pi / 4)
        b[start:e, 0] += mono[: e - start] * vol * l
        b[start:e, 1] += mono[: e - start] * vol * r

    def note(self, busname, inst, m, step, length, vol=1.0, pan=0.0, **kw):
        gate = self.pos(length)
        ring = {"pad": 1.6, "bell": 1.8, "pluck": 1.2, "choir": 1.5, "epiano": 1.6}.get(inst, 0.5)
        n = gate + int(ring * SR)
        self.add(busname, self.pos(step), INSTR[inst](hz(m), n, gate, **kw), vol, pan)

    def melody(self, busname, inst, bars, start_bar=0, vol=1.0, pan=0.0, octave=0, **kw):
        """bars: list of strings of 'NOTE:len' tokens ('_' = rest), 16 steps per bar."""
        for bi, bar in enumerate(bars):
            step = (start_bar + bi) * 16
            used = 0
            for tok in bar.split():
                name, ln = tok.split(":")
                ln = float(ln)
                if name != "_":
                    self.note(busname, inst, midi(name) + 12 * octave, step + used, ln * 0.95, vol, pan, **kw)
                used += ln
            assert abs(used - 16) < 1e-6, f"bar {start_bar + bi} has {used} steps: {bar}"

    def drums(self, busname, pattern, start_bar, bars, vol=1.0, pan_map=None):
        """pattern: dict char -> 16-char string per bar ('.' empty, char or
        digit 1-9 for velocity)."""
        pan_map = pan_map or {}
        for b in range(bars):
            for ch, line in pattern.items():
                for i, c in enumerate(line):
                    if c == ".":
                        continue
                    v = 1.0 if not c.isdigit() else int(c) / 9.0
                    step = (start_bar + b) * 16 + i
                    self.add(busname, self.pos(step), DRUM[ch](v), vol, pan_map.get(ch, 0.0))
                    if ch == "K":
                        self.kicks.append(self.pos(step))

    def fx(self, busname, mono, step, vol=1.0):
        self.add(busname, self.pos(step), mono, vol)


def chord_notes(name, octave=3):
    """'Dmaj7', 'Bm7', 'A', 'Asus', 'F#m7', 'E7', 'Cm', 'Eb'... -> midi list."""
    import re
    mm = re.match(r"([A-G][b#]?)(.*)", name)
    root, q = mm.group(1), mm.group(2)
    r = midi(root + str(octave))
    iv = {"": [0, 4, 7], "m": [0, 3, 7], "maj7": [0, 4, 7, 11], "m7": [0, 3, 7, 10], "7": [0, 4, 7, 10],
          "sus": [0, 5, 7], "6": [0, 4, 7, 9], "m9": [0, 3, 7, 10, 14], "add9": [0, 4, 7, 14],
          "maj7#11": [0, 4, 7, 11, 18]}[q]
    return [r + i for i in iv]


# ================================================================== mixing
def reverb_ir(seconds=2.2, damp=5000.0, seed=3):
    n = int(seconds * SR)
    t = np.arange(n) / SR
    rng = np.random.default_rng(seed)
    ir = np.stack([rng.uniform(-1, 1, n), rng.uniform(-1, 1, n)], 1)
    ir *= np.exp(-t / (seconds / 5.5))[:, None]
    ir[:, 0] = lowpass(ir[:, 0], damp)
    ir[:, 1] = lowpass(ir[:, 1], damp)
    ir[: int(0.012 * SR)] = 0  # predelay
    return ir / np.sqrt((ir ** 2).sum(0))


def reverb(x, amount, seconds=2.2):
    ir = reverb_ir(seconds)
    wet = np.stack([signal.fftconvolve(x[:, c], ir[:, c])[: len(x)] for c in range(2)], 1)
    return wet * amount


def pingpong(x, song, feedback=0.38, mix=0.3, steps=3):
    d = song.pos(steps)
    out = np.zeros_like(x)
    src = x.copy()
    for k in range(1, 5):
        g = mix * feedback ** (k - 1)
        sh = np.zeros_like(x)
        sh[d * k:] = src[: len(x) - d * k]
        ch = k % 2
        out[:, ch] += (sh[:, 0] + sh[:, 1]) * 0.5 * g
    return lowpass_st(out, 3500)


def lowpass_st(x, fc):
    return np.stack([lowpass(x[:, 0], fc), lowpass(x[:, 1], fc)], 1)


def highpass_st(x, fc):
    return np.stack([highpass(x[:, 0], fc), highpass(x[:, 1], fc)], 1)


def duck(song, depth=0.45, release=0.16):
    g = np.ones(song.n)
    t = np.arange(int(release * 5 * SR)) / SR
    shape = 1 - depth * np.exp(-t / release)
    for k in song.kicks:
        e = min(song.n, k + len(shape))
        g[k:e] = np.minimum(g[k:e], shape[: e - k])
    return g[:, None]


def mixdown(song, spec, sidechain=0.0):
    """spec: bus -> (gain, reverb_send, delay_send). Returns stereo float."""
    dry = np.zeros((song.n, 2))
    send = np.zeros((song.n, 2))
    dly = np.zeros((song.n, 2))
    g_duck = duck(song, sidechain) if sidechain > 0 and song.kicks else 1.0
    for name, (gain, rv, dl, *opt) in spec.items():
        if name not in song.buses:
            continue
        b = song.buses[name] * gain
        if opt and opt[0] == "duck":
            b = b * g_duck
        dry += b
        send += b * rv
        dly += b * dl
    wet = reverb(send, 1.0)
    if np.any(dly):
        wet += pingpong(dly, song)
    return dry + wet


def loop_wrap(x, length):
    """Folds the tail (reverb/delay ring) back onto the start: seamless loop."""
    out = x[:length].copy()
    tail = x[length:]
    out[: len(tail)] += tail[: length]
    return out


def master(x, gain=1.0):
    x = highpass_st(x, 28)
    x = np.tanh(x * gain * 1.15) / np.tanh(1.15)
    return x


def write(name, x):
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, name + ".ogg")
    sf.write(path, np.clip(x, -1, 1).astype(np.float32), SR, format="OGG", subtype="VORBIS",
             compression_level=0.8)
    peak = np.abs(x).max()
    rms = np.sqrt((x ** 2).mean())
    print(f"  {name}.ogg  {len(x) / SR:5.1f}s  peak {peak:.2f}  rms {20 * np.log10(rms + 1e-9):5.1f} dB  {os.path.getsize(path) // 1024} KB")


def normalize_pair(*tracks, target=0.89):
    total = sum(tracks)
    k = target / max(1e-6, np.abs(total).max())
    return [t * k for t in tracks]


# ================================================================ tracks
def chords_track(song, bus, prog, inst="pad", octave=3, vol=0.22, start_bar=0, per_bar=1, **kw):
    """prog: list of chord names, one per bar (or per half bar with per_bar=2)."""
    span = 16 // per_bar
    for i, ch in enumerate(prog):
        if ch in ("-", "_"):
            continue
        for j, m in enumerate(chord_notes(ch, octave)):
            pan = (j / max(1, len(chord_notes(ch)) - 1) - 0.5) * 0.6
            song.note(bus, inst, m, start_bar * 16 + i * span, span, vol, pan, **kw)


def arp_track(song, bus, prog, pattern, octave=4, vol=0.16, inst="pluck", start_bar=0, pan_swing=0.35):
    """pattern: list of chord-tone indices per 16th ('.' = rest). Tones above the
    chord size wrap to the next octave."""
    for i, ch in enumerate(prog):
        if ch in ("-", "_"):
            continue
        tones = chord_notes(ch, octave)
        for s, idx in enumerate(pattern):
            if idx == ".":
                continue
            k = int(idx)
            m = tones[k % len(tones)] + 12 * (k // len(tones))
            pan = pan_swing * (1 if s % 2 else -1)
            song.note(bus, inst, m, (start_bar + i) * 16 + s, 1.6, vol * (1.0 if s % 4 == 0 else 0.78), pan)


def bass_track(song, bus, prog, rhythm, octave=2, vol=0.5, inst="bass", start_bar=0, **kw):
    """rhythm: string per bar: 'R' root, 'O' root octave up, '5' fifth, '.' rest,
    '-' sustain of the previous note."""
    for i, ch in enumerate(prog):
        if ch in ("-", "_"):
            continue
        r = chord_notes(ch, octave)[0]
        s = 0
        while s < 16:
            c = rhythm[s]
            if c in ".-":
                s += 1
                continue
            ln = 1
            while s + ln < 16 and rhythm[s + ln] == "-":
                ln += 1
            m = r + {"R": 0, "O": 12, "5": 7, "3": 4, "b": -2}[c]
            song.note(bus, inst, m, (start_bar + i) * 16 + s, ln * 0.92, vol, 0.0, **kw)
            s += ln


# ----------------------------------------------------------------- explore
EXPLORE_PROG = (["Dmaj7", "Bm7", "Gmaj7", "A6", "Dmaj7", "F#m7", "Gmaj7", "A"]
                + ["Em7", "F#m7", "Gmaj7", "A", "Bm7", "F#m7", "Gmaj7", "Asus"]
                + ["Gmaj7", "A", "F#m7", "Bm7", "Em7", "A", "Dmaj7", "Dmaj7"]
                + ["Dmaj7", "Bm7", "Gmaj7", "A6", "Dmaj7", "F#m7", "Gmaj7", "A"])
HOOK_A = ["A4:2 D5:2 F#5:3 E5:1 D5:2 E5:2 F#5:4", "_:2 F#5:2 A5:2 F#5:2 E5:4 D5:4",
          "B4:2 D5:2 G5:3 F#5:1 E5:2 D5:2 E5:4", "_:4 C#5:2 D5:2 E5:4 A4:4",
          "A4:2 D5:2 F#5:3 E5:1 D5:2 E5:2 F#5:4", "_:2 F#5:2 A5:2 C#6:2 B5:4 A5:4",
          "B5:3 A5:1 G5:2 F#5:2 E5:2 D5:2 E5:4", "E5:4 F#5:2 E5:2 C#5:4 _:4"]
HOOK_B = ["_:4 G5:2 F#5:2 E5:4 B4:4", "_:4 A5:2 G5:2 F#5:4 C#5:4",
          "_:2 D5:2 G5:2 B5:2 A5:4 G5:4", "F#5:2 E5:2 C#5:4 E5:4 _:4",
          "_:4 D5:2 F#5:2 B5:4 A5:4", "_:4 C#6:2 B5:2 A5:4 F#5:4",
          "G5:2 A5:2 B5:4 D6:4 C#6:4", "B5:4 A5:4 _:8"]
HOOK_C = ["D6:8 B5:4 A5:4", "C#6:8 A5:4 E5:4", "A5:8 F#5:4 C#6:4", "B5:12 A5:4",
          "G5:4 B5:4 E6:8", "E6:4 D6:4 C#6:8", "D6:16", "_:16"]
HOOK_A2 = HOOK_A[:7] + ["E5:4 F#5:2 E5:2 D5:4 _:4"]


def explore():
    s = Song(118, 32)
    # ---- calm layer
    chords_track(s, "pad", EXPLORE_PROG, "pad", 3, 0.2)
    arp_track(s, "arp", EXPLORE_PROG, list("0123" "2123" "0123" "4321"), 4, 0.13)
    bass_track(s, "sub", EXPLORE_PROG, "R-------5---R---", 2, 0.42, "sub")
    s.melody("lead", "softlead", HOOK_A + HOOK_B, 0, 0.36)
    s.melody("lead", "bell", HOOK_C, 16, 0.3)
    s.melody("lead", "softlead", HOOK_A2, 24, 0.36)
    s.melody("bell", "bell", HOOK_A, 24, 0.12, 0.3, octave=1)
    perc = {"k": "5.......5.......", "s": "..4...4...4...45", "r": "....6.......6..."}
    s.drums("perc", perc, 0, 32, 0.55, {"s": 0.3, "r": -0.25})
    s.kicks.clear()
    # ---- drive layer (bus names prefixed with d_)
    drv = {"K": "9...9...9...9...", "C": "....8.......8...", "h": "..6...6...6...6.", "o": "..............6."}
    drv_b = {"K": "9...9...9...9...", "S": "....9.......9..5", "h": "5.6.5.6.5.6.5.6.", "o": "..............7."}
    s.drums("d_drums", drv, 0, 8, 0.8)
    s.drums("d_drums", drv_b, 8, 8, 0.8)
    s.drums("d_drums", drv, 16, 7, 0.85)
    s.drums("d_drums", {"T": "........7...7...", "t": "..........7...77", "S": "9.5.9.5.9.5.9999"}, 23, 1, 0.8)
    s.drums("d_drums", drv_b, 24, 8, 0.85)
    for b in (0, 8, 16, 24):
        s.drums("d_drums", {"X": "9..............."}, b, 1, 0.8)
    s.fx("d_fx", dr_riser(s.step * 16 * 2), 22 * 16, 0.9)
    bass_track(s, "d_bass", EXPLORE_PROG, "R.RO.RO.R.RO.R5O", 2, 0.34, "bass")
    s.melody("d_lead", "lead", HOOK_A + HOOK_B + HOOK_C + HOOK_A2, 0, 0.2, octave=0)
    return s


EXPLORE_MIX_BASE = {"pad": (1.0, 0.35, 0.0, "duck"), "arp": (1.2, 0.3, 0.25), "sub": (0.7, 0.0, 0.0, "duck"),
                    "lead": (1.5, 0.3, 0.3), "bell": (1.0, 0.45, 0.2), "perc": (1.0, 0.15, 0.0)}
EXPLORE_MIX_DRIVE = {"d_drums": (0.55, 0.1, 0.0), "d_bass": (0.6, 0.0, 0.0, "duck"), "d_lead": (1.9, 0.25, 0.3),
                     "d_fx": (1.0, 0.3, 0.0)}


# -------------------------------------------------------------------- boss
BOSS_PROG = (["Am", "F", "G", "E", "Am", "F", "G", "E"]
             + ["Dm", "Am", "F", "E", "Dm", "Am", "F", "E7"]
             + ["Am", "F", "G", "E", "Am", "F", "G", "E"]
             + ["F", "G", "Am", "Am", "F", "G", "E", "E7"])
BOSS_A = ["A5:4 E5:2 A5:2 C6:4 B5:2 A5:2", "C6:2 A5:2 F5:4 A5:8", "B5:4 G5:2 B5:2 D6:4 C6:2 B5:2",
          "G#5:8 B5:4 E6:4", "E6:4 D6:2 C6:2 B5:4 A5:4", "F5:4 A5:4 C6:4 F6:4",
          "G6:4 F6:2 E6:2 D6:4 B5:4", "E6:16"]
BOSS_B = ["D6:4 C6:2 A5:2 F5:4 A5:4", "E5:4 A5:4 C6:4 E6:4", "F6:4 E6:2 C6:2 A5:4 C6:4",
          "B5:4 G#5:4 E5:8", "D6:4 F6:4 A6:4 F6:4", "E6:4 C6:4 A5:4 C6:4",
          "C6:2 D6:2 C6:2 A5:2 F5:4 C6:4", "B5:4 D6:4 G#6:8"]
BOSS_C = ["_:16", "_:16", "A5:8 C6:8", "E6:16", "F6:8 E6:8", "D6:8 B5:8", "E6:8 G#6:8", "A6:8 G#6:8"]


def boss():
    s = Song(140, 32)
    chords_track(s, "pad", BOSS_PROG, "pad", 3, 0.16, bright=2400)
    bass_track(s, "bass", BOSS_PROG[:24], "RROROR5RRROROR5O", 2, 0.4, "bass", cutoff=900)
    bass_track(s, "bass", BOSS_PROG[24:], "R-------R-------", 2, 0.45, "bass", start_bar=24, cutoff=500)
    arp_track(s, "arp", BOSS_PROG, list("0120" "1201" "2012" "3210"), 4, 0.1, "pluck")
    s.melody("lead", "lead", BOSS_A + BOSS_B + BOSS_A, 0, 0.26, cutoff=4200)
    s.melody("lead", "brass", BOSS_C, 24, 0.3)
    s.melody("lead2", "lead", BOSS_A, 16, 0.1, 0.35, octave=-1)
    beat = {"K": "9..9..9...9..9..", "S": "....9.......9...", "h": "7.7.7.7.7.7.7.7.", "o": "......5.......5."}
    beat2 = {"K": "9.9.9.9.9.9.9.9.", "S": "....9.......9.55", "h": "7777777777777777"}
    s.drums("drums", beat, 0, 8, 0.85)
    s.drums("drums", beat2, 8, 7, 0.85)
    s.drums("drums", {"T": "9.9.....", "t": "....9.9.9", "S": "........99999999"[:16]}, 15, 1, 0.8)
    s.drums("drums", beat, 16, 8, 0.85)
    s.drums("drums", {"t": "9...............", "k": "9.......9......."}, 24, 6, 0.8)
    s.drums("drums", {"S": "9.9.9.9.99999999"}, 30, 1, 0.75)
    s.drums("drums", {"T": "9...9...9.9.9999", "K": "9...9...9...9..."}, 31, 1, 0.85)
    for b in (0, 8, 16, 24):
        s.drums("drums", {"X": "9..............."}, b, 1, 0.9)
    s.fx("fx", dr_riser(s.step * 16 * 2), 30 * 16, 1.0)
    return s


BOSS_MIX = {"pad": (1.3, 0.3, 0.0, "duck"), "bass": (0.55, 0.0, 0.0, "duck"), "arp": (1.4, 0.25, 0.2),
            "lead": (2.0, 0.25, 0.28), "lead2": (1.6, 0.3, 0.0), "drums": (0.55, 0.12, 0.0), "fx": (1.0, 0.3, 0.0)}


# ------------------------------------------------------------------- final
FINAL_PROG = (["D", "D", "Eb", "D", "D", "D", "Eb", "Cm"]
              + ["Gm", "Eb", "Cm", "D", "Gm", "Eb", "Cm", "D"]
              + ["D", "D", "Eb", "D", "D", "D", "Eb", "Cm"]
              + ["Gm", "Eb", "Cm", "D", "Gm", "Eb", "Cm", "D"])
FINAL_A = ["D5:6 Eb5:2 F#5:8", "G5:4 F#5:4 Eb5:8", "Eb5:6 D5:2 C5:8", "D5:16",
           "A5:6 Bb5:2 A5:8", "G5:4 F#5:4 Eb5:4 D5:4", "G5:6 Bb5:2 Eb6:8", "C6:8 G5:8"]
FINAL_B = ["Bb5:4 A5:4 G5:8", "G5:4 Bb5:4 Eb6:8", "C6:4 Bb5:4 G5:4 Eb5:4", "F#5:8 A5:4 D6:4",
           "D6:4 C6:4 Bb5:8", "Bb5:4 C6:4 Eb6:8", "Eb6:4 D6:4 C6:4 G5:4", "F#5:4 A5:4 D6:8"]


def final():
    s = Song(120, 32)
    chords_track(s, "choir", FINAL_PROG, "choir", 4, 0.16)
    chords_track(s, "pad", FINAL_PROG, "pad", 2, 0.14, bright=900)
    for i, ch in enumerate(FINAL_PROG):
        r = chord_notes(ch, 2)[0]
        for k, off in enumerate([0, 0, 1, 0, 0, 0, 3, 0]):
            s.note("ost", "ostinato", r + off + (12 if k in (2, 6) else 0), i * 16 + k * 2, 1.7, 0.26, 0.2 * (1 if k % 2 else -1))
    bass_track(s, "bass", FINAL_PROG, "R-------R---R-O-", 1, 0.5, "bass", cutoff=400)
    s.melody("lead", "brass", FINAL_A + FINAL_B, 0, 0.3)
    s.melody("lead", "lead", FINAL_A + FINAL_B, 16, 0.22, cutoff=3000)
    s.melody("lead2", "brass", FINAL_B, 24, 0.12, 0.4, octave=-1)
    half = {"K": "9.........9.....", "S": "........9.......", "h": "5...5...5...5...", "t": "..............6."}
    full = {"K": "9.....9...9.....", "S": "....9.......9...", "h": "6.6.6.6.6.6.6.6.", "T": "...............7"}
    s.drums("drums", half, 0, 8, 0.85)
    s.drums("drums", full, 8, 8, 0.85)
    s.drums("drums", half, 16, 8, 0.85)
    s.drums("drums", full, 24, 7, 0.85)
    s.drums("drums", {"T": "9.9.9.9.", "t": "........9.9.9999", "K": "9...9...9...9..."}, 31, 1, 0.85)
    for b in (0, 8, 16, 24):
        s.drums("drums", {"X": "9..............."}, b, 1, 0.9)
    return s


FINAL_MIX = {"choir": (1.4, 0.5, 0.0), "pad": (1.0, 0.3, 0.0, "duck"), "ost": (1.3, 0.2, 0.15),
             "bass": (0.6, 0.0, 0.0, "duck"), "lead": (1.8, 0.3, 0.25), "lead2": (1.4, 0.4, 0.0),
             "drums": (0.6, 0.15, 0.0)}


# -------------------------------------------------------------------- menu
MENU_PROG = (["Gmaj7", "Cmaj7", "Em7", "Dsus", "Gmaj7", "Cmaj7", "Em7", "D"]
             + ["Am7", "Bm7", "Cmaj7", "D", "Am7", "Bm7", "Cmaj7", "D"]
             + ["Gmaj7", "Cmaj7", "Em7", "Dsus", "Gmaj7", "Cmaj7", "Em7", "D"])
MENU_A = ["B5:6 A5:2 G5:4 D5:4", "E5:6 F#5:2 G5:4 B5:4", "A5:8 G5:4 E5:4", "F#5:12 _:4",
          "B5:6 A5:2 G5:4 D6:4", "C6:6 B5:2 A5:4 G5:4", "E5:8 G5:4 B5:4", "A5:16"]
MENU_B = ["C6:4 B5:4 A5:4 E5:4", "D6:4 C6:4 B5:4 F#5:4", "E5:4 G5:4 C6:4 B5:4", "A5:8 F#5:8",
          "C6:4 B5:4 A5:4 E6:4", "D6:4 B5:4 F#5:4 D6:4", "E6:4 D6:4 C6:4 B5:4", "A5:8 D6:8"]
MENU_A2 = MENU_A[:7] + ["G5:16"]


def menu():
    s = Song(90, 24)
    chords_track(s, "pad", MENU_PROG, "pad", 3, 0.2, bright=1500)
    chords_track(s, "ep", MENU_PROG, "epiano", 4, 0.07, per_bar=2)
    arp_track(s, "arp", MENU_PROG, list("0.2.1.3.2.1.4..."), 4, 0.12)
    bass_track(s, "sub", MENU_PROG, "R-------5-------", 2, 0.4, "sub")
    s.melody("lead", "bell", MENU_A + MENU_B + MENU_A2, 0, 0.26)
    s.melody("lead2", "softlead", MENU_B, 8, 0.12, 0.35, octave=-1)
    s.drums("perc", {"k": "7.......6.......", "s": "..3...3...3...3.", "r": "....5.......5..."}, 8, 16, 0.45)
    return s


MENU_MIX = {"pad": (1.0, 0.45, 0.0), "ep": (1.0, 0.4, 0.25), "arp": (1.0, 0.35, 0.3), "sub": (1.0, 0.0, 0.0),
            "lead": (1.0, 0.45, 0.3), "lead2": (1.0, 0.4, 0.2), "perc": (1.0, 0.2, 0.0)}


# ---------------------------------------------------------------- stingers
def stinger(kind):
    if kind == "levelup":       # D major sparkle, same key as the run music
        s = Song(150, 2, tail=1.5)
        for i, n in enumerate(["D5", "F#5", "A5", "D6", "F#6"]):
            s.note("a", "pluck", midi(n), i, 1.5, 0.35, (i - 2) * 0.2)
        for n in ["D5", "F#5", "A5", "D6"]:
            s.note("b", "bell", midi(n), 5, 8, 0.18)
        mix = {"a": (1.0, 0.3, 0.2), "b": (1.0, 0.5, 0.0)}
    elif kind == "victory":
        s = Song(132, 4, tail=2.0)
        mel = ["D5:3 D5:1 D5:2 A5:6 F#5:4", "G5:3 A5:1 B5:4 A5:8", "F#5:4 A5:4 D6:8", "_:16"]
        s.melody("lead", "brass", mel, 0, 0.35)
        chords_track(s, "pad", ["D", "G", "D", "D"], "pad", 3, 0.2)
        s.drums("drums", {"K": "9...............", "X": "9...............", "S": "..........5.5.99"}, 0, 1, 0.7)
        s.drums("drums", {"K": "9.......9.......", "X": "9..............."}, 2, 1, 0.7)
        mix = {"lead": (1.0, 0.35, 0.2), "pad": (1.0, 0.4, 0.0), "drums": (1.0, 0.2, 0.0)}
    elif kind == "defeat":
        s = Song(80, 3, tail=2.5)
        s.melody("lead", "softlead", ["A5:4 G5:4 E5:4 D5:4", "C5:4 B4:4 A4:8", "_:16"], 0, 0.3)
        chords_track(s, "pad", ["Am", "F", "Am"], "pad", 3, 0.18, bright=1100)
        mix = {"lead": (1.0, 0.45, 0.2), "pad": (1.0, 0.5, 0.0)}
    else:                        # fusion: riser + big chord
        s = Song(120, 3, tail=2.5)
        s.fx("fx", dr_riser(s.step * 16), 0, 0.9)
        for n in ["D4", "A4", "D5", "F#5", "A5", "E6"]:
            s.note("hit", "bell", midi(n), 16, 16, 0.16)
            s.note("pad", "pad", midi(n) - 12, 16, 16, 0.12)
        s.drums("drums", {"X": "9...............", "K": "9..............."}, 1, 1, 0.8)
        mix = {"fx": (1.0, 0.3, 0.0), "hit": (1.0, 0.5, 0.2), "pad": (1.0, 0.5, 0.0), "drums": (1.0, 0.3, 0.0)}
    x = mixdown(s, mix)
    x = master(x)
    x *= 0.8 / max(1e-6, np.abs(x).max())
    # trim the silent tail
    lvl = np.abs(x).max(1)
    last = np.nonzero(lvl > 10 ** (-40 / 20))[0]
    x = x[: min(len(x), int(last[-1]) + int(0.05 * SR))] if len(last) else x
    fade = int(0.08 * SR)
    x[-fade:] *= np.linspace(1, 0, fade)[:, None]
    return x


# ------------------------------------------------------------------- main
def render_loop(song, mix, sidechain):
    x = mixdown(song, mix, sidechain)
    return loop_wrap(x, song.length)


def main():
    want = set(sys.argv[1:])
    print("composing ->", os.path.abspath(OUT))
    if not want or "explore" in want:
        s = explore()
        base = render_loop(s, EXPLORE_MIX_BASE, 0.25)
        drive = render_loop(s, EXPLORE_MIX_DRIVE, 0.4)
        base, drive = normalize_pair(master(base, 1.0), master(drive, 1.0))
        write("explore_base", base)
        write("explore_drive", drive)
    if not want or "boss" in want:
        s = boss()
        x = master(render_loop(s, BOSS_MIX, 0.4))
        write("boss", x * 0.89 / np.abs(x).max())
    if not want or "final" in want:
        s = final()
        x = master(render_loop(s, FINAL_MIX, 0.35))
        write("final", x * 0.89 / np.abs(x).max())
    if not want or "menu" in want:
        s = menu()
        x = master(render_loop(s, MENU_MIX, 0.0))
        write("menu", x * 0.85 / np.abs(x).max())
    if not want or "stingers" in want:
        for k in ("levelup", "victory", "defeat", "fusion"):
            write("sting_" + k, stinger(k))


if __name__ == "__main__":
    main()
