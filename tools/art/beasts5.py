"""Body plans: bobbit worm, tube worm, sea turtle and sea otter."""
from __future__ import annotations

import math

import numpy as np

from pro import PAL, ramp
from beasts import Plan, skin_ramp, skin_detail, segmented, spline, hsh, TAU
from beasts4 import lure_bulb

BOBBIT = [ramp("#e08a9a", dark=0.3), ramp("#c86a8a"), ramp("#a85a90"), ramp("#8a4a98"), ramp("#6a3a98")]
TUBE = ramp("#e8e0d0", dark=0.35)
PLUME = [ramp("#ff7a6a"), ramp("#ff5a4a"), ramp("#f04040"), ramp("#e02a3a"), ramp("#d0204a")]
WORM_PINK = ramp("#e8a8a0", dark=0.3)
TURTLE_SHELL = [ramp("#8ab06a", dark=0.3), ramp("#7a9a5a"), ramp("#6a8a4a"), ramp("#5a7a44"), ramp("#4a6a4a")]
TURTLE_SKIN = [ramp("#b8c88a", dark=0.3), ramp("#a8b87a"), ramp("#98a86a"), ramp("#889860"), ramp("#7a8a60")]
OTTER = [ramp("#b8906a", dark=0.3), ramp("#9a6a4a"), ramp("#8a5a3a"), ramp("#7a4a30"), ramp("#6a4030")]
OTTER_FACE = [ramp("#e8d8c0", dark=0.3), ramp("#d8c0a0"), ramp("#d0b490"), ramp("#d8c8b0"), ramp("#f0e8dc", dark=0.3)]


def along(pts, u):
    q = u * (len(pts) - 1)
    i0 = min(int(q), len(pts) - 2)
    f = q - i0
    x = pts[i0][0] + (pts[i0 + 1][0] - pts[i0][0]) * f
    y = pts[i0][1] + (pts[i0 + 1][1] - pts[i0][1]) * f
    dx, dy = pts[i0 + 1][0] - pts[i0][0], pts[i0 + 1][1] - pts[i0][1]
    L = math.hypot(dx, dy) or 1.0
    return x, y, dx / L, dy / L


def tail_variants(ctx, lay, tail, tip, direction, rmp, st, scale=1.0):
    """Shared tail mutations for worm-like plans, drawn along direction."""
    tx, ty = tip
    dx, dy = direction
    nx, ny = -dy, dx
    sw = math.sin(st["phase"]) * 0.8
    if tail == "tail_fork":
        for j in (-1, 1):
            e = (tx + dx * 4 * scale + nx * j * 2.6 * scale, ty + dy * 4 * scale + ny * j * 2.6 * scale + sw * 0.3)
            m, h = ctx.path([(tx, ty), e], 0.9 * scale, 0.3)
            ctx.shade(lay, m, rmp, h)
    elif tail == "tail_sting":
        e = (tx + dx * 6 * scale, ty + dy * 6 * scale + sw * 0.2)
        m = ctx.poly([(tx + nx * 1.4 * scale, ty + ny * 1.4 * scale), e, (tx - nx * 1.4 * scale, ty - ny * 1.4 * scale)])
        ctx.shade(lay, m, PAL["bone"])
        lay.paint(ctx.seg(e, (e[0] - dx * 1.5, e[1] - dy * 1.5), 0.35), ramp("#b85ce0"), 5)
    elif tail == "tail_eel":
        p = [(tx + dx * q * 2.2 * scale + nx * math.sin(st["phase"] + q) * 0.35 * q, ty + dy * q * 2.2 * scale + ny * math.sin(st["phase"] + q) * 0.35 * q) for q in range(8)]
        m, h = ctx.path(spline(p, 18), 0.9 * scale, 0.25)
        ctx.shade(lay, m, rmp, h, shift=-1)


