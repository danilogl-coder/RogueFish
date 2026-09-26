"""Pickups, projectiles and effects."""
from __future__ import annotations

import math
from PIL import Image
from pixel import Canvas, Mat, sheet, rng, col, dither, hexc


def A(ramp, idx=3, group=None, alpha=255):
    return Mat(ramp, idx, auto=True, group=group or ramp, alpha=alpha)


def F(ramp, idx=3, group=None, alpha=255, outline=True):
    return Mat(ramp, idx, auto=False, group=group or ramp, alpha=alpha, outline=outline)


def gem(size, ramp):
    frames = []
    for i in range(4):
        c = Canvas(size, size)
        h = size / 2
        c.poly([(h, 0.5), (size - 0.5, h), (h, size - 0.5), (0.5, h)], A(ramp, 3, "g"))
        img = c.render()
        px = img.load()
        sp = [(int(h - 1), int(h - 1)), (int(h), int(h - 2)), (int(h - 2), int(h)), (int(h - 1), int(h - 1))][i]
        px[sp] = col(ramp, 5)
        frames.append(img)
    return sheet(frames)


def pearl():
    frames = []
    for i in range(4):
        c = Canvas(9, 9)
        c.circle(4.5, 4.5, 3.6, A("white", 4, "p"))
        img = c.render()
        img.putpixel((3, 3), (255, 255, 255, 255))
        if i == 1:
            img.putpixel((6, 2), (255, 255, 255, 255))
        frames.append(img)
    return sheet(frames)


def food():
    c = Canvas(12, 10)
    c.ellipse(6, 5.5, 4.5, 3.5, A("red", 3, "meat"))
    c.ellipse(5, 4.5, 2, 1.4, F("pink", 5, "fat", outline=False))
    c.line(9, 6, 11.5, 8.5, F("bone", 4, "bone"), 1.6)
    return c.render()


def heart(size=9):
    c = Canvas(size, size)
    s = size / 9
    c.circle(2.6 * s, 3.2 * s, 2.3 * s, A("red", 4, "h"))
    c.circle(6.4 * s, 3.2 * s, 2.3 * s, A("red", 4, "h"))
    c.poly([(0.4 * s, 3.8 * s), (4.5 * s, 8.4 * s), (8.6 * s, 3.8 * s)], A("red", 4, "h"))
    return c.render()


def magnet_shell():
    frames = []
    for i in range(4):
        c = Canvas(14, 14)
        c.circle(7, 7, 6, A("cyan", 3, "s"))
        for k in range(5):
            a = -math.pi * 0.9 + k * 0.45
            c.line(7, 11, 7 + math.cos(a) * 6, 7 + math.sin(a) * 6, F("cyan", 5 if (k + i) % 2 else 2, "r", outline=False), 0.8)
        frames.append(c.render())
    return sheet(frames)


def bubble(size):
    frames = []
    for i in range(2):
        c = Canvas(size, size)
        h = size / 2
        r = h - 0.8 - (0.4 if i else 0)

        def f(x, y):
            d = math.hypot(x - h, y - h)
            if d > r:
                return False
            if d > r - 1.2:
                return F("glow", 4, "ring", alpha=255, outline=False)
            return F("cyan", 3, "in", alpha=110, outline=False)
        c.paint_fn(f, None)
        img = c.render(outline=False)
        img.putpixel((int(h - r * 0.45), int(h - r * 0.45)), (255, 255, 255, 255))
        frames.append(img)
    return sheet(frames)


def torpedo():
    frames = []
    for i in range(2):
        c = Canvas(16, 12)
        c.ellipse(9, 6, 6, 4, A("glow", 3, "b", alpha=240))
        for k in range(3):
            c.circle(3 - k + (i * 0.5), 6 + (k - 1) * 2, 1.2, F("white", 4, "t", alpha=180, outline=False))
        img = c.render()
        img.putpixel((7, 4), (255, 255, 255, 255))
        frames.append(img)
    return sheet(frames)


def spine(ramp="bone", w=10, h=4):
    c = Canvas(w, h)
    c.poly([(0.5, h / 2 - 1), (w - 0.5, h / 2), (0.5, h / 2 + 1)], A(ramp, 4, "s"))
    return c.render()


def ink_ball():
    c = Canvas(9, 9)
    c.circle(4.5, 4.5, 3.4, A("ink", 3, "i"))
    img = c.render()
    img.putpixel((3, 3), col("ink", 5))
    return img


def cloud(ramp, size=32, frames_n=4, seed=3):
    frames = []
    r = rng(seed)
    blobs = [(r.uniform(-0.3, 0.3), r.uniform(-0.25, 0.25), r.uniform(0.28, 0.42)) for _ in range(7)]
    for i in range(frames_n):
        c = Canvas(size, size)
        grow = 0.85 + 0.15 * math.sin(i / frames_n * math.tau)
        for k, (bx, by, br) in enumerate(blobs):
            ph = i / frames_n * math.tau + k
            x = size / 2 + (bx + math.cos(ph) * 0.03) * size
            y = size / 2 + (by + math.sin(ph) * 0.03) * size
            c.circle(x, y, br * size / 2 * grow * 1.3, A(ramp, 3, "c", alpha=200))
        frames.append(c.render(outline=False))
    return sheet(frames)


def whirlpool():
    frames = []
    for i in range(4):
        size = 48
        img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        px = img.load()
        for y in range(size):
            for x in range(size):
                dx, dy = x - size / 2 + 0.5, y - size / 2 + 0.5
                d = math.hypot(dx, dy)
                if d > size / 2 - 1:
                    continue
                a = math.atan2(dy, dx)
                arm = math.sin(a * 3 + d * 0.35 - i * math.pi / 2)
                if arm > 0.55:
                    fade = 1.0 - d / (size / 2)
                    idx = 5 if arm > 0.9 else (4 if fade > 0.4 else 3)
                    px[x, y] = col("cyan", idx, int(90 + 150 * fade))
        frames.append(img)
    return sheet(frames)


