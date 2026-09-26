"""Ecosystem food items: detritus (marine snow), carcasses, boss food, alpha scale, phytoplankton."""
from __future__ import annotations

import math
from pixel import Canvas, Mat, sheet, col
from fx import A, F


def detritus():
    frames = []
    for i in range(2):
        c = Canvas(5, 5)
        c.pixel(2, 2, col("sandy", 4))
        c.pixel(1 + i, 1, col("sandy", 3))
        c.pixel(3, 3 - i, col("brown", 4))
        frames.append(c.render(outline=False))
    return sheet(frames)


def carcass(big=False):
    w, h = (24, 16) if big else (16, 11)
    c = Canvas(w, h)
    s = w / 16
    c.ellipse(7 * s, 6.5 * s * 0.95, 5.5 * s, 3.6 * s, A("red", 3, "m"))
    c.ellipse(6 * s, 5.2 * s * 0.95, 2.4 * s, 1.3 * s, F("pink", 5, "fat", outline=False))
    c.line(10 * s, 7 * s * 0.95, 14.5 * s, 9 * s * 0.95, F("bone", 4, "b"), 1.7 * s)
    c.circle(14.8 * s, 8.4 * s * 0.95, 1.4 * s, F("bone", 5, "k"))
    c.circle(14.8 * s, 10 * s * 0.95, 1.4 * s, F("bone", 5, "k"))
    if big:
        for k in range(3):
            c.line(3 + k * 3, 3, 4 + k * 3, 9, F("bone", 4, "r"), 1.2)
    return c.render()


def boss_food():
    frames = []
    for i in range(4):
        c = Canvas(16, 16)
        c.circle(8, 9, 5.5 + (0.4 if i % 2 else 0), A("gold", 4, "f"))
        c.poly([(8, 3.5), (11, 0.5), (9.5, 4)], A("kelp", 4, "leaf"))
        img = c.render()
        sp = [(5, 6), (10, 7), (7, 12), (6, 8)][i]
        img.putpixel(sp, (255, 255, 255, 255))
        frames.append(img)
    return sheet(frames)


def alpha_scale():
    frames = []
    for i in range(4):
        c = Canvas(11, 11)
        c.poly([(5.5, 0.5), (10, 4), (8, 10), (3, 10), (1, 4)], A("cyan", 3, "s"))
        img = c.render()
        img.putpixel((4 + (i % 2), 3 + i // 2), (255, 255, 255, 255))
        frames.append(img)
    return sheet(frames)


def phyto():
    frames = []
    for i in range(4):
        c = Canvas(6, 6)
        c.circle(3, 3, 1.4 + (0.4 if i % 2 else 0), F("cyan", 4, "p", outline=False))
        img = c.render(outline=False)
        img.putpixel((3, 3), col("glow", 5))
        frames.append(img)
    return sheet(frames)


ALL = {
    "detritus": detritus, "carcass": carcass, "carcass_big": lambda: carcass(True),
    "boss_food": boss_food, "alpha_scale": alpha_scale, "phyto": phyto,
}
