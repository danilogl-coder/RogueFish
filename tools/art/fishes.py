"""Enemy / ecosystem fish and fish-like bosses, rendered with fishpro.

Every sheet has 10 frames: 6 swim + 4 bite (anticipation, gape, snap, recover).
Each species has its own jaw: the lower jaw rotates around the corner of the
mouth, so teeth, tongue and gums belong to the head instead of being painted
over it.
"""
from __future__ import annotations

import math

import numpy as np
from PIL import Image

import fishpro as FP
from fishpro import Fish, Layer, recolor, lure_shape, lure_detail
from pro import poly_mask, seg_dist
from player import spots

N = FP.N_FRAMES


def sheet(L, extra_shapes=(), extras=(), parts=("tail", "fins_back", "body", "fins_front"), rows=1, **kw):
    """Auto-sized sheet centred on the body (see fishpro.auto_sheet)."""
    def make(cx, cy):
        f = Fish(L, cx, cy, **kw)
        f.extra_shapes.extend(extra_shapes)
        f.extras.extend(extras)
        return f
    return FP.auto_sheet(make, L, parts=parts, rows=rows)


# ------------------------------------------------------------------ patterns
def band_back(ramp, v_max=0.3, shift=0):
    def f(fish, fl):
        recolor(fl, fl["body"] & (fl["v"] < v_max), ramp, shift=shift)
    return f


def bars(ramp, every=0.16, width=0.35, v_max=0.62, t0=0.12, t1=0.8, shift=0):
    def f(fish, fl):
        t = fl["t"]
        k = ((t - t0) / every) % 1.0
        on = fl["body"] & (k < width) & (t > t0) & (t < t1) & (fl["v"] < v_max)
        recolor(fl, on, ramp, shift=shift)
    return f


def chain(*fns):
    def f(fish, fl):
        for fn in fns:
            fn(fish, fl)
    return f


def gill_slits(n=4, t0=0.66, dt=0.028, v0=0.34, v1=0.74):
    def fn(fish, st, f, lay):
        if fish.L < 24:
            return
        for k in range(n):
            xo = fish.xt + fish.L * (t0 + k * dt) - 0.03 * fish.L * np.sin(np.clip(f["v"], 0, 1) * math.pi)
            on = f["up"] & (np.abs(f["x"] - xo) < 0.5) & (f["v"] > v0 + k * 0.01) & (f["v"] < v1 - k * 0.02)
            lay.shift(on, -2, lo=1)
    return fn


def photophores(v=0.8, step=0.08, t0=0.12, t1=0.82, ramp="glow"):
    def fn(fish, st, f, lay):
        s = max(2.0, step * fish.L)
        on = f["body"] & (np.abs(f["v"] - v) * (fish.bottom(f["t"]) - fish.top(f["t"])) < 0.6)
        on &= ((f["sx"] - fish.xt) % s) < 1.0
        on &= (f["t"] > t0) & (f["t"] < t1)
        lay.paint(on, ramp, 6)
    return fn


# ----------------------------------------------------------------- small fish
def sardine():
    return sheet(12, H=0.34, peak=0.62, q=1.2, front_e=0.7, body="silver", belly="white", fin="silver",
                 tail="fork", tail_len=0.42, eye=0.12, eye_ramp="iris_white", dorsal=("tri", 0.42, 0.58, 0.5),
                 anal=None, pelvic=0.0, pectoral=(0.18, 0.08), pattern=band_back("neon", 0.34),
                 mouth=dict(v=0.52, corner_t=0.86, corner_v=0.56, open=0.6))


def golden():
    return sheet(13, H=0.36, peak=0.6, q=1.1, front_e=0.7, body="gold", belly="cream", fin="volt",
                 tail="fork", tail_len=0.45, eye=0.12, eye_ramp="iris_white", dorsal=("tri", 0.42, 0.6, 0.55),
                 anal=None, pelvic=0.0, pectoral=(0.18, 0.08), pattern=band_back("volt", 0.36, 1),
                 mouth=dict(v=0.52, corner_t=0.86, corner_v=0.56, open=0.6))


