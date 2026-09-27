"""Larval forms of the invertebrates (the first stages of their life cycle).

Real development, redrawn at pixel level:
  zoea (crabs, shrimp)   : glass carapace with a long dorsal spine, huge eye,
                           curled segmented abdomen, feathery rowing legs
  megalopa (crabs)       : a small crab that still has its lobster-like tail
  veliger (snail)        : a tiny shell under two ciliated swimming lobes
  pluteus (urchin)       : an easel of glass arms stiffened by white rods
  auricularia/doliolaria : the sea cucumber's ear-shaped and barrel larvae
  ephyra (jellyfish)     : an eight-armed star that pulses
  nauplius (louse)       : a shield with one red eye and three pairs of legs
  trochophore (worms)    : a spinning top with a belt of cilia

Glass tissue is translucent; mutations are drawn as larval anatomy too
(serrated mouthparts, a spine, a glowing bulb, bigger paddles...).
"""
from __future__ import annotations

import math

import numpy as np

from pro import PAL, ramp
from beasts import Plan, skin_ramp, skin_detail, segmented, spline, hsh, TAU
from beasts4 import lure_bulb
from beasts5 import tail_variants

GLASS_A = 190


def glass(hexc, dark=0.6):
    """Luminous see-through tissue: a light ramp that never goes muddy."""
    return ramp(hexc, dark=max(dark, 0.55), light_gain=0.9, sat_dark=1.25)


def tissue(ctx, lay, mask, rmp, skin, hgt=None, gain=1.3, shift=0):
    """Shade a larval body part: see-through glass unless a skin mutation
    made it solid."""
    body = skin_ramp(rmp, skin)
    if skin == "":
        # glass: flat and bright, darker only at the rim, a hot highlight
        ctx.shade(lay, mask, body, hgt, gain=gain * 0.8, shift=shift + 1, lo=3, hi=6)
        lay.alpha[mask] = GLASS_A
    else:
        ctx.shade(lay, mask, body, hgt, gain=gain, shift=shift)
    return body


def limb(ctx, lay, pts, r0, r1, col, far, fins):
    """A delicate see-through appendage (solid when mutated)."""
    m, h = ctx.path(pts, r0, r1)
    if fins:
        ctx.shade(lay, m, col, h, gain=1.0, shift=-2 if far else 0)
    else:
        lay.paint(m, col, 4 if far else 5, alpha=150 if far else 200, outline=False)
    return m


def limb_colour(fins, base):
    if fins == "fins_volt":
        return PAL["volt"]
    if fins == "fins_spiky":
        return PAL["coral"]
    if fins == "fins_wing":
        return ramp("#4ab8d8")
    return base


def head_mut(ctx, lay, head, pt, direction, rmp, st, size=1.0):
    """Head mutations at larval scale."""
    x, y = pt
    dx, dy = direction
    nx, ny = -dy, dx
    if head == "head_piranha":
        op = st["open"]
        for s_ in (-1, 1):
            b = (x + nx * s_ * 0.6 * size, y + ny * s_ * 0.6 * size)
            e = (x + dx * 2.2 * size + nx * s_ * (0.3 + op) * size, y + dy * 2.2 * size + ny * s_ * (0.3 + op) * size)
            lay.paint(ctx.poly([(b[0] - nx * s_ * 0.5, b[1] - ny * s_ * 0.5), e, (b[0] + nx * s_ * 0.5, b[1] + ny * s_ * 0.5)]),
                      PAL["white"], 6)
    elif head == "head_sword":
        ext = (5.0 + (st["reach"] * 2.0 if st["act"] else 0.0)) * size
        m, h = ctx.path([(x - dx * 0.5, y - dy * 0.5), (x + dx * ext, y + dy * ext)], 0.8 * size, 0.2)
        ctx.shade(lay, m, PAL["steel"], h)
    elif head == "head_lure":
        lure_bulb(ctx, lay, [(x - dx, y - 1.0), (x + dx * 1.5, y - 4.5 * size), (x + dx * 3.5, y - 5.0 * size + math.sin(st["phase"]) * 0.4)], rmp)


def head_lure_pos(pt, direction, st, size=1.0):
    x, y = pt
    dx, _ = direction
    return (x + dx * 3.5, y - 5.0 * size + math.sin(st["phase"]) * 0.4)


def cilia(ctx, lay, pts, st, colour=None, every=2, r=0.35):
    """A beating ciliary band: bright pixels that travel along a path."""
    if colour is None:
        colour = ramp("#e8fbff", dark=0.5)
    off = st["i"] % every
    for q in range(off, len(pts), every):
        x, y = pts[q]
        ctx.dot(lay, x, y, colour, 6, r=r)


def eye(ctx, lay, x, y, r, colour=None):
    lay.paint(ctx.ell(x, y, r, r), colour or PAL["black"], 0 if colour is None else 4)
    ctx.dot(lay, x - r * 0.35, y - r * 0.35, PAL["white"], 6, r=max(0.3, r * 0.3))


