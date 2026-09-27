"""Item art for the "Marés Profundas" expansion: projectile / effect sheets
(fx/...) and 16x16 inventory icons (w_... weapons, f_... fusions).

Everything is drawn with the pixel.Canvas helpers (auto-shaded materials with
selective dark outlines), the same toolkit as the base items."""
from __future__ import annotations

import math

from PIL import Image

from pixel import Canvas, Mat, sheet, rng, col


def A(ramp, idx=3, group=None, alpha=255):
    return Mat(ramp, idx, auto=True, group=group or ramp, alpha=alpha)


def F(ramp, idx=3, group=None, alpha=255, outline=True):
    return Mat(ramp, idx, auto=False, group=group or ramp, alpha=alpha, outline=outline)


# ======================================================== projectile / fx
def lash_arc():
    """Tail-whip swoosh, 4 frames, drawn facing right (rotated in game):
    a thick crescent that sweeps open and fades."""
    frames = []
    for i in range(4):
        c = Canvas(40, 40)
        span = [0.9, 1.45, 1.7, 1.8][i]
        alpha = [255, 255, 210, 130][i]
        rout = 18.0
        thick = [4.0, 7.0, 6.0, 3.5][i]
        start = -span * 0.5

        def shape(x, y, inner):
            dx, dy = x - 13, y - 20
            d = math.hypot(dx, dy)
            a = math.atan2(dy, dx)
            if not (start <= a <= start + span):
                return False
            t = (a - start) / span
            w = thick * math.sin(t * math.pi) ** 0.7
            if inner:
                return rout - w * 0.45 <= d <= rout
            return rout - w <= d <= rout + 0.6
        c.paint_fn(lambda x, y: shape(x, y, False), F("cyan", 3, "o", alpha=alpha, outline=False))
        c.paint_fn(lambda x, y: shape(x, y, True), F("white", 5, "i", alpha=alpha, outline=False))
        frames.append(c.render(outline=False))
    return sheet(frames)


def claw_snap():
    """Crab hammer claw snapping shut, 4 frames."""
    frames = []
    for i in range(4):
        c = Canvas(40, 40)
        gap = [0.75, 0.45, 0.08, 0.0][i]
        cx, cy = 16, 20
        # lower fixed finger
        c.poly([(cx - 8, cy + 2), (cx + 14, cy + 4 + gap * 6), (cx + 10, cy + 9), (cx - 6, cy + 8)], A("red", 3, "lo"))
        # upper moving finger
        a = -gap
        pts = []
        for px, py in [(-8, -2), (14, -4), (10, -10), (-6, -8)]:
            rx = px * math.cos(a) - py * math.sin(a)
            ry = px * math.sin(a) + py * math.cos(a)
            pts.append((cx + rx, cy + ry))
        c.poly(pts, A("red", 4, "up"))
        c.circle(cx - 8, cy + 3, 6.5, A("red", 3, "palm"))
        img = c.render()
        if i >= 2:
            for k in range(5):
                x, y = 30 + k % 2, 17 + k * 2
                img.putpixel((x, y), col("white", 5))
        frames.append(img)
    return sheet(frames)


def coral_shard():
    c = Canvas(10, 6)
    c.poly([(0.5, 3), (4, 0.5), (9.5, 2.6), (4.5, 5.5)], A("coral", 4, "s"))
    img = c.render()
    img.putpixel((5, 2), col("coral", 5))
    return img


def silver_arrow():
    c = Canvas(16, 5)
    c.line(1, 2.5, 11, 2.5, F("silver", 4, "a", outline=False), 1.2)
    c.poly([(10, 0.5), (15.5, 2.5), (10, 4.5)], A("white", 4, "h"))
    c.poly([(0.5, 0.5), (3, 2.5), (0.5, 4.5)], A("cyan", 3, "t"))
    return c.render()


def tooth(ramp="white", accent="cream"):
    frames = []
    for i in range(4):
        c = Canvas(9, 9)
        a = i * math.pi / 2
        pts = [(-3, 3), (0, -4), (3, 3), (1, 2), (0, 3.5), (-1, 2)]
        c.poly([(4.5 + x * math.cos(a) - y * math.sin(a), 4.5 + x * math.sin(a) + y * math.cos(a)) for x, y in pts], A(ramp, 4, "t"))
        img = c.render()
        frames.append(img)
    return sheet(frames)


