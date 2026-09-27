"""Invertebrates, reptiles, mammals and non-fish boss parts in the pro style.

Same frame layout as before (4 move + 2 action unless noted). Bodies are
built from shaded primitives (capsules, domes, Voronoi plates), outlined with
selective outlines, and mouths are real moving parts (the turtle's lower beak
rotates open, the otter opens its jaw while eating).
"""
from __future__ import annotations

import math

import numpy as np
from scipy import ndimage

import pro
from pro import PAL, ramp, poly_mask, seg_dist
from fishpro import Layer, band
from props import grid, sheet, light_of, capsule_field, voronoi, noise2

TURTLE_SHELL = ramp("#7a8a3a")
TURTLE_SKIN = ramp("#8aa860")
CRAB = ramp("#e8503a")
SHRIMP = ramp("#ff8a7a")
SQUID = ramp("#ff7a9a")
JELLY = ramp("#c07cf0")
FUR = ramp("#8a5a3a", dark=0.28)
CUKE = ramp("#9a5a3e")
ISO = ramp("#8a9ab8")
URCHIN = ramp("#8a4ad0")
KRAKEN = ramp("#e04a42")
LEVI = PAL["navy"]


def curve_pts(p0, p1, p2, n=10):
    t = np.linspace(0, 1, n)[:, None]
    p0, p1, p2 = (np.array(p, float) for p in (p0, p1, p2))
    return (1 - t) ** 2 * p0 + 2 * (1 - t) * t * p1 + t * t * p2


def tube(pts, r0, r1):
    """Tapered capsules along a polyline."""
    segs = []
    n = len(pts) - 1
    for i in range(n):
        ra = r0 + (r1 - r0) * i / n
        rb = r0 + (r1 - r0) * (i + 1) / n
        segs.append((pts[i][0], pts[i][1], pts[i + 1][0], pts[i + 1][1], ra, rb))
    return segs


def shaded(lay, mask, hgt, rmp, gain=1.4, smooth=0.5, shift=0, lo=1, hi=5):
    li = light_of(hgt * gain, smooth=smooth)
    lay.paint(mask, rmp, np.clip(band(li) + shift, lo, hi))


def dot(lay, X, Y, x, y, rmp, tone):
    lay.paint((np.floor(X) == math.floor(x)) & (np.floor(Y) == math.floor(y)), rmp, tone)


def eye(lay, X, Y, x, y, big=False):
    """Tiny critter eye: dark pupil + one catch light."""
    if big:
        m = np.hypot(X - x, Y - y) < 1.6
        lay.paint(m, PAL["black"], 0)
        dot(lay, X, Y, x - 0.6, y - 0.6, PAL["white"], 6)
    else:
        dot(lay, X, Y, x, y, PAL["black"], 0)


# ------------------------------------------------------------------ turtle
def turtle():
    frames = []
    for i in range(6):
        w, h = 50, 32
        X, Y = grid(w, h)
        flap = [0.0, 0.6, 1.0, 0.4, 0.2, 0.2][i]
        bite = [0, 0, 0, 0, 1.0, 0.35][i]
        cx, cy = 23.0, 17.0
        lay_back = Layer(w, h)
        # far flippers (behind the shell, darker)
        rear = tube(curve_pts((cx - 11, cy + 3), (cx - 16, cy + 6), (cx - 19, cy + 8 - flap * 3)), 2.6, 1.2)
        m, hg = capsule_field(rear, X, Y)
        shaded(lay_back, m, hg, TURTLE_SKIN, shift=-1)
        ff = tube(curve_pts((cx + 5, cy + 1), (cx - 1, cy - 5 + flap * 8), (cx - 6, cy - 8 + flap * 12)), 3.0, 1.4)
        m, hg = capsule_field(ff, X, Y)
        shaded(lay_back, m, hg, TURTLE_SKIN, shift=-1)
        lay_back.clean(1)
        # head + neck (lower beak rotates open when biting)
        lay = Layer(w, h)
        hx = cx + 16.5 + bite * 1.5
        hy = cy - 1.0
        neck = tube([(cx + 9, cy + 1), (hx - 3, hy + 0.5)], 3.4, 3.0)
        m, hg = capsule_field(neck, X, Y)
        shaded(lay, m, hg, TURTLE_SKIN)
        head = ((X - hx) / 5.6) ** 2 + ((Y - hy) / 4.2) ** 2 <= 1.0
        ang = bite * 0.55
        # lower jaw: region below the beak line, rotated around the jaw hinge
        jx, jy = hx - 2.0, hy + 0.8
        c, s = math.cos(-ang), math.sin(-ang)
        sx = jx + (X - jx) * c - (Y - jy) * s
        sy = jy + (X - jx) * s + (Y - jy) * c
        head_src = ((sx - hx) / 5.6) ** 2 + ((sy - hy) / 4.2) ** 2 <= 1.0
        upper = head & (Y < jy + 0.2 + (X - jx) * 0.08)
        lower = head_src & (sy >= jy + 0.2 + (sx - jx) * 0.08) & (sx > jx - 1)
        hgt = pro.dome_height(upper | lower)
        shaded(lay, upper | lower, hgt, TURTLE_SKIN, gain=1.2)
        if bite > 0:
            mouth = poly_mask(X, Y, [(jx, jy), (hx + 5.8, hy + 0.9), (jx + (hx + 5.8 - jx) * math.cos(ang), jy + (hx + 5.8 - jx) * math.sin(ang))]) & ~upper & ~lower
            lay.paint(mouth, PAL["mouth"], np.where(X < hx + 1, 1, 3))
        # beak edge: horny rim of the upper beak
        rim = upper & (X > hx + 1.5) & (Y > hy - 0.5)
        lay.paint(rim, PAL["bone"], 3)
        # scale pattern on the head
        lay.shift(upper & (((np.floor(X) + np.floor(Y) * 2) % 5) == 0) & (Y < hy - 1.5), -1, lo=2)
        eye(lay, X, Y, hx + 1.2, hy - 1.6)
        # shell: domed carapace with scutes (Voronoi plates)
        shell = (((X - cx) / 14.5) ** 2 + ((Y - cy - 2) / 11.0) ** 2 <= 1.0) & (Y < cy + 4.5)
        labels, border = voronoi(shell, 6.5, 3)
        small = ndimage.distance_transform_edt(shell & ~border)
        hgt = pro.dome_height(shell) * 0.8 + np.sqrt(np.clip(small / 2.5, 0, 1)) * 2.0
        shaded(lay, shell, hgt, TURTLE_SHELL, gain=1.2)
        lay.paint(border & shell, TURTLE_SHELL, 1)
        # plastron rim
        rimp = shell & (Y >= cy + 2.5)
        lay.paint(rimp, PAL["sandy"], 3)
        # near flippers (in front of the shell)
        nf = tube(curve_pts((cx + 7, cy + 4), (cx + 1, cy + 11 - flap * 9), (cx - 4, cy + 13 - flap * 12)), 3.2, 1.5)
        m, hg = capsule_field(nf, X, Y)
        shaded(lay, m, hg, TURTLE_SKIN, gain=1.2)
        rf = tube(curve_pts((cx - 10, cy + 4), (cx - 13, cy + 8), (cx - 15, cy + 9 + flap * 2)), 2.2, 1.0)
        m, hg = capsule_field(rf, X, Y)
        shaded(lay, m, hg, TURTLE_SKIN)
        lay.clean(1)
        im = lay_back.to_image()
        im.alpha_composite(lay.to_image())
        frames.append(im)
    return sheet(frames)


