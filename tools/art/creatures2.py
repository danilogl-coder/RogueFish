"""Food-web expansion: detritivores, grazers and the surface otter.
Same conventions as creatures.py (6 frames: 4 move + 2 action)."""
from __future__ import annotations

import math
from pixel import Canvas, Mat, sheet
from creatures import A, NF


def F(ramp, idx=3, group=None, alpha=255, outline=True):
    return Mat(ramp, idx, auto=False, group=group or ramp, alpha=alpha, outline=outline)


def sea_cucumber():
    frames = []
    for i in range(NF):
        w, h = 26, 12
        c = Canvas(w, h)
        stretch = [0.0, 1.0, 2.0, 1.0, 0.0, 0.0][i]
        L = 18 + stretch
        x0 = 4
        feeding = i >= 4

        def body(x, y):
            u = (x - x0) / L
            if u < 0 or u > 1:
                return False
            hh = 3.6 * math.sin(math.pi * (0.1 + u * 0.85)) ** 0.6
            yc = 8.0 - 0.6 * math.sin(u * math.pi)
            if abs(y - yc) > hh:
                return False
            bump = (int(x) * 3 + int(y) * 5) % 7 == 0 and y < yc
            return F("coral" if bump else "brown", 4 if bump else (3 if y < yc else 2), "b")
        c.paint_fn(body, None)
        hx = x0 + L
        # feeding tentacles
        for k in range(3):
            ang = -0.6 + k * 0.6 + (0.3 * math.sin(i) if feeding else 0)
            ln = 3.5 if feeding else 2
            c.line(hx, 7.5, hx + math.cos(ang) * ln, 7.5 + math.sin(ang) * ln, F("sandy", 5, "t", outline=False), 1.0)
        frames.append(c.render())
    return sheet(frames)


def isopod():
    frames = []
    for i in range(NF):
        w, h = 22, 13
        c = Canvas(w, h)
        step = i % 2
        cx, cy = 11, 7
        for k in range(5):
            x = 5 + k * 3
            c.line(x, cy + 2, x - 1 + (1 if (k + step) % 2 else 0), cy + 5, F("steel", 2, "leg", outline=False), 1.0)
        # segmented shell

        def shell(x, y):
            dx, dy = (x - cx) / 9.5, (y - cy) / 4.2
            if dy > 0.55 or dx * dx + dy * dy > 1:
                return False
            seg = int((x - cx + 20) / 2.4) % 2
            return F("silver", 4 if dy < -0.5 else (3 if seg else 2), "s")
        c.paint_fn(shell, None)
        # head + antennae
        c.ellipse(cx + 9, cy + 1, 2.2, 2.0, A("silver", 3, "h"))
        sw = [0, 1, 0, -1, 1, 1][i]
        c.line(cx + 10, cy - 0.5, cx + 13, cy - 3 + sw * 0.5, F("silver", 4, "ant", outline=False), 0.8)
        c.poly([(cx - 9, cy), (cx - 12, cy - 1), (cx - 12, cy + 2)], A("silver", 2, "tail"))
        img = c.render()
        img.putpixel((cx + 10, cy), (10, 8, 18, 255))
        frames.append(img)
    return sheet(frames)


def urchin():
    frames = []
    for i in range(NF):
        w = h = 18
        c = Canvas(w, h)
        cx, cy, r = 9, 11, 4.6
        for k in range(16):
            a = math.pi + k / 15 * math.pi + math.sin(i + k) * 0.05
            ln = 7.5 if k % 2 else 6
            if i >= 4:
                ln += 1.5
            c.line(cx + math.cos(a) * 3, cy + math.sin(a) * 3, cx + math.cos(a) * ln, cy + math.sin(a) * ln, F("violet", 4 if k % 2 else 3, "sp", outline=False), 1.0)
        for k in range(4):
            a = 0.3 + k * 0.8
            c.line(cx + math.cos(a) * 3, cy + math.sin(a) * 2, cx + math.cos(a) * 6, cy + math.sin(a) * 4, F("violet", 2, "sp2", outline=False), 1.0)
        c.ellipse(cx, cy, r, r * 0.85, A("poison", 2, "b"))
        frames.append(c.render())
    return sheet(frames)


def otter():
    frames = []
    for i in range(NF):
        w, h = 40, 18
        c = Canvas(w, h)
        paddle = [0.0, 1.0, 0.0, -1.0, 0.5, 0.5][i]
        cy = 9
        # tail
        c.poly([(8, cy), (1, cy - 1 + paddle * 0.5), (2, cy + 2), (8, cy + 2)], A("brown", 2, "tail"))
        # body
        c.ellipse(18, cy + 0.5, 11, 4.2, A("brown", 3, "body"))
        # belly lighter
        c.ellipse(19, cy + 2.3, 8, 1.6, F("sandy", 4, "belly", outline=False))
        # head
        c.circle(31, cy - 1, 4.3, A("brown", 4, "head"))
        c.ellipse(33.5, cy + 0.3, 2.4, 1.8, F("cream", 4, "muzzle", outline=False))
        c.circle(28.5, cy - 4.5, 1.2, A("brown", 2, "ear"))
        # feet
        c.poly([(12, cy + 3), (9 - paddle * 2, cy + 7), (13, cy + 5)], A("brown", 1, "foot"))
        c.poly([(23, cy + 3), (22 + paddle * 2, cy + 7), (25, cy + 4)], A("brown", 1, "foot2"))
        if i >= 4:
            # holding a snack (urchin)
            c.circle(35, cy - 5, 2.2, F("violet", 3, "snack"))
        img = c.render()
        img.putpixel((32, cy - 2), (10, 8, 18, 255))
        img.putpixel((36, cy), (20, 10, 12, 255))
        for k in range(3):
            img.putpixel((37, cy - 1 + k), (240, 230, 210, 255))
        frames.append(img)
    return sheet(frames)



ALL = {
    "sea_cucumber": sea_cucumber, "isopod": isopod, "urchin": urchin, "otter": otter,
}
