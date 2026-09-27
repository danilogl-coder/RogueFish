"""Player atlases for the non-fish characters (Marés Profundas).

The critter drawings in critters.py are resolution independent (every shape is
a function of X, Y in "sprite units"), so each growth stage is rendered by
sampling the same functions on a finer grid: real pixel art at every size,
never an upscale. Mutations are drawn as fitted parts using anchors measured on
each frame's silhouette (mouth, rear, back line), and each stage adds its own
look (speckles, battle marks, bioluminescent spots).

Atlas layout matches player.py (same LAYERS rows) so PlayerVisual can combine
any mutation set; critters have 4 move + 2 action frames.
"""
from __future__ import annotations

import math
from contextlib import contextmanager

import numpy as np
from PIL import Image
from scipy import ndimage

import critters
import player as PL
from fishpro import Layer
from pro import PAL, ramp, poly_mask, seg_dist

# species -> (critter function, natural body length in sprite units)
CRITTERS = {
    "camarao": ("shrimp", 18.0),
    "caramujo": ("snail", 16.0),
    "pepino": ("sea_cucumber", 24.0),
    "ourico": ("urchin", 15.0),
    "agua_viva": ("jellyfish", 19.0),
    "caranguejo": ("crab", 28.0),
    "lula": ("squid", 30.0),
    "tartaruga": ("turtle", 44.0),
    "isopode": ("isopod", 22.0),
    "lontra": ("otter", 38.0),
    "minhoca": ("bobbit_swim", 40.0),
    "piolho": ("louse_f", 22.0),
    "lula_vampira": ("vampire_squid", 30.0),
}
SIZE_K = 1.1           # critters read a bit smaller than fish of the same length


# ------------------------------------------------------------ scaled render
@contextmanager
def scaled(k):
    og, olayer, odot = critters.grid, critters.Layer, critters.dot

    def grid(w, h):
        W, H = max(4, int(round(w * k))), max(4, int(round(h * k)))
        ys, xs = np.mgrid[0:H, 0:W].astype(np.float64)
        return (xs + 0.5) / k, (ys + 0.5) / k

    class ScaledLayer(olayer):
        def __init__(self, w, h):
            super().__init__(max(4, int(round(w * k))), max(4, int(round(h * k))))

    def dot(lay, X, Y, x, y, rmp, tone):
        r = max(0.5, 0.5 / k)
        cx, cy = math.floor(x) + 0.5, math.floor(y) + 0.5
        lay.paint((np.abs(X - cx) <= r) & (np.abs(Y - cy) <= r), rmp, tone)

    critters.grid, critters.Layer, critters.dot = grid, ScaledLayer, dot
    try:
        yield
    finally:
        critters.grid, critters.Layer, critters.dot = og, olayer, odot