# -------------------------------------------------------------------- crab
def crab():
    frames = []
    claw = ramp("#ff7a3a")
    for i in range(6):
        w, h = 36, 22
        X, Y = grid(w, h)
        atk = i >= 4
        step = i % 2
        cx, cy = 18.0, 12.5
        lay = Layer(w, h)
        # walking legs: splayed outward, jointed, alternating lift
        for k in range(3):
            for sgn in (-1, 1):
                bx = cx + sgn * (3.0 + k * 1.6)
                lift = 1.2 if (k + step + (sgn > 0)) % 2 else 0.0
                knee = (bx + sgn * (4.5 + k * 0.8), cy - 1.8 - lift)
                foot = (bx + sgn * (7.0 + k * 1.2), cy + 7.5 - lift)
                m, hg = capsule_field(tube([(bx, cy + 1.5), knee, foot], 1.05, 0.55), X, Y)
                shaded(lay, m, hg, CRAB, shift=-1)
        # claws raised in front: arm + rounded chela with a movable finger
        for sgn in (-1, 1):
            ax, ay = cx + sgn * 7.5, cy - (7.5 if atk else 5.0)
            m, hg = capsule_field(tube([(cx + sgn * 4.5, cy - 1), (cx + sgn * 6.5, ay + 3.5), (ax, ay + 1.0)], 1.4, 1.2), X, Y)
            shaded(lay, m, hg, CRAB)
            palm = (((X - ax) / 3.6) ** 2 + ((Y - ay) / 2.9) ** 2 <= 1.0)
            shaded(lay, palm, pro.dome_height(palm), claw, gain=1.3)
            gap = 1.0 if (atk and i == 4) else 0.1
            fx = ax + sgn * 2.4
            fixed = poly_mask(X, Y, [(fx - sgn * 1.0, ay - 0.2), (fx + sgn * 3.4, ay - 1.8), (fx + sgn * 0.6, ay + 1.4)])
            moving = poly_mask(X, Y, [(fx - sgn * 1.0, ay - 2.2), (fx + sgn * 3.2, ay - 3.0 - gap * 2.2), (fx + sgn * 0.4, ay - 0.9)])
            lay.paint(fixed, claw, 3)
            lay.paint(moving, claw, 5)
        # carapace: wide dome with a scalloped front edge
        shell = (((X - cx) / 8.4) ** 2 + ((Y - cy) / 5.8) ** 2 <= 1.0) & (Y < cy + 3.8)
        shaded(lay, shell, pro.dome_height(shell), CRAB, gain=1.4)
        bumps = shell & (((np.floor(X) * 3 + np.floor(Y) * 5) % 11) == 0) & (Y < cy)
        lay.shift(bumps, +1, hi=5)
        front = shell & (Y > cy + 2.4) & ((np.floor(X) % 3) == 0)
        lay.shift(front, -1, lo=2)
        # eye stalks
        for sgn in (-1, 1):
            m, hg = capsule_field(tube([(cx + sgn * 2.0, cy - 4.5), (cx + sgn * 2.6, cy - 7.4)], 0.7, 0.6), X, Y)
            lay.paint(m, CRAB, 3)
            dot(lay, X, Y, cx + sgn * 2.6, cy - 8.0, PAL["black"], 0)
        lay.clean(1)
        frames.append(lay.to_image())
    return sheet(frames)


