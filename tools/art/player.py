"""Player fish atlases: one PNG per species/stage, one row per layer, 10 frames.

Frames: 0-5 swim, 6-9 bite (see fishpro.FRAMES).
Rows (see LAYERS, also stored in art_meta.json):
  * body variants: every head mutation x skin mutation is rendered as a whole
    body, so the jaw, teeth, rostrum or lure are part of the head itself and
    open with it (no overlays on top of a closed mouth);
  * tails and fins stay separate rows so any combination can be assembled.
"""
from __future__ import annotations

import math

import numpy as np
from PIL import Image

import fishpro as FP
from fishpro import Fish, Layer, recolor, bill_shape, lure_shape, lure_detail, lure_screen
from pro import poly_mask, seg_dist

STAGE_LEN = [20, 28, 36, 46, 58]
HEADS = ["", "head_piranha", "head_sword", "head_lure"]
SKINS = ["", "skin_armor", "skin_toxic", "skin_glow"]


def body_key(head: str, skin: str) -> str:
    k = "body"
    if head:
        k += "+" + head
    if skin:
        k += "+" + skin
    return k


BODY_ROWS = [body_key(hd, sk) for hd in HEADS for sk in SKINS]
TAIL_ROWS = ["tail", "tail_fork", "tail_sting", "tail_eel"]
FIN_ROWS = ["fins_back", "fins_front", "fins_spiky_back", "fins_spiky_front", "fins_wing_back",
            "fins_wing_front", "fins_volt_back", "fins_volt_front"]
LAYERS = BODY_ROWS + TAIL_ROWS + FIN_ROWS


# ------------------------------------------------------------------ patterns
def _hash(a, b, seed=0):
    v = np.sin(a * 12.9898 + b * 78.233 + seed * 37.719) * 43758.5453
    return v - np.floor(v)


def neon_pattern(fish, f):
    t, v = f["t"], f["v"]
    body = f["body"]
    recolor(f, body & (v > 0.5) & (v < 0.84) & (t < 0.55) & (t > 0.04), "red")
    stripe = body & (v > 0.3) & (v < 0.46) & (t > 0.16) & (t < 0.93)
    recolor(f, stripe, "cyan", shift=1, lo=3)


def spots(fish, f, ramp, cell=0.085, rad=(0.018, 0.034), zone=None, seed=1, shift=0, density=0.75):
    """Organic spots in body space (they ride on the jaw when it opens)."""
    c = max(2.5, cell * fish.L)
    sx, sy = f["sx"], f["sy"]
    gx, gy = np.floor((sx - fish.xt) / c), np.floor((sy - fish.cy) / c)
    ox, oy = _hash(gx, gy, seed), _hash(gy, gx, seed + 7)
    rr = (rad[0] + (rad[1] - rad[0]) * _hash(gx, gy, seed + 3)) * fish.L
    keep = _hash(gx, gy, seed + 11) < density
    cxs = fish.xt + (gx + 0.2 + 0.6 * ox) * c
    cys = fish.cy + (gy + 0.2 + 0.6 * oy) * c
    d = np.hypot(sx - cxs, (sy - cys) * 1.1)
    msk = f["body"] & keep & (d <= np.maximum(0.6, rr))
    if zone is not None:
        msk &= zone
    recolor(f, msk, ramp, shift=shift)
    return msk


def garoupa_pattern(fish, f):
    zone = (f["v"] < 0.78) & (f["t"] > 0.05)
    spots(fish, f, "brown", zone=zone, seed=3, shift=-1)
    spots(fish, f, "sandy", cell=0.11, rad=(0.012, 0.02), zone=zone & (f["v"] < 0.6), seed=9, density=0.5)
    # darker saddle bands on the back
    band = f["body"] & (f["v"] < 0.4) & (np.sin((f["t"] * 5.5) * math.pi) > 0.55) & (f["t"] < 0.7)
    f["lay"].shift(band, -1, lo=2)


def kraken_pattern(fish, f):
    spots(fish, f, "coral", cell=0.1, rad=(0.018, 0.03), zone=f["v"] < 0.7, seed=27, shift=1, density=0.6)