# ------------------------------------------------------------------ zoea
class Zoea(Plan):
    """Crab zoea (stage 0 of crabs) and shrimp zoea (stage 0 of shrimp)."""
    canvas = (30, 30)
    length = 15.0
    tint = {"caranguejo": "#ffc8a8", "caranguejo_yeti": "#e8f4f8", "camarao": "#ffd0c0"}
    spots = {"caranguejo": "#e04a2a", "caranguejo_yeti": "#c8b8a8", "camarao": "#ff5a3a"}

    def geom(self, st):
        bob = math.sin(st["phase"]) * 0.5
        return 15.0, 13.0 + bob, bob

    def draw(self, ctx, stage, st, head="", skin="", fins="", tail="", what=("rear", "back", "body", "front")):
        cx, cy, bob = self.geom(st)
        shrimp = self.species == "camarao"
        g = glass(self.tint[self.species])
        dot = ramp(self.spots[self.species])
        rx, ry = (5.2, 3.0) if shrimp else (4.4, 4.0)
        # abdomen path: crab zoea curls it under, shrimp zoea keeps it straight
        flick = math.sin(st["phase"] * 2.0) * (0.25 if not st["act"] else 0.5)
        if shrimp:
            ab = [(cx - rx * 0.6, cy + 0.5), (cx - rx - 2.5, cy + 0.8 + flick), (cx - rx - 6.5, cy + 1.2 + flick * 2)]
        else:
            ab = [(cx - rx * 0.4, cy + ry * 0.6), (cx - rx - 1.0, cy + ry + 1.5 + flick), (cx - rx - 0.5, cy + ry + 5.5 + flick * 2),
                  (cx - rx + 2.0, cy + ry + 7.5 + flick * 2)]
        abp = spline(ab, 16)
        tip = abp[-1]
        tdir = (tip[0] - abp[-3][0], tip[1] - abp[-3][1])
        tl = math.hypot(*tdir) or 1.0
        tdir = (tdir[0] / tl, tdir[1] / tl)
        if "rear" in what:
            lay = ctx.L["rear"]
            if tail:
                tail_variants(ctx, lay, tail, tip, tdir, g, st, scale=0.7)
        for side in ("back", "front"):
            if side not in what:
                continue
            lay = ctx.L[side]
            far = side == "back"
            col = limb_colour(fins, g)
            # two feathery rowing maxillipeds
            for j in range(2):
                row = math.sin(st["phase"] * 2 + j * 1.2 + (0.7 if far else 0)) * 0.6
                b = (cx + 0.5 + j * 1.2 - (0.8 if far else 0), cy + ry * 0.7)
                e = (b[0] - 2.0 + row * 1.5, b[1] + 4.5 + j * 0.4)
                limb(ctx, lay, [b, ((b[0] + e[0]) / 2 + 0.6, (b[1] + e[1]) / 2), e], 0.45, 0.3, col, far, fins)
                # setae fan at the tip
                for q in (-0.6, 0.0, 0.6):
                    s_e = (e[0] - 1.2 + q, e[1] + 1.4)
                    lay.paint(ctx.seg(e, s_e, 0.22), col, 3 if far else 5, outline=False)
                if fins == "fins_wing":
                    lay.paint(ctx.ell(e[0] - 0.4, e[1] + 0.8, 1.6, 0.9), col, 3 if far else 5)
                if fins == "fins_spiky":
                    lay.paint(ctx.poly([(b[0] - 0.3, b[1] + 1.5), (b[0] + 1.8, b[1] + 2.0), (b[0], b[1] + 2.3)]), PAL["coral"], 5)
                if fins == "fins_volt" and (st["i"] + j) % 2 == 0:
                    lay.paint(ctx.seg(e, (e[0] + 1.0, e[1] + 1.2), 0.25), PAL["volt"], 6, outline=False)
        if "body" in what:
            lay = ctx.L["body"]
            # spines first (behind the carapace)
            sp_r = skin_ramp(g, skin)
            if not shrimp:
                ds = spline([(cx - 0.5, cy - ry + 0.8), (cx - 1.2, cy - ry - 3.0), (cx - 2.8, cy - ry - 7.0 - 0.6 * stage)], 10)
                m, h = ctx.path(ds, 0.7, 0.15)
                tissue(ctx, lay, m, g, skin, h)
                rs = [(cx + rx * 0.5, cy + ry * 0.5), (cx + rx + 1.0, cy + ry + 3.0), (cx + rx + 1.2, cy + ry + 5.0)]
                m, h = ctx.path(spline(rs, 8), 0.5, 0.15)
                tissue(ctx, lay, m, g, skin, h)
            else:
                m, h = ctx.path([(cx + rx * 0.6, cy - 0.8), (cx + rx + 4.5, cy - 1.4)], 0.6, 0.18)
                tissue(ctx, lay, m, g, skin, h)
            m = segmented(ctx, lay, abp, 1.1, 0.55, sp_r, seg_len=1.4)
            if skin == "":
                lay.alpha[m] = GLASS_A
            # telson fork
            for s_ in (-1, 1):
                nx, ny = -tdir[1], tdir[0]
                e = (tip[0] + tdir[0] * 1.8 + nx * s_ * 1.4, tip[1] + tdir[1] * 1.8 + ny * s_ * 1.4)
                lay.paint(ctx.seg(tip, e, 0.35), sp_r, 3)
            car = ctx.ell(cx, cy, rx, ry, rot=-0.15)
            body = tissue(ctx, lay, car, g, skin, gain=1.5)
            if skin == "":
                # gut and chromatophores seen through the glass
                lay.paint(ctx.ell(cx - 0.5, cy + 0.5, rx * 0.45, ry * 0.3), ramp("#c8a050"), 3, alpha=230)
                for j in range(3 + stage):
                    a = j * 2.1 + 0.4
                    ctx.dot(lay, cx + math.cos(a) * rx * 0.55, cy + math.sin(a) * ry * 0.5, dot, 4, r=0.4)
            skin_detail(ctx, lay, car, skin, seed=51, center=(cx, cy), radii=(rx, ry))
            # the huge compound eye
            ex, ey = cx + rx * 0.72, cy - ry * 0.15
            eye(ctx, lay, ex, ey, 1.6 if not shrimp else 1.4)
            head_mut(ctx, lay, head, (cx + rx * 0.9, cy + ry * 0.35), (1.0, 0.25), body, st)

    def lure_pos(self, stage, st):
        cx, cy, bob = self.geom(st)
        rx, ry = (5.2, 3.0) if self.species == "camarao" else (4.4, 4.0)
        return head_lure_pos((cx + rx * 0.9, cy + ry * 0.35), (1.0, 0.25), st)


