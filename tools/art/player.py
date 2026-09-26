"""Player fish atlases: one PNG per species/stage, one row per layer.

Row order (see LAYERS) is mirrored in scripts/data/player_art.gd.
"""
from __future__ import annotations

import math
from pixel import Canvas, sheet, stack_rows, rng, point_in_poly, col
from fish import FishModel, M, set_frame, FRAMES

STAGE_LEN = [20, 28, 36, 46, 58]

SPECIES = {
    "dourado": dict(H=0.58, peak=0.56, q=1.0, body="gold", belly="cream", fin="flame",
                    tail="veil", tail_len=0.55, eye=0.1, dorsal=1.0),
    "neon": dict(H=0.4, peak=0.6, q=1.1, body="neon", belly="white", fin="glow",
                 tail="fork", tail_len=0.42, eye=0.1, dorsal=0.8, fin_alpha=235,
                 stripe=("cyan", 0.28, 0.44, 0.18, 0.96), front_e=0.6),
    "garoupa": dict(H=0.56, peak=0.52, q=0.9, body="olive", belly="sandy", fin="brown",
                    tail="round", tail_len=0.36, eye=0.075, mouth_v=0.64, jaw_open=0.75,
                    dorsal=0.8, front_e=0.5),
}


def neon_pattern(m, x, y, t, v):
    if v > 0.5 and t < 0.55 and v < m.belly_v + 0.12:
        return ("red", 3 if v < 0.58 else 2)
    return None


def garoupa_pattern(m, x, y, t, v):
    r = rng(int(x) * 131 + int(y) * 71)
    h = (int(x) * 7 + int(y) * 13) % 11
    if v < m.belly_v and h == 0:
        return ("brown", 2)
    if v < m.belly_v and h == 5 and r.random() < 0.6:
        return ("sandy", 3)
    return None


PATTERNS = {"neon": neon_pattern, "garoupa": garoupa_pattern}

LAYERS = [
    "body", "tail", "fins_back", "fins_front",
    "head_piranha", "head_sword", "head_lure",
    "fins_spiky_back", "fins_spiky_front", "fins_wing_back", "fins_wing_front",
    "fins_volt_back", "fins_volt_front",
    "skin_armor", "skin_toxic", "skin_glow",
    "tail_fork", "tail_sting", "tail_eel",
]


def canvas_size(L):
    w = int(L * 2.0) + 6
    h = int(L * 1.25) + 6
    return w + (w % 2), h + (h % 2)


def make_model(species, L, w, h):
    kw = dict(SPECIES[species])
    m = FishModel(L, w * 0.5 + L * 0.12, h * 0.52, **kw)
    m.pattern = PATTERNS.get(species)
    return m


# --------------------------------------------------------------- mutations
def body_mask_fn(m):
    def f(x, y):
        x, y = m.warp(x, y)
        kind, sx, sy = m.classify(x, y)
        if kind in ("upper", "lower"):
            return sx, sy
        return None
    return f


def paint_head_piranha(c, m):
    # protruding lower jaw + teeth
    L = m.L
    my = m.mouth_y
    hx = m.xt + L * 0.8

    def jaw(x, y):
        x, y = m.warp(x, y)
        if m.open > 0 and x > hx:
            sx, sy = m.to_jaw_space(x, y)
        else:
            sx, sy = x, y
        t = m.t_of(sx)
        if 0.78 < t < 1.07 and my + 0.3 <= sy <= my + max(2.0, m.H * 0.16) * (1.0 - max(0.0, t - 0.95) * 4):
            return M("red", 2 if sy > my + 1.5 else 3, group="jaw")
        return False
    c.paint_fn(jaw, None)
    n = max(3, int(L / 7))
    tw = max(1.0, L * 0.035)
    for i in range(n):
        t = 0.84 + i * (0.16 / n)
        tx = m.xt + t * L

        def tooth_up(x, y, tx=tx):
            x, y = m.warp(x, y)
            return point_in_poly(x, y, [(tx - tw, my - 0.2), (tx + tw, my - 0.2), (tx + 0.2, my + tw * 1.9)]) and M("bone", 4, group="tooth")

        def tooth_dn(x, y, tx=tx):
            x, y = m.warp(x, y)
            if m.open > 0 and x > hx:
                x, y = m.to_jaw_space(x, y)
            return point_in_poly(x, y, [(tx - tw + 1, my + 0.8), (tx + tw + 1, my + 0.8), (tx + 1.2, my - tw * 1.5)]) and M("bone", 5, group="tooth")
        c.paint_fn(tooth_up, None)
        if m.open > 0 or i % 2 == 0:
            c.paint_fn(tooth_dn, None)