# ------------------------------------------------------------------ shrimp
def shrimp():
    frames = []
    for i in range(6):
        w, h = 20, 14
        X, Y = grid(w, h)
        curl = 0.25 if i < 4 else 0.95
        leg = i % 2
        lay = Layer(w, h)
        # abdomen curls from head (right) to tail (left)
        pts = []
        a = math.pi
        x, y = 13.5, 6.2
        pts.append((x, y))
        for k in range(6):
            a += 0.12 + curl * 0.22
            x += math.cos(a) * 1.9
            y += -math.sin(a) * 1.9 * 0.55 + curl * 0.55
            pts.append((x, y))
        segs = []
        for k in range(len(pts) - 1):
            r = 2.4 - k * 0.28
            segs.append((pts[k][0], pts[k][1], pts[k + 1][0], pts[k + 1][1], r, r - 0.28))
        m, hg = capsule_field(segs, X, Y)
        shaded(lay, m, hg, SHRIMP, gain=1.6)
        # segment bands
        for k in range(1, len(pts) - 1):
            px, py = pts[k]
            band_ = m & (np.abs((X - px) * 0.9 + (Y - py) * 0.35) < 0.45)
            lay.shift(band_, -1, lo=2)
        # tail fan
        tx, ty = pts[-1]
        fan = poly_mask(X, Y, [(tx + 1, ty - 1), (tx - 3.5, ty - 2.2 + curl * 2), (tx - 3.2, ty + 2.4 + curl * 2), (tx + 1, ty + 1)])
        lay.paint(fan & ~m, ramp("#ff6a5a"), 4)
        # carapace + rostrum
        cara = (((X - 14.2) / 3.4) ** 2 + ((Y - 5.8) / 2.6) ** 2 <= 1.0)
        shaded(lay, cara, pro.dome_height(cara), SHRIMP, gain=1.5)
        rost = poly_mask(X, Y, [(16, 4.4), (19.6, 4.2), (16.4, 5.8)])
        lay.paint(rost, SHRIMP, 5)
        # legs (swimmerets) paddling
        for k in range(4):
            lx = 13 - k * 1.8
            d = seg_dist(X, Y, lx, 7.6, lx - 0.8 + (0.9 if (k + leg) % 2 else 0), 10.8)
            lay.paint(d < 0.45, ramp("#ff6a5a"), 3, outline=False)
        # antennae
        sway = [0, 1, 0, -1, 1, 1][i]
        for x1, y1 in ((19.5, 0.5 + sway * 0.5), (11.0, 0.3)):
            d = seg_dist(X, Y, 15.8, 4.0, x1, y1)
            lay.paint(d < 0.42, ramp("#ffb0a0"), 4, outline=False)
        eye(lay, X, Y, 15.0, 4.6)
        lay.clean(1)
        frames.append(lay.to_image())
    return sheet(frames)


# --------------------------------------------------------------- jellyfish
def jellyfish():
    frames = []
    for i in range(6):
        w, h = 24, 32
        X, Y = grid(w, h)
        pulse = [0.0, 0.6, 1.0, 0.5, 0.0, 0.0][i]
        zap = i >= 4
        rmp = PAL["volt"] if zap else JELLY
        rx = 8.0 + pulse * 1.4
        ry = 7.0 - pulse * 1.3
        by = 10.0
        lay = Layer(w, h)
        # trailing tentacles (thin, translucent)
        for k in range(6):
            x0 = 12 - 6 + k * 2.4
            pts = [(x0 + math.sin(j * 0.8 + i * 1.5 + k) * 1.2, by + 1.5 + j * (2.4 - pulse * 0.4)) for j in range(8)]
            d = np.full(X.shape, 99.0)
            for j in range(len(pts) - 1):
                d = np.minimum(d, seg_dist(X, Y, *pts[j], *pts[j + 1]))
            lay.paint(d < 0.5, rmp, 4 if k % 2 else 5, alpha=200, outline=False)
        # frilly oral arms
        arms = tube([(12, by + 1), (12 + math.sin(i) * 1.2, by + 7), (12 - math.sin(i) * 1.0, by + 12 - pulse * 2)], 2.0, 1.0)
        m, hg = capsule_field(arms, X, Y)
        lay.paint(m, rmp, np.where((np.floor(Y) % 2) == 0, 3, 4), alpha=220)
        # bell: translucent dome, bright rim and inner ring organs
        bell = (((X - 12) / rx) ** 2 + ((Y - by) / ry) ** 2 <= 1.0) & (Y < by + 1.2)
        hg = pro.dome_height(bell)
        li = light_of(hg * 1.2, smooth=0.6)
        lay.paint(bell, rmp, np.clip(band(li) + 1, 2, 6), alpha=225)
        organs = (((X - 12) / (rx * 0.5)) ** 2 + ((Y - by + 1) / (ry * 0.42)) ** 2 <= 1.0) & (Y < by)
        lay.paint(organs & bell, rmp, 6 if zap else 5, alpha=235)
        lay.shift(organs & bell & (np.abs(X - 12) < 0.6), -1, lo=2)
        margin = bell & (Y > by + 0.2)
        lay.paint(margin & ((np.floor(X) % 2) == 0), rmp, 6, alpha=235)
        lay.clean(1)
        frames.append(lay.to_image())
    return sheet(frames)


# ------------------------------------------------------------------- squid
def squid():
    frames = []
    for i in range(6):
        w, h = 36, 20
        X, Y = grid(w, h)
        spread = [0.2, 0.5, 0.8, 0.5, 1.4, 1.1][i]
        lay = Layer(w, h)
        # arms trailing left (behind the head)
        for k in range(6):
            yoff = (k - 2.5) * spread
            pts = [(12.5, 10 + (k - 2.5) * 0.6)]
            for j in range(1, 7):
                pts.append((12.5 - j * 1.8, 10 + yoff * j * 0.5 + math.sin(j + i + k) * 0.6))
            m, hg = capsule_field(tube(pts, 1.1, 0.5), X, Y)
            shaded(lay, m, hg, SQUID, shift=(-1 if k % 2 else 0))
        # mantle: torpedo pointing right, with fins at the tip
        mt = poly_mask(X, Y, [(12, 6.2), (29, 8.2), (33, 10), (29, 11.8), (12, 13.8)])
        mt |= ((X - 12.5) / 3.0) ** 2 + ((Y - 10) / 3.9) ** 2 <= 1.0
        hg = pro.dome_height(mt)
        shaded(lay, mt, hg, SQUID, gain=1.3)
        # chromatophore spots
        sp = mt & (((np.floor(X) * 7 + np.floor(Y) * 3) % 13) == 0)
        lay.shift(sp, -1, lo=2)
        fin_up = poly_mask(X, Y, [(26, 8.4), (32, 4 + (i % 2)), (31, 9.2)])
        fin_dn = poly_mask(X, Y, [(26, 11.6), (32, 16 - (i % 2)), (31, 10.8)])
        lay.paint(fin_up & ~mt, SQUID, 5)
        lay.paint(fin_dn & ~mt, SQUID, 3)
        # head + big eye
        hd = ((X - 13.6) / 2.9) ** 2 + ((Y - 10) / 3.4) ** 2 <= 1.0
        shaded(lay, hd, pro.dome_height(hd), SQUID, gain=1.3)
        lay.paint(np.hypot(X - 14.2, Y - 9.2) < 1.6, PAL["iris_gold"], 5)
        lay.paint(np.hypot(X - 14.5, Y - 9.2) < 0.8, PAL["black"], 0)
        lay.clean(1)
        frames.append(lay.to_image())
    return sheet(frames)


