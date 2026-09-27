"""Body plans: squid, vampire squid and jellyfish."""
from __future__ import annotations

import math

import numpy as np

from pro import PAL, ramp
from beasts import Plan, skin_ramp, skin_detail, segmented, spline, hsh, TAU

SQUID = [ramp("#ffb0c0", dark=0.3), ramp("#ff8aa0"), ramp("#f07088"), ramp("#d8485e"), ramp("#b02a44")]
VAMP = [ramp("#8a2a48"), ramp("#7a1e3a"), ramp("#7a1e3a"), ramp("#6a1830"), ramp("#5a1228")]
JELLY = [ramp("#d8b8ff", dark=0.3), ramp("#c8a0ff"), ramp("#c090f8"), ramp("#b07ef0"), ramp("#a068f0")]


class Squid(Plan):
    """Lula (and Lula-Vampira), side view: arms forward, mantle behind.
    Squid path: small plain -> bigger fins -> chromatophore spots -> hooked
    tentacle clubs -> colossal with a glowing eye. Vampire squid path: a
    cloak of web grows between the arms, white arm tips, photophores, and at
    the last stage the whole cloak rim glows."""
    canvas = (60, 34)
    length = 40.0

    def __init__(self, species):
        super().__init__(species)
        self.vamp = species == "lula_vampira"

    def geom(self, stage, st):
        pulse = math.sin(st["phase"]) * 0.5
        cy = 16.0
        if self.vamp:
            return dict(mx=17.0, my=cy, mrx=10.0, mry=5.8 + pulse * 0.3, hx=28.0, ax0=30.0, cy=cy, pulse=pulse)
        return dict(mx=16.0, my=cy, mrx=12.0, mry=4.6 + pulse * 0.25, hx=29.0, ax0=31.0, cy=cy, pulse=pulse)

    def base(self, stage):
        return (VAMP if self.vamp else SQUID)[stage]

    def draw(self, ctx, stage, st, head="", skin="", fins="", tail="", what=("rear", "back", "body", "front")):
        g = self.geom(stage, st)
        base = self.base(stage)
        body_r = skin_ramp(base, skin)
        mx, my, mrx, mry = g["mx"], g["my"], g["mrx"], g["mry"]
        tip = (mx - mrx + 0.4, my)
        if "rear" in what:
            lay = ctx.L["rear"]
            sw = math.sin(st["phase"]) * 1.2
            if tail == "tail_fork":
                for j in (-1, 1):
                    sp = spline([(tip[0] + 1.5, my + j * 0.8), (tip[0] - 2.5, my + j * 2.2 + sw * 0.3), (tip[0] - 5.0, my + j * 3.5)], 10)
                    m, h = ctx.path(sp, 1.4, 0.3)
                    ctx.shade(lay, m, base, h)
            elif tail == "tail_sting":
                m = ctx.poly([(tip[0] + 1.5, my - 1.3), (tip[0] - 6.5, my + sw * 0.3), (tip[0] + 1.5, my + 1.3)])
                ctx.shade(lay, m, PAL["bone"], gain=1.0)
            elif tail == "tail_eel":
                for j in (-1, 0, 1):
                    sp = spline([(tip[0] + 1, my + j * 0.6), (tip[0] - 6, my + j * 2 + sw), (tip[0] - 14, my + j * 3 - sw)], 16)
                    m, h = ctx.path(sp, 0.45, 0.25)
                    lay.paint(m, base, 3 if j else 4)
                    fx, fy = sp[-1]
                    ctx.dot(lay, fx, fy, PAL["glow"], 5, r=0.4)
        for side in ("back", "front"):
            if side not in what:
                continue
            lay = ctx.L[side]
            far = side == "back"
            flap = math.sin(st["phase"] * 2) * 0.6
            if self.vamp:
                # ear fins on top of the mantle
                fx, fy = mx - mrx * 0.35 + (0.8 if far else 0.0), my - mry + 0.8
                big = 1.0 + 0.12 * stage + (0.9 if fins == "fins_wing" else 0.0)
                fin = ctx.ell(fx, fy - 1.4 * big, 1.8 * big, 1.2 * big, rot=-0.6 + flap * 0.3)
            else:
                # rhomboid fins at the rear of the mantle
                big = 1.0 + 0.1 * stage + (0.45 if fins == "fins_wing" else 0.0)
                rx0 = mx - mrx * 0.55
                fin = ctx.poly([(rx0 + 5.5 * big, my - (0.4 if far else -0.4)), (rx0 - 1.0, my - (4.8 + flap) * big * (1 if far else -1)),
                                (rx0 - 5.0 * big, my)])
            fr = ramp("#4ab8d8") if fins == "fins_wing" else base
            ctx.shade(lay, fin, fr, gain=1.0, shift=-2 if far else 0)
            if fins == "fins_spiky":
                ys, xs = np.nonzero(fin)
                if len(xs):
                    for q in range(0, len(xs), max(1, len(xs) // 5)):
                        px, py = xs[q] / ctx.k, ys[q] / ctx.k
                        lay.paint(ctx.poly([(px - 0.4, py), (px - 0.8, py - 1.8 if far else py + 1.8), (px + 0.4, py)]), PAL["coral"], 5)
            if fins == "fins_volt":
                edge = fin & ~np.roll(fin, 1, axis=0)
                lay.paint(edge | (fin & (hsh(np.floor(ctx.X), np.floor(ctx.Y), st["i"]) < 0.06)), PAL["volt"], 6, outline=False)
        if "body" in what:
            lay = ctx.L["body"]
            ax0 = g["ax0"]
            sway = math.sin(st["phase"])
            reach = st["reach"] if st["act"] else 0.0
            # arms (8, drawn as a bundle) and two long tentacles
            arm_len = 10.0 + 1.0 * stage
            for j in range(6):
                off = (j - 2.5) * 0.9
                sp = spline([(ax0, my + off * 0.5), (ax0 + arm_len * 0.5, my + off + sway * 0.8), (ax0 + arm_len + reach * 3, my + off * 1.4 - sway * 0.6)], 12)
                m, h = ctx.path(sp, 1.0, 0.35)
                ctx.shade(lay, m, body_r, h, shift=-1 if j % 2 else 0)
                if self.vamp and stage >= 2:
                    fx, fy = sp[-1]
                    ctx.dot(lay, fx, fy, PAL["white"] if stage < 4 else PAL["glow"], 5, r=0.45)
                if head == "head_piranha" and j % 2 == 0:
                    for q in range(3, len(sp), 3):
                        lay.paint(ctx.poly([(sp[q][0] - 0.3, sp[q][1] + 0.4), (sp[q][0] + 0.2, sp[q][1] + 1.4), (sp[q][0] + 0.4, sp[q][1] + 0.3)]), PAL["white"], 6)
            if self.vamp and stage >= 1:
                # cloak: the web between the arms
                web = ctx.poly([(ax0 - 1.0, my - 2.5), (ax0 + arm_len * 0.75, my - 3.5 - sway), (ax0 + arm_len * 0.9, my + sway),
                                (ax0 + arm_len * 0.75, my + 3.5 + sway), (ax0 - 1.0, my + 2.5)])
                lay.paint(web, base, 2)
                if stage >= 4:
                    rim = web & ~ctx.poly([(ax0 - 0.5, my - 2.0), (ax0 + arm_len * 0.7, my - 2.8 - sway), (ax0 + arm_len * 0.8, my + sway),
                                          (ax0 + arm_len * 0.7, my + 2.8 + sway), (ax0 - 0.5, my + 2.0)])
                    lay.paint(rim, PAL["glow"], 4)
            tl = arm_len + 5.0 + (2.0 if stage >= 3 else 0.0)
            for j in (-1, 1):
                end = (ax0 + tl + reach * 5, my + j * 2.0 - sway * j)
                if head == "head_sword":
                    end = (ax0 + tl + 7.0 + reach * 5, my + j * 1.2)
                sp = spline([(ax0, my + j * 0.4), (ax0 + tl * 0.5, my + j * 1.5 + sway), end], 14)
                m, h = ctx.path(sp, 0.55, 0.45)
                ctx.shade(lay, m, body_r, h, shift=-1)
                ex, ey = end
                if head == "head_sword":
                    lay.paint(ctx.poly([(ex - 1.2, ey - 0.9), (ex + 3.4, ey), (ex - 1.2, ey + 0.9)]), PAL["steel"], 5)
                elif stage >= 3 or head == "head_piranha":
                    club = ctx.ell(ex, ey, 1.8, 1.0)
                    ctx.shade(lay, club, body_r, gain=1.1)
                    for q in (-1, 0, 1):
                        lay.paint(ctx.poly([(ex + q * 0.8 - 0.3, ey + 0.7), (ex + q * 0.8, ey + 1.8), (ex + q * 0.8 + 0.3, ey + 0.7)]), PAL["white"], 6)
            if head == "head_lure":
                sp = spline([(ax0, my - 1.0), (ax0 + 5, my - 6.5), (ax0 + 11, my - 5.0 + sway)], 12)
                m, h = ctx.path(sp, 0.35, 0.3)
                lay.paint(m, body_r, 3)
                bx, by = sp[-1]
                lay.paint(ctx.ell(bx, by, 1.4, 1.4), PAL["glow"], 5)
                ctx.dot(lay, bx - 0.4, by - 0.4, PAL["white"], 6, r=0.35)
            # mantle
            mantle = ctx.ell(mx, my, mrx, mry)
            if not self.vamp:
                mantle |= ctx.poly([(mx - mrx + 0.3, my - 1.2), (mx - mrx - 2.0, my), (mx - mrx + 0.3, my + 1.2)])
            ctx.shade(lay, mantle, body_r, gain=1.5)
            if stage >= 2 and skin == "":
                # chromatophores (squid) / photophores (vampire)
                spots = mantle & (hsh(np.floor(ctx.X * 0.8), np.floor(ctx.Y * 0.8), 7) < (0.1 if not self.vamp else 0.05))
                lay.paint(spots, PAL["glow"] if (self.vamp or stage >= 4) else ramp("#8a1a30"), 5 if self.vamp else 2)
            skin_detail(ctx, lay, mantle, skin, seed=13, center=(mx, my), radii=(mrx, mry))
            # head + eye
            hx = g["hx"]
            head_m = ctx.ell(hx, my, 3.2, 3.0)
            ctx.shade(lay, head_m, body_r, gain=1.3, shift=1)
            er = 1.5 + (0.6 if stage >= 4 else 0.0) + (0.4 if self.vamp else 0.0)
            eye_c = ramp("#3a8cff") if self.vamp else (PAL["glow"] if stage >= 4 else ramp("#f0d060"))
            lay.paint(ctx.ell(hx + 0.4, my - 0.6, er, er), eye_c, 4)
            lay.paint(ctx.ell(hx + 0.7, my - 0.6, er * 0.5, er * 0.6), PAL["black"], 0)
            ctx.dot(lay, hx - 0.1, my - 1.3, PAL["white"], 6, r=0.35)
            if head == "head_piranha":
                # the beak peeking between the arms
                op = st["open"]
                lay.paint(ctx.poly([(ax0 - 0.5, my - 0.6), (ax0 + 2.2, my - 0.3 - op * 0.8), (ax0 - 0.2, my + 0.2)]), ramp("#2a1a20"), 3)
                lay.paint(ctx.poly([(ax0 - 0.5, my + 0.4), (ax0 + 1.8, my + 0.8 + op * 0.8), (ax0 - 0.2, my + 0.9)]), ramp("#2a1a20"), 2)

    def lure_pos(self, stage, st):
        g = self.geom(stage, st)
        return (g["ax0"] + 11, g["my"] - 5.0 + math.sin(st["phase"]))


# ------------------------------------------------------------ jellyfish
class Jelly(Plan):
    """Água-viva: translucent bell pulsing over oral arms and tentacles.
    Path: small clear bell -> more tentacles -> radial canals and gonads ->
    scalloped rim and longer tentacles -> crown jelly with a glowing rim."""
    canvas = (40, 50)
    length = 26.0

    def geom(self, stage, st):
        p = math.sin(st["phase"])
        if st["act"]:
            p = -1.0 + st["reach"] * 1.6
        return 20.0, 13.0, 9.0 + 0.3 * stage + p * 0.9, 6.5 + 0.2 * stage - p * 0.7, p

    def draw(self, ctx, stage, st, head="", skin="", fins="", tail="", what=("rear", "back", "body", "front")):
        cx, cy, rx, ry, p = self.geom(stage, st)
        base = JELLY[stage]
        body_r = skin_ramp(base, skin)
        rim_y = cy + 0.5
        if "rear" in what:
            lay = ctx.L["rear"]
            n = 2 if tail == "tail_fork" else 1
            if tail == "tail_sting":
                sp = spline([(cx, rim_y), (cx + 1.5, rim_y + 10), (cx - 1.0, rim_y + 20 + p)], 18)
                m, h = ctx.path(sp, 1.2, 0.5)
                ctx.shade(lay, m, base, h)
                tx, ty = sp[-1]
                lay.paint(ctx.poly([(tx - 1.6, ty - 1.0), (tx, ty + 3.0), (tx + 1.6, ty - 1.0)]), PAL["bone"], 5)
            elif tail == "tail_eel":
                sp = spline([(cx, rim_y), (cx + 3.0, rim_y + 10), (cx - 3.0, rim_y + 22), (cx + 2.0, rim_y + 34 + p)], 30)
                m, h = ctx.path(sp, 1.3, 0.35)
                ctx.shade(lay, m, base, h, shift=-1)
            else:
                # frilly oral arms (fork: two wide pairs)
                for j in range(4 if n == 1 else 6):
                    off = (j - (1.5 if n == 1 else 2.5)) * (1.3 if n == 1 else 1.6)
                    sw = math.sin(st["phase"] + j) * 1.0
                    ln = 9.0 + 1.5 * stage
                    sp = spline([(cx + off * 0.4, rim_y), (cx + off + sw, rim_y + ln * 0.5), (cx + off * 0.7 - sw, rim_y + ln)], 14)
                    m, h = ctx.path(sp, 1.1 if n == 1 else 1.5, 0.5)
                    ctx.shade(lay, m, base, h, shift=-1 if j % 2 else 0)
                    frill = m & (np.sin(ctx.Y * 3.0) > 0.6)
                    lay.shift(frill, +1, hi=6)
        for side in ("back", "front"):
            if side not in what:
                continue
            lay = ctx.L[side]
            far = side == "back"
            nt = 2 + (stage + (0 if far else 1)) // 2
            for j in range(nt):
                t = (j + (0.5 if far else 0.0)) / max(1, nt - 1 + (0.5 if far else 0.0))
                x0 = cx - rx * 0.85 + t * rx * 1.7
                ln = (10.0 + 2.5 * stage) * (0.55 if fins == "fins_wing" else 1.0)
                pts = []
                for q in range(7):
                    u = q / 6.0
                    wav = math.sin(st["phase"] * 1.0 + u * 4.0 + j * 1.7 + (1.3 if far else 0.0)) * (0.4 + 1.6 * u)
                    pts.append((x0 + wav + (x0 - cx) * 0.15 * u, rim_y + u * ln))
                sp = spline(pts, 22)
                m, h = ctx.path(sp, 0.45, 0.22)
                lay.paint(m, base, 2 if far else 4, alpha=190 if far else 230)
                if fins == "fins_spiky":
                    for q in range(4, len(sp), 5):
                        bx, by = sp[q]
                        lay.paint(ctx.ell(bx, by, 0.55, 0.55), PAL["coral"], 5)
                if fins == "fins_volt":
                    for q in range(3 + (st["i"] % 3), len(sp), 6):
                        bx, by = sp[q]
                        ctx.dot(lay, bx, by, PAL["volt"], 6, r=0.4)
                    if (st["i"] + j) % 3 == 0:
                        ex, ey = sp[-1]
                        zz = [(ex, ey), (ex + 1.0, ey + 1.0), (ex - 0.4, ey + 2.0)]
                        lay.paint(ctx.seg(zz[0], zz[1], 0.3) | ctx.seg(zz[1], zz[2], 0.3), PAL["volt"], 6, outline=False)
            if fins == "fins_wing" and not far:
                # velum: a translucent frilled skirt around the rim
                skirt = ctx.poly([(cx - rx - 1.5, rim_y - 0.5), (cx + rx + 1.5, rim_y - 0.5), (cx + rx * 0.8, rim_y + 4.0 + p),
                                  (cx - rx * 0.8, rim_y + 4.0 + p)])
                lay.paint(skirt, ramp("#9ad8ff"), 4, alpha=170)
                scal = skirt & (np.sin(ctx.X * 2.2) > 0.7)
                lay.shift(scal, +1, hi=6)
        if "body" in what:
            lay = ctx.L["body"]
            bell = ctx.ell(cx, cy, rx, ry) & (ctx.Y <= rim_y)
            if stage >= 3:   # scalloped rim
                bell |= (ctx.Y > rim_y - 0.2) & (ctx.Y < rim_y + 1.2) & (np.abs(ctx.X - cx) < rx) & (np.sin((ctx.X - cx) * 1.6) > -0.2)
            if head == "head_sword":
                bell |= ctx.poly([(cx - 1.4, cy - ry + 0.6), (cx, cy - ry - 7.0), (cx + 1.4, cy - ry + 0.6)])
            ctx.shade(lay, bell, body_r, gain=1.3)
            lay.alpha[bell] = 225
            if head == "head_sword":
                lay.paint(bell & (ctx.Y < cy - ry + 0.5), PAL["steel"], 5)
            # inner structure: radial canals + gonads (stage 2+)
            if stage >= 2 and skin == "":
                for j in range(4):
                    a = math.pi + (j + 0.5) * math.pi / 4
                    lay.paint(bell & ctx.seg((cx, cy - 0.5), (cx + math.cos(a) * rx * 0.9, cy + math.sin(a) * ry * 0.9 * -1 * -1), 0.3), body_r, 5)
                ring = bell & (np.abs(np.hypot((ctx.X - cx) / (rx * 0.4), (ctx.Y - cy + 0.5) / (ry * 0.4)) - 1.0) < 0.25)
                lay.paint(ring, ramp("#ff9ac8"), 4)
            if stage >= 4:
                for j in range(9):
                    x = cx - rx * 0.9 + j * rx * 1.8 / 8
                    ctx.dot(lay, x, rim_y - 0.2, PAL["glow"], 6, r=0.4)
            skin_detail(ctx, lay, bell, skin, seed=17, center=(cx, cy), radii=(rx, ry))
            if head == "head_piranha":
                for j in range(7):
                    x = cx - rx * 0.8 + j * rx * 1.6 / 6
                    lay.paint(ctx.poly([(x - 0.5, rim_y - 0.4), (x, rim_y + 1.6 + st["open"] * 0.6), (x + 0.5, rim_y - 0.4)]), PAL["white"], 6)
            if head == "head_lure":
                sp = spline([(cx, cy - ry + 0.5), (cx + 2.0, cy - ry - 4.0), (cx + 5.0, cy - ry - 5.0 + p)], 10)
                m, h = ctx.path(sp, 0.4, 0.3)
                lay.paint(m, body_r, 3)
                bx, by = sp[-1]
                lay.paint(ctx.ell(bx, by, 1.4, 1.4), PAL["glow"], 5)
                ctx.dot(lay, bx - 0.4, by - 0.4, PAL["white"], 6, r=0.35)
            # highlight on the dome
            lay.paint(bell & ctx.ell(cx - rx * 0.35, cy - ry * 0.45, rx * 0.25, ry * 0.18), PAL["white"], 5, outline=False)

    def lure_pos(self, stage, st):
        cx, cy, rx, ry, p = self.geom(stage, st)
        return (cx + 5.0, cy - ry - 5.0 + p)


PLANS = {"lula": Squid, "lula_vampira": Squid, "agua_viva": Jelly}
