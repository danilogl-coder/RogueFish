"""Scenery props rendered with the same pro shading as the fish (fishpro/pro).

Rocks are built from Voronoi cells: every stone gets its own small dome of
light on top of the big form, cracks between cells are the darkest tone and
the top edge of each stone catches the light. Organic props (coral, anemone,
seagrass, kelp) are shaded as cylinders along their skeleton. Everything uses
hue-shifted ramps, clean clusters and selective outlines; the bottom rows of
grounded props are meant to be hidden behind the terrain lip.
"""
from __future__ import annotations

import math

import numpy as np
from PIL import Image
from scipy import ndimage
from scipy.spatial import cKDTree

import pro
from pro import PAL, ramp, poly_mask, seg_dist
from fishpro import Layer, band

ROCK = ramp("#7a7090", dark=0.28)
ROCK_DARK = ramp("#4a4462", dark=0.3)
SMOKER = ramp("#4c4052", dark=0.3)
MOSS = PAL["moss"]
WOOD = ramp("#a8683a", dark=0.3)
GOLD = ramp("#ffc83a")


def grid(w, h):
    ys, xs = np.mgrid[0:h, 0:w].astype(np.float64)
    return xs + 0.5, ys + 0.5


def sheet(frames):
    w, h = frames[0].size
    out = Image.new("RGBA", (w * len(frames), h))
    for k, im in enumerate(frames):
        out.alpha_composite(im, (k * w, 0))
    return out


def light_of(height, smooth=0.8, ambient=0.2):
    n = pro.normals(height, smooth=smooth)
    return pro.light(n, ambient=ambient)


def noise2(X, Y, scale, seed):
    """Cheap smooth 2D value noise in [-1, 1]."""
    rng = np.random.default_rng(seed)
    gw, gh = int(X.max() / scale) + 3, int(Y.max() / scale) + 3
    g = rng.uniform(-1, 1, (gh, gw))
    u, v = X / scale, Y / scale
    i, j = np.floor(u).astype(int), np.floor(v).astype(int)
    fu, fv = u - i, v - j
    fu, fv = fu * fu * (3 - 2 * fu), fv * fv * (3 - 2 * fv)
    a = g[j, i] * (1 - fu) + g[j, i + 1] * fu
    b = g[j + 1, i] * (1 - fu) + g[j + 1, i + 1] * fu
    return a * (1 - fv) + b * fv


# ------------------------------------------------------------------- rocks
def voronoi(mask, cell, seed):
    ys, xs = np.nonzero(mask)
    rng = np.random.default_rng(seed)
    n = max(3, int(mask.sum() / (cell * cell)))
    pick = rng.choice(len(xs), min(n, len(xs)), replace=False)
    pts = np.stack([xs[pick], ys[pick]], 1) + rng.uniform(0, 1, (len(pick), 2))
    _, lab = cKDTree(pts).query(np.stack([xs + 0.5, ys + 0.5], 1))
    labels = np.full(mask.shape, -1)
    labels[ys, xs] = lab
    border = np.zeros_like(mask)
    border[:, :-1] |= (labels[:, :-1] != labels[:, 1:]) & mask[:, 1:] & mask[:, :-1]
    border[:-1, :] |= (labels[:-1, :] != labels[1:, :]) & mask[1:, :] & mask[:-1, :]
    return labels, border


def rock_layer(mask, rmp, cell=8, seed=0, big=0.65, lay=None, bands=(0.3, 0.48, 0.66, 0.84)):
    """Shaded stony mass: big dome form + per-stone domes + dark cracks."""
    h, w = mask.shape
    lay = lay or Layer(w, h)
    labels, border = voronoi(mask, cell, seed)
    inner = mask & ~border
    small = ndimage.distance_transform_edt(inner)
    small = np.sqrt(np.clip(small / 3.0, 0, 1)) * 3.0
    large = pro.dome_height(mask)
    height = large * big + small * (1.0 - big) * 2.2
    li = light_of(height, smooth=0.7)
    tone = band(li, bands)
    lay.paint(mask, rmp, tone)
    lay.paint(border, rmp, np.clip(tone - 2, 1, 5))
    # lit top edge of every stone
    above_border = np.pad(border, ((1, 0), (0, 0)))[:-1, :]
    lay.shift(inner & above_border & (tone >= 3), +1, hi=5)
    return lay, labels, border