def paint_head_sword(c, m):
    L = m.L
    y0 = m.mouth_y - max(1.0, m.H * 0.12)
    x0 = m.xn - L * 0.1
    ln = L * 0.36
    thick = max(1.6, m.H * 0.16)

    def f(x, y):
        x, y = m.warp(x, y)
        u = (x - x0) / ln
        if u < 0.0 or u > 1.0:
            return False
        half = thick * (1.0 - u) * 0.5 + 0.35
        if abs(y - y0) > half:
            return False
        stripe = int((x - x0) + (y - y0) * 1.5) % 4 == 0
        idx = 4 if y < y0 else 3
        if stripe:
            idx -= 1
        return M("bone", idx, group="sword")
    c.paint_fn(f, None)


def lure_pts(m):
    L, H = m.L, m.H
    sway = math.sin(m.phase) * L * 0.02
    base = (m.xt + L * 0.78, m.top(0.78) + 0.5)
    mid = (m.xt + L * 0.95, m.top(0.78) - H * 0.55 + sway)
    tip = (m.xn + L * 0.14, m.top(0.78) - H * 0.35 + sway * 1.5)
    return base, mid, tip


def paint_head_lure(c, m):
    base, mid, tip = lure_pts(m)
    pts = []
    for i in range(9):
        t = i / 8.0
        x = (1 - t) ** 2 * base[0] + 2 * (1 - t) * t * mid[0] + t * t * tip[0]
        y = (1 - t) ** 2 * base[1] + 2 * (1 - t) * t * mid[1] + t * t * tip[1]
        pts.append((x, y))
    c.curve(pts, M("abyss", 3, group="stalk"), width=max(1.0, m.L * 0.035), warp=None)
    r = max(1.6, m.L * 0.065)
    c.circle(tip[0], tip[1] + r * 0.6, r, M("glow", 3, group="bulb"))
    c.circle(tip[0] - r * 0.25, tip[1] + r * 0.35, r * 0.5, M("glow", 5, group="bulb2"))


def spike_list(m, t0, t1, n, side, length):
    out = []
    for i in range(n):
        t = t0 + (t1 - t0) * (i / max(1, n - 1))
        x = m.xt + t * m.L
        by = m.top(t) if side == "top" else m.bottom(t)
        ln = length * (0.75 + 0.25 * math.sin(i / max(1, n - 1) * math.pi))
        d = -1 if side == "top" else 1
        out.append((x, by, ln, d))
    return out


def paint_spikes(c, m, spikes, ramp="bone", tip="red"):
    w = max(1.4, m.L * 0.05)
    for x, by, ln, d in spikes:
        pts = [(x - w, by + d * 1.5), (x + w * 0.6, by + d * 1.5), (x - ln * 0.35, by + d * ln)]

        def f(px, py, pts=pts, by=by, ln=ln, d=d):
            px, py = m.warp(px, py)
            if point_in_poly(px, py, pts):
                k = abs(py - by) / max(1.0, ln)
                if k > 0.62:
                    return M(tip, 3, group="spiketip")
                return M(ramp, 4 if px < pts[0][0] + w * 0.8 else 3, group="spike")
            return False
        c.paint_fn(f, None)


def paint_fins_spiky_back(c, m):
    # webbed membrane + spines
    mem = m.fin_poly(0.3, "top", [(-0.05, -0.2), (0.05, 0.3), (0.45, 0.3), (0.5, -0.2)])
    m.paint_poly_fin(c, mem, ramp="coral", base=2)
    paint_spikes(c, m, spike_list(m, 0.3, 0.78, max(3, int(m.L / 8)), "top", m.H * 0.55))
    paint_spikes(c, m, spike_list(m, 0.42, 0.56, 2, "bottom", m.H * 0.35))


def paint_fins_spiky_front(c, m):
    pts = m.pectoral_pts(length=0.26, width=0.12)
    m.paint_poly_fin(c, pts, ramp="coral", base=3)
    x, y = pts[2]

    def f(px, py):
        px, py = m.warp(px, py)
        return math.hypot(px - x, py - y) < max(1.0, m.L * 0.03) and M("bone", 5, group="sp")
    c.paint_fn(f, None)


def paint_fins_wing_back(c, m):
    pts = m.pectoral_pts(length=0.62, width=0.24, angle_extra=-0.55)
    m.paint_poly_fin(c, pts, ramp="neon", base=2, alpha=230)
    dorsal = m.fin_poly(0.42, "top", [(-0.08, -0.2), (0.02, 0.25), (0.18, 0.2), (0.24, -0.2)])
    m.paint_poly_fin(c, dorsal)


def paint_fins_wing_front(c, m):
    m.flap = 0.6
    pts = m.pectoral_pts(length=0.62, width=0.2, angle_extra=0.05)
    m.flap = 0.0
    m.paint_poly_fin(c, pts, ramp="cyan", base=4, alpha=205)


