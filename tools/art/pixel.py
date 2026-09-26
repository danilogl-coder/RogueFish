"""Tiny pixel-art rasterizer used to generate every sprite of Rogue Fish.

Shapes are implicit (a point is inside or not), painted into a material map,
then shaded (top-left light), outlined with a darker tone of the neighbour
ramp ("selective outline") and exported as RGBA images.
"""
from __future__ import annotations

import math
import random
from PIL import Image


def hexc(h: str, a: int = 255):
    h = h.lstrip("#")
    return (int(h[0:2], 16), int(h[2:4], 16), int(h[4:6], 16), a)


# Every ramp goes from darkest (0) to lightest. Index 0 doubles as outline.
RAMPS = {
    "gold":    ["#3a1408", "#7a2a10", "#c4501a", "#ee8626", "#ffbf45", "#ffe98f"],
    "cream":   ["#5a2e1c", "#a0603a", "#e0a86a", "#f7d59a", "#fff0c8", "#ffffff"],
    "flame":   ["#3a0a14", "#7a1628", "#c42c38", "#f0583e", "#ff9a5c", "#ffd29a"],
    "neon":    ["#0c1438", "#16306e", "#1f5eb4", "#2aa0e8", "#5ee0ff", "#c8fbff"],
    "ruby":    ["#360818", "#6e1026", "#b01e34", "#e64048", "#ff7a6a", "#ffc0a8"],
    "olive":   ["#1a1a10", "#34331c", "#5a5428", "#86783a", "#b4a35a", "#dccf8c"],
    "sandy":   ["#2c1e18", "#5a3a2a", "#8e6040", "#c08e5c", "#e2bc86", "#f8e2b8"],
    "steel":   ["#10141e", "#232c40", "#3e4c66", "#62748e", "#93a6bc", "#d2dde8"],
    "shark":   ["#0e1624", "#1c2c44", "#2e4866", "#48688a", "#7094b2", "#b0cce0"],
    "white":   ["#3a3e58", "#6e7690", "#a6aec2", "#d4dae6", "#f0f4f8", "#ffffff"],
    "ink":     ["#08060e", "#14101e", "#221a30", "#342846", "#4c3c62", "#6c5a86"],
    "poison":  ["#1c0a2c", "#3c1454", "#662a84", "#9a48b4", "#cc7ee0", "#f2c4f6"],
    "lime":    ["#0e2410", "#1e4a18", "#3a7c20", "#68b030", "#a4dc4c", "#e2ff9a"],
    "kelp":    ["#0a1c18", "#12302a", "#1c4c36", "#2c6e3e", "#4c9446", "#86c05a"],
    "coral":   ["#300c26", "#5e1a3e", "#962c52", "#cc4a62", "#f07c7c", "#ffc0a8"],
    "violet":  ["#140c30", "#26185a", "#40288c", "#6444bc", "#9474e2", "#d0bcff"],
    "cyan":    ["#062030", "#0a3e52", "#107080", "#1ca8b0", "#4ee0d8", "#b8fff4"],
    "volt":    ["#2a2008", "#5c4a0c", "#a08414", "#e0c020", "#fff060", "#ffffd0"],
    "rock":    ["#0c0e1a", "#191d30", "#282e48", "#3c4462", "#58627e", "#7e89a2"],
    "sand":    ["#2a1c24", "#4e3438", "#7e5846", "#b08462", "#d8b284", "#f2dcae"],
    "pink":    ["#3a0e22", "#701c3c", "#b0325a", "#e0587a", "#ff8ea2", "#ffd0da"],
    "jelly":   ["#200a3a", "#44146a", "#7a2c9c", "#b056c8", "#e08ee6", "#ffd2fa"],
    "turtle":  ["#0e1c10", "#1c3a1c", "#2e5a26", "#4a8032", "#78aa48", "#b4d478"],
    "shell":   ["#26140e", "#4a2a18", "#7c4a24", "#b0762e", "#dca650", "#f6d690"],
    "silver":  ["#101a2a", "#22364e", "#3e5c78", "#6a8ca6", "#a8c6d8", "#eaf6ff"],
    "red":     ["#2a0610", "#5a0c1c", "#9a1628", "#d42a34", "#ff5c4c", "#ffa48a"],
    "brown":   ["#1a0e0a", "#342016", "#543422", "#7a4e30", "#a67448", "#d2a672"],
    "abyss":   ["#06040c", "#100c1c", "#1c162e", "#2a2242", "#3e3260", "#5c4c84"],
    "bone":    ["#3a3028", "#6e6050", "#a89880", "#d6c8ae", "#f0e8d6", "#ffffff"],
    "black":   ["#040308", "#0a0812", "#14101e", "#1e1a2c", "#2c263e", "#403858"],
    "water":   ["#07122a", "#0c1f3d", "#11305a", "#174374", "#1f5a8c", "#2a76a4"],
    "glow":    ["#0a3040", "#1a7080", "#40c0c0", "#80f0e0", "#c0fff0", "#ffffff"],
    "orange":  ["#3a1206", "#7a260a", "#c24a10", "#f07a1a", "#ffae3c", "#ffe08a"],
    "moss":    ["#0c1a10", "#183020", "#28502c", "#3e7236", "#62964a", "#9cc46a"],
    "navy":    ["#060a18", "#0c1428", "#142040", "#1e3058", "#2c4674", "#40628e"],
}