def pilot():
    return sheet(9, H=0.42, peak=0.6, q=1.0, front_e=0.6, body="white", belly="white", fin="neon",
                 tail="fork", tail_len=0.45, eye=0.13, eye_ramp="iris_dark", dorsal=("tri", 0.42, 0.6, 0.4),
                 anal=None, pelvic=0.0, pectoral=None, pattern=bars("navy", 0.22, 0.45, 0.95, 0.08, 0.8),
                 mouth=dict(v=0.52, corner_t=0.86, corner_v=0.56, open=0.6))


def lanternfish():
    return sheet(12, H=0.42, peak=0.62, q=1.0, front_e=0.55, body="abyss", belly="ink", fin="abyss",
                 tail="fork", tail_len=0.42, eye=0.15, eye_ramp="glow", dorsal=("tri", 0.4, 0.58, 0.45),
                 anal=None, pelvic=0.0, pectoral=(0.16, 0.08), gloss=False, countershade=0.1,
                 extras=(photophores(0.78, 0.12),),
                 mouth=dict(v=0.55, corner_t=0.82, corner_v=0.6, open=0.7))


def piranha():
    return sheet(15, H=0.66, peak=0.58, q=0.9, front_e=0.5, body="steel", belly="red", fin="steel",
                 tail="fork", tail_len=0.36, eye=0.1, eye_ramp="iris_red", dorsal=("tri", 0.44, 0.62, 0.4),
                 anal=("soft", 0.18, 0.34, 0.3), pectoral=(0.18, 0.09), pelvic=0.0, belly_v=0.56,
                 mouth=dict(v=0.64, corner_t=0.76, corner_v=0.66, open=0.95, under=0.07, chin=0.28,
                            teeth="triangle", teeth_n=3, teeth_len=0.09, closed_teeth=True, jaw_ramp="red"))


def puffer():
    def pattern(fish, fl):
        spots(fish, fl, "brown", cell=0.16, rad=(0.03, 0.05), zone=fl["v"] < 0.55, seed=5, shift=-1)
    return sheet(15, H=0.8, peak=0.5, q=0.7, front_e=0.45, body="sandy", belly="cream", fin="orange",
                 tail="round", tail_len=0.3, eye=0.13, eye_ramp="iris_green", dorsal=("round", 0.3, 0.44, 0.22),
                 anal=("round", 0.2, 0.32, 0.18), pectoral=(0.2, 0.14), pelvic=0.0, pattern=pattern,
                 mouth=dict(v=0.62, corner_t=0.9, corner_v=0.62, open=0.7, teeth="peg", teeth_n=2,
                            teeth_len=0.06, closed_teeth=True, tongue=False))