# --------------------------------------------------------------- snail
def snail():
    frames = []
    shell_r = ramp("#c88a4a")
    foot_r = ramp("#d8b890")
    for i in range(6):
        w, h = 20, 16
        X, Y = grid(w, h)
        hide = i >= 4
        stretch = [0, 1, 2, 1, 0, 0][i]
        lay = Layer(w, h)
        if not hide:
            foot = (((X - 10 - stretch * 0.5) / (7.5 + stretch * 0.5)) ** 2 + ((Y - 14) / 2.2) ** 2 <= 1.0) & (Y > 11.5)
            head = (((X - 15.5 - stretch) / 2.6) ** 2 + ((Y - 11.5) / 2.2) ** 2 <= 1.0)
            m = foot | head
            shaded(lay, m, pro.dome_height(m), foot_r)
            for dx, ln in ((0.0, 4.2), (-1.6, 3.2)):
                sx0 = 16.0 + stretch + dx
                mm, hg = capsule_field(tube([(sx0, 10.5), (sx0 + 0.8, 10.5 - ln)], 0.6, 0.5), X, Y)
                lay.paint(mm, foot_r, 4)
                dot(lay, X, Y, sx0 + 0.8, 10.5 - ln - 0.6, PAL["black"], 0)
        # spiral shell: dome + spiral groove
        sh = ((X - 9.0) / 6.0) ** 2 + ((Y - 8.2) / 6.0) ** 2 <= 1.0
        shaded(lay, sh, pro.dome_height(sh), shell_r, gain=1.3)
        r = np.hypot(X - 9.4, Y - 8.4)
        a = np.arctan2(Y - 8.4, X - 9.4)
        spiral = sh & (np.abs(((r - (a + math.pi) / math.tau * 1.9) % 1.9) - 0.95) < 0.3) & (r > 0.8)
        lay.shift(spiral, -2, lo=1)
        lay.shift(sh & (r < 1.4), +1, hi=6)
        lay.clean(1)
        frames.append(lay.to_image())
    return sheet(frames)


# ---------------------------------------------------------------- otter
def otter():
    frames = []
    belly_r = ramp("#d8b890")
    for i in range(6):
        w, h = 42, 20
        X, Y = grid(w, h)
        paddle = [0.0, 1.0, 0.0, -1.0, 0.5, 0.5][i]
        eat = i >= 4
        cy = 10.0
        lay = Layer(w, h)
        # tail and hind feet
        m, hg = capsule_field(tube([(9, cy + 0.5), (4, cy + 0.2 + paddle * 0.4), (1.5, cy + 0.6)], 1.7, 1.0), X, Y)
        shaded(lay, m, hg, FUR, shift=-1)
        for fx, ph in ((12, 0.0), (24, 1.0)):
            m, hg = capsule_field(tube([(fx, cy + 3), (fx - 2 - paddle * 2 * (1 if ph else -1), cy + 7)], 1.3, 1.0), X, Y)
            shaded(lay, m, hg, FUR, shift=-1)
        # body: long furry capsule with a pale belly
        body = (((X - 19) / 11.5) ** 2 + ((Y - cy) / 4.4) ** 2 <= 1.0)
        shaded(lay, body, pro.dome_height(body), FUR, gain=1.2)
        belly = body & (Y > cy + 1.6)
        lay.paint(belly, belly_r, np.where(Y > cy + 3, 3, 4))
        fur = body & ~belly & (((np.floor(X) * 2 + np.floor(Y) * 3) % 7) == 0)
        lay.shift(fur, -1, lo=2)
        # head with an opening jaw
        hx, hy = 32.5, cy - 1.0
        head = ((X - hx) / 4.6) ** 2 + ((Y - hy) / 4.0) ** 2 <= 1.0
        shaded(lay, head, pro.dome_height(head), FUR, gain=1.2)
        muzzle = ((X - (hx + 3.0)) / 2.6) ** 2 + ((Y - (hy + 1.3)) / 1.9) ** 2 <= 1.0
        lay.paint(muzzle, belly_r, np.where(Y < hy + 1, 5, 4))
        if eat:
            mouth = poly_mask(X, Y, [(hx + 2.0, hy + 2.0), (hx + 5.6, hy + 1.6), (hx + 5.2, hy + 3.4)])
            lay.paint(mouth, PAL["mouth"], 2)
            dot(lay, X, Y, hx + 4.4, hy + 1.9, PAL["bone"], 5)
        dot(lay, X, Y, hx + 5.2, hy + 0.4, PAL["black"], 0)  # nose
        ear = ((X - (hx - 2.0)) / 1.3) ** 2 + ((Y - (hy - 3.6)) / 1.1) ** 2 <= 1.0
        lay.paint(ear, FUR, 3)
        eye(lay, X, Y, hx + 1.4, hy - 1.2)
        # whiskers
        for dy in (-0.4, 0.8):
            d = seg_dist(X, Y, hx + 4.2, hy + 1.2, hx + 7.5, hy + 1.2 + dy * 2)
            lay.paint(d < 0.35, PAL["white"], 5, outline=False)
        if eat:
            ur = np.hypot(X - (hx + 3.5), Y - (hy - 4.8))
            lay.paint(ur < 2.4, URCHIN, np.where(Y < hy - 5, 5, 3))
            for k in range(7):
                a = k / 7 * math.tau
                d = seg_dist(X, Y, hx + 3.5 + math.cos(a) * 2, hy - 4.8 + math.sin(a) * 2, hx + 3.5 + math.cos(a) * 3.8, hy - 4.8 + math.sin(a) * 3.8)
                lay.paint(d < 0.4, URCHIN, 4, outline=False)
        lay.clean(1)
        frames.append(lay.to_image())
    return sheet(frames)