def zigzag_fin(m, t0, t1, side, height, teeth):
    pts = []
    base_pts = []
    for i in range(teeth * 2 + 1):
        t = t0 + (t1 - t0) * i / (teeth * 2)
        k = math.sin(i / (teeth * 2) * math.pi)
        h = height * (0.35 + 0.65 * k) * (1.0 if i % 2 else 0.55)
        pts.append((t - t0, h))
    pts = [(0.0, -0.2)] + pts + [(t1 - t0, -0.2)]
    return m.fin_poly(t0, side, pts)


def paint_fins_volt_back(c, m):
    m.paint_poly_fin(c, zigzag_fin(m, 0.28, 0.72, "top", 0.42, 4), ramp="volt", base=3)
    m.paint_poly_fin(c, zigzag_fin(m, 0.18, 0.5, "bottom", 0.3, 3), ramp="volt", base=2)


def paint_fins_volt_front(c, m):
    m.paint_poly_fin(c, m.pectoral_pts(length=0.3, width=0.16), ramp="cyan", base=4)
    r = rng(int(m.phase * 100) + int(m.L))
    for _ in range(max(2, int(m.L / 10))):
        t = r.uniform(0.25, 0.75)
        x = m.xt + t * m.L
        y = m.top(t) - r.uniform(1, m.H * 0.5)
        c.pixel(x, y + m.warp_offset(x), (255, 250, 170, 255))
        c.pixel(x + 1, y + m.warp_offset(x) - 1, (170, 250, 255, 255))


def skin_painter(m, fn):
    mask = body_mask_fn(m)

    def f(x, y):
        r = mask(x, y)
        if r is None:
            return False
        sx, sy = r
        t = m.t_of(sx)
        v = (sy - m.top(t)) / max(0.001, m.bottom(t) - m.top(t))
        return fn(sx, sy, t, v)
    return f


def paint_skin_armor(c, m):
    seg = max(3.0, m.L * 0.12)

    def fn(x, y, t, v):
        if v > 0.62 or t < 0.12 or t > 0.83:
            return False
        k = (x - m.xt) / seg
        kk = k - math.floor(k)
        row = 0 if v < 0.3 else 1
        if row == 1:
            kk = (k + 0.5) - math.floor(k + 0.5)
        if kk < 0.14:
            return M("steel", 1, group="plate")
        if abs(v - 0.3) < 0.03:
            return M("steel", 1, group="plate")
        idx = 4 if kk < 0.35 else (3 if kk < 0.8 else 2)
        if v < 0.1:
            idx = 5
        return M("steel", idx, group="plate")
    c.paint_fn(skin_painter(m, fn), None)
    # rivets
    for i in range(int(0.7 * m.L / seg)):
        x = m.xt + m.L * 0.15 + i * seg + seg * 0.5
        t = m.t_of(x)
        if t > 0.8:
            break
        y = m.top(t) + (m.bottom(t) - m.top(t)) * 0.16
        c.pixel(x, y + m.warp_offset(x), col("steel", 5))


def paint_skin_toxic(c, m):
    spots = []
    r = rng(99 + int(m.L))
    for _ in range(int(m.L * 0.28)):
        spots.append((r.uniform(0.12, 0.9), r.uniform(0.08, 0.7), r.uniform(0.6, 1.0) * max(1.0, m.L * 0.045), r.random() < 0.25))

    def fn(x, y, t, v):
        for st, sv, sr, wart in spots:
            sx = m.xt + st * m.L
            sy = m.top(st) + (m.bottom(st) - m.top(st)) * sv
            d = math.hypot(x - sx, y - sy)
            if d <= sr:
                if wart:
                    return M("lime", 4 if d < sr * 0.5 else 3, group="wart")
                return M("poison", 3 if d < sr * 0.6 else 2, group="spot")
        return False
    c.paint_fn(skin_painter(m, fn), None)