def puffer_big():
    """Inflated puffer: shaded sphere with spines, 4 pulse frames."""
    frames = []
    S = 38
    for i in range(4):
        w = h = S
        lay = Layer(w, h)
        X, Y = FP.grid(w, h)
        cx, cy = S / 2 + 1.5, S / 2
        r = 10.5 + (0.5 if i % 2 else 0.0)
        # spines behind the body, pointing outward
        for k in range(16):
            a = k / 16 * math.tau + i * 0.08
            x0, y0 = cx + math.cos(a) * r * 0.8, cy + math.sin(a) * r * 0.8
            x1, y1 = cx + math.cos(a) * (r + 4.0), cy + math.sin(a) * (r + 4.0)
            d = seg_dist(X, Y, x0, y0, x1, y1)
            lay.paint(d <= 0.62, "bone", 5 if math.sin(a) < 0 else 4)
        d = np.hypot(X - cx, Y - cy)
        ball = d <= r
        nz = np.sqrt(np.clip(1 - (d / r) ** 2, 0, 1))
        n = np.stack([(X - cx) / r, (Y - cy) / r, nz], axis=-1)
        li = np.clip(n @ FP.pro.LIGHT, 0, 1) * 0.85 + 0.15
        tone = FP.band(li + 0.3 * np.clip((Y - cy) / r, 0, 1))
        lay.paint(ball, "sandy", tone)
        belly = ball & (Y > cy + r * 0.25)
        lay.paint(belly, "cream", tone)
        # spots on the upper half
        for k in range(10):
            a = k * 2.39
            sx, sy = cx - 2 + math.cos(a) * 6, cy - 4 + math.sin(a) * 3.2
            lay.shift((np.hypot(X - sx, Y - sy) <= 1.0) & ball & ~belly, -2, lo=1)
        # tail fan
        tail = poly_mask(X, Y, [(cx - r + 1, cy - 2), (cx - r - 4.5, cy - 5 + i % 2), (cx - r - 4.5, cy + 5 - i % 2), (cx - r + 1, cy + 2)])
        lay.paint(tail & ~ball, "orange", 4)
        lay.clean(1)
        # eye + frown + small open "o" mouth (part of the face, shaded)
        ex, ey = cx + 5.5, cy - 2.5
        de = np.hypot(X - ex, Y - ey)
        lay.paint(de <= 2.6, "iris_green", np.where(Y < ey, 3, 5))
        lay.paint(np.hypot(X - (ex + 0.6), Y - ey) <= 1.3, "black", 0)
        lay.paint((np.floor(X) == math.floor(ex - 1)) & (np.floor(Y) == math.floor(ey - 1)), "white", 6)
        brow = seg_dist(X, Y, ex - 3.2, ey - 3.6, ex + 2.2, ey - 2.4) <= 0.6
        lay.shift(brow & ball, -2, lo=1)
        mo = np.hypot((X - (cx + 9.2)) / 1.4, (Y - (cy + 3)) / 1.2) <= 1.0
        lay.paint(mo & ball, "mouth", 1)
        lay.paint(mo & ball & (Y > cy + 3.4), "gum", 3)
        frames.append(lay.to_image())
    out = Image.new("RGBA", (S * 4, S))
    for k, im in enumerate(frames):
        out.alpha_composite(im, (k * S, 0))
    return out


# --------------------------------------------------------------- predators
def barracuda():
    return sheet(34, H=0.22, peak=0.6, q=1.0, front_e=0.95, body="silver", belly="white", fin="sharkgrey",
                 tail="fork", tail_len=0.26, eye=0.06, eye_ramp="iris_white", dorsal=("tri", 0.2, 0.3, 0.9),
                 dorsal2=("tri", 0.52, 0.62, 0.7), anal=("tri", 0.16, 0.26, 0.6), pectoral=(0.12, 0.06),
                 pelvic=0.0, gill_t=0.74, belly_v=0.58, backshade=0.15,
                 pattern=chain(band_back("sharkgrey", 0.34), bars("sharkgrey", 0.09, 0.4, 0.52, 0.1, 0.7, shift=-1)),
                 mouth=dict(v=0.5, corner_t=0.78, corner_v=0.56, open=0.62, under=0.06, chin=0.24,
                            teeth="fang", teeth_n=6, teeth_len=0.04, closed_teeth=True))


def shark():
    return sheet(56, H=0.3, peak=0.6, q=1.1, front_e=0.78, top_ratio=0.5, body="sharkgrey", belly="white",
                 fin="sharkgrey", tail="hetero", tail_len=0.36, eye=0.03, eye_ramp="iris_dark",
                 dorsal=("shark", 0.46, 0.62, 0.8), anal=("tri", 0.2, 0.26, 0.3), pectoral=(0.26, 0.09),
                 pelvic=0.1, belly_v=0.58, gill=False, extras=(gill_slits(4, 0.66),), wag=0.8, backshade=0.28,
                 mouth=dict(v=0.92, corner_t=0.74, corner_v=0.8, sag=0.05, open=0.78, teeth="triangle",
                            teeth_n=7, teeth_len=0.04, tongue=False))


def angler():
    return sheet(28, H=0.72, peak=0.62, q=0.8, front_e=0.36, body="abyss", belly="ink", fin="abyss",
                 tail="round", tail_len=0.3, eye=0.065, eye_ramp="volt", dorsal=("low", 0.3, 0.52, 0.3),
                 anal=("round", 0.14, 0.3, 0.25), pectoral=(0.18, 0.12), pelvic=0.0, gloss=False,
                 pattern=lambda fish, fl: spots(fish, fl, "violet", cell=0.14, rad=(0.02, 0.035), seed=13, shift=0),
                 extra_shapes=(lure_shape(stalk_ramp="abyss"),), extras=(lure_detail(),),
                 mouth=dict(v=0.36, corner_t=0.64, corner_v=0.58, sag=0.06, open=0.85, under=0.06, chin=0.3,
                            teeth="needle", teeth_n=5, teeth_len=0.1, closed_teeth=True))