def coin():
    frames = []
    for i in range(4):
        c = Canvas(10, 10)
        w = [4.2, 2.6, 0.9, 2.6][i]
        c.ellipse(5, 5, w, 4.2, A("gold", 4, "c"))
        if w > 2:
            c.ellipse(5, 5, w - 1.6, 2.6, F("gold", 3, "i", outline=False))
        img = c.render()
        if w > 2:
            img.putpixel((4, 3), col("white", 5))
        frames.append(img)
    return sheet(frames)


def splash_ring():
    """Orca breach shockwave: foamy ring, 5 frames."""
    frames = []
    for i in range(5):
        c = Canvas(64, 64)
        r = 10 + i * 5.5
        th = 5.5 - i * 0.9

        def f(x, y, r=r, th=th):
            d = math.hypot(x - 32, y - 32)
            return abs(d - r) < th * 0.5 + 0.5
        c.paint_fn(f, F("water", 4, "r", alpha=235 - i * 30))

        def g(x, y, r=r):
            d = math.hypot(x - 32, y - 32)
            a = math.atan2(y - 32, x - 32)
            return abs(d - r - 1) < 0.9 and math.sin(a * 9 + i) > 0.2
        c.paint_fn(g, F("white", 5, "f", alpha=255 - i * 35, outline=False))
        frames.append(c.render(outline=False))
    return sheet(frames)


def cavitation():
    """Snapping-shrimp cavitation bubble: glowing bubble with a flash core."""
    frames = []
    for i in range(2):
        c = Canvas(12, 12)
        c.circle(6, 6, 4.8 - i * 0.4, F("cyan", 3, "o", alpha=190))
        c.circle(6, 6, 3.2, F("glow", 4, "i", outline=False, alpha=220))
        c.circle(6.5, 5.5, 1.4, F("white", 5, "c", outline=False))
        frames.append(c.render())
    return sheet(frames)


def cavitation_pop():
    frames = []
    for i in range(5):
        c = Canvas(32, 32)
        r = 3 + i * 3
        c.paint_fn(lambda x, y, r=r: abs(math.hypot(x - 16, y - 16) - r) < 1.3, F("white", 5, "r", alpha=255 - i * 45, outline=False))
        if i < 3:
            c.circle(16, 16, 5 - i * 1.5, F("glow", 5, "c", outline=False))
        rr = rng(i + 3)
        img = c.render(outline=False)
        for _ in range(8):
            a = rr.uniform(0, math.tau)
            d = r + rr.uniform(1, 4)
            x, y = int(16 + math.cos(a) * d), int(16 + math.sin(a) * d)
            if 0 <= x < 32 and 0 <= y < 32:
                img.putpixel((x, y), col("cyan", 5, max(40, 220 - i * 40)))
        frames.append(img)
    return sheet(frames)


def sucker():
    """Squid tentacle tip with suckers, 2 frames (curls)."""
    frames = []
    for i in range(2):
        c = Canvas(16, 12)
        curl = [0.0, 0.8][i]
        pts = []
        for k in range(8):
            t = k / 7
            pts.append((2 + t * 11, 6 + math.sin(t * math.pi * 1.2 + curl) * 2.5))
        c.curve(pts, A("pink", 3, "t"), 4.0, taper=lambda t: 1.0 - t * 0.55)
        img = c.render()
        for k in range(1, 7, 2):
            x, y = pts[k]
            img.putpixel((int(x), int(y) + 1), col("cream", 5))
        frames.append(img)
    return sheet(frames)


def shell_spin():
    frames = []
    for i in range(4):
        c = Canvas(14, 14)
        c.circle(7, 7, 6, A("turtle", 3, "s"))
        a0 = i * math.pi / 8
        for k in range(6):
            a = a0 + k * math.tau / 6
            c.line(7, 7, 7 + math.cos(a) * 5.4, 7 + math.sin(a) * 5.4, F("turtle", 1, "l", outline=False), 0.9)
        c.circle(7, 7, 2.2, F("turtle", 4, "c", outline=False))
        frames.append(c.render())
    return sheet(frames)


def spine_violet():
    c = Canvas(10, 4)
    c.poly([(0.5, 1), (9.5, 2), (0.5, 3)], A("violet", 4, "s"))
    return c.render()


