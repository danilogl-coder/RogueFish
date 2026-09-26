"""Abyss / ecosystem environment props."""
from __future__ import annotations

import math
from pixel import Canvas, Mat, sheet, rng, col
from env import A, F


def tube_worms():
    frames = []
    for i in range(4):
        c = Canvas(18, 24)
        for k, (x, hgt) in enumerate(((4, 16), (8, 20), (12, 14), (15, 11))):
            c.line(x, 23, x + math.sin(i * 1.5 + k) * 0.6, 23 - hgt, A("white", 4, "tube%d" % k), 2.2)
            px, py = x + math.sin(i * 1.5 + k) * 0.6, 23 - hgt
            open_ = 1.0 + 0.6 * math.sin(i * math.pi / 2 + k)
            c.poly([(px - 2.5 * open_, py - 2.5), (px, py + 1), (px + 2.5 * open_, py - 2.5), (px, py - 3.5)], F("red", 4, "plume%d" % k))
        frames.append(c.render())
    return sheet(frames)


def black_smoker():
    c = Canvas(34, 64)
    r = rng(4)
    pts = [(3, 63), (8, 40), (11, 22), (13, 6), (21, 6), (23, 24), (26, 44), (31, 63)]
    c.poly(pts, A("rock", 2, "ch"))
    for _ in range(14):
        c.circle(r.uniform(8, 26), r.uniform(12, 60), r.uniform(1.5, 3), A("rock", r.choice([1, 2, 3]), "k%d" % r.randrange(3)))
    c.ellipse(17, 6, 4.5, 2, F("orange", 4, "lava"))
    c.line(17, 8, 15, 30, F("red", 4, "crack", outline=False), 1.0)
    c.line(19, 12, 22, 40, F("orange", 3, "crack2", outline=False), 1.0)
    # yellow bacterial crust
    for _ in range(10):
        c.pixel(r.uniform(6, 28), r.uniform(40, 62), col("volt", 4))
    return c.render()


def bacterial_mat():
    c = Canvas(48, 6)
    r = rng(8)

    def f(x, y):
        edge = 2 + math.sin(x * 0.7) * 1.2 + math.sin(x * 0.23) * 1.5
        if y < 6 - edge - 1:
            return False
        return F("volt" if (int(x) + int(y)) % 3 else "cream", 3 if y > 4 else 4, "m", outline=False)
    c.paint_fn(f, None)
    return c.render(outline=False)


def whale_bones():
    c = Canvas(140, 46)
    # spine
    for k in range(14):
        x = 20 + k * 7.5
        y = 38 - math.sin(k / 13 * math.pi) * 6
        c.ellipse(x, y, 3.2, 2.4, A("bone", 3, "v%d" % (k % 2)))
    # ribs
    for k in range(7):
        x = 40 + k * 10
        top = 38 - math.sin((k + 3) / 13 * math.pi) * 6
        h = 26 - abs(k - 3) * 3
        pts = [(x + math.sin(j / 6 * math.pi) * 6, top - j / 6 * h) for j in range(7)]
        c.curve(pts, A("bone", 4, "r%d" % k), 2.0)
    # skull
    c.poly([(118, 40), (124, 26), (138, 30), (138, 42)], A("bone", 3, "skull"))
    c.circle(128, 33, 2, F("black", 0, "eye", outline=False))
    # tail bones
    for k in range(4):
        c.ellipse(16 - k * 4, 40 + k * 0.5, 2 - k * 0.3, 1.6, A("bone", 3, "t"))
    return c.render()


def glow_mushroom():
    frames = []
    for i in range(2):
        c = Canvas(14, 14)
        c.line(7, 13, 7, 7, A("white", 3, "st"), 2)
        c.ellipse(7, 6, 5.5, 3.5 + i * 0.3, F("glow", 3 + i, "cap"))
        c.pixel(5, 5, col("glow", 5))
        c.pixel(9, 6, col("glow", 5))
        frames.append(c.render())
    return sheet(frames)


ALL = {
    "tube_worms": tube_worms, "black_smoker": black_smoker, "bacterial_mat": bacterial_mat,
    "whale_bones": whale_bones, "glow_mushroom": glow_mushroom,
}
