"""Enemy / ecosystem creature sheets. All face right. 6 frames: 4 move + 2 attack."""
from __future__ import annotations

import math
from pixel import Canvas, Mat, sheet, rng, point_in_poly, col, seg_dist
from fish import FishModel, M, set_frame, FRAMES
import player as P

NF = 6


def A(ramp, idx=3, group=None, alpha=255, hl=True):
    return Mat(ramp, idx, auto=True, group=group or ramp, alpha=alpha, hl=hl)


# ---------------------------------------------------------------- fish based
def fish_sheet(w, h, L, extra=None, back=None, front=None, cx=None, cy=None, tail=True, fins=True, **kw):
    frames = []
    for i in range(NF):
        m = FishModel(L, cx if cx is not None else w * 0.5 + L * 0.08, cy if cy is not None else h * 0.5, **kw)
        set_frame(m, i)
        c = Canvas(w, h)
        if tail:
            m.paint_tail(c)
        if fins:
            m.paint_default_back_fins(c)
        if back:
            back(c, m)
        m.paint_body(c)
        if extra:
            extra(c, m)
        img = c.render()
        c2 = Canvas(w, h)
        if fins:
            m.paint_default_front_fins(c2)
        if front:
            front(c2, m)
        img.alpha_composite(c2.render())
        frames.append(img)
    return sheet(frames)