def mucus():
    """Slime puddle (cloud sheet style): 4 wobbling frames."""
    frames = []
    r = rng(11)
    blobs = [(r.uniform(-0.3, 0.3), r.uniform(-0.12, 0.12), r.uniform(0.25, 0.4)) for _ in range(6)]
    for i in range(4):
        c = Canvas(32, 32)
        for k, (bx, by, br) in enumerate(blobs):
            ph = i / 4 * math.tau + k
            c.ellipse(16 + (bx + math.cos(ph) * 0.02) * 32, 18 + by * 32, br * 16 * 1.2, br * 16 * 0.55,
                      A("lime", 2, "m", alpha=180))
        img = c.render(outline=False)
        for _ in range(3):
            x, y = int(r.uniform(8, 24)), int(r.uniform(15, 20))
            img.putpixel((x, y), col("white", 5, 200))
        frames.append(img)
    return sheet(frames)


def guts():
    """Sea cucumber sticky guts: pink tangle, 2 frames (pulsing)."""
    frames = []
    for i in range(2):
        c = Canvas(16, 12)
        k = 1.0 + i * 0.08
        for pts in (((2, 8), (5, 3), (9, 7), (13, 4)), ((3, 5), (7, 9), (11, 6), (14, 9))):
            c.curve([(x, 6 + (y - 6) * k) for x, y in pts], A("pink", 3, "g"), 2.6)
        img = c.render()
        img.putpixel((6, 5), col("white", 5))
        frames.append(img)
    return sheet(frames)


def stone():
    frames = []
    for i in range(4):
        c = Canvas(10, 10)
        a = i * math.pi / 4
        pts = [(5 + math.cos(a + k * 1.25) * (4.2 - (k % 2) * 0.9), 5 + math.sin(a + k * 1.25) * (3.8 - (k % 2) * 0.7)) for k in range(5)]
        c.poly(pts, A("rock", 3, "s"))
        frames.append(c.render())
    return sheet(frames)


def jaws():
    """Bobbit scissor jaws springing up: 4 frames (rise, open, snap, closed)."""
    frames = []
    for i in range(4):
        c = Canvas(24, 26)
        rise = [8, 2, 0, 0][i]
        gape = [0.2, 0.9, 1.2, 0.05][i]
        base_y = 24
        c.rect(9, 10 + rise, 6, 16, A("violet", 3, "b"))
        for k in range(3):
            c.rect(9, 12 + rise + k * 4, 6, 1, F("violet", 1, "ring", outline=False))
        for s in (-1, 1):
            a = -math.pi / 2 + s * (0.3 + gape * 0.55)
            x0, y0 = 12 + s * 2, 10 + rise
            x1, y1 = x0 + math.cos(a) * 8, y0 + math.sin(a) * 8
            c.line(x0, y0, x1, y1, A("gold", 3, "j%d" % s), 2.2)
            c.line(x1, y1, x1 - s * 3, y1 - 1.5, A("gold", 4, "t%d" % s), 1.6)
        img = c.render()
        if i == 2:
            for x in range(8, 16, 2):
                img.putpixel((x, 3), col("white", 5))
        frames.append(img)
    del base_y
    return sheet(frames)


def megajaw():
    """Ancient jaws snapping shut on a target: 4 frames (open wide -> shut).
    Each jaw is a crescent (outer arc = lip, inner arc = gum line) lined with
    serrated triangular teeth along the inner edge."""
    frames = []
    for i in range(4):
        c = Canvas(52, 44)
        gap = [15.0, 10.0, 4.0, 0.5][i]
        for s_ in (-1, 1):
            cy = 22 + s_ * (gap * 0.5 + 1.5)
            # lip: ellipse band; gum: slightly smaller ellipse towards the mouth
            def lip(x, y, s_=s_, cy=cy):
                u = ((x - 26) / 24.0) ** 2 + ((y - cy) / 10.5) ** 2
                inner = ((x - 26) / 20.0) ** 2 + ((y - cy + s_ * 3.5) / 8.0) ** 2
                return u <= 1.0 and s_ * (y - cy) < 4.0 and not (inner <= 1.0 and s_ * (y - cy) < -1.0) and s_ * (y - cy) > -10.5 + 0 * x
            c.paint_fn(lambda x, y, s_=s_, cy=cy: ((x - 26) / 24.0) ** 2 + ((y - cy) / 10.5) ** 2 <= 1.0 and s_ * (y - cy) > -1.5,
                       A("shark", 3, "j%d" % s_))
            c.paint_fn(lambda x, y, s_=s_, cy=cy: ((x - 26) / 21.0) ** 2 + ((y - cy) / 6.5) ** 2 <= 1.0 and s_ * (y - cy) > -1.5 and s_ * (y - cy) < 2.5,
                       F("red", 2, "g%d" % s_, outline=False))
            edge = cy - s_ * 1.5
            for k in range(10):
                x = 8.5 + k * 3.6
                w_ = 1.6
                depth = (4.8 if i < 3 else 2.4) * (1.0 - abs(x - 26) / 34.0)
                c.poly([(x - w_, edge), (x + w_, edge), (x, edge - s_ * depth)], A("white", 4, "t%d%d" % (s_, k)))
        frames.append(c.render())
    return sheet(frames)