# ---------------------------------------------------------- sea cucumber
def sea_cucumber():
    frames = []
    for i in range(6):
        w, h = 28, 13
        X, Y = grid(w, h)
        stretch = [0.0, 1.0, 2.0, 1.0, 0.0, 0.0][i]
        feeding = i >= 4
        L = 19 + stretch
        x0 = 4
        lay = Layer(w, h)
        u = (X - x0) / L
        hh = 3.6 * np.sin(np.pi * np.clip(0.08 + u * 0.86, 0, 1)) ** 0.6
        yc = 8.3 - 0.6 * np.sin(np.clip(u, 0, 1) * math.pi)
        body = (u >= 0) & (u <= 1) & (np.abs(Y - yc) <= hh)
        hgt = np.sqrt(np.clip(1 - ((Y - yc) / np.maximum(hh, 0.5)) ** 2, 0, 1)) * hh
        shaded(lay, body, hgt, CUKE, gain=1.5)
        warts = body & (((np.floor(X) * 3 + np.floor(Y) * 5) % 6) == 0) & (Y < yc)
        lay.paint(warts, ramp("#e0906a"), 5)
        hx = x0 + L
        for k in range(4):
            ang = -0.8 + k * 0.5 + (0.3 * math.sin(i * 1.3 + k) if feeding else 0)
            ln = 3.8 if feeding else 2.0
            d = seg_dist(X, Y, hx, 7.8, hx + math.cos(ang) * ln, 7.8 + math.sin(ang) * ln)
            lay.paint(d < 0.5, ramp("#f0c8a0"), 5, outline=False)
        lay.clean(1)
        frames.append(lay.to_image())
    return sheet(frames)


# ---------------------------------------------------------------- isopod
def isopod():
    frames = []
    for i in range(6):
        w, h = 24, 14
        X, Y = grid(w, h)
        step = i % 2
        cx, cy = 11.5, 8.0
        lay = Layer(w, h)
        for k in range(6):
            lx = 5.0 + k * 2.6
            d = seg_dist(X, Y, lx, cy + 2.5, lx - 1.0 + (1.2 if (k + step) % 2 else 0), cy + 5.4)
            lay.paint(d < 0.5, ISO, 2, outline=False)
        shell = (((X - cx) / 9.6) ** 2 + ((Y - cy) / 4.4) ** 2 <= 1.0) & (Y < cy + 2.6)
        hg = pro.dome_height(shell)
        shaded(lay, shell, hg, ISO, gain=1.5)
        seams = shell & (((X - cx + 30) % 2.6) < 0.7) & (X < cx + 7)
        lay.shift(seams, -1, lo=2)
        head = ((X - (cx + 9.2)) / 2.4) ** 2 + ((Y - (cy + 0.8)) / 2.2) ** 2 <= 1.0
        shaded(lay, head, pro.dome_height(head), ISO)
        sw = [0, 1, 0, -1, 1, 1][i]
        d = seg_dist(X, Y, cx + 10.2, cy - 0.5, cx + 13.2, cy - 3.2 + sw * 0.5)
        lay.paint(d < 0.4, ISO, 5, outline=False)
        tail = poly_mask(X, Y, [(cx - 9, cy), (cx - 12, cy - 1.2), (cx - 12, cy + 2.2), (cx - 9, cy + 2)])
        lay.paint(tail, ISO, 3)
        dot(lay, X, Y, cx + 10.0, cy + 0.2, PAL["black"], 0)
        lay.clean(1)
        frames.append(lay.to_image())
    return sheet(frames)


# ---------------------------------------------------------------- urchin
def urchin():
    frames = []
    for i in range(6):
        w, h = 20, 20
        X, Y = grid(w, h)
        cx, cy, r = 10.0, 12.5, 4.8
        lay = Layer(w, h)
        n = 18
        for k in range(n):
            a = math.pi + k / (n - 1) * math.pi + math.sin(i + k) * 0.05
            ln = (7.8 if k % 2 else 6.2) + (1.6 if i >= 4 else 0.0)
            d = seg_dist(X, Y, cx + math.cos(a) * 3, cy + math.sin(a) * 3, cx + math.cos(a) * ln, cy + math.sin(a) * ln)
            lay.paint(d < 0.5, URCHIN, 5 if math.sin(a) < -0.5 else 4, outline=False)
        for k in range(5):
            a = 0.25 + k * 0.65
            d = seg_dist(X, Y, cx + math.cos(a) * 3, cy + math.sin(a) * 2, cx + math.cos(a) * 6.2, cy + math.sin(a) * 4)
            lay.paint(d < 0.5, URCHIN, 3, outline=False)
        body = ((X - cx) / r) ** 2 + ((Y - cy) / (r * 0.85)) ** 2 <= 1.0
        shaded(lay, body, pro.dome_height(body), ramp("#6a2a8a"), gain=1.3)
        tub = body & (((np.floor(X) + np.floor(Y)) % 3) == 0) & (Y < cy)
        lay.shift(tub, +1, hi=5)
        lay.clean(1)
        frames.append(lay.to_image())
    return sheet(frames)