def orca_pattern(fish, fl):
    t, v = fl["t"], fl["v"]
    body = fl["body"]
    # white eye patch behind the eye and grey saddle behind the dorsal fin
    patch = body & (((t - 0.8) / 0.06) ** 2 + ((v - 0.4) / 0.11) ** 2 <= 1.0)
    recolor(fl, patch, "white", shift=1, lo=3)
    saddle = body & (((t - 0.46) / 0.12) ** 2 + ((v - 0.02) / 0.16) ** 2 <= 1.0)
    recolor(fl, saddle, "steel", shift=0)
    # white flank sweep reaching up behind the belly
    flank = body & (((t - 0.3) / 0.12) ** 2 + ((v - 0.66) / 0.2) ** 2 <= 1.0)
    recolor(fl, flank, "white", shift=1, lo=3)


def orca():
    return sheet(112, H=0.34, peak=0.56, q=1.0, front_e=0.62, body="orca", belly="white",
                 fin="orca", tail="fluke", tail_len=0.26, eye=0.022, eye_ramp="iris_dark",
                 dorsal=("orca", 0.45, 0.6, 0.95), anal=None, pectoral=(0.2, 0.1), pelvic=0.0,
                 belly_v=0.62, gill=False, pattern=orca_pattern, eye_t=0.87, eye_v=0.46, wag=0.6,
                 mouth=dict(v=0.64, corner_t=0.84, corner_v=0.62, sag=0.03, open=0.5, teeth="cone", teeth_n=7,
                            teeth_len=0.02))


def moray():
    def pattern(fish, fl):
        spots(fish, fl, "volt", cell=0.05, rad=(0.008, 0.012), seed=17, zone=fl["v"] < 0.7, density=0.6, shift=0)
    return sheet(50, H=0.2, peak=0.72, q=0.55, front_e=0.62, ped=0.55, top_ratio=0.5, body="eel",
                 belly="lime", fin="eel", tail="point", tail_len=0.22, eye=0.045, eye_ramp="volt", eye_t=0.9,
                 dorsal=("long", 0.06, 0.8, 0.42), anal=("long", 0.04, 0.48, 0.35), pectoral=None, pelvic=0.0,
                 belly_v=0.7, wag=2.6, gill=False, pattern=pattern, countershade=0.15,
                 mouth=dict(v=0.55, corner_t=0.82, corner_v=0.6, open=0.85, teeth="fang", teeth_n=4,
                            teeth_len=0.04, tongue=False))


# -------------------------------------------------------------------- bosses
def scars(fish, st, f, lay):
    for k in range(3):
        t0 = 0.44 + k * 0.05
        x0 = fish.xt + t0 * fish.L
        y0 = float(fish.section_y(t0, 0.28))
        d = seg_dist(f["x"], f["y"], x0, y0, x0 + fish.L * 0.045, y0 + fish.H * 0.3)
        lay.paint((d < 0.55) & f["up"], "pink", 3)
        lay.paint((d >= 0.55) & (d < 1.2) & f["up"] & (f["x"] > x0 + 0.5), "pink", 5)


def boss_shark():
    return sheet(108, H=0.32, peak=0.6, q=1.1, front_e=0.78, top_ratio=0.5, body="navy", belly="white",
                 fin="navy", tail="hetero", tail_len=0.36, eye=0.03, eye_ramp="iris_red",
                 dorsal=("shark", 0.44, 0.62, 0.85), anal=("tri", 0.2, 0.26, 0.3), pectoral=(0.26, 0.09),
                 pelvic=0.1, belly_v=0.58, gill=False, extras=(gill_slits(5, 0.64, 0.024), scars), wag=0.7, backshade=0.2,
                 mouth=dict(v=0.9, corner_t=0.78, corner_v=0.8, sag=0.05, open=0.66, teeth="triangle",
                            teeth_n=8, teeth_len=0.04, tongue=False))


