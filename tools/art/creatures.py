"""Invertebrates, reptiles and non-fish boss parts. All face right. 6 frames: 4 move + 2 action.

Fish (and fish-like bosses) live in fishes.py and use the jaw rig in fishpro.py."""
from __future__ import annotations

import math
from pixel import Canvas, Mat, sheet, col

NF = 6


def A(ramp, idx=3, group=None, alpha=255, hl=True):
    return Mat(ramp, idx, auto=True, group=group or ramp, alpha=alpha, hl=hl)





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
    "shrimp": shrimp, "snail": snail, "crab": crab, "jellyfish": jellyfish, "squid": squid, "turtle": turtle,
    "kraken_head": kraken_head, "kraken_segment": kraken_segment, "leviathan_segment": leviathan_segment,
}