def cave_front():
    w, h = 128, 72
    X, Y = grid(w, h)
    nz = noise2(X, Y, 9.0, 3)
    outer = ((X - w / 2) / (62.0 + 3.0 * nz)) ** 2 + ((Y - h) / (70.0 + 3.0 * nz)) ** 2 <= 1.0
    inner = ((X - w / 2) / 40.0) ** 2 + ((Y - h) / 50.0) ** 2 <= 1.0
    # stalactites hanging from the arch
    for sx, ln in ((46, 8), (57, 5), (70, 9), (80, 4)):
        tip = poly_mask(X, Y, [(sx - 3, h - 49), (sx + 3, h - 49), (sx + 0.5, h - 49 + ln)])
        inner &= ~tip
    mask = outer & ~inner
    lay, labels, border = rock_layer(mask, ROCK, cell=9, seed=5)
    # moss and small corals on top
    top_edge = mask & ~np.pad(mask, ((1, 0), (0, 0)))[:-1, :]
    near_top = ndimage.binary_dilation(top_edge, iterations=3) & mask & (Y < h - 30)
    moss = near_top & (noise2(X, Y, 6.0, 8) > 0.05)
    lay.paint(moss, MOSS, np.where(ndimage.binary_dilation(top_edge, iterations=1) & moss, 5, 4))
    for cx in (30, 88, 104):
        cy = float(np.argmax(mask[:, cx])) + 1
        for k in range(3):
            d = seg_dist(X, Y, cx + k * 2 - 2, cy, cx + (k - 1) * 3, cy - 4 - k % 2 * 2)
            lay.paint(d < 0.7, PAL["coral"], 5 if k == 1 else 4)
    lay.clean(1)
    return lay.to_image()


def cave_back():
    w, h = 128, 72
    X, Y = grid(w, h)
    inner = ((X - w / 2) / 44.0) ** 2 + ((Y - h) / 54.0) ** 2 <= 1.0
    lay = Layer(w, h)
    depth = np.clip(1.0 - (((X - w / 2) / 44.0) ** 2 + ((Y - h) / 54.0) ** 2), 0, 1)
    tone = np.where(depth > 0.55, 0, np.where(depth > 0.22, 1, 2))
    lay.paint(inner, ROCK_DARK, tone)
    # faint back-wall stones near the rim
    labels, border = voronoi(inner, 10, 12)
    lay.paint(border & (depth < 0.35), ROCK_DARK, 1)
    return lay.to_image(outline=False)


def eel_rock():
    w, h = 52, 36
    X, Y = grid(w, h)
    nz = noise2(X, Y, 6.0, 21)
    mound = ((X - w / 2) / (25.0 + 2 * nz)) ** 2 + ((Y - h) / (33.0 + 2 * nz)) ** 2 <= 1.0
    lay, labels, border = rock_layer(mound, ROCK, cell=7, seed=9)
    # the moray's den: a dark hole with a lit lower lip
    hole = ((X - 27) / 8.5) ** 2 + ((Y - 21) / 6.0) ** 2 <= 1.0
    lay.paint(hole, PAL["black"], np.where(Y < 19, 0, 1))
    lip = ndimage.binary_dilation(hole) & ~hole & mound & (Y > 21)
    lay.paint(lip, ROCK, 5)
    rim = ndimage.binary_dilation(hole) & ~hole & mound & (Y <= 21)
    lay.paint(rim, ROCK, 1)
    # sponges / coral dots
    for cx, cy, c in ((10, 24, "orange"), (40, 16, "coral"), (35, 29, "violet")):
        dd = np.hypot(X - cx, Y - cy)
        lay.paint((dd < 1.8) & mound, PAL[c], np.where(Y < cy, 5, 4))
    lay.clean(1)
    return lay.to_image()


def black_smoker():
    w, h = 34, 64
    X, Y = grid(w, h)
    t = Y / h
    nz = noise2(X, Y, 5.0, 31)
    half = 5.0 + 11.0 * t ** 1.6 + 1.6 * nz
    col = np.abs(X - w / 2 + 1.5 * np.sin(Y * 0.15)) <= half
    col &= Y > 4
    lay, labels, border = rock_layer(col, SMOKER, cell=6, seed=4, big=0.55)
    # glowing mineral cracks: a few cell borders shine
    rng = np.random.default_rng(7)
    hot_cells = rng.random(labels.max() + 2) < 0.28
    hot = border & (hot_cells[np.clip(labels, 0, None)]) & (Y > 10)
    lay.paint(hot, PAL["orange"], np.where(Y < 30, 6, 5))
    # crater with glow at the top
    top_rim = col & (Y < 9)
    lay.paint(top_rim, SMOKER, 2)
    crater = (np.abs(X - w / 2 - 0.5) < 3.5) & (Y >= 4) & (Y < 7)
    lay.paint(crater, PAL["volt"], 6)
    lay.paint((np.abs(X - w / 2 - 0.5) < 2.5) & (Y >= 7) & (Y < 9), PAL["orange"], 5)
    lay.clean(1)
    return lay.to_image()


