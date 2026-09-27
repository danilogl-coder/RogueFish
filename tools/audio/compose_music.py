"""RogueFish soundtrack composer: a small synth + sequencer in numpy.

Renders every music track of the game to OGG Vorbis (seamless loops):

  menu            "Canção das Marés"   E lydian, 72 bpm: warm detuned pads, flute
                                       melody, harp arpeggio in ping-pong delay,
                                       whale calls and wave swells (ocean theme)
  explore1..5     the run music, five songs rotated during a run, each one as two
                  synced stems (_base = calm layer, _drive = drums/bass/lead faded
                  in by danger: adaptive music)
    explore1      "Recife Ensolarado"  D dorian, 100 bpm, rhodes + marimba + congas
    explore2      "Corrente Profunda"  C minor, 90 bpm, pulsing ostinato, strings
    explore3      "Floresta de Kelp"   F lydian, 80 bpm, harp plucks and flute
    explore4      "Abismo Azul"        A minor/phrygian, 68 bpm, dark ambient
    explore5      "Maré Alta"          G mixolydian, 122 bpm, upbeat adventure
  horde           "Horda"              E phrygian, 148 bpm, taiko + ostinato + brass
  boss            "Mandíbulas"      A harmonic minor, 140 bpm, heroic and driving
  final           "Devorador"       D phrygian dominant, 120 bpm, choir + ostinato
  stingers        level-up (in D), victory fanfare, defeat, fusion, horde alarm

Design notes (see docs/DESIGN.md, "Música"):
  * one hook per track, repeated and varied (A A' B C) so it sticks;
  * tension -> release: section C lifts to the top of the range, a drum fill
    and a riser lead back to the hook;
  * adaptive layering instead of track switching during a run: the calm and
    the drive stems share tempo and length and play in sync;
  * ocean colour: warm detuned pads with chorus and slow filter sweeps, long
    reverb, dotted ping-pong delays, whale-like glides, bubbles, wave-noise
    swells, lydian/dorian modes; no bright bells or music box (sounded like
    Christmas);
  * soft timbres, gentle high end and 70+ second loops against fatigue; loops
    are folded (reverb tail onto the start) and mastered circularly so the
    seam is click-free.

Usage: python3 tools/audio/compose_music.py [menu explore explore1..5 horde boss final stingers]
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


def phase_of(freq, ph0=0.0):
    return (np.cumsum(freq / SR) + ph0) % 1.0


def saw(freq, ph0=0.0):
    ph = phase_of(freq, ph0)
    return 2 * ph - 1 - _blep(ph, freq / SR)


def square(freq, pw=0.5):
    ph = phase_of(freq)
    dt = freq / SR
    s1 = 2 * ph - 1 - _blep(ph, dt)
    ph2 = (ph + pw) % 1.0
    s2 = 2 * ph2 - 1 - _blep(ph2, dt)
    return (s1 - s2) * 0.5


def sine(freq, ph0=0.0):
    return np.sin(2 * np.pi * phase_of(freq, ph0))


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


# ---- ocean palette: warm, deep, flowing (no bright bells)
def inst_warmpad(f, n, gate, cutoff=1100.0, voices=5, spread=0.17, attack=0.7):
    """Supersaw-ish pad: detuned voices with random phases, dark low-pass,
    a sine for body. Chorus and slow filter sweeps are added on the bus."""
    out = np.zeros(n)
    for i in range(voices):
        det = spread * (2 * i / (voices - 1) - 1)
        out += saw(np.full(n, f * 2 ** (det / 12)), RNG.uniform())
    out = lowpass(lowpass(out / voices, cutoff * 1.2), cutoff * 2.4)
    out += 0.35 * sine(np.full(n, f))
    return out * env_adsr(n, attack, 1.0, 0.85, 1.1, gate) * 0.8


def inst_ooh(f, n, gate):
    """Soft 'ooh' choir: detuned ensemble through low formants."""
    x = np.zeros(n)
    for k, det in enumerate((-0.14, -0.05, 0.05, 0.14)):
        x += saw(vibrato(n, f * 2 ** (det / 12), 0.09, 4.3 + k * 0.37, 0.2), RNG.uniform())
    x /= 4
    y = 0.55 * lowpass(x, 900) + bandpass(x, 280, 480) + 0.6 * bandpass(x, 700, 1000)
    return y * env_adsr(n, 0.45, 0.8, 0.85, 0.9, gate) * 0.9


def inst_flute(f, n, gate):
    """Breathy, warm flute: sine-rich tone, delayed vibrato, breath noise."""
    t = np.arange(n) / SR
    fr = vibrato(n, f, 0.13, 5.0, 0.3)
    x = sine(fr) + 0.3 * sine(2 * fr) + 0.12 * sine(3 * fr) + 0.04 * sine(4 * fr)
    br = bandpass(noise(n), max(200.0, f * 0.8), min(SR * 0.4, f * 3.5))
    x += br * (0.1 + 0.25 * np.exp(-t / 0.08))
    return x * env_adsr(n, 0.06, 0.3, 0.85, 0.2, gate) * 0.5


def inst_whale(f, n, gate):
    """Whale-like moan: slow rising/falling glide, flutter, band-limited."""
    t = np.arange(n) / SR
    g = max(gate / SR, 0.3)
    u = np.clip(t / g, 0, 1)
    semis = -4 + 6 * np.sin(np.pi * u * 0.8) - 5 * np.clip((t - g) / 1.2, 0, 1)
    fr = f * 2 ** (semis / 12) * (1 + 0.004 * np.sin(2 * np.pi * 6.5 * t))
    x = sine(fr) + 0.35 * sine(2 * fr) + 0.12 * tri(3 * fr)
    x = bandpass(x, 120, 1600) * (1 + 0.2 * np.sin(2 * np.pi * 3.1 * t))
    return x * env_adsr(n, 0.5, 1.0, 0.8, 0.9, gate) * 0.6


def inst_marimba(f, n, gate):
    """Soft wooden mallet (Aquatic Ambience flavour), no metallic ring."""
    t = np.arange(n) / SR
    dec = float(np.clip(0.8 * (220 / f) ** 0.5, 0.2, 1.1))
    x = np.sin(2 * np.pi * f * t) * np.exp(-t / dec)
    x += 0.3 * np.sin(2 * np.pi * 3.93 * f * t) * np.exp(-t / (dec * 0.15))
    x += 0.15 * lowpass(noise(n), 2500) * np.exp(-t / 0.006)
    return lowpass(x, 3500) * np.clip(t / 0.002, 0, 1) * 0.8


def inst_harp(f, n, gate):
    """Warm Karplus-Strong harp / nylon pluck."""
    t = np.arange(n) / SR
    body = np.sin(2 * np.pi * f * t) * np.exp(-t / 0.9) * 0.25
    return inst_pluck(f, n, gate + int(0.8 * SR), damp=0.997, tone=3400.0) + body


def inst_rhodes(f, n, gate):
    """Mellow electric piano with a slow tremolo."""
    t = np.arange(n) / SR
    x = inst_bell(f, n, gate, ratio=1.0, index=0.8, decay=1.8)
    x += 0.15 * inst_bell(f, n, gate, ratio=2.0, index=0.3, decay=0.4)
    return lowpass(x, 3000) * (1 + 0.18 * np.sin(2 * np.pi * 4.2 * t))


def inst_strings(f, n, gate, attack=0.18, cutoff=2800.0):
    """String ensemble: five detuned saws with vibrato."""
    x = np.zeros(n)
    for k, det in enumerate((-0.12, -0.05, 0.0, 0.06, 0.13)):
        x += saw(vibrato(n, f * 2 ** (det / 12), 0.1, 5.0 + 0.3 * k, 0.2), RNG.uniform())
    x = highpass(lowpass(x / 5, cutoff), 110)
    return x * env_adsr(n, attack, 0.4, 0.85, 0.35, gate) * 0.55


def inst_pulse(f, n, gate, cutoff=1800.0):
    """Plucky filtered synth bass for ostinatos."""
    t = np.arange(n) / SR
    x = saw(np.full(n, f)) + 0.5 * square(np.full(n, f * 1.003), 0.4)
    fe = np.exp(-t / 0.07)
    y = lowpass(x, 350) + (lowpass(x, cutoff) - lowpass(x, 350)) * fe
    y += 0.5 * sine(np.full(n, f))
    return y * env_adsr(n, 0.003, 0.12, 0.6, 0.05, gate) * 0.5


def inst_horn(f, n, gate):
    """Deep swelling horn with an upward scoop (horde alarm)."""
    t = np.arange(n) / SR
    fr = f * 2 ** (-3 * np.exp(-t / 0.12) / 12)
    x = saw(fr) + 0.7 * saw(fr * 1.004, 0.3) + 0.5 * square(fr * 0.5, 0.45)
    cut = 500 + 1400 * np.clip(t / 0.35, 0, 1)
    y = lowpass(x, 500) + (lowpass(x, 1900) - lowpass(x, 500)) * (cut - 500) / 1400
    return y * env_adsr(n, 0.12, 0.5, 0.8, 0.5, gate) * 0.45


def inst_bubble(f, n, gate):
    """A rising sine chirp: the sound of an air bubble."""
    t = np.arange(n) / SR
    fr = f * (1 + 2.2 * t / 0.06)
    x = np.sin(2 * np.pi * np.cumsum(fr) / SR) * np.exp(-t / 0.035)
    return x * np.clip(t / 0.003, 0, 1) * 0.5


INSTR = {"pad": inst_pad, "pluck": inst_pluck, "bell": inst_bell, "epiano": inst_epiano, "lead": inst_lead,
         "softlead": inst_softlead, "bass": inst_bass, "sub": inst_sub, "choir": inst_choir,
         "brass": inst_brass, "ostinato": inst_ostinato, "warmpad": inst_warmpad, "ooh": inst_ooh,
         "flute": inst_flute, "whale": inst_whale, "marimba": inst_marimba, "harp": inst_harp,
         "rhodes": inst_rhodes, "strings": inst_strings, "pulse": inst_pulse, "horn": inst_horn,
         "bubble": inst_bubble}


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


def dr_conga(v=1.0, f0=330):
    n = int(0.32 * SR)
    t = np.arange(n) / SR
    f = f0 * (1 + 0.25 * np.exp(-t / 0.012))
    body = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 0.11)
    slap = bandpass(noise(n), 900, 4000) * np.exp(-t / 0.007)
    return (body + 0.35 * slap) * 0.55 * v


def dr_taiko(v=1.0):
    n = int(1.3 * SR)
    t = np.arange(n) / SR
    f = 56 * (1 + 0.9 * np.exp(-t / 0.045))
    body = np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-t / 0.42)
    skin = lowpass(noise(n), 700) * np.exp(-t / 0.07)
    return np.tanh((body + 0.6 * skin) * 1.5) * 0.85 * v


def dr_brush(v=1.0):
    n = int(0.18 * SR)
    t = np.arange(n) / SR
    e = np.clip(t / 0.012, 0, 1) * np.exp(-t / 0.07)
    return bandpass(noise(n), 2000, 7000) * e * 0.3 * v


DRUM = {"K": dr_kick, "k": dr_softkick, "S": dr_snare, "C": dr_clap, "h": dr_hat,
        "o": lambda v=1.0: dr_hat(v, True), "s": dr_shaker, "r": dr_rim, "X": dr_crash,
        "T": lambda v=1.0: dr_tom(v, 190), "t": lambda v=1.0: dr_tom(v, 130),
        "c": lambda v=1.0: dr_conga(v, 340), "g": lambda v=1.0: dr_conga(v, 225), "D": dr_taiko,
        "B": dr_brush}


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
        ring = {"pad": 1.6, "bell": 1.8, "pluck": 1.2, "choir": 1.5, "epiano": 1.6, "warmpad": 2.6,
                "ooh": 2.0, "strings": 1.2, "whale": 2.2, "marimba": 1.4, "harp": 1.8, "rhodes": 1.8,
                "horn": 1.6, "bubble": 0.2, "flute": 0.8}.get(inst, 0.5)
        n = gate + int(ring * SR)
        x = INSTR[inst](hz(m), n, gate, **kw)
        fade = min(len(x), int(0.03 * SR))
        x[-fade:] *= np.linspace(1, 0, fade)
        self.add(busname, self.pos(step), x, vol, pan)

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
    """'Dmaj7', 'Bm7', 'A', 'Asus', 'F#m7', 'E7', 'Cm', 'Eb', 'F#/E'... -> midi
    list (a slash bass only changes chord_root)."""
    import re
    name = name.split("/")[0]
    mm = re.match(r"([A-G][b#]?)(.*)", name)
    root, q = mm.group(1), mm.group(2)
    r = midi(root + str(octave))
    iv = {"": [0, 4, 7], "m": [0, 3, 7], "maj7": [0, 4, 7, 11], "m7": [0, 3, 7, 10], "7": [0, 4, 7, 10],
          "sus": [0, 5, 7], "6": [0, 4, 7, 9], "m9": [0, 3, 7, 10, 14], "add9": [0, 4, 7, 14],
          "maj7#11": [0, 4, 7, 11, 18], "maj9": [0, 4, 7, 11, 14], "m11": [0, 3, 7, 10, 14, 17],
          "7sus": [0, 5, 7, 10], "madd9": [0, 3, 7, 14], "sus2": [0, 2, 7], "9": [0, 4, 7, 10, 14]}[q]
    return [r + i for i in iv]


def chord_root(name, octave=2):
    """Bass note of a chord, honouring slash chords ('F#/E' -> E)."""
    if "/" in name:
        b = name.split("/")[1]
        return midi(b + str(octave))
    return chord_notes(name, octave)[0]


# ================================================================== mixing
_IR_CACHE: dict = {}


def reverb_ir(seconds=2.2, damp=5000.0, seed=3):
    key = (seconds, damp, seed)
    if key in _IR_CACHE:
        return _IR_CACHE[key]
    n = int(seconds * SR)
    t = np.arange(n) / SR
    rng = np.random.default_rng(seed)
    ir = np.stack([rng.uniform(-1, 1, n), rng.uniform(-1, 1, n)], 1)
    ir *= np.exp(-t / (seconds / 5.5))[:, None]
    ir[:, 0] = lowpass(ir[:, 0], damp)
    ir[:, 1] = lowpass(ir[:, 1], damp)
    ir[: int(0.012 * SR)] = 0  # predelay
    ir = ir / np.sqrt((ir ** 2).sum(0))
    _IR_CACHE[key] = ir
    return ir


def reverb(x, amount, seconds=2.2, damp=5000.0):
    ir = reverb_ir(seconds, damp)
    wet = np.stack([signal.fftconvolve(x[:, c], ir[:, c])[: len(x)] for c in range(2)], 1)
    return wet * amount


def pingpong(x, song, feedback=0.38, mix=0.3, steps=3, repeats=4, tone=3500.0):
    d = song.pos(steps)
    out = np.zeros_like(x)
    src = x.copy()
    for k in range(1, repeats + 1):
        g = mix * feedback ** (k - 1)
        sh = np.zeros_like(x)
        if d * k >= len(x):
            break
        sh[d * k:] = src[: len(x) - d * k]
        ch = k % 2
        out[:, ch] += (sh[:, 0] + sh[:, 1]) * 0.5 * g
    return lowpass_st(out, tone)


def chorus_st(x, depth_ms=3.5, base_ms=14.0, rate=0.21, mix=0.6):
    """Slow stereo chorus (modulated delay, quadrature LFOs)."""
    n = len(x)
    t = np.arange(n) / SR
    out = x.copy()
    idx = np.arange(n, dtype=float)
    for c in range(2):
        d = (base_ms + depth_ms * np.sin(2 * np.pi * rate * t + c * np.pi / 2)) * SR / 1000
        mono = 0.5 * (x[:, 0] + x[:, 1])
        out[:, c] += mix * np.interp(idx - d, idx, mono, left=0.0)
    return out / (1 + mix * 0.5)


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


def mixdown(song, spec, sidechain=0.0, rv_seconds=2.2, rv_damp=5000.0, delay=None):
    """spec: bus -> (gain, reverb_send, delay_send, *options). Options: "duck"
    (sidechain to the kicks), "chorus", ("sweep", low_cutoff, cycles): a slow
    low-pass sweep whose period divides the loop. delay: pingpong kwargs."""
    dry = np.zeros((song.n, 2))
    send = np.zeros((song.n, 2))
    dly = np.zeros((song.n, 2))
    g_duck = duck(song, sidechain) if sidechain > 0 and song.kicks else 1.0
    for name, (gain, rv, dl, *opts) in spec.items():
        if name not in song.buses:
            continue
        b = song.buses[name] * gain
        for o in opts:
            if o == "duck":
                b = b * g_duck
            elif o == "chorus":
                b = chorus_st(b)
            elif isinstance(o, tuple) and o[0] == "sweep":
                m = 0.5 - 0.5 * np.cos(2 * np.pi * o[2] * np.arange(song.n) / song.length)
                b = lowpass_st(b, o[1]) * (1 - m[:, None]) + b * m[:, None]
        dry += b
        send += b * rv
        dly += b * dl
    wet = reverb(send, 1.0, rv_seconds, rv_damp)
    if np.any(dly):
        wet += pingpong(dly, song, **(delay or {}))
    return dry + wet


def loop_wrap(x, length):
    """Folds the tail (reverb/delay ring) back onto the start: seamless loop."""
    out = x[:length].copy()
    tail = x[length:]
    while len(tail):
        k = min(len(tail), length)
        out[:k] += tail[:k]
        tail = tail[k:]
    return out


def master(x, gain=1.0):
    x = highpass_st(x, 28)
    x = np.tanh(x * gain * 1.15) / np.tanh(1.15)
    return x


def master_loop(x, peak_in=1.0, lp=None):
    """Mastering for loops, done circularly (the filters see the loop as
    periodic) so the seam stays click-free. peak_in sets how hard the soft
    clipper is driven."""
    n = len(x)
    y = np.concatenate([x, x, x]) * (peak_in / max(1e-6, np.abs(x).max()))
    y = highpass_st(y, 30)
    if lp:
        y = lowpass_st(y, lp)
    y = np.tanh(y * 1.1) / np.tanh(1.1)
    return y[n: 2 * n]


def ocean_bed(length, swells, cutoff=600.0, foam=0.22, seed=11):
    """Wave-noise swells, exactly periodic over `length` (seamless)."""
    rng = np.random.default_rng(seed)
    t = np.arange(length) / length
    out = np.zeros((length, 2))
    for c in range(2):
        base = rng.uniform(-1, 1, length)
        tiled = np.concatenate([base, base, base])
        low = lowpass(lowpass(tiled, cutoff), cutoff)[length: 2 * length]
        hi = bandpass(tiled, 900, 3200)[length: 2 * length]
        env = (0.5 - 0.5 * np.cos(2 * np.pi * swells * t + c * 0.6)) ** 1.6
        out[:, c] = low * (0.25 + 0.75 * env) * 1.6 + hi * foam * env ** 2
    return out


def write(name, x, quality=0.8):
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, name + ".ogg")
    data = np.clip(x, -1, 1).astype(np.float32)
    # written in blocks: libsndfile's Vorbis encoder can crash on one huge write
    with sf.SoundFile(path, "w", SR, data.shape[1], format="OGG", subtype="VORBIS",
                      compression_level=quality) as f:
        for i in range(0, len(data), SR):
            f.write(data[i: i + SR])
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


def comp_track(song, bus, prog, rhythm, inst="rhodes", octave=3, vol=0.12, start_bar=0, strum=0.0,
               hold=None, **kw):
    """Rhythmic chords. rhythm: 16 chars, 'x' hit, digit = velocity, '.' rest;
    each hit lasts until the next one (or `hold` steps)."""
    hits = [i for i, c in enumerate(rhythm) if c != "."]
    for bi, ch in enumerate(prog):
        if ch in ("-", "_"):
            continue
        notes = chord_notes(ch, octave)
        for hi, st in enumerate(hits):
            ln = hold or ((hits[hi + 1] if hi + 1 < len(hits) else 16) - st) * 0.92
            c = rhythm[st]
            v = vol * (int(c) / 9.0 if c.isdigit() else 1.0)
            for j, m in enumerate(notes):
                pan = (j / max(1, len(notes) - 1) - 0.5) * 0.7
                song.note(bus, inst, m, (start_bar + bi) * 16 + st + j * strum, ln, v, pan, **kw)


def whales(song, bus, calls, vol=0.2):
    """calls: list of (bar, note name, length in steps, pan)."""
    for bar, nm, ln, pan in calls:
        song.note(bus, "whale", midi(nm), bar * 16, ln, vol, pan)


def bubbles(song, bus, count, vol=0.05, seed=5):
    rng = np.random.default_rng(seed)
    total = song.bars * 16
    for _ in range(count):
        st = rng.uniform(0, total - 1)
        burst = rng.integers(1, 4)
        for k in range(burst):
            f = rng.uniform(72, 86)
            song.note(bus, "bubble", f, st + k * rng.uniform(0.3, 0.9), 0.4, vol * rng.uniform(0.5, 1.0),
                      rng.uniform(-0.8, 0.8))


def arp_track(song, bus, prog, pattern, octave=4, vol=0.16, inst="pluck", start_bar=0, pan_swing=0.35,
              note_len=1.6, **kw):
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
            song.note(bus, inst, m, (start_bar + i) * 16 + s, note_len, vol * (1.0 if s % 4 == 0 else 0.78), pan, **kw)


def bass_track(song, bus, prog, rhythm, octave=2, vol=0.5, inst="bass", start_bar=0, **kw):
    """rhythm: string per bar: 'R' root, 'O' root octave up, '5' fifth, '.' rest,
    '-' sustain of the previous note."""
    for i, ch in enumerate(prog):
        if ch in ("-", "_"):
            continue
        r = chord_root(ch, octave)
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
# Five songs rotate during a run. Each is rendered as two synced stems: the
# calm base (always on) and the drive layer (buses prefixed d_) that the game
# fades in with danger.  Every song has its own key, mode, tempo and palette.

# --- 1. "Recife Ensolarado": D dorian, 100 bpm, sunny reef groove
R1_A = ["Dm9", "G9", "Dm9", "G9", "Fmaj7", "C", "Em7", "A7sus"]
R1_B = ["Fmaj7", "G9", "Em7", "Am7", "Dm9", "G9", "Cmaj7", "A7sus"]
R1_C = ["Fmaj7", "Em7", "Dm9", "C", "Fmaj7", "G9", "A7sus", "A7sus"]
R1_PROG = R1_A + R1_B + R1_C + R1_A
R1_MA = ["D5:3 F5:3 A5:2 G5:2 F5:2 E5:2 D5:2", "B4:4 D5:2 E5:2 F5:4 E5:4",
         "D5:3 F5:3 A5:2 C6:2 A5:2 G5:2 F5:2", "G5:8 E5:4 _:4",
         "A5:3 C6:3 A5:2 G5:2 F5:2 E5:2 C5:2", "E5:6 D5:2 C5:4 G4:4",
         "B4:4 D5:4 E5:4 G5:4", "A5:12 _:4"]
R1_MB = ["_:4 C6:2 A5:2 F5:4 A5:4", "B5:6 A5:2 G5:4 D5:4", "_:4 G5:2 E5:2 B4:4 E5:4",
         "C6:6 B5:2 A5:4 E5:4", "F5:4 A5:4 D6:4 C6:4", "B5:8 A5:4 G5:4",
         "E5:4 G5:4 B5:4 C6:4", "A5:8 E5:8"]
R1_MC = ["A5:16", "G5:16", "F5:8 E5:8", "E5:16", "C6:16", "B5:16", "A5:8 G5:8", "A5:16"]
R1_MA2 = R1_MA[:7] + ["D5:12 _:4"]


def explore1():
    s = Song(100, 32, tail=5.0)
    # ---- calm layer
    comp_track(s, "keys", R1_PROG, "x..x..x...x.x...", "rhodes", 3, 0.075)
    chords_track(s, "pad", R1_PROG, "warmpad", 3, 0.05, cutoff=900)
    arp_track(s, "arp", R1_PROG, list("0.2.4.3.1.3.2.4."), 4, 0.12, "marimba", note_len=2)
    bass_track(s, "sub", R1_PROG, "R-----R-5-----R-", 2, 0.4, "sub")
    s.melody("lead", "flute", R1_MA + R1_MB, 0, 0.3)
    s.melody("lead", "ooh", R1_MC, 16, 0.16)
    s.melody("lead", "flute", R1_MA2, 24, 0.3)
    s.melody("lead2", "marimba", R1_MA2, 24, 0.07, 0.4, octave=-1)
    perc = {"c": "..6...6.....6.6.", "g": "6.....5...6.....", "s": "5.3.5.3.5.3.5.3."}
    s.drums("perc", perc, 0, 32, 0.5, {"c": 0.3, "g": -0.2, "s": 0.4})
    bubbles(s, "fx", 14, 0.05, seed=1)
    s.kicks.clear()
    # ---- drive layer
    groove = {"K": "9.....9...9.....", "S": "....9.......9...", "h": "6.6.6.6.6.6.6.6.", "o": "..............6."}
    groove_b = {"K": "9.....9...9..6..", "S": "....9.......9..5", "h": "6464646464646464", "o": "......6.......6."}
    s.drums("d_drums", groove, 0, 16, 0.8)
    s.drums("d_drums", groove_b, 16, 15, 0.8)
    s.drums("d_drums", {"S": "9.5.9.5.9.5.9999", "t": "..........7..7..", "K": "9...9..........."}, 31, 1, 0.8)
    for b in (0, 8, 16, 24):
        s.drums("d_drums", {"X": "9..............."}, b, 1, 0.6)
    s.fx("d_fx", dr_riser(s.step * 16 * 2), 22 * 16, 0.8)
    bass_track(s, "d_bass", R1_PROG, "R..R..O.R..5.R.O", 2, 0.32, "bass", cutoff=800)
    s.melody("d_lead", "lead", R1_MA + R1_MB + R1_MC + R1_MA2, 0, 0.15, cutoff=2600)
    return s


R1_MIX_BASE = {"pad": (1.6, 0.5, 0.0, "duck", "chorus"), "keys": (0.55, 0.3, 0.15, "duck"),
               "arp": (1.0, 0.35, 0.35), "sub": (0.5, 0.0, 0.0, "duck"), "lead": (1.2, 0.4, 0.25),
               "lead2": (1.0, 0.4, 0.3), "perc": (1.0, 0.18, 0.0), "fx": (1.0, 0.5, 0.2)}
R1_MIX_DRIVE = {"d_drums": (0.42, 0.1, 0.0), "d_bass": (0.95, 0.0, 0.0, "duck"), "d_lead": (2.2, 0.3, 0.3),
                "d_fx": (1.0, 0.3, 0.0)}

# --- 2. "Corrente Profunda": C minor, 90 bpm, mysterious deep current
R2_A = ["Cm9", "Abmaj7", "Fm9", "G7sus", "Cm9", "Dbmaj7", "Abmaj7", "G7sus"]
R2_B = ["Abmaj7", "Bb", "Gm7", "Cm9", "Fm9", "Ebmaj7", "Dbmaj7", "G"]
R2_PROG = R2_A + R2_B + R2_A + R2_B
R2_MA = ["G4:8 Eb4:4 D4:4", "C4:8 Eb4:4 G4:4", "Ab4:6 G4:2 F4:4 C4:4", "D4:12 _:4",
         "G4:6 Bb4:2 C5:8", "Db5:6 C5:2 Ab4:8", "G4:4 Eb4:4 C4:4 Eb4:4", "D4:8 F4:4 G4:4"]
R2_MB = ["C5:8 Eb5:8", "D5:8 F5:4 D5:4", "Bb4:8 D5:4 F5:4", "Eb5:12 D5:4",
         "C5:8 Ab4:4 G4:4", "Bb4:8 G4:4 Eb4:4", "F4:8 Ab4:4 C5:4", "B4:12 _:4"]


def explore2():
    s = Song(90, 32, tail=5.0)
    chords_track(s, "pad", R2_PROG, "warmpad", 3, 0.08, cutoff=800)
    chords_track(s, "choir", R2_B, "ooh", 4, 0.045, start_bar=8)
    chords_track(s, "choir", R2_B, "ooh", 4, 0.045, start_bar=24)
    bass_track(s, "ost", R2_PROG, "R.R.O.R.R.R.O.5.", 2, 0.2, "pulse", cutoff=1200)
    bass_track(s, "sub", R2_PROG, "R-------R-------", 2, 0.34, "sub")
    arp_track(s, "harp", R2_PROG, list("0...2...4...3..."), 4, 0.1, "harp", note_len=4)
    s.melody("lead", "strings", R2_MA + R2_MB, 0, 0.22, attack=0.25)
    s.melody("lead", "strings", R2_MA, 16, 0.22, attack=0.25)
    s.melody("lead", "strings", R2_MB, 24, 0.2, attack=0.25, octave=1)
    s.melody("lead", "strings", R2_MB, 24, 0.14, attack=0.25)
    whales(s, "whale", [(2, "G3", 26, -0.5), (10, "C4", 22, 0.5), (18, "Eb3", 28, 0.3), (27, "G3", 24, -0.4)], 0.2)
    s.drums("perc", {"g": "6.......3.....4.", "s": "..3...3...3...3."}, 0, 32, 0.45, {"g": -0.2, "s": 0.35})
    bubbles(s, "fx", 10, 0.04, seed=2)
    s.kicks.clear()
    # ---- drive
    beat = {"D": "9.......7.......", "K": "9.....6...9.....", "r": "....7.......7..5", "h": "5.5.5.5.5.5.5.5."}
    beat_b = {"D": "9.......7...6...", "K": "9.....6...9..6..", "S": "....8.......8...", "h": "5555555555555555"}
    s.drums("d_drums", beat, 0, 8, 0.75)
    s.drums("d_drums", beat_b, 8, 7, 0.75)
    s.drums("d_drums", {"T": "9.9.9.9.........", "t": "........9.9.9999", "D": "9..............."}, 15, 1, 0.75)
    s.drums("d_drums", beat, 16, 8, 0.75)
    s.drums("d_drums", beat_b, 24, 8, 0.75)
    for b in (0, 8, 16, 24):
        s.drums("d_drums", {"X": "9..............."}, b, 1, 0.55)
    arp_track(s, "d_arp", R2_PROG, list("0123" "2123" "0123" "4321"), 4, 0.07, "pluck")
    comp_track(s, "d_stab", R2_PROG, "x.....x...x.....", "brass", 3, 0.05, hold=1.6)
    bass_track(s, "d_bass", R2_PROG, "R.R.R.O.R.R.R.O.", 1, 0.3, "bass", cutoff=600)
    s.fx("d_fx", dr_riser(s.step * 16 * 2), 14 * 16, 0.7)
    s.fx("d_fx", dr_riser(s.step * 16 * 2), 30 * 16, 0.7)
    return s


R2_MIX_BASE = {"pad": (1.5, 0.5, 0.0, "duck", "chorus", ("sweep", 450.0, 4)), "choir": (1.8, 0.6, 0.0),
               "ost": (1.1, 0.15, 0.2, "duck"), "sub": (0.5, 0.0, 0.0, "duck"), "harp": (1.6, 0.45, 0.45),
               "lead": (2.3, 0.45, 0.15), "whale": (1.0, 0.8, 0.3), "perc": (1.0, 0.2, 0.0),
               "fx": (1.0, 0.5, 0.2)}
R2_MIX_DRIVE = {"d_drums": (0.42, 0.15, 0.0), "d_arp": (2.0, 0.3, 0.35), "d_stab": (1.3, 0.35, 0.1),
                "d_bass": (0.95, 0.0, 0.0, "duck"), "d_fx": (1.0, 0.3, 0.0)}

# --- 3. "Floresta de Kelp": F lydian, 80 bpm, gentle swaying plucks
R3_A = ["Fmaj7", "G/F", "Am7", "G/F", "Dm9", "Em7", "Fmaj7", "Csus"]
R3_B = ["Dm9", "Em7", "Fmaj7", "G", "Am7", "G/B", "Cmaj7", "Csus"]
R3_T = ["Fmaj7", "G/F", "Fmaj7", "G/F"]
R3_PROG = R3_A + R3_B + R3_A + R3_T
R3_MA = ["A4:6 C5:2 E5:8", "D5:6 B4:2 G4:8", "C5:4 E5:4 G5:4 E5:4", "F5:8 D5:4 B4:4",
         "A4:6 C5:2 F5:8", "E5:4 D5:4 B4:8", "C5:4 A4:4 E5:8", "C5:12 _:4"]
R3_MB = ["F5:6 E5:2 D5:4 A5:4", "G5:8 E5:4 D5:4", "A5:6 G5:2 E5:8", "D5:8 B4:4 D5:4",
         "E5:6 G5:2 C6:8", "B5:6 A5:2 G5:8", "E5:4 G5:4 B5:4 G5:4", "F5:8 G5:8"]
R3_COUNTER = ["C5:16", "B4:16", "A4:16", "B4:16", "F4:16", "G4:16", "A4:16", "G4:16"]


def explore3():
    s = Song(80, 28, tail=5.0)
    chords_track(s, "pad", R3_PROG, "warmpad", 3, 0.07, cutoff=1100)
    arp_track(s, "harp", R3_PROG, list("0.1.2.3.4.3.2.1."), 4, 0.1, "harp", note_len=3)
    bass_track(s, "sub", R3_PROG, "R-------5-------", 2, 0.38, "sub")
    s.melody("lead", "flute", R3_MA + R3_MB + R3_MA, 0, 0.28)
    s.melody("choir", "ooh", R3_COUNTER, 16, 0.09)
    chords_track(s, "choir", R3_T, "ooh", 4, 0.04, start_bar=24)
    whales(s, "whale", [(24, "C4", 22, -0.4), (26, "F3", 20, 0.4)], 0.18)
    s.drums("perc", {"s": "..4...4...4...45", "B": "....5.......5..."}, 0, 28, 0.45, {"s": 0.35, "B": -0.2})
    bubbles(s, "fx", 16, 0.05, seed=3)
    s.kicks.clear()
    # ---- drive
    beat = {"K": "9.......9.6.....", "r": "....7.......7...", "h": "..5...5...5...5."}
    beat_b = {"K": "9.......9.6...6.", "S": "....8.......8...", "h": "5.5.5.5.5.5.5.5.", "c": "......5.....5.5."}
    s.drums("d_drums", beat, 0, 8, 0.75)
    s.drums("d_drums", beat_b, 8, 8, 0.75)
    s.drums("d_drums", beat, 16, 8, 0.75)
    s.drums("d_drums", {"r": "....5.......5...", "h": "..4...4...4...4."}, 24, 4, 0.7)
    for b in (0, 8, 16):
        s.drums("d_drums", {"X": "7..............."}, b, 1, 0.5)
    arp_track(s, "d_arp", R3_PROG[:24], list("0243" "1342" "0243" "1432"), 4, 0.06, "marimba")
    bass_track(s, "d_bass", R3_PROG, "R..R....5..R.O..", 2, 0.3, "bass", cutoff=700)
    s.melody("d_lead", "lead", R3_MA + R3_MB + R3_MA, 0, 0.12, cutoff=2200)
    return s


R3_MIX_BASE = {"pad": (1.6, 0.5, 0.0, "duck", "chorus", ("sweep", 600.0, 2)), "harp": (1.6, 0.4, 0.4),
               "sub": (0.5, 0.0, 0.0, "duck"), "lead": (1.2, 0.45, 0.25), "choir": (1.8, 0.6, 0.0),
               "whale": (1.0, 0.8, 0.3), "perc": (1.0, 0.2, 0.0), "fx": (1.0, 0.5, 0.2)}
R3_MIX_DRIVE = {"d_drums": (0.45, 0.12, 0.0), "d_arp": (0.9, 0.3, 0.35), "d_bass": (0.95, 0.0, 0.0, "duck"),
                "d_lead": (2.0, 0.35, 0.3)}

# --- 4. "Abismo Azul": A minor / phrygian, 68 bpm, dark ambient deep sea
R4_P1 = ["Amadd9", "Amadd9", "Fmaj7", "Fmaj7", "Dm9", "Dm9", "Bbmaj7", "E7sus"]
R4_P2 = ["Amadd9", "Amadd9", "Cmaj7", "G", "Fmaj7", "Fmaj7", "Bbmaj7", "E7sus"]
R4_P3 = ["Dm9", "Dm9", "Amadd9", "Amadd9", "Bbmaj7", "Bbmaj7", "E7sus", "E"]
R4_PROG = R4_P1 + R4_P2 + R4_P3
R4_M1 = ["E4:16", "_:16", "C5:8 A4:8", "_:16", "F4:16", "E4:8 D4:8", "D4:16", "E4:12 _:4"]
R4_M2 = ["B4:16", "C5:8 E5:8", "G5:16", "D5:16", "C5:8 A4:8", "F5:16", "D5:8 F5:8", "E5:12 _:4"]
R4_M3 = ["A4:16", "F4:8 E4:8", "E4:16", "_:16", "F4:16", "D4:8 F4:8", "E4:16", "G#4:12 _:4"]


def explore4():
    s = Song(68, 24, tail=6.0)
    chords_track(s, "pad", R4_PROG, "warmpad", 3, 0.09, cutoff=700, attack=1.2)
    chords_track(s, "choir", R4_PROG, "ooh", 4, 0.035)
    bass_track(s, "sub", R4_PROG, "R---------------", 2, 0.36, "sub")
    s.melody("lead", "ooh", R4_M1, 0, 0.16)
    s.melody("lead", "flute", R4_M2, 8, 0.24)
    s.melody("lead", "ooh", R4_M3, 16, 0.16)
    s.melody("lead", "flute", R4_M3, 16, 0.12, octave=1)
    for bar in range(0, 24, 2):
        nm = ["A3", "E4", "A3", "C4", "D4", "A3", "E4", "A3", "D4", "A3", "F4", "E4"][bar // 2]
        s.note("sonar", "marimba", midi(nm), bar * 16 + 6, 2, 0.13, -0.3)
    whales(s, "whale", [(1, "E4", 30, -0.5), (6, "A3", 28, 0.5), (11, "C4", 30, -0.2), (17, "E3", 30, 0.4),
                        (21, "A3", 26, -0.4)], 0.22)
    bubbles(s, "fx", 12, 0.045, seed=4)
    s.kicks.clear()
    # ---- drive
    beat = {"K": "9..6....9..6....", "h": "..4...4...4...4."}
    beat_b = {"K": "9..6....9..6....", "S": "........7.......", "h": "..4...4...4...4.", "t": "..............76"}
    s.drums("d_drums", beat, 0, 8, 0.8)
    s.drums("d_drums", beat_b, 8, 8, 0.8)
    s.drums("d_drums", beat_b, 16, 8, 0.8)
    s.drums("d_drums", {"D": "9..............."}, 8, 1, 0.8)
    s.drums("d_drums", {"D": "9..............."}, 16, 1, 0.8)
    bass_track(s, "d_ost", R4_PROG, "R.R.R.R.R.R.R.O.", 2, 0.18, "pulse", cutoff=1000)
    s.melody("d_lead", "strings", R4_M1 + R4_M2 + R4_M3, 0, 0.1, octave=1, attack=0.3)
    s.fx("d_fx", dr_riser(s.step * 16 * 2), 14 * 16, 0.6)
    return s


R4_MIX_BASE = {"pad": (1.4, 0.55, 0.0, "duck", "chorus", ("sweep", 380.0, 3)), "choir": (1.8, 0.6, 0.0),
               "sub": (0.5, 0.0, 0.0, "duck"), "lead": (1.2, 0.55, 0.3), "sonar": (1.4, 0.6, 0.6),
               "whale": (0.9, 0.8, 0.35), "fx": (1.0, 0.5, 0.2)}
R4_MIX_DRIVE = {"d_drums": (0.45, 0.2, 0.0), "d_ost": (1.4, 0.2, 0.25, "duck"), "d_lead": (2.4, 0.5, 0.2),
                "d_fx": (1.0, 0.4, 0.0)}

# --- 5. "Maré Alta": G mixolydian, 122 bpm, upbeat adventure
R5_A = ["G", "D/F#", "Em7", "Cadd9", "G", "F", "C", "D"]
R5_B = ["Em7", "Cadd9", "G", "D", "Em7", "Cadd9", "Am7", "D7sus"]
R5_C = ["Cadd9", "D", "Bm7", "Em7", "Cadd9", "D", "F", "D"]
R5_PROG = R5_A + R5_B + R5_A + R5_C + R5_A
R5_MA = ["D5:3 G5:3 B5:2 A5:4 G5:4", "F#5:3 A5:3 D6:2 A5:4 F#5:4", "G5:3 B5:3 E6:2 D6:4 B5:4",
         "C6:6 B5:2 A5:4 G5:4", "D5:3 G5:3 B5:2 D6:4 B5:4", "C6:3 A5:3 F5:2 A5:4 C6:4",
         "E6:4 D6:4 C6:4 G5:4", "A5:12 _:4"]
R5_MB = ["_:4 B4:2 D5:2 E5:4 G5:4", "G5:6 E5:2 D5:4 C5:4", "_:4 B4:2 D5:2 G5:4 B5:4", "A5:8 F#5:4 D5:4",
         "_:4 E5:2 G5:2 B5:4 D6:4", "E6:6 D6:2 C6:4 G5:4", "A5:4 C6:4 E6:4 C6:4", "D6:8 C6:4 A5:4"]
R5_MC = ["E5:8 G5:8", "F#5:8 A5:8", "D6:12 B5:4", "B5:16", "C6:8 E6:8", "D6:8 A5:8", "C6:8 A5:8",
         "A5:4 B5:4 C6:4 D6:4"]
R5_MA2 = R5_MA[:7] + ["G5:12 _:4"]


def explore5():
    s = Song(122, 40, tail=4.0)
    comp_track(s, "gtr", R5_PROG, "x.x..x.x..x.x.x.", "harp", 3, 0.06, strum=0.12)
    chords_track(s, "pad", R5_PROG, "warmpad", 3, 0.05, cutoff=1300)
    bass_track(s, "sub", R5_PROG, "R---R---5---R---", 2, 0.36, "sub")
    s.melody("lead", "flute", R5_MA + R5_MB + R5_MA, 0, 0.28)
    s.melody("lead", "ooh", R5_MC, 24, 0.16)
    s.melody("lead", "flute", R5_MA2, 32, 0.28)
    arp_track(s, "arp", R5_B, list("0.2.1.3.2.4.3.1."), 4, 0.08, "marimba", start_bar=8)
    arp_track(s, "arp", R5_C, list("0.2.1.3.2.4.3.1."), 4, 0.08, "marimba", start_bar=24)
    perc = {"c": "..5..5....5..5..", "g": "5.......5.....5.", "s": "4.4.4.4.4.4.4.4."}
    s.drums("perc", perc, 0, 40, 0.5, {"c": 0.3, "g": -0.25, "s": 0.4})
    bubbles(s, "fx", 14, 0.05, seed=6)
    s.kicks.clear()
    # ---- drive
    rock = {"K": "9...9...9...9...", "S": "....9.......9...", "h": "..6...6...6...6."}
    rock_b = {"K": "9...9...9...9.6.", "S": "....9.......9...", "h": "6464646464646464", "o": "..............6."}
    fill = {"T": "........9.9.....", "t": "............9999", "S": "9...9..........."}
    s.drums("d_drums", rock, 0, 8, 0.8)
    s.drums("d_drums", rock_b, 8, 7, 0.8)
    s.drums("d_drums", fill, 15, 1, 0.8)
    s.drums("d_drums", rock, 16, 8, 0.8)
    s.drums("d_drums", rock_b, 24, 7, 0.8)
    s.drums("d_drums", fill, 31, 1, 0.8)
    s.drums("d_drums", rock_b, 32, 8, 0.8)
    for b in (0, 8, 16, 24, 32):
        s.drums("d_drums", {"X": "9..............."}, b, 1, 0.6)
    s.fx("d_fx", dr_riser(s.step * 16 * 2), 30 * 16, 0.8)
    bass_track(s, "d_bass", R5_PROG, "R.RO.RO.R.RO.R5O", 2, 0.3, "bass", cutoff=900)
    s.melody("d_lead", "lead", R5_MA + R5_MB + R5_MA + R5_MC + R5_MA2, 0, 0.14, cutoff=3000)
    comp_track(s, "d_brass", R5_C, "x.....x.....x...", "brass", 3, 0.05, start_bar=24, hold=2.5)
    return s


R5_MIX_BASE = {"gtr": (1.5, 0.3, 0.2, "duck"), "pad": (1.6, 0.45, 0.0, "duck", "chorus"),
               "sub": (0.5, 0.0, 0.0, "duck"), "lead": (1.2, 0.35, 0.25), "arp": (1.5, 0.35, 0.35),
               "perc": (1.0, 0.18, 0.0), "fx": (1.0, 0.5, 0.2)}
R5_MIX_DRIVE = {"d_drums": (0.4, 0.1, 0.0), "d_bass": (0.95, 0.0, 0.0, "duck"), "d_lead": (2.0, 0.3, 0.3),
                "d_brass": (1.8, 0.3, 0.1), "d_fx": (1.0, 0.3, 0.0)}

# song id -> (builder, base mix, drive mix, reverb seconds, delay kwargs, ocean swells, bed volume)
EXPLORE_SONGS = {
    "explore1": (explore1, R1_MIX_BASE, R1_MIX_DRIVE, 2.6, {"steps": 3, "feedback": 0.4}, 8, 0.05),
    "explore2": (explore2, R2_MIX_BASE, R2_MIX_DRIVE, 3.4, {"steps": 3, "feedback": 0.45, "repeats": 5}, 8, 0.07),
    "explore3": (explore3, R3_MIX_BASE, R3_MIX_DRIVE, 3.2, {"steps": 3, "feedback": 0.45, "repeats": 5}, 7, 0.06),
    "explore4": (explore4, R4_MIX_BASE, R4_MIX_DRIVE, 4.0, {"steps": 6, "feedback": 0.5, "repeats": 6, "tone": 2500.0}, 6, 0.09),
    "explore5": (explore5, R5_MIX_BASE, R5_MIX_DRIVE, 2.4, {"steps": 3, "feedback": 0.38}, 10, 0.04),
}


def render_explore(key):
    build, mb, md, rv, dl, swells, bed = EXPLORE_SONGS[key]
    s = build()
    base = loop_wrap(mixdown(s, mb, 0.15, rv, 4200.0, dl), s.length)
    drive = loop_wrap(mixdown(s, md, 0.4, rv, 4200.0, dl), s.length)
    base += ocean_bed(s.length, swells, seed=int(key[-1]) + 20) * bed * np.abs(base).max()
    k = 1.0 / max(1e-6, np.abs(base + drive).max())
    base = master_loop(base * k, np.abs(base * k).max(), lp=11000)
    drive = master_loop(drive * k, np.abs(drive * k).max(), lp=11000)
    base, drive = normalize_pair(base, drive, target=0.89)
    return base, drive


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
# "Canção das Marés": E lydian, 72 bpm. Deep warm pads with chorus, a slow
# flute melody, a harp arpeggio through a dotted ping-pong delay, whale calls,
# bubbles and wave-noise swells. No bells: warm, deep and flowing.
MENU_A = ["Emaj9", "F#/E", "Emaj9", "F#/E", "C#m9", "Amaj9", "F#m11", "Bsus"]
MENU_B = ["Amaj9", "B", "G#m7", "C#m9", "Amaj9", "B", "Emaj9", "F#/E"]
MENU_PROG = MENU_A + MENU_B + MENU_A
MENU_MA = ["B4:6 C#5:2 D#5:8", "A#4:8 F#4:8", "G#4:4 B4:4 D#5:4 F#5:4", "E5:8 C#5:4 A#4:4",
           "G#4:12 E4:4", "C#5:8 B4:4 A4:4", "G#4:6 A4:2 B4:8", "F#4:16"]
MENU_MB = ["C#5:6 E5:2 G#5:8", "F#5:8 D#5:8", "D#5:6 B4:2 G#4:8", "E5:8 G#5:8",
           "C#5:4 E5:4 A5:4 G#5:4", "F#5:12 D#5:4", "E5:4 D#5:4 B4:8", "A#4:8 C#5:8"]


def menu():
    s = Song(72, 24, tail=6.0)
    chords_track(s, "pad", MENU_PROG, "warmpad", 3, 0.085, cutoff=1000)
    chords_track(s, "choir", MENU_B, "ooh", 4, 0.04, start_bar=8)
    arp_track(s, "harp", MENU_PROG, list("0.2.4.3.1.3.2.4."), 4, 0.1, "harp", note_len=3)
    bass_track(s, "sub", MENU_PROG, "R-------5-------", 2, 0.36, "sub")
    s.melody("lead", "flute", MENU_MA + MENU_MB + MENU_MA, 0, 0.3)
    s.melody("lead2", "ooh", MENU_MA, 16, 0.11, -0.3, octave=-1)
    s.melody("lead2", "marimba", MENU_MB, 8, 0.06, 0.4, octave=-1)
    whales(s, "whale", [(3, "B3", 28, -0.5), (11, "E4", 26, 0.5), (19, "G#3", 30, -0.3)], 0.2)
    s.drums("perc", {"g": "5.......4.....3.", "s": "..3...3...3...3."}, 8, 16, 0.4, {"g": -0.2, "s": 0.35})
    bubbles(s, "fx", 14, 0.05, seed=9)
    return s


MENU_MIX = {"pad": (1.5, 0.55, 0.0, "chorus", ("sweep", 500.0, 3)), "choir": (1.8, 0.6, 0.0),
            "harp": (1.7, 0.45, 0.45), "sub": (0.5, 0.0, 0.0), "lead": (1.2, 0.45, 0.28),
            "lead2": (1.4, 0.55, 0.2), "whale": (1.0, 0.8, 0.35), "perc": (1.0, 0.25, 0.0),
            "fx": (1.0, 0.5, 0.2)}


def render_menu():
    s = menu()
    x = loop_wrap(mixdown(s, MENU_MIX, 0.0, 3.6, 4000.0, {"steps": 3, "feedback": 0.48, "repeats": 6}), s.length)
    x += ocean_bed(s.length, 12, seed=31) * 0.08 * np.abs(x).max()
    x = master_loop(x, 1.0, lp=10000)
    return x * 0.86 / np.abs(x).max()


# ------------------------------------------------------------------- horde
# "Horda": E phrygian, 148 bpm. Taiko + snare, a 16th pulse ostinato, string
# ostinato, urgent brass stabs, then a brass melody; a breakdown with a whale
# call and riser keeps it underwater.
H_1 = ["Em", "Em", "C", "D", "Em", "Em", "F", "B7"]
H_2 = ["Am", "Em", "F", "Em", "Am", "C", "D", "B"]
H_BRK = ["Em", "F", "Em", "F"]
HORDE_PROG = H_1 + H_2 + H_BRK + H_1
H_M1 = ["E5:4 B4:2 E5:2 G5:4 F#5:2 E5:2", "B5:8 A5:4 G5:4", "G5:4 E5:2 G5:2 C6:4 B5:2 A5:2",
        "A5:8 F#5:4 D5:4", "E5:4 B4:2 E5:2 G5:4 A5:2 B5:2", "E6:8 D6:4 B5:4", "C6:4 A5:4 F5:4 A5:4",
        "B5:4 A5:4 F#5:4 D#5:4"]
H_M2 = ["A5:6 C6:2 E6:8", "B5:6 G5:2 E5:8", "C6:8 A5:8", "B5:16", "A5:4 C6:4 E6:4 C6:4",
        "E6:8 C6:8", "D6:8 A5:8", "B5:8 D#6:8"]


def horde():
    s = Song(148, 28, tail=3.5)
    bass_track(s, "ost", HORDE_PROG, "RRORRROR5RROR5OR", 2, 0.24, "pulse", cutoff=1600)
    bass_track(s, "sub", HORDE_PROG, "R-------R-------", 1, 0.34, "sub")
    arp_track(s, "str", H_1 + H_2, list("0.1.2.1.0.1.2.1."), 4, 0.09, "strings", note_len=1.8, attack=0.01)
    arp_track(s, "str", H_1, list("0.1.2.1.0.1.2.1."), 4, 0.09, "strings", start_bar=20, note_len=1.8,
              attack=0.01)
    comp_track(s, "stab", H_1 + H_2, "x..x..x...x..x..", "brass", 3, 0.055, hold=1.5)
    comp_track(s, "stab", H_1, "x..x..x...x..x..", "brass", 3, 0.055, start_bar=20, hold=1.5)
    chords_track(s, "pad", HORDE_PROG, "warmpad", 3, 0.045, cutoff=1400, attack=0.3)
    s.melody("lead", "strings", H_M1, 0, 0.16, attack=0.05)
    s.melody("lead", "brass", H_M2, 8, 0.24)
    s.melody("lead", "brass", H_M1, 20, 0.24)
    s.melody("lead", "strings", H_M1, 20, 0.12, octave=-1, attack=0.05)
    whales(s, "whale", [(16, "E3", 40, -0.4)], 0.22)
    s.fx("fx", dr_riser(s.step * 16 * 2), 18 * 16, 0.9)
    main_ = {"D": "9.......9.......", "K": "9..9..9...9..9..", "S": "....9.......9...", "h": "5.7.5.7.5.7.5.7."}
    main_b = {"D": "9.....7.9.......", "K": "9..9..9...9..9.9", "S": "....9.......9..6", "h": "5757575757575757",
              "t": "..............7."}
    fill = {"T": "9.9.9.9.........", "t": "........9.9.9999", "D": "9..............."}
    s.drums("drums", main_, 0, 7, 0.8)
    s.drums("drums", fill, 7, 1, 0.8)
    s.drums("drums", main_b, 8, 7, 0.8)
    s.drums("drums", fill, 15, 1, 0.8)
    s.drums("drums", {"D": "9.......9.......", "t": "............7.7."}, 16, 3, 0.8)
    s.drums("drums", {"D": "9...9...9...9...", "S": "..............99"}, 19, 1, 0.8)
    s.drums("drums", main_b, 20, 7, 0.8)
    s.drums("drums", fill, 27, 1, 0.8)
    for b in (0, 8, 20):
        s.drums("drums", {"X": "9..............."}, b, 1, 0.65)
    return s


HORDE_MIX = {"ost": (1.4, 0.1, 0.12, "duck"), "sub": (0.6, 0.0, 0.0, "duck"), "str": (2.4, 0.3, 0.15),
             "stab": (1.6, 0.3, 0.1), "pad": (1.4, 0.4, 0.0, "duck", "chorus"), "lead": (1.4, 0.3, 0.2),
             "whale": (1.0, 0.8, 0.3), "fx": (1.0, 0.3, 0.0), "drums": (0.38, 0.12, 0.0)}


def render_horde():
    s = horde()
    x = loop_wrap(mixdown(s, HORDE_MIX, 0.35, 2.4, 4500.0, {"steps": 3, "feedback": 0.35}), s.length)
    x += ocean_bed(s.length, 7, seed=41) * 0.04 * np.abs(x).max()
    x = master_loop(x, 1.25, lp=12000)
    return x * 0.89 / np.abs(x).max()


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
    elif kind == "horde":        # alarm: water swell -> taiko + deep horn in E
        s = Song(100, 2, tail=2.5)
        s.fx("fx", dr_riser(0.4) * 1.6, 0, 1.0)
        for n, v in (("E2", 0.3), ("B2", 0.24), ("E3", 0.22), ("G3", 0.12)):
            s.note("horn", "horn", midi(n), 2.5, 8, v)
        s.note("whale", "whale", midi("E3"), 2.5, 12, 0.18)
        s.drums("drums", {"D": "..9.....7.9.....", "X": "..9.............", "t": "......6.6......."}, 0, 1, 0.9)
        mix = {"fx": (1.0, 0.3, 0.0), "horn": (1.0, 0.4, 0.0), "whale": (1.0, 0.6, 0.0),
               "drums": (0.8, 0.25, 0.0)}
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
    if kind == "horde":
        x = x[: int(3.0 * SR)]
        fade = int(0.5 * SR)
    else:
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
    for key in EXPLORE_SONGS:
        if not want or "explore" in want or key in want:
            base, drive = render_explore(key)
            write(key + "_base", base, 0.85)
            write(key + "_drive", drive, 0.9)
    if not want or "horde" in want:
        write("horde", render_horde())
        write("sting_horde", stinger("horde"))
    if not want or "boss" in want:
        s = boss()
        x = master(render_loop(s, BOSS_MIX, 0.4))
        write("boss", x * 0.89 / np.abs(x).max())
    if not want or "final" in want:
        s = final()
        x = master(render_loop(s, FINAL_MIX, 0.35))
        write("final", x * 0.89 / np.abs(x).max())
    if not want or "menu" in want:
        write("menu", render_menu())
    if not want or "stingers" in want:
        for k in ("levelup", "victory", "defeat", "fusion", "horde"):
            write("sting_" + k, stinger(k))


if __name__ == "__main__":
    main()
