"""Natural life cycles for the playable fish (see scripts/data/evolutions.gd).

Every fish is redrawn per stage from its real development, not scaled:
  0 larva    : glass body, huge dark eye, continuous fin fold, yolk sac,
               a row of melanophores along the gut and a few chromatophores
               of the adult colour. Live-bearers (sharks, orca...) are born
               as miniature newborns instead;
  1 fry      : still see-through fins, big eye, dull colours and parr marks;
  2 juvenile : the species' own juvenile colouring (a goldfish is still
               bronze, a juvenile piranha is spotted, a grouper is banded...);
  3 adult    : the species as designed in player.SPECIES;
  4 apex     : a legendary form unique to the species (oranda wen, porcupine
               spines, the moray-dragon's horns, the black piranha...).
"""
from __future__ import annotations

import math

import numpy as np

from pro import PAL, ramp, poly_mask, seg_dist

PAL.setdefault("larva", ramp("#bfe6ee", dark=0.45, light_gain=0.9))
PAL.setdefault("larvafin", ramp("#d8f0f4", dark=0.5))
PAL.setdefault("yolk", ramp("#ffb84a", dark=0.35))
PAL.setdefault("fry", ramp("#8a9a86", dark=0.3))
PAL.setdefault("bronze", ramp("#8a6a3a", dark=0.3))
PAL.setdefault("wen", ramp("#ff6a3a"))
PAL.setdefault("blackfish", ramp("#2a2e3a", dark=0.35, light_gain=0.7))
PAL.setdefault("dragon", ramp("#e8641e"))
PAL.setdefault("calf", ramp("#f0c890", dark=0.3))
PAL.setdefault("goldglow", ramp("#ffd84a"))

LIVE_BORN = {"tubarao", "megalodonte", "orca", "titanacon"}
NO_YOLK = {"kraken", "moreia"}
LARVA_ALPHA = 185
FRY_ALPHA = 215


# ------------------------------------------------------------ small parts
def melanophores(fish, st, f, lay):
    """A dotted row of dark pigment cells along the gut of a larva."""
    if fish.L < 14:
        return
    step = max(2.0, fish.L * 0.09)
    row = f["body"] & (np.abs(f["v"] - 0.78) * (fish.bottom(f["t"]) - fish.top(f["t"])) < 0.55)
    row &= ((f["sx"] - fish.xt) % step) < 1.0
    row &= (f["t"] > 0.12) & (f["t"] < 0.7)
    lay.paint(row, "ink", 2)


def chromatophores(ramp_name):
    """Three or four spots of the adult colour on the larva's back."""
    def fn(fish, st, f, lay):
        for k, t0 in enumerate((0.3, 0.45, 0.6, 0.72)):
            x0 = fish.xt + t0 * fish.L
            y0 = float(fish.section_y(t0, 0.32 + 0.05 * (k % 2)))
            r = max(0.6, fish.L * 0.022)
            lay.paint(f["body"] & (np.hypot(f["x"] - x0, f["y"] - y0) <= r), ramp_name, 4)
    return fn


def notochord(fish, st, f, lay):
    on = f["body"] & (np.abs(f["v"] - 0.46) * (fish.bottom(f["t"]) - fish.top(f["t"])) < 0.5)
    on &= (f["t"] > 0.04) & (f["t"] < 0.74)
    lay.shift(on, +1, hi=6)


def yolk_sac(fish, st, f, lay):
    """The yolk hangs under the throat of a newly hatched larva."""
    t0 = 0.66
    x0 = fish.xt + t0 * fish.L
    y0 = float(fish.bottom(t0)) + fish.H * 0.1
    rx, ry = fish.L * 0.13, max(1.2, fish.H * 0.32)
    d = ((f["x"] - x0) / rx) ** 2 + ((f["y"] - y0) / ry) ** 2
    sac = d <= 1.0
    tone = np.where(f["y"] < y0 - ry * 0.3, 5, np.where(f["y"] > y0 + ry * 0.4, 3, 4))
    lay.paint(sac, "yolk", tone)
    # oil droplet highlight
    lay.paint(sac & (np.hypot(f["x"] - (x0 - rx * 0.3), f["y"] - (y0 - ry * 0.2)) < max(0.6, ry * 0.3)), "yolk", 6)


