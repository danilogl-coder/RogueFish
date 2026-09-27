"""Body plans: shrimp (camarão-pistola), isopod and fish louse."""
from __future__ import annotations

import math

import numpy as np

from pro import PAL, ramp
from beasts import (Plan, skin_ramp, skin_detail, segmented, spline, pincer, curve, hsh, TAU)

SHRIMP = ramp("#ff7a5a")
SHRIMP_PALE = ramp("#ffb09a", dark=0.3)
SHRIMP_DEEP = ramp("#e04a3a")


class Shrimp(Plan):
    """Camarão-pistola, side view. Evolution path: translucent juvenile ->
    bigger snapping claw -> banded abdomen -> huge pistol claw and dorsal
    spines -> vivid adult with glowing bands and feathered antennae."""
    canvas = (58, 38)
    length = 38.0

    def colours(self, stage, skin):
        base = [SHRIMP_PALE, SHRIMP, SHRIMP, SHRIMP_DEEP, SHRIMP_DEEP][stage]
        return skin_ramp(base, skin)

    def spine(self, stage, st):
        flex = math.sin(st["phase"]) * 0.8 + (-1.6 if st["act"] and st["reach"] > 0.5 else 0.0)
        ctrl = [(38.0, 17.0), (30.0, 16.5), (22.0, 17.5 + flex * 0.3), (15.0, 20.5 + flex * 0.7), (10.0, 24.5 + flex)]
        return spline(ctrl, 30)

    def draw(self, ctx, stage, st, head="", skin="", fins="", tail="", what=("rear", "back", "body", "front")):
        pts = self.spine(stage, st)
        base = self.colours(stage, "")
        body_r = self.colours(stage, skin)
        ex, ey = pts[-1]
        if "rear" in what:
            lay = ctx.L["rear"]
            beat = math.sin(st["phase"]) * 0.25
            if tail == "tail_sting":
                # spiked telson curling down like a scorpion's
                sp = spline([(ex + 0.5, ey), (ex - 3.0, ey + 2.0), (ex - 4.0, ey + 5.5), (ex - 1.5, ey + 7.5)], 16)
                segmented(ctx, lay, sp, 1.4, 0.5, base, seg_len=1.4)
                tx, ty = sp[-1]
                lay.paint(ctx.poly([(tx - 0.6, ty - 0.4), (tx + 2.2, ty + 0.2), (tx - 0.2, ty + 0.8)]), PAL["bone"], 5)
            elif tail == "tail_eel":
                # extra abdominal segments trailing into a thin whip
                sp = spline([(ex + 1.0, ey), (ex - 4.0, ey + 2.5 + beat * 4), (ex - 9.0, ey + 1.5), (ex - 13.0, ey - 1.0 + beat * 3)], 24)
                segmented(ctx, lay, sp, 1.6, 0.4, base, seg_len=1.6)
                fx, fy = sp[-1]
                for j in (-1, 1):
                    lay.paint(ctx.poly([(fx + 0.4, fy), (fx - 2.4, fy + j * 1.6), (fx - 1.2, fy)]), base, 4)
            else:
                # tail fan: telson + uropods (fork = a huge double fan)
                big = 1.6 if tail == "tail_fork" else 1.0
                n = 5 if tail != "tail_fork" else 7
                for j in range(n):
                    a = math.pi * 0.72 + (j - (n - 1) / 2) * (0.26 + beat * 0.1)
                    ln = (4.6 - abs(j - (n - 1) / 2) * 0.35) * big
                    tip = (ex + math.cos(a) * ln, ey + math.sin(a) * ln)
                    w = 1.1 * big
                    m = ctx.poly([(ex, ey - 0.6), (tip[0] - w * math.sin(a), tip[1] + w * math.cos(a) * 0.4), tip,
                                  (tip[0] + w * math.sin(a), tip[1] - w * math.cos(a) * 0.4), (ex, ey + 0.6)])
                    ctx.shade(lay, m, base, gain=1.0, shift=-1 if j % 2 else 0)
                    lay.paint(m & ctx.seg((ex, ey), tip, 0.22), base, 5, outline=False)
                    if tail == "tail_fork":
                        ctx.dot(lay, tip[0], tip[1], PAL["glow"] if stage >= 4 else PAL["white"], 5, r=0.35)
        if "back" in what or "front" in what:
            for side in (("back",) if "back" in what else ()) + (("front",) if "front" in what else ()):
                lay = ctx.L[side]
                far = side == "back"
                # walking legs under the carapace
                for k in range(3):
                    ph = st["phase"] + k * 1.2 + (math.pi if far else 0.0)
                    bx, by = 33.0 - k * 2.6 + (0.8 if far else 0.0), 19.5
                    knee = (bx + 1.8, by + 2.6 + math.sin(ph) * 0.4)
                    foot = (bx + 0.8 + math.sin(ph) * 0.9, by + 6.0)
                    m, h = ctx.path([(bx, by), knee, foot], 0.55, 0.3)
                    ctx.shade(lay, m, base, h, shift=-2 if far else -1)
                    if fins == "fins_spiky":
                        lay.paint(ctx.poly([(knee[0] - 0.3, knee[1]), (knee[0] + 1.5, knee[1] - 0.8), (knee[0] + 0.3, knee[1] + 0.5)]), PAL["coral"], 5)
                    if fins == "fins_volt":
                        lay.paint(ctx.ell(knee[0], knee[1], 0.55, 0.55), PAL["volt"], 6)
                # swimmerets under the abdomen
                for j in range(5):
                    idx = 6 + j * 4
                    if idx >= len(pts):
                        break
                    px, py = pts[idx]
                    ph = st["phase"] * 2 + j * 0.9 + (0.6 if far else 0)
                    r = 2.0 + 0.5 * (fins == "fins_wing") * 1.6
                    tip = (px + math.sin(ph) * 1.4, py + 2.6 + r)
                    if fins == "fins_wing":
                        # swimming fans: broad feathered paddles
                        pd = ctx.ell((px + tip[0]) / 2, (py + tip[1]) / 2 + 0.5, 1.2, 2.6, rot=math.sin(ph) * 0.4)
                        ctx.shade(lay, pd, ramp("#4ab8d8"), gain=1.1, shift=-1 if far else 0)
                        lay.paint(pd & ctx.seg((px, py + 1), tip, 0.2), ramp("#4ab8d8"), 5, outline=False)
                    else:
                        m, h = ctx.path([(px, py + 1.2), tip], 0.45, 0.25)
                        ctx.shade(lay, m, base, h, shift=-2 if far else -1)
                    if fins == "fins_volt" and (st["i"] + j) % 2 == 0:
                        ctx.dot(lay, tip[0], tip[1], PAL["volt"], 6, r=0.35)
                    if fins == "fins_spiky" and not far:
                        lay.paint(ctx.poly([(px - 0.4, py - 2.6), (px - 1.2, py - 4.6), (px + 0.4, py - 2.7)]), PAL["coral"], 5)
        if "body" in what:
            lay = ctx.L["body"]
            # abdomen: segmented, tapering to the tail
            abd = segmented(ctx, lay, pts, 4.4 + 0.1 * stage, 1.8, body_r, seg_len=2.6, gain=1.4)
            if stage >= 2 and skin == "":
                bands = abd & (np.sin(ctx.X * 1.2) > 0.75)
                lay.paint(bands, PAL["glow"] if stage >= 4 else PAL["white"], 5 if stage >= 4 else 4)
            # carapace
            cx, cy = 32.5, 15.0
            cara = ctx.ell(cx, cy, 7.6, 4.8) | ctx.ell(cx + 4.5, cy + 0.5, 4.0, 3.4)
            ctx.shade(lay, cara, body_r, gain=1.5)
            skin_detail(ctx, lay, cara | abd, skin, seed=5, center=(28.0, 17.0), radii=(14.0, 6.0))
            if stage >= 3:   # dorsal spines
                for j in range(3):
                    px = cx - 3 + j * 2.4
                    lay.paint(ctx.poly([(px - 0.7, cy - 4.3), (px + 0.6, cy - 6.6), (px + 0.7, cy - 4.2)]), body_r, 5)
            # rostrum / lance
            if head == "head_sword":
                tip = (52.0, 11.0)
                lay.paint(ctx.poly([(cx + 7.0, cy - 2.6), tip, (cx + 7.0, cy - 0.8)]), PAL["steel"], 5)
                for j in range(5):
                    px = cx + 8.5 + j * 2.4
                    lay.paint(ctx.poly([(px, cy - 2.2 + j * -0.35), (px + 0.6, cy - 3.6 - j * 0.35), (px + 1.0, cy - 2.4 - j * 0.35)]), PAL["steel"], 6)
            else:
                lay.paint(ctx.poly([(cx + 7.0, cy - 2.4), (cx + 10.5, cy - 3.2), (cx + 7.0, cy - 1.0)]), body_r, 4)
            # antennae
            sway = math.sin(st["phase"]) * 1.2
            for j, (ln, up) in enumerate(((22.0, 9.0), (16.0, 3.0))):
                a = spline([(cx + 6.0, cy - 1.5), (cx + 12.0, cy - up - 2.0), (cx + 6.0 + ln * 0.9, cy - up + sway * (j + 1))], 18)
                m, h = ctx.path(a, 0.35, 0.3)
                lay.paint(m, body_r, 3)
                if stage >= 4 and head != "head_lure":
                    for q in range(3, len(a), 3):
                        lay.paint(ctx.seg(a[q], (a[q][0] + 0.6, a[q][1] + 1.0), 0.2), body_r, 5, outline=False)
                if head == "head_lure":
                    bx, by = a[-1]
                    lay.paint(ctx.ell(bx, by, 1.3, 1.3), PAL["glow"], 5)
                    ctx.dot(lay, bx - 0.4, by - 0.4, PAL["white"], 6, r=0.35)
            # stalked eye
            lay.paint(ctx.ell(cx + 6.2, cy - 2.2, 1.35, 1.35), PAL["black"], 1)
            ctx.dot(lay, cx + 5.8, cy - 2.7, PAL["white"], 6, r=0.35)
            # pistol claw (bigger each stage) and the small claw
            size = [1.5, 1.9, 2.2, 2.8, 3.1][stage]
            arm = spline([(cx + 3.0, cy + 3.0), (cx + 6.5, cy + 5.2), (cx + 9.0, cy + 4.6)], 10)
            m, h = ctx.path(arm, 1.0, 0.9)
            ctx.shade(lay, m, body_r, h, shift=-1)
            gap = 0.9 * (1.0 - st["open"]) if not st["act"] else st["open"]
            if st["act"] and st["reach"] > 0.5:
                gap = 0.0
            pincer(ctx, lay, (cx + 9.5 + size * 0.6, cy + 4.4), (1.0, -0.15), size, body_r, gap,
                   serrated=head == "head_piranha", inner=ramp("#6a1a28"))
            if st["act"] and st["open"] == 0.0:
                # the snap: a cavitation flash in front of the claw
                fx = cx + 9.5 + size * 3.2
                lay.paint(ctx.ell(fx, cy + 3.6, 1.8, 1.8) & ~ctx.ell(fx, cy + 3.6, 1.0, 1.0), PAL["glow"], 5, outline=False)
            small = ctx.ell(cx + 6.0, cy + 6.0, 1.2, 0.8)
            ctx.shade(lay, small, body_r)

    def lure_pos(self, stage, st):
        sway = math.sin(st["phase"]) * 1.2
        return (32.5 + 6.0 + 22.0 * 0.9, 15.0 - 9.0 + sway)