# ------------------------------------------------------------ bobbit worm
class Bobbit(Plan):
    """Minhoca (bobbit worm): a long iridescent polychaete with scissor jaws.
    Path: pink juvenile -> iridescent bands -> bristle tufts -> five long
    antennae and huge jaws -> giant with glowing segments."""
    canvas = (68, 28)
    length = 46.0

    def spine(self, stage, st):
        n = 18
        amp = 1.4
        lunge = st["reach"] * 3.0 if st["act"] else 0.0
        return [(8.0 + u * 44.0 + (lunge * u ** 3), 14.0 + math.sin(st["phase"] - u * 5.0) * amp * (0.4 + 0.6 * (1 - u)))
                for u in (q / (n - 1) for q in range(n))]

    def rad(self, stage, u):
        return (2.9 + 0.3 * stage) * (0.55 + 0.45 * math.sin(math.pi * min(1.0, 0.15 + u)) ** 0.5)

    def draw(self, ctx, stage, st, head="", skin="", fins="", tail="", what=("rear", "back", "body", "front")):
        pts = self.spine(stage, st)
        body_r = skin_ramp(BOBBIT[stage], skin)
        if "rear" in what:
            lay = ctx.L["rear"]
            x, y, dx, dy = along(pts, 0.0)
            if tail:
                tail_variants(ctx, lay, tail, (x + 1, y), (-dx, -dy), body_r, st)
            else:
                for j in (-1, 1):
                    m, h = ctx.path([(x + 1, y), (x - 2.5, y + j * 1.4 + math.sin(st["phase"]) * 0.4)], 0.4, 0.25)
                    lay.paint(m, body_r, 3)
        for side in ("back", "front"):
            if side not in what or stage < 2 and fins == "":
                continue
            lay = ctx.L[side]
            far = side == "back"
            n = 6 + stage
            for j in range(n):
                u = 0.08 + (j + (0.5 if far else 0.0)) * 0.8 / n
                x, y, dx, dy = along(pts, u)
                r = self.rad(stage, u)
                nx, ny = -dy, dx
                s_ = -1 if far else 1
                bx, by = x + nx * r * 0.8 * s_, y + ny * r * 0.8 * s_
                wig = math.sin(st["phase"] * 2 + j) * 0.4
                if fins == "fins_wing":
                    m = ctx.ell(bx + nx * s_ * 1.1 + wig * dx, by + ny * s_ * 1.1, 1.2, 0.8, rot=math.atan2(dy, dx) + 0.4 * s_)
                    ctx.shade(lay, m, ramp("#4ab8d8"), gain=1.0, shift=-2 if far else 0)
                    continue
                col = PAL["coral"] if fins == "fins_spiky" else (PAL["volt"] if fins == "fins_volt" else ramp("#f0d0a0", dark=0.3))
                ln = 1.2 + (1.4 if fins == "fins_spiky" else 0.0) + 0.2 * stage
                for q in ((0.0,) if far else (-0.3, 0.3)):
                    e = (bx + (nx * s_ + dx * q) * ln + wig * dx, by + (ny * s_ + dy * q) * ln)
                    lay.paint(ctx.seg((bx, by), e, 0.22), col, 3 if far else 5, outline=far)
                if fins == "fins_volt" and (st["i"] + j) % 4 == 0:
                    ctx.dot(lay, bx + nx * s_ * ln, by + ny * s_ * ln, PAL["volt"], 6, r=0.5)
        if "body" in what:
            lay = ctx.L["body"]
            m = segmented(ctx, lay, pts, self.rad(stage, 0.0) * 0.8, self.rad(stage, 1.0), body_r, seg_len=1.6 + 0.15 * stage)
            # iridescent sheen travelling along the body
            if stage >= 1 and skin == "":
                sheen = m & (np.sin(ctx.X * 0.6 - st["phase"] * 2) > 0.75) & (ctx.Y < 14.0 + math.sin(st["phase"]) * 0.5)
                lay.paint(sheen, ramp("#8ae0c8"), 4)
            if stage >= 4 and skin == "":
                for q in range(6):
                    x, y, _, _ = along(pts, 0.1 + q * 0.14)
                    ctx.dot(lay, x, y + self.rad(stage, 0.1 + q * 0.14) * 0.4, PAL["glow"], 5, r=0.45)
            skin_detail(ctx, lay, m, skin, seed=31, center=(30.0, 14.0), radii=(22.0, 2.5 + 0.25 * stage))
            # head: prostomium + antennae + jaws
            hx, hy, dx, dy = along(pts, 1.0)
            hr = self.rad(stage, 1.0) + 0.3
            hm = ctx.ell(hx, hy, hr + 0.3, hr)
            ctx.shade(lay, hm, body_r, gain=1.3, shift=1)
            ctx.dot(lay, hx - 0.2, hy - hr * 0.5, PAL["black"], 0, r=0.4)
            if stage >= 1:
                ctx.dot(lay, hx + 0.6, hy - hr * 0.5, PAL["black"], 0, r=0.4)
            na = [2, 3, 3, 5, 5][stage]
            for j in range(na):
                a = -1.9 + j * 0.9 / max(1, na - 1) * 1.6
                ln = [2.5, 3.2, 4.0, 5.5, 6.5][stage]
                wig = math.sin(st["phase"] * 1.8 + j) * 0.3
                e = (hx + math.cos(a + wig) * ln, hy - hr * 0.6 + math.sin(a + wig) * ln)
                m2, _ = ctx.path([(hx, hy - hr * 0.6), e], 0.3, 0.25)
                lay.paint(m2, body_r, 5)
                if stage >= 4:
                    ctx.dot(lay, e[0], e[1], PAL["glow"], 6, r=0.35)
            op = st["open"]
            jl = 2.0 + 0.5 * stage + (1.5 if head == "head_piranha" else 0.0)
            jaw_r = ramp("#3a2a2a") if head != "head_sword" else PAL["steel"]
            if head == "head_sword":
                jl += 5.0
            for s_ in (-1, 1):
                a = s_ * (0.15 + op * 0.7)
                b = (hx + hr * 0.6, hy + s_ * 0.5)
                e = (b[0] + math.cos(a) * jl, b[1] + math.sin(a) * jl)
                c = (b[0] + math.cos(a) * jl * 0.6 - math.sin(a) * s_ * -0.8, b[1] + math.sin(a) * jl * 0.6 + math.cos(a) * s_ * -0.8 * -1)
                mj, hj = ctx.path(spline([b, c, e], 10), 0.8, 0.25)
                ctx.shade(lay, mj, jaw_r, hj, gain=1.2)
                if head == "head_piranha":
                    for q in (0.35, 0.6, 0.85):
                        px, py = b[0] + (e[0] - b[0]) * q, b[1] + (e[1] - b[1]) * q
                        lay.paint(ctx.poly([(px - 0.35, py), (px, py - s_ * 1.1), (px + 0.35, py)]), PAL["white"], 6)
            if head == "head_lure":
                lure_bulb(ctx, lay, [(hx, hy - hr), (hx + 1, hy - hr - 5), (hx + 4, hy - hr - 6 + math.sin(st["phase"]))], body_r)

    def lure_pos(self, stage, st):
        hx, hy, _, _ = along(self.spine(stage, st), 1.0)
        hr = self.rad(stage, 1.0) + 0.3
        return (hx + 4, hy - hr - 6 + math.sin(st["phase"]))