RAMP_RGBA = {k: [hexc(c) for c in v] for k, v in RAMPS.items()}


def col(ramp: str, idx: int, a: int = 255):
    idx = max(0, min(5, idx))
    c = RAMP_RGBA[ramp][idx]
    return (c[0], c[1], c[2], a)


class Mat:
    """A material painted into the canvas.

    ramp  : name of the colour ramp
    idx   : base index into the ramp, or a callable (x, y) -> idx
    auto  : if True the canvas applies automatic top-left shading
    group : pixels of the same group shade together (edges between different
            groups count as edges)
    alpha : opacity
    outline: whether this material produces an outline around itself
    """

    __slots__ = ("ramp", "idx", "auto", "group", "alpha", "outline", "hl", "emissive")

    def __init__(self, ramp, idx=3, auto=True, group=None, alpha=255, outline=True, hl=True, emissive=False):
        self.ramp = ramp
        self.idx = idx
        self.auto = auto
        self.group = group if group is not None else ramp
        self.alpha = alpha
        self.outline = outline
        self.hl = hl
        self.emissive = emissive


class Canvas:
    def __init__(self, w: int, h: int):
        self.w = w
        self.h = h
        self.mat = [[None] * w for _ in range(h)]
        self.over = [[None] * w for _ in range(h)]  # explicit RGBA overrides

    # ------------------------------------------------------------------ paint
    def paint_fn(self, inside, mat, bbox=None, warp=None, erase=False):
        """inside(sx, sy) -> bool | Mat.  Mat returned overrides mat."""
        x0, y0, x1, y1 = bbox if bbox else (0, 0, self.w, self.h)
        x0 = max(0, int(math.floor(x0)) - 3)
        y0 = max(0, int(math.floor(y0)) - 3)
        x1 = min(self.w, int(math.ceil(x1)) + 3)
        y1 = min(self.h, int(math.ceil(y1)) + 3)
        for y in range(y0, y1):
            row = self.mat[y]
            orow = self.over[y]
            for x in range(x0, x1):
                sx, sy = x + 0.5, y + 0.5
                if warp:
                    sx, sy = warp(sx, sy)
                r = inside(sx, sy)
                if r:
                    if erase:
                        row[x] = None
                        orow[x] = None
                    else:
                        row[x] = r if isinstance(r, Mat) else mat
                        orow[x] = None

    def ellipse(self, cx, cy, rx, ry, mat, warp=None, erase=False):
        def f(x, y):
            return ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2 <= 1.0
        self.paint_fn(f, mat, (cx - rx - 4, cy - ry - 4, cx + rx + 4, cy + ry + 4) if not warp else None, warp, erase)

    def circle(self, cx, cy, r, mat, warp=None, erase=False):
        self.ellipse(cx, cy, r, r, mat, warp, erase)

    def rect(self, x, y, w, h, mat, warp=None, erase=False):
        def f(px, py):
            return x <= px < x + w and y <= py < y + h
        self.paint_fn(f, mat, (x, y, x + w, y + h) if not warp else None, warp, erase)

    def poly(self, pts, mat, warp=None, erase=False):
        xs = [p[0] for p in pts]
        ys = [p[1] for p in pts]

        def f(px, py):
            return point_in_poly(px, py, pts)
        self.paint_fn(f, mat, (min(xs), min(ys), max(xs), max(ys)) if not warp else None, warp, erase)

    def line(self, x0, y0, x1, y1, mat, width=1.0, warp=None, erase=False):
        r = width / 2.0

        def f(px, py):
            return seg_dist(px, py, x0, y0, x1, y1) <= r
        self.paint_fn(f, mat, (min(x0, x1) - r, min(y0, y1) - r, max(x0, x1) + r, max(y0, y1) + r) if not warp else None, warp, erase)

    def curve(self, pts, mat, width=1.0, warp=None, erase=False, taper=None):
        """Poly-line with optional taper(t)->width multiplier."""
        n = len(pts) - 1
        for i in range(n):
            a, b = pts[i], pts[i + 1]
            wmul = taper(i / max(1, n)) if taper else 1.0
            self.line(a[0], a[1], b[0], b[1], mat, width * wmul, warp, erase)

    def pixel(self, x, y, rgba):
        x, y = int(x), int(y)
        if 0 <= x < self.w and 0 <= y < self.h:
            self.over[y][x] = rgba
            if self.mat[y][x] is None:
                self.mat[y][x] = MAT_OVERRIDE

    def get(self, x, y):
        if 0 <= x < self.w and 0 <= y < self.h:
            return self.mat[y][x]
        return None

    # ----------------------------------------------------------------- render
    def render(self, outline=True, outline_color=None, light=(-1, -1), shade=True, dark_outline_alpha=255):
        img = Image.new("RGBA", (self.w, self.h), (0, 0, 0, 0))
        px = img.load()
        lx, ly = light
        for y in range(self.h):
            for x in range(self.w):
                m = self.mat[y][x]
                if m is None:
                    continue
                o = self.over[y][x]
                if o is not None:
                    px[x, y] = o
                    continue
                idx = m.idx(x, y) if callable(m.idx) else m.idx
                if m.auto and shade:
                    g = m.group

                    def same(dx, dy):
                        n = self.get(x + dx, y + dy)
                        return n is not None and n is not MAT_OVERRIDE and n.group == g
                    if not same(lx, ly) and m.hl:
                        idx += 1
                    elif not same(-lx, -ly):
                        idx -= 1
                    elif not same(-2 * lx, -2 * ly) and not same(-lx * 2, 0):
                        idx -= 1
                px[x, y] = col(m.ramp, idx, m.alpha)
        if outline:
            out = img.copy()
            opx = out.load()
            for y in range(self.h):
                for x in range(self.w):
                    if self.mat[y][x] is not None:
                        continue
                    best = None
                    for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                        n = self.get(x + dx, y + dy)
                        if n is not None and n is not MAT_OVERRIDE and n.outline:
                            best = n
                            break
                    if best is not None:
                        if outline_color:
                            opx[x, y] = outline_color
                        else:
                            c = col(best.ramp, 0, max(best.alpha, dark_outline_alpha) if best.alpha < 255 else 255)
                            opx[x, y] = c
            img = out
        return img