# -------------------------------------------------------------- megalopa
class Megalopa(Plan):
    """Crab megalopa (stage 1): a little crab still dragging a shrimp tail."""
    canvas = (40, 28)
    length = 24.0
    tint = {"caranguejo": "#ffb898", "caranguejo_yeti": "#e8f0f0"}

    def draw(self, ctx, stage, st, head="", skin="", fins="", tail="", what=("rear", "back", "body", "front")):
        bob = math.sin(st["phase"]) * 0.4
        cx, cy = 22.0, 13.0 + bob
        rx, ry = 5.0, 4.0
        g = glass(self.tint[self.species])
        kick = math.sin(st["phase"] * 2.0)
        ab = spline([(cx - rx * 0.7, cy + 0.4), (cx - rx - 3.0, cy + 0.6 + kick * 0.3), (cx - rx - 7.0, cy + 0.2 + kick * 0.6)], 16)
        tip = ab[-1]
        if "rear" in what:
            lay = ctx.L["rear"]
            if tail:
                tail_variants(ctx, lay, tail, tip, (-1.0, 0.0), g, st, scale=0.8)
        for side in ("back", "front"):
            if side not in what:
                continue
            lay = ctx.L[side]
            far = side == "back"
            col = limb_colour(fins, g)
            # swimming pleopods under the tail
            for j in range(3):
                x = cx - rx - 1.5 - j * 2.3 - (0.8 if far else 0)
                sw = math.sin(st["phase"] * 2 + j) * 0.8
                e = (x - 0.5 + sw, cy + 3.8)
                limb(ctx, lay, [(x, cy + 1.0), e], 0.35, 0.3, col, far, fins)
                if fins == "fins_wing":
                    lay.paint(ctx.ell(e[0], e[1] + 0.4, 1.2, 0.7), col, 3 if far else 5)
            # walking legs (bent, not yet used for walking)
            for j in range(3):
                bx = cx - 2.0 + j * 2.2 + (0.8 if far else 0)
                knee = (bx + 1.4, cy + ry + 1.4 + math.sin(st["phase"] + j) * 0.3)
                foot = (bx + 0.6, cy + ry + 3.8)
                limb(ctx, lay, [(bx, cy + ry * 0.6), knee, foot], 0.42, 0.3, col, far, fins)
                if fins == "fins_spiky":
                    lay.paint(ctx.poly([(knee[0] - 0.3, knee[1]), (knee[0] + 0.9, knee[1] - 1.6), (knee[0] + 0.4, knee[1] + 0.1)]), PAL["coral"], 5)
                if fins == "fins_volt" and (st["i"] + j) % 3 == 0:
                    ctx.dot(lay, knee[0], knee[1], PAL["volt"], 6, r=0.5)
            # small claw
            reach = st["reach"] if st["act"] else 0.0
            b = (cx + rx * 0.6, cy + ry * 0.4)
            e = (cx + rx + 2.4 + reach * 1.5, cy - 0.8 - (0.6 if far else 0))
            m, h = ctx.path([b, (b[0] + 1.6, b[1] + 0.6), e], 0.6, 0.9)
            ctx.shade(lay, m, g, h, shift=-2 if far else 0)
            op = st["open"]
            lay.paint(ctx.poly([(e[0], e[1] - 0.9), (e[0] + 2.0, e[1] - 0.6 - op * 0.8), (e[0] + 0.4, e[1] - 0.1)]), g, 3 if far else 5)
            lay.paint(ctx.poly([(e[0], e[1] + 0.3), (e[0] + 1.8, e[1] + 0.5 + op * 0.6), (e[0] + 0.2, e[1] + 0.9)]), g, 2 if far else 4)
        if "body" in what:
            lay = ctx.L["body"]
            sp_r = skin_ramp(g, skin)
            m = segmented(ctx, lay, ab, 1.5, 0.8, sp_r, seg_len=1.6)
            if skin == "":
                lay.alpha[m] = GLASS_A
            # tail fan
            fan = ctx.poly([(tip[0] + 0.5, tip[1] - 0.8), (tip[0] - 2.8, tip[1] - 2.2), (tip[0] - 3.2, tip[1] + 2.2), (tip[0] + 0.5, tip[1] + 0.8)])
            tissue(ctx, lay, fan, g, skin, gain=0.9, shift=-1)
            car = ctx.ell(cx, cy, rx, ry)
            body = tissue(ctx, lay, car, g, skin, gain=1.5)
            if skin == "":
                lay.paint(ctx.ell(cx - 0.8, cy + 0.3, rx * 0.4, ry * 0.3), ramp("#c89050"), 3, alpha=230)
                for j in range(4):
                    ctx.dot(lay, cx - 3 + j * 2.0, cy - ry * 0.5 + (j % 2) * 0.8, ramp("#e04a2a"), 4, r=0.4)
            skin_detail(ctx, lay, car, skin, seed=53, center=(cx, cy), radii=(rx, ry))
            # eyes on short stalks
            for s_ in (0, 1):
                ex = cx + rx - 0.6 - s_ * 1.2
                lay.paint(ctx.seg((ex - 0.6, cy - ry * 0.4), (ex, cy - ry - 0.6), 0.4), body, 3)
                eye(ctx, lay, ex, cy - ry - 0.9, 1.0)
            head_mut(ctx, lay, head, (cx + rx, cy + 0.6), (1.0, 0.0), body, st)

    def lure_pos(self, stage, st):
        bob = math.sin(st["phase"]) * 0.4
        return head_lure_pos((27.5, 13.6 + bob), (1.0, 0.0), st)


