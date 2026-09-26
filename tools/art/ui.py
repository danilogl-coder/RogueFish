"""UI kit: 9-slice panels, buttons, cards, bars, touch controls, icons and logo."""
from __future__ import annotations

import math
import os
from PIL import Image, ImageDraw, ImageFont
from pixel import Canvas, Mat, sheet, rng, col, dither, hexc, scale

FONT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "fonts", "PressStart2P-Regular.ttf")


def A(ramp, idx=3, group=None, alpha=255):
    return Mat(ramp, idx, auto=True, group=group or ramp, alpha=alpha)


def F(ramp, idx=3, group=None, alpha=255, outline=True):
    return Mat(ramp, idx, auto=False, group=group or ramp, alpha=alpha, outline=outline)


# ------------------------------------------------------------- 9-slices
def frame(w, h, fill, border, light, dark, radius=2, inner=None, fill_alpha=255):
    img = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    px = img.load()
    for y in range(h):
        for x in range(w):
            # rounded corners
            cx = min(x, w - 1 - x)
            cy = min(y, h - 1 - y)
            if cx + cy < radius:
                continue
            edge = cx == 0 or cy == 0 or cx + cy == radius
            if edge:
                px[x, y] = border
            elif cx == 1 or cy == 1 or cx + cy == radius + 1:
                px[x, y] = light if (y < h / 2 and cy == 1) or (cx == 1 and x < w / 2) else dark
            else:
                c = fill
                if inner and (cx == 2 or cy == 2):
                    c = inner
                px[x, y] = (c[0], c[1], c[2], fill_alpha)
    return img


def panel():
    img = frame(24, 24, hexc("#10213a"), hexc("#050a14"), hexc("#3a6a94"), hexc("#0a1628"), 3, hexc("#16304e"), 240)
    px = img.load()
    for (x, y) in ((3, 3), (20, 3), (3, 20), (20, 20)):
        px[x, y] = hexc("#6ec2c6")
    return img


def panel_light():
    return frame(24, 24, hexc("#1c3a5c"), hexc("#050a14"), hexc("#5ea8c8"), hexc("#10243c"), 3, hexc("#244a70"), 250)


def button(state):
    fills = {"normal": ("#1f7a8c", "#5ee0d8", "#0e3e52"), "hover": ("#28949e", "#8ef0e4", "#10485a"),
             "pressed": ("#135868", "#1f7a8c", "#0a2e3e"), "disabled": ("#2c3a4c", "#46586e", "#1a2432"),
             "gold": ("#c47a1c", "#ffd35c", "#6a3410"), "gold_pressed": ("#8e5214", "#c47a1c", "#4a240a"),
             "red": ("#a82a3a", "#ff7a6a", "#541020")}
    f, l, d = fills[state]
    h = 20
    img = frame(24, h, hexc(f), hexc("#050a14"), hexc(l), hexc(d), 2)
    if state not in ("pressed", "gold_pressed"):
        px = img.load()
        for x in range(2, 22):
            px[x, h - 2] = hexc(d)
            px[x, h - 3] = hexc(d)
    return img


def card(rarity):
    col_map = {"common": ("#8a9ab0", "#d4dae6"), "rare": ("#2aa0e8", "#8ee8ff"),
               "epic": ("#9a48b4", "#e39be6"), "legend": ("#ee8626", "#ffe98f"), "mutation": ("#3a9c50", "#a4dc4c")}
    b, l = col_map[rarity]
    img = frame(32, 32, hexc("#0e1a2e"), hexc("#050a14"), hexc(l), hexc(b), 3, hexc(b), 250)
    px = img.load()
    # top gem
    for y in range(0, 5):
        for x in range(13, 19):
            if abs(x - 15.5) + abs(y - 2) <= 3:
                px[x, y] = hexc(l) if abs(x - 15.5) + abs(y - 2) <= 1.5 else hexc(b)
    return img


def bar_frame():
    return frame(12, 10, hexc("#07101e"), hexc("#050a14"), hexc("#2c4a6a"), hexc("#0a1628"), 1, None, 230)