def kraken_arms(fish, st, x, y):
    """Arms reaching forward from the head, waving with the swim phase."""
    L, H = fish.L, fish.H
    mask = np.zeros(x.shape, dtype=bool)
    tone = np.zeros(x.shape, dtype=np.int32)
    for k in range(4):
        y0 = fish.cy + (k - 1.2) * H * 0.14
        x0 = fish.xn - 0.1 * L
        ln = L * (0.3 + 0.05 * (k % 2))
        d = np.full(x.shape, 99.0)
        r = np.zeros(x.shape)
        prev = (x0, y0)
        for i in range(1, 9):
            u = i / 8
            px = x0 + u * ln
            py = y0 + math.sin(u * 3.2 - st["phase"] + k) * H * 0.12 * u + (k - 1.5) * u * H * 0.12
            di = seg_dist(x, y, prev[0], prev[1], px, py)
            closer = di < d
            r = np.where(closer, max(0.6, H * 0.075 * (1.0 - u * 0.7)), r)
            d = np.minimum(d, di)
            prev = (px, py)
        m = d <= r
        mask |= m
        tone = np.where(m, np.where(y < y0, 5, 4) - (k % 2), tone)
    return mask, "kraken", tone


def leviathan_horn(fish, st, x, y):
    t0 = 0.74
    bx, by = fish.xt + t0 * fish.L, float(fish.top(t0)) + 1.0
    pts = [(bx - 1, by), (bx - 0.2 * fish.L, by - fish.H * 0.55), (bx - 0.12 * fish.L, by - fish.H * 0.45), (bx + 3, by + 0.5)]
    msk = poly_mask(x, y, pts)
    return msk, "bone", np.where(y < by - fish.H * 0.25, 5, 4)


def leviathan_pattern(fish, f):
    t = f["t"]
    on = f["body"] & (((t * 12.0) % 1.0) < 0.2) & (t < 0.66) & (f["v"] < 0.6)
    recolor(f, on, "volt", shift=1, lo=3)


def titan_pattern(fish, f):
    import fishes
    fishes.titan_armor(fish, f)


def shark_extras(fish):
    import fishes
    fish.extras.append(fishes.gill_slits(4, 0.66))


def titan_extras(fish):
    import fishes
    fish.extras.append(fishes.titan_glow)


def kraken_extras(fish):
    fish.extra_shapes.append(kraken_arms)


def leviathan_extras(fish):
    fish.extra_shapes.append(leviathan_horn)


def angler_extras(fish):
    fish.extra_shapes.append(lure_shape(stalk_ramp="abyss"))
    fish.extras.append(lure_detail())


def lantern_extras(fish):
    import fishes
    fish.extras.append(fishes.photophores(0.78, 0.1))


def band_back(ramp, v_max=0.34, shift=0):
    import fishes
    return fishes.band_back(ramp, v_max, shift)


def sardine_pattern(fish, f):
    band_back("neon", 0.34)(fish, f)


def golden_pattern(fish, f):
    band_back("volt", 0.36, 1)(fish, f)


def barracuda_pattern(fish, f):
    import fishes
    fishes.chain(fishes.band_back("sharkgrey", 0.34), fishes.bars("sharkgrey", 0.09, 0.4, 0.52, 0.1, 0.7, shift=-1))(fish, f)


def puffer_pattern(fish, f):
    spots(fish, f, "brown", cell=0.16, rad=(0.03, 0.05), zone=f["v"] < 0.55, seed=5, shift=-1)


def moray_pattern(fish, f):
    spots(fish, f, "volt", cell=0.06, rad=(0.01, 0.015), seed=17, zone=f["v"] < 0.7, density=0.6, shift=0)


def orca_pattern(fish, f):
    import fishes
    fishes.orca_pattern(fish, f)


# species with parts that are not mutations (built into the head)
SPECIES_EXTRAS = {"tubarao": shark_extras, "titanacon": titan_extras, "kraken": kraken_extras,
                  "leviata": leviathan_extras, "pescadora": angler_extras, "lanterna": lantern_extras}
BUILTIN_LURE = {"pescadora"}