def parr_marks(ramp_name="ink", n=6):
    """Soft vertical blotches along the flank of the fry."""
    def fn(fish, fl):
        t = fl["t"]
        k = ((t - 0.12) * n) % 1.0
        on = fl["body"] & (k < 0.35) & (t > 0.12) & (t < 0.72) & (fl["v"] > 0.25) & (fl["v"] < 0.62)
        fl["lay"].shift(on, -1, lo=2)
    return fn


def spot_rows(ramp_name, v=0.35, step=0.07, t0=0.2, t1=0.72, tone=2, r=0.028):
    def fn(fish, st, f, lay):
        s = max(2.0, step * fish.L)
        for i in range(40):
            t = t0 + i * s / fish.L
            if t > t1:
                break
            x0 = fish.xt + t * fish.L
            y0 = float(fish.section_y(t, v))
            lay.paint(f["body"] & (np.hypot(f["x"] - x0, f["y"] - y0) <= max(0.6, r * fish.L)), ramp_name, tone)
    return fn


def blotches(ramp_name, seed=3, v_max=0.7, density=0.6, cell=0.1, shift=0):
    def fn(fish, fl):
        import player
        player.spots(fish, fl, ramp_name, cell=cell, rad=(0.025, 0.045), zone=fl["v"] < v_max, seed=seed,
                     density=density, shift=shift)
    return fn


def body_spines(ramp_name="bone", n=14, ln=0.12):
    """Porcupine-fish spines standing out all around the body."""
    def shape(fish, st, x, y):
        mask = np.zeros(x.shape, dtype=bool)
        for i in range(n):
            t = 0.12 + i * 0.72 / (n - 1)
            for side in (-1, 1):
                if side < 0:
                    by = float(fish.top(t))
                else:
                    by = float(fish.bottom(t))
                bx = fish.xt + t * fish.L
                ang = (math.pi * 0.5) * side + (0.5 - t) * 0.9 * side * -1
                tip = (bx - math.cos(ang) * 0 + (t - 0.5) * fish.L * ln * 0.8, by + side * fish.L * ln)
                w = max(0.7, fish.L * 0.022)
                mask |= poly_mask(x, y, [(bx - w, by - side * 0.8), tip, (bx + w, by - side * 0.8)])
        return mask & ~fish.inside(x, y), ramp_name, 5
    return shape


def nostril_horns(fish, st, x, y):
    """The moray-dragon's tubular nostril horns."""
    mask = np.zeros(x.shape, dtype=bool)
    tn = 0.96
    bx, by = fish.xt + tn * fish.L, float(fish.top(tn))
    for k, (dx, h) in enumerate(((0.0, 0.1), (-0.05, 0.08))):
        x0 = bx + dx * fish.L
        mask |= poly_mask(x, y, [(x0 - fish.L * 0.012, by + 0.8), (x0 + fish.L * 0.03, by - fish.L * h),
                                 (x0 + fish.L * 0.03, by + 0.8)])
    return mask, "dragon", 5


def wen(fish, st, f, lay):
    """Oranda's bumpy head growth."""
    hx0 = fish.xt + 0.74 * fish.L
    zone = f["up"] & (f["x"] > hx0) & (f["v"] < 0.45)
    bumps = zone & (np.sin(f["x"] * 1.7) * np.sin(f["y"] * 1.9) > 0.15)
    lay.paint(zone, "wen", 4)
    lay.shift(bumps, +1, hi=6)
    lay.shift(zone & ~bumps & (np.sin(f["x"] * 1.7 + 1.5) > 0.7), -1, lo=2)