def glow_lines(fish, st, f, lay):
    t, v = f["t"], f["v"]
    hgt = fish.bottom(t) - fish.top(t)
    line = f["body"] & (np.abs(v - 0.55) * hgt < 0.6) & (t > 0.12) & (t < 0.6)
    lay.paint(line, "glow", 5)
    s = max(3.0, fish.L / 9.0)
    dots = f["body"] & (np.abs(v - 0.78) * hgt < 0.7) & (((f["sx"] - fish.xt) % s) < 1.2) & (t > 0.14) & (t < 0.62)
    lay.paint(dots, "glow", 6)


def boss_angler():
    return sheet(80, H=0.78, peak=0.62, q=0.8, front_e=0.36, body="abyss", belly="ink",
                 fin="violet", tail="round", tail_len=0.3, eye=0.05, eye_ramp="volt", dorsal=("low", 0.28, 0.54, 0.3),
                 anal=("round", 0.14, 0.3, 0.25), pectoral=(0.2, 0.13), pelvic=0.0, gloss=False,
                 pattern=lambda fish, fl: spots(fish, fl, "violet", cell=0.1, rad=(0.014, 0.026), seed=19),
                 extra_shapes=(lure_shape(stalk_ramp="abyss"),), extras=(lure_detail(), glow_lines),
                 mouth=dict(v=0.34, corner_t=0.64, corner_v=0.58, sag=0.06, open=0.9, under=0.06, chin=0.3,
                            teeth="needle", teeth_n=7, teeth_len=0.1, closed_teeth=True))


def leviathan_head():
    """Serpent head: the neck runs off the left edge where the body segments attach."""
    def horn(fish, st, x, y):
        t0 = 0.72
        bx, by = fish.xt + t0 * fish.L, float(fish.top(t0)) + 1.5
        pts = [(bx - 2, by), (bx - 0.2 * fish.L, by - fish.H * 0.62), (bx - 0.12 * fish.L, by - fish.H * 0.5), (bx + 4, by + 0.5)]
        msk = poly_mask(x, y, pts)
        tone = np.where(y < by - fish.H * 0.3, 5, 4)
        return msk, "bone", tone

    def stripes(fish, fl):
        t = fl["t"]
        on = fl["body"] & (((t * 14.0) % 1.0) < 0.22) & (t < 0.62) & (fl["v"] < 0.55)
        recolor(fl, on, "volt", shift=1, lo=3)

    def mane(fish, w, h, x, y, st, f):
        lay = Layer(w, h)
        fish.paint_fin(lay, x, y, fish.fin_pts(("spiny", 0.0, 0.62, 0.5), "top", st, flutter=0.4), "cyan", 3)
        lay.clean(1)
        return lay

    w, h = 64, 46
    frames = []
    for i in range(N):
        fish = Fish(64, 26, 27, H=0.36, peak=0.35, q=0.8, front_e=0.8, ped=0.9, body="navy", belly="cyan", fin="cyan",
                    eye=0.035, eye_ramp="volt", belly_v=0.68, tail=None, dorsal=None, anal=None, pectoral=None,
                    pelvic=0.0, wag=0.0, pattern=stripes, gill=False,
                    mouth=dict(v=0.6, corner_t=0.8, corner_v=0.64, open=0.62, teeth="fang", teeth_n=4, teeth_len=0.03))
        fish.extra_shapes.append(horn)
        st = FP.frame_state(i)
        st["lunge"] = 0.0
        X, Y = FP.grid(w, h)
        x, y = fish.to_fish(X, Y, st)
        f = fish._body_fields(x, y, st)
        f["X"], f["Y"] = X, Y
        im = mane(fish, w, h, x, y, st, f).to_image()
        body = fish.render(w, h, st, parts=("body",))["body"].to_image()
        im.alpha_composite(body)
        frames.append(im)
    out = Image.new("RGBA", (w * N, h))
    for k, im in enumerate(frames):
        out.alpha_composite(im, (k * w, 0))
    return out