# -------------------------------------------------------------- tube worm
class TubeWorm(Plan):
    """Verme-tubo: a worm that swims carrying its own chitin tube, a red
    feathery plume blooming from the open end.
    Path: short soft tube -> growth rings -> longer ringed tube with a double
    plume -> calcified ridges and barnacles -> giant with a glowing plume."""
    canvas = (60, 32)
    length = 40.0

    def geom(self, stage, st):
        sway = math.sin(st["phase"]) * 0.5
        tl = [14.0, 17.0, 20.0, 22.0, 24.0][stage]
        x1 = 34.0
        x0 = x1 - tl
        cy = 16.0 + sway
        return x0, x1, cy, 3.0 + 0.2 * stage, sway

    def draw(self, ctx, stage, st, head="", skin="", fins="", tail="", what=("rear", "back", "body", "front")):
        x0, x1, cy, r, sway = self.geom(stage, st)
        tube_r = skin_ramp(TUBE, skin)
        plume_r = PLUME[stage]
        if "rear" in what:
            lay = ctx.L["rear"]
            if tail:
                tail_variants(ctx, lay, tail, (x0 + 0.5, cy), (-1.0, 0.0), tube_r if tail == "tail_eel" else WORM_PINK, st)
        for side in ("back", "front"):
            if side not in what:
                continue
            lay = ctx.L[side]
            far = side == "back"
            # the soft worm body shows as a bristled "skirt" out of the tube
            # mouth on both sides; fins turn it into paddles / spines / sparks
            n = 3
            for j in range(n):
                x = x0 + 3.0 + j * (x1 - x0 - 6) / (n - 1) + (1.5 if far else 0.0)
                s_ = -1 if far else 1
                y = cy + s_ * r * 0.95
                wig = math.sin(st["phase"] * 1.6 + j + (1 if far else 0)) * 0.6
                if fins == "fins_wing":
                    m = ctx.ell(x + wig, y + s_ * 1.6, 2.2, 1.0, rot=0.3 * s_)
                    ctx.shade(lay, m, ramp("#4ab8d8"), gain=1.0, shift=-2 if far else 0)
                elif fins == "fins_spiky":
                    lay.paint(ctx.poly([(x - 1.0, y), (x - 0.5 + wig, y + s_ * 3.2), (x + 1.0, y)]), PAL["coral"], 3 if far else 5)
                elif fins == "fins_volt":
                    ctx.dot(lay, x, y + s_ * 0.6, PAL["volt"], 6, r=0.6)
                    if (st["i"] + j) % 2 == 0:
                        lay.paint(ctx.seg((x, y + s_ * 0.6), (x + 1.0, y + s_ * 2.0), 0.25), PAL["volt"], 6, outline=False)
        if "body" in what:
            lay = ctx.L["body"]
            # plume first (behind the tube lip), then the tube
            pr = [5.5, 7.0, 8.5, 10.0, 11.5][stage]
            if st["act"]:
                pr *= 1.0 - 0.35 * st["reach"]      # snaps shut when it strikes
            npl = [5, 6, 8, 9, 11][stage]
            for j in range(npl):
                a = -1.25 + j * 2.5 / (npl - 1)
                wav = math.sin(st["phase"] * 1.4 + j * 0.8) * 0.12
                e = (x1 + math.cos(a + wav) * pr, cy + math.sin(a + wav) * pr * 0.95)
                mid = (x1 + math.cos(a) * pr * 0.55, cy + math.sin(a) * pr * 0.5)
                sp = spline([(x1 - 0.5, cy), mid, e], 10)
                m, h = ctx.path(sp, 0.6, 0.45)
                ctx.shade(lay, m, plume_r, h, gain=1.1, shift=0 if j % 2 else -1)
                # feathery pinnules
                for q in range(3, len(sp), 2):
                    px, py = sp[q]
                    lay.paint(ctx.seg((px, py), (px + math.cos(a + 1.3) * 0.9, py + math.sin(a + 1.3) * 0.9), 0.2), plume_r, 5)
                if stage >= 4 or head == "head_lure":
                    ctx.dot(lay, e[0], e[1], PAL["glow"], 6, r=0.45)
            if stage >= 2:
                # an inner second whorl of the plume
                for j in range(npl - 2):
                    a = -1.0 + j * 2.0 / max(1, npl - 3)
                    e = (x1 + math.cos(a) * pr * 0.6, cy + math.sin(a) * pr * 0.55)
                    m, h = ctx.path([(x1, cy), e], 0.5, 0.35)
                    ctx.shade(lay, m, plume_r, h, shift=1)
            if head == "head_piranha":
                op = st["open"]
                lay.paint(ctx.ell(x1 + 1.0, cy, 1.4, 1.0 + op), ramp("#3a1a1a"), 1)
                for s_ in (-1, 1):
                    for q in range(3):
                        px = x1 + 0.2 + q * 0.8
                        lay.paint(ctx.poly([(px - 0.3, cy + s_ * (1.0 + op)), (px, cy + s_ * (0.1 + op * 0.3)), (px + 0.3, cy + s_ * (1.0 + op))]), PAL["white"], 6)
            if head == "head_sword":
                # the operculum: a stopper spike
                ext = 6.0 + (st["reach"] * 3 if st["act"] else 0)
                m, h = ctx.path([(x1, cy), (x1 + pr + ext, cy - 0.5)], 1.2, 0.2)
                ctx.shade(lay, m, PAL["steel"], h)
            tube = ctx.poly([(x0, cy - r * 0.6), (x1, cy - r), (x1, cy + r), (x0, cy + r * 0.6)])
            tube |= ctx.ell(x0, cy, 1.0, r * 0.6)
            ctx.shade(lay, tube, tube_r, gain=1.5)
            if skin == "":
                ring = tube & (np.sin((ctx.X - x0) * (1.1 + 0.25 * stage)) > 0.85) if stage >= 1 else tube & False
                lay.shift(ring, -1, lo=1)
                if stage >= 3:
                    ridge = tube & (np.abs(ctx.Y - cy + r * 0.3) < 0.4) & (np.sin(ctx.X * 1.5) > 0.2)
                    lay.shift(ridge, +2, hi=6)
                    for q in range(2 + stage - 3):
                        bx = x0 + 3 + q * 6.5
                        by = cy + r * 0.2 - (q % 2) * r * 0.9
                        b = ctx.ell(bx, by, 1.2, 1.0)
                        ctx.shade(lay, b, ramp("#c8c0b0"), gain=1.2)
                        ctx.dot(lay, bx, by - 0.2, ramp("#5a5048"), 1, r=0.35)
            skin_detail(ctx, lay, tube, skin, seed=37, center=((x0 + x1) / 2, cy), radii=((x1 - x0) / 2, r))
            # lip of the tube
            lip = ctx.ell(x1, cy, 0.9, r)
            ctx.shade(lay, lip, tube_r, gain=1.0, shift=1)
            if head == "head_lure":
                lure_bulb(ctx, lay, [(x1 - 2, cy - r), (x1 + 1, cy - r - 6), (x1 + 5, cy - r - 7 + sway)], plume_r)

    def lure_pos(self, stage, st):
        x0, x1, cy, r, sway = self.geom(stage, st)
        return (x1 + 5, cy - r - 7 + sway)