MAT_OVERRIDE = Mat("black", 0, auto=False, group="__override__", outline=False)


def point_in_poly(x, y, pts):
    inside = False
    n = len(pts)
    j = n - 1
    for i in range(n):
        xi, yi = pts[i]
        xj, yj = pts[j]
        if ((yi > y) != (yj > y)) and (x < (xj - xi) * (y - yi) / (yj - yi + 1e-9) + xi):
            inside = not inside
        j = i
    return inside


def seg_dist(px, py, x0, y0, x1, y1):
    dx, dy = x1 - x0, y1 - y0
    l2 = dx * dx + dy * dy
    if l2 == 0:
        return math.hypot(px - x0, py - y0)
    t = max(0.0, min(1.0, ((px - x0) * dx + (py - y0) * dy) / l2))
    return math.hypot(px - (x0 + t * dx), py - (y0 + t * dy))


def sheet(frames, cols=None):
    """Pack same-size frames horizontally (or in a grid when cols is given)."""
    w, h = frames[0].size
    if cols is None:
        cols = len(frames)
    rows = (len(frames) + cols - 1) // cols
    out = Image.new("RGBA", (w * cols, h * rows), (0, 0, 0, 0))
    for i, f in enumerate(frames):
        out.paste(f, ((i % cols) * w, (i // cols) * h))
    return out


def stack_rows(rows):
    w = max(r.size[0] for r in rows)
    h = sum(r.size[1] for r in rows)
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    y = 0
    for r in rows:
        out.paste(r, (0, y))
        y += r.size[1]
    return out


def dither(x, y, level):
    """Ordered 2x2 bayer dithering; level in [0,1]."""
    m = ((0, 2), (3, 1))
    return (m[y % 2][x % 2] + 0.5) / 4.0 < level


def overlay(dst: Image.Image, src: Image.Image, x=0, y=0):
    dst.alpha_composite(src, (int(x), int(y)))
    return dst


def scale(img, s):
    return img.resize((img.size[0] * s, img.size[1] * s), Image.NEAREST)


def rng(seed):
    return random.Random(seed)