def vent():
    w, h = 32, 26
    X, Y = grid(w, h)
    nz = noise2(X, Y, 5.0, 41)
    mound = ((X - w / 2) / (15.0 + nz)) ** 2 + ((Y - h) / (19.0 + nz)) ** 2 <= 1.0
    mound &= ~(((X - w / 2) / 4.0) ** 2 + ((Y - 7) / 3.0) ** 2 <= 1.0)
    lay, labels, border = rock_layer(mound, SMOKER, cell=6, seed=6)
    fis = mound & (np.abs(X - w / 2 - 1.5 * np.sin(Y * 0.5)) < 1.0) & (Y > 8) & (Y < 20)
    lay.paint(fis, PAL["orange"], 5)
    lay.paint((((X - w / 2) / 4.0) ** 2 + ((Y - 8.5) / 1.5) ** 2 <= 1.0), PAL["volt"], 6)
    lay.clean(1)
    return lay.to_image()


# ------------------------------------------------------------ whale fall
def whale_bones():
    w, h = 140, 46
    X, Y = grid(w, h)
    lay = Layer(w, h)
    bone = PAL["bone"]
    ground = 42.0
    # ribs: arcs rising from the spine and curving back toward the tail
    for k in range(9):
        bx = 30 + k * 10.0
        ht = 27 - abs(k - 3.0) * 2.4
        lean = 9.0 + k * 0.4
        pts = []
        for u in np.linspace(0, 1, 12):
            a = u * math.pi * 0.5
            pts.append((bx - lean * (1 - math.cos(a)), ground - 6 - ht * math.sin(a)))
        d = np.full(X.shape, 99.0)
        for i in range(len(pts) - 1):
            d = np.minimum(d, seg_dist(X, Y, *pts[i], *pts[i + 1]))
        th = 1.7 - 0.6 * np.clip((ground - 6 - Y) / ht, 0, 1)
        rib = d <= th
        # lit on the outer (upper-front) side of the curve
        cxr, cyr = bx - lean, ground - 6
        outer_side = np.hypot((X - cxr) / lean, (Y - cyr) / ht) > 1.0
        lay.paint(rib, bone, np.where(outer_side, 5, 3))
    # vertebrae chain
    for k in range(15):
        vx = 8 + k * 7.4
        vy = ground - 4 - 1.2 * math.sin(k * 0.5)
        r = 3.6 - abs(k - 9) * 0.12
        v = ((X - vx) / r) ** 2 + ((Y - vy) / (r * 0.8)) ** 2 <= 1.0
        tone = np.where(Y < vy - r * 0.3, 5, np.where(Y > vy + r * 0.3, 3, 4))
        lay.paint(v, bone, tone)
        spine = poly_mask(X, Y, [(vx - 1, vy - r * 0.6), (vx + 1, vy - r * 0.6), (vx - 1.5, vy - r * 1.9)])
        lay.paint(spine, bone, 4)
    # skull and jaw
    skull = ((X - 124) / 15.0) ** 2 + ((Y - 34) / 9.5) ** 2 <= 1.0
    skull |= poly_mask(X, Y, [(110, 30), (139, 34), (139, 40), (112, 42)])
    lay.paint(skull, bone, np.where(Y < 30, 5, np.where(Y > 38, 3, 4)))
    eye = ((X - 128) / 3.0) ** 2 + ((Y - 32) / 2.4) ** 2 <= 1.0
    lay.paint(eye, PAL["black"], 1)
    jaw = poly_mask(X, Y, [(96, 41), (139, 41), (139, 43.5), (98, 44.5)])
    lay.paint(jaw, bone, 3)
    # bone-eating worms (pink tufts) and bacterial film
    for bx, by in ((40, 20), (61, 16), (86, 22), (122, 26), (70, 38)):
        lay.paint(np.hypot(X - bx, Y - by) < 1.3, PAL["coral"], 5)
    lay.clean(1)
    img = lay.to_image()
    return img