# --------------------------------------------------------------- isopods
ISO = ramp("#8a9ab8")
ISO_DEEP = ramp("#7a6aa0")
LOUSE = ramp("#e89aa8", dark=0.3)
EGG = ramp("#f0d060")


class Isopod(Plan):
    """Isópode gigante / Piolho-do-mar (female), side view: overlapping dorsal
    plates over many legs. Isopod path: pale pill -> ridged plates -> spines
    along the back -> armoured deep-sea giant -> Bathynomus king with glowing
    eyes. Louse path: its brood pouch swells stage by stage until it glows."""
    canvas = (46, 30)
    length = 30.0

    def __init__(self, species):
        super().__init__(species)
        self.louse = species == "piolho"

    def base(self, stage):
        if self.louse:
            return LOUSE
        return [ramp("#aab4c8"), ISO, ISO, ISO_DEEP, ISO_DEEP][stage]

    def draw(self, ctx, stage, st, head="", skin="", fins="", tail="", what=("rear", "back", "body", "front")):
        cx, cy = 22.0, 15.0 + math.sin(st["phase"] * 2) * 0.25
        rx, ry = 11.0, 5.4 if not self.louse else 4.6
        rear_up = st["reach"] * 1.5 if st["act"] else 0.0
        base = self.base(stage)
        body_r = skin_ramp(base, skin)
        tx, ty = cx - rx + 0.5, cy + 1.5
        if "rear" in what:
            lay = ctx.L["rear"]
            if tail == "tail_fork":
                for j in (-1, 1):
                    m = ctx.poly([(tx + 1, ty - 0.5), (tx - 5.5, ty + j * 2.6 - 0.8), (tx - 5.0, ty + j * 2.6 + 0.8), (tx + 1, ty + 0.8)])
                    ctx.shade(lay, m, base, gain=1.0)
            elif tail == "tail_sting":
                sp = spline([(tx + 1, ty), (tx - 3.0, ty - 1.0), (tx - 6.0, ty - 3.5)], 10)
                m, h = ctx.path(sp, 1.3, 0.2)
                ctx.shade(lay, m, PAL["bone"], h, shift=0)
            elif tail == "tail_eel":
                sw = math.sin(st["phase"]) * 1.5
                for j in (-1, 1):
                    sp = spline([(tx + 1, ty), (tx - 5.0, ty + j * 1.5 + sw), (tx - 11.0, ty + j * 2.5 - sw)], 16)
                    m, h = ctx.path(sp, 0.55, 0.25)
                    ctx.shade(lay, m, base, h, shift=-1)
            else:
                for j in (-1, 1):
                    m = ctx.poly([(tx + 1, ty - 0.3), (tx - 2.6, ty + j * 1.2), (tx + 1, ty + 0.6)])
                    ctx.shade(lay, m, base, gain=1.0)
        for side in ("back", "front"):
            if side not in what:
                continue
            lay = ctx.L[side]
            far = side == "back"
            for k in range(7):
                ph = st["phase"] + k * 0.9 + (math.pi if far else 0.0)
                lift = max(0.0, math.sin(ph)) * 0.9
                bx = cx - rx * 0.75 + k * (rx * 1.5 / 6) + (0.6 if far else 0.0)
                by = cy + ry * 0.55
                knee = (bx + 1.0, by + 1.8 - lift)
                foot = (bx + 0.2 + math.cos(ph) * 0.8, by + 3.8 - lift * 0.5)
                if self.louse:   # short hooked legs (it clings to its host)
                    knee = (bx + 1.2, by + 1.2 - lift * 0.5)
                    foot = (bx + 1.8 + math.cos(ph) * 0.4, by + 2.4)
                    if far is False and k % 2 == 1:
                        continue
                if fins == "fins_wing" and k >= 5:
                    pd = ctx.ell(foot[0], foot[1] - 0.6, 1.4, 0.8, rot=0.3)
                    ctx.shade(lay, pd, ramp("#4ab8d8"), gain=1.0, shift=-1 if far else 0)
                    continue
                m, h = ctx.path([(bx, by), knee, foot], 0.55, 0.3)
                ctx.shade(lay, m, base, h, shift=-2 if far else -1)
                if fins == "fins_spiky" and not far and k % 2 == 0:
                    lay.paint(ctx.poly([(bx - 0.4, cy - ry + 0.8), (bx - 0.8, cy - ry - 2.2), (bx + 0.4, cy - ry + 0.6)]), PAL["coral"], 5)
                if fins == "fins_volt":
                    lay.paint(ctx.ell(foot[0], foot[1], 0.5, 0.5), PAL["volt"], 6)
        if "body" in what:
            lay = ctx.L["body"]
            shell = ctx.ell(cx, cy - rear_up * 0.2, rx, ry) & (ctx.Y < cy + ry * 0.55)
            if self.louse and stage >= 1:
                pouch = ctx.ell(cx - 1.0, cy + ry * 0.7 + 0.3 * stage, rx * (0.45 + 0.07 * stage), 1.8 + 0.45 * stage)
                ctx.shade(lay, pouch, ramp("#f4c8d0", dark=0.3), gain=1.0, shift=1)
                n = 2 + stage * 2
                for j in range(n):
                    ex_ = cx - 1.0 - rx * 0.35 + j * (rx * 0.7 / max(1, n - 1))
                    ey_ = cy + ry * 0.7 + 0.3 * stage + 0.4 * ((j % 2) * 2 - 1)
                    lay.paint(ctx.ell(ex_, ey_, 0.7, 0.7), EGG if stage < 4 else PAL["glow"], 5, outline=False)
            ctx.shade(lay, shell, body_r, gain=1.6)
            # overlapping plates: seam + bright rim per segment
            nseg = 7
            for j in range(1, nseg):
                sx = cx - rx + j * (2 * rx / nseg)
                seam = shell & (np.abs(ctx.X - sx - (ctx.Y - cy) * 0.15) < 0.35 + ctx.px * 0.3)
                lay.shift(seam, -1, lo=1)
                lip = shell & (np.abs(ctx.X - sx - 0.7 - (ctx.Y - cy) * 0.15) < ctx.px * 0.55)
                lay.shift(lip, +1, hi=6)
            if stage >= 2 and not self.louse:
                for j in range(1, nseg):
                    sx = cx - rx + j * (2 * rx / nseg) + 0.5
                    top = cy - ry * math.sqrt(max(0.0, 1 - ((sx - cx) / rx) ** 2))
                    h_ = 1.0 + 0.5 * (stage - 2)
                    lay.paint(ctx.poly([(sx - 0.6, top + 0.6), (sx - 0.2, top - h_), (sx + 0.5, top + 0.6)]), body_r, 5)
            skin_detail(ctx, lay, shell, skin, seed=9, center=(cx, cy), radii=(rx, ry))
            # head
            hx, hy = cx + rx - 0.8, cy + 0.6 - rear_up * 0.4
            head_m = ctx.ell(hx, hy, 2.6, 2.4)
            ctx.shade(lay, head_m, body_r, gain=1.3, shift=1)
            glow_eye = stage >= 4
            lay.paint(ctx.ell(hx + 0.6, hy - 0.8, 1.0 if not self.louse else 1.2, 0.9), PAL["glow"] if glow_eye else PAL["black"], 5 if glow_eye else 1)
            ctx.dot(lay, hx + 0.3, hy - 1.1, PAL["white"], 6, r=0.3)
            # antennae
            sway = math.sin(st["phase"]) * 0.8
            for j, (ln, up) in enumerate(((7.0, 3.0), (4.5, 0.5))):
                a = spline([(hx + 1.5, hy - 1.0), (hx + 3.5, hy - up - 1.5), (hx + 1.5 + ln, hy - up + sway)], 10)
                m, h = ctx.path(a, 0.35, 0.25)
                lay.paint(m, body_r, 3)
                if head == "head_lure" and j == 0:
                    bx, by = a[-1]
                    lay.paint(ctx.ell(bx, by, 1.2, 1.2), PAL["glow"], 5)
            if head == "head_piranha":
                # mandibles: two curved blades at the front of the head
                op = 0.3 + st["open"] * 0.7
                for sgn in (-1, 1):
                    sp = spline([(hx + 1.8, hy + 1.0), (hx + 3.6, hy + 1.2 + sgn * op * 1.2), (hx + 4.6, hy + 0.6 - sgn * 0.4)], 8)
                    m, h = ctx.path(sp, 0.7, 0.2)
                    ctx.shade(lay, m, ramp("#3a2a30"), h, shift=1)
            elif head == "head_sword":
                sp = spline([(hx + 1.4, hy - 1.4), (hx + 4.0, hy - 3.0), (hx + 7.5, hy - 3.4)], 10)
                m, h = ctx.path(sp, 0.9, 0.12)
                ctx.shade(lay, m, PAL["steel"], h, shift=1)

    def lure_pos(self, stage, st):
        sway = math.sin(st["phase"]) * 0.8
        return (22.0 + 11.0 - 0.8 + 1.5 + 7.0, 15.0 + 0.6 - 3.0 + sway)


PLANS = {"camarao": Shrimp, "isopode": Isopod, "piolho": Isopod}
