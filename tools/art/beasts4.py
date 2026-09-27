"""Body plans: sea urchin, sea cucumber and sea snail."""
from __future__ import annotations

import math

import numpy as np

from pro import PAL, ramp
from beasts import Plan, skin_ramp, skin_detail, spline, hsh, TAU

URCHIN = [ramp("#9a6ad8"), ramp("#8a5ad0"), ramp("#7a4ac8"), ramp("#6a3ab8"), ramp("#4a2a98")]
URCHIN_SPINE = [ramp("#b88ae8"), ramp("#a878e0"), ramp("#b060c8"), ramp("#c050b0"), ramp("#d04898")]
CUKE = [ramp("#d89a7a", dark=0.3), ramp("#c8806a"), ramp("#b86a5a"), ramp("#a8505a"), ramp("#903a58")]
PAPILLA = ramp("#f0c8a0")
SHELL = [ramp("#d8a870", dark=0.3), ramp("#c88a4a"), ramp("#c07a3a"), ramp("#b0683a"), ramp("#9a5a3a")]
FOOT = ramp("#d8b890", dark=0.3)


def lure_bulb(ctx, lay, pts, rmp):
    sp = spline(pts, 12)
    m, _ = ctx.path(sp, 0.4, 0.3)
    lay.paint(m, rmp, 3)
    bx, by = sp[-1]
    lay.paint(ctx.ell(bx, by, 1.4, 1.4), PAL["glow"], 5)
    ctx.dot(lay, bx - 0.4, by - 0.4, PAL["white"], 6, r=0.35)
    return bx, by