# --------------------------------------------------------------- veliger
class Veliger(Plan):
    """Snail veliger: a tiny shell swimming under two ciliated lobes."""
    canvas = (30, 30)
    length = 14.5

    def draw(self, ctx, stage, st, head="", skin="", fins="", tail="", what=("rear", "back", "body", "front")):
        bob = math.sin(st["phase"]) * 0.6
        sx, sy = 13.0, 18.0 + bob
        R = 3.8
        g = ramp("#d8a868", dark=0.35)
        vel = glass("#d8f4f0")
        beat = math.sin(st["phase"] * 2.0)
        if "rear" in what:
            lay = ctx.L["rear"]
            if tail:
                tail_variants(ctx, lay, tail, (sx - R + 0.5, sy + 0.8), (-0.8, 0.6), g, st, scale=0.7)
        for side in ("back", "front"):
            if side not in what:
                continue
            lay = ctx.L[side]
            far = side == "back"
            # velar lobes: the far one behind, the near one in front
            lx = sx + (0.8 if far else 3.6)
            ly = sy - R - 1.4 - (0.9 if far else 0.0)
            rw = 4.6 + (1.4 if fins == "fins_wing" else 0.0)
            lobe = ctx.ell(lx, ly, rw, 2.2 + beat * 0.3, rot=-0.25 if far else 0.2)
            col = limb_colour(fins, vel) if fins in ("fins_wing", "fins_volt") else vel
            ctx.shade(lay, lobe, col, gain=1.0, shift=-2 if far else 0)
            if fins == "":
                lay.alpha[lobe] = 170 if far else 205
            # ciliated rim
            rim = []
            for q in range(18):
                a = q * TAU / 18
                rim.append((lx + math.cos(a) * rw * 1.02, ly + math.sin(a) * (2.2 + beat * 0.3) * 1.02))
            cilia(ctx, lay, rim, st, PAL["volt"] if fins == "fins_volt" else None)
            if fins == "fins_spiky":
                for q in range(0, 18, 4):
                    x, y = rim[q]
                    lay.paint(ctx.poly([(x - 0.4, y), (x + (x - lx) * 0.25, y + (y - ly) * 0.5), (x + 0.4, y)]), PAL["coral"], 5)
        if "body" in what:
            lay = ctx.L["body"]
            # foot / visceral mass peeking out
            foot = ctx.ell(sx + R * 0.7, sy + 0.4, 2.2, 1.4)
            body = tissue(ctx, lay, foot, glass("#f0e0c8", dark=0.4), skin)
            shell = ctx.ell(sx, sy, R, R * 0.9)
            shell |= ctx.poly([(sx - R * 0.5, sy - R * 0.5), (sx - R - 1.2, sy - R * 0.8), (sx - R * 0.1, sy - R * 0.85)])
            sr = skin_ramp(g, skin)
            ctx.shade(lay, shell, sr, gain=1.6)
            wx, wy, wr = sx - R * 0.2, sy - R * 0.15, R * 0.55
            inner = ctx.ell(wx, wy, wr, wr * 0.9) & shell
            ctx.shade(lay, inner, sr, gain=1.2, shift=1, lo=2, hi=6)
            ring = inner & ~ctx.ell(wx, wy, wr - ctx.px * 1.1, wr * 0.9 - ctx.px * 1.1)
            lay.shift(ring & (ctx.X > wx - wr * 0.2), -2, lo=1)
            if skin == "":
                lay.alpha[shell] = 225
            skin_detail(ctx, lay, shell, skin, seed=55, center=(sx, sy), radii=(R, R * 0.9))
            # eyespots and tiny tentacles
            ctx.dot(lay, sx + R * 0.8 + 0.8, sy - 0.4, PAL["black"], 0, r=0.4)
            head_mut(ctx, lay, head, (sx + R + 1.6, sy + 0.6), (1.0, 0.1), body, st)

    def lure_pos(self, stage, st):
        bob = math.sin(st["phase"]) * 0.6
        return head_lure_pos((13.0 + 3.8 + 1.6, 18.6 + bob), (1.0, 0.1), st)