def crown_lights(fish, st, f, lay):
    for k in range(4):
        t = 0.62 + k * 0.08
        x0 = fish.xt + t * fish.L
        y0 = float(fish.top(t)) + 1.2
        lay.paint((np.abs(f["x"] - x0) < 0.6) & (np.abs(f["y"] - y0) < 0.6), "glow", 6, outline=False)


def star_field(fish, st, f, lay):
    on = f["body"] & (((np.floor(f["sx"]) * 7 + np.floor(f["sy"]) * 13) % 23) == 0) & (f["v"] < 0.8)
    lay.paint(on, "glow", 5, outline=False)


def golden_glints(fish, st, f, lay):
    on = f["body"] & (((np.floor(f["sx"]) * 5 + np.floor(f["sy"]) * 11) % 17) == 0)
    lay.paint(on, "goldglow", 6, outline=False)


def calf_patches(fish, fl):
    """An orca calf's white patches are still peach/orange."""
    from pro import PAL as P
    lay = fl["lay"]
    wi = next((i for i, r in enumerate(lay.ramps) if r is P["white"]), -1)
    if wi >= 0:
        sel = (lay.mat == wi) & fl["body"]
        lay.paint(sel, "calf", lay.tone)


def larva_ramps(species, adult_body):
    """Glass tinted with a hint of the adult colour, so every larva is its own."""
    base = PAL.get(adult_body, PAL["larva"])[4]
    glass = (0xbf, 0xe6, 0xee)
    mix = tuple(int(g * 0.5 + b * 0.5) for g, b in zip(glass, base))
    hexc = "#%02x%02x%02x" % mix
    kb, kf = "larva_" + species, "larvafin_" + species
    PAL.setdefault(kb, ramp(hexc, dark=0.45, light_gain=0.9))
    fmix = tuple(int(g * 0.8 + b * 0.2) for g, b in zip((0xd8, 0xf0, 0xf4), base))
    PAL.setdefault(kf, ramp("#%02x%02x%02x" % fmix, dark=0.5))
    return kb, kf


def larval_spines(fish, st, x, y):
    """Grouper larvae carry a very long dorsal and pelvic spine."""
    t0 = 0.62
    bx, by = fish.xt + t0 * fish.L, float(fish.top(t0))
    m = poly_mask(x, y, [(bx - 1.1, by + 0.5), (bx - fish.L * 0.18, by - fish.L * 0.42), (bx + 1.1, by + 0.5)])
    t1 = 0.66
    px, py = fish.xt + t1 * fish.L, float(fish.bottom(t1))
    m |= poly_mask(x, y, [(px - 1.1, py - 0.5), (px - fish.L * 0.12, py + fish.L * 0.3), (px + 1.1, py - 0.5)])
    return m & ~fish.inside(x, y), "bone", 5


def _grow(fin, k):
    if not fin or not isinstance(fin, tuple) or len(fin) < 4:
        return fin
    return fin[:3] + (fin[3] * k,) + fin[4:]


# ------------------------------------------------------ per species data
# juvenile colouring (stage 2)
JUVENILE = {
    "dourado": dict(body="bronze", fin="bronze", tail_len=0.42, patterns=[blotches("gold", seed=4, density=0.7, cell=0.12)]),
    "dourado_raro": dict(tail_len=0.4, patterns=[parr_marks()]),
    "sardinha": dict(patterns=[], body="silver"),
    "neon": dict(patterns=["adult"]),
    "garoupa": dict(body="sandy", patterns=[lambda fish, fl: __import__("fishes").bars("brown", 0.16, 0.45, 0.8, 0.1, 0.8, shift=-1)(fish, fl)]),
    "barracuda": dict(patterns=[blotches("sharkgrey", seed=8, v_max=0.6, density=0.8, cell=0.12, shift=-1)]),
    "piranha": dict(belly="silver", patterns=[blotches("ink", seed=12, v_max=0.8, density=0.7, cell=0.08)]),
    "baiacu": dict(patterns=[blotches("brown", seed=5, v_max=0.6, density=0.9, cell=0.1, shift=-1)]),
    "moreia": dict(body="olive", belly="olive", patterns=[]),
    "lanterna": dict(patterns=[]),
    "vibora": dict(patterns=[]),
    "orca": dict(patterns=["adult"]),
}