def paint_skin_glow(c, m):
    step = max(3, int(m.L / 7))

    def fn(x, y, t, v):
        if t < 0.1 or t > 0.82:
            return False
        xi = int(x - m.xt)
        if abs(v - 0.48) < 0.045:
            return M("glow", 3, group="line")
        if xi % step == 0 and abs(v - 0.7) < 0.07:
            return M("glow", 5, group="dot")
        if (xi + step // 2) % step == 0 and abs(v - 0.22) < 0.06 and 0.2 < t < 0.7:
            return M("glow", 4, group="dot")
        return False
    c.paint_fn(skin_painter(m, fn), None)


def paint_tail_fork(c, m):
    old = m.tail_len
    m.tail_len = m.L * 0.6
    m.paint_tail(c, kind="fork", ramp="navy" if m.body != "neon" else "violet")
    m.tail_len = old


def paint_tail_sting(c, m):
    L = m.L
    x0 = m.xt + 2
    pts = []
    n = 10
    for i in range(n + 1):
        t = i / n
        pts.append((x0 - t * L * 0.75, m.cy + math.sin(t * 2.2 + m.phase) * L * 0.05 * t))
    width = max(1.2, m.H * m.ped * 1.6)

    for i in range(n):
        a, b = pts[i], pts[i + 1]
        w = width * (1.0 - i / n * 0.75)

        def f(x, y, a=a, b=b, w=w):
            x, y = m.warp(x, y)
            from pixel import seg_dist
            if seg_dist(x, y, a[0], a[1], b[0], b[1]) <= w / 2:
                return M("poison", 3 if y < (a[1] + b[1]) / 2 else 2, group="whip")
            return False
        c.paint_fn(f, None)
    tx, ty = pts[-1]
    bw = max(2.0, L * 0.08)

    def barb(x, y):
        x, y = m.warp(x, y)
        return point_in_poly(x, y, [(tx + 2, ty - bw * 0.7), (tx - bw * 1.6, ty), (tx + 2, ty + bw * 0.7)]) and M("lime", 4, group="barb")
    c.paint_fn(barb, None)
    # small side fins at base
    fin = [(x0, m.cy - m.H * 0.1), (x0 - L * 0.18, m.cy - m.H * 0.4), (x0 - L * 0.12, m.cy)]
    m.paint_poly_fin(c, fin, ramp="poison", base=3)
    fin2 = [(x0, m.cy + m.H * 0.1), (x0 - L * 0.18, m.cy + m.H * 0.4), (x0 - L * 0.12, m.cy)]
    m.paint_poly_fin(c, fin2, ramp="poison", base=2)


def paint_tail_eel(c, m):
    L = m.L
    x0 = m.xt + 2
    ln = L * 0.7
    base_h = m.H * m.ped * 1.1

    def f(x, y):
        x, y = m.warp(x, y)
        if x > x0:
            return False
        u = (x0 - x) / ln
        if u > 1.0:
            return False
        wave = math.sin(u * 5.0 - m.phase * 1.0) * L * 0.03 * u
        yc = m.cy + wave
        h_top = base_h * (1.0 - u * 0.8)
        h_bot = base_h * (1.0 - u * 0.8) + L * 0.12 * math.sin(u * math.pi) * (1 - u * 0.3)
        if yc - h_top <= y <= yc + h_bot:
            if y > yc + h_top * 0.6:
                stripe = int((x0 - x) / max(2.0, L * 0.07)) % 2 == 0
                return M("volt", 4 if stripe else 2, group="ribbon")
            return M(m.body, 3 if y < yc else 2, group="eelbody")
        return False
    c.paint_fn(f, None)


PAINTERS = {
    "head_piranha": paint_head_piranha,
    "head_sword": paint_head_sword,
    "head_lure": paint_head_lure,
    "fins_spiky_back": paint_fins_spiky_back,
    "fins_spiky_front": paint_fins_spiky_front,
    "fins_wing_back": paint_fins_wing_back,
    "fins_wing_front": paint_fins_wing_front,
    "fins_volt_back": paint_fins_volt_back,
    "fins_volt_front": paint_fins_volt_front,
    "skin_armor": paint_skin_armor,
    "skin_toxic": paint_skin_toxic,
    "skin_glow": paint_skin_glow,
    "tail_fork": paint_tail_fork,
    "tail_sting": paint_tail_sting,
    "tail_eel": paint_tail_eel,
}


def render_layer(species, stage, layer):
    L = STAGE_LEN[stage]
    w, h = canvas_size(L)
    frames = []
    for i in range(len(FRAMES)):
        m = make_model(species, L, w, h)
        set_frame(m, i)
        c = Canvas(w, h)
        if layer == "body":
            m.paint_body(c)
        elif layer == "tail":
            m.paint_tail(c)
        elif layer == "fins_back":
            m.paint_default_back_fins(c)
        elif layer == "fins_front":
            m.paint_default_front_fins(c)
        else:
            PAINTERS[layer](c, m)
        frames.append(c.render())
    return sheet(frames)


def render_atlas(species, stage):
    rows = [render_layer(species, stage, ly) for ly in LAYERS]
    L = STAGE_LEN[stage]
    w, h = canvas_size(L)
    m = make_model(species, L, w, h)
    base, mid, tip = lure_pts(m)
    meta = dict(
        frame_w=w, frame_h=h, frames=len(FRAMES), layers=LAYERS,
        center=[round(m.cx, 1), round(m.cy, 1)],
        mouth=[round(m.xn, 1), round(m.mouth_y, 1)],
        lure=[round(tip[0], 1), round(tip[1] + max(1.6, L * 0.065) * 0.6, 1)],
        length=L, height=round(m.H, 1),
    )
    return stack_rows(rows), meta
