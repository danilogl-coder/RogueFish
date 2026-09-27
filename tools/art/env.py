"""Backgrounds (backdrop + parallax silhouettes), the water surface and plankton.

Props live in props.py and the seafloor in terrain.py."""
from __future__ import annotations

import math
from PIL import Image
from pixel import Canvas, Mat, sheet, rng, col, dither, hexc

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


# ---------------------------------------------------------------- POIs


ALL = {
    "bg_backdrop": backdrop, "bg_far": far_layer, "bg_mid": mid_layer, "bg_near": near_layer,
    "surface": surface_strip, "plankton": plankton,
}