def bobbit_swim():
    """The sea worm swimming: a long iridescent body undulating horizontally,
    antennae and scissor jaws at the right. 4 swim + 2 bite frames."""
    frames = []
    for i in range(6):
        w, h = 48, 20
        X, Y = critters.grid(w, h)
        lay = critters.Layer(w, h)
        ph = i / 4 * math.tau if i < 4 else 0.0
        pts = []
        for s in range(15):
            u = s / 14
            pts.append((4 + u * 34, 11 + math.sin(u * 5.5 - ph) * 2.6 * (1 - u * 0.6)))
        segs = critters.tube(pts, 2.6, 3.6)
        m, hg = critters.capsule_field(segs, X, Y)
        for s in range(1, len(pts) - 1):
            px, py = pts[s]
            for side in (-1, 1):
                d = seg_dist(X, Y, px, py + side * 3.0, px - 1.0, py + side * 4.6)
                lay.paint((d < 0.45), critters.BOBBIT_B, 5, outline=False)
        critters.shaded(lay, m, hg, critters.BOBBIT, gain=1.3)
        rings = m & ((np.floor(X) % 3) == 0)
        lay.shift(rings, -1, lo=1)
        sheen = m & (Y < np.interp(X, [p[0] for p in pts], [p[1] for p in pts]) - 0.8) & ((np.floor(X) % 3) != 0)
        lay.paint(sheen, critters.BOBBIT_B, 5, outline=False)
        hx, hy = pts[-1][0] + 2.5, pts[-1][1]
        head = ((X - hx) / 4.0) ** 2 + ((Y - hy) / 3.6) ** 2 <= 1.0
        critters.shaded(lay, head, critters.pro.dome_height(head), critters.BOBBIT, gain=1.2, shift=1)
        for k, a in enumerate((-1.1, -0.6, -0.2)):
            ln = 5.5 + (1.0 if (i + k) % 2 else 0.0)
            ax, ay = hx + 1 + math.cos(a) * ln, hy - 2 + math.sin(a) * ln
            d = seg_dist(X, Y, hx, hy - 2, ax, ay)
            lay.paint((d < 0.45) & ((np.floor(X) % 2) == 0), PAL["white"], 5, outline=False)
            lay.paint((d < 0.45) & ((np.floor(X) % 2) == 1), critters.BOBBIT, 2, outline=False)
        gape = 0.25 if i < 4 else (1.1 if i == 4 else 0.05)
        for s in (-1, 1):
            a0 = s * (0.2 + gape * 0.6)
            x0, y0 = hx + 3.0, hy + s * 0.8
            x1, y1 = x0 + math.cos(a0) * 4.2, y0 + math.sin(a0) * 4.2
            d = np.minimum(seg_dist(X, Y, x0, y0, x1, y1), seg_dist(X, Y, x1, y1, x1 + 0.6, y1 - s * 1.8))
            lay.paint(d < 0.6, critters.BOBBIT_B, 4)
        critters.dot(lay, X, Y, hx + 0.8, hy - 1.0, PAL["black"], 0)
        lay.clean(1)
        frames.append(lay.to_image())
    return critters.sheet(frames)


def _render_frames(species, stage):
    fname, base_len = CRITTERS[species]
    L = max(base_len * 0.85, PL.STAGE_LEN[stage] * SIZE_K)
    k = L / base_len
    with scaled(k):
        if fname == "bobbit_swim":
            sheet = bobbit_swim()
        elif fname == "louse_f":
            sheet = critters._louse(True)
        else:
            sheet = getattr(critters, fname)()
    n = 6
    fw = sheet.size[0] // n
    frames = [sheet.crop((j * fw, 0, (j + 1) * fw, sheet.size[1])) for j in range(n)]
    return frames, k


# ------------------------------------------------------------- anchors
def anchors(img):
    """Mouth (front-middle), rear, back line and bounding box of a frame."""
    a = np.array(img)[:, :, 3] > 0
    ys, xs = np.nonzero(a)
    y0, y1, x0, x1 = ys.min(), ys.max(), xs.min(), xs.max()
    mid = (ys > y0 + (y1 - y0) * 0.25) & (ys < y1 - (y1 - y0) * 0.25)
    front = xs[mid].max() if mid.any() else x1
    fy = ys[mid][xs[mid] >= front - 1].mean() if mid.any() else (y0 + y1) / 2
    back = xs[mid].min() if mid.any() else x0
    by = ys[mid][xs[mid] <= back + 1].mean() if mid.any() else (y0 + y1) / 2
    top = []
    for x in range(x0, x1 + 1):
        col_ = np.nonzero(a[:, x])[0]
        if len(col_):
            top.append((x, col_.min()))
    return dict(mouth=(float(front), float(fy)), rear=(float(back), float(by)), top=top,
                box=(x0, y0, x1, y1), mask=a)


def body_ramp(img):
    arr = np.array(img)
    a = arr[:, :, 3] > 0
    er = ndimage.binary_erosion(a, iterations=1)
    px = arr[er][:, :3] if er.any() else arr[a][:, :3]
    med = np.median(px, axis=0).astype(int)
    return ramp("#%02x%02x%02x" % tuple(int(c) for c in med))


