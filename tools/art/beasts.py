"""Native pixel art for the non-fish playable characters.

Every character is a *body plan*: a drawing written in resolution-free "sprite
units" and sampled per growth stage at the pixel density of that stage, so the
art is redrawn (never scaled) at every size. Growth stages change the anatomy
(each animal has its own evolution path) and every mutation is a real part of
the drawing: it is modelled, shaded and outlined together with the body, and
each body plan has its own mutation set (a crab grows serrated pincers and
swimming paddles, a jellyfish grows barbed tentacles and a glowing bell...).

Frames: 6 swim/walk + 4 action (anticipation, full reach, strike, recover),
the same layout as the fish. Each frame is rendered in four layers so any
mutation combination can be assembled in game (see player.LAYERS):
    rear  -> tail row (tail mutations)
    back  -> fins_back row (far limbs / fin mutations)
    body  -> body rows (head x skin mutations, baked with the body)
    front -> fins_front row (near limbs)
"""
from __future__ import annotations

import math

import numpy as np
from PIL import Image

import pro
from pro import PAL, ramp, poly_mask, seg_dist
from fishpro import Layer, band
from props import capsule_field, light_of

TAU = math.tau
SWIM_N, ACT_N = 6, 4
N_FRAMES = SWIM_N + ACT_N
# action: anticipation, full reach, strike (snap), recover
ACT = [dict(open=0.55, reach=-0.4), dict(open=1.0, reach=1.0), dict(open=0.0, reach=0.6), dict(open=0.25, reach=0.1)]


def frame_state(i):
    if i < SWIM_N:
        return dict(phase=i * TAU / SWIM_N, open=0.0, reach=0.0, act=False, i=i)
    a = ACT[i - SWIM_N]
    return dict(phase=(i - SWIM_N) * TAU / 8.0, open=a["open"], reach=a["reach"], act=True, i=i)


# ---------------------------------------------------------------- canvas
class Ctx:
    """A frame in sprite units: X, Y grids + the four part layers."""

    def __init__(self, w, h, k):
        self.k = k
        self.W, self.H = max(8, int(round(w * k))), max(8, int(round(h * k)))
        ys, xs = np.mgrid[0:self.H, 0:self.W].astype(np.float64)
        self.X, self.Y = (xs + 0.5) / k, (ys + 0.5) / k
        self.px = 1.0 / k
        self.L = {n: Layer(self.W, self.H) for n in ("rear", "back", "body", "front")}

    def r(self, r):
        """Radius that never drops under half a pixel (thin parts stay solid)."""
        return max(r, 0.62 * self.px)

    # -- masks
    def ell(self, cx, cy, rx, ry, rot=0.0):
        X, Y = self.X - cx, self.Y - cy
        if rot:
            c, s = math.cos(rot), math.sin(rot)
            X, Y = X * c + Y * s, -X * s + Y * c
        return (X / rx) ** 2 + (Y / ry) ** 2 <= 1.0

    def poly(self, pts):
        return poly_mask(self.X, self.Y, pts)

    def seg(self, a, b, r):
        return seg_dist(self.X, self.Y, a[0], a[1], b[0], b[1]) <= self.r(r)

    def path(self, pts, r0, r1=None):
        """Tapered tube along a polyline -> (mask, height)."""
        r1 = r0 if r1 is None else r1
        n = len(pts) - 1
        segs = []
        for i in range(n):
            ra = self.r(r0 + (r1 - r0) * i / n)
            rb = self.r(r0 + (r1 - r0) * (i + 1) / n)
            segs.append((pts[i][0], pts[i][1], pts[i + 1][0], pts[i + 1][1], ra, rb))
        return capsule_field(segs, self.X, self.Y)

    def dot(self, lay, x, y, rmp, tone, r=0.5, outline=False):
        rr = max(r, 0.5 * self.px)
        m = (np.abs(self.X - x) <= rr) & (np.abs(self.Y - y) <= rr)
        lay.paint(m, rmp, tone, outline=outline)

    # -- shading
    def shade(self, lay, mask, rmp, hgt=None, gain=1.4, shift=0, lo=1, hi=5, smooth=0.5):
        if not mask.any():
            return
        if hgt is None:
            hgt = pro.dome_height(mask)          # already in pixels
        else:
            hgt = hgt * self.k                   # capsule heights are in sprite units
        li = light_of(hgt * gain, smooth=smooth)
        lay.paint(mask, rmp, np.clip(band(li) + shift, lo, hi))