# --------------------------------------------------------------- pluteus
class Pluteus(Plan):
    """Urchin echinopluteus: glass body with long arms held open by white
    skeletal rods, edged with a ciliated band."""
    canvas = (34, 30)
    length = 14.5

    def arms(self, st):
        bob = math.sin(st["phase"]) * 0.5
        cx, cy = 14.0, 12.0 + bob
        spread = 1.0 + (0.25 * st["reach"] if st["act"] else 0.0)
        sway = math.sin(st["phase"] * 1.5) * 0.08
        out = []
        for j, (a, ln) in enumerate(((-0.55, 9.0), (0.55, 11.0), (-0.15, 12.5), (0.2, 12.0))):
            aa = (a + sway * (1 if j % 2 else -1)) * spread
            out.append(((cx + 0.5, cy + 1.0), (cx + math.cos(aa) * ln, cy + math.sin(aa) * ln)))
        return cx, cy, out

    def draw(self, ctx, stage, st, head="", skin="", fins="", tail="", what=("rear", "back", "body", "front")):
        cx, cy, arms = self.arms(st)
        g = glass("#d8c8f0")
        if "rear" in what:
            lay = ctx.L["rear"]
            if tail:
                tail_variants(ctx, lay, tail, (cx - 3.5, cy - 0.5), (-1.0, -0.2), g, st, scale=0.7)
        for side in ("back", "front"):
            if side not in what:
                continue
            lay = ctx.L[side]
            far = side == "back"
            col = limb_colour(fins, g)
            for j, (b, e) in enumerate(arms):
                if (j % 2 == 0) != far:
                    continue
                w = 0.8 + (0.5 if fins == "fins_wing" else 0.0)
                m = limb(ctx, lay, [b, e], w + 0.4, w * 0.6, col, far, fins)
                # white skeletal rod inside
                lay.paint(ctx.seg(b, e, 0.22), PAL["white"], 5 if not far else 4, outline=False)
                # cilia along the arm
                n = 8
                pts = [(b[0] + (e[0] - b[0]) * q / n, b[1] + (e[1] - b[1]) * q / n - w) for q in range(1, n + 1)]
                cilia(ctx, lay, pts, st, PAL["volt"] if fins == "fins_volt" else None)
                if fins == "fins_spiky":
                    lay.paint(ctx.poly([(e[0] - 0.5, e[1] - 0.4), (e[0] + (e[0] - b[0]) * 0.18, e[1] + (e[1] - b[1]) * 0.18), (e[0] + 0.5, e[1] + 0.4)]), PAL["coral"], 5)
        if "body" in what:
            lay = ctx.L["body"]
            body_m = ctx.ell(cx, cy, 4.2, 3.6)
            body_m |= ctx.poly([(cx - 3.0, cy - 2.6), (cx - 5.2, cy), (cx - 3.0, cy + 2.6)])
            body = tissue(ctx, lay, body_m, g, skin, gain=1.4)
            if skin == "":
                lay.paint(ctx.ell(cx - 0.6, cy + 0.2, 1.8, 1.5), ramp("#a8c860"), 3, alpha=235)   # stomach
                if stage >= 0:
                    lay.paint(ctx.ell(cx + 1.6, cy - 1.2, 0.8, 0.7), ramp("#78a850"), 4, alpha=235)  # rudiment
            skin_detail(ctx, lay, body_m, skin, seed=57, center=(cx, cy), radii=(3.4, 3.0))
            head_mut(ctx, lay, head, (cx + 3.4, cy + 0.2), (1.0, 0.0), body, st)

    def lure_pos(self, stage, st):
        cx, cy, _ = self.arms(st)
        return head_lure_pos((cx + 3.4, cy + 0.2), (1.0, 0.0), st)


# -------------------------------------------------- sea cucumber larvae
class Auricularia(Plan):
    """Stage 0: the ear-shaped auricularia with its looping ciliated band.
    Stage 1: the barrel-shaped doliolaria with five ciliary rings."""
    canvas = (34, 28)
    length = 14.5

    def draw(self, ctx, stage, st, head="", skin="", fins="", tail="", what=("rear", "back", "body", "front")):
        bob = math.sin(st["phase"]) * 0.5
        cx, cy = 16.0, 14.0 + bob
        barrel = stage >= 1
        g = glass("#f0c8b0" if not barrel else "#e8b098")
        rx, ry = (7.0, 4.6) if not barrel else (6.5, 4.2)
        squeeze = 1.0 + (0.12 * math.sin(st["phase"] * 2.0))
        if "rear" in what:
            lay = ctx.L["rear"]
            if tail:
                tail_variants(ctx, lay, tail, (cx - rx + 0.5, cy), (-1.0, 0.0), g, st, scale=0.8)
        for side in ("back", "front"):
            if side not in what:
                continue
            lay = ctx.L[side]
            far = side == "back"
            if fins == "" and not barrel:
                continue
            col = limb_colour(fins, g)
            if barrel and fins == "":
                # apical tuft of long cilia at the front
                for q in range(3):
                    a = -0.4 + q * 0.4 + math.sin(st["phase"] * 2 + q) * 0.1
                    b = (cx + rx - 0.5, cy - 0.5 + q * 0.5 - (0.5 if far else 0))
                    lay.paint(ctx.seg(b, (b[0] + math.cos(a) * 3.0, b[1] + math.sin(a) * 3.0), 0.2), ramp("#e8fbff", dark=0.5), 5, outline=False)
                continue
            # mutation limbs: paddles / spines / sparks along the flanks
            for j in range(3):
                x = cx - rx * 0.5 + j * rx * 0.5 + (0.8 if far else 0)
                y = cy + (-ry if far else ry) * 0.9
                s_ = -1 if far else 1
                if fins == "fins_wing":
                    m = ctx.ell(x, y + s_ * 1.2, 1.8, 1.0)
                    ctx.shade(lay, m, col, shift=-2 if far else 0)
                elif fins == "fins_spiky":
                    lay.paint(ctx.poly([(x - 0.7, y), (x, y + s_ * 2.6), (x + 0.7, y)]), PAL["coral"], 3 if far else 5)
                elif fins == "fins_volt":
                    ctx.dot(lay, x, y + s_ * 0.8, PAL["volt"], 6, r=0.5)
        if "body" in what:
            lay = ctx.L["body"]
            if not barrel:
                # ear shape: an ellipse with lobed edges
                ang = np.arctan2(ctx.Y - cy, ctx.X - cx)
                rr = np.hypot((ctx.X - cx) / rx, (ctx.Y - cy) / (ry * squeeze))
                lobes = 1.0 + 0.12 * np.sin(ang * 5.0 + 0.6)
                body_m = rr <= lobes
            else:
                body_m = ctx.ell(cx, cy, rx / squeeze ** 0.5, ry * squeeze)
            body = tissue(ctx, lay, body_m, g, skin, gain=1.3)
            if skin == "":
                # gut: stomach + oesophagus
                lay.paint(ctx.ell(cx - 0.5, cy + 0.4, 2.0, 1.6), ramp("#d8a050"), 3, alpha=235)
                lay.paint(ctx.seg((cx + 1.2, cy - 0.2), (cx + 3.5, cy - 1.2), 0.45), ramp("#d8a050"), 4, alpha=235)
                if not barrel:
                    pts = []
                    for q in range(40):
                        a = q * TAU / 40
                        rr_ = 0.78 + 0.14 * math.sin(a * 5.0 + 0.6 + math.pi)
                        pts.append((cx + math.cos(a) * rx * rr_, cy + math.sin(a) * ry * squeeze * rr_))
                    for q in range(0, 40, 1):
                        ctx.dot(lay, pts[q][0], pts[q][1], ramp("#f8e8d8", dark=0.5), 5, r=0.3)
                    cilia(ctx, lay, pts, st, every=4)
                else:
                    for q in range(5):
                        x = cx - rx * 0.7 + q * rx * 0.35
                        band_m = body_m & (np.abs(ctx.X - x) < 0.45)
                        lay.shift(band_m, +2, hi=6)
                        if (q + st["i"]) % 2 == 0:
                            ctx.dot(lay, x, cy - ry * squeeze - 0.2, ramp("#e8fbff", dark=0.5), 6, r=0.35)
                            ctx.dot(lay, x, cy + ry * squeeze + 0.2, ramp("#e8fbff", dark=0.5), 6, r=0.35)
            skin_detail(ctx, lay, body_m, skin, seed=59, center=(cx, cy), radii=(rx, ry))
            head_mut(ctx, lay, head, (cx + rx - 0.3, cy + 0.4), (1.0, 0.0), body, st)

    def lure_pos(self, stage, st):
        bob = math.sin(st["phase"]) * 0.5
        rx = 7.0 if stage == 0 else 6.5
        return head_lure_pos((16.0 + rx - 0.3, 14.4 + bob), (1.0, 0.0), st)