SPECIES = {
    "dourado": dict(H=0.58, peak=0.56, q=1.0, front_e=0.45, body="gold", belly="cream", fin="flame",
                    tail="veil", tail_len=0.55, eye=0.1, eye_ramp="iris_gold",
                    dorsal=("round", 0.36, 0.72, 0.55), anal=("soft", 0.16, 0.34, 0.3), pectoral=(0.22, 0.13),
                    pelvic=0.2, mouth=dict(v=0.58, corner_t=0.77, corner_v=0.64, open=0.85)),
    "neon": dict(H=0.42, peak=0.6, q=1.1, front_e=0.55, body="neon", belly="white", fin="silver", fin_alpha=225,
                 tail="fork", tail_len=0.42, eye=0.11, eye_ramp="iris_cyan", dorsal=("tri", 0.42, 0.6, 0.55),
                 anal=("long", 0.16, 0.42, 0.28), pectoral=(0.2, 0.1), pelvic=0.16, pattern=neon_pattern,
                 belly_v=0.64, mouth=dict(v=0.55, corner_t=0.8, corner_v=0.6, open=0.8)),
    "garoupa": dict(H=0.56, peak=0.52, q=0.9, front_e=0.42, body="olive", belly="sandy", fin="brown",
                    tail="round", tail_len=0.36, eye=0.075, eye_ramp="iris_red", dorsal=("spiny", 0.3, 0.74, 0.4),
                    anal=("round", 0.14, 0.3, 0.3), pectoral=(0.24, 0.15), pelvic=0.22, pattern=garoupa_pattern,
                    mouth=dict(v=0.62, corner_t=0.72, corner_v=0.66, open=0.8, under=0.03, chin=0.2,
                               lips="sandy", teeth="peg", teeth_n=4, teeth_len=0.03)),
    # ---- unlocked by defeating bosses
    "tubarao": dict(H=0.34, peak=0.6, q=1.1, front_e=0.75, top_ratio=0.5, body="navy", belly="white", fin="navy",
                    tail="hetero", tail_len=0.4, eye=0.05, eye_ramp="iris_red", dorsal=("shark", 0.44, 0.62, 0.85),
                    anal=("tri", 0.2, 0.27, 0.3), pectoral=(0.26, 0.1), pelvic=0.1, belly_v=0.58, gill=False,
                    backshade=0.2, mouth=dict(v=0.9, corner_t=0.76, corner_v=0.8, sag=0.05, open=0.8,
                                              teeth="triangle", teeth_n=5, teeth_len=0.045, tongue=False)),
    "kraken": dict(H=0.34, peak=0.72, q=0.55, front_e=0.35, top_ratio=0.5, ped=0.16, body="kraken", belly="coral",
                   fin="kraken", tail="lunate", tail_len=0.3, eye=0.12, eye_ramp="iris_gold", eye_t=0.8, eye_v=0.4,
                   dorsal=None, anal=None, pectoral=None, pelvic=0.0, gill=False, pattern=kraken_pattern,
                   belly_v=0.7, mouth=dict(v=0.66, corner_t=0.88, corner_v=0.66, open=0.8, teeth="peg", teeth_n=2,
                                          teeth_len=0.05, tongue=False)),
    "pescadora": dict(H=0.7, peak=0.62, q=0.8, front_e=0.36, body="abyss", belly="ink", fin="violet", tail="round",
                      tail_len=0.3, eye=0.07, eye_ramp="volt", dorsal=("low", 0.3, 0.52, 0.3),
                      anal=("round", 0.14, 0.3, 0.25), pectoral=(0.2, 0.13), pelvic=0.0, gloss=False,
                      pattern=lambda fish, f: spots(fish, f, "violet", cell=0.12, rad=(0.02, 0.035), seed=13),
                      mouth=dict(v=0.36, corner_t=0.64, corner_v=0.58, sag=0.06, open=0.9, under=0.06, chin=0.3,
                                 teeth="needle", teeth_n=4, teeth_len=0.1, closed_teeth=True)),
    "leviata": dict(H=0.3, peak=0.6, q=0.7, front_e=0.7, top_ratio=0.5, ped=0.45, body="navy", belly="cyan",
                    fin="cyan", tail="point", tail_len=0.42, eye=0.06, eye_ramp="volt",
                    dorsal=("spiny", 0.12, 0.7, 0.5), anal=("low", 0.1, 0.45, 0.35), pectoral=(0.18, 0.1),
                    pelvic=0.0, gill=False, belly_v=0.66, wag=1.6, pattern=leviathan_pattern,
                    mouth=dict(v=0.6, corner_t=0.8, corner_v=0.64, open=0.85, teeth="fang", teeth_n=3,
                               teeth_len=0.05)),
    "titanacon": dict(H=0.42, peak=0.62, q=0.8, front_e=0.5, top_ratio=0.52, ped=0.2, hump=0.1, hump_t=0.72,
                      body="titan", belly="titanbelly", fin="titan", tail="lunate", tail_len=0.34, eye=0.05,
                      eye_ramp="iris_red", eye_t=0.86, eye_v=0.3, dorsal=("spiny", 0.4, 0.62, 0.5),
                      anal=("tri", 0.2, 0.28, 0.3), pectoral=(0.2, 0.1), pelvic=0.08, gill=False, backshade=0.2,
                      belly_v=0.64, pattern=titan_pattern,
                      mouth=dict(v=0.62, corner_t=0.66, corner_v=0.64, sag=0.04, open=1.0, teeth="triangle",
                                 teeth_n=4, teeth_len=0.05, tongue=True)),
    # ---- fish mobs (Marés Profundas)
    "sardinha": dict(H=0.36, peak=0.62, q=1.15, front_e=0.68, body="silver", belly="white", fin="silver",
                     tail="fork", tail_len=0.44, eye=0.13, eye_ramp="iris_white", dorsal=("tri", 0.42, 0.58, 0.5),
                     anal=("tri", 0.2, 0.3, 0.25), pelvic=0.1, pectoral=(0.18, 0.08), pattern=sardine_pattern,
                     mouth=dict(v=0.52, corner_t=0.84, corner_v=0.56, open=0.7)),
    "lanterna": dict(H=0.44, peak=0.62, q=1.0, front_e=0.55, body="abyss", belly="ink", fin="abyss",
                     tail="fork", tail_len=0.42, eye=0.16, eye_ramp="glow", dorsal=("tri", 0.4, 0.58, 0.45),
                     anal=("soft", 0.18, 0.32, 0.25), pelvic=0.0, pectoral=(0.16, 0.08), gloss=False, countershade=0.1,
                     mouth=dict(v=0.55, corner_t=0.8, corner_v=0.6, open=0.8, teeth="needle", teeth_n=3, teeth_len=0.05)),
    "piranha": dict(H=0.66, peak=0.58, q=0.9, front_e=0.5, body="steel", belly="red", fin="steel",
                    tail="fork", tail_len=0.36, eye=0.1, eye_ramp="iris_red", dorsal=("tri", 0.44, 0.62, 0.4),
                    anal=("soft", 0.18, 0.34, 0.3), pectoral=(0.18, 0.09), pelvic=0.0, belly_v=0.56,
                    mouth=dict(v=0.64, corner_t=0.76, corner_v=0.66, open=0.95, under=0.07, chin=0.28,
                               teeth="triangle", teeth_n=3, teeth_len=0.09, closed_teeth=True, jaw_ramp="red")),
    "barracuda": dict(H=0.24, peak=0.6, q=1.0, front_e=0.95, body="silver", belly="white", fin="sharkgrey",
                      tail="fork", tail_len=0.28, eye=0.07, eye_ramp="iris_white", dorsal=("tri", 0.2, 0.3, 0.9),
                      dorsal2=("tri", 0.52, 0.62, 0.7), anal=("tri", 0.16, 0.26, 0.6), pectoral=(0.12, 0.06),
                      pelvic=0.0, gill_t=0.74, belly_v=0.58, backshade=0.15, pattern=barracuda_pattern,
                      mouth=dict(v=0.5, corner_t=0.78, corner_v=0.56, open=0.7, under=0.06, chin=0.24,
                                 teeth="fang", teeth_n=5, teeth_len=0.05, closed_teeth=True)),
    "baiacu": dict(H=0.78, peak=0.5, q=0.7, front_e=0.45, body="sandy", belly="cream", fin="orange",
                   tail="round", tail_len=0.3, eye=0.14, eye_ramp="iris_green", dorsal=("round", 0.3, 0.44, 0.22),
                   anal=("round", 0.2, 0.32, 0.18), pectoral=(0.2, 0.14), pelvic=0.0, pattern=puffer_pattern,
                   mouth=dict(v=0.62, corner_t=0.9, corner_v=0.62, open=0.75, teeth="peg", teeth_n=2,
                              teeth_len=0.06, closed_teeth=True, tongue=False)),
    "moreia": dict(H=0.22, peak=0.72, q=0.55, front_e=0.62, ped=0.55, top_ratio=0.5, body="eel",
                   belly="lime", fin="eel", tail="point", tail_len=0.24, eye=0.05, eye_ramp="volt", eye_t=0.9,
                   dorsal=("long", 0.06, 0.8, 0.42), anal=("long", 0.04, 0.48, 0.35), pectoral=None, pelvic=0.0,
                   belly_v=0.7, wag=2.4, gill=False, pattern=moray_pattern, countershade=0.15,
                   mouth=dict(v=0.55, corner_t=0.82, corner_v=0.6, open=0.9, teeth="fang", teeth_n=4,
                              teeth_len=0.045, tongue=False)),
    "dourado_raro": dict(H=0.4, peak=0.6, q=1.1, front_e=0.7, body="gold", belly="cream", fin="volt",
                         tail="veil", tail_len=0.5, eye=0.12, eye_ramp="iris_white", dorsal=("tri", 0.42, 0.62, 0.6),
                         anal=("soft", 0.18, 0.3, 0.3), pelvic=0.12, pectoral=(0.2, 0.1), pattern=golden_pattern,
                         mouth=dict(v=0.52, corner_t=0.84, corner_v=0.56, open=0.7)),
    "orca": dict(H=0.36, peak=0.56, q=1.0, front_e=0.62, body="orca", belly="white", fin="orca", tail="fluke",
                 tail_len=0.28, eye=0.035, eye_ramp="iris_dark", dorsal=("orca", 0.45, 0.6, 0.95), anal=None,
                 pectoral=(0.2, 0.1), pelvic=0.0, belly_v=0.62, gill=False, pattern=orca_pattern, eye_t=0.87,
                 eye_v=0.46, wag=0.6, mouth=dict(v=0.64, corner_t=0.84, corner_v=0.62, sag=0.03, open=0.6,
                                                   teeth="cone", teeth_n=5, teeth_len=0.03)),
}