# ---------------------------------------------------------------- urchin
class Urchin(Plan):
    """Ouriço: a round test bristling with spines, walking on tube feet.
    Path: short stubby spines -> longer spines -> banded spines -> long needle
    crown with a second row of short spines -> royal urchin with glowing tips."""
    canvas = (42, 40)
    length = 20.0

    def geom(self, stage, st):
        bob = math.sin(st["phase"]) * 0.4
        return 21.0, 20.0 + bob, 7.0, 6.2, bob

    def spine_len(self, stage, st):
        flare = 1.0 + (0.35 * st["reach"] if st["act"] else 0.0)
        return ([3.2, 4.8, 6.0, 8.0, 9.5][stage]) * flare

    def draw(self, ctx, stage, st, head="", skin="", fins="", tail="", what=("rear", "back", "body", "front")):
        cx, cy, rx, ry, bob = self.geom(stage, st)
        test_r = skin_ramp(URCHIN[stage], skin)
        sp_r = URCHIN_SPINE[stage]
        if skin == "skin_armor":
            sp_r = PAL["steel"]
        elif skin == "skin_toxic":
            sp_r = ramp("#b85ce0")
        elif skin == "skin_glow":
            sp_r = ramp("#3a4a8e")
        sl = self.spine_len(stage, st)
        if "rear" in what:
            lay = ctx.L["rear"]
            sw = math.sin(st["phase"]) * 0.8
            if tail == "tail_fork":
                for j in (-1, 1):
                    a = math.pi + j * 0.45
                    b = (cx + math.cos(a) * rx * 0.8, cy + math.sin(a) * ry * 0.8)
                    e = (cx + math.cos(a) * (rx + sl + 4), cy + math.sin(a) * (ry + sl + 4) + sw)
                    m, h = ctx.path([b, e], 1.1, 0.3)
                    ctx.shade(lay, m, sp_r, h, gain=1.1)
                    lay.paint(ctx.ell(e[0], e[1], 1.2, 1.2), sp_r, 5)
            elif tail == "tail_sting":
                b = (cx - rx * 0.6, cy)
                e = (cx - rx - sl - 6, cy + sw * 0.5)
                m, h = ctx.path([b, e], 1.5, 0.25)
                ctx.shade(lay, m, PAL["bone"], h)
                lay.paint(ctx.seg((e[0] + 3, e[1]), e, 0.35), ramp("#b85ce0"), 5)
            elif tail == "tail_eel":
                pts = [(cx - rx + 1 - q * 2.2, cy + 1 + math.sin(st["phase"] + q * 0.9) * (0.3 + q * 0.35)) for q in range(9)]
                sp = spline(pts, 20)
                m, h = ctx.path(sp, 0.9, 0.3)
                ctx.shade(lay, m, test_r, h, shift=-1)
        for side in ("back", "front"):
            if side not in what:
                continue
            lay = ctx.L[side]
            far = side == "back"
            n = 3 + (1 if stage >= 2 else 0)
            for j in range(n):
                t = (j + (0.5 if far else 0.0)) / n
                x0 = cx - rx * 0.75 + t * rx * 1.5
                step = math.sin(st["phase"] + j * 1.8 + (math.pi if far else 0.0))
                y0 = cy + ry * 0.6
                foot = (x0 + step * 1.2, cy + ry + 3.2 + max(0.0, -step) * -0.6)
                if fins == "fins_wing":
                    m = ctx.poly([(x0 - 0.6, y0), (foot[0] - 2.2, foot[1] + 0.8), (foot[0] + 2.2, foot[1] + 0.8), (x0 + 0.6, y0)])
                    ctx.shade(lay, m, ramp("#4ab8d8"), gain=1.0, shift=-2 if far else 0)
                    continue
                m, h = ctx.path([(x0, y0), ((x0 + foot[0]) / 2, (y0 + foot[1]) / 2 + 0.3), foot], 0.45, 0.4)
                col = PAL["volt"] if fins == "fins_volt" else ramp("#f0a0c8")
                lay.paint(m, col if fins == "fins_volt" else ramp("#e890c0"), 2 if far else 4)
                lay.paint(ctx.ell(foot[0], foot[1], 0.75, 0.55), col, 3 if far else 5)
                if fins == "fins_spiky":
                    lay.paint(ctx.poly([(x0 - 0.5, y0 + 1.0), (x0 + (1.8 if j % 2 else -1.8), y0 + 2.5), (x0 + 0.5, y0 + 1.3)]), PAL["coral"], 5)
                if fins == "fins_volt" and (st["i"] + j) % 3 == 0:
                    lay.paint(ctx.seg(foot, (foot[0] + 1.0, foot[1] + 1.2), 0.25), PAL["volt"], 6, outline=False)
        if "body" in what:
            lay = ctx.L["body"]
            # spines behind the test first, then the test on top
            n = [10, 12, 14, 16, 18][stage]
            for j in range(n):
                a = j * TAU / n + (0.5 * TAU / n if stage % 2 else 0.0)
                if 0.6 < a < 2.55 and stage < 3:   # the underside stays clear for the feet
                    continue
                if 0.9 < a < 2.25:
                    continue
                sway = math.sin(st["phase"] + j * 0.7) * 0.12
                aa = a + sway
                ln = sl * (0.85 + 0.3 * hsh(j, stage, 3))
                b = (cx + math.cos(aa) * rx * 0.7, cy + math.sin(aa) * ry * 0.7)
                e = (cx + math.cos(aa) * (rx + ln), cy + math.sin(aa) * (ry + ln))
                m, h = ctx.path([b, e], 0.65 + 0.08 * stage, 0.22)
                ctx.shade(lay, m, sp_r, h, gain=1.0)
                if stage == 2 or stage == 3:
                    # banded spines
                    band_m = m & (np.sin(np.hypot(ctx.X - cx, ctx.Y - cy) * 1.9) > 0.55)
                    lay.shift(band_m, -2, lo=1)
                if stage >= 4 or fins == "fins_volt":
                    ctx.dot(lay, e[0], e[1], PAL["glow"], 5, r=0.45)
            if stage >= 3:
                # second row of short spines
                for j in range(n):
                    a = (j + 0.5) * TAU / n
                    if 0.9 < a < 2.25:
                        continue
                    b = (cx + math.cos(a) * rx * 0.8, cy + math.sin(a) * ry * 0.8)
                    e = (cx + math.cos(a) * (rx + 2.2), cy + math.sin(a) * (ry + 2.2))
                    m, h = ctx.path([b, e], 0.55, 0.2)
                    ctx.shade(lay, m, sp_r, h, shift=-1)
            if head == "head_sword":
                b = (cx + rx * 0.5, cy - 0.5)
                e = (cx + rx + sl + 7 + (3 * st["reach"] if st["act"] else 0), cy - 1.0)
                m, h = ctx.path([b, e], 1.3, 0.2)
                ctx.shade(lay, m, PAL["steel"], h)
            if head == "head_lure":
                lure_bulb(ctx, lay, [(cx, cy - ry * 0.6), (cx + 2, cy - ry - sl - 2), (cx + 5, cy - ry - sl - 3 + bob)], test_r)
            test = ctx.ell(cx, cy, rx, ry)
            ctx.shade(lay, test, test_r, gain=1.5)
            if skin == "":
                # ambulacral rows of pores following the curvature
                ang = np.arctan2((ctx.Y - cy) / ry, (ctx.X - cx) / rx)
                u = np.hypot((ctx.X - cx) / rx, (ctx.Y - cy) / ry)
                rows = test & (np.abs(np.sin(ang * 2.5)) < 0.12) & (u > 0.3) & (u < 0.9)
                lay.shift(rows, -1, lo=1)
                tub = test & (hsh(np.floor(ctx.X * 1.2), np.floor(ctx.Y * 1.2), stage) < 0.1) & (u < 0.85)
                lay.shift(tub, +1, hi=6)
            skin_detail(ctx, lay, test, skin, seed=21, center=(cx, cy), radii=(rx, ry))
            # eye spots / crown
            if stage >= 4:
                for j in range(5):
                    a = -math.pi / 2 + (j - 2) * 0.35
                    ctx.dot(lay, cx + math.cos(a) * rx * 0.55, cy + math.sin(a) * ry * 0.55, PAL["glow"], 6, r=0.45)
            if head == "head_piranha":
                # Aristotle's lantern: five teeth opening at the mouth (front-bottom)
                mx, my = cx + rx * 0.72, cy + ry * 0.45
                op = st["open"]
                lay.paint(ctx.ell(mx, my, 2.0, 1.6), ramp("#3a1a3a"), 1)
                for j in range(5):
                    a = -1.2 + j * 0.6
                    d = 0.6 + op * 1.2
                    tip = (mx + math.cos(a) * (d + 1.6), my + math.sin(a) * (d + 1.4))
                    lay.paint(ctx.poly([(mx + math.cos(a - 0.4) * d, my + math.sin(a - 0.4) * d), tip,
                                        (mx + math.cos(a + 0.4) * d, my + math.sin(a + 0.4) * d)]), PAL["white"], 6)

    def lure_pos(self, stage, st):
        cx, cy, rx, ry, bob = self.geom(stage, st)
        sl = self.spine_len(stage, st)
        return (cx + 5, cy - ry - sl - 3 + bob)