# ----------------------------------------------------------------- turtle
class Turtle(Plan):
    """Tartaruga: a sea turtle rowing with long front flippers.
    Path: hatchling (big head, smooth shell) -> scutes -> ridged carapace ->
    keels with barnacles -> ancient turtle with glowing scute seams."""
    canvas = (62, 44)
    length = 44.0

    def geom(self, stage, st):
        bob = math.sin(st["phase"]) * 0.4
        cx, cy = 27.0, 21.0 + bob
        return cx, cy, 13.0 + 0.3 * stage, 7.5 + 0.2 * stage, bob

    def draw(self, ctx, stage, st, head="", skin="", fins="", tail="", what=("rear", "back", "body", "front")):
        cx, cy, rx, ry, bob = self.geom(stage, st)
        shell_r = skin_ramp(TURTLE_SHELL[stage], skin)
        skin_c = TURTLE_SKIN[stage]
        if "rear" in what:
            lay = ctx.L["rear"]
            tb = (cx - rx + 0.5, cy + 1.5)
            if tail:
                tail_variants(ctx, lay, tail, tb, (-1.0, 0.1), skin_c, st)
            else:
                m = ctx.poly([(tb[0] + 2, tb[1] - 1.0), (tb[0] - 3.0, tb[1] + 0.8 + math.sin(st["phase"]) * 0.4), (tb[0] + 2, tb[1] + 1.2)])
                ctx.shade(lay, m, skin_c)
        for side in ("back", "front"):
            if side not in what:
                continue
            lay = ctx.L[side]
            far = side == "back"
            stroke = math.sin(st["phase"] + (0.0 if not far else 0.9))
            wing = fins == "fins_wing"
            # front flipper (the big rower)
            fl = (11.0 + 1.2 * stage) * (1.35 if wing else 1.0)
            bx, by = cx + rx * 0.45, cy + ry * 0.45
            ang = 2.3 - stroke * 0.55 - (0.2 if far else 0.0)
            tip = (bx + math.cos(ang) * fl, by + math.sin(ang) * fl * 0.75)
            mid = (bx + math.cos(ang + 0.25) * fl * 0.45, by + math.sin(ang + 0.25) * fl * 0.45 + 1.5)
            pts = spline([(bx, by), mid, tip], 14)
            m, h = ctx.path(pts, 2.2 + 0.1 * stage, 0.5)
            fr = ramp("#4ab8d8") if wing else skin_c
            ctx.shade(lay, m, fr, h, shift=-2 if far else 0)
            # hind flipper
            hx, hy = cx - rx * 0.6, cy + ry * 0.55
            ha = 2.6 + stroke * 0.3
            htip = (hx + math.cos(ha) * 5.5, hy + math.sin(ha) * 4.0 + 1.5)
            m2, h2 = ctx.path([(hx, hy), htip], 1.8, 0.8)
            ctx.shade(lay, m2, fr, h2, shift=-2 if far else -1)
            if skin == "" and not wing:
                scal = m & (hsh(np.floor(ctx.X * 1.3), np.floor(ctx.Y * 1.3), 3) < 0.2)
                lay.shift(scal, -1, lo=1)
            if fins == "fins_spiky":
                for q in (0.35, 0.6, 0.85):
                    px, py = pts[int(q * (len(pts) - 1))]
                    lay.paint(ctx.poly([(px - 0.5, py), (px - 1.2, py - 2.4), (px + 0.5, py - 0.3)]), PAL["coral"], 5)
            if fins == "fins_volt":
                edge = m & ~np.roll(m, -1, axis=0)
                lay.paint(edge, PAL["volt"], 6, outline=False)
                if st["i"] % 2 == 0:
                    lay.paint(ctx.seg(tip, (tip[0] - 1.2, tip[1] + 1.5), 0.3), PAL["volt"], 6, outline=False)
        if "body" in what:
            lay = ctx.L["body"]
            # head + neck (drawn under the shell rim)
            hs = [1.25, 1.1, 1.0, 1.0, 1.05][stage]
            hx, hy = cx + rx + 3.0 * hs, cy - 0.5 + (st["reach"] * 0.8 if st["act"] else 0.0)
            if st["act"]:
                hx += st["reach"] * 2.5
            neck, nh = ctx.path([(cx + rx - 3, cy + 0.5), (hx - 1.5, hy)], 2.3 * hs, 2.0 * hs)
            ctx.shade(lay, neck, skin_c, nh, shift=-1)
            head_m = ctx.ell(hx, hy, 3.4 * hs, 2.6 * hs)
            if head == "head_sword":
                head_m |= ctx.poly([(hx + 1.0, hy - 2.0 * hs), (hx + 11.0, hy - 2.5), (hx + 2.0, hy - 0.6)])
            ctx.shade(lay, head_m, skin_c, gain=1.3, shift=1)
            if head == "head_sword":
                lay.paint(head_m & (ctx.X > hx + 2.8 * hs), PAL["steel"], 5)
            if skin == "":
                sc = head_m & (hsh(np.floor(ctx.X * 0.9), np.floor(ctx.Y * 0.9), 7) < 0.15)
                lay.shift(sc, -1, lo=1)
            # beak / jaw
            op = st["open"]
            bx0 = hx + 2.6 * hs
            beak = ctx.poly([(bx0 - 1.2, hy - 0.4), (bx0 + 1.6 * hs, hy + 0.6), (bx0 - 1.0, hy + 1.2)])
            lay.paint(beak, ramp("#d8c070"), 4)
            if op > 0.1:
                lay.paint(ctx.poly([(bx0 - 2.2, hy + 0.6), (bx0 + 1.2, hy + 0.9 + op * 1.8), (bx0 - 1.8, hy + 1.8 + op)]), ramp("#3a1a1a"), 1)
            if head == "head_piranha":
                for q in range(3):
                    px = bx0 - 1.6 + q * 0.9
                    lay.paint(ctx.poly([(px - 0.35, hy + 0.7), (px, hy + 1.8 + op * 0.4), (px + 0.35, hy + 0.7)]), PAL["white"], 6)
            if head == "head_lure":
                # alligator-snapping turtle: a worm lure on the tongue
                lx, ly = bx0 - 0.5, hy + 1.2 + op * 1.2
                wig = math.sin(st["phase"] * 3) * 0.5
                lay.paint(ctx.seg((lx - 1.0, ly), (lx + 0.8, ly + wig), 0.45), PAL["glow"], 5)
            er = 0.9 * hs + (0.2 if stage >= 4 else 0.0)
            lay.paint(ctx.ell(hx + 0.6, hy - 0.9, er, er), PAL["black"], 0)
            ctx.dot(lay, hx + 0.4, hy - 1.2, PAL["glow"] if stage >= 4 else PAL["white"], 6, r=0.3)
            # carapace
            shell = ctx.ell(cx, cy, rx, ry) & (ctx.Y < cy + ry * 0.45)
            shell |= ctx.ell(cx, cy + ry * 0.35, rx * 0.92, ry * 0.3)
            ctx.shade(lay, shell, shell_r, gain=1.6)
            plast = ctx.ell(cx + 0.5, cy + ry * 0.48, rx * 0.8, ry * 0.18) & ~ctx.ell(cx, cy, rx - 0.6, ry - 0.8)
            lay.paint(plast, ramp("#e8d8a0"), 4)
            if stage >= 1 and skin == "":
                # scutes: a central row + side row, seams follow the dome
                u = (ctx.X - cx) / rx
                v = (ctx.Y - cy) / ry
                cols = np.floor((u + 1.0) * (2.0 + 0.5 * stage))
                seam_v = shell & (np.abs(((u + 1.0) * (2.0 + 0.5 * stage)) % 1.0) < 0.09 + ctx.px * 0.05)
                seam_h = shell & (np.abs(v + 0.35) < 0.08)
                seams = (seam_v & (v < 0.35)) | seam_h
                lay.shift(seams, -2, lo=1)
                if stage >= 4:
                    lay.paint(seam_h, PAL["glow"], 4)
                if stage >= 2:
                    # growth rings in each scute
                    ring = shell & (np.abs(((u + 1.0) * (2.0 + 0.5 * stage)) % 1.0 - 0.5) < 0.07) & (v < -0.4)
                    lay.shift(ring, +1, hi=6)
            if stage >= 3:
                # dorsal keel ridge + barnacles
                keel = ctx.ell(cx, cy - ry + 0.6, rx * 0.8, 0.9) & shell
                lay.shift(keel, +1, hi=6)
                for q in range(stage - 1):
                    bx = cx - rx * 0.5 + q * rx * 0.45
                    by = cy - ry * 0.55 + (q % 2) * 1.5
                    b = ctx.ell(bx, by, 1.2, 1.0)
                    ctx.shade(lay, b, ramp("#d8d0c0"), gain=1.2)
                    ctx.dot(lay, bx, by - 0.1, ramp("#5a5048"), 1, r=0.35)
            skin_detail(ctx, lay, shell, skin, seed=41, center=(cx, cy), radii=(rx, ry))

    def lure_pos(self, stage, st):
        cx, cy, rx, ry, bob = self.geom(stage, st)
        hs = [1.25, 1.1, 1.0, 1.0, 1.05][stage]
        hx = cx + rx + 3.0 * hs + (st["reach"] * 2.5 if st["act"] else 0.0)
        hy = cy - 0.5 + (st["reach"] * 0.8 if st["act"] else 0.0)
        return (hx + 2.6 * hs, hy + 1.5 + st["open"] * 1.2)