# ------------------------------------------------------------- boss parts
def kraken_head():
    frames = []
    skin2 = ramp("#b02a3a")
    for i in range(6):
        w, h = 84, 88
        X, Y = grid(w, h)
        pulse = [0.0, 0.5, 1.0, 0.5, 0.2, 0.2][i]
        angry = i >= 4
        cx = 42.0
        top, bot = 5.0 - pulse, 80.0
        rx = 27.0 + pulse * 1.6
        lay = Layer(w, h)
        # side fins near the top of the mantle
        for sgn in (-1, 1):
            fin = poly_mask(X, Y, [(cx + sgn * 8, 20), (cx + sgn * (29 + pulse * 3), 12 - pulse), (cx + sgn * 25, 22), (cx + sgn * 13, 31)])
            lay.paint(fin, KRAKEN, np.where(Y < 18, 4, 3))
        # arm stubs curling out under the head
        for k in range(6):
            ax = cx + (k - 2.5) * 8.0
            curl = (k - 2.5) * 0.9
            pts = [(ax, bot - 10), (ax + curl * 2, bot - 2), (ax + curl * 4.5, bot + 3)]
            m, hg = capsule_field(tube(pts, 4.2, 2.4), X, Y)
            shaded(lay, m, hg, skin2, gain=1.3)
            lay.paint(m & (np.hypot(X - pts[1][0], Y - pts[1][1] - 1.5) < 1.1), PAL["pink"], 5)
        # mantle
        u = np.clip((Y - top) / (bot - top), 0, 1)
        half = np.where(u < 0.72, rx * np.sin(np.clip(u / 0.72, 0, 1) * math.pi / 2) ** 0.62, rx * (1.0 - (u - 0.72) * 0.55))
        mantle = (Y >= top) & (Y <= bot) & (np.abs(X - cx) <= half)
        hg = pro.dome_height(mantle)
        li = light_of(hg * 0.9, smooth=1.0)
        lay.paint(mantle, KRAKEN, band(li, (0.26, 0.42, 0.62, 0.84)))
        # skin: dark rings and light bumps
        nz = noise2(X, Y, 5.5, 13)
        rings = mantle & (np.abs(nz) < 0.06) & (Y < bot - 20)
        lay.shift(rings, -1, lo=1)
        bumps = mantle & (((np.floor(X) * 7 + np.floor(Y) * 11) % 29) == 0) & (Y < bot - 22)
        lay.shift(bumps, +2, hi=6)
        # eyes: brow fold, glowing iris, horizontal slit pupil
        for sgn in (-1, 1):
            ex, ey = cx + sgn * 12.5, 53.0
            brow = seg_dist(X, Y, ex - sgn * 9.5, ey - 9.5 + (4.0 if angry else 0), ex + sgn * 6.5, ey - 9.0 - (1.5 if angry else 0)) < 1.6
            lay.paint(brow & mantle, skin2, 2)
            socket = np.hypot(X - ex, (Y - ey) * 1.1) < 8.6
            lay.shift(socket & mantle & ~brow, -1, lo=1)
            iris = np.hypot(X - ex, (Y - ey) * 1.1) < 7.4
            irr = PAL["volt"] if angry else PAL["orange"]
            lay.paint(iris, irr, np.where(Y < ey - 2, 4, np.where(Y > ey + 2.5, 6, 5)))
            slit = iris & (np.abs(Y - ey) < (1.0 if angry else 1.8)) & (np.abs(X - ex) < 5.6)
            lay.paint(slit, PAL["black"], 0)
            dot(lay, X, Y, ex - 2.5, ey - 3.0, PAL["white"], 6)
        lay.clean(1)
        frames.append(lay.to_image())
    return sheet(frames)


def kraken_segment():
    frames = []
    for i in range(4):
        w = h = 14
        X, Y = grid(w, h)
        lay = Layer(w, h)
        if i < 2:
            m = np.hypot(X - 7, Y - 7) < 5.8
            shaded(lay, m, pro.dome_height(m), KRAKEN, gain=1.2)
            su = np.hypot(X - 7, Y - (9.4 - i)) < 2.1
            lay.paint(su, PAL["pink"], np.where(Y < 9 - i, 4, 5))
            dot(lay, X, Y, 7, 9.4 - i, PAL["coral"], 2)
        elif i == 2:
            m = poly_mask(X, Y, [(2, 4), (12.5, 7), (2, 10)])
            lay.paint(m, KRAKEN, np.where(Y < 7, 4, 3))
        else:
            m = poly_mask(X, Y, [(1, 3.5), (13, 5), (13, 9), (1, 10.5)]) | (np.hypot(X - 10, Y - 7) < 3.4)
            shaded(lay, m, pro.dome_height(m), KRAKEN, gain=1.2)
            for sx in (9, 11.5):
                lay.paint(np.hypot(X - sx, Y - 8.6) < 1.1, PAL["pink"], 5)
        lay.clean(1)
        frames.append(lay.to_image())
    return sheet(frames)