def gold_tooth():
    return tooth("gold")


FX = {
    "lash_arc": lash_arc, "claw_snap": claw_snap, "coral_shard": coral_shard, "silver_arrow": silver_arrow,
    "tooth": tooth, "gold_tooth": gold_tooth, "coin": coin, "splash_ring": splash_ring,
    "cavitation": cavitation, "cavitation_pop": cavitation_pop, "sucker": sucker, "shell_spin": shell_spin,
    "spine_violet": spine_violet, "mucus": mucus, "guts": guts, "stone": stone, "jaws": jaws, "megajaw": megajaw,
}
FX_FRAMES = {"lash_arc": 4, "claw_snap": 4, "tooth": 4, "gold_tooth": 4, "coin": 4, "splash_ring": 5,
             "cavitation": 2, "cavitation_pop": 5, "sucker": 2, "shell_spin": 4, "mucus": 4, "guts": 2,
             "stone": 4, "jaws": 4, "megajaw": 4}


# ================================================================= icons
def ic():
    return Canvas(16, 16)


def i_tail_whip():
    c = ic()
    c.curve([(2, 13), (5, 6), (10, 3), (14, 5)], A("orange", 3, "t"), 2.6, taper=lambda t: 1.0 - t * 0.6)
    c.poly([(12, 3), (15.5, 1), (15, 7)], A("flame", 4, "f"))
    return c.render()


def i_coral_shard():
    c = ic()
    for x, y, a in ((5, 10, 0.4), (10, 6, -0.6), (11, 12, 0.9)):
        pts = [(x + math.cos(a) * 4, y + math.sin(a) * 4), (x + math.cos(a + 2.2) * 2, y + math.sin(a + 2.2) * 2),
               (x - math.cos(a) * 3, y - math.sin(a) * 3), (x + math.cos(a - 2.2) * 2, y + math.sin(a - 2.2) * 2)]
        c.poly(pts, A("coral", 4, "s%d" % x))
    return c.render()


def i_bubble_ring():
    c = ic()
    for k in range(6):
        a = k * math.tau / 6
        c.circle(8 + math.cos(a) * 5.2, 8 + math.sin(a) * 5.2, 1.9, F("cyan", 3, "b%d" % k))
    img = c.render()
    img.putpixel((8, 8), col("white", 5))
    return img


def i_volt_lance():
    c = ic()
    c.poly([(1, 14), (7, 8), (6, 10), (15, 2), (9, 9), (10, 7)], A("volt", 4, "b"))
    c.line(1, 14, 15, 2, F("cyan", 5, "g", alpha=90, outline=False), 3.0)
    return c.render()


def i_silver_school():
    c = ic()
    for x, y in ((4, 5), (10, 4), (6, 10), (12, 11)):
        c.ellipse(x + 1, y, 2.6, 1.3, A("silver", 4, "f%d" % x))
        c.poly([(x - 1.4, y), (x - 3, y - 1.4), (x - 3, y + 1.4)], A("silver", 3, "t%d" % x))
    return c.render()


def i_photophore():
    c = ic()
    c.circle(8, 8, 6, F("glow", 2, "h", alpha=110, outline=False))
    c.circle(8, 8, 3.6, F("glow", 4, "o"))
    c.circle(7, 7, 1.4, F("white", 5, "c", outline=False))
    return c.render()


def i_tetrodo():
    c = ic()
    for x, y, r in ((6, 9, 4.2), (10, 7, 4.0), (9, 11, 3.2)):
        c.circle(x, y, r, A("lime", 3, "n", alpha=210))
    c.circle(9, 8, 2.2, F("sandy", 4, "p"))
    for k in range(6):
        a = k * math.tau / 6
        c.line(9 + math.cos(a) * 2, 8 + math.sin(a) * 2, 9 + math.cos(a) * 3.6, 8 + math.sin(a) * 3.6, F("sandy", 2, "sp", outline=False), 0.8)
    return c.render()


def i_silver_arrow():
    c = ic()
    c.line(2, 14, 12, 4, F("silver", 4, "s", outline=False), 1.4)
    c.poly([(10, 2.5), (14.5, 1.5), (13.5, 6)], A("white", 4, "h"))
    c.poly([(1, 12), (4, 15), (2.5, 15.5), (0.5, 13.5)], A("cyan", 3, "t"))
    return c.render()


