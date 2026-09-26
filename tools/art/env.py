"""Backgrounds, seabed, decorations, plants, hideouts and points of interest."""
from __future__ import annotations

import math
from PIL import Image
from pixel import Canvas, Mat, sheet, rng, col, dither, hexc, point_in_poly, RAMP_RGBA

W, H = 640, 360


def A(ramp, idx=3, group=None, alpha=255, hl=True):
    return Mat(ramp, idx, auto=True, group=group or ramp, alpha=alpha, hl=hl)


def F(ramp, idx=3, group=None, alpha=255, outline=True):
    return Mat(ramp, idx, auto=False, group=group or ramp, alpha=alpha, outline=outline)


def lerp(a, b, t):
    return tuple(int(a[i] + (b[i] - a[i]) * t) for i in range(4))


# ------------------------------------------------------------ backdrops
def backdrop():
    """Screen-space water gradient with god rays. Tinted by depth in-game."""
    img = Image.new("RGBA", (W, H))
    px = img.load()
    stops = [hexc("#2a86b0"), hexc("#1d6694"), hexc("#154c78"), hexc("#10375e")]
    for y in range(H):
        t = y / (H - 1) * (len(stops) - 1)
        i = min(len(stops) - 2, int(t))
        base = stops[i]
        nxt = stops[i + 1]
        f = t - i
        for x in range(W):
            # band quantised + dithered edges for a pixel-art gradient
            ff = 1.0 if f > 0.66 else (0.5 if f > 0.33 else 0.0)
            if 0.28 < f < 0.38 or 0.62 < f < 0.72:
                ff = 0.5 if dither(x, y, 0.5) else ff
            c = lerp(base, nxt, ff)
            px[x, y] = c
    # god rays
    r = rng(7)
    rays = [(r.uniform(0, W), r.uniform(18, 46), r.uniform(0.25, 0.4)) for _ in range(7)]
    for y in range(H):
        fade = max(0.0, 1.0 - y / (H * 0.95))
        for x0, wdt, slope in rays:
            cx = x0 + y * slope
            for x in range(int(cx - wdt / 2), int(cx + wdt / 2)):
                xx = x % W
                d = abs(x - cx) / (wdt / 2)
                a = (1.0 - d) * fade * 0.16
                if a <= 0.02:
                    continue
                if not dither(xx, y, min(1.0, a * 6)):
                    continue
                c = px[xx, y]
                px[xx, y] = (min(255, c[0] + 14), min(255, c[1] + 20), min(255, c[2] + 22), 255)
    return img