def curve(p0, p1, p2, n=10):
    t = np.linspace(0, 1, n)[:, None]
    p0, p1, p2 = (np.array(p, float) for p in (p0, p1, p2))
    return [tuple(v) for v in ((1 - t) ** 2 * p0 + 2 * (1 - t) * t * p1 + t * t * p2)]


def rot(p, c, a):
    x, y = p[0] - c[0], p[1] - c[1]
    ca, sa = math.cos(a), math.sin(a)
    return (c[0] + x * ca - y * sa, c[1] + x * sa + y * ca)


def hsh(a, b, s=0):
    v = np.sin(a * 12.9898 + b * 78.233 + s * 37.719) * 43758.5453
    return v - np.floor(v)


# ------------------------------------------------------------ materials
def skin_ramp(base, skin):
    """Body material per skin mutation (the whole shell / hide changes)."""
    if skin == "skin_armor":
        return PAL["armor"]
    if skin == "skin_toxic":
        return ramp("#7cc83a")
    if skin == "skin_glow":
        return ramp("#2a3a6e", dark=0.3)
    return base


def skin_detail(ctx, lay, mask, skin, cell=2.6, seed=1, rim=None, center=None, radii=None):
    """Surface of a skin mutation drawn *into* the shaded body.

    armor : concentric plates that follow the body's curvature (bright lip,
            dark seam) with a rivet row on the outer plate
    toxic : a few big smooth pustules with a highlight and a dark rim
    glow  : bioluminescent veins + photophores"""
    X, Y = ctx.X, ctx.Y
    if not mask.any():
        return
    ys, xs = np.nonzero(mask)
    if center is None:
        center = ((xs.min() + xs.max() + 1) / 2 / ctx.k, (ys.min() + ys.max() + 1) / 2 / ctx.k)
    if radii is None:
        radii = ((xs.max() - xs.min() + 1) / 2 / ctx.k, (ys.max() - ys.min() + 1) / 2 / ctx.k)
    cx, cy = center
    rx, ry = radii
    u = np.sqrt(((X - cx) / rx) ** 2 + ((Y - cy) / ry) ** 2)
    if skin == "skin_armor":
        bands = 3
        pos = u * bands
        frac = pos % 1.0
        edge_w = ctx.px / (min(rx, ry) / bands) * 1.1
        seam = mask & (frac < edge_w) & (pos > 0.6)
        lip = mask & (frac > 1.0 - edge_w * 1.2) & (pos > 0.5)
        lay.shift(seam, -2, lo=1)
        lay.shift(lip, +1, hi=6)
        # rivets on the outer plate
        ang = np.arctan2((Y - cy) / ry, (X - cx) / rx)
        n = 12
        a0 = np.round(ang / TAU * n) * TAU / n
        rvx, rvy = cx + np.cos(a0) * rx * 0.83, cy + np.sin(a0) * ry * 0.83
        rivet = mask & (np.hypot(X - rvx, Y - rvy) < max(0.45, ctx.px * 0.62))
        lay.shift(rivet, +2, hi=6)
    elif skin == "skin_toxic":
        rng = np.random.default_rng(seed)
        n = 3 + int(rx * ry / 32)
        for _ in range(n):
            a = rng.uniform(0, TAU)
            d = rng.uniform(0.15, 0.75)
            px, py = cx + math.cos(a) * rx * d, cy + math.sin(a) * ry * d
            r = rng.uniform(0.9, 1.5) * max(1.0, min(rx, ry) / 5)
            blob = mask & (np.hypot(X - px, (Y - py) * 1.1) < r)
            rim_ = mask & (np.hypot(X - px, (Y - py) * 1.1) < r + ctx.px * 1.05) & ~blob
            lay.paint(rim_, ramp("#4a2458"), 2)
            lay.paint(blob, ramp("#b85ce0"), 4)
            lay.paint(blob & (np.hypot(X - px + r * 0.35, Y - py + r * 0.35) < r * 0.4), ramp("#b85ce0"), 6)
    elif skin == "skin_glow":
        ang = np.arctan2((Y - cy) / ry, (X - cx) / rx)
        spoke = np.abs(np.sin(ang * 3.0 + u * 2.0)) < 0.13 + ctx.px * 0.1
        vein = mask & spoke & (u > 0.25) & (u < 0.92)
        lay.paint(vein, PAL["glow"], 4)
        ring = mask & (np.abs(u - 0.62) < ctx.px / min(rx, ry) * 0.7)
        lay.paint(ring, PAL["glow"], 3)
        for j in range(6):
            a = j * TAU / 6 + 0.3
            px_, py_ = cx + math.cos(a) * rx * 0.62, cy + math.sin(a) * ry * 0.62
            d = mask & (np.abs(X - px_) <= max(0.45, 0.5 * ctx.px)) & (np.abs(Y - py_) <= max(0.45, 0.5 * ctx.px))
            lay.paint(d, PAL["glow"], 6, outline=False)