def explosion(ramp_a="orange", ramp_b="volt", size=32):
    frames = []
    for i in range(6):
        c = Canvas(size, size)
        t = (i + 1) / 6
        r = size / 2 * (0.3 + 0.7 * t)
        if i < 5:
            c.circle(size / 2, size / 2, r, F(ramp_a, 4 - i // 2, "o", outline=False))
            if i < 3:
                c.circle(size / 2, size / 2, r * 0.6, F(ramp_b, 5, "i", outline=False))
        if i >= 2:
            c.circle(size / 2, size / 2, r * (0.5 + 0.1 * i), F("black", 0, "x"), erase=True)
        rr = rng(i)
        for _ in range(6):
            a = rr.uniform(0, math.tau)
            d = r * rr.uniform(0.8, 1.1)
            c.circle(size / 2 + math.cos(a) * d, size / 2 + math.sin(a) * d, max(0.6, 2.5 - i * 0.4), F(ramp_a, 3, "d", outline=False))
        frames.append(c.render(outline=False))
    return sheet(frames)


def hit_spark():
    frames = []
    for i in range(4):
        c = Canvas(14, 14)
        ln = 2 + i * 1.6
        for k in range(4):
            a = k * math.pi / 2 + math.pi / 4
            c.line(7 + math.cos(a) * (ln - 3), 7 + math.sin(a) * (ln - 3), 7 + math.cos(a) * ln, 7 + math.sin(a) * ln,
                   F("white", 5 if i < 2 else 3, "s", outline=False), 1.4)
        if i < 2:
            c.circle(7, 7, 2.5 - i, F("volt", 5, "c", outline=False))
        frames.append(c.render(outline=False))
    return sheet(frames)


def light_orb():
    frames = []
    for i in range(2):
        c = Canvas(10, 10)
        c.circle(5, 5, 4 - i * 0.4, F("glow", 3, "o", alpha=200, outline=False))
        c.circle(5, 5, 2.2, F("glow", 5, "c", outline=False))
        frames.append(c.render(outline=False))
    return sheet(frames)


def volt_ball():
    frames = []
    for i in range(2):
        c = Canvas(12, 12)
        c.circle(6, 6, 4.5, F("volt", 3, "o", alpha=210, outline=False))
        c.circle(6, 6, 2.5, F("white", 5, "c", outline=False))
        img = c.render(outline=False)
        r = rng(i)
        for _ in range(4):
            a = r.uniform(0, math.tau)
            img.putpixel((int(6 + math.cos(a) * 5.4), int(6 + math.sin(a) * 5.4)), col("volt", 5))
        frames.append(img)
    return sheet(frames)


def particles():
    """0 bubble small,1 bubble tiny,2 chunk red,3 chunk white,4 spark,5 ink,6 poison,7 glow"""
    frames = []
    specs = [("glow", 3, 1.6, True), ("glow", 4, 0.9, True), ("red", 3, 1.2, False), ("white", 4, 1.2, False),
             ("volt", 5, 1.0, False), ("ink", 3, 1.6, False), ("lime", 4, 1.4, False), ("cyan", 5, 1.2, False)]
    for ramp, idx, r, ring in specs:
        c = Canvas(6, 6)
        if ring:
            def f(x, y, r=r, ramp=ramp, idx=idx):
                d = math.hypot(x - 3, y - 3)
                if d > r + 0.6:
                    return False
                return F(ramp, idx if d > r - 0.6 else 2, "b", alpha=255 if d > r - 0.6 else 90, outline=False)
            c.paint_fn(f, None)
        else:
            c.circle(3, 3, r, F(ramp, idx, "p", outline=False))
        frames.append(c.render(outline=False))
    return sheet(frames)


def shadow():
    img = Image.new("RGBA", (24, 8), (0, 0, 0, 0))
    px = img.load()
    for y in range(8):
        for x in range(24):
            d = ((x - 11.5) / 12) ** 2 + ((y - 3.5) / 4) ** 2
            if d < 1 and dither(x, y, 0.6 - d * 0.4):
                px[x, y] = (4, 10, 24, 110)
    return img


def glow_blob():
    """Soft radial light used for additive glows (not pixel-snapped)."""
    size = 64
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    px = img.load()
    for y in range(size):
        for x in range(size):
            d = math.hypot(x - 31.5, y - 31.5) / 32
            if d < 1:
                a = (1 - d) ** 2
                px[x, y] = (255, 255, 255, int(255 * a))
    return img


def darkness_hole():
    """Radial gradient used by the depth-darkness shader (as texture)."""
    return glow_blob()


ALL = {
    "xp_small": lambda: gem(6, "lime"), "xp_mid": lambda: gem(8, "cyan"),
    "xp_big": lambda: gem(10, "poison"), "xp_huge": lambda: gem(12, "gold"),
    "pearl": pearl, "food": food, "heart": heart, "magnet": magnet_shell,
    "bubble": lambda: bubble(9), "bubble_big": lambda: bubble(14), "torpedo": torpedo,
    "spine": spine, "spine_coral": lambda: spine("coral", 12, 5), "ink_ball": ink_ball,
    "ink_cloud": lambda: cloud("ink", 32, 4, 3), "poison_cloud": lambda: cloud("lime", 32, 4, 5),
    "whirlpool": whirlpool, "explosion": explosion,
    "explosion_toxic": lambda: explosion("poison", "lime"), "hit_spark": hit_spark,
    "light_orb": light_orb, "volt_ball": volt_ball, "particles": particles, "shadow": shadow,
    "glow": glow_blob,
}