# --------------------------------------------------------------- mutations
def piranha_mouth(m):
    m = dict(m)
    m.update(corner_t=min(m.get("corner_t", 0.8), 0.73), corner_v=0.66, open=1.0, under=0.07, chin=0.26,
             teeth="triangle", teeth_n=5, teeth_len=0.06, closed_teeth=True, jaw_ramp="red", lips=None)
    return m


def skin_armor(fish, f):
    t, v = f["t"], f["v"]
    lay = f["lay"]
    zone = f["body"] & (t > 0.1) & (t < 0.78) & (v < 0.64)
    seg = max(3.0, fish.L * 0.12)
    k = (f["sx"] - fish.xt) / seg
    row2 = v >= 0.32
    kk = np.where(row2, (k + 0.5) % 1.0, k % 1.0) * seg
    recolor(f, zone, "steel", shift=0, lo=2)
    lay.shift(zone & (kk >= 1.0) & (kk < 2.0), +1, hi=5)
    lay.shift(zone & (kk > seg - 1.5), -1, lo=2)
    hgt = fish.bottom(t) - fish.top(t)
    seam = zone & ((kk < 1.0) | (np.abs(v - 0.32) * hgt < 0.55) | (np.abs(v - 0.64) * hgt < 0.55))
    lay.paint(seam, "steel", 1)
    f["armor_zone"] = zone