# ------------------------------------------------------------------ corals
def capsule_field(segs, X, Y):
    """Distance to a set of (x0, y0, x1, y1, r0, r1) tapered segments.
    Returns inside mask and a cylinder height (for shading)."""
    inside = np.zeros(X.shape, dtype=bool)
    hgt = np.zeros(X.shape)
    for x0, y0, x1, y1, r0, r1 in segs:
        dx, dy = x1 - x0, y1 - y0
        l2 = dx * dx + dy * dy + 1e-9
        t = np.clip(((X - x0) * dx + (Y - y0) * dy) / l2, 0, 1)
        px, py = x0 + t * dx, y0 + t * dy
        d = np.hypot(X - px, Y - py)
        r = r0 + (r1 - r0) * t
        m = d <= r
        hh = np.sqrt(np.clip(1 - (d / np.maximum(r, 0.5)) ** 2, 0, 1)) * r
        hgt = np.where(m, np.maximum(hgt, hh), hgt)
        inside |= m
    return inside, hgt


def branch_segments(x, y, ang, length, thick, depth, rng, out):
    x1 = x + math.cos(ang) * length
    y1 = y + math.sin(ang) * length
    out.append((x, y, x1, y1, thick, thick * 0.78))
    if depth <= 0 or thick < 0.6:
        out.append((x1, y1, x1, y1, thick * 0.95, thick * 0.95))  # rounded polyp tip
        return
    n = 2 if rng.random() < 0.6 else 3
    for k in range(n):
        da = (k - (n - 1) / 2) * rng.uniform(0.55, 0.85)
        # branches bend back upward (corals grow toward the light)
        na = ang + da + rng.uniform(-0.12, 0.12)
        na = na + (-math.pi / 2 - na) * 0.25
        branch_segments(x1, y1, na, length * rng.uniform(0.66, 0.82), thick * 0.72, depth - 1, rng, out)


def coral_branch(seed, rmp_name):
    """Staghorn coral: short trunk, three limbs that fork once or twice."""
    w, h = 30, 34
    X, Y = grid(w, h)
    rng = np.random.default_rng(seed)
    segs = [(15, 34.5, 15, 28, 2.0, 1.8)]
    tips = []
    for a0 in (-2.35, -1.62, -0.9):
        a = a0 + rng.uniform(-0.12, 0.12)
        l1 = rng.uniform(7.5, 9.5)
        x1, y1 = 15 + math.cos(a) * l1, 28 + math.sin(a) * l1
        segs.append((15, 28, x1, y1, 1.6, 1.3))
        for da in (-0.5, 0.45):
            b = a + da * rng.uniform(0.8, 1.2)
            b += (-math.pi / 2 - b) * 0.35
            l2 = rng.uniform(5.5, 8.0)
            x2, y2 = x1 + math.cos(b) * l2, y1 + math.sin(b) * l2
            segs.append((x1, y1, x2, y2, 1.25, 1.0))
            if rng.random() < 0.55:
                c = b + rng.choice([-0.45, 0.45])
                c += (-math.pi / 2 - c) * 0.3
                l3 = rng.uniform(3.0, 4.5)
                x3, y3 = x2 + math.cos(c) * l3, y2 + math.sin(c) * l3
                segs.append((x2, y2, x3, y3, 0.95, 0.85))
                tips.append((x3, y3))
            tips.append((x2, y2))
    for tx, ty in tips:
        segs.append((tx, ty, tx, ty, 1.05, 1.05))
    m, hgt = capsule_field(segs, X, Y)
    li = light_of(hgt * 1.4, smooth=0.45)
    lay = Layer(w, h)
    rmp = PAL[rmp_name]
    lay.paint(m, rmp, band(li))
    lay.clean(1)
    for tx, ty in tips:
        lay.paint((np.hypot(X - tx, Y - ty) < 0.75) & m, rmp, 6)
    return lay.to_image()