def bars_pattern(ramp, every, idx=1):
    def f(m, x, y, t, v):
        if v < m.belly_v and 0.15 < t < 0.8 and int(x - m.xt) % every < max(1, every // 3):
            return (ramp, idx)
        return None
    return f


def spots_pattern(ramp, idx, mod=9, v_max=0.6):
    def f(m, x, y, t, v):
        if v < v_max and (int(x) * 5 + int(y) * 11) % mod == 0:
            return (ramp, idx)
        return None
    return f


def sardine():
    return fish_sheet(18, 11, 12, H=0.34, peak=0.62, q=1.2, body="silver", belly="white", fin="silver",
                      tail="fork", tail_len=0.42, eye=0.12, dorsal=0.7, stripe=("neon", 0.35, 0.45, 0.2, 0.9))


def golden():
    return fish_sheet(20, 12, 13, H=0.36, peak=0.6, q=1.1, body="volt", belly="cream", fin="gold",
                      tail="fork", tail_len=0.45, eye=0.12, dorsal=0.8, stripe=("gold", 0.36, 0.46, 0.2, 0.9))


def pilot():
    return fish_sheet(14, 9, 9, H=0.4, peak=0.6, body="white", belly="white", fin="neon",
                      tail="fork", tail_len=0.45, eye=0.12, dorsal=0.6, pattern=bars_pattern("navy", 3, 2))


def piranha():
    return fish_sheet(24, 18, 15, H=0.66, peak=0.58, q=0.9, body="steel", belly="red", fin="steel",
                      tail="fork", tail_len=0.36, eye=0.1, dorsal=0.7, mouth_v=0.62, jaw_open=0.8,
                      belly_v=0.58, extra=P.paint_head_piranha)


def barracuda():
    return fish_sheet(50, 14, 34, H=0.24, peak=0.62, q=1.0, front_e=0.95, body="silver", belly="white",
                      fin="steel", tail="fork", tail_len=0.26, eye=0.06, dorsal=0.9, mouth_v=0.55,
                      jaw_open=0.4, pattern=bars_pattern("steel", 5, 1), extra=P.paint_head_piranha)


def shark_teeth(c, m):
    # gills
    for k in range(3):
        gx = m.xt + m.L * (0.66 + k * 0.035)
        for yy in range(int(m.top(0.68) + m.H * 0.25), int(m.top(0.68) + m.H * 0.62)):
            c.pixel(gx, yy + m.warp_offset(gx), col(m.body, 1))
    if m.open > 0.0:
        P.paint_head_piranha(c, m)


def shark_back(c, m):
    dorsal = m.fin_poly(0.5, "top", [(0.12, -0.2), (-0.03, 1.0), (0.0, 0.75), (-0.08, -0.2)])
    m.paint_poly_fin(c, dorsal, ramp=m.body, base=2, rays=False)


def shark():
    return fish_sheet(80, 36, 56, H=0.3, peak=0.6, q=1.1, front_e=0.75, body="shark", belly="white",
                      fin="shark", tail="fork", tail_len=0.34, eye=0.035, dorsal=0.3, mouth_v=0.7,
                      jaw_open=0.55, belly_v=0.6, extra=shark_teeth, back=shark_back, cy=20)


def puffer():
    return fish_sheet(24, 20, 15, H=0.8, peak=0.5, q=0.7, front_e=0.45, body="sandy", belly="cream",
                      fin="orange", tail="round", tail_len=0.3, eye=0.13, dorsal=0.5,
                      pattern=spots_pattern("brown", 2, 7))


def puffer_big():
    frames = []
    for i in range(4):
        w = h = 30
        c = Canvas(w, h)
        cx, cy, r = 15, 15, 10.5 + (0.5 if i % 2 else 0)
        # spikes
        for k in range(14):
            a = k / 14 * math.tau + i * 0.1
            x0, y0 = cx + math.cos(a) * r * 0.8, cy + math.sin(a) * r * 0.8
            x1, y1 = cx + math.cos(a) * (r + 3.5), cy + math.sin(a) * (r + 3.5)
            c.line(x0, y0, x1, y1, A("bone", 4, "spike"), 1.4)
        c.circle(cx, cy, r, A("sandy", 3, "body"))
        c.ellipse(cx, cy + 4, r * 0.8, r * 0.55, A("cream", 3, "belly"))
        for k in range(9):
            a = k * 2.3
            c.circle(cx - 2 + math.cos(a) * 6, cy - 4 + math.sin(a) * 3, 0.9, Mat("brown", 2, auto=False))
        c.ellipse(cx + 6, cy - 2, 2.5, 2.5, Mat("white", 4, auto=False, group="eye"))
        c.pixel(cx + 7, cy - 2, (10, 8, 18, 255))
        c.pixel(cx + 7, cy - 1, (10, 8, 18, 255))
        c.line(cx + 4, cy - 5, cx + 8, cy - 4, Mat("brown", 1, auto=False, group="brow"), 1.0)
        c.ellipse(cx + 9.5, cy + 3, 1.5, 1.2, Mat("ruby", 1, auto=False, group="mouth"))
        c.poly([(cx - r + 1, cy - 2), (cx - r - 4, cy - 5 + i % 2), (cx - r - 4, cy + 5 - i % 2), (cx - r + 1, cy + 2)], A("orange", 3, "fin"))
        frames.append(c.render())
    return sheet(frames)


def angler_extra(c, m):
    P.paint_head_piranha(c, m)
    P.paint_head_lure(c, m)


def angler():
    return fish_sheet(44, 36, 28, H=0.72, peak=0.66, q=0.8, front_e=0.4, body="abyss", belly="ink",
                      fin="abyss", tail="round", tail_len=0.3, eye=0.07, eye_ramp="volt", dorsal=0.4,
                      mouth_v=0.55, jaw_open=0.7, belly_v=0.7, extra=angler_extra, cy=22,
                      pattern=spots_pattern("violet", 2, 13))


# ------------------------------------------------------------- invertebrates
def shrimp():
    frames = []
    for i in range(NF):
        w, h = 18, 13
        c = Canvas(w, h)
        curl = 0.35 if i < 4 else 0.95
        leg = i % 2
        # body segments from head (right) to tail (left) along an arc
        pts = []
        for k in range(6):
            a = math.pi * 0.05 + k * (0.22 + curl * 0.12)
            pts.append((12.5 - k * 1.75, 6.0 + math.sin(a) * k * 0.55 * (1 + curl)))
        for k, (x, y) in enumerate(pts):
            r = 2.7 - k * 0.28
            c.ellipse(x, y, r * 0.9, r, A("pink", 3 if k % 2 == 0 else 4, "body"))
        tx, ty = pts[-1]
        c.poly([(tx + 1, ty - 1), (tx - 3.5, ty - 2.5 + curl * 2), (tx - 3, ty + 2.5 + curl * 2), (tx + 1, ty + 1)], A("coral", 4, "tail"))
        # head / rostrum
        c.poly([(13, 4), (17.5, 4.5), (13, 6.5)], A("pink", 4, "head"))
        # legs
        for k in range(4):
            x = 12 - k * 1.8
            c.line(x, 7.5, x - 0.8 + (0.8 if (k + leg) % 2 else 0), 10.5, Mat("coral", 2, auto=False, group="leg", outline=False), 0.9)
        # antennae
        sway = [0, 1, 0, -1, 1, 1][i]
        c.line(15, 3.5, 17.5, 0.5 + sway * 0.5, Mat("coral", 4, auto=False, group="ant", outline=False), 0.8)
        c.line(14, 3.5, 11, 0.5, Mat("coral", 4, auto=False, group="ant", outline=False), 0.8)
        img = c.render()
        from PIL import Image
        img.putpixel((14, 4), (10, 8, 18, 255))
        frames.append(img)
    return sheet(frames)


def snail():
    frames = []
    for i in range(NF):
        w, h = 18, 15
        c = Canvas(w, h)
        hide = i >= 4
        stretch = [0, 1, 2, 1, 0, 0][i]
        if not hide:
            c.poly([(3, 13), (13 + stretch, 13), (16 + stretch, 10.5), (13 + stretch, 9), (4, 10)], A("sandy", 4, "foot"))
            c.line(14 + stretch, 9.5, 15.5 + stretch, 6, Mat("sandy", 3, auto=False, group="st"), 1.0)
            c.line(13 + stretch, 9.5, 13.5 + stretch, 6.5, Mat("sandy", 3, auto=False, group="st"), 1.0)
        c.circle(8.5, 7.5, 5.8, A("shell", 3, "shell"))
        # spiral
        for k in range(26):
            a = k * 0.42
            rr = 5.0 - k * 0.17
            if rr <= 0.6:
                break
            c.pixel(8.5 + math.cos(a) * rr, 7.5 + math.sin(a) * rr, col("shell", 1))
        img = c.render()
        if not hide:
            img.putpixel((min(w - 1, 15 + stretch), 5), (10, 8, 18, 255))
            img.putpixel((13 + stretch, 6), (10, 8, 18, 255))
        frames.append(img)
    return sheet(frames)


def crab():
    frames = []
    for i in range(NF):
        w, h = 28, 20
        c = Canvas(w, h)
        atk = i >= 4
        step = i % 2
        cx, cy = 14, 12
        # legs
        for k in range(3):
            for sgn in (-1, 1):
                bx = cx + sgn * (3 + k * 2)
                c.line(bx, cy + 1, bx + sgn * 3, cy + 5 + ((k + step) % 2), Mat("red", 2, auto=False, group="leg"), 1.2)
        # claws
        for sgn in (-1, 1):
            ax = cx + sgn * 7
            ay = cy - (6 if atk else 2)
            c.line(cx + sgn * 5, cy - 1, ax, ay, Mat("red", 3, auto=False, group="arm"), 1.6)
            c.ellipse(ax + sgn * 1.5, ay - 1.5, 3.0, 2.4, A("orange", 3, "claw%d" % sgn))
            if atk and i == 4:
                c.poly([(ax + sgn * 1, ay - 2), (ax + sgn * 5, ay - 5), (ax + sgn * 4, ay - 1)], A("orange", 4, "pin"), erase=False)
        c.ellipse(cx, cy, 7.5, 4.8, A("red", 3, "shell"))
        for sgn in (-1, 1):
            c.line(cx + sgn * 2, cy - 4, cx + sgn * 2.5, cy - 7, Mat("red", 2, auto=False, group="stalk"), 1.0)
        img = c.render()
        for sgn in (-1, 1):
            img.putpixel((int(cx + sgn * 2.5), cy - 8), (250, 250, 250, 255))
        frames.append(img)
    return sheet(frames)


def jellyfish():
    frames = []
    for i in range(NF):
        w, h = 22, 30
        c = Canvas(w, h)
        pulse = [0.0, 0.6, 1.0, 0.5, 0.0, 0.0][i]
        zap = i >= 4
        ramp = "volt" if zap else "jelly"
        rx = 7.5 + pulse * 1.5
        ry = 6.5 - pulse * 1.3
        by = 9.5
        # tentacles
        for k in range(5):
            x0 = 11 - 5 + k * 2.5
            pts = []
            for j in range(8):
                yy = by + 2 + j * (2.2 - pulse * 0.4)
                pts.append((x0 + math.sin(j * 0.8 + i * 1.5 + k) * 1.2, yy))
            c.curve(pts, Mat(ramp, 3 if k % 2 else 4, auto=False, group="t", alpha=220, outline=False), 1.0)
        # oral arms
        c.poly([(9, by + 1), (13, by + 1), (12.5, by + 11 - pulse * 2), (9.5, by + 11 - pulse * 2)], Mat(ramp, 2, auto=False, alpha=200, group="arm"))

        def bell(x, y):
            dx, dy = (x - 11) / rx, (y - by) / ry
            return dy <= 0.3 and dx * dx + dy * dy <= 1.0
        c.paint_fn(bell, A(ramp, 3, "bell", alpha=235))
        c.ellipse(11, by - 1, rx * 0.45, ry * 0.4, Mat(ramp, 5, auto=False, group="organ", alpha=235))
        frames.append(c.render())
    return sheet(frames)


def moray():
    frames = []
    for i in range(NF):
        w, h = 58, 20
        c = Canvas(w, h)
        open_ = i >= 4
        ph = i * math.pi / 2
        L = 50
        pts = []
        for k in range(26):
            u = k / 25.0
            x = 4 + u * L
            y = 10 + math.sin(u * 7.0 - ph) * 2.6 * (1.0 - u) ** 1.2
            pts.append((x, y))

        def body(x, y):
            best = 99
            bu = 0
            for k in range(len(pts) - 1):
                d = seg_dist(x, y, pts[k][0], pts[k][1], pts[k + 1][0], pts[k + 1][1])
                if d < best:
                    best, bu = d, k / 25.0
            rad = 1.0 + 3.6 * min(1.0, bu * 2.2) * (1.0 if bu < 0.9 else (1.0 - (bu - 0.9) * 4))
            if best <= rad:
                yc = pts[int(bu * 25)][1]
                top = y < yc - rad * 0.2
                spot = (int(x) * 3 + int(y) * 5) % 7 == 0
                if spot and top:
                    return Mat("volt", 3, auto=False, group="body")
                return Mat("moss", 4 if y < yc - rad * 0.5 else (3 if top else 2), auto=False, group="body")
            if best <= rad + 1.6 and y < pts[min(24, int(bu * 25))][1] and 0.08 < bu < 0.8:
                return Mat("lime", 2, auto=False, group="fin")
            return False
        c.paint_fn(body, None)
        hx, hy = pts[-1]
        if open_:
            c.poly([(hx - 5, hy + 0.5), (hx + 3, hy - 1), (hx + 3, hy + 4)], Mat("ruby", 1, auto=False, group="mouth"), erase=False)
            for k in range(3):
                c.pixel(hx - 2 + k * 2, hy, col("bone", 5))
                c.pixel(hx - 1 + k * 2, hy + 2, col("bone", 5))
        img = c.render()
        img.putpixel((int(hx - 3), int(hy - 2)), (255, 240, 120, 255))
        img.putpixel((int(hx - 2), int(hy - 2)), (10, 8, 18, 255))
        frames.append(img)
    return sheet(frames)


def squid():
    frames = []
    for i in range(NF):
        w, h = 34, 18
        c = Canvas(w, h)
        spread = [0.2, 0.5, 0.8, 0.5, 1.4, 1.1][i]
        # tentacles trailing left
        for k in range(6):
            yoff = (k - 2.5) * spread
            pts = [(12, 9 + (k - 2.5) * 0.6)]
            for j in range(1, 7):
                pts.append((12 - j * 1.8, 9 + yoff * j * 0.5 + math.sin(j + i + k) * 0.6))
            c.curve(pts, Mat("pink", 3 if k % 2 else 2, auto=False, group="t"), 1.2)
        # mantle pointing right
        c.poly([(11, 5.5), (29, 7.5), (32, 9), (29, 10.5), (11, 12.5)], A("pink", 3, "mantle"))
        c.poly([(26, 7.5), (31, 3.5 + (i % 2)), (30, 8.5)], A("pink", 4, "fin"))
        c.poly([(26, 10.5), (31, 14.5 - (i % 2)), (30, 9.5)], A("pink", 2, "fin"))
        c.ellipse(13.5, 9, 2.8, 3.5, A("pink", 4, "head"))
        img = c.render()
        img.putpixel((14, 8), (250, 230, 120, 255))
        img.putpixel((15, 8), (10, 8, 18, 255))
        frames.append(img)
    return sheet(frames)


def turtle():
    frames = []
    for i in range(NF):
        w, h = 48, 32
        c = Canvas(w, h)
        flap = [0.0, 0.6, 1.0, 0.4, 0.0, 0.0][i]
        atk = i >= 4
        cx, cy = 22, 17
        # back flipper
        c.poly([(cx - 10, cy + 3), (cx - 18, cy + 7 - flap * 3), (cx - 12, cy + 7)], A("moss", 3, "bf"))
        # front flipper (far)
        c.poly([(cx + 6, cy + 1), (cx - 4, cy - 8 + flap * 10), (cx + 1, cy + 3)], A("moss", 2, "ff2"))
        # head
        hx = cx + 15 + (2 if atk else 0)
        c.ellipse(hx, cy - 1, 5.5, 4.2, A("moss", 4, "head"))
        c.line(cx + 9, cy, hx - 2, cy, Mat("moss", 3, auto=False, group="neck"), 5.0)
        # shell

        def shell(x, y):
            dx, dy = (x - cx) / 14.5, (y - cy) / 10.5
            if dy > 0.35 or dx * dx + dy * dy > 1.0:
                return False
            hx_ = (x - cx + 20) / 5.0
            hy_ = (y - cy + 20) / 4.0
            fx = hx_ - math.floor(hx_)
            fy = hy_ - math.floor(hy_ + (0.5 if int(math.floor(hx_)) % 2 else 0))
            edge = fx < 0.16 or (fy - math.floor(fy)) < 0.2
            if dy > 0.18:
                return Mat("olive", 3, auto=False, group="rim")
            return Mat("turtle", 1 if edge else (4 if dy < -0.55 else 3), auto=False, group="shell")
        c.paint_fn(shell, None)
        # front flipper (near)
        c.poly([(cx + 7, cy + 3), (cx - 1, cy + 12 - flap * 10), (cx + 3, cy + 12 - flap * 9), (cx + 11, cy + 4)], A("moss", 4, "ff"))
        img = c.render()
        img.putpixel((hx + 2, cy - 2), (10, 8, 18, 255))
        if atk:
            for k in range(3):
                img.putpixel((hx + 3 + k // 2, cy + 1), (60, 20, 20, 255))
        frames.append(img)
    return sheet(frames)


# -------------------------------------------------------------------- bosses
def boss_shark_extra(c, m):
    shark_teeth(c, m)
    # scars
    for k in range(3):
        x0 = m.xt + m.L * (0.45 + k * 0.05)
        y0 = m.top(0.5) + m.H * 0.2
        c.line(x0, y0 + m.warp_offset(x0), x0 + 5, y0 + 6 + m.warp_offset(x0), Mat("pink", 3, auto=False, group="scar", outline=False), 1.0)


def boss_shark_back(c, m):
    dorsal = m.fin_poly(0.48, "top", [(0.14, -0.2), (0.06, 0.6), (0.04, 0.7), (-0.02, 1.0), (0.01, 0.8), (-0.03, 0.75), (-0.08, -0.2)])
    m.paint_poly_fin(c, dorsal, ramp=m.body, base=2, rays=False)


def boss_shark():
    return fish_sheet(150, 64, 108, H=0.32, peak=0.6, q=1.1, front_e=0.75, body="navy", belly="white",
                      fin="navy", tail="fork", tail_len=0.34, eye=0.03, eye_ramp="red", dorsal=0.2,
                      mouth_v=0.7, jaw_open=0.6, belly_v=0.62, extra=boss_shark_extra,
                      back=boss_shark_back, cy=36)


def boss_angler_extra(c, m):
    P.paint_head_piranha(c, m)
    P.paint_head_lure(c, m)
    P.paint_skin_glow(c, m)


def boss_angler():
    return fish_sheet(130, 100, 80, H=0.78, peak=0.66, q=0.8, front_e=0.4, body="abyss", belly="ink",
                      fin="violet", tail="round", tail_len=0.3, eye=0.05, eye_ramp="volt", dorsal=0.6,
                      mouth_v=0.52, jaw_open=0.75, belly_v=0.7, extra=boss_angler_extra, cy=60,
                      pattern=spots_pattern("violet", 2, 13))


def kraken_head():
    frames = []
    for i in range(NF):
        w, h = 80, 84
        c = Canvas(w, h)
        pulse = [0.0, 0.5, 1.0, 0.5, 0.2, 0.2][i]
        angry = i >= 4
        cx, cy = 40, 40
        rx = 26 - pulse * 1.5
        ry = 34 + pulse * 1.5
        # fins at top
        c.poly([(cx - 8, cy - ry + 10), (cx - 26 - pulse * 3, cy - ry + 4), (cx - 14, cy - ry + 22)], A("red", 3, "fin"))
        c.poly([(cx + 8, cy - ry + 10), (cx + 26 + pulse * 3, cy - ry + 4), (cx + 14, cy - ry + 22)], A("red", 3, "fin"))

        top = cy - ry
        bot = cy + ry * 0.72

        def mantle(x, y):
            if y < top or y > bot:
                return False
            u = (y - top) / (bot - top)
            if u < 0.7:
                half = rx * math.sin(min(1.0, u / 0.7) * math.pi / 2) ** 0.7
            else:
                half = rx * (1.0 - (u - 0.7) * 0.5)
            if abs(x - cx) > half:
                return False
            spot = (int(x) * 7 + int(y) * 13) % 37 == 0 and u < 0.7
            return Mat("coral", 4, auto=False, group="m") if spot else A("red", 3, "m")
        c.paint_fn(mantle, None)
        eye_r = 6.0
        for sgn in (-1, 1):
            ex, ey = cx + sgn * 11, cy + 14
            c.circle(ex, ey, eye_r, Mat("volt" if angry else "orange", 4, auto=False, group="eye"))
            c.ellipse(ex, ey, 1.4, eye_r * 0.8, Mat("black", 0, auto=False, group="pupil"))
            c.line(ex - sgn * 7, ey - 9 + (3 if angry else 0), ex + sgn * 4, ey - 7, Mat("ruby", 1, auto=False, group="brow"), 2.0)
        frames.append(c.render())
    return sheet(frames)


def kraken_segment():
    frames = []
    for i in range(2):
        c = Canvas(14, 14)
        c.circle(7, 7, 5.5, A("red", 3, "seg"))
        c.circle(7, 9 - i, 2.0, Mat("coral", 4, auto=False, group="sucker"))
        c.pixel(7, 9 - i, col("coral", 2))
        frames.append(c.render())
    c = Canvas(14, 14)
    c.poly([(2, 4), (12, 7), (2, 10)], A("red", 3, "tip"))
    frames.append(c.render())
    c = Canvas(14, 14)
    c.poly([(1, 3), (13, 5), (13, 9), (1, 11)], A("red", 3, "tip"))
    c.circle(10, 7, 3, A("coral", 4, "club"))
    frames.append(c.render())
    return sheet(frames)


def leviathan_head():
    frames = []
    for i in range(NF):
        w, h = 60, 44
        m = FishModel(64, 22, 26, H=0.36, peak=0.35, q=0.8, front_e=0.8, body="navy", belly="cyan",
                      fin="cyan", eye=0.035, eye_ramp="volt", mouth_v=0.62, jaw_open=0.55, belly_v=0.7, ped=0.9)
        set_frame(m, i)
        m.phase = 0.0
        c = Canvas(w, h)
        hx0 = m.xt + m.L * 0.62
        c.poly([(hx0, m.top(0.66) + 2), (hx0 - 14, m.top(0.66) - 12 + (i % 2)), (hx0 + 4, m.top(0.7) + 1)], A("bone", 4, "horn"))
        m.paint_body(c)
        P.paint_head_piranha(c, m)
        for k in range(5):
            x = 2 + k * 7
            t = m.t_of(x)
            y0 = m.top(t) + 1
            c.line(x, y0, x + 3, y0 + m.H * 0.3, Mat("volt", 4, auto=False, group="stripe", outline=False), 1.2)
        mane = m.fin_poly(0.3, "top", [(-0.3, -0.2), (-0.25, 0.4 + 0.05 * (i % 2)), (-0.1, 0.25), (0.0, 0.45), (0.12, 0.3), (0.2, -0.2)])
        m.paint_poly_fin(c, mane, ramp="cyan", base=3)
        frames.append(c.render())
    return sheet(frames)


def leviathan_segment():
    frames = []
    for i in range(2):
        c = Canvas(30, 30)
        c.poly([(9, 8), (15, -1 + i), (21, 8)], A("cyan", 3, "fin"))
        c.circle(15, 15, 10, A("navy", 3, "seg"))
        for k in range(3):
            c.line(9 + k * 5, 8, 11 + k * 5, 22, Mat("volt", 4 if i else 3, auto=False, group="stripe", outline=False), 1.2)
        frames.append(c.render())
    c = Canvas(30, 30)
    c.poly([(26, 10), (2, 3), (8, 15), (2, 27), (26, 20)], A("cyan", 3, "tail"))
    c.circle(24, 15, 6, A("navy", 3, "seg"))
    frames.append(c.render())
    frames.append(frames[2])
    return sheet(frames)


ALL = {
    "sardine": sardine, "golden": golden, "pilot": pilot, "piranha": piranha,
    "barracuda": barracuda, "shark": shark, "puffer": puffer, "puffer_big": puffer_big,
    "angler": angler, "shrimp": shrimp, "snail": snail, "crab": crab, "jellyfish": jellyfish,
    "moray": moray, "squid": squid, "turtle": turtle,
    "boss_shark": boss_shark, "boss_angler": boss_angler, "kraken_head": kraken_head,
    "kraken_segment": kraken_segment, "leviathan_head": leviathan_head,
    "leviathan_segment": leviathan_segment,
}