def leviathan_segment():
    frames = []
    for i in range(4):
        w = h = 30
        X, Y = grid(w, h)
        lay = Layer(w, h)
        if i < 2:
            fin = poly_mask(X, Y, [(8, 9), (13, 0.5 + i), (17, 1.5), (22, 9)])
            lay.paint(fin, PAL["cyan"], np.where(Y < 5, 5, 4))
            lay.shift(fin & ((np.floor(X) % 3) == 0), -1, lo=2)
            body = np.hypot(X - 15, Y - 15) < 10.0
            shaded(lay, body, pro.dome_height(body), LEVI, gain=1.1)
            belly = body & (Y > 19)
            lay.paint(belly, PAL["cyan"], np.where(Y > 23, 3, 4))
            for k in range(3):
                stripe = body & (np.abs(X - (9 + k * 6) - (Y - 15) * 0.25) < 1.0) & (Y < 21)
                lay.paint(stripe, PAL["volt"], 6 if i else 4)
        else:
            tail = poly_mask(X, Y, [(26, 10), (2, 2.5), (9, 15), (2, 27.5), (26, 20)])
            lay.paint(tail, PAL["cyan"], np.where(Y < 15, 5, 3))
            lay.shift(tail & (np.abs(Y - 15) > 3) & ((np.floor(Y) % 4) == 0), -1, lo=2)
            body = np.hypot(X - 23.5, Y - 15) < 6.2
            shaded(lay, body, pro.dome_height(body), LEVI, gain=1.1)
        lay.clean(1)
        frames.append(lay.to_image())
    return sheet(frames)


ALL = {"kraken_head": kraken_head, "kraken_segment": kraken_segment, "leviathan_segment": leviathan_segment,
       "turtle": turtle, "crab": crab, "shrimp": shrimp, "jellyfish": jellyfish, "squid": squid, "snail": snail,
       "otter": otter, "sea_cucumber": sea_cucumber, "isopod": isopod, "urchin": urchin}


# ------------------------------------------------------ Titanacon's insides
def organ_heart():
    """Vital organ: a beating heart with arteries (4 pulse frames)."""
    frames = []
    for i in range(4):
        w, h = 52, 50
        X, Y = grid(w, h)
        k = [1.0, 1.08, 0.94, 1.0][i]
        lay = Layer(w, h)
        # arteries rising to the top
        for ax, bend in ((20, -5), (30, 4), (26, 0)):
            m, hg = capsule_field(tube(curve_pts((ax, 24), (ax + bend, 12), (ax + bend * 1.6, 1)), 3.6, 2.6), X, Y)
            shaded(lay, m, hg, ramp("#b03a6a"), gain=1.3)
        # two lobes + pointed apex
        lobes = ((((X - 19) / (11 * k)) ** 2 + ((Y - 26) / (10 * k)) ** 2 <= 1.0)
                 | (((X - 33) / (11 * k)) ** 2 + ((Y - 26) / (10 * k)) ** 2 <= 1.0)
                 | poly_mask(X, Y, [(9, 29), (43, 29), (26, 29 + 18 * k)]))
        shaded(lay, lobes, pro.dome_height(lobes), PAL["flesh"], gain=1.1)
        # veins
        for pts in (((14, 22), (20, 30), (18, 38)), ((36, 21), (31, 31), (30, 40)), ((26, 20), (26, 30), (24, 42))):
            d = np.full(X.shape, 99.0)
            cp = curve_pts(*pts)
            for j in range(len(cp) - 1):
                d = np.minimum(d, seg_dist(X, Y, *cp[j], *cp[j + 1]))
            lay.shift((d < 0.7) & lobes, -2, lo=1)
        lay.clean(1)
        # glossy highlight
        lay.paint((np.hypot(X - 15, Y - 21) < 2.2) & lobes, PAL["flesh"], 6)
        frames.append(lay.to_image())
    return sheet(frames)


def organ_gland():
    """Acid gland on the stomach wall (4 pulse frames)."""
    frames = []
    for i in range(4):
        w, h = 36, 36
        X, Y = grid(w, h)
        k = [1.0, 1.06, 1.1, 1.04][i]
        lay = Layer(w, h)
        stalk = (np.abs(X - 18) < 4) & (Y > 24)
        lay.paint(stalk, PAL["flesh"], 3)
        sac = ((X - 18) / (12 * k)) ** 2 + ((Y - 17) / (11 * k)) ** 2 <= 1.0
        shaded(lay, sac, pro.dome_height(sac), PAL["acid"], gain=1.1)
        cells = sac & (np.abs(noise2(X, Y, 3.0, 5 + i)) < 0.08)
        lay.shift(cells, -1, lo=2)
        lay.paint((np.hypot(X - 14, Y - 12) < 2.0) & sac, PAL["acid"], 6)
        lay.paint((np.hypot(X - 22, Y - 21) < 1.2) & sac, PAL["acid"], 6)
        lay.clean(1)
        frames.append(lay.to_image())
    return sheet(frames)


ALL.update({"organ_heart": organ_heart, "organ_gland": organ_gland})


# ------------------------------------------------- sea worm & fish lice
BOBBIT = ramp("#8a4aa0")
BOBBIT_B = ramp("#c08a3a")
LOUSE = ramp("#b8aa98", dark=0.3)
LOUSE_F = ramp("#e89aa8", dark=0.3)
EGG = ramp("#f0d060")