def coral_fan():
    """Sea fan (gorgonian): a tall lattice of branches spreading from one stem."""
    w, h = 34, 28
    X, Y = grid(w, h)
    cx, cy = 17, 27.5
    rng = np.random.default_rng(3)
    segs = [(cx, cy, cx, cy - 6, 1.6, 1.3)]
    # main radiating branches
    tips = []
    for k in range(9):
        a = -math.pi / 2 + (k - 4) * 0.32
        ln = 19 + rng.uniform(-3, 2) - abs(k - 4) * 1.2
        x0, y0 = cx + (k - 4) * 0.4, cy - 6
        mx, my = x0 + math.cos(a) * ln * 0.5, y0 + math.sin(a) * ln * 0.5
        x1, y1 = x0 + math.cos(a) * ln, y0 + math.sin(a) * ln
        segs += [(x0, y0, mx, my, 0.9, 0.75), (mx, my, x1, y1, 0.75, 0.6)]
        tips.append((x1, y1))
    m, hgt = capsule_field(segs, X, Y)
    # cross-links: the fine mesh between the branches
    r = np.hypot(X - cx, (Y - cy + 6) * 0.95)
    a = np.arctan2(Y - cy + 6, X - cx)
    env = (a < -0.25) & (a > -math.pi + 0.25) & (r < 19.5 - np.abs(a + math.pi / 2) * 3.5)
    mesh = env & (np.abs((r / 3.2) % 1.0 - 0.5) < 0.17)
    lay = Layer(w, h)
    rmp = PAL["violet"]
    lay.paint(mesh, rmp, np.where(Y < 12, 4, 3))
    li = light_of(hgt * 1.3, smooth=0.4)
    lay.paint(m, rmp, np.clip(band(li) + 1, 2, 6))
    for tx, ty in tips:
        lay.paint(np.hypot(X - tx, Y - ty) < 0.9, rmp, 6)
    lay.clean(1)
    return lay.to_image()


def coral_brain():
    w, h = 24, 14
    X, Y = grid(w, h)
    dome = ((X - 12) / 11.5) ** 2 + ((Y - 14) / 13.0) ** 2 <= 1.0
    hgt = pro.dome_height(dome)
    li = light_of(hgt * 1.3, smooth=0.9)
    lay = Layer(w, h)
    rmp = ramp("#8fbf4a")
    tone = band(li)
    lay.paint(dome, rmp, tone)
    lay.clean(1)
    inner = ndimage.binary_erosion(dome)
    grooves = inner & (np.abs(np.sin(X * 0.9 + np.sin(Y * 0.75) * 2.4)) < 0.35) & (Y > 2)
    lay.shift(grooves, -1, lo=1)
    return lay.to_image()


def anemone():
    """Sea anemone: a stout column, an oral disc and a crown of drooping tentacles."""
    frames = []
    for i in range(4):
        w, h = 20, 20
        X, Y = grid(w, h)
        segs = [(10, 20.5, 10, 13.5, 3.0, 2.6)]
        tent = []
        for k in range(9):
            side = (k - 4) / 4.0
            sway = math.sin(i * math.pi / 2 + k * 0.9) * 0.28
            x0, y0 = 10 + side * 3.2, 12.2 - (1 - abs(side)) * 0.8
            a1 = -math.pi / 2 + side * 1.15 + sway
            x1, y1 = x0 + math.cos(a1) * 4.0, y0 + math.sin(a1) * 4.0
            a2 = a1 + side * 0.9 + sway * 0.8          # tips droop outward
            x2, y2 = x1 + math.cos(a2) * 3.0, y1 + math.sin(a2) * 3.0
            tent += [(x0, y0, x1, y1, 0.95, 0.8), (x1, y1, x2, y2, 0.8, 0.65)]
        mc, hc = capsule_field(segs, X, Y)
        mt, ht = capsule_field(tent, X, Y)
        lay = Layer(w, h)
        lay.paint(mc, PAL["coral"], band(light_of(hc * 1.5, smooth=0.5)))
        disc = (((X - 10) / 3.6) ** 2 + ((Y - 12.6) / 1.3) ** 2 <= 1.0)
        lay.paint(disc, PAL["coral"], 5)
        lay.paint(mt & ~disc, PAL["pink"], band(light_of(ht * 1.5, smooth=0.3)))
        lay.clean(1)
        # glowing tentacle tips
        for x0, y0, x1, y1, r0, r1 in tent[1::2]:
            lay.paint((np.hypot(X - x1, Y - y1) < 0.8) & mt, PAL["pink"], 6)
        frames.append(lay.to_image())
    return sheet(frames)