def i_serrated():
    c = ic()
    for k, (x, y) in enumerate(((4, 5), (11, 7), (6, 12))):
        c.poly([(x - 2.5, y + 2), (x, y - 3.5), (x + 2.5, y + 2)], A("white", 4, "t%d" % k))
    img = c.render()
    img.putpixel((13, 3), col("red", 4))
    img.putpixel((2, 10), col("red", 4))
    return img


def i_moray_strike():
    c = ic()
    c.curve([(1, 14), (4, 10), (9, 8), (12, 5)], A("kelp", 3, "b"), 3.2)
    c.poly([(11, 3), (15.5, 4), (12, 7.5)], A("kelp", 4, "h"))
    img = c.render()
    img.putpixel((13, 4), col("volt", 5))
    return img


def i_gold_rain():
    c = ic()
    for x, y in ((4, 4), (11, 6), (7, 11)):
        c.ellipse(x, y, 2.6, 2.4, A("gold", 4, "c%d" % x))
    img = c.render()
    for x, y in ((4, 1), (11, 3), (7, 8)):
        img.putpixel((x, y), col("white", 5, 180))
    return img


def i_orca_breach():
    c = ic()
    c.paint_fn(lambda x, y: abs(math.hypot(x - 8, y - 10) - 6) < 0.9 and y < 13, F("water", 4, "w"))
    c.ellipse(8, 7, 4.5, 2.4, A("black", 3, "o"))
    c.ellipse(9, 8, 2.4, 1.0, F("white", 5, "b", outline=False))
    c.poly([(6, 5), (7.5, 1.5), (8.5, 5)], A("black", 2, "d"))
    return c.render()


def i_cavitation():
    c = ic()
    c.circle(10, 7, 4.2, F("cyan", 3, "o", alpha=200))
    c.circle(10, 7, 2.2, F("white", 5, "c", outline=False))
    c.poly([(1, 12), (5, 9), (7, 11), (4, 15)], A("coral", 4, "claw"))
    return c.render()


def i_claw():
    c = ic()
    c.poly([(2, 10), (11, 11), (14, 14), (4, 14)], A("red", 3, "lo"))
    c.poly([(2, 9), (10, 3), (14, 4), (9, 9)], A("red", 4, "up"))
    c.circle(3.5, 11, 3, A("red", 3, "p"))
    return c.render()


def i_tentacles():
    c = ic()
    c.ellipse(8, 5, 5, 3.6, A("jelly", 3, "b", alpha=230))
    for k, x in enumerate((4, 7, 10, 12)):
        c.curve([(x, 7), (x + (1 if k % 2 else -1), 10), (x, 13), (x + 1, 15)], F("jelly", 4, "t%d" % k, outline=False), 1.0)
    return c.render()


def i_sucker():
    c = ic()
    c.paint_fn(lambda x, y: abs(math.hypot(x - 8, y - 8) - 5) < 1.5 and not (x > 9 and y < 8), A("pink", 3, "t"))
    img = c.render()
    for x, y in ((4, 9), (7, 12), (11, 11)):
        img.putpixel((x, y), col("cream", 5))
    return img


def i_shell_bounce():
    c = ic()
    c.circle(8, 9, 6, A("turtle", 3, "s"))
    for a in (0.3, 1.9, 3.5, 5.1):
        c.line(8, 9, 8 + math.cos(a) * 5, 9 + math.sin(a) * 5, F("turtle", 1, "l", outline=False), 0.9)
    img = c.render()
    img.putpixel((1, 2), col("white", 4))
    img.putpixel((3, 1), col("white", 4))
    return img


def i_urchin_burst():
    c = ic()
    for k in range(10):
        a = k * math.tau / 10
        c.line(8 + math.cos(a) * 2, 8 + math.sin(a) * 2, 8 + math.cos(a) * 7, 8 + math.sin(a) * 7, F("violet", 4, "s", outline=False), 1.0)
    c.circle(8, 8, 3, A("violet", 3, "b"))
    return c.render()


def i_mucus():
    c = ic()
    c.ellipse(8, 11, 6.5, 3, A("lime", 3, "m", alpha=220))
    c.ellipse(11, 6, 3, 2.4, A("cream", 3, "shell"))
    img = c.render()
    img.putpixel((6, 10), col("white", 5))
    return img