# --------------------------------------------------------------- titanacon
def titan_armor(fish, fl):
    """Bony head armour (like Dunkleosteus): plates with seams, bony jaw blades."""
    t, v = fl["t"], fl["v"]
    lay = fl["lay"]
    head = fl["up"] & (t > 0.63) & (v < 0.66)
    recolor(fl, head, "armor", shift=0, lo=2)
    hgt = fish.bottom(t) - fish.top(t)
    seam = head & ((np.abs(t - 0.72) * fish.L < 0.6) | (np.abs(t - 0.83) * fish.L < 0.6) | (np.abs(v - 0.34) * hgt < 0.6))
    lay.paint(seam, "armor", 1)
    lay.shift(head & (np.abs(t - 0.72) * fish.L >= 0.6) & (np.abs(t - 0.72) * fish.L < 1.6), +1, hi=6)
    lay.shift(head & (np.abs(t - 0.83) * fish.L >= 0.6) & (np.abs(t - 0.83) * fish.L < 1.6), +1, hi=6)
    recolor(fl, fl["jaw"] & (v < 0.9), "armor", shift=0, lo=2)
    # scars and dark mottling on the flank
    spots(fish, fl, "titan", cell=0.07, rad=(0.008, 0.016), zone=fl["body"] & (t < 0.62) & (v < 0.6), seed=41, shift=-1, density=0.5)


def titan_glow(fish, st, f, lay):
    """Row of glowing red vents along the flank (reads well in the dark)."""
    s = max(3.0, 0.045 * fish.L)
    on = f["body"] & (np.abs(f["v"] - 0.56) * (fish.bottom(f["t"]) - fish.top(f["t"])) < 0.8)
    on &= ((f["sx"] - fish.xt) % s) < 1.2
    on &= (f["t"] > 0.14) & (f["t"] < 0.6)
    lay.paint(on, "iris_red", 6)


def titanacon():
    # colossal: rendered at 260 px (x2 in game), frames in 2 rows to fit mobile texture limits
    return sheet(260, rows=2, H=0.42, peak=0.62, q=0.8, front_e=0.5, top_ratio=0.52, ped=0.2, hump=0.1, hump_t=0.72,
                 body="titan", belly="titanbelly", fin="titan", tail="lunate", tail_len=0.34, eye=0.024,
                 eye_ramp="iris_red", eye_t=0.86, eye_v=0.3, dorsal=("spiny", 0.4, 0.62, 0.5),
                 anal=("tri", 0.2, 0.28, 0.3), pectoral=(0.2, 0.1), pelvic=0.08, gill=False, backshade=0.22,
                 belly_v=0.64, wag=0.6, pattern=titan_armor, extras=(titan_glow,),
                 mouth=dict(v=0.62, corner_t=0.66, corner_v=0.64, sag=0.04, open=1.0, teeth="triangle", teeth_n=6,
                            teeth_len=0.04, tongue=True))


# Body cavity seen through the "x-ray" while the player is inside (in sprite pixels,
# relative to the body centre; the game scales it like the boss sprite).
CAVITY = dict(cx=-4.0, cy=6.0, rx=146.0, ry=76.0)


def _cavity_grid(pad=6):
    c = CAVITY
    w, h = int(c["rx"] * 2 + pad * 2), int(c["ry"] * 2 + pad * 2)
    X, Y = np.meshgrid(np.arange(w) + 0.5, np.arange(h) + 0.5)
    return c, w, h, X, Y, w / 2.0, h / 2.0


# vanishing point of the gullet (toward the tail), relative to the cavity centre
VP = (-0.42, -0.05)