def seagrass():
    frames = []
    for i in range(4):
        w, h = 18, 18
        X, Y = grid(w, h)
        lay = Layer(w, h)
        for k, (bx, ln, ph) in enumerate(((5, 15, 0.0), (8, 17, 1.1), (11, 13, 2.2), (13, 10, 3.0), (7, 9, 4.1))):
            sway = math.sin(i * math.pi / 2 + ph) * 2.2
            pts = [(bx + sway * (u ** 1.6), 18 - u * ln) for u in np.linspace(0, 1, 8)]
            d = np.full(X.shape, 99.0)
            for j in range(len(pts) - 1):
                d = np.minimum(d, seg_dist(X, Y, *pts[j], *pts[j + 1]))
            blade = d <= 0.85
            tone = np.where(Y < 18 - ln * 0.7, 5, np.where(k % 2 == 0, 3, 4))
            lay.paint(blade, PAL["moss"], tone)
        lay.clean(1)
        frames.append(lay.to_image())
    return sheet(frames)


def tube_worms():
    frames = []
    for i in range(4):
        w, h = 18, 24
        X, Y = grid(w, h)
        lay = Layer(w, h)
        for k, (tx, th) in enumerate(((4, 13), (8, 18), (11, 11), (14, 15))):
            tube = (np.abs(X - tx) <= 1.6) & (Y > 24 - th)
            rel = (X - tx) / 1.6
            lay.paint(tube, PAL["white"], np.where(rel < -0.2, 5, np.where(rel > 0.4, 3, 4)))
            rings = tube & ((np.floor(Y) % 4) == 0)
            lay.shift(rings, -1, lo=2)
            ext = [1.0, 0.7, 0.35, 0.7][(i + k) % 4]
            py = 24 - th
            plume = (np.hypot((X - tx) / 2.4, (Y - (py - 2.2 * ext)) / (2.2 * ext + 0.4)) <= 1.0) & (Y < py + 0.5)
            lay.paint(plume, PAL["red"], np.where(Y < py - 2.2 * ext, 5, 4))
        lay.clean(1)
        frames.append(lay.to_image())
    return sheet(frames)


def glow_mushroom():
    frames = []
    for i in range(2):
        w, h = 14, 14
        X, Y = grid(w, h)
        lay = Layer(w, h)
        stem = (np.abs(X - 7) < 1.2) & (Y > 7)
        lay.paint(stem, PAL["ink"], 5)
        cap = (((X - 7) / 5.5) ** 2 + ((Y - 7.5) / 4.2) ** 2 <= 1.0) & (Y < 8.5)
        g = PAL["glow"]
        lay.paint(cap, g, np.where(Y < 5, 6 if i else 5, 4 if i else 3))
        spots = cap & (((X * 3 + Y * 5).astype(int) % 7) == 0)
        lay.paint(spots, g, 6)
        small = (((X - 11) / 2.4) ** 2 + ((Y - 10) / 1.8) ** 2 <= 1.0) & (Y < 10.5)
        lay.paint(small, g, 5 if i else 4)
        lay.clean(1)
        frames.append(lay.to_image())
    return sheet(frames)


def thicket():
    """Dense clump of kelp blades used as a hideout (2 sway frames)."""
    frames = []
    w, h = 84, 64
    rng = np.random.default_rng(12)
    blades = []
    for k in range(26):
        bx = rng.uniform(6, 78)
        ln = rng.uniform(34, 62) * (1.0 - abs(bx - 42) / 90.0)
        blades.append((bx, ln, rng.uniform(0, math.tau), rng.uniform(1.4, 2.6), rng.random() < 0.5, rng.integers(0, 3)))
    blades.sort(key=lambda b: b[4])  # back row first
    for i in range(2):
        X, Y = grid(w, h)
        lay = Layer(w, h)
        for bx, ln, ph, wd, front, shade in blades:
            sway = math.sin(ph + i * math.pi) * 3.5
            pts = [(bx + sway * (u ** 1.5) + math.sin(u * 3 + ph) * 2.0, h - u * ln) for u in np.linspace(0, 1, 10)]
            d = np.full(X.shape, 99.0)
            tt = np.zeros(X.shape)
            for j in range(len(pts) - 1):
                dj = seg_dist(X, Y, *pts[j], *pts[j + 1])
                closer = dj < d
                tt = np.where(closer, (j + 0.5) / (len(pts) - 1), tt)
                d = np.minimum(d, dj)
            r = wd * (1.0 - 0.55 * tt) + 0.4
            blade = d <= r
            base = 3 if front else 2
            tone = np.where(tt > 0.7, base + 2, np.where(tt > 0.35, base + 1, base)) - (shade == 2)
            lay.paint(blade, PAL["kelp"] if shade != 1 else PAL["moss"], np.clip(tone, 1, 6))
            mid = blade & (d < 0.45) & (tt > 0.15)
            lay.shift(mid, +1, hi=6)
        # dark hollow at the base where things hide
        hollow = (((X - 42) / 26.0) ** 2 + ((Y - h) / 14.0) ** 2 <= 1.0) & lay.mask
        lay.shift(hollow, -1, lo=1)
        lay.clean(1)
        frames.append(lay.to_image())
    return sheet(frames)