def skin_armor_detail(fish, st, f, lay):
    if fish.L < 26:
        return
    seg = max(3.0, fish.L * 0.12)
    X, Y = f["x"], f["y"]
    for i in range(12):
        tx = 0.1 + (i + 0.5) * seg / fish.L
        if tx > 0.74:
            break
        ry = float(fish.section_y(tx, 0.14))
        rx = fish.xt + tx * fish.L
        lay.paint((np.abs(X - rx) < 0.5) & (np.abs(Y - ry) < 0.5) & f["up"], "steel", 6)


def skin_toxic(fish, f):
    zone = (f["t"] > 0.08) & (f["v"] < 0.9)
    spots(fish, f, "poison", cell=0.12, rad=(0.028, 0.045), zone=zone, seed=21, density=0.8)
    spots(fish, f, "lime", cell=0.16, rad=(0.018, 0.03), zone=zone & (f["v"] < 0.7), seed=33, density=0.55, shift=1)


def skin_toxic_detail(fish, st, f, lay):
    # glossy tops on the warts
    lime = next((i for i, r in enumerate(lay.ramps) if r is FP.PAL["lime"]), -1)
    if lime < 0:
        return
    m = lay.mat == lime
    above = np.pad(m, ((1, 0), (0, 0)))[:-1, :]
    top_px = m & ~above
    lay.paint(top_px & (np.roll(top_px, 1, axis=1)), "lime", 6)


def skin_glow_detail(fish, st, f, lay):
    t, v = f["t"], f["v"]
    body = f["body"]
    hgt = fish.bottom(t) - fish.top(t)
    line = body & (np.abs(v - 0.5) * hgt < 0.55) & (t > 0.08) & (t < 0.7)
    lay.paint(line, "glow", 5)
    step = max(3.0, fish.L / 7.0)
    xi = (f["sx"] - fish.xt)
    dots = body & (np.abs(v - 0.74) * hgt < 0.6) & ((xi % step) < 1.0) & (t > 0.12) & (t < 0.72)
    lay.paint(dots, "glow", 6)
    dots2 = body & (np.abs(v - 0.22) * hgt < 0.6) & (((xi + step / 2) % step) < 1.0) & (t > 0.2) & (t < 0.66)
    lay.paint(dots2, "glow", 5)


def canvas_size(L):
    w = int(L * 2.0) + 6
    h = int(L * 1.25) + 6
    return w + (w % 2), h + (h % 2)


def _grow_fin(fin, k):
    if not fin or not isinstance(fin, tuple) or len(fin) < 4:
        return fin
    return fin[:3] + (fin[3] * k,) + fin[4:]


def stage_features(spec, stage):
    """Growth changes the look, not only the size: taller fins (adult),
    longer tail (veteran), battle scars (veteran) and bioluminescent marks
    along the flank (leviathan stage)."""
    if stage >= 2:
        spec["dorsal"] = _grow_fin(spec.get("dorsal"), 1.15)
        spec["anal"] = _grow_fin(spec.get("anal"), 1.1)
    if stage >= 3:
        spec["tail_len"] = spec.get("tail_len", 0.4) * 1.1
    return spec