# ---------------------------------------------------------------- ephyra
class Ephyra(Plan):
    """Jellyfish ephyra: a flat eight-armed star seen slightly from above,
    each arm ending in a pair of lappets; the arms beat down on the pulse."""
    canvas = (34, 30)
    length = 14.5

    def geom(self, st):
        p = math.sin(st["phase"])
        if st["act"]:
            p = -1.0 + st["reach"] * 1.6
        return 17.0, 13.0, p

    def arm_tips(self, st):
        cx, cy, p = self.geom(st)
        tips = []
        for j in range(8):
            a = j * TAU / 8 + 0.2
            R = 7.0 + p * 0.6
            x = cx + math.cos(a) * R
            y = cy + math.sin(a) * R * 0.42 + (2.2 - p * 1.6)  # arms curl down on the stroke
            tips.append((a, x, y))
        return tips

    def draw(self, ctx, stage, st, head="", skin="", fins="", tail="", what=("rear", "back", "body", "front")):
        cx, cy, p = self.geom(st)
        g = glass("#e0c8ff")
        tips = self.arm_tips(st)
        if "rear" in what:
            lay = ctx.L["rear"]
            if tail:
                tail_variants(ctx, lay, tail, (cx, cy + 1.5), (0.0, 1.0), g, st, scale=0.8)
        for side in ("back", "front"):
            if side not in what:
                continue
            lay = ctx.L[side]
            far = side == "back"
            col = limb_colour(fins, g)
            for a, x, y in tips:
                back_arm = math.sin(a) < 0
                if back_arm != far:
                    continue
                m, h = ctx.path([(cx, cy), (x, y)], 1.6 + (0.5 if fins == "fins_wing" else 0.0), 0.9)
                ctx.shade(lay, m, col, h, shift=-2 if far else 0)
                if fins == "":
                    lay.alpha[m] = GLASS_A
                # the two lappets
                dx, dy = x - cx, y - cy
                L = math.hypot(dx, dy) or 1.0
                dx, dy = dx / L, dy / L
                for s_ in (-1, 1):
                    e = (x + dx * 1.4 - dy * s_ * 1.0, y + dy * 1.4 + dx * s_ * 1.0)
                    lay.paint(ctx.seg((x, y), e, 0.45), col, 3 if far else 5, alpha=255 if fins else GLASS_A)
                # sense organ (rhopalium) between the lappets
                ctx.dot(lay, x + dx * 0.6, y + dy * 0.6, ramp("#f0d060"), 5, r=0.35)
                if fins == "fins_spiky":
                    lay.paint(ctx.poly([(x - 0.4, y), (x + dx * 2.8, y + dy * 2.8 + 0.2), (x + 0.4, y + 0.3)]), PAL["coral"], 5)
                if fins == "fins_volt" and (st["i"] + int(a * 3)) % 3 == 0:
                    lay.paint(ctx.seg((x, y), (x + dx * 1.6 + 0.6, y + dy * 1.6 + 1.0), 0.25), PAL["volt"], 6, outline=False)
        if "body" in what:
            lay = ctx.L["body"]
            disc = ctx.ell(cx, cy, 3.4 + p * 0.3, 1.8)
            body = tissue(ctx, lay, disc, g, skin, gain=1.4)
            if skin == "":
                # the pink gastric cross in the middle
                lay.paint(disc & ((np.abs(ctx.X - cx) < 0.5) | (np.abs(ctx.Y - cy) < 0.4)) & ctx.ell(cx, cy, 2.2, 1.2),
                          ramp("#ff9ac8"), 4, alpha=235)
                lay.paint(ctx.ell(cx, cy + 0.9, 0.9, 0.9), ramp("#ff9ac8"), 3, alpha=235)  # manubrium
            skin_detail(ctx, lay, disc, skin, seed=61, center=(cx, cy), radii=(3.4, 1.8))
            head_mut(ctx, lay, head, (cx, cy + 1.5), (0.0, 1.0), body, st)
            if head == "head_lure":
                pass

    def lure_pos(self, stage, st):
        cx, cy, p = self.geom(st)
        return head_lure_pos((cx, cy + 1.5), (0.0, 1.0), st)