def i_sticky_guts():
    c = ic()
    c.curve([(2, 10), (5, 5), (9, 11), (14, 6)], A("pink", 3, "g1"), 2.6)
    c.curve([(3, 13), (8, 8), (13, 13)], A("pink", 4, "g2"), 2.0)
    return c.render()


def i_scavengers():
    c = ic()
    for x, y in ((5, 6), (11, 11)):
        c.ellipse(x, y, 4, 2.4, A("steel", 3, "b%d" % x))
        c.rect(x - 3, y + 2, 6, 1, F("steel", 1, "l%d" % x, outline=False))
    return c.render()


def i_otter_stone():
    c = ic()
    c.poly([(3, 9), (7, 4), (13, 6), (13, 11), (6, 13)], A("rock", 3, "s"))
    img = c.render()
    img.putpixel((7, 6), col("white", 4))
    return img


def i_scissor_jaws():
    c = ic()
    c.rect(6, 9, 4, 7, A("violet", 3, "b"))
    c.line(8, 9, 3, 2, A("gold", 3, "l"), 2.0)
    c.line(8, 9, 13, 2, A("gold", 3, "r"), 2.0)
    return c.render()


def i_louse_swarm():
    c = ic()
    for x, y in ((4, 5), (11, 4), (7, 11), (13, 12)):
        c.ellipse(x, y, 2.6, 1.6, A("pink", 3, "l%d" % x))
    img = c.render()
    for x, y in ((6, 5), (13, 4), (9, 11), (15, 12)):
        if x < 16:
            img.putpixel((x, y), col("black", 0))
    return img


def i_hypno_lure():
    c = ic()
    c.curve([(2, 14), (4, 8), (9, 5)], F("abyss", 3, "st", outline=True), 1.2)
    c.circle(11, 5, 3.4, F("glow", 3, "h", alpha=150, outline=False))
    c.circle(11, 5, 2.0, F("glow", 5, "b"))
    for r in (5.5,):
        c.paint_fn(lambda x, y, r=r: abs(math.hypot(x - 11, y - 5) - r) < 0.5 and x < 11, F("cyan", 4, "ring", outline=False))
    return c.render()


def i_star_mucus():
    c = ic()
    for x, y, r in ((5, 6, 2.6), (11, 5, 2.0), (8, 11, 2.8), (13, 12, 1.6)):
        c.circle(x, y, r, F("glow", 3, "o%d" % x, alpha=210))
        c.circle(x - 0.4, y - 0.4, r * 0.45, F("white", 5, "c%d" % x, outline=False))
    return c.render()


def i_ancient_jaws():
    c = ic()
    c.poly([(1, 7), (15, 7), (13, 2), (3, 2)], A("shark", 3, "u"))
    c.poly([(1, 9), (15, 9), (13, 14), (3, 14)], A("shark", 3, "l"))
    img = c.render()
    for x in range(3, 14, 3):
        img.putpixel((x, 7), col("white", 5))
        img.putpixel((x + 1, 8), col("white", 5))
    return img


WEAPON_ICONS = {
    "w_ancient_jaws": i_ancient_jaws,
    "w_hypno_lure": i_hypno_lure, "w_star_mucus": i_star_mucus,
    "w_tail_whip": i_tail_whip, "w_coral_shard": i_coral_shard, "w_bubble_ring": i_bubble_ring,
    "w_volt_lance": i_volt_lance, "w_silver_school": i_silver_school, "w_photophore": i_photophore,
    "w_tetrodo": i_tetrodo, "w_silver_arrow": i_silver_arrow, "w_serrated": i_serrated,
    "w_moray_strike": i_moray_strike, "w_gold_rain": i_gold_rain, "w_orca_breach": i_orca_breach,
    "w_cavitation": i_cavitation, "w_claw": i_claw, "w_tentacles": i_tentacles, "w_sucker": i_sucker,
    "w_shell_bounce": i_shell_bounce, "w_urchin_burst": i_urchin_burst, "w_mucus": i_mucus,
    "w_sticky_guts": i_sticky_guts, "w_scavengers": i_scavengers, "w_otter_stone": i_otter_stone,
    "w_scissor_jaws": i_scissor_jaws, "w_louse_swarm": i_louse_swarm,
}