def stage_extras(fish, stage):
    import fishes
    if stage >= 3:
        fish.extras.append(fishes.scars)
    if stage >= 4:
        fish.extras.append(fishes.photophores(0.62, 0.09, 0.2, 0.7, "glow"))


def make_fish(species, L, w, h, head="", skin="", stage=0):
    spec = stage_features(dict(SPECIES[species]), stage)
    pat = spec.pop("pattern", None)
    if head == "head_piranha":
        spec["mouth"] = piranha_mouth(spec["mouth"])
    patterns = [pat] if pat else []
    if skin == "skin_armor":
        patterns.append(skin_armor)
    elif skin == "skin_toxic":
        patterns.append(skin_toxic)

    def pattern(fish, f):
        for fn in patterns:
            fn(fish, f)
    spec["pattern"] = pattern if patterns else None
    fish = Fish(L, w * 0.5 + L * 0.12, h * 0.52, **spec)
    if species in SPECIES_EXTRAS:
        SPECIES_EXTRAS[species](fish)
    stage_extras(fish, stage)
    if head == "head_sword":
        fish.extra_shapes.append(bill_shape(length=0.36))
    elif head == "head_lure" and species not in BUILTIN_LURE:
        fish.extra_shapes.append(lure_shape(stalk_ramp=spec["body"]))
        fish.extras.append(lure_detail())
    if skin == "skin_armor":
        fish.extras.append(skin_armor_detail)
    elif skin == "skin_toxic":
        fish.extras.append(skin_toxic_detail)
    elif skin == "skin_glow":
        fish.extras.append(skin_glow_detail)
    return fish


# ------------------------------------------------------------ fin mutations
def fins_spiky_back(fish, w, h, x, y, st, f):
    lay = Layer(w, h)
    pts = fish.fin_pts(("spiny", 0.28, 0.8, 0.62), "top", st)
    fish.paint_fin(lay, x, y, pts, "coral", 3, rays=False)
    # bone spines along the spiky edge
    n = len(pts) // 2
    outer = pts[n:][::-1]
    for i in range(0, n, 4):
        (ax, ay), (bx, by) = pts[i], outer[i]
        d = seg_dist(x, y, ax, ay, bx, by)
        lay.paint((d < 0.55) & poly_mask(x, y, pts), "bone", 5)
    pts2 = fish.fin_pts(("spiny", 0.14, 0.34, 0.36), "bottom", st)
    fish.paint_fin(lay, x, y, pts2, "coral", 3, rays=False)
    lay.clean(1)
    return lay


def fins_spiky_front(fish, w, h, x, y, st, f):
    lay = Layer(w, h)
    bx, by = fish.pectoral_root()
    ang = math.pi * 0.86 + 0.28 * math.sin(st["phase"] + 1.0) + st["pect"] * 0.5
    ln = (fish.p["pectoral"] or (0.22, 0.12))[0] * fish.L * 1.1
    poly = fish.fan_poly(bx, by, ang, ln, (fish.p["pectoral"] or (0.22, 0.12))[1] * fish.L)
    fish.paint_fin(lay, x, y, poly, "coral", 4, root=(bx, by))
    tx, ty = bx + math.cos(ang) * ln * 1.25, by + math.sin(ang) * ln * 1.25
    d = seg_dist(x, y, bx + math.cos(ang) * ln * 0.3, by + math.sin(ang) * ln * 0.3, tx, ty)
    lay.paint(d < max(0.55, fish.L * 0.014), "bone", 5)
    lay.clean(1)
    fish._contact_shadow(lay, f)
    return lay


def fins_wing_back(fish, w, h, x, y, st, f):
    lay = Layer(w, h)
    fish.paint_fin(lay, x, y, fish.fin_pts(("soft", 0.42, 0.66, 0.35), "top", st), fish.p["fin"], 3)
    bx, by = fish.pectoral_root(0.64, 0.5)
    ang = math.pi * 1.1 - 0.35 * math.sin(st["phase"] + 0.4)
    poly = fish.fan_poly(bx, by, ang, fish.L * 0.55, fish.L * 0.22)
    fish.paint_fin(lay, x, y, poly, "neon", 3, root=(bx, by))
    lay.clean(1)
    return lay


def fins_wing_front(fish, w, h, x, y, st, f):
    lay = Layer(w, h)
    bx, by = fish.pectoral_root(0.66, 0.56)
    ang = math.pi * 1.02 + 0.42 * math.sin(st["phase"] + 1.0) + st["pect"] * 0.4
    poly = fish.fan_poly(bx, by, ang, fish.L * 0.6, fish.L * 0.24)
    fish.paint_fin(lay, x, y, poly, "cyan", 4, root=(bx, by), alpha=235)
    lay.clean(1)
    fish._contact_shadow(lay, f)
    return lay