def titan_far():
    """Deep layer: the gullet recedes to a dark vanishing point (the intestine)
    with fleshy rings shrinking and darkening with distance."""
    import props
    from pro import ramp
    c, w, h, X, Y, ex, ey = _cavity_grid()
    vx, vy = ex + VP[0] * c["rx"], ey + VP[1] * c["ry"]
    dark = ramp("#5a1a2e", dark=0.3)
    flesh = FP.PAL["flesh"]
    lay = Layer(w, h)
    # "depth" of each pixel: 0 at the rim (near), 1 at the vanishing point (far)
    best = np.zeros(X.shape)
    for s_ in np.linspace(1.0, 0.04, 90):
        cxs, cys = vx + (ex - vx) * s_, vy + (ey - vy) * s_
        inside = ((X - cxs) / (c["rx"] * s_)) ** 2 + ((Y - cys) / (c["ry"] * s_)) ** 2 <= 1.0
        best = np.where(inside, 1.0 - s_, best)
    cav = ((X - ex) / c["rx"]) ** 2 + ((Y - ey) / c["ry"]) ** 2 <= 1.0
    depth = np.where(cav, best, 0.0)
    nz = props.noise2(X, Y, 7.0, 31)
    # rings: equal steps in 1/scale feel evenly spaced in depth
    ringpos = (1.0 / np.maximum(1.0 - depth, 0.05)) * 1.6 + nz * 0.25
    ring = (ringpos % 1.0) < 0.16
    light = (1.0 - depth) ** 1.3
    tone = np.clip(np.floor(light * 4.6), 0, 4).astype(int)
    lay.paint(cav, dark, np.clip(tone, 0, 4))
    lay.paint(cav & (light > 0.62), flesh, np.clip(tone - 2, 1, 3))
    lay.shift(cav & ring & (depth < 0.85), +1, hi=5)
    hole = cav & (depth > 0.9)
    lay.paint(hole, FP.PAL["black"], 0)
    return lay.to_image(outline=False)


def titan_mid():
    """Middle layer: rib arches and the acid floor, both in perspective."""
    from pro import ramp
    c, w, h, X, Y, ex, ey = _cavity_grid()
    vx, vy = ex + VP[0] * c["rx"], ey + VP[1] * c["ry"]
    lay = Layer(w, h)
    bone = FP.PAL["bone"]
    for s_ in (0.92, 0.7, 0.52, 0.38, 0.27):
        cxs, cys = vx + (ex - vx) * s_, vy + (ey - vy) * s_
        rx, ry = c["rx"] * s_ * 0.97, c["ry"] * s_ * 0.97
        d = np.abs(np.hypot((X - cxs) / rx, (Y - cys) / ry) - 1.0) * ry
        th = 2.6 * s_ + 0.4
        rib = (d < th) & (Y < cys + ry * 0.25)
        tone = {0.92: 5, 0.7: 4, 0.52: 3, 0.38: 2, 0.27: 1}[s_]
        lay.paint(rib, bone if s_ > 0.45 else ramp("#8a6a6e", dark=0.3), np.where(d < th * 0.4, tone, max(0, tone - 2)))
    # acid floor: a plane whose far edge converges toward the vanishing point
    yl = ey + c["ry"] * 0.55
    far_y = vy + (yl - vy) * 0.25
    u = np.clip((Y - far_y) / max(1.0, yl - far_y), 0, 1)       # 0 far .. 1 near
    half = (c["rx"] * 0.25) + (c["rx"] * 0.95 - c["rx"] * 0.25) * u
    xc = vx + (ex - vx) * (0.25 + 0.75 * u)
    floor = (Y >= far_y) & (np.abs(X - xc) <= half)
    floor &= ((X - ex) / c["rx"]) ** 2 + ((Y - ey) / c["ry"]) ** 2 <= 1.0
    acid = FP.PAL["acid"]
    lay.paint(floor, acid, np.clip(np.floor(1 + u * 3.2).astype(int), 1, 4))
    # ripples get wider toward the viewer (perspective)
    shine = floor & (np.abs(np.sin((X - xc) / (2.0 + 6.0 * u) + u * 14.0)) < 0.08) & (u > 0.3)
    lay.shift(shine, +1, hi=5)
    return lay.to_image(outline=False)