# legendary last stage
APEX = {
    "dourado": dict(spec=dict(hump=0.22, hump_t=0.86, hump_w=0.09, tail_len=0.78, fin="flame"),
                    grow=1.3, extras=[wen]),
    "dourado_raro": dict(spec=dict(tail_len=0.72, fin="goldglow"), grow=1.35, extras=[golden_glints]),
    "sardinha": dict(spec=dict(fin="neon"), extras=[spot_rows("navy", v=0.4, step=0.08, t0=0.4, t1=0.7)]),
    "neon": dict(patterns=[lambda fish, fl: __import__("player").recolor(
        fl, fl["body"] & (fl["v"] > 0.46) & (fl["t"] < 0.95) & (fl["t"] > 0.04), "red")]),
    "baiacu": dict(spec=dict(H=0.86), shapes=[body_spines()]),
    "lanterna": dict(spec=dict(eye=0.2), extras=[lambda fish, st, f, lay: __import__("fishes").photophores(0.62, 0.08)(fish, st, f, lay),
                                                 crown_lights]),
    "garoupa": dict(spec=dict(H=0.62, peak=0.45, body="olive", eye=0.06),
                    patterns=[blotches("sandy", seed=6, v_max=0.75, density=0.6, cell=0.09, shift=1)], grow=1.1),
    "barracuda": dict(spec=dict(H=0.21), scars=True, patterns=[blotches("ink", seed=9, v_max=0.7, density=0.5, cell=0.1)]),
    "piranha": dict(spec=dict(body="blackfish", belly="red", fin="blackfish", eye=0.12), keep_pattern=False),
    "moreia": dict(spec=dict(body="dragon", belly="cream", fin="dragon", eye=0.06),
                   patterns=[blotches("white", seed=19, v_max=0.8, density=0.7, cell=0.07)], shapes=[nostril_horns],
                   grow=1.25),
    "orca": dict(grow=1.35, scars=True),
    "vibora": dict(extras=[star_field]),
    "tubarao": dict(grow=1.2, scars=True),
    "kraken": dict(extras=[star_field]),
    "pescadora": dict(extras=[crown_lights]),
    "leviata": dict(grow=1.2),
    "megalodonte": dict(grow=1.15, scars=True),
    "titanacon": dict(grow=1.15),
}