# -------------------------------------------------------------- nauplius
class Nauplius(Plan):
    """Sea-louse nauplius: an oval shield, one red median eye, three pairs
    of bristly swimming limbs and two long tail setae."""
    canvas = (30, 28)
    length = 13.0

    def draw(self, ctx, stage, st, head="", skin="", fins="", tail="", what=("rear", "back", "body", "front")):
        bob = math.sin(st["phase"]) * 0.5
        cx, cy = 15.0, 13.0 + bob
        rx, ry = 4.6, 3.6
        g = glass("#f0c8d0")
        if "rear" in what:
            lay = ctx.L["rear"]
            if tail:
                tail_variants(ctx, lay, tail, (cx - rx + 0.5, cy + 0.5), (-1.0, 0.1), g, st, scale=0.7)
            else:
                for s_ in (-1, 1):
                    e = (cx - rx - 4.0, cy + 0.5 + s_ * 1.6 + math.sin(st["phase"]) * 0.4)
                    lay.paint(ctx.seg((cx - rx + 0.5, cy + 0.5), e, 0.22), ramp("#f8e0e8", dark=0.5), 5, outline=False)
        for side in ("back", "front"):
            if side not in what:
                continue
            lay = ctx.L[side]
            far = side == "back"
            col = limb_colour(fins, g)
            for j, (ang, ln) in enumerate(((-0.9, 4.5), (0.2, 6.5), (0.9, 4.0))):
                row = math.sin(st["phase"] * 2 + j * 1.3 + (0.9 if far else 0)) * 0.35
                a = ang + row + (0.25 if far else 0.0)
                b = (cx + rx * 0.4 - j * 1.6, cy + (0.4 if far else 0.8))
                e = (b[0] + math.cos(a) * ln * 0.6, b[1] + math.sin(a) * ln)
                m, h = ctx.path([b, e], 0.5, 0.35)
                lay.paint(m, col, 2 if far else 4, alpha=255 if fins else GLASS_A)
                for q in (-0.5, 0.5):
                    lay.paint(ctx.seg(e, (e[0] - 1.4, e[1] + q * 1.6 + 0.8), 0.2), ramp("#f8e0e8", dark=0.5) if not fins else col,
                              3 if far else 5, outline=False)
                if fins == "fins_wing":
                    lay.paint(ctx.ell(e[0], e[1] + 0.3, 1.4, 0.8), col, 3 if far else 5)
                if fins == "fins_spiky":
                    lay.paint(ctx.poly([(e[0] - 0.4, e[1]), (e[0] + math.cos(a) * 2.0, e[1] + math.sin(a) * 2.0), (e[0] + 0.4, e[1])]), PAL["coral"], 5)
                if fins == "fins_volt" and (st["i"] + j) % 2 == 0:
                    ctx.dot(lay, e[0], e[1], PAL["volt"], 6, r=0.5)
        if "body" in what:
            lay = ctx.L["body"]
            shield = ctx.ell(cx, cy, rx, ry)
            shield |= ctx.ell(cx + rx * 0.5, cy - 0.4, rx * 0.6, ry * 0.8)
            body = tissue(ctx, lay, shield, g, skin, gain=1.5)
            if skin == "":
                lay.paint(ctx.ell(cx - 0.8, cy + 0.6, 1.8, 1.3), ramp("#c89060"), 3, alpha=235)
                for j in range(3):
                    ctx.dot(lay, cx - 2.4 + j * 1.6, cy + 1.9, ramp("#d88a4a"), 4, r=0.3)
            skin_detail(ctx, lay, shield, skin, seed=63, center=(cx, cy), radii=(rx, ry))
            # the single red naupliar eye
            lay.paint(ctx.ell(cx + rx * 0.72, cy - 0.9, 0.9, 0.8), ramp("#ff3a3a"), 4)
            ctx.dot(lay, cx + rx * 0.62, cy - 1.2, PAL["white"], 6, r=0.3)
            head_mut(ctx, lay, head, (cx + rx + 0.6, cy + 0.4), (1.0, 0.0), body, st)

    def lure_pos(self, stage, st):
        bob = math.sin(st["phase"]) * 0.5
        return head_lure_pos((15.0 + 4.6 + 0.6, 13.4 + bob), (1.0, 0.0), st)