# ---------------------------------------------------------- sea cucumber
class Cucumber(Plan):
    """Pepino-do-mar: a soft sausage crawling by peristalsis.
    Path: smooth -> warts -> tall papillae on the back -> branched feeding
    crown -> abyssal cucumber with glowing papillae and a sail."""
    canvas = (54, 30)
    length = 36.0

    def spine(self, stage, st):
        n = 14
        pts = []
        for q in range(n):
            u = q / (n - 1)
            x = 9.0 + u * 34.0
            y = 16.0 + math.sin(st["phase"] - u * 3.0) * 0.6
            pts.append((x, y))
        return pts

    def radius(self, stage, st, u):
        base = 4.2 + 0.25 * stage
        wave = 1.0 + 0.1 * math.sin(st["phase"] * 1.0 - u * 6.0)
        taper = math.sin(math.pi * (0.1 + 0.85 * u)) ** 0.45
        return base * wave * taper

    def draw(self, ctx, stage, st, head="", skin="", fins="", tail="", what=("rear", "back", "body", "front")):
        pts = self.spine(stage, st)
        body_r = skin_ramp(CUKE[stage], skin)
        tx, ty = pts[0]
        hx, hy = pts[-1]
        if st["act"]:
            hx += st["reach"] * 1.5
        if "rear" in what:
            lay = ctx.L["rear"]
            sw = math.sin(st["phase"]) * 0.8
            if tail == "tail_fork":
                for j in (-1, 1):
                    m = ctx.ell(tx - 1.5, ty + j * 2.2, 3.0, 1.6, rot=-j * 0.4)
                    ctx.shade(lay, m, body_r, gain=1.0, shift=-1)
            elif tail == "tail_sting":
                m = ctx.poly([(tx + 2, ty - 1.6), (tx - 7, ty + sw * 0.4), (tx + 2, ty + 1.6)])
                ctx.shade(lay, m, PAL["bone"])
            elif tail == "tail_eel":
                # Cuvierian threads: sticky white filaments
                for j in range(5):
                    p = [(tx + 1, ty + (j - 2) * 0.6)]
                    for q in range(1, 6):
                        p.append((tx + 1 - q * 2.4, ty + (j - 2) * (0.6 + q * 0.5) + math.sin(st["phase"] + q + j) * 0.8))
                    m, h = ctx.path(spline(p, 16), 0.35, 0.3)
                    lay.paint(m, PAL["white"], 5 if j % 2 else 4)
        for side in ("back", "front"):
            if side not in what:
                continue
            lay = ctx.L[side]
            far = side == "back"
            if fins == "fins_wing" and far:
                # swimming veil (like Enypniastes) over the front third
                x0 = hx - 15
                flap = math.sin(st["phase"] * 1.5) * 1.2
                top = hy - 12 - 0.5 * stage
                m = ctx.poly([(x0, hy - 2), (x0 + 13, hy - 3), (x0 + 14, top - flap), (x0 + 8, top - 1.5), (x0 + 1, top + 3 + flap)])
                lay.paint(m, ramp("#6ac8e8"), 4, alpha=200)
                lay.shift(m & (np.sin(ctx.X * 2.4) > 0.75), +1, hi=6)
                continue
            n = 4 + stage
            for j in range(n):
                u = (j + (0.5 if far else 0.0)) / n * 0.8 + 0.1
                q = u * (len(pts) - 1)
                i0 = min(int(q), len(pts) - 2)
                fx = pts[i0][0] + (pts[i0 + 1][0] - pts[i0][0]) * (q - i0)
                fy = pts[i0][1] + (pts[i0 + 1][1] - pts[i0][1]) * (q - i0)
                r = self.radius(stage, st, u)
                step = math.sin(st["phase"] * 1.0 - u * 6.0 + (0.8 if far else 0))
                a = (fx, fy + r * 0.7)
                b = (fx + step * 0.5, fy + r + 0.5 + (0.0 if far else 0.4) + max(0.0, step) * 0.5)
                col = PAL["volt"] if fins == "fins_volt" else ramp("#f0b8a0")
                m, h = ctx.path([a, b], 0.75, 0.6)
                lay.paint(m, col, 2 if far else 4)
                lay.paint(ctx.ell(b[0], b[1], 0.9, 0.55), col, 3 if far else 5)
                if fins == "fins_spiky" and j % 2 == 0:
                    lay.paint(ctx.poly([(fx - 0.5, fy + r - 0.3), (fx + 0.4, fy + r + 3.0), (fx + 0.9, fy + r - 0.3)]), PAL["coral"], 5)
        if "body" in what:
            lay = ctx.L["body"]
            # body tube with per-point radius
            segs_m = np.zeros_like(ctx.X, dtype=bool)
            hgt = np.zeros_like(ctx.X)
            for q in range(len(pts) - 1):
                u0, u1 = q / (len(pts) - 1), (q + 1) / (len(pts) - 1)
                m, h = ctx.path([pts[q], pts[q + 1]], self.radius(stage, st, u0), self.radius(stage, st, u1))
                segs_m |= m
                hgt = np.maximum(hgt, h)
            # papillae on the back (stage path)
            pap = []
            if stage >= 1:
                npap = [0, 6, 7, 8, 9][stage]
                for j in range(npap):
                    u = 0.12 + j * 0.78 / max(1, npap - 1)
                    q = u * (len(pts) - 1)
                    i0 = min(int(q), len(pts) - 2)
                    px = pts[i0][0] + (pts[i0 + 1][0] - pts[i0][0]) * (q - i0)
                    py = pts[i0][1] - self.radius(stage, st, u) * 0.85
                    tall = [0, 1.0, 2.6, 3.4, 4.2][stage] * (0.8 + 0.4 * hsh(j, 1, 5))
                    sway = math.sin(st["phase"] + j) * 0.5
                    pap.append((px, py, tall, sway))
                    m, h = ctx.path([(px, py + 0.8), (px + sway, py - tall)], 1.0, 0.45)
                    ctx.shade(lay, m, body_r, h, gain=1.1)
            ctx.shade(lay, segs_m, body_r, hgt, gain=1.4)
            if skin == "":
                warts = segs_m & (hsh(np.floor(ctx.X * 1.1), np.floor(ctx.Y * 1.1), 9) < 0.09)
                lay.shift(warts, +1, hi=6)
                belly = segs_m & (ctx.Y > 16.0 + 2.2 + 0.25 * stage)
                lay.shift(belly, +1, hi=5)
            for px, py, tall, sway in pap:
                tipc = PAL["glow"] if (stage >= 4 or skin == "skin_glow") else PAPILLA
                ctx.dot(lay, px + sway, py - tall, tipc, 5, r=0.45)
            ys, xs = np.nonzero(segs_m)
            skin_detail(ctx, lay, segs_m, skin, seed=25, center=(26.0, 16.0), radii=(17.0, 4.5 + 0.25 * stage))
            # the mouth end: oral tentacles (stage path) or a mutation
            mo = (hx + 0.6, hy)
            if head == "head_sword":
                m, h = ctx.path([(hx - 1, hy - 0.5), (hx + 9, hy - 1.5)], 1.4, 0.2)
                ctx.shade(lay, m, PAL["steel"], h)
            elif head == "head_piranha":
                op = st["open"]
                lay.paint(ctx.ell(mo[0], mo[1], 1.3, 1.9 + op * 0.8), ramp("#3a1a2a"), 1)
                for j in range(5):
                    a = -1.1 + j * 0.55
                    b0 = (mo[0] + math.cos(a) * 1.2, mo[1] + math.sin(a) * (1.8 + op))
                    lay.paint(ctx.poly([(b0[0], b0[1] - 0.4), (b0[0] + 1.8, b0[1] + math.sin(a) * 0.6), (b0[0], b0[1] + 0.4)]), PAL["white"], 6)
            elif stage >= 3 or head == "head_lure":
                # branched feeding crown
                for j in range(5 if stage >= 3 else 3):
                    a = -0.9 + j * 0.45
                    sway = math.sin(st["phase"] * 1.5 + j) * 0.25
                    ln = 3.5 + (st["reach"] * 2.0 if st["act"] else 0.0)
                    e = (mo[0] + math.cos(a + sway) * ln, mo[1] + math.sin(a + sway) * ln)
                    m, h = ctx.path([mo, e], 0.45, 0.35)
                    lay.paint(m, PAPILLA, 4)
                    for s_ in (-1, 1):
                        b = (e[0] + math.cos(a + s_ * 0.8) * 1.2, e[1] + math.sin(a + s_ * 0.8) * 1.2)
                        lay.paint(ctx.seg(e, b, 0.3), PAPILLA, 5)
            if head == "head_lure":
                lure_bulb(ctx, lay, [(hx - 3, hy - 3), (hx, hy - 9), (hx + 4, hy - 10 + math.sin(st["phase"]))], body_r)

    def lure_pos(self, stage, st):
        pts = self.spine(stage, st)
        hx, hy = pts[-1]
        if st["act"]:
            hx += st["reach"] * 1.5
        return (hx + 4, hy - 10 + math.sin(st["phase"]))