def titan_near():
    """Front layer, drawn over the player: thick wall folds, dripping mucus."""
    import props
    from pro import ramp
    c, w, h, X, Y, ex, ey = _cavity_grid()
    dark = ramp("#5a1a2e", dark=0.3)
    flesh = FP.PAL["flesh"]
    nz = props.noise2(X, Y, 6.0, 41)
    r = np.hypot((X - ex) / c["rx"], (Y - ey) / c["ry"])
    edge = 0.86 + 0.07 * nz + 0.05 * np.sin(np.arctan2(Y - ey, X - ex) * 9.0)
    wall = (r >= edge) & (r <= 1.02)
    lay = Layer(w, h)
    t = np.clip((r - edge) / 0.14, 0, 1)
    lay.paint(wall, dark, np.clip(np.floor(1 + (1 - t) * 3).astype(int), 1, 4))
    lay.paint(wall & (t < 0.35) & (Y < ey), flesh, 3)
    # mucus drips hanging from the upper wall
    rng = np.random.default_rng(5)
    for _ in range(9):
        a = rng.uniform(math.pi * 1.1, math.pi * 1.9)
        bx, by = ex + math.cos(a) * c["rx"] * 0.86, ey + math.sin(a) * c["ry"] * 0.86
        ln = rng.uniform(4, 11)
        drip = (np.abs(X - bx) < 1.2 - (Y - by) / ln * 0.5) & (Y >= by) & (Y < by + ln)
        lay.paint(drip, FP.PAL["pink"], 4, alpha=210)
        lay.paint((np.hypot(X - bx, Y - (by + ln)) < 1.4), FP.PAL["pink"], 6, alpha=230)
    return lay.to_image(outline=False)


def parasite():
    """Lamprey-like parasite that lives inside the Titanacon: sucker mouth ringed with teeth."""
    def pores(fish, st, f, lay):
        s = max(2.0, 0.06 * fish.L)
        on = f["up"] & (np.abs(f["v"] - 0.45) * (fish.bottom(f["t"]) - fish.top(f["t"])) < 0.6)
        on &= ((f["sx"] - fish.xt) % s) < 1.0
        on &= (f["t"] > 0.66) & (f["t"] < 0.84)
        lay.paint(on, "black", 1)
    return sheet(18, H=0.24, peak=0.74, q=0.6, front_e=0.75, ped=0.5, top_ratio=0.5, body="parasite", belly="pink",
                 fin="parasite", tail="point", tail_len=0.22, eye=0.07, eye_ramp="iris_gold", eye_t=0.88, eye_v=0.35,
                 dorsal=("low", 0.08, 0.5, 0.4), anal=None, pectoral=None, pelvic=0.0, gill=False, wag=2.0,
                 extras=(pores,), mouth=dict(v=0.5, corner_t=0.9, corner_v=0.55, open=0.95, teeth="needle",
                                             teeth_n=3, teeth_len=0.08, tongue=False))


def viperfish():
    """Peixe-Víbora: slim abyssal hunter, needle fangs that never fit in the
    mouth, a photophore line along the belly and a glowing eye."""
    return sheet(24, H=0.26, peak=0.64, q=0.9, front_e=0.6, body="abyss", belly="ink", fin="abyss", tail="fork",
                 tail_len=0.3, eye=0.09, eye_ramp="glow", dorsal=("tri", 0.66, 0.72, 0.5), anal=("tri", 0.14, 0.24, 0.4),
                 pectoral=(0.14, 0.06), pelvic=0.0, gloss=False, countershade=0.1, extras=(photophores(0.82, 0.07),),
                 mouth=dict(v=0.5, corner_t=0.72, corner_v=0.56, open=1.0, under=0.08, chin=0.3, teeth="needle",
                            teeth_n=3, teeth_len=0.2, closed_teeth=True, tongue=False))


ALL = {"viperfish": viperfish, 
    "sardine": sardine, "golden": golden, "pilot": pilot, "lanternfish": lanternfish, "piranha": piranha,
    "puffer": puffer, "puffer_big": puffer_big, "barracuda": barracuda, "shark": shark, "angler": angler,
    "orca": orca, "moray": moray, "boss_shark": boss_shark, "boss_angler": boss_angler,
    "leviathan_head": leviathan_head, "titanacon": titanacon, "parasite": parasite,
    "titan_far": titan_far, "titan_mid": titan_mid, "titan_near": titan_near,
}

# swim / action frame counts per sheet (default for this module: 6 swim + 4 bite)
ANIM = {name: (FP.SWIM_N, FP.BITE_N) for name in ALL}
ANIM["puffer_big"] = (4, 0)
for _k in ("titan_far", "titan_mid", "titan_near"):
    ANIM[_k] = (1, 0)