def bar_fill(ramp):
    img = Image.new("RGBA", (4, 6), (0, 0, 0, 0))
    px = img.load()
    for x in range(4):
        px[x, 0] = col(ramp, 5)
        px[x, 1] = col(ramp, 4)
        px[x, 2] = col(ramp, 4)
        px[x, 3] = col(ramp, 3)
        px[x, 4] = col(ramp, 3)
        px[x, 5] = col(ramp, 2)
    return img


# -------------------------------------------------------------- touch
def joy_base():
    s = 64
    img = Image.new("RGBA", (s, s), (0, 0, 0, 0))
    px = img.load()
    for y in range(s):
        for x in range(s):
            d = math.hypot(x - 31.5, y - 31.5)
            if d < 31:
                if d > 29.5:
                    px[x, y] = (150, 230, 240, 200)
                elif d > 28:
                    px[x, y] = (20, 60, 90, 160)
                else:
                    px[x, y] = (8, 30, 52, 90 if dither(x, y, 0.5) else 60)
    for k in range(4):
        a = k * math.pi / 2
        for j in range(3):
            for w in range(-j, j + 1):
                x = 31.5 + math.cos(a) * (24 - j) - math.sin(a) * w
                y = 31.5 + math.sin(a) * (24 - j) + math.cos(a) * w
                px[int(x), int(y)] = (150, 230, 240, 170)
    return img


def joy_knob():
    c = Canvas(26, 26)
    c.circle(13, 13, 11, A("cyan", 3, "k", alpha=235))
    img = c.render()
    px = img.load()
    px[9, 8] = (255, 255, 255, 255)
    px[10, 8] = (255, 255, 255, 255)
    px[9, 9] = (255, 255, 255, 255)
    return img