def fins_volt_back(fish, w, h, x, y, st, f):
    lay = Layer(w, h)
    fish.paint_fin(lay, x, y, fish.fin_pts(("zig", 0.28, 0.74, 0.5), "top", st), "volt", 3)
    fish.paint_fin(lay, x, y, fish.fin_pts(("zig", 0.16, 0.44, 0.34), "bottom", st), "volt", 3)
    lay.clean(1)
    return lay


def fins_volt_front(fish, w, h, x, y, st, f):
    lay = Layer(w, h)
    bx, by = fish.pectoral_root()
    ang = math.pi * 0.86 + 0.28 * math.sin(st["phase"] + 1.0) + st["pect"] * 0.5
    poly = fish.fan_poly(bx, by, ang, (fish.p["pectoral"] or (0.22, 0.12))[0] * fish.L * 1.1, (fish.p["pectoral"] or (0.22, 0.12))[1] * fish.L)
    fish.paint_fin(lay, x, y, poly, "cyan", 4, root=(bx, by))
    lay.clean(1)
    fish._contact_shadow(lay, f)
    # sparks: small bright crosses that hop around every frame (emissive, no outline)
    rng = np.random.default_rng(int(st["phase"] * 1000) + int(fish.L))
    X, Y = f["X"], f["Y"]
    for _ in range(max(2, int(fish.L / 11))):
        t = rng.uniform(0.25, 0.75)
        sx = fish.xt + t * fish.L
        sy = float(fish.top(t)) - rng.uniform(1.0, fish.H * 0.55)
        px, py = fish.to_screen(sx, sy, st)
        px, py = math.floor(px), math.floor(py)
        c = (np.floor(X) == px) & (np.floor(Y) == py)
        arm = ((np.abs(np.floor(X) - px) == 1) & (np.floor(Y) == py)) | ((np.abs(np.floor(Y) - py) == 1) & (np.floor(X) == px))
        lay.paint(arm & ~lay.mask, "volt", 5, outline=False)
        lay.paint(c, "volt", 6, outline=False)
    return lay


FIN_PAINTERS = {
    "fins_spiky_back": fins_spiky_back, "fins_spiky_front": fins_spiky_front,
    "fins_wing_back": fins_wing_back, "fins_wing_front": fins_wing_front,
    "fins_volt_back": fins_volt_back, "fins_volt_front": fins_volt_front,
}


# ----------------------------------------------------------- tail mutations
def tail_fork(fish, w, h, x, y, st, f):
    ramp = "violet" if fish.p["body"] == "neon" else "navy"
    return fish.render_tail(w, h, x, y, st, f, kind="fork", ramp=ramp, tail_len=0.62)


def _whip_points(fish, st, length, n=14, amp=0.05):
    x0 = fish.xt + 1.5
    pts = []
    for i in range(n + 1):
        t = i / n
        pts.append((x0 - t * length * fish.L, fish.cy + math.sin(t * 2.4 - st["phase"]) * fish.L * amp * t))
    return pts


def tail_sting(fish, w, h, x, y, st, f):
    lay = Layer(w, h)
    L = fish.L
    pts = _whip_points(fish, st, 0.78)
    width = max(1.2, fish.H * fish.p["ped"] * 1.5)
    n = len(pts) - 1
    whip = np.zeros(x.shape, dtype=bool)
    tone = np.zeros(x.shape, dtype=np.int32)
    for i in range(n):
        (ax, ay), (bx, by) = pts[i], pts[i + 1]
        wd = width * (1.0 - i / n * 0.72) * 0.5
        d = seg_dist(x, y, ax, ay, bx, by)
        seg = d <= wd
        whip |= seg
        tone = np.where(seg, np.where(y < (ay + by) / 2 - wd * 0.3, 4, 3), tone)
    lay.paint(whip, "poison", tone)
    # spots along the whip
    lay.shift(whip & (((np.floor(x) + np.floor(y)) % 4) == 0), -1, lo=2)
    tx, ty = pts[-1]
    (ax, ay) = pts[-2]
    dx, dy = tx - ax, ty - ay
    dl = max(1e-6, math.hypot(dx, dy))
    dx, dy = dx / dl, dy / dl
    bw = max(1.6, L * 0.075)
    barb = [(tx - dy * bw * 0.8, ty + dx * bw * 0.8), (tx + dx * bw * 1.8, ty + dy * bw * 1.8), (tx + dy * bw * 0.8, ty - dx * bw * 0.8)]
    bm = poly_mask(x, y, barb)
    lay.paint(bm, "lime", np.where(y < ty, 5, 4))
    # small fins at the base
    x0 = fish.xt + 1.5
    for sgn in (-1, 1):
        fin = [(x0, fish.cy + sgn * fish.H * 0.08), (x0 - L * 0.2, fish.cy + sgn * fish.H * 0.42),
               (x0 - L * 0.12, fish.cy + sgn * fish.H * 0.05)]
        fish.paint_fin(lay, x, y, fin, "poison", 3 if sgn < 0 else 2, rays=False)
    lay.clean(1)
    return lay