def _hash(x, y, s):
    v = np.sin(x * 12.9898 + y * 78.233 + s * 37.719) * 43758.5453
    return v - np.floor(v)


def _interior(img):
    a = np.array(img)[:, :, 3] > 0
    return ndimage.binary_erosion(a, iterations=1)


def _tint(img, mask, rgb, amount):
    arr = np.array(img).astype(np.float32)
    for c in range(3):
        arr[:, :, c] = np.where(mask, arr[:, :, c] * (1 - amount) + rgb[c] * amount, arr[:, :, c])
    return Image.fromarray(arr.clip(0, 255).astype(np.uint8), "RGBA")


def _shade(img, mask, k):
    arr = np.array(img).astype(np.float32)
    arr[:, :, :3] = np.where(mask[:, :, None], arr[:, :, :3] * k, arr[:, :, :3])
    return Image.fromarray(arr.clip(0, 255).astype(np.uint8), "RGBA")


def _put(img, mask, rgb):
    arr = np.array(img)
    arr[mask, 0], arr[mask, 1], arr[mask, 2] = rgb
    arr[mask, 3] = 255
    return Image.fromarray(arr, "RGBA")


# ----------------------------------------------------- stage appearance
def stage_look(img, stage, sp_seed):
    inner = _interior(img)
    h, w = inner.shape
    Y, X = np.mgrid[0:h, 0:w]
    cell = max(3, int(round(min(w, h) / 7)))
    if stage >= 2:      # adult: speckles
        spk = inner & (_hash(X // cell, Y // cell, sp_seed) > 0.78) & (((X + Y) % cell) == 0)
        img = _shade(img, spk, 1.22)
    if stage >= 3:      # veteran: darker battle marks across the back
        a = anchors(img)
        x0, y0, x1, y1 = a["box"]
        marks = np.zeros_like(inner)
        for j in range(3):
            cx = x0 + (x1 - x0) * (0.35 + 0.12 * j)
            d = np.abs((X - cx) - (Y - y0) * 0.5)
            marks |= inner & (d < 0.7) & (Y < y0 + (y1 - y0) * 0.45)
        img = _shade(img, marks, 0.72)
    if stage >= 4:      # leviathan: bioluminescent spots
        glow = inner & (_hash(X // cell, Y // cell, sp_seed + 5) > 0.86) & ((X % cell) == cell // 2) & ((Y % cell) == cell // 2)
        grow = ndimage.binary_dilation(glow, iterations=1) & inner
        img = _put(img, grow, (80, 220, 255))
        img = _put(img, glow, (230, 255, 255))
    return img


# ------------------------------------------------------ mutation parts
def skin_variant(img, skin, seed):
    if not skin:
        return img
    inner = _interior(img)
    h, w = inner.shape
    Y, X = np.mgrid[0:h, 0:w]
    if skin == "skin_armor":
        cell = max(3, int(round(min(w, h) / 6)))
        seam = inner & (((X + (Y // cell) * (cell // 2)) % cell == 0) | (Y % cell == 0))
        img = _tint(img, inner, (184, 174, 156), 0.35)
        img = _shade(img, seam, 0.62)
        hl = inner & (((X + (Y // cell) * (cell // 2)) % cell == 1)) & (Y % cell == 1)
        img = _shade(img, hl, 1.35)
    elif skin == "skin_toxic":
        cell = max(3, int(round(min(w, h) / 6)))
        cx = (X // cell) * cell + cell // 2 + (_hash(X // cell, Y // cell, seed) * 2 - 1)
        cy = (Y // cell) * cell + cell // 2
        spot = inner & (np.hypot(X - cx, Y - cy) < cell * 0.26) & (_hash(X // cell, Y // cell, seed + 1) > 0.35)
        ring = ndimage.binary_dilation(spot) & inner & ~spot
        img = _put(img, ring, (70, 120, 30))
        img = _put(img, spot, (170, 236, 70))
    elif skin == "skin_glow":
        img = _tint(img, inner, (60, 200, 220), 0.18)
        cell = max(3, int(round(min(w, h) / 5)))
        dots = inner & ((X % cell) == 0) & ((Y % cell) == cell // 2) & (_hash(X // cell, Y // cell, seed) > 0.4)
        img = _put(img, ndimage.binary_dilation(dots) & inner, (90, 230, 255))
        img = _put(img, dots, (235, 255, 255))
    return img


def head_part(img, head, anc, size, frame):
    """Teeth / rostrum / lure drawn on the body frame. Returns (img, lure_pos)."""
    if not head:
        return img, None
    w, h = img.size
    X, Y = np.meshgrid(np.arange(w) + 0.5, np.arange(h) + 0.5)
    lay = Layer(w, h)
    mx, my = anc["mouth"]
    lure = None
    if head == "head_piranha":
        n = 3
        tl = max(1.6, size * 0.09)
        for j in range(n):
            x = mx - 0.6 - j * tl * 0.9
            for s in (-1, 1):
                pts = [(x - tl * 0.45, my + s * 0.2), (x + tl * 0.45, my + s * 0.2), (x, my + s * (tl + 0.2))]
                lay.paint(poly_mask(X, Y, pts), PAL["white"], 5)
        lay.paint(np.hypot(X - mx + 1, Y - my) < 0.9, PAL["red"], 2, outline=False)
    elif head == "head_sword":
        ln = size * 0.42
        th = max(1.0, size * 0.06)
        pts = [(mx - 1, my - th), (mx + ln, my - 0.2), (mx + ln, my + 0.3), (mx - 1, my + th)]
        m = poly_mask(X, Y, pts)
        lay.paint(m, PAL["steel"], 4)
        lay.paint(m & (Y < my - th * 0.2), PAL["steel"], 5, outline=False)
    elif head == "head_lure":
        x0, y0, x1, y1 = anc["box"]
        tx = x0 + (x1 - x0) * 0.72
        ty = min(yy for xx, yy in anc["top"] if abs(xx - tx) < 2) if anc["top"] else y0
        sway = math.sin(frame * 1.3) * 1.0
        bx, by = mx + size * 0.18, ty - size * 0.28 + sway
        d = np.full(X.shape, 99.0)
        prev = (tx, ty + 1)
        for u in np.linspace(0.1, 1.0, 8):
            px = tx + (bx - tx) * u
            py = ty + (by - ty) * u - math.sin(u * math.pi) * size * 0.12
            d = np.minimum(d, seg_dist(X, Y, prev[0], prev[1], px, py))
            prev = (px, py)
        lay.paint(d < max(0.55, size * 0.025), PAL["abyss"], 3)
        rb = max(1.4, size * 0.06)
        bulb = np.hypot(X - bx, Y - by) <= rb
        lay.paint(bulb, PAL["glow"], 5)
        lay.paint(np.hypot(X - bx + rb * 0.3, Y - by + rb * 0.3) < rb * 0.5, PAL["white"], 6, outline=False)
        lure = [round(bx, 1), round(by, 1)]
    part = lay.to_image()
    out = img.copy()
    out.alpha_composite(part)
    return out, lure


def tail_part(name, anc, size, frame, rmp):
    w, h = anc["mask"].shape[1], anc["mask"].shape[0]
    X, Y = np.meshgrid(np.arange(w) + 0.5, np.arange(h) + 0.5)
    lay = Layer(w, h)
    rx, ry = anc["rear"]
    wag = math.sin(frame / 4 * math.tau) * size * 0.05 if frame < 4 else 0.0
    if name == "tail_fork":
        ln = size * 0.28
        for s in (-1, 1):
            pts = [(rx + 1.5, ry), (rx - ln, ry + s * ln * 0.75 + wag), (rx - ln * 0.55, ry + wag * 0.5)]
            lay.paint(poly_mask(X, Y, pts), rmp, 3)
    elif name == "tail_sting":
        ln = size * 0.4
        pts = []
        for u in np.linspace(0, 1, 10):
            pts.append((rx + 1 - u * ln, ry - math.sin(u * math.pi * 0.8) * ln * 0.55 + wag * u))
        d = np.full(X.shape, 99.0)
        r = np.zeros(X.shape)
        for j in range(len(pts) - 1):
            dj = seg_dist(X, Y, *pts[j], *pts[j + 1])
            rr = max(0.6, size * 0.06 * (1 - j / len(pts)))
            r = np.where(dj < d, rr, r)
            d = np.minimum(d, dj)
        lay.paint(d <= r, PAL["coral"], 3)
        tx, ty = pts[-1]
        spike = [(tx + 1, ty - 1), (tx - size * 0.1, ty + size * 0.05), (tx + 1, ty + 1.2)]
        lay.paint(poly_mask(X, Y, spike), PAL["bone"], 5)
    elif name == "tail_eel":
        ln = size * 0.6
        d = np.full(X.shape, 99.0)
        r = np.zeros(X.shape)
        prev = (rx + 1.5, ry)
        for u in np.linspace(0.05, 1, 14):
            px = rx + 1.5 - u * ln
            py = ry + math.sin(u * 6.0 - frame * 1.6) * size * 0.08 * u
            dj = seg_dist(X, Y, prev[0], prev[1], px, py)
            rr = max(0.55, size * 0.07 * (1 - u * 0.8))
            r = np.where(dj < d, rr, r)
            d = np.minimum(d, dj)
            prev = (px, py)
        lay.paint(d <= r, rmp, 3)
    return lay.to_image()


def fin_part(name, anc, size, frame):
    w, h = anc["mask"].shape[1], anc["mask"].shape[0]
    X, Y = np.meshgrid(np.arange(w) + 0.5, np.arange(h) + 0.5)
    lay = Layer(w, h)
    x0, y0, x1, y1 = anc["box"]
    top = anc["top"]
    flap = math.sin(frame / 4 * math.tau) if frame < 4 else 0.6
    if name == "fins_spiky_back" and top:
        for j in range(5):
            u = 0.25 + j * 0.12
            tx = x0 + (x1 - x0) * u
            ty = min((yy for xx, yy in top if abs(xx - tx) < 1.5), default=y0)
            ln = size * (0.16 + 0.04 * (j % 2))
            pts = [(tx - size * 0.05, ty + 1.5), (tx - ln * 0.35, ty - ln), (tx + size * 0.05, ty + 1.5)]
            lay.paint(poly_mask(X, Y, pts), PAL["coral"], 4)
    elif name == "fins_spiky_front":
        cx, cy = x0 + (x1 - x0) * 0.55, y1 - (y1 - y0) * 0.2
        for j in range(2):
            ln = size * 0.14
            bx = cx - j * size * 0.12
            pts = [(bx - size * 0.04, cy - 1), (bx - ln * 0.4, cy + ln), (bx + size * 0.04, cy - 1)]
            lay.paint(poly_mask(X, Y, pts), PAL["coral"], 3)
    elif name in ("fins_wing_back", "fins_wing_front"):
        back = name.endswith("back")
        bx = x0 + (x1 - x0) * (0.55 if back else 0.48)
        by = y0 + (y1 - y0) * (0.25 if back else 0.55)
        ln = size * (0.5 if back else 0.34)
        ang = -2.3 + flap * 0.35 if back else 2.5 - flap * 0.25
        tip = (bx + math.cos(ang) * ln, by + math.sin(ang) * ln)
        mid = (bx + math.cos(ang + 0.35) * ln * 0.7, by + math.sin(ang + 0.35) * ln * 0.7)
        pts = [(bx + 1, by), tip, mid, (bx - ln * 0.25, by + 0.5)]
        m = poly_mask(X, Y, pts)
        lay.paint(m, PAL["cyan"], 4 if back else 5, alpha=200)
        for j in range(3):
            u = 0.3 + j * 0.2
            d = seg_dist(X, Y, bx, by, bx + (tip[0] - bx) * u * 1.4, by + (tip[1] - by) * u * 1.4)
            lay.paint(m & (d < 0.45), PAL["cyan"], 2, outline=False)
    elif name in ("fins_volt_back", "fins_volt_front") and top:
        rng_ = np.random.default_rng(frame * 7 + (1 if name.endswith("back") else 2))
        n = 3 if name.endswith("back") else 2
        for j in range(n):
            u = rng_.uniform(0.2, 0.85)
            tx = x0 + (x1 - x0) * u
            ty = min((yy for xx, yy in top if abs(xx - tx) < 1.5), default=y0) if name.endswith("back") else y1 - 1
            s = -1 if name.endswith("back") else 1
            pts = [(tx, ty)]
            for q in range(3):
                pts.append((pts[-1][0] + rng_.uniform(-1.5, 1.5), pts[-1][1] + s * size * 0.08))
            d = np.full(X.shape, 99.0)
            for q in range(len(pts) - 1):
                d = np.minimum(d, seg_dist(X, Y, *pts[q], *pts[q + 1]))
            lay.paint(d < 0.55, PAL["volt"], 5, outline=False)
    return lay.to_image()


# ------------------------------------------------------------------ atlas
def render_critter_atlas(species, stage):
    base_frames, k = _render_frames(species, stage)
    size = PL.STAGE_LEN[stage] * SIZE_K
    fw0, fh0 = base_frames[0].size
    # room around the body for rostrum / lure / eel tail / wings
    pad_x, pad_y = int(size * 0.6) + 4, int(size * 0.45) + 4
    w, h = fw0 + pad_x * 2, fh0 + pad_y * 2
    w += w % 2
    h += h % 2
    seed = sum(ord(c) for c in species)
    rmp = body_ramp(base_frames[0])
    rows = {name: [] for name in PL.LAYERS}
    lure = []
    blank = Image.new("RGBA", (w, h))
    for fi, bf in enumerate(base_frames):
        canvas = blank.copy()
        canvas.alpha_composite(bf, (pad_x, pad_y))
        body = stage_look(canvas, stage, seed)
        anc = anchors(body)
        for hd in PL.HEADS:
            for sk in PL.SKINS:
                v = skin_variant(body, sk, seed)
                v, lp = head_part(v, hd, anc, size, fi)
                rows[PL.body_key(hd, sk)].append(v)
                if hd == "head_lure" and sk == "":
                    lure.append(lp)
        rows["tail"].append(blank)
        rows["fins_back"].append(blank)
        rows["fins_front"].append(blank)
        for t in ("tail_fork", "tail_sting", "tail_eel"):
            rows[t].append(tail_part(t, anc, size, fi, rmp))
        for f in ("fins_spiky_back", "fins_spiky_front", "fins_wing_back", "fins_wing_front", "fins_volt_back", "fins_volt_front"):
            rows[f].append(fin_part(f, anc, size, fi))
    n = len(base_frames)
    sheet = Image.new("RGBA", (w * n, h * len(PL.LAYERS)))
    for r, name in enumerate(PL.LAYERS):
        for c, im in enumerate(rows[name]):
            sheet.alpha_composite(im, (c * w, r * h))
    a0 = anchors(rows["body"][0])
    x0, y0, x1, y1 = a0["box"]
    cx, cy = (x0 + x1 + 1) / 2, (y0 + y1 + 1) / 2
    meta = dict(frame_w=w, frame_h=h, frames=n, swim=4, act=2, layers=PL.LAYERS, center=[round(cx, 1), round(cy, 1)],
                mouth=list(a0["mouth"]), lure=lure, lure_builtin=False, length=round(float(x1 - x0), 1),
                height=round(float(y1 - y0), 1), critter=True)
    return sheet, meta