def silhouette_layer(seed, w, h, color, peaks, rough, base_h, kelp=0, kelp_color=None, arches=0):
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    px = img.load()
    r = rng(seed)
    # tileable height function from sines
    comps = [(r.uniform(0.5, 1.0) * base_h * 0.5, k, r.uniform(0, math.tau)) for k in peaks]
    hh = []
    for x in range(w):
        v = base_h
        for amp, k, ph in comps:
            v += amp * math.sin(x / w * math.tau * k + ph)
        v += (r.random() - 0.5) * rough
        hh.append(v)
    for x in range(w):
        top = int(h - hh[x])
        for y in range(max(0, top), h):
            px[x, y] = color
    # kelp silhouettes
    kc = kelp_color or color
    for _ in range(kelp):
        x0 = r.uniform(0, w)
        ln = r.uniform(h * 0.35, h * 0.85)
        ph = r.uniform(0, math.tau)
        for yy in range(int(ln)):
            y = h - yy
            x = x0 + math.sin(yy * 0.05 + ph) * 5
            for dx in range(-1, 2):
                px[int(x + dx) % w, max(0, min(h - 1, y))] = kc
            if yy % 9 == 0 and yy > 10:
                for k in range(5):
                    px[int(x + 2 + k) % w, max(0, min(h - 1, y - k // 2))] = kc
    return img


def far_layer():
    return silhouette_layer(3, W, 200, hexc("#133f66"), [1, 2, 5, 9], 1.5, 70)


def mid_layer():
    return silhouette_layer(11, W, 220, hexc("#0f3152"), [1, 3, 4, 8], 2.0, 46, kelp=16, kelp_color=hexc("#0f3456"))


def near_layer():
    return silhouette_layer(23, W, 140, hexc("#0a2440"), [2, 3, 6, 11], 2.5, 34, kelp=8, kelp_color=hexc("#0b2a47"))


# --------------------------------------------------------------- seabed
def seabed_strip():
    w, h = 320, 96
    c = Canvas(w, h)
    r = rng(5)
    comps = [(r.uniform(0.8, 2.0), k, r.uniform(0, math.tau)) for k in (1, 2, 3, 7)]

    def surf(x):
        v = 14
        for amp, k, ph in comps:
            v += amp * math.sin(x / w * math.tau * k + ph)
        return v

    def sand(x, y):
        s = surf(x)
        if y < s:
            return False
        d = y - s
        n = (int(x) * 13 + int(y) * 7) % 11
        if d < 2:
            return F("sand", 5)
        if d < 5:
            return F("sand", 4 if n else 3)
        if d < 14:
            return F("sand", 3 if n > 1 else 2)
        if d < 30:
            return F("sand", 2 if n > 1 else 1)
        return F("sand", 1 if n > 2 else 0)
    c.paint_fn(sand, None)
    img = c.render(outline=False)
    # pebbles
    px = img.load()
    for _ in range(90):
        x = r.randrange(w)
        y = int(surf(x) + r.uniform(4, 40))
        if 0 <= y < h - 1:
            k = r.choice(["rock", "sand", "shell"])
            px[x, y] = col(k, 4)
            px[(x + 1) % w, y] = col(k, 3)
            if y + 1 < h:
                px[x, y + 1] = col(k, 2)
    return img


def surface_strip():
    frames = []
    for i in range(4):
        w, h = 64, 20
        img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
        px = img.load()
        for x in range(w):
            wave = 4 + 2.0 * math.sin((x / w) * math.tau * 2 + i * math.pi / 2) + math.sin((x / w) * math.tau * 3 - i * math.pi / 2)
            for y in range(h):
                if y < wave:
                    px[x, y] = hexc("#8ee8f0", 255)
                elif y < wave + 1.5:
                    px[x, y] = hexc("#d8fff8", 255)
                elif y < wave + 5:
                    if dither(x, y, 0.5):
                        px[x, y] = hexc("#5cc8e0", 170)
                elif y < wave + 10:
                    if dither(x, y, 0.25):
                        px[x, y] = hexc("#48b0d0", 110)
        frames.append(img)
    return sheet(frames)


# ---------------------------------------------------------- decorations
def coral_branch(seed=1, ramp="coral"):
    c = Canvas(30, 34)
    r = rng(seed)

    def branch(x, y, ang, ln, wd, depth):
        x2 = x + math.cos(ang) * ln
        y2 = y + math.sin(ang) * ln
        c.line(x, y, x2, y2, A(ramp, 3, "c"), wd)
        if depth > 0:
            for s in (-1, 1):
                branch(x2, y2, ang + s * r.uniform(0.3, 0.6), ln * 0.72, max(1.6, wd * 0.72), depth - 1)
        else:
            c.circle(x2, y2, wd * 0.7, F(ramp, 5, "tip"))
    branch(15, 33, -math.pi / 2, 10, 4.0, 3)
    return c.render()


def coral_fan(seed=2):
    c = Canvas(34, 28)
    r = rng(seed)

    def fan(x, y):
        dx, dy = (x - 17) / 15, (y - 26) / 24
        if dy > 0 or dx * dx + dy * dy > 1:
            return False
        a = math.atan2(y - 26, x - 17)
        rib = int(a * 9) % 2 == 0
        hole = (int(x) * 7 + int(y) * 3) % 5 == 0
        if hole and not rib:
            return False
        return F("violet", 4 if rib else 3, "fan")
    c.paint_fn(fan, None)
    c.line(17, 27, 17, 18, A("violet", 2, "st"), 2)
    return c.render()


def coral_brain():
    c = Canvas(24, 14)

    def f(x, y):
        dx, dy = (x - 12) / 11, (y - 13) / 11
        if dy > 0 or dx * dx + dy * dy > 1:
            return False
        groove = int(math.sin(x * 0.9) * 2 + y) % 3 == 0
        return F("lime", 2 if groove else (4 if dy < -0.7 else 3), "b")
    c.paint_fn(f, None)
    return c.render()


def anemone():
    frames = []
    for i in range(4):
        c = Canvas(20, 20)
        for k in range(9):
            a = -math.pi / 2 + (k - 4) * 0.28
            sway = math.sin(i * math.pi / 2 + k) * 0.18
            pts = [(10, 16)]
            for j in range(1, 5):
                pts.append((10 + math.cos(a + sway * j) * j * 3, 16 + math.sin(a + sway * j) * j * 3))
            c.curve(pts, F("pink", 4 if k % 2 else 3, "t"), 1.8)
        c.ellipse(10, 17, 6, 3, A("pink", 2, "base"))
        frames.append(c.render())
    return sheet(frames)


def seagrass():
    frames = []
    for i in range(4):
        c = Canvas(18, 18)
        for k in range(5):
            x0 = 4 + k * 2.5
            ph = i * math.pi / 2 + k
            pts = [(x0 + math.sin(ph + j * 0.6) * j * 0.35, 17 - j * 2.6) for j in range(6 - (k % 2))]
            c.curve(pts, F("kelp", 4 if k % 2 else 3, "g", outline=False), 1.3)
        frames.append(c.render(outline=False))
    return sheet(frames)


def rock(w, h, seed):
    c = Canvas(w, h)
    r = rng(seed)
    pts = []
    n = 9
    for k in range(n + 1):
        a = math.pi + k / n * math.pi
        rr = r.uniform(0.8, 1.0)
        pts.append((w / 2 + math.cos(a) * (w / 2 - 1) * rr, h - 1 + math.sin(a) * (h - 2) * rr))
    c.poly(pts, A("rock", 3, "r"))
    for _ in range(int(w * h / 60)):
        x, y = r.uniform(3, w - 3), r.uniform(h * 0.4, h - 2)
        if c.get(int(x), int(y)):
            c.pixel(x, y, col("rock", 2))
    moss_y = {}
    img = c.render()
    px = img.load()
    for x in range(w):
        for y in range(h):
            if px[x, y][3] and (y == 0 or px[x, y - 1][3] == 0 or (y > 0 and px[x, y - 1] == col("rock", 0))):
                if px[x, y] != col("rock", 0) and r.random() < 0.7:
                    px[x, y] = col("moss", 4)
                    if y + 1 < h and r.random() < 0.5 and px[x, y + 1][3]:
                        px[x, y + 1] = col("moss", 3)
                break
    return img


def starfish():
    c = Canvas(12, 12)
    pts = []
    for k in range(10):
        a = -math.pi / 2 + k * math.pi / 5
        rr = 5.5 if k % 2 == 0 else 2.2
        pts.append((6 + math.cos(a) * rr, 6.5 + math.sin(a) * rr))
    c.poly(pts, A("orange", 3, "s"))
    return c.render()


def shell_deco():
    c = Canvas(10, 8)
    c.ellipse(5, 6, 4.5, 4.5, A("shell", 4, "s"))
    c.rect(0, 7, 10, 2, F("shell", 0), erase=True)
    for k in range(4):
        c.line(5, 7, 1.5 + k * 2.2, 3, F("shell", 2, "l", outline=False), 0.7)
    return c.render()


def kelp_parts():
    """Frame 0-1 leaf segments, 2 bulb top, 3 stem base."""
    frames = []
    for i in range(2):
        c = Canvas(12, 10)
        c.line(6, 0, 6, 10, F("kelp", 3, "stem"), 1.6)
        s = 1 if i == 0 else -1
        c.poly([(6, 6), (6 + s * 6, 1), (6 + s * 5, 5), (6, 9)], A("kelp", 4, "leaf"))
        frames.append(c.render())
    c = Canvas(12, 10)
    c.line(6, 4, 6, 10, F("kelp", 3, "stem"), 1.6)
    c.ellipse(6, 4, 3, 3.5, A("olive", 4, "bulb"))
    frames.append(c.render())
    c = Canvas(12, 10)
    c.poly([(2, 10), (6, 0), (10, 10)], A("kelp", 2, "hold"))
    frames.append(c.render())
    return sheet(frames)


def plankton():
    frames = []
    for i in range(4):
        c = Canvas(6, 6)
        c.circle(3, 3, 1.6 + (0.5 if i % 2 else 0), F("lime", 4, "p", outline=False))
        img = c.render(outline=False)
        img.putpixel((3, 3), col("lime", 5))
        frames.append(img)
    return sheet(frames)


# -------------------------------------------------------------- hideouts
def cave_back():
    c = Canvas(128, 72)

    def f(x, y):
        dx, dy = (x - 64) / 58, (y - 72) / 60
        return dy <= 0 and dx * dx + dy * dy <= 1
    c.paint_fn(f, F("black", 2, "in", outline=False))
    img = c.render(outline=False)
    px = img.load()
    for y in range(72):
        for x in range(128):
            p = px[x, y]
            if p[3]:
                dx, dy = (x - 64) / 58, (y - 72) / 60
                d = dx * dx + dy * dy
                if d > 0.7 and dither(x, y, (d - 0.7) / 0.3):
                    px[x, y] = col("black", 3)
    return img


def cave_front():
    c = Canvas(128, 72)
    r = rng(17)

    def arch(x, y):
        dx, dy = (x - 64) / 62, (y - 72) / 70
        dxi, dyi = (x - 64) / 44, (y - 72) / 48
        outer = dy <= 0 and dx * dx + dy * dy <= 1
        inner = dyi <= 0 and dxi * dxi + dyi * dyi <= 1
        return outer and not inner
    c.paint_fn(arch, A("rock", 3, "arch"))
    for _ in range(40):
        a = r.uniform(math.pi, math.tau)
        rr = r.uniform(48, 60)
        x, y = 64 + math.cos(a) * rr * 1.3, 72 + math.sin(a) * rr
        c.circle(x, y, r.uniform(2, 5), A("rock", r.choice([2, 3, 4]), "boulder%d" % r.randrange(3)))
    img = c.render()
    px = img.load()
    for x in range(128):
        for y in range(72):
            if px[x, y][3]:
                if r.random() < 0.8:
                    px[x, y] = col("moss", 4)
                    if y + 1 < 72 and px[x, y + 1][3]:
                        px[x, y + 1] = col("moss", 3)
                break
    return img


def thicket():
    frames = []
    for i in range(2):
        c = Canvas(84, 64)
        r = rng(33)
        for k in range(26):
            x0 = r.uniform(4, 80)
            ln = r.uniform(26, 60)
            ph = r.uniform(0, math.tau)
            ramp_idx = r.choice([2, 3, 4])
            pts = []
            for j in range(9):
                yy = 63 - j * ln / 8
                pts.append((x0 + math.sin(ph + j * 0.5 + i * 0.6) * j * 0.6, yy))
            c.curve(pts, F("kelp", ramp_idx, "k%d" % ramp_idx), 3.2 - (k % 3) * 0.6)
            for j in range(2, 8, 2):
                x, y = pts[j]
                s = 1 if (j // 2 + k) % 2 else -1
                c.poly([(x, y), (x + s * 7, y - 4), (x + s * 4, y + 1)], F("kelp", min(5, ramp_idx + 1), "l"))
        frames.append(c.render())
    return sheet(frames)


def eel_rock():
    c = Canvas(52, 36)
    pts = [(1, 35), (4, 16), (12, 5), (26, 1), (40, 5), (49, 17), (51, 35)]
    c.poly(pts, A("rock", 3, "r"))
    c.ellipse(28, 22, 9, 7, F("black", 1, "hole", outline=False))
    img = c.render()
    return img


# ---------------------------------------------------------------- POIs
def chest():
    frames = []
    for i in range(2):
        c = Canvas(28, 24)
        # base
        c.rect(3, 12, 22, 11, A("brown", 3, "wood"))
        c.rect(3, 15, 22, 2, F("volt", 3, "band"))
        c.rect(12, 12, 4, 11, F("volt", 3, "band2"))
        if i == 0:
            c.poly([(3, 12), (4, 6), (8, 3), (20, 3), (24, 6), (25, 12)], A("brown", 4, "lid"))
            c.rect(12, 3, 4, 9, F("volt", 4, "band3"))
            c.rect(13, 10, 2, 4, F("gold", 5, "lock"))
        else:
            c.poly([(3, 12), (2, 4), (6, 1), (8, 6)], A("brown", 2, "lid"))
            c.ellipse(14, 12, 9, 3, F("volt", 5, "gold"))
            for k in range(5):
                c.pixel(8 + k * 3, 10 - (k % 2), col("gold", 5))
        frames.append(c.render())
    return sheet(frames)


def clam():
    frames = []
    for i in range(3):
        c = Canvas(36, 28)
        op = [0.0, 0.35, 0.75][i]
        cx, cy = 18, 20

        def lower(x, y):
            dx, dy = (x - cx) / 16, (y - cy) / 7
            return dy >= 0 and dx * dx + dy * dy <= 1
        c.paint_fn(lower, A("violet", 3, "low"))
        if op > 0:
            c.ellipse(cx, cy, 13, 2.5 + op * 3, F("pink", 4, "flesh"))
            if op > 0.5:
                c.circle(cx, cy - 2, 3.5, A("white", 4, "pearl"))
        ang = op * 0.9
        hx, hy = cx - 16, cy

        def upper(x, y):
            dx, dy = x - hx, y - hy
            ca, sa = math.cos(ang), math.sin(ang)
            sx, sy = hx + dx * ca - dy * sa, hy + dx * sa + dy * ca
            ddx, ddy = (sx - cx) / 16, (sy - cy) / 11
            if ddy > 0 or ddx * ddx + ddy * ddy > 1:
                return False
            rib = int((sx - cx) * 0.6 + 50) % 3 == 0
            return F("violet", 3 if rib else 4, "up")
        c.paint_fn(upper, None)
        frames.append(c.render())
    return sheet(frames)


def vent():
    c = Canvas(32, 26)
    c.poly([(2, 25), (9, 8), (13, 4), (19, 4), (23, 8), (30, 25)], A("rock", 3, "v"))
    c.ellipse(16, 5, 4, 2, F("orange", 4, "lava"))
    c.line(16, 7, 13, 18, F("orange", 3, "crack", outline=False), 1.2)
    c.line(16, 7, 20, 16, F("red", 4, "crack2", outline=False), 1.0)
    return c.render()


def surface_light():
    pass


ALL = {
    "bg_backdrop": backdrop, "bg_far": far_layer, "bg_mid": mid_layer, "bg_near": near_layer,
    "seabed": seabed_strip, "surface": surface_strip,
    "coral_branch": lambda: coral_branch(1, "coral"), "coral_branch2": lambda: coral_branch(4, "orange"),
    "coral_fan": coral_fan, "coral_brain": coral_brain, "anemone": anemone, "seagrass": seagrass,
    "rock_big": lambda: rock(44, 24, 3), "rock_small": lambda: rock(22, 13, 8), "rock_mid": lambda: rock(32, 18, 12),
    "starfish": starfish, "shell": shell_deco, "kelp": kelp_parts, "plankton": plankton,
    "cave_back": cave_back, "cave_front": cave_front, "thicket": thicket, "eel_rock": eel_rock,
    "chest": chest, "clam": clam, "vent": vent,
}