# fusion id -> (icon of weapon A, icon of weapon B); drawn as a diagonal
# split of both inside a glowing magenta frame.
FUSION_PAIRS = {
    "f_storm_bubbles": ("w_bubble", "w_pulse"), "f_ink_vortex": ("w_ink", "w_whirl"),
    "f_thorn_tempest": ("w_spines", "w_urchin_burst"), "f_royal_school": ("w_pilot", "w_silver_school"),
    "f_orca_song": ("w_sonar", "w_orca_breach"), "f_abyss_aurora": ("w_volt_lance", "w_photophore"),
    "f_abyss_shears": ("w_claw", "w_tail_whip"), "f_cavitation_cannon": ("w_cavitation", "w_coral_shard"),
    "f_armored_boomerang": ("w_sucker", "w_shell_bounce"), "f_slime_marsh": ("w_mucus", "w_sticky_guts"),
    "f_abyss_plague": ("w_scavengers", "w_louse_swarm"), "f_deadly_ambush": ("w_moray_strike", "w_scissor_jaws"),
    "f_golden_fangs": ("w_gold_rain", "w_serrated"), "f_venom_garden": ("w_tetrodo", "w_tentacles"),
    "f_tide_ring": ("w_bubble_ring", "w_silver_arrow"), "f_star_abyss": ("w_hypno_lure", "w_star_mucus"),
    "f_fang_storm": ("w_ancient_jaws", "w_serrated"),
}


def fusion_icon(a_img: Image.Image, b_img: Image.Image) -> Image.Image:
    out = Image.new("RGBA", (16, 16))
    pa, pb, po = a_img.load(), b_img.load(), out.load()
    for y in range(16):
        for x in range(16):
            src = pa if x + y < 16 else pb
            po[x, y] = src[x, y]
    # magenta rune frame corners + diagonal seam sparkle
    for (x, y) in ((0, 0), (1, 0), (0, 1), (15, 15), (14, 15), (15, 14), (15, 0), (0, 15)):
        po[x, y] = col("pink", 5)
    for k in range(3, 13, 3):
        po[k, 15 - k] = (255, 255, 255, 255)
    return out


# ============================================================ shop icons
def s_pack_vents():
    c = ic()
    c.poly([(4, 15), (6, 6), (10, 6), (12, 15)], A("rock", 2, "ch"))
    c.rect(5, 5, 6, 2, A("rock", 3, "top"))
    for k, (x, y, r) in enumerate(((8, 3.5, 2.2), (6, 1.8, 1.6), (10.5, 1.5, 1.4))):
        c.circle(x, y, r, F("black", 2, "sm%d" % k, alpha=200, outline=False))
    img = c.render()
    for y in range(8, 15, 2):
        img.putpixel((8, y), col("orange", 5))
    return img


def s_pack_glow():
    c = ic()
    c.ellipse(8, 9, 6, 3.4, A("abyss", 3, "b"))
    c.poly([(12, 8), (15.5, 7), (14, 10)], A("abyss", 2, "j"))
    img = c.render()
    for x in range(3, 13, 2):
        img.putpixel((x, 11), col("glow", 5))
    img.putpixel((12, 8), col("white", 5))
    img.putpixel((13, 11), col("white", 5))
    img.putpixel((14, 11), col("white", 5))
    return img


def s_pack_megalodon():
    c = ic()
    c.ellipse(8, 9, 7, 5, A("shark", 3, "h"))
    c.poly([(3, 9), (13, 9), (12, 13), (4, 13)], F("red", 1, "m"))
    img = c.render()
    for x in range(4, 13, 2):
        img.putpixel((x, 9), col("white", 5))
        img.putpixel((x + 1, 12), col("white", 5))
    img.putpixel((11, 6), col("black", 0))
    return img


def s_relic_compass():
    c = ic()
    c.circle(8, 8, 7, A("gold", 3, "r"))
    c.circle(8, 8, 5.5, F("navy", 2, "in", outline=False))
    c.poly([(8, 2.5), (9.5, 8), (8, 13.5), (6.5, 8)], F("white", 5, "n", outline=False))
    c.poly([(2.5, 8), (8, 6.8), (13.5, 8), (8, 9.2)], F("cyan", 4, "e", outline=False))
    return c.render()


def s_relic_crown():
    c = ic()
    c.poly([(2, 13), (2, 6), (5, 9), (8, 3), (11, 9), (14, 6), (14, 13)], A("coral", 4, "c"))
    img = c.render()
    for x, y in ((8, 5), (4, 9), (12, 9)):
        img.putpixel((x, y), col("glow", 5))
    return img


def s_relic_anchor():
    c = ic()
    c.rect(7, 2, 2, 11, A("steel", 3, "s"))
    c.circle(8, 3, 2, A("steel", 4, "ring"))
    c.paint_fn(lambda x, y: abs(math.hypot(x - 8, y - 8) - 6) < 1.0 and y > 9, A("steel", 3, "arc"))
    c.rect(5, 5, 6, 1.5, A("steel", 4, "bar"))
    return c.render()