def action_button(pressed=False, ramp="coral", icon=None):
    c = Canvas(56, 56)
    c.circle(28, 28 + (1 if pressed else 0), 25, A(ramp, 2 if pressed else 3, "b", alpha=235))
    img = c.render()
    if icon is not None:
        ic = scale(icon, 2)
        img.alpha_composite(ic, (28 - ic.size[0] // 2, 28 - ic.size[1] // 2 + (1 if pressed else 0)))
    return img


def round_button(pressed=False):
    c = Canvas(24, 24)
    c.circle(12, 12 + (1 if pressed else 0), 10.5, A("navy", 3 if not pressed else 2, "b", alpha=230))
    return c.render()


# -------------------------------------------------------------- icons
def icon_canvas(size=16):
    return Canvas(size, size)


def ic_bubble():
    c = icon_canvas()
    for x, y, r in ((6, 9, 4.5), (12, 5, 2.5), (12.5, 12, 1.8)):
        c.circle(x, y, r, F("cyan", 3, "b%d" % x, alpha=255))
        c.circle(x, y, r - 1.2, F("glow", 2, "i%d" % x, alpha=255, outline=False))
    img = c.render()
    img.putpixel((4, 7), (255, 255, 255, 255))
    img.putpixel((11, 4), (255, 255, 255, 255))
    return img


def ic_ink():
    c = icon_canvas()
    for x, y, r in ((6, 9, 4), (10, 7, 4), (9, 11, 3.5), (5, 5, 2.5)):
        c.circle(x, y, r, A("ink", 4, "i"))
    return c.render()


def ic_pulse():
    c = icon_canvas()
    c.circle(8, 8, 6.5, F("volt", 2, "r", outline=True))
    c.circle(8, 8, 5, F("black", 0, "x"), erase=True)
    c.poly([(9, 1.5), (4, 9), (7.5, 9), (6, 14.5), (12, 6.5), (8.5, 6.5)], A("volt", 4, "b"))
    return c.render()


def ic_spines():
    c = icon_canvas()
    for k in range(5):
        a = -math.pi / 2 + (k - 2) * 0.45
        c.poly([(8 + math.cos(a + 1.3) * 1.8, 13 + math.sin(a + 1.3) * 1.8), (8 + math.cos(a) * 12, 13 + math.sin(a) * 12),
                (8 + math.cos(a - 1.3) * 1.8, 13 + math.sin(a - 1.3) * 1.8)], A("bone", 4, "s%d" % k))
    return c.render()


def ic_pilot():
    c = icon_canvas()
    c.circle(8, 8, 6.5, F("neon", 2, "orbit", outline=False))
    c.circle(8, 8, 5.5, F("black", 0, "x"), erase=True)
    for x, y in ((3, 5), (11, 11)):
        c.ellipse(x + 1, y, 2.6, 1.6, A("white", 4, "f"))
        c.poly([(x - 1, y), (x - 3, y - 1.8), (x - 3, y + 1.8)], A("neon", 4, "t"))
    return c.render()


def ic_sonar():
    c = icon_canvas()
    for r in (7, 4.5):
        def f(x, y, r=r):
            d = math.hypot(x - 3, y - 8)
            return abs(d - r) < 0.8 and x > 3.5
        c.paint_fn(f, F("cyan", 4, "r%d" % r))
    c.circle(3, 8, 2, A("cyan", 4, "s"))
    return c.render()


def ic_whirl():
    c = icon_canvas()

    def f(x, y):
        dx, dy = x - 8, y - 8
        d = math.hypot(dx, dy)
        if d > 7:
            return False
        a = math.atan2(dy, dx)
        return math.sin(a * 2 + d * 0.9) > 0.35
    c.paint_fn(f, F("cyan", 4, "w"))
    return c.render()


def ic_torpedo():
    c = icon_canvas()
    c.ellipse(9, 8, 5.5, 3.5, A("glow", 3, "t"))
    c.poly([(3, 8), (1, 5), (1, 11)], A("orange", 4, "f"))
    c.circle(3, 3, 1.5, F("volt", 5, "s", outline=False))
    return c.render()


def ic_heart():
    from fx import heart
    img = Image.new("RGBA", (16, 16))
    h = heart(13)
    img.alpha_composite(h, (1, 2))
    return img


def ic_gills():
    c = icon_canvas()
    c.ellipse(8, 8, 7, 5.5, A("gold", 3, "b"))
    for k in range(3):
        c.line(4 + k * 3, 4, 3 + k * 3, 12, F("red", 2, "g%d" % k, outline=False), 1.2)
    return c.render()


def ic_fins():
    c = icon_canvas()
    c.poly([(2, 13), (8, 2), (14, 4), (9, 9), (14, 14)], A("cyan", 3, "f"))
    for k in range(3):
        c.line(3 + k * 2, 12, 8 + k * 2, 4, F("cyan", 5, "r", outline=False), 0.7)
    return c.render()


def ic_teeth():
    c = icon_canvas()
    c.rect(1, 2, 14, 3, A("red", 3, "gum"))
    c.rect(1, 11, 14, 3, A("red", 2, "gum2"))
    for k in range(4):
        c.poly([(1.5 + k * 3.5, 5), (4.5 + k * 3.5, 5), (3 + k * 3.5, 10)], A("bone", 4, "t%d" % k))
    return c.render()


def ic_venom():
    c = icon_canvas()
    c.circle(8, 10, 4.5, A("poison", 3, "d"))
    c.poly([(3.8, 9), (8, 1.5), (12.2, 9)], A("poison", 3, "d"))
    img = c.render()
    img.putpixel((6, 8), col("poison", 5))
    img.putpixel((6, 9), col("poison", 5))
    return img


def ic_battery():
    c = icon_canvas()
    c.rect(3, 4, 10, 10, A("steel", 3, "b"))
    c.rect(6, 2, 4, 2, A("steel", 4, "t"))
    c.poly([(9, 5), (5.5, 10), (8, 10), (7, 13), (10.5, 8), (8, 8)], F("volt", 5, "z", outline=False))
    return c.render()


def ic_eye(ramp="glow"):
    c = icon_canvas()

    def f(x, y):
        return abs(y - 8) < 5.5 * math.cos((x - 8) / 8 * math.pi / 2) * 1.05 and 0.5 < x < 15.5
    c.paint_fn(f, F("white", 4, "w"))
    c.circle(8, 8, 3.5, F(ramp, 3, "iris"))
    c.circle(8, 8, 1.5, F("black", 0, "p", outline=False))
    img = c.render()
    img.putpixel((7, 6), (255, 255, 255, 255))
    return img


def ic_shell():
    c = icon_canvas()
    c.ellipse(8, 9, 6.5, 6, A("steel", 3, "s"))
    c.rect(0, 14, 16, 3, F("black", 0, "x"), erase=True)
    for k in range(5):
        c.line(8, 13, 2.5 + k * 2.75, 4, F("steel", 1, "l", outline=False), 0.8)
    return c.render()


def ic_magnet():
    c = icon_canvas()

    def f(x, y):
        d = math.hypot(x - 8, y - 7)
        return (4 < d < 7.5 and y <= 7) or ((3 <= abs(x - 8) + 0.5 <= 7.5 and abs(x - 8) > 3.9) and 7 < y < 13)
    c.paint_fn(f, A("red", 3, "m"))
    c.rect(0.5, 11, 4, 2.5, F("white", 4, "p1"))
    c.rect(11.5, 11, 4, 2.5, F("white", 4, "p2"))
    return c.render()


def ic_star(ramp="volt"):
    c = icon_canvas()
    pts = []
    for k in range(10):
        a = -math.pi / 2 + k * math.pi / 5
        r = 7 if k % 2 == 0 else 3
        pts.append((8 + math.cos(a) * r, 8.5 + math.sin(a) * r))
    c.poly(pts, A(ramp, 4, "s"))
    return c.render()


def ic_brain():
    c = icon_canvas()
    c.ellipse(8, 8, 6.5, 5.5, A("pink", 4, "b"))
    for k in range(3):
        c.line(4 + k * 3, 4, 5 + k * 3, 12, F("pink", 2, "l", outline=False), 0.8)
    return c.render()


def ic_skull():
    c = icon_canvas()
    c.circle(8, 7, 5.5, A("bone", 4, "s"))
    c.rect(5, 10, 6, 4, A("bone", 4, "s"))
    c.circle(6, 7, 1.6, F("black", 0, "e", outline=False))
    c.circle(10, 7, 1.6, F("black", 0, "e", outline=False))
    return c.render()


def ic_clock():
    c = icon_canvas()
    c.circle(8, 8, 6.5, A("white", 4, "c"))
    c.line(8, 8, 8, 4, F("black", 1, "h", outline=False), 1)
    c.line(8, 8, 11, 9, F("black", 1, "m", outline=False), 1)
    return c.render()


def ic_pause():
    c = icon_canvas()
    c.rect(3.5, 3, 3.5, 10, F("white", 5, "a"))
    c.rect(9, 3, 3.5, 10, F("white", 5, "b"))
    return c.render()


def ic_reroll():
    c = icon_canvas()

    def f(x, y):
        d = math.hypot(x - 8, y - 8)
        a = math.atan2(y - 8, x - 8)
        return 4 < d < 6.5 and not (-0.4 < a < 0.5) and not (2.7 < abs(a))
    c.paint_fn(f, F("cyan", 4, "r"))
    c.poly([(11, 8.5), (15.5, 8.5), (13.2, 5)], F("cyan", 4, "a1"))
    c.poly([(0.5, 7.5), (5, 7.5), (2.8, 11)], F("cyan", 4, "a2"))
    return c.render()


def ic_lock():
    c = icon_canvas()

    def f(x, y):
        d = math.hypot(x - 8, y - 6)
        return 2.5 < d < 4.5 and y < 7
    c.paint_fn(f, F("steel", 4, "arc"))
    c.rect(3, 7, 10, 8, A("gold", 3, "b"))
    c.rect(7.5, 9, 1.5, 3, F("black", 0, "k", outline=False))
    return c.render()


def ic_check():
    c = icon_canvas()
    c.curve([(2, 8), (6, 12), (14, 3)], F("lime", 4, "c"), 2.4)
    return c.render()


def ic_music():
    c = icon_canvas()
    c.circle(5, 12, 2.5, F("white", 5, "n1"))
    c.circle(12, 10, 2.5, F("white", 5, "n2"))
    c.line(7, 12, 7, 3, F("white", 5, "s1"), 1.3)
    c.line(14, 10, 14, 2, F("white", 5, "s2"), 1.3)
    c.line(7, 3, 14, 2, F("white", 5, "b"), 2.0)
    return c.render()


def ic_sound():
    c = icon_canvas()
    c.poly([(2, 6), (5, 6), (9, 2), (9, 14), (5, 10), (2, 10)], F("white", 5, "s"))

    def f(x, y):
        d = math.hypot(x - 8, y - 8)
        return (abs(d - 4) < 0.7 or abs(d - 6.5) < 0.7) and x > 10
    c.paint_fn(f, F("white", 4, "w", outline=False))
    return c.render()


def ic_vibrate():
    c = icon_canvas()
    c.rect(5, 2, 6, 12, A("steel", 4, "p"))
    c.rect(6.5, 3.5, 3, 7, F("cyan", 3, "sc", outline=False))
    for sx in (2, 13):
        c.line(sx, 5, sx, 11, F("white", 5, "v%d" % sx, outline=False), 1)
    return c.render()


def ic_gear():
    c = icon_canvas()

    def f(x, y):
        d = math.hypot(x - 8, y - 8)
        a = math.atan2(y - 8, x - 8)
        r = 5.2 + (1.8 if math.cos(a * 8) > 0.2 else 0)
        return 2.2 < d < r
    c.paint_fn(f, A("steel", 4, "g"))
    return c.render()


def ic_back():
    c = icon_canvas()
    c.poly([(2, 8), (8, 2), (8, 5.5), (14, 5.5), (14, 10.5), (8, 10.5), (8, 14)], F("white", 5, "a"))
    return c.render()


def ic_play():
    c = icon_canvas()
    c.poly([(4, 2), (14, 8), (4, 14)], A("lime", 4, "p"))
    return c.render()


def ic_trophy():
    c = icon_canvas()
    c.poly([(3, 2), (13, 2), (12, 8), (8, 10), (4, 8)], A("gold", 4, "c"))
    c.rect(7, 10, 2, 3, A("gold", 3, "s"))
    c.rect(4, 13, 8, 2, A("gold", 3, "b"))
    return c.render()


def ic_crown():
    c = icon_canvas()
    c.poly([(1.5, 13), (1.5, 4), (5, 8), (8, 2.5), (11, 8), (14.5, 4), (14.5, 13)], A("gold", 4, "c"))
    c.pixel(8, 9, col("ruby", 4))
    c.pixel(4, 10, col("cyan", 4))
    c.pixel(12, 10, col("cyan", 4))
    return c.render()


def ic_hidden():
    c = icon_canvas()
    c.curve([(1, 8), (4, 11), (8, 12), (12, 11), (15, 8)], F("lime", 4, "l"), 1.6)
    for x in (4, 8, 12):
        c.line(x, 12, x - 0.5 + (x - 8) * 0.2, 14.5, F("lime", 4, "k%d" % x), 1.2)
    return c.render()


def ic_plus():
    c = icon_canvas()
    c.rect(6.5, 2, 3, 12, F("lime", 4, "a"))
    c.rect(2, 6.5, 12, 3, F("lime", 4, "a"))
    return c.render()


def ic_fang():
    c = icon_canvas()
    c.poly([(3, 2), (13, 2), (12, 5), (9, 14), (7, 14), (4, 5)], A("bone", 4, "f"))
    return c.render()


def ic_wave():
    c = icon_canvas()
    pts = [(x, 8 + math.sin(x * 0.8) * 2.5) for x in range(1, 16)]
    c.curve(pts, F("cyan", 4, "w"), 2.2)
    pts2 = [(x, 12 + math.sin(x * 0.8 + 1) * 1.5) for x in range(2, 15)]
    c.curve(pts2, F("cyan", 3, "w2"), 1.4)
    return c.render()


def ic_coral():
    c = icon_canvas()
    c.line(8, 15, 8, 8, A("coral", 3, "c"), 2.6)
    c.line(8, 9, 3, 4, A("coral", 3, "c"), 2.2)
    c.line(8, 10, 13, 3, A("coral", 3, "c"), 2.2)
    c.line(5, 6, 5, 1.5, A("coral", 3, "c"), 1.8)
    return c.render()


def ic_fish():
    c = icon_canvas()
    c.ellipse(9, 8, 5.5, 4, A("gold", 4, "b"))
    c.poly([(4, 8), (0.5, 4), (0.5, 12)], A("flame", 4, "t"))
    img = c.render()
    img.putpixel((12, 7), (10, 8, 18, 255))
    return img


def ic_dna():
    c = icon_canvas()
    for k in range(14):
        y = 1 + k
        x1 = 8 + math.sin(k * 0.55) * 5
        x2 = 8 - math.sin(k * 0.55) * 5
        c.pixel(x1, y, col("lime", 4))
        c.pixel(x2, y, col("cyan", 4))
        if k % 3 == 0:
            for x in range(int(min(x1, x2)) + 1, int(max(x1, x2))):
                c.pixel(x, y, col("white", 3))
    return c.render()


def ic_numbers():
    img = Image.new("RGBA", (16, 16), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)
    d.fontmode = "1"
    f = ImageFont.truetype(FONT, 8)
    d.text((1, 4), "12", font=f, fill=hexc("#ffbf45"))
    return img


def ic_pearl():
    c = icon_canvas()
    c.circle(8, 8.5, 5.8, A("white", 4, "p"))
    img = c.render()
    for x, y in ((6, 6), (6, 5), (5, 6)):
        img.putpixel((x, y), (255, 255, 255, 255))
    img.putpixel((10, 11), col("cyan", 4))
    return img


def ic_chest():
    c = icon_canvas()
    c.rect(1.5, 7, 13, 7.5, A("brown", 3, "b"))
    c.poly([(1.5, 7), (2.5, 3), (13.5, 3), (14.5, 7)], A("brown", 4, "l"))
    c.rect(1.5, 8, 13, 1.5, F("volt", 4, "band", outline=False))
    c.rect(7, 6, 2, 4, F("gold", 5, "lock", outline=False))
    return c.render()


def ic_arrow():
    c = icon_canvas()
    c.poly([(2, 3), (14, 8), (2, 13), (5, 8)], A("volt", 4, "a"))
    return c.render()


ICONS = {
    # weapons
    "w_bubble": ic_bubble, "w_ink": ic_ink, "w_pulse": ic_pulse, "w_spines": ic_spines,
    "w_pilot": ic_pilot, "w_sonar": ic_sonar, "w_whirl": ic_whirl,
    # passives
    "p_gills": ic_gills, "p_heart": ic_heart, "p_fins": ic_fins, "p_teeth": ic_teeth,
    "p_venom": ic_venom, "p_battery": ic_battery, "p_eyes": lambda: ic_eye("violet"), "p_shell": ic_shell,
    "p_magnet": ic_magnet, "p_luck": lambda: ic_star("orange"), "p_brain": ic_brain,
    # misc
    "torpedo": ic_torpedo, "skull": ic_skull, "clock": ic_clock, "pause": ic_pause, "reroll": ic_reroll,
    "lock": ic_lock, "check": ic_check, "music": ic_music, "sound": ic_sound, "vibrate": ic_vibrate,
    "gear": ic_gear, "back": ic_back, "play": ic_play, "trophy": ic_trophy, "crown": ic_crown,
    "hidden": ic_hidden, "plus": ic_plus, "fang": ic_fang, "wave": ic_wave, "coral": ic_coral,
    "fish": ic_fish, "dna": ic_dna, "numbers": ic_numbers, "arrow": ic_arrow, "star": ic_star,
    "eye": ic_eye, "heart": ic_heart, "bolt": ic_pulse, "venom": ic_venom,
    "pearl": ic_pearl, "chest": ic_chest,
}


def icon_atlas():
    names = list(ICONS.keys())
    cols = 8
    rows = (len(names) + cols - 1) // cols
    img = Image.new("RGBA", (cols * 16, rows * 16), (0, 0, 0, 0))
    for i, n in enumerate(names):
        ic = ICONS[n]()
        img.alpha_composite(ic, ((i % cols) * 16, (i // cols) * 16))
    return img, names


# --------------------------------------------------------------- logo
def logo():
    f = ImageFont.truetype(FONT, 24)
    f2 = ImageFont.truetype(FONT, 32)
    w, h = 260, 80
    mask = Image.new("L", (w, h), 0)
    d = ImageDraw.Draw(mask)
    d.fontmode = "1"
    d.text((10, 6), "ROGUE", font=f, fill=255)
    d.text((58, 38), "FISH", font=f2, fill=255)
    bbox = mask.getbbox()
    out = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    m = mask.load()
    o = out.load()
    top_ramp = ["#fff0a0", "#ffd35c", "#f5a02a", "#e0661c"]
    fish_ramp = ["#c8fbff", "#5ee0ff", "#2aa0e8", "#1f5eb4"]
    for y in range(h):
        for x in range(w):
            if m[x, y]:
                if y < 34:
                    rr = top_ramp
                    t = (y - 6) / 24
                else:
                    rr = fish_ramp
                    t = (y - 38) / 32
                idx = min(3, max(0, int(t * 4)))
                o[x, y] = hexc(rr[idx])
    # outline + drop shadow
    res = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    r = res.load()
    for y in range(h):
        for x in range(w):
            if m[x, y]:
                continue
            near = False
            for dx in (-2, -1, 0, 1, 2):
                for dy in (-2, -1, 0, 1, 2):
                    if abs(dx) + abs(dy) <= 2 and 0 <= x + dx < w and 0 <= y + dy < h and m[x + dx, y + dy]:
                        near = True
            if near:
                r[x, y] = hexc("#07101e")
    shadow = Image.new("RGBA", (w, h), (0, 0, 0, 0))
    s = shadow.load()
    for y in range(h):
        for x in range(w):
            if r[x, y][3] or o[x, y][3]:
                if x + 3 < w and y + 3 < h:
                    s[x + 3, y + 3] = hexc("#07101e", 200)
    shadow.alpha_composite(res)
    shadow.alpha_composite(out)
    # shine pixels
    for x in range(bbox[0], bbox[2], 7):
        for y in range(8, 12):
            if m[x, y]:
                shadow.putpixel((x, y), hexc("#ffffff"))
                break
    return shadow.crop(shadow.getbbox())


ALL = {
    "panel": panel, "panel_light": panel_light,
    "btn_normal": lambda: button("normal"), "btn_hover": lambda: button("hover"),
    "btn_pressed": lambda: button("pressed"), "btn_disabled": lambda: button("disabled"),
    "btn_gold": lambda: button("gold"), "btn_gold_pressed": lambda: button("gold_pressed"),
    "btn_red": lambda: button("red"),
    "card_common": lambda: card("common"), "card_rare": lambda: card("rare"),
    "card_epic": lambda: card("epic"), "card_legend": lambda: card("legend"),
    "card_mutation": lambda: card("mutation"),
    "bar_frame": bar_frame, "bar_hp": lambda: bar_fill("red"), "bar_xp": lambda: bar_fill("cyan"),
    "bar_boss": lambda: bar_fill("poison"), "bar_stealth": lambda: bar_fill("lime"),
    "bar_wave": lambda: bar_fill("orange"),
    "joy_base": joy_base, "joy_knob": joy_knob,
    "btn_attack": lambda: action_button(False, "coral", ic_fang()),
    "btn_attack_pressed": lambda: action_button(True, "coral", ic_fang()),
    "btn_round": round_button, "btn_round_pressed": lambda: round_button(True),
    "logo": logo,
}