def bobbit():
    """Minhoca-do-mar (bobbit worm): iridescent segmented body springing out
    of the sand, five striped antennae and scissor jaws.
    4 sway frames + 2 strike frames (jaws open, snap). Anchored at the bottom."""
    frames = []
    for i in range(6):
        w, h = 28, 72
        X, Y = grid(w, h)
        lay = Layer(w, h)
        sway = [-2.5, -0.8, 2.5, 0.8, 0.0, 0.0][i]
        top = 17.0 if i < 4 else 12.0
        pts = curve_pts((14, h + 2), (14 - sway * 1.6, 44), (14 + sway, top))
        segs = tube(pts, 5.2, 4.2)
        m, hg = capsule_field(segs, X, Y)
        # bristles (parapodia) along both flanks
        for k in range(len(pts) - 1):
            px, py = pts[k]
            for s in (-1, 1):
                d = seg_dist(X, Y, px + s * 4.5, py, px + s * 6.8, py - 1.2)
                lay.paint((d < 0.45) & (py < h - 3), BOBBIT_B, 5, outline=False)
        shaded(lay, m, hg, BOBBIT, gain=1.3)
        # segment rings with an iridescent bronze sheen band
        rings = m & ((np.floor(Y) % 3) == 0)
        lay.shift(rings, -1, lo=1)
        sheen = m & (np.abs(X - (np.interp(Y, pts[::-1, 1], pts[::-1, 0]) - 1.5)) < 1.1) & ((np.floor(Y) % 3) != 0)
        lay.paint(sheen, BOBBIT_B, 5, outline=False)
        # head
        hx, hy = pts[-1]
        head = ((X - hx) / 5.4) ** 2 + ((Y - hy) / 4.2) ** 2 <= 1.0
        shaded(lay, head, pro.dome_height(head), BOBBIT, gain=1.2, shift=1)
        # five antennae, striped
        for k, a in enumerate((-0.9, -0.45, 0.0, 0.45, 0.9)):
            ln = 9.0 - abs(a) * 3.0 + (1.0 if (i + k) % 2 else 0.0)
            ax = hx + math.sin(a + sway * 0.05) * ln
            ay = hy - 3.0 - math.cos(a) * ln
            d = seg_dist(X, Y, hx + a * 2.0, hy - 3.0, ax, ay)
            stripe = (np.floor(Y) % 2) == 0
            lay.paint((d < 0.5) & stripe, PAL["white"], 5, outline=False)
            lay.paint((d < 0.5) & ~stripe, BOBBIT, 2, outline=False)
        # scissor jaws: closed while swaying, wide open then snapped on a strike
        gape = [0.35, 0.35, 0.35, 0.35, 1.25, 0.05][i]
        for s in (-1, 1):
            a0 = -math.pi / 2 + s * (0.35 + gape)
            x0, y0 = hx + s * 1.6, hy - 3.2
            x1 = x0 + math.cos(a0) * 5.5
            y1 = y0 + math.sin(a0) * 5.5
            x2 = x1 - s * 2.4
            y2 = y1 - 1.2
            d = np.minimum(seg_dist(X, Y, x0, y0, x1, y1), seg_dist(X, Y, x1, y1, x2, y2))
            lay.paint(d < 0.6, BOBBIT_B, 3)
            lay.paint((d < 0.6) & (Y < y1), BOBBIT_B, 5)
        eye(lay, X, Y, hx - 2.2, hy + 0.5)
        eye(lay, X, Y, hx + 2.2, hy + 0.5)
        lay.clean(1)
        frames.append(lay.to_image())
    return sheet(frames)


def _louse(female: bool):
    """Fish louse (Cymothoa-like isopod). Males are small and grey; the female
    is bigger, pink and carries a brood pouch full of eggs.
    4 crawl frames + 2 grip frames (legs clamp, body arches)."""
    frames = []
    rmp = LOUSE_F if female else LOUSE
    for i in range(6):
        w, h = (24, 16) if female else (16, 11)
        X, Y = grid(w, h)
        lay = Layer(w, h)
        s = 1.35 if female else 1.0
        cx, cy = w / 2 - 0.5, h / 2 - 0.5
        grip = i >= 4
        step = i % 2
        # seven pairs of hooked legs
        for k in range(7):
            lx = cx - 4.6 * s + k * 1.45 * s
            curl = 1.2 if grip else (0.9 if (k + step) % 2 else -0.3)
            d = seg_dist(X, Y, lx, cy + 1.5 * s, lx - curl, cy + 3.6 * s)
            lay.paint(d < 0.45, rmp, 1, outline=False)
        arch = 0.6 if (grip and i == 5) else 0.0
        body = (((X - cx) / (6.3 * s)) ** 2 + ((Y - cy + arch) / (3.2 * s)) ** 2 <= 1.0) & (Y < cy + 2.0 * s)
        shaded(lay, body, pro.dome_height(body), rmp, gain=1.6)
        seams = body & ((np.floor(X - cx + 40) % 2) == 0) & (X < cx + 3.6 * s) & (X > cx - 5.0 * s)
        lay.shift(seams, -1, lo=2)
        if female:
            # marsupium: translucent pouch under the belly, eggs showing through
            pouch = ((X - cx + 0.5) / 5.0) ** 2 + ((Y - cy - 2.8) / 2.6) ** 2 <= 1.0
            lay.paint(pouch & ~body, rmp, 5)
        # head with big dark eyes
        hx = cx + 6.0 * s
        head = ((X - hx) / (1.9 * s)) ** 2 + ((Y - cy) / (2.0 * s)) ** 2 <= 1.0
        shaded(lay, head, pro.dome_height(head), rmp, shift=1)
        dot(lay, X, Y, hx, cy - 0.8, PAL["black"], 0)
        if female:
            dot(lay, X, Y, hx + 0.9, cy - 0.8, PAL["black"], 0)
        # tail fan
        tail = poly_mask(X, Y, [(cx - 6 * s, cy), (cx - 8.2 * s, cy - 1.4 * s), (cx - 8.2 * s, cy + 1.6 * s), (cx - 6 * s, cy + 1.4 * s)])
        lay.paint(tail, rmp, 3)
        lay.clean(1)
        if female:
            for ex in range(-4, 4, 2):
                egg = np.hypot(X - (cx + ex + 0.5 + (i % 2) * 0.4), Y - (cy + 3.2)) < 0.9
                lay.paint(egg, EGG, 4, outline=False)
        frames.append(lay.to_image())
    return sheet(frames)


def louse():
    return _louse(False)


def louse_f():
    return _louse(True)


ALL.update({"bobbit": bobbit, "louse": louse, "louse_f": louse_f})