# -------------------------------------------------------------------- POIs
def chest():
    frames = []
    for i in range(2):
        w, h = 28, 24
        X, Y = grid(w, h)
        lay = Layer(w, h)
        body = (X > 3) & (X < 25) & (Y > 12) & (Y < 23)
        plank = ((np.floor(Y) - 12) % 4 == 0)
        lay.paint(body, WOOD, np.where(plank, 2, np.where(X < 8, 4, 3)))
        if i == 0:
            lid = (((X - 14) / 11.2) ** 2 + ((Y - 13) / 7.5) ** 2 <= 1.0) & (Y < 13)
            lay.paint(lid, WOOD, np.where(Y < 8, 5, 4))
            band_ = lid & ((np.abs(X - 7) < 1.1) | (np.abs(X - 21) < 1.1))
            lay.paint(band_, GOLD, 5)
        else:
            lid = poly_mask(X, Y, [(4, 12), (24, 12), (26, 3), (7, 1)])
            lay.paint(lid, WOOD, 2)
            inner = (X > 5) & (X < 23) & (Y > 11) & (Y < 14)
            lay.paint(inner, GOLD, np.where((np.floor(X) % 3) == 0, 6, 5))
        bands = body & ((np.abs(X - 7) < 1.1) | (np.abs(X - 21) < 1.1))
        lay.paint(bands, GOLD, 4)
        lock = (np.abs(X - 14) < 1.8) & (Y > 12) & (Y < 16.5)
        lay.paint(lock, GOLD, np.where(Y < 14, 6, 4))
        # barnacles
        for bx, by in ((5, 21), (22, 19)):
            lay.paint(np.hypot(X - bx, Y - by) < 1.2, PAL["bone"], 4)
        lay.clean(1)
        frames.append(lay.to_image())
    return sheet(frames)


def clam():
    frames = []
    for i in range(3):
        w, h = 36, 28
        X, Y = grid(w, h)
        lay = Layer(w, h)
        shell = PAL["violet"]
        cx, cy = 18, 27
        rel = (X - cx) / 16.0
        wave = 1.4 * np.sin(X * 1.1)
        bottom = (np.abs(rel) <= 1.0) & (Y > cy - 8 + 4 * rel * rel + wave * 0.4) & (Y < cy + 0.5)
        open_h = [0.0, 3.5, 8.0][i]
        top_y = cy - 8 - open_h
        top = (np.abs(rel) <= 1.0) & (Y > top_y - 8 * np.sqrt(np.clip(1 - rel * rel, 0, 1))) & (Y <= top_y + 4 * rel * rel + wave * 0.4)
        ribs = (np.floor(X) % 4 == 0)
        if open_h > 0:
            mantle = (np.abs(rel) <= 0.95) & (Y > top_y + 2) & (Y < cy - 6)
            lay.paint(mantle, PAL["cyan"], np.where((np.floor(X) + np.floor(Y)) % 3 == 0, 5, 4))
            if i == 1:
                pearl = np.hypot(X - cx, Y - (cy - 7.5)) < 2.6
                lay.paint(pearl, PAL["white"], np.where(np.hypot(X - cx + 0.8, Y - (cy - 8.5)) < 1.1, 6, 5))
        lay.paint(bottom, shell, np.where(ribs, 3, 4))
        lay.paint(top, shell, np.where(ribs, 4, np.where(Y < top_y - 4, 6, 5)))
        lay.clean(1)
        frames.append(lay.to_image())
    return sheet(frames)