# ----------------------------------------------------------- trochophore
class Trochophore(Plan):
    """Worm trochophore: a spinning top with a belt of beating cilia (the
    prototroch), an apical tuft, red eyespots and a see-through gut."""
    canvas = (30, 30)
    length = 13.5
    tint = {"minhoca": "#e0b8f0", "verme_tubo": "#ffc0b8"}

    def draw(self, ctx, stage, st, head="", skin="", fins="", tail="", what=("rear", "back", "body", "front")):
        bob = math.sin(st["phase"]) * 0.6
        spin = st["phase"]
        cx, cy = 15.0, 14.0 + bob
        g = glass(self.tint[self.species])
        # the larva swims forward with its apical tuft leading (tilted right)
        if "rear" in what:
            lay = ctx.L["rear"]
            if tail:
                tail_variants(ctx, lay, tail, (cx - 1.5, cy + 4.0), (-0.5, 1.0), g, st, scale=0.7)
        for side in ("back", "front"):
            if side not in what:
                continue
            lay = ctx.L[side]
            far = side == "back"
            # the prototroch belt: far half behind, near half in front
            pts = []
            for q in range(24):
                a = q * TAU / 24 + spin * 0.5
                if (math.sin(a) < 0) != far:
                    continue
                pts.append((cx + math.cos(a) * 5.4 + 0.6, cy - 0.2 + math.sin(a) * 1.6))
            col = limb_colour(fins, ramp("#f0f8ff", dark=0.5))
            belt = np.zeros_like(ctx.X, dtype=bool)
            for x, y in pts:
                belt |= ctx.ell(x, y, 0.8, 0.6)
            lay.paint(belt, col, 3 if far else 5, alpha=255 if fins else 220)
            cilia(ctx, lay, [(x + 0.0, y - 1.0) for x, y in pts], st, PAL["volt"] if fins == "fins_volt" else None)
            if fins == "fins_wing" and not far:
                for s_ in (-1, 1):
                    m = ctx.ell(cx + s_ * 6.8 + 0.6, cy + 0.3, 2.2, 1.0, rot=-0.3 * s_)
                    ctx.shade(lay, m, col, gain=1.0)
            if fins == "fins_spiky":
                for x, y in pts[::3]:
                    lay.paint(ctx.poly([(x - 0.4, y), (x + (x - cx) * 0.3, y + 1.8), (x + 0.4, y)]), PAL["coral"], 3 if far else 5)
        if "body" in what:
            lay = ctx.L["body"]
            epi = ctx.ell(cx + 0.6, cy - 0.5, 5.0, 4.6) & (ctx.Y <= cy)
            hypo = ctx.poly([(cx - 4.6, cy - 0.2), (cx + 5.8, cy - 0.2), (cx + 1.5, cy + 5.0), (cx - 0.6, cy + 5.2)])
            hypo &= ~epi
            body_m = epi | hypo | ctx.ell(cx + 0.6, cy, 5.2, 1.4)
            body = tissue(ctx, lay, body_m, g, skin, gain=1.5)
            if skin == "":
                # U-shaped gut
                gut, _ = ctx.path(spline([(cx + 2.4, cy + 0.8), (cx + 0.8, cy + 2.6), (cx - 0.6, cy + 1.0), (cx + 0.2, cy + 4.2)], 12), 0.8, 0.6)
                lay.paint(gut & body_m, ramp("#e0b060"), 3, alpha=235)
                for s_ in (-1, 1):
                    ctx.dot(lay, cx + 0.6 + s_ * 1.6, cy - 2.6, ramp("#e02a3a"), 4, r=0.45)
            skin_detail(ctx, lay, body_m, skin, seed=65, center=(cx, cy), radii=(5.0, 4.6))
            # apical tuft on top
            for q in range(3):
                a = -math.pi / 2 + (q - 1) * 0.3 + math.sin(st["phase"] * 2 + q) * 0.12
                b = (cx + 0.6, cy - 5.0)
                lay.paint(ctx.seg(b, (b[0] + math.cos(a) * 3.2, b[1] + math.sin(a) * 3.2), 0.2), ramp("#e8fbff", dark=0.5), 5, outline=False)
            head_mut(ctx, lay, head, (cx + 5.0, cy + 0.6), (1.0, 0.1), body, st)

    def lure_pos(self, stage, st):
        bob = math.sin(st["phase"]) * 0.6
        return head_lure_pos((20.0, 14.6 + bob), (1.0, 0.1), st)


# ----------------------------------------------------- glass juveniles
GLASS_OF = {"camarao": "#ffd8c8", "lula": "#ffd0dc", "lula_vampira": "#e8a8c0", "piolho": "#f8d8e8",
            "isopode": "#e8ecf8"}

# species -> {life stage: larval plan | ("adult", glass mode)}; glass mode is
# True (see-through juvenile) or "pale" (an unpigmented newborn)
LARVAL = {
    "caranguejo": {0: Zoea, 1: Megalopa}, "caranguejo_yeti": {0: Zoea, 1: Megalopa},
    "camarao": {0: Zoea, 1: ("adult", True)},
    "caramujo": {0: Veliger}, "ourico": {0: Pluteus}, "pepino": {0: Auricularia, 1: Auricularia},
    "agua_viva": {0: Ephyra}, "piolho": {0: Nauplius, 1: ("adult", True)},
    "minhoca": {0: Trochophore}, "verme_tubo": {0: Trochophore},
    "lula": {0: ("adult", True)}, "lula_vampira": {0: ("adult", True)},
    "isopode": {0: ("adult", "pale")},
}
# which anatomy stage of the adult body plan draws each life stage
ANATOMY = {
    "caranguejo": [0, 0, 1, 3, 4], "caranguejo_yeti": [0, 0, 1, 3, 4], "camarao": [0, 0, 2, 3, 4],
    "pepino": [0, 0, 2, 3, 4], "piolho": [0, 0, 2, 3, 4],
    "caramujo": [0, 1, 2, 3, 4], "ourico": [0, 1, 2, 3, 4], "agua_viva": [0, 1, 2, 3, 4],
    "minhoca": [0, 1, 2, 3, 4], "verme_tubo": [0, 1, 2, 3, 4],
}

KEEP = {"#4ab8d8", "#b85ce0", "#4a2458", "#7cc83a", "#2a3a6e", "#6ac8e8", "#9ad8ff", "#f0f8ff"}


def _hex(r):
    return "#%02x%02x%02x" % tuple(r[4])


def vitrify(species, lay, mode):
    """Turn the pigmented tissue of a juvenile drawing into glass (or pale
    newborn tissue), keeping eyes, mutation materials and lights."""
    keep = {id(PAL[k]) for k in ("black", "white", "glow", "volt", "coral", "steel", "bone", "armor")}
    g = glass(GLASS_OF.get(species, "#e8e8f0"), dark=0.4 if mode is True else 0.3)
    for i, r in enumerate(lay.ramps):
        if id(r) in keep or _hex(r) in KEEP:
            continue
        sel = lay.mat == i
        lay.ramps[i] = g
        if mode is True:
            lay.alpha[sel] = np.minimum(lay.alpha[sel], GLASS_A)


def plan_for(species, stage):
    """(plan, anatomy stage, glass mode) that draws this life stage."""
    import beasts
    spec = LARVAL.get(species, {}).get(stage)
    if spec is not None and not isinstance(spec, tuple):
        return spec(species), stage, None
    anat = ANATOMY.get(species, [0, 1, 2, 3, 4])[stage]
    return beasts.get_plan(species), anat, (spec[1] if spec else None)