def segmented(ctx, lay, pts, r0, r1, rmp, seg_len=1.8, gain=1.3, shift=0):
    """A smooth tapered tube with darker joint lines every seg_len units
    (scorpion tails, lobster abdomens, worm bodies)."""
    m, h = ctx.path(pts, r0, r1)
    ctx.shade(lay, m, rmp, h, gain=gain, shift=shift)
    # joints: perpendicular bands along the path
    acc = 0.0
    for i in range(len(pts) - 1):
        (x0, y0), (x1, y1) = pts[i], pts[i + 1]
        L = math.hypot(x1 - x0, y1 - y0)
        acc += L
        if acc >= seg_len:
            acc = 0.0
            t = i / (len(pts) - 1)
            r = r0 + (r1 - r0) * t
            nx, ny = -(y1 - y0) / max(L, 1e-6), (x1 - x0) / max(L, 1e-6)
            band_ = ctx.seg((x1 - nx * r * 1.2, y1 - ny * r * 1.2), (x1 + nx * r * 1.2, y1 + ny * r * 1.2), 0.3) & m
            lay.shift(band_, -1, lo=1)
    return m


def spline(pts, n=24):
    """Catmull-Rom through control points -> smooth polyline."""
    P = [pts[0]] + list(pts) + [pts[-1]]
    out = []
    for i in range(1, len(P) - 2):
        p0, p1, p2, p3 = (np.array(P[j], float) for j in (i - 1, i, i + 1, i + 2))
        for t in np.linspace(0, 1, max(2, n // (len(pts) - 1)), endpoint=False):
            t2, t3 = t * t, t * t * t
            v = 0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3)
            out.append((float(v[0]), float(v[1])))
    out.append(tuple(pts[-1]))
    return out


def pincer(ctx, lay, base, direction, size, rmp, gap, serrated=False, inner=None):
    """Chela: an oval palm and two curved tapered fingers with a visible gap.
    direction: unit vector the fingers point to; gap 0..1."""
    dx, dy = direction
    nx, ny = -dy, dx
    bx, by = base
    palm = ctx.ell(bx, by, size * 1.05, size * 0.82, rot=math.atan2(dy, dx))
    ctx.shade(lay, palm, rmp, gain=1.5)
    L = size * 1.55
    tip_open = 0.35 + gap * 0.55
    fingers = []
    for side, tone in ((1, 5), (-1, 3)):
        a = side * tip_open * 0.5
        ca, sa = math.cos(a), math.sin(a)
        fx, fy = dx * ca - dy * sa, dx * sa + dy * ca
        root = (bx + dx * size * 0.75 + nx * side * size * 0.35, by + dy * size * 0.75 + ny * side * size * 0.35)
        mid = (root[0] + fx * L * 0.55 + nx * side * size * 0.12, root[1] + fy * L * 0.55 + ny * side * size * 0.12)
        tip = (root[0] + fx * L - nx * side * size * 0.18, root[1] + fy * L - ny * side * size * 0.18)
        pts = spline([root, mid, tip], 10)
        m, h = ctx.path(pts, size * 0.42, size * 0.1)
        ctx.shade(lay, m, rmp, h, gain=1.2, shift=1 if side > 0 else -1)
        fingers.append((pts, side))
    if serrated:
        for pts, side in fingers:
            for j in (2, 4, 6):
                if j >= len(pts):
                    continue
                px, py = pts[j]
                toothx, toothy = px - nx * side * size * 0.38, py - ny * side * size * 0.38
                tri = ctx.poly([(px - dx * 0.4, py - dy * 0.4), (px + dx * 0.4, py + dy * 0.4), (toothx, toothy)])
                lay.paint(tri, PAL["white"], 6)
    if inner is not None:
        cav = ctx.ell(bx + dx * size * 0.95, by + dy * size * 0.95, size * 0.35, size * 0.25, rot=math.atan2(dy, dx))
        lay.paint(cav & ~ctx.ell(bx, by, size * 1.05, size * 0.82, rot=math.atan2(dy, dx)), inner, 2, outline=False)
    return fingers


# ======================================================== body plans
class Plan:
    """Base body plan. Subclasses set size and implement draw()."""
    canvas = (40, 30)       # sprite units
    length = 30.0           # body length in units (sets the pixel density per stage)
    base = PAL["coral"]
    names = {}              # mutation id -> (name, short description) for this animal

    def __init__(self, species):
        self.species = species

    def k_for(self, stage):
        import player as PL
        return PL.STAGE_LEN[stage] * 1.1 / self.length

    def draw(self, ctx, stage, st, head="", skin="", fins="", tail="", what=("rear", "back", "body", "front")):
        raise NotImplementedError


# ---------------------------------------------------------------- crabs
CRAB_SHELL = ramp("#e05a3a")
CRAB_CLAW = ramp("#ff7a3a")
YETI_SHELL = ramp("#e8e0d4", dark=0.35)
YETI_HAIR = ramp("#d8c8a8", dark=0.3)


class Crab(Plan):
    """Frontal crab. Evolution path (caranguejo): juvenile -> spiked rim ->
    grooved shell and a crusher claw -> spiny king crab with a crown.
    Yeti crab: pale, its hairy claws grow longer bacteria gardens that glow."""
    canvas = (50, 38)
    length = 34.0

    def __init__(self, species):
        super().__init__(species)
        self.yeti = species == "caranguejo_yeti"

    def geom(self, stage, st):
        cx, cy = 25.0, 21.0 + math.sin(st["phase"] * 2) * 0.35
        rx = 8.2 + 0.35 * stage
        ry = 5.6 + 0.2 * stage
        return cx, cy, rx, ry

    # -- claws (head slot)
    def claw(self, ctx, lay, stage, st, sgn, head, skin, cx, cy, rx, ry):
        big = 1.0 + 0.07 * stage + (0.32 if (stage >= 3 and sgn < 0) else 0.0)   # crusher claw from stage 3
        lift = st["reach"] * 2.6 if st["act"] else math.sin(st["phase"] + (0 if sgn > 0 else 1.3)) * 0.6
        sx, sy = cx + sgn * rx * 0.55, cy - 0.8
        ex, ey = cx + sgn * (rx + 2.0), cy - 3.4 - lift * 0.4
        ax, ay = cx + sgn * (rx + 3.0), cy - 7.0 - lift
        shell = skin_ramp(YETI_SHELL if self.yeti else CRAB_CLAW, skin)
        # arm: two segments (merus + carpus)
        m, h = ctx.path([(sx, sy), (ex, ey)], 1.35 * big, 1.15 * big)
        ctx.shade(lay, m, shell, h, shift=-1)
        m2, h2 = ctx.path([(ex, ey), (ax, ay + 1.2)], 1.15 * big, 1.1 * big)
        ctx.shade(lay, m2, shell, h2, shift=0)
        if stage >= 3:   # spines along the arm
            for t in (0.35, 0.7):
                px, py = sx + (ex - sx) * t, sy + (ey - sy) * t
                lay.paint(ctx.poly([(px - 0.5, py - 0.9), (px + sgn * 0.4, py - 2.4), (px + 0.5, py - 0.8)]), shell, 5)
        size = 2.3 * big
        direction = (sgn * 0.45, -0.9)
        nrm = math.hypot(*direction)
        direction = (direction[0] / nrm, direction[1] / nrm)
        if head == "head_sword":
            # lance pincer: both fingers fused into one long spear
            palm = ctx.ell(ax, ay, size, size * 0.8, rot=math.atan2(direction[1], direction[0]))
            ctx.shade(lay, palm, shell, gain=1.5)
            tip = (ax + direction[0] * size * 4.2, ay + direction[1] * size * 4.2)
            pts = spline([(ax + direction[0] * size * 0.6, ay + direction[1] * size * 0.6),
                          (ax + direction[0] * size * 2.3 + sgn * 0.3, ay + direction[1] * size * 2.3), tip], 10)
            m3, h3 = ctx.path(pts, size * 0.5, 0.15)
            ctx.shade(lay, m3, PAL["steel"], h3, gain=1.1, shift=1)
            return
        pincer(ctx, lay, (ax, ay), direction, size, shell, 0.15 + st["open"] * 0.85,
               serrated=head == "head_piranha", inner=ramp("#6a1a28"))
        if skin == "skin_armor":
            palm = ctx.ell(ax, ay, size * 1.05, size * 0.82, rot=math.atan2(direction[1], direction[0]))
            skin_detail(ctx, lay, palm, skin, seed=3 + sgn)
        if self.yeti:
            # setae: hair hanging from arm and palm (the bacteria garden)
            n = 6 + stage * 2
            for j in range(n):
                t = j / max(1, n - 1)
                hx, hy = sx + (ax - sx) * t, sy + (ay - sy) * t + 1.0
                ln = 1.8 + stage * 0.5 + (j % 3) * 0.4
                sway = math.sin(st["phase"] + j) * 0.4
                lay.paint(ctx.seg((hx, hy), (hx + sway, hy + ln), 0.28), YETI_HAIR, 3 + (j % 2), outline=False)
                if stage >= 4 and j % 3 == 0:
                    ctx.dot(lay, hx + sway, hy + ln, PAL["glow"], 6, r=0.35)

    # -- legs (fins slot): far pairs in 'back', near pairs in 'front'
    def legs(self, ctx, lay, stage, st, fins, cx, cy, rx, ry, back):
        rmp = YETI_SHELL if self.yeti else CRAB_SHELL
        pairs = ((0, 2) if back else (1, 3))
        for k in pairs:
            for sgn in (-1, 1):
                phase = st["phase"] + k * 1.6 + (0 if sgn > 0 else math.pi)
                lift = max(0.0, math.sin(phase)) * 1.3 if not st["act"] else 0.2
                spread = [0.62, 0.9, 1.15, 1.35][k]
                bx = cx + sgn * rx * 0.5
                by = cy + 0.6 + k * 0.6
                knee = (bx + sgn * rx * 0.55 * spread + sgn * 2.0, by - 2.6 - lift + k * 0.3)
                foot = (bx + sgn * (rx * 0.62 * spread + 4.8), by + 5.0 - lift + k * 0.7)
                shade_shift = -2 if back else -1
                m, h = ctx.path([(bx, by), knee], 0.95, 0.85)
                ctx.shade(lay, m, rmp, h, shift=shade_shift)
                m2, h2 = ctx.path([knee, foot], 0.8, 0.35)
                ctx.shade(lay, m2, rmp, h2, shift=shade_shift)
                if fins == "fins_wing" and k == 3:
                    # blue-crab swimming paddle on the last pair
                    pd = ctx.ell(foot[0] - sgn * 0.3, foot[1] - 1.2, 2.4, 1.2, rot=sgn * (0.9 + math.sin(phase) * 0.35))
                    ctx.shade(lay, pd, ramp("#4a8ad8"), gain=1.2)
                    rib = pd & ctx.seg((foot[0] - sgn * 2.0, foot[1] - 2.0), (foot[0] + sgn * 1.2, foot[1] - 0.4), 0.25)
                    lay.paint(rib, ramp("#4a8ad8"), 5, outline=False)
                if fins == "fins_spiky":
                    for t in (0.35, 0.75):
                        px = knee[0] + (foot[0] - knee[0]) * t
                        py = knee[1] + (foot[1] - knee[1]) * t
                        lay.paint(ctx.poly([(px - 0.45, py - 0.2), (px + sgn * 1.2, py - 1.7), (px + 0.45, py + 0.1)]), PAL["coral"], 5)
                    lay.paint(ctx.poly([(knee[0] - 0.5, knee[1]), (knee[0] + sgn * 0.6, knee[1] - 2.0), (knee[0] + 0.5, knee[1] + 0.2)]), PAL["coral"], 5)
                if fins == "fins_volt":
                    lay.paint(ctx.ell(knee[0], knee[1], 0.75, 0.75), PAL["volt"], 5)
                    lay.paint(ctx.ell(foot[0], foot[1], 0.6, 0.6), PAL["volt"], 6)
                    if (st["i"] + k) % 2 == 0:
                        zz = [foot, (foot[0] + sgn * 0.8, foot[1] + 1.0), (foot[0] + sgn * 0.2, foot[1] + 1.8), (foot[0] + sgn * 1.0, foot[1] + 2.8)]
                        for q in range(3):
                            lay.paint(ctx.seg(zz[q], zz[q + 1], 0.25), PAL["volt"], 6, outline=False)
                if self.yeti and stage >= 2:
                    for t in (0.4, 0.75):
                        px = knee[0] + (foot[0] - knee[0]) * t
                        py = knee[1] + (foot[1] - knee[1]) * t
                        lay.paint(ctx.seg((px, py), (px + sgn * 0.3, py + 1.5), 0.26), YETI_HAIR, 4, outline=False)

    # -- rear (tail slot)
    def rear(self, ctx, lay, stage, st, tail, cx, cy, rx, ry, skin_base):
        rmp = skin_base
        if tail == "tail_sting":
            # scorpion tail rising from behind the shell, stinger aimed forward
            sway = math.sin(st["phase"]) * 0.6 + (st["reach"] * 2.0 if st["act"] else 0.0)
            ctrl = [(cx - 1.0, cy + 1.0), (cx - rx * 0.9, cy - 2.0), (cx - rx * 0.75, cy - ry - 6.0),
                    (cx - 2.0, cy - ry - 9.5 + sway * 0.3), (cx + 2.5 + sway, cy - ry - 8.0 + sway)]
            pts = spline(ctrl, 30)
            segmented(ctx, lay, pts, 2.0, 1.1, rmp, seg_len=1.7)
            tx, ty = pts[-1]
            bulb = ctx.ell(tx + 0.4, ty + 0.2, 1.7, 1.35)
            ctx.shade(lay, bulb, rmp, gain=1.3, shift=1)
            barb = spline([(tx + 1.2, ty + 0.6), (tx + 2.8, ty + 1.2), (tx + 3.2, ty + 2.8)], 8)
            m, h = ctx.path(barb, 0.55, 0.12)
            ctx.shade(lay, m, PAL["bone"], h, shift=1)
        elif tail == "tail_fork":
            # lobster tail fan below the body (telson + 4 uropods)
            spread = 0.34 + 0.08 * math.sin(st["phase"])
            p0 = (cx, cy + ry * 0.45)
            for j in (-2, -1, 1, 2, 0):
                a = math.pi / 2 + j * spread
                ln = 6.6 - abs(j) * 0.5
                tip = (p0[0] + math.cos(a) * ln, p0[1] + math.sin(a) * ln)
                w0 = 1.1
                wv = 1.7 if j else 1.4
                m = ctx.poly([(p0[0] - w0, p0[1]), (tip[0] - wv, tip[1] - 0.3), (tip[0], tip[1] + 0.6), (tip[0] + wv, tip[1] - 0.3), (p0[0] + w0, p0[1])])
                ctx.shade(lay, m, rmp, gain=1.1, shift=-1 if j else 0)
                lay.paint(m & ctx.seg(p0, tip, 0.25), rmp, 5, outline=False)
        elif tail == "tail_eel":
            # long lobster abdomen curling back and down
            sw = math.sin(st["phase"]) * 1.2
            ctrl = [(cx - 1.0, cy + 2.0), (cx - rx * 0.9, cy + 6.0), (cx - rx - 6.0, cy + 7.0 + sw), (cx - rx - 11.0, cy + 3.0 + sw)]
            pts = spline(ctrl, 30)
            segmented(ctx, lay, pts, 3.0, 1.6, rmp, seg_len=2.2)
            ex, ey = pts[-1]
            for j in (-1, 0, 1):
                m = ctx.poly([(ex + 0.5, ey), (ex - 3.0, ey + j * 1.7 - 0.9), (ex - 3.4, ey + j * 1.7 + 0.5)])
                ctx.shade(lay, m, rmp, gain=1.0, shift=-1 if j else 0)

    # -- body (shell + claws + eyes + antennae)
    def body(self, ctx, lay, stage, st, head, skin, cx, cy, rx, ry):
        base = YETI_SHELL if self.yeti else CRAB_SHELL
        shell_r = skin_ramp(base, skin)
        # claws behind the shell edge first (arms), shell on top
        for sgn in (-1, 1):
            self.claw(ctx, lay, stage, st, sgn, head, skin, cx, cy, rx, ry)
        shell = ctx.ell(cx, cy, rx, ry) & (ctx.Y < cy + ry * 0.62)
        if stage >= 2:   # spiked front rim
            for j in range(5):
                a = math.pi + 0.25 + j * 0.28
                for sgn in (-1, 1):
                    px, py = cx + sgn * math.cos(a) * -rx * 0.98, cy + math.sin(a) * ry * 0.98
                    shell |= ctx.poly([(px - 0.7, py + 0.4), (px + sgn * 1.0 * (1 if stage < 4 else 1.5), py - 1.1 - 0.3 * stage), (px + 0.7, py + 0.4)])
        if stage >= 4:   # crown
            for j in range(3):
                px = cx - 2.5 + j * 2.5
                shell |= ctx.poly([(px - 0.9, cy - ry + 0.8), (px, cy - ry - 2.4 - (j == 1) * 1.0), (px + 0.9, cy - ry + 0.8)])
        ctx.shade(lay, shell, shell_r, gain=1.5)
        # carapace sculpture per stage
        if skin == "":
            bumps = shell & (hsh(np.floor(ctx.X * 1.2), np.floor(ctx.Y * 1.2), 3) < 0.08) & (ctx.Y < cy)
            lay.shift(bumps, +1, hi=5)
        if stage >= 3:
            for sgn in (-1, 1):
                groove = shell & ctx.seg((cx + sgn * 2.0, cy - ry * 0.7), (cx + sgn * 3.2, cy + ry * 0.3), 0.3)
                lay.shift(groove, -1, lo=1)
        front = shell & (ctx.Y > cy + ry * 0.4)
        lay.shift(front, -1, lo=1)
        skin_detail(ctx, lay, shell, skin, seed=7, center=(cx, cy), radii=(rx, ry))
        if self.yeti and stage >= 1:
            fuzz = shell & (hsh(np.floor(ctx.X * 2), np.floor(ctx.Y * 2), 11) < 0.18)
            lay.shift(fuzz, -1, lo=2)
        # eye stalks
        for sgn in (-1, 1):
            ex, ey = cx + sgn * 2.1, cy - ry - 1.6 - 0.2 * stage
            m, h = ctx.path([(cx + sgn * 1.6, cy - ry + 1.0), (ex, ey)], 0.6)
            lay.paint(m, shell_r, 3)
            eyec = PAL["glow"] if (stage >= 4 or skin == "skin_glow") else PAL["black"]
            lay.paint(ctx.ell(ex, ey - 0.3, 0.9, 0.9), eyec, 1 if eyec is PAL["black"] else 5)
            ctx.dot(lay, ex - 0.3, ey - 0.6, PAL["white"], 6, r=0.3)
        if head == "head_lure":
            # lantern antennae arching forward with glowing bulbs
            for sgn in (-1, 1):
                sway = math.sin(st["phase"] + sgn) * 0.8
                pts = curve((cx + sgn * 0.8, cy - ry + 0.5), (cx + sgn * 4.0, cy - ry - 9.0), (cx + sgn * 7.5 + sway, cy - ry - 5.5), 8)
                m, h = ctx.path(pts, 0.45, 0.35)
                lay.paint(m, shell_r, 2)
                bx, by = pts[-1]
                lay.paint(ctx.ell(bx, by, 1.3, 1.3), PAL["glow"], 5)
                ctx.dot(lay, bx - 0.4, by - 0.4, PAL["white"], 6, r=0.35)
        # mouthparts
        lay.paint(ctx.ell(cx, cy + ry * 0.45, 1.6, 0.8) & shell, shell_r, 1, outline=False)

    def draw(self, ctx, stage, st, head="", skin="", fins="", tail="", what=("rear", "back", "body", "front")):
        cx, cy, rx, ry = self.geom(stage, st)
        base = skin_ramp(YETI_SHELL if self.yeti else CRAB_SHELL, "")
        if "rear" in what:
            self.rear(ctx, ctx.L["rear"], stage, st, tail, cx, cy, rx, ry, base)
        if "back" in what:
            self.legs(ctx, ctx.L["back"], stage, st, fins, cx, cy, rx, ry, True)
        if "body" in what:
            self.body(ctx, ctx.L["body"], stage, st, head, skin, cx, cy, rx, ry)
        if "front" in what:
            self.legs(ctx, ctx.L["front"], stage, st, fins, cx, cy, rx, ry, False)

    def lure_pos(self, stage, st):
        cx, cy, rx, ry = self.geom(stage, st)
        sway = math.sin(st["phase"] + 1) * 0.8
        return (cx + 7.5 + sway, cy - ry - 5.5)


PLANS = {"caranguejo": Crab, "caranguejo_yeti": Crab}


def get_plan(species):
    if species not in PLANS:
        import beasts2, beasts3, beasts4, beasts5  # noqa: F401  (register their plans)
        for mod in (beasts2, beasts3, beasts4, beasts5):
            PLANS.update(getattr(mod, "PLANS", {}))
    return PLANS[species](species)


# ------------------------------------------------------------ atlas
def render_atlas(species, stage):
    import player as PL
    import beasts6
    plan, anat, glassy = beasts6.plan_for(species, stage)
    # pixel density comes from the real life stage, anatomy from the plan
    k = PL.STAGE_LEN[stage] * 1.1 / plan.length
    cw, ch = plan.canvas
    rows = {name: [] for name in PL.LAYERS}
    lure = []

    def img(ctx, part):
        lay = ctx.L[part]
        if glassy:
            beasts6.vitrify(species, lay, glassy)
        lay.clean(1)
        return lay.to_image()

    for i in range(N_FRAMES):
        st = frame_state(i)
        # tails
        for t, row in (("", "tail"), ("tail_fork", "tail_fork"), ("tail_sting", "tail_sting"), ("tail_eel", "tail_eel")):
            c = Ctx(cw, ch, k)
            plan.draw(c, anat, st, tail=t, what=("rear",))
            rows[row].append(img(c, "rear"))
        # limbs / fins
        for f, rb, rf in (("", "fins_back", "fins_front"), ("fins_spiky", "fins_spiky_back", "fins_spiky_front"),
                          ("fins_wing", "fins_wing_back", "fins_wing_front"), ("fins_volt", "fins_volt_back", "fins_volt_front")):
            c = Ctx(cw, ch, k)
            plan.draw(c, anat, st, fins=f, what=("back", "front"))
            rows[rb].append(img(c, "back"))
            rows[rf].append(img(c, "front"))
        # bodies
        for hd in PL.HEADS:
            for sk in PL.SKINS:
                c = Ctx(cw, ch, k)
                plan.draw(c, anat, st, head=hd, skin=sk, what=("body",))
                rows[PL.body_key(hd, sk)].append(img(c, "body"))
        lp = plan.lure_pos(anat, st)
        lure.append([round(lp[0] * k, 1), round(lp[1] * k, 1)])
    w, h = rows["body"][0].size
    sheet = Image.new("RGBA", (w * N_FRAMES, h * len(PL.LAYERS)))
    for r, name in enumerate(PL.LAYERS):
        for cidx, im in enumerate(rows[name]):
            sheet.alpha_composite(im, (cidx * w, r * h))
    # centre / extents from the plain body of frame 0
    a = np.array(rows["body"][0])[:, :, 3] > 0
    ys, xs = np.nonzero(a)
    cx, cy = (xs.min() + xs.max() + 1) / 2, (ys.min() + ys.max() + 1) / 2
    meta = dict(frame_w=w, frame_h=h, frames=N_FRAMES, swim=SWIM_N, act=ACT_N, layers=PL.LAYERS,
                center=[round(float(cx), 1), round(float(cy), 1)], mouth=[float(xs.max()), float(cy)],
                lure=lure, lure_builtin=False, length=round(float(xs.max() - xs.min()), 1),
                height=round(float(ys.max() - ys.min()), 1), critter=True)
    return sheet, meta


def preview(species, path, stages=(0, 1, 2, 3, 4), combos=None, scale=3):
    """Debug sheet: every stage plain + a set of mutation combos."""
    import player as PL
    combos = combos or [
        ("body+head_piranha", "", "", ""), ("body+head_sword+skin_armor", "", "", ""),
        ("body+head_lure+skin_glow", "", "", ""), ("body+skin_toxic", "fins_spiky", "tail_sting", ""),
        ("body", "fins_wing", "tail_fork", ""), ("body+head_piranha+skin_armor", "fins_volt", "tail_eel", ""),
    ]
    tiles = []
    for s in stages:
        sh, m = render_atlas(species, s)
        tiles.append(PL.compose_frame(sh, m, ["tail", "fins_back", "body", "fins_front"], 0))
        if s == 2:
            for body, fins, tail, _ in combos:
                layers = [tail or "tail", (fins + "_back") if fins else "fins_back", body, (fins + "_front") if fins else "fins_front"]
                tiles.append(PL.compose_frame(sh, m, layers, 7))
    W = sum(t.width for t in tiles) * scale + 10 * len(tiles)
    H = max(t.height for t in tiles) * scale
    out = Image.new("RGBA", (W, H), (24, 48, 72, 255))
    x = 0
    for t in tiles:
        out.alpha_composite(t.resize((t.width * scale, t.height * scale), Image.NEAREST), (x, H - t.height * scale))
        x += t.width * scale + 10
    out.save(path)


def sheet_preview(species, path, scale=3):
    """Two rows: the five growth stages, then mutation combos at stage 3."""
    import player as PL
    stages = []
    for s in range(5):
        sh, m = render_atlas(species, s)
        stages.append(PL.compose_frame(sh, m, ["tail", "fins_back", "body", "fins_front"], 0))
        if s == 3:
            sh3, m3 = sh, m
    combos = [["tail", "fins_back", "body+head_piranha", "fins_front"],
              ["tail_sting", "fins_spiky_back", "body+skin_toxic", "fins_spiky_front"],
              ["tail_fork", "fins_wing_back", "body+head_lure+skin_glow", "fins_wing_front"],
              ["tail_eel", "fins_volt_back", "body+head_sword+skin_armor", "fins_volt_front"]]
    muts = [PL.compose_frame(sh3, m3, c, f) for c, f in zip(combos, [7, 2, 4, 8])]
    rows = [stages, muts]
    W = max(sum(t.width for t in r) * scale + 10 * len(r) for r in rows)
    Hs = [max(t.height for t in r) * scale for r in rows]
    out = Image.new("RGBA", (W, sum(Hs) + 10), (24, 48, 72, 255))
    y = 0
    for r, H in zip(rows, Hs):
        x = 0
        for t in r:
            out.alpha_composite(t.resize((t.width * scale, t.height * scale), Image.NEAREST), (x, y + H - t.height * scale))
            x += t.width * scale + 10
        y += H + 10
    out.save(path)