# ------------------------------------------------------------------ otter
class Otter(Plan):
    """Lontra: a sea otter swimming belly-down, tail sculling.
    Path: fluffy pale pup -> sleek brown -> dark with whiskers -> big, scarred
    -> elder with a silver head and a lucky stone."""
    canvas = (64, 34)
    length = 44.0

    def spine(self, stage, st):
        w = st["phase"]
        return [(12.0 + q * 3.2, 17.0 + math.sin(w - q * 0.6) * 0.8 * (1.0 - q / 12)) for q in range(11)]

    def draw(self, ctx, stage, st, head="", skin="", fins="", tail="", what=("rear", "back", "body", "front")):
        pts = self.spine(stage, st)
        fur = skin_ramp(OTTER[stage], skin)
        face = OTTER_FACE[stage] if skin == "" else fur
        pup = stage == 0
        if "rear" in what:
            lay = ctx.L["rear"]
            x, y, dx, dy = along(pts, 0.0)
            if tail:
                tail_variants(ctx, lay, tail, (x + 1, y), (-1.0, 0.0), fur, st, scale=1.1)
            else:
                sw = math.sin(st["phase"] - 1.0) * 1.2
                tp = spline([(x + 2, y), (x - 3, y + sw * 0.5), (x - 9, y + sw)], 12)
                m, h = ctx.path(tp, 2.2, 0.7)
                ctx.shade(lay, m, fur, h, shift=-1)
        for side in ("back", "front"):
            if side not in what:
                continue
            lay = ctx.L[side]
            far = side == "back"
            s_ = 0.6 if far else 0.0
            kick = math.sin(st["phase"] * 1.0 + s_)
            wing = fins == "fins_wing"
            # hind webbed foot (rear) + front paw
            hx, hy, _, _ = along(pts, 0.12)
            hy += 3.0
            foot_tip = (hx - 5.5 - kick * 1.5, hy + 2.0 + kick * 1.2)
            m, h = ctx.path([(hx, hy - 1), (hx - 2.5, hy + 0.8), foot_tip], 1.6, 1.0)
            ctx.shade(lay, m, fur, h, shift=-2 if far else -1)
            wsz = 2.8 if wing else 1.7
            web = ctx.ell(foot_tip[0] - 0.8, foot_tip[1], wsz, wsz * 0.6, rot=0.4 + kick * 0.3)
            ctx.shade(lay, web, ramp("#4ab8d8") if wing else ramp("#5a3a2a"), gain=1.0, shift=-2 if far else 0)
            fx, fy, _, _ = along(pts, 0.78)
            fy += 3.0
            paw = (fx + 1.5 + kick * 0.6 * (1 if far else -1), fy + 2.6)
            m2, h2 = ctx.path([(fx, fy - 1), paw], 1.3, 1.0)
            ctx.shade(lay, m2, fur, h2, shift=-2 if far else 0)
            if wing:
                lay.paint(ctx.ell(paw[0] + 0.3, paw[1] + 0.4, 1.8, 0.9), ramp("#4ab8d8"), 3 if far else 4)
            if fins == "fins_spiky":
                for q in range(3):
                    lay.paint(ctx.seg((paw[0] - 0.6 + q * 0.6, paw[1] + 0.5), (paw[0] + q * 0.6, paw[1] + 1.9), 0.22), PAL["white"], 6)
                    lay.paint(ctx.seg((foot_tip[0] - 1.5, foot_tip[1] - 0.6 + q * 0.6), (foot_tip[0] - 3.0, foot_tip[1] - 0.4 + q * 0.8), 0.22), PAL["white"], 6)
            if fins == "fins_volt":
                ctx.dot(lay, paw[0], paw[1] + 0.4, PAL["volt"], 6, r=0.6)
                if st["i"] % 2 == 0:
                    lay.paint(ctx.seg(paw, (paw[0] + 1.5, paw[1] + 1.4), 0.25) | ctx.seg(foot_tip, (foot_tip[0] - 1.6, foot_tip[1] + 1.3), 0.25), PAL["volt"], 6, outline=False)
        if "body" in what:
            lay = ctx.L["body"]
            rads = [3.2, 4.2, 4.7, 5.0, 5.0, 4.8, 4.6, 4.3, 3.9, 3.6, 3.3]
            if pup:
                rads = [r * 1.12 for r in rads]
            body = np.zeros_like(ctx.X, dtype=bool)
            hgt = np.zeros_like(ctx.X)
            for q in range(len(pts) - 1):
                m, h = ctx.path([pts[q], pts[q + 1]], rads[q], rads[q + 1])
                body |= m
                hgt = np.maximum(hgt, h)
            ctx.shade(lay, body, fur, hgt, gain=1.4)
            # fur: short strokes with the lay of the hair
            if skin == "":
                strokes = body & (np.sin(ctx.X * 2.6 + ctx.Y * 1.3) > 0.8) & (hsh(np.floor(ctx.X * 0.8), np.floor(ctx.Y * 1.6), 11) < 0.5)
                lay.shift(strokes, -1, lo=1)
                if pup:
                    fluff = body & ~ctx.path(pts, 3.0, 3.0)[0] & (np.sin(ctx.X * 3.1) > 0.3)
                    lay.shift(fluff, +1, hi=6)
                belly = body & (ctx.Y > 17.0 + 2.2) & (ctx.X > 20)
                lay.shift(belly, +1, hi=5)
                if stage >= 3:
                    for q in range(2):
                        sx0 = 26.0 + q * 5.0
                        lay.paint(ctx.seg((sx0, 14.2), (sx0 + 2.2, 15.4), 0.25) & body, ramp("#d8a8a0"), 4, outline=False)
                if stage >= 4:
                    silver = body & (ctx.X > 36.0) & (ctx.Y < 17.0)
                    lay.paint(silver, ramp("#c8c0b8", dark=0.3), 4)
            skin_detail(ctx, lay, body, skin, seed=43, center=(28.0, 17.0), radii=(16.0, 4.6))
            # head
            hx, hy = pts[-1][0] + 3.2, pts[-1][1] - 1.2
            if st["act"]:
                hx += st["reach"] * 1.8
            hr = 4.3 if not pup else 4.8
            hx -= 1.0
            head_m = ctx.ell(hx, hy, hr, hr * 0.92)
            ctx.shade(lay, head_m, face if stage >= 2 else fur, gain=1.3, shift=1)
            snout = ctx.ell(hx + hr * 0.75, hy + 1.0, 1.7, 1.4)
            ctx.shade(lay, snout, face, gain=1.1, shift=1)
            ear = ctx.ell(hx - 1.2, hy - hr * 0.8, 0.9, 0.7)
            lay.paint(ear, fur, 2)
            if head == "head_sword":
                m, h = ctx.path([(hx + 1, hy - hr * 0.6), (hx + 11, hy - hr - 1.0)], 1.0, 0.2)
                ctx.shade(lay, m, PAL["steel"], h)
            er = 0.75 if not pup else 1.0
            lay.paint(ctx.ell(hx + 1.0, hy - 0.8, er, er), PAL["black"], 0)
            ctx.dot(lay, hx + 0.8, hy - 1.1, PAL["white"], 6, r=0.28)
            ctx.dot(lay, hx + hr * 0.75 + 1.3, hy + 0.3, PAL["black"], 0, r=0.55)
            op = st["open"]
            if op > 0.15 or head == "head_piranha":
                mo = ctx.poly([(hx + hr * 0.4, hy + 1.8), (hx + hr * 0.8 + 2.0, hy + 1.6), (hx + hr * 0.8 + 1.5, hy + 2.0 + op * 1.6)])
                lay.paint(mo, ramp("#5a1a2a"), 1)
                if head == "head_piranha":
                    for q in range(3):
                        px = hx + hr * 0.6 + q * 0.8
                        lay.paint(ctx.poly([(px - 0.3, hy + 1.7), (px, hy + 2.6), (px + 0.3, hy + 1.7)]), PAL["white"], 6)
            if stage >= 2:
                for j in (-1, 0, 1):
                    a = 0.1 * j
                    b = (hx + hr * 0.8 + 1.2, hy + 1.0 + j * 0.4)
                    lay.paint(ctx.seg(b, (b[0] + 2.8, b[1] + j * 0.9 + a), 0.16), PAL["white"], 5, outline=False)
            if stage >= 4 and head == "":
                # the lucky stone held against the chest
                sx0, sy0, _, _ = along(pts, 0.85)
                st_m = ctx.ell(sx0, sy0 + 3.0, 1.5, 1.2)
                ctx.shade(lay, st_m, ramp("#8a90a0"), gain=1.2)
            if head == "head_lure":
                lure_bulb(ctx, lay, [(hx, hy - hr), (hx + 2, hy - hr - 5), (hx + 5, hy - hr - 6 + math.sin(st["phase"]))], fur)

    def lure_pos(self, stage, st):
        pts = self.spine(stage, st)
        hx, hy = pts[-1][0] + 3.2 + (st["reach"] * 1.8 if st["act"] else 0.0), pts[-1][1] - 1.2
        hr = 4.3 if stage else 4.8
        hx -= 1.0
        return (hx + 5, hy - hr - 6 + math.sin(st["phase"]))


PLANS = {"minhoca": Bobbit, "verme_tubo": TubeWorm, "tartaruga": Turtle, "lontra": Otter}