def s_relic_eye():
    c = ic()
    c.ellipse(8, 8, 7, 4.2, A("cyan", 4, "w"))
    c.circle(8, 8, 3, F("navy", 2, "i"))
    c.circle(8, 8, 1.3, F("glow", 5, "p", outline=False))
    return c.render()


def s_relic_amber():
    c = ic()
    c.poly([(8, 1.5), (13.5, 6), (12, 13.5), (4, 13.5), (2.5, 6)], A("orange", 3, "a", alpha=235))
    c.ellipse(8, 9, 2.4, 1.2, F("black", 1, "bug", outline=False))
    img = c.render()
    img.putpixel((6, 4), col("white", 5))
    return img


def s_relic_bottle():
    c = ic()
    c.rect(6, 1, 4, 3, A("brown", 3, "cork"))
    c.poly([(5, 4), (11, 4), (13, 14), (3, 14)], A("water", 3, "g", alpha=200))
    c.rect(5, 8, 6, 3, F("cream", 5, "note", outline=False))
    return c.render()


def s_relic_pearl():
    c = ic()
    c.circle(8, 8, 5.5, A("abyss", 2, "p"))
    img = c.render()
    img.putpixel((6, 6), col("violet", 5))
    img.putpixel((7, 5), col("white", 5))
    return img


def s_relic_hourglass():
    c = ic()
    c.rect(3, 1, 10, 2, A("brown", 3, "t"))
    c.rect(3, 13, 10, 2, A("brown", 3, "b"))
    c.poly([(4, 3), (12, 3), (8.5, 8), (12, 13), (4, 13), (7.5, 8)], A("water", 4, "g", alpha=200))
    c.poly([(5.5, 12.5), (10.5, 12.5), (8, 9.5)], F("sand", 4, "s", outline=False))
    return c.render()


def s_relic_music():
    c = ic()
    c.rect(2, 8, 12, 6, A("brown", 3, "box"))
    c.rect(2, 6, 12, 2, A("brown", 4, "lid"))
    c.line(10, 6, 12, 1, F("gold", 4, "n", outline=False), 1.2)
    c.circle(11, 2, 1.3, F("gold", 5, "h", outline=False))
    return c.render()


def _tide(ramp):
    def f():
        c = ic()
        for k in range(3):
            y = 5 + k * 4
            c.curve([(1, y), (4, y - 2), (8, y), (12, y - 2), (15, y)], A(ramp, 4 - (k % 2), "w%d" % k), 2.0)
        return c.render()
    return f


def s_mode_mutant():
    c = ic()
    c.ellipse(8, 9, 6, 4, A("lime", 3, "b"))
    c.poly([(2, 8), (0.5, 5), (3.5, 6)], A("red", 3, "s1"))
    c.poly([(10, 5), (12, 1), (13, 6)], A("violet", 3, "s2"))
    img = c.render()
    img.putpixel((11, 8), col("red", 5))
    img.putpixel((12, 8), col("black", 0))
    return img


def s_mode_hyper():
    c = ic()
    c.poly([(9, 1), (3, 9), (7.5, 9), (6, 15), (13, 6), (8.5, 6)], A("orange", 4, "b"))
    return c.render()


def s_mode_inverse():
    c = ic()
    c.circle(8, 8, 6.5, A("violet", 2, "m"))
    c.circle(10.5, 6.5, 5, F("black", 0, "x"), erase=True)
    img = c.render()
    img.putpixel((4, 12), col("white", 5))
    img.putpixel((12, 12), col("white", 4))
    return img


SHOP_ICONS = {
    "pack_vents": s_pack_vents, "pack_glow": s_pack_glow, "pack_megalodon": s_pack_megalodon,
    "relic_compass": s_relic_compass, "relic_crown": s_relic_crown, "relic_anchor": s_relic_anchor,
    "relic_eye": s_relic_eye, "relic_amber": s_relic_amber, "relic_bottle": s_relic_bottle,
    "relic_pearl": s_relic_pearl, "relic_hourglass": s_relic_hourglass, "relic_music": s_relic_music,
    "tide_red": _tide("red"), "tide_silver": _tide("silver"), "tide_black": _tide("ink"),
    "tide_storm": _tide("volt"), "tide_life": _tide("lime"), "tide_gold": _tide("gold"),
    "mode_mutant": s_mode_mutant, "mode_hyper": s_mode_hyper, "mode_inverse": s_mode_inverse,
}