def kelp_parts():
    """Frames: 0-1 leaf segments, 2 float bulb (top), 3 holdfast."""
    frames = []
    kr = PAL["kelp"]
    for i in range(4):
        w, h = 12, 10
        X, Y = grid(w, h)
        lay = Layer(w, h)
        stipe = (np.abs(X - 6) < 1.1)
        if i < 2:
            sgn = 1 if i == 0 else -1
            blade = poly_mask(X, Y, [(6, 9), (6 + sgn * 5.5, 2.5), (6 + sgn * 6, 5), (6, 10)])
            lay.paint(blade, kr, np.where(Y < 5, 5, 4))
            lay.paint(stipe, kr, 3)
        elif i == 2:
            lay.paint(stipe & (Y > 5), kr, 3)
            bulb = np.hypot(X - 6, Y - 4) < 3.2
            lay.paint(bulb, PAL["olive"], np.where(np.hypot(X - 5, Y - 3) < 1.3, 6, 4))
        else:
            hold = poly_mask(X, Y, [(2, 10), (10, 10), (8, 6), (6, 3), (4, 6)])
            lay.paint(hold, PAL["brown"], np.where(Y < 7, 4, 3))
            lay.paint(stipe & (Y < 6), kr, 3)
        lay.clean(1)
        frames.append(lay.to_image())
    return sheet(frames)


ALL = {
    "cave_front": cave_front, "cave_back": cave_back, "eel_rock": eel_rock, "black_smoker": black_smoker,
    "vent": vent, "whale_bones": whale_bones, "coral_branch": lambda: coral_branch(1, "coral"),
    "coral_branch2": lambda: coral_branch(4, "orange"), "coral_fan": coral_fan, "coral_brain": coral_brain,
    "anemone": anemone, "seagrass": seagrass, "tube_worms": tube_worms, "glow_mushroom": glow_mushroom,
    "chest": chest, "clam": clam, "kelp": kelp_parts, "thicket": thicket,
}


def stomach():
    """Inside the Titanacon: fleshy cavity with folds, veins, ribs and an acid pool (640x360)."""
    w, h = 640, 360
    X, Y = grid(w, h)
    flesh = PAL["flesh"]
    dark = ramp("#5a1a2e", dark=0.3)
    lay = Layer(w, h)
    # cavity: brighter in the middle, darker toward the walls
    cav = ((X - 320) / 360.0) ** 2 + ((Y - 175) / 210.0) ** 2
    base = np.clip(1.15 - cav, 0, 1)
    nz = noise2(X, Y, 40.0, 3)
    # rugae: broad wavy folds of the stomach lining
    fold = np.sin((Y + 16 * np.sin(X / 47.0) + 18 * nz) / 13.0)
    val = base * 0.8 + fold * 0.09
    tone = band(val, (0.2, 0.4, 0.62, 0.85))
    lay.paint(np.ones_like(X, dtype=bool), dark, np.clip(tone, 1, 4))
    lay.paint(val > 0.62, flesh, np.clip(tone - 2, 1, 3))
    ridge = (fold > 0.93) & (val > 0.35)
    lay.shift(ridge, +1, hi=4)
    # veins
    rng = np.random.default_rng(4)
    for _ in range(14):
        x0, y0 = rng.uniform(0, w), rng.uniform(0, h * 0.8)
        pts = [(x0, y0)]
        a = rng.uniform(0, math.tau)
        for _ in range(8):
            a += rng.uniform(-0.6, 0.6)
            pts.append((pts[-1][0] + math.cos(a) * 16, pts[-1][1] + math.sin(a) * 16))
        d = np.full(X.shape, 99.0)
        for j in range(len(pts) - 1):
            d = np.minimum(d, seg_dist(X, Y, *pts[j], *pts[j + 1]))
        lay.paint(d < 1.0, ramp("#7a3a8a"), 1)
    # ribs arching across the ceiling
    for rx in range(40, 640, 90):
        d = np.abs(np.hypot((X - rx - 45) / 70.0, (Y - 70) / 70.0) - 1.0) * 70
        rib = (d < 4.5) & (Y < 60)
        lay.paint(rib, PAL["bone"], np.where(d < 1.6, 4, 2))
    # throat opening on the left (where the fish came in)
    throat = ((X - 0) / 34.0) ** 2 + ((Y - 150) / 60.0) ** 2 <= 1.0
    lay.paint(throat, PAL["black"], 0)
    # acid pool
    surf = 322 + 3 * np.sin(X / 23.0)
    acid = Y > surf
    lay.paint(acid, PAL["acid"], np.where(Y < surf + 2, 5, np.where(Y < surf + 12, 3, 2)))
    bub = acid & (np.hypot((X % 37) - 18, (Y % 13) - 6) < 1.3) & (Y > surf + 4)
    lay.paint(bub, PAL["acid"], 5)
    return lay.to_image(outline=False)


ALL["stomach"] = stomach