# ----------------------------------------------------------------- snail
class Snail(Plan):
    """Caramujo: a coiled shell carried on a muscular foot.
    Path: plain shell -> growth lines -> spiral knobs -> murex spines ->
    great conch with a glowing pearly aperture."""
    canvas = (44, 36)
    length = 22.0

    def draw(self, ctx, stage, st, head="", skin="", fins="", tail="", what=("rear", "back", "body", "front")):
        crawl = math.sin(st["phase"])
        sx, sy = 19.0 - crawl * 0.3, 16.0
        R = 6.8 + 0.25 * stage
        fy = sy + R * 0.75
        fx0, fx1 = sx - R - 1.5, sx + R + 3.5 + crawl * 0.8
        if st["act"]:
            fx1 += st["reach"] * 1.5
        shell_r = skin_ramp(SHELL[stage], skin)
        foot_r = FOOT
        if "rear" in what:
            lay = ctx.L["rear"]
            if tail == "tail_fork":
                for j in (-1, 1):
                    m = ctx.poly([(fx0 + 2, fy), (fx0 - 3, fy + j * 2.2 + 0.8), (fx0 - 2, fy + 0.6 + j * 0.4)])
                    ctx.shade(lay, m, foot_r, gain=1.0)
            elif tail == "tail_sting":
                m = ctx.poly([(fx0 + 2, fy - 0.8), (fx0 - 5, fy + 1.0), (fx0 + 2, fy + 2.0)])
                ctx.shade(lay, m, PAL["bone"])
            elif tail == "tail_eel":
                p = [(fx0 + 2, fy + 0.5)] + [(fx0 + 1 - q * 2.2, fy + 0.8 + math.sin(st["phase"] + q) * 0.3 * q) for q in range(1, 7)]
                m, h = ctx.path(spline(p, 16), 0.9, 0.3)
                ctx.shade(lay, m, foot_r, h)
        for side in ("back", "front"):
            if side not in what:
                continue
            lay = ctx.L[side]
            far = side == "back"
            if fins == "fins_wing":
                # parapodia: sea-butterfly wings
                flap = math.sin(st["phase"] * 1.3 + (0.6 if far else 0.0))
                bx, by = sx + 3, fy - 0.5
                tip = (bx - 4, by - 9 - flap * 2.5) if far else (bx + 6, by - 6 - flap * 2.0)
                m = ctx.poly([(bx - 2, by), tip, (bx + 5, by)])
                ctx.shade(lay, m, ramp("#6ac8e8"), gain=1.0, shift=-2 if far else 0)
                lay.paint(m, ramp("#6ac8e8"), 4, alpha=220)
                continue
            # tentacles: far eye stalk behind, near oral tentacle in front
            hx = fx1 - 1.5
            wig = math.sin(st["phase"] * 1.5 + (1 if far else 0)) * 0.6
            base = (hx - (0.8 if far else 0.0), fy - 1.2)
            tipp = (hx + 1.5 + wig, fy - 5.5 - 0.2 * stage) if far else (hx + 3.2, fy - 3.8 + wig)
            col = foot_r
            m, h = ctx.path([base, tipp], 0.6, 0.4)
            ctx.shade(lay, m, col, h, shift=-1 if far else 0)
            if fins == "fins_volt":
                ctx.dot(lay, tipp[0], tipp[1], PAL["volt"], 6, r=0.55)
                if st["i"] % 2 == 0:
                    lay.paint(ctx.seg(tipp, (tipp[0] + 1.2, tipp[1] - 1.0), 0.25), PAL["volt"], 6, outline=False)
            if fins == "fins_spiky":
                for q in (0.35, 0.7):
                    px = base[0] + (tipp[0] - base[0]) * q
                    py = base[1] + (tipp[1] - base[1]) * q
                    lay.paint(ctx.poly([(px - 0.4, py), (px - 1.8, py - 0.6), (px, py - 0.5)]), PAL["coral"], 5)
            if far:
                ctx.dot(lay, tipp[0], tipp[1], PAL["black"], 0, r=0.5)
        if "body" in what:
            lay = ctx.L["body"]
            # foot
            foot = ctx.ell((fx0 + fx1) / 2, fy + 0.8, (fx1 - fx0) / 2, 2.2)
            foot &= ctx.Y > fy - 1.8
            head_m = ctx.ell(fx1 - 2.0, fy - 0.2, 2.8, 2.4)
            ctx.shade(lay, foot | head_m, foot_r, gain=1.1)
            rip = (foot) & (np.sin(ctx.X * 2.0 - st["phase"] * 2) > 0.8) & (ctx.Y > fy + 1.5)
            lay.shift(rip, -1, lo=1)
            ctx.dot(lay, fx1 - 1.0, fy - 0.8, PAL["black"], 0, r=0.45) if head != "head_piranha" else None
            if head == "head_piranha":
                # radula proboscis with teeth
                op = st["open"]
                mx, my = fx1 + 0.4, fy + 0.2
                lay.paint(ctx.ell(mx, my, 1.2, 0.8 + op * 0.8), ramp("#3a1a1a"), 1)
                for j in range(3):
                    yy = my - 0.8 - op * 0.5 + j * (0.8 + op * 0.5)
                    lay.paint(ctx.poly([(mx - 0.2, yy - 0.3), (mx + 1.6, yy), (mx - 0.2, yy + 0.3)]), PAL["white"], 6)
            if head == "head_sword":
                # cone-snail harpoon: shoots out on the strike
                ext = 3.0 + (st["reach"] * 6.0 if st["act"] else 0.0)
                m, h = ctx.path([(fx1, fy), (fx1 + ext, fy - 0.5)], 0.55, 0.45)
                ctx.shade(lay, m, foot_r, h)
                e = (fx1 + ext, fy - 0.5)
                lay.paint(ctx.poly([(e[0] - 0.4, e[1] - 1.0), (e[0] + 2.6, e[1]), (e[0] - 0.4, e[1] + 1.0)]), PAL["steel"], 5)
            # shell: whorls seen from the side, each a nested dome that
            # winds up towards the spire (back-top)
            shell = ctx.ell(sx, sy, R, R * 0.92)
            spire_tip = (sx - R - 1.0 - 0.6 * stage, sy - R * 0.9 - 0.5 * stage)
            if stage >= 1:
                shell |= ctx.poly([(sx - R * 0.55, sy - R * 0.6), spire_tip, (sx - R * 0.05, sy - R * 0.88)])
            spines = []
            if stage >= 3:
                nsp = 5 if stage == 3 else 7
                for j in range(nsp):
                    a_ = -math.pi * 0.95 + j * math.pi * 1.1 / (nsp - 1)
                    ln = 2.0 + 0.8 * (stage - 3) + (1.0 if skin == "skin_armor" else 0.0)
                    b0 = (sx + math.cos(a_) * R * 0.85, sy + math.sin(a_) * R * 0.85)
                    e = (sx + math.cos(a_) * (R + ln), sy + math.sin(a_) * (R + ln))
                    m, h = ctx.path([b0, e], 0.8, 0.2)
                    ctx.shade(lay, m, shell_r, h, shift=-1)
                    spines.append(e)
            ctx.shade(lay, shell, shell_r, gain=1.6)
            whorls = []
            wx, wy, wr = sx, sy, R
            for q in range(3):
                wr *= 0.62
                wx -= R * 0.16 * (0.62 ** q)
                wy -= R * 0.14 * (0.62 ** q)
                w = ctx.ell(wx, wy, wr, wr * 0.92) & shell
                whorls.append((wx, wy, wr, w))
            for q, (wx, wy, wr, w) in enumerate(whorls):
                ctx.shade(lay, w, shell_r, gain=1.3, shift=1 if q % 2 == 0 else 0, lo=2, hi=6)
                ring = w & ~ctx.ell(wx, wy, wr - ctx.px * 1.1, wr * 0.92 - ctx.px * 1.1)
                lay.shift(ring & (ctx.X > wx - wr * 0.2), -2, lo=1)
            if stage >= 1 and skin == "":
                ang = np.arctan2(ctx.Y - sy, ctx.X - sx)
                rr = np.hypot(ctx.X - sx, (ctx.Y - sy) / 0.92)
                outer = shell & ~whorls[0][3]
                growth = outer & (np.abs(np.sin(ang * (6 + 2 * stage))) < 0.09) & (rr > R * 0.55)
                lay.shift(growth, -1, lo=1)
                if stage >= 2:
                    knob = outer & (np.abs(rr - R * 0.8) < 0.6) & (np.sin(ang * 8) > 0.55)
                    lay.shift(knob, +2, hi=6)
                    band_ = outer & (np.abs(rr - R * 0.62) < 0.45)
                    lay.paint(band_, ramp("#8a4a2a"), 3)
            skin_detail(ctx, lay, shell, skin, seed=29, center=(sx, sy), radii=(R, R * 0.92))
            # aperture lip where the shell meets the foot
            ap = ctx.ell(sx + R * 0.55, sy + R * 0.55, R * 0.45, R * 0.28, rot=-0.5) & shell
            lay.paint(ap, ramp("#f0d8c8"), 4)
            if stage >= 4:
                lip = ap & ~ctx.ell(sx + R * 0.55, sy + R * 0.55, R * 0.45 - ctx.px * 1.2, R * 0.28 - ctx.px * 1.2, rot=-0.5)
                lay.paint(lip, PAL["glow"], 5)
            for e in spines:
                if stage >= 4 or skin == "skin_glow":
                    ctx.dot(lay, e[0], e[1], PAL["glow"], 6, r=0.4)
            if head == "head_lure":
                lure_bulb(ctx, lay, [(fx1 - 3, fy - 1.5), (fx1 + 1, fy - 8), (fx1 + 5, fy - 9 + crawl * 0.6)], foot_r)

    def lure_pos(self, stage, st):
        crawl = math.sin(st["phase"])
        R = 6.8 + 0.25 * stage
        fy = 16.0 + R * 0.75
        fx1 = 19.0 - crawl * 0.3 + R + 3.5 + crawl * 0.8
        if st["act"]:
            fx1 += st["reach"] * 1.5
        return (fx1 + 5, fy - 9 + crawl * 0.6)


PLANS = {"ourico": Urchin, "pepino": Cucumber, "caramujo": Snail}