# ------------------------------------------------------------- transform
def transform(species, stage, spec):
    """Returns (spec, patterns, extras, shapes, alpha) for this life stage.

    spec     : a copy of player.SPECIES[species] changed for the stage
    patterns : extra body patterns (fish, fields) run after the species one
    extras   : body detail painters (fish, st, fields, layer)
    shapes   : extra head shapes (fish, st, x, y) -> (mask, ramp, tone)
    alpha    : {ramp name: alpha} for see-through larval tissue
    """
    import fishes
    spec = dict(spec)
    patterns, extras, shapes, alpha = [], [], [], {}
    live = species in LIVE_BORN
    adult_body = spec.get("body")
    if stage == 0 and not live:
        spec.update(H=spec["H"] * (0.62 if species != "baiacu" else 0.8), eye=min(0.17, spec.get("eye", 0.09) * 2.0),
                    eye_ramp="iris_dark", fin_alpha=LARVA_ALPHA,
                    dorsal=("long", 0.04, 0.78, 0.5), anal=("long", 0.04, 0.5, 0.42), pectoral=(0.14, 0.1),
                    pelvic=0.0, tail="round", tail_len=0.3, gill=False, scales=False, countershade=0.0,
                    backshade=0.0, hump=0.0, dorsal2=None, belly_v=0.95)
        kb, kf = larva_ramps(species, adult_body)
        spec.update(body=kb, belly=kb, fin=kf, tail_ramp=kf)
        if species == "garoupa":
            shapes.append(larval_spines)
        if species == "moreia":
            # leptocephalus: a transparent willow leaf with a tiny head
            spec.update(H=0.3, peak=0.5, q=0.7, front_e=0.9, ped=0.2, eye=0.05, top_ratio=0.5)
            patterns.append(lambda fish, fl: fl["lay"].shift(
                fl["body"] & (np.abs(((fl["sx"] - fish.xt) / max(2.0, fish.L * 0.06) + np.abs(fl["v"] - 0.5) * 1.5) % 1.0) < 0.14),
                -1, lo=2))
        spec["pattern"] = None
        m = dict(spec.get("mouth") or {})
        m["teeth_len"] = m.get("teeth_len", 0.0) * 0.4
        m["jaw_ramp"] = None
        spec["mouth"] = m
        extras += [notochord, melanophores, chromatophores(adult_body)]
        if species not in NO_YOLK:
            extras.append(yolk_sac)
        alpha = {kb: LARVA_ALPHA, kf: LARVA_ALPHA}
        return spec, patterns, extras, shapes, alpha
    if stage == 0 and live:
        # newborn: big head and eye, rounder, softer colours
        spec.update(H=spec["H"] * 1.1, eye=spec.get("eye", 0.05) * 1.6, dorsal=_grow(spec.get("dorsal"), 0.8))
        if species == "orca":
            patterns.append(calf_patches)
        return spec, patterns, extras, shapes, alpha
    if stage == 1:
        spec.update(H=spec["H"] * 0.88, eye=min(0.15, spec.get("eye", 0.09) * 1.45),
                    dorsal=_grow(spec.get("dorsal"), 0.8), anal=_grow(spec.get("anal"), 0.85),
                    tail_len=spec.get("tail_len", 0.4) * 0.85, fin_alpha=min(spec.get("fin_alpha", 255), 200),
                    scales=False)
        if not live:
            if species not in ("neon", "lanterna", "vibora", "pescadora", "kraken", "leviata", "dourado_raro"):
                if species in ("dourado", "garoupa", "baiacu"):
                    spec.update(body="fry", fin="fry")
            spec["pattern"] = None
            patterns.append(parr_marks())
            alpha = {spec.get("fin", ""): 200}
        if species == "orca":
            patterns.append(calf_patches)
        return spec, patterns, extras, shapes, alpha
    if stage == 2:
        juv = JUVENILE.get(species)
        spec.update(dorsal=_grow(spec.get("dorsal"), 0.92))
        if juv:
            juv = dict(juv)
            pats = juv.pop("patterns", [])
            if "adult" not in pats:
                spec["pattern"] = None
            patterns += [p for p in pats if p != "adult"]
            spec.update(juv)
        return spec, patterns, extras, shapes, alpha
    if stage == 3:
        spec.update(dorsal=_grow(spec.get("dorsal"), 1.1), anal=_grow(spec.get("anal"), 1.05))
        if species in ("tubarao", "barracuda", "megalodonte", "orca", "titanacon"):
            extras.append(fishes.scars)
        return spec, patterns, extras, shapes, alpha
    # stage 4: the legendary form
    ap = APEX.get(species, {})
    g = ap.get("grow", 1.2)
    spec.update(dorsal=_grow(spec.get("dorsal"), g), anal=_grow(spec.get("anal"), min(g, 1.15)),
                tail_len=spec.get("tail_len", 0.4) * min(1.2, g))
    spec.update(ap.get("spec", {}))
    if not ap.get("keep_pattern", True):
        spec["pattern"] = None
    patterns += ap.get("patterns", [])
    extras += ap.get("extras", [])
    shapes += ap.get("shapes", [])
    if ap.get("scars"):
        extras.append(fishes.scars)
    return spec, patterns, extras, shapes, alpha