def tail_eel(fish, w, h, x, y, st, f):
    lay = Layer(w, h)
    L = fish.L
    x0 = fish.xt + 2
    ln = L * 0.72
    base_h = fish.H * fish.p["ped"] * 1.1
    u = (x0 - x) / ln
    inside_u = (u >= 0) & (u <= 1)
    wave = np.sin(u * 5.0 - st["phase"]) * L * 0.035 * u
    yc = fish.cy + wave
    h_top = base_h * (1.0 - u * 0.8)
    h_bot = base_h * (1.0 - u * 0.8)
    rib = L * 0.13 * np.sin(np.clip(u, 0, 1) * math.pi) * (1 - u * 0.3)
    body = inside_u & (y >= yc - h_top) & (y <= yc + h_bot)
    ribbon = inside_u & ~body & (((y > yc + h_bot) & (y <= yc + h_bot + rib)) | ((y < yc - h_top) & (y >= yc - h_top - rib * 0.55)))
    lay.paint(body, fish.p["body"], np.where(y < yc, 4, 3))
    stripe = (np.floor((x0 - x) / max(2.0, L * 0.07)) % 2) == 0
    lay.paint(ribbon, "volt", np.where(stripe, 5, 3))
    lay.clean(1)
    return lay


TAIL_PAINTERS = {"tail_fork": tail_fork, "tail_sting": tail_sting, "tail_eel": tail_eel}


# ------------------------------------------------------------------ atlas
def render_atlas(species, stage, progress=None):
    L = STAGE_LEN[stage]
    w, h = canvas_size(L)
    rows = {name: [] for name in LAYERS}
    lure = []
    for i in range(FP.N_FRAMES):
        st = FP.frame_state(i)
        base = make_fish(species, L, w, h, stage=stage)
        X, Y = FP.grid(w, h)
        x, y = base.to_fish(X, Y, st)
        f = base._body_fields(x, y, st)
        f["X"], f["Y"] = X, Y
        rows["tail"].append(base.render_tail(w, h, x, y, st, f).to_image())
        rows["fins_back"].append(base.render_fins_back(w, h, x, y, st, f).to_image())
        rows["fins_front"].append(base.render_fins_front(w, h, x, y, st, f).to_image())
        for name, fn in TAIL_PAINTERS.items():
            rows[name].append(fn(base, w, h, x, y, st, f).to_image())
        for name, fn in FIN_PAINTERS.items():
            rows[name].append(fn(base, w, h, x, y, st, f).to_image())
        for head in HEADS:
            for skin in SKINS:
                fish = make_fish(species, L, w, h, head, skin, stage)
                lay = fish.render(w, h, st, parts=("body",))["body"]
                rows[body_key(head, skin)].append(lay.to_image())
                if head == "head_lure" and skin == "":
                    lx, ly = lure_screen(fish, st)
                    lure.append([round(lx, 1), round(ly, 1)])
    sheet = Image.new("RGBA", (w * FP.N_FRAMES, h * len(LAYERS)))
    for r, name in enumerate(LAYERS):
        for c, im in enumerate(rows[name]):
            sheet.alpha_composite(im, (c * w, r * h))
    base = make_fish(species, L, w, h, stage=stage)
    meta = dict(
        frame_w=w, frame_h=h, frames=FP.N_FRAMES, swim=FP.SWIM_N, act=FP.BITE_N, layers=LAYERS,
        center=[round(base.cx, 1), round(base.cy, 1)],
        mouth=[round(base.lip[0], 1), round(base.lip[1], 1)],
        lure=lure, lure_builtin=species in BUILTIN_LURE, length=L, height=round(base.H, 1),
    )
    return sheet, meta


def compose_frame(sheet, meta, layers, frame):
    """Composite a set of rows for one frame (app icon, previews)."""
    w, h = meta["frame_w"], meta["frame_h"]
    out = Image.new("RGBA", (w, h))
    for name in layers:
        r = meta["layers"].index(name)
        out.alpha_composite(sheet.crop((frame * w, r * h, frame * w + w, r * h + h)))
    return out
