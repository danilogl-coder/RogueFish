"""Parametric side-view fish renderer (facing right).

A FishModel knows the body profile, jaw, fins and tail. Every layer is painted
with the same warp (swim wag) so separately rendered layers line up.
"""
from __future__ import annotations

import math
from pixel import Canvas, Mat, col, dither, RAMP_RGBA, rng

_MAT_CACHE = {}


def M(ramp, idx, group=None, alpha=255, outline=True):
    key = (ramp, idx, group, alpha, outline)
    m = _MAT_CACHE.get(key)
    if m is None:
        m = Mat(ramp, max(0, min(5, idx)), auto=False, group=group or ramp, alpha=alpha, outline=outline)
        _MAT_CACHE[key] = m
    return m


class FishModel:
    def __init__(self, L, cx, cy, *, H=0.5, peak=0.6, q=0.75, top_ratio=0.55, ped=0.22,
                 body="gold", belly="cream", fin="flame", eye_ramp="white",
                 tail="veil", tail_len=0.55, dorsal=1.0, eye=0.085, mouth_v=0.6,
                 pattern=None, belly_v=0.64, snout=0.0, seed=1, jaw_open=0.55,
                 gill=True, fin_alpha=255, stripe=None, front_e=0.55):
        self.L = L
        self.H = H * L
        self.cx = cx
        self.cy = cy
        self.xt = cx - L / 2.0
        self.xn = cx + L / 2.0
        self.peak = peak
        self.q = q
        self.front_e = front_e
        self.top_ratio = top_ratio
        self.ped = ped
        self.body = body
        self.belly = belly
        self.fin = fin
        self.eye_ramp = eye_ramp
        self.tail = tail
        self.tail_len = tail_len * L
        self.dorsal = dorsal
        self.eye_r = max(1.2, eye * L)
        self.mouth_v = mouth_v
        self.pattern = pattern
        self.belly_v = belly_v
        self.snout = snout
        self.seed = seed
        self.jaw_open = jaw_open
        self.gill = gill
        self.fin_alpha = fin_alpha
        self.stripe = stripe
        # animation state
        self.phase = 0.0
        self.open = 0.0
        self.flap = 0.0

    # ---------------------------------------------------------------- profile
    def prof(self, t):
        if t <= 0.0 or t >= 1.0:
            return 0.0
        pk = self.peak
        if t >= pk:
            u = (t - pk) / (1.0 - pk)
            v = max(0.0, 1.0 - u * u) ** self.front_e
        else:
            u = t / pk
            v = math.sin(u * math.pi * 0.5) ** self.q
        if t < 0.45:
            v = max(v, self.ped * (1.0 - t / 0.45) + v * (t / 0.45))
        return v

    def top(self, t):
        return self.cy - self.H * self.top_ratio * self.prof(t)

    def bottom(self, t):
        return self.cy + self.H * (1.0 - self.top_ratio) * self.prof(t)

    def t_of(self, x):
        return (x - self.xt) / self.L

    def body_inside(self, x, y):
        t = self.t_of(x)
        if t <= 0.0 or t >= 1.0 + self.snout:
            return False
        if t > 1.0:
            return False
        return self.top(t) <= y <= self.bottom(t)

    # ------------------------------------------------------------- mouth/jaw
    @property
    def hinge(self):
        t = 0.8
        return (self.xt + t * self.L, self.mouth_y)

    @property
    def mouth_y(self):
        t = 0.97
        top, bot = self.top(0.9), self.bottom(0.9)
        return top + (bot - top) * self.mouth_v

    def jaw_angle(self):
        return self.open * self.jaw_open

    def to_jaw_space(self, x, y):
        """Maps a point of the open lower jaw back to closed-body space."""
        hx, hy = self.hinge
        a = -self.jaw_angle()
        dx, dy = x - hx, y - hy
        ca, sa = math.cos(a), math.sin(a)
        return (hx + dx * ca - dy * sa, hy + dx * sa + dy * ca)

    def classify(self, x, y):
        """Return ('upper'|'lower'|'cavity'|None, sx, sy) for fish-space point."""
        hx, hy = self.hinge
        if self.open <= 0.0 or x < hx:
            if self.body_inside(x, y):
                return ("upper" if y < self.mouth_y else "lower", x, y)
            return (None, x, y)
        if y < self.mouth_y and self.body_inside(x, y):
            return ("upper", x, y)
        sx, sy = self.to_jaw_space(x, y)
        if sy >= self.mouth_y and self.body_inside(sx, sy):
            return ("lower", sx, sy)
        # cavity: between upper jaw bottom and rotated lower jaw top
        ang = math.atan2(y - hy, x - hx)
        if 0.0 <= ang <= self.jaw_angle() and x < self.xn - self.L * 0.02:
            return ("cavity", x, y)
        return (None, x, y)

    # ------------------------------------------------------------------ warp
    def warp(self, x, y):
        """Screen -> fish space (inverse of the swim wag)."""
        pivot = self.cx + self.L * 0.12
        d = max(0.0, (pivot - x) / (self.L * 1.1))
        amp = max(0.9, self.L * 0.06)
        wag = amp * math.sin(self.phase) * (d ** 1.5)
        y2 = y - wag
        if x < self.xt:
            k = 0.8 + 0.2 * math.cos(self.phase * 2.0)
            x = self.xt - (self.xt - x) / k
        return x, y2

    # --------------------------------------------------------------- shading
    def body_mat(self, x, y, jaw=False):
        t = self.t_of(x)
        top, bot = self.top(t), self.bottom(t)
        h = max(0.001, bot - top)
        v = (y - top) / h
        xi, yi = int(x), int(y)
        ramp = self.body
        if v < 0.13:
            idx = 4
        elif v < 0.42:
            idx = 3 if not (v > 0.36 and dither(xi, yi, 0.5)) else 2
        elif v < self.belly_v:
            idx = 2 if not (v < 0.48 and dither(xi, yi, 0.5)) else 3
        else:
            ramp = self.belly
            if v < 0.86:
                idx = 3 if not (v < self.belly_v + 0.06 and dither(xi, yi, 0.5)) else 2
            else:
                idx = 2
        if t < 0.18:
            idx -= 1
        if self.stripe:
            s_ramp, s_v0, s_v1, s_t0, s_t1 = self.stripe
            if s_v0 <= v <= s_v1 and s_t0 <= t <= s_t1:
                ramp = s_ramp
                idx = 4 if v < (s_v0 + s_v1) / 2 else 3
        if self.pattern:
            pr = self.pattern(self, x, y, t, v)
            if pr:
                ramp, idx = pr if isinstance(pr, tuple) else (pr, idx)
        if self.gill and 0.2 < v < 0.8:
            gx = self.xt + self.L * (0.74 - 0.05 * math.sin(v * math.pi))
            if abs(x - gx) < 0.55 and self.L >= 16:
                idx = min(idx, 1) if ramp == self.body else 1
        return M(ramp, idx, group="body")

    def fin_mat(self, x, y, base=3, ramp=None, rays=True):
        ramp = ramp or self.fin
        idx = base
        if rays and ((int(x) + int(y * 0.5)) % 3 == 0):
            idx -= 1
        return M(ramp, idx, group="fin", alpha=self.fin_alpha)

    # --------------------------------------------------------------- layers
    def paint_body(self, c: Canvas, with_eye=True, with_mouth=True):
        def inside(x, y):
            x, y = self.warp(x, y)
            kind, sx, sy = self.classify(x, y)
            if kind is None:
                return False
            if kind == "cavity":
                return M("ruby", 1, group="cavity")
            m = self.body_mat(sx, sy)
            # lip line
            if with_mouth and self.open <= 0.0:
                my = self.mouth_y
                t = self.t_of(sx)
                if t > 0.9 and abs(sy - my) < 0.5 and self.L >= 14:
                    return M(self.body, 1, group="body")
            return m
        c.paint_fn(inside, None)
        if with_eye:
            self.paint_eye(c)

    def eye_pos(self):
        t = 0.84
        top, bot = self.top(t), self.bottom(t)
        return (self.xt + t * self.L, top + (bot - top) * 0.36)

    def paint_eye(self, c: Canvas, pos=None, r=None):
        ex, ey = pos or self.eye_pos()
        r = r or self.eye_r
        wag = self.warp_offset(ex)
        ey += wag
        if r < 1.6:
            c.pixel(ex, ey, col(self.eye_ramp, 5))
            c.pixel(ex + 1, ey, (10, 8, 18, 255))
            return
        c.circle(ex, ey, r, M(self.eye_ramp, 4, group="eye"))
        c.circle(ex + r * 0.25, ey + r * 0.05, r * 0.58, M("black", 0, group="pupil"))
        c.pixel(ex - r * 0.2, ey - r * 0.35, (255, 255, 255, 255))

    def warp_offset(self, x):
        pivot = self.cx + self.L * 0.12
        d = max(0.0, (pivot - x) / (self.L * 1.1))
        amp = max(0.9, self.L * 0.06)
        return amp * math.sin(self.phase) * (d ** 1.5)

    def paint_tail(self, c: Canvas, kind=None, ramp=None):
        kind = kind or self.tail
        ramp = ramp or self.fin
        Lt = self.tail_len
        xt, cy = self.xt + 1.5, self.cy
        ph = self.H * self.ped * 0.9

        if kind == "veil":
            def inside(x, y):
                x, y = self.warp(x, y)
                if x > xt:
                    return False
                d = xt - x
                u = d / Lt
                if u > 1.05:
                    return False
                # two flowing lobes
                spread = ph + Lt * 0.75 * math.sin(min(1.0, u) * math.pi * 0.62)
                if abs(y - cy) > spread:
                    return False
                edge = 1.0 - 0.25 * math.cos(abs(y - cy) / max(1, spread) * math.pi)
                if u > edge:
                    return False
                notch = abs(y - cy) < (u - 0.55) * Lt * 0.5
                if notch:
                    return False
                idx = 3 if u < 0.55 else 4
                if (int(x) + int(abs(y - cy) * 0.8)) % 3 == 0:
                    idx -= 1
                return M(ramp, idx, group="tail", alpha=self.fin_alpha)
        elif kind == "fork":
            def inside(x, y):
                x, y = self.warp(x, y)
                if x > xt:
                    return False
                u = (xt - x) / Lt
                if u > 1.0:
                    return False
                a = abs(y - cy)
                outer = ph + Lt * 0.8 * u
                inner = Lt * 1.1 * max(0.0, u - 0.45)
                if a > outer or a < inner:
                    return False
                if u > 0.55 and a < Lt * 0.9 * (u - 0.35):
                    return False
                idx = 3 if a > outer - 1.5 else 2
                return M(ramp, idx, group="tail", alpha=self.fin_alpha)
        elif kind == "lunate":
            def inside(x, y):
                x, y = self.warp(x, y)
                if x > xt:
                    return False
                u = (xt - x) / Lt
                if u > 1.0:
                    return False
                a = abs(y - cy) / (Lt * 1.1)
                if u < 0.35:
                    return a < ph / (Lt * 1.1) + u * 0.4
                crescent = a < 0.1 + u * 0.95 and a > (u - 0.35) * 1.45 - 0.05 + 0.5 * (1.0 - u) * 0.0
                inner = (u - 0.5) * 1.2
                if a < inner:
                    return False
                return M(ramp, 2 if a < 0.5 else 3, group="tail") if crescent else False
        else:  # round fan
            def inside(x, y):
                x, y = self.warp(x, y)
                if x > xt:
                    return False
                u = (xt - x) / Lt
                a = abs(y - cy)
                spread = ph + Lt * 0.7 * math.sqrt(max(0.0, min(1.0, u * 1.3)))
                if a > spread:
                    return False
                if u > 1.0 - 0.35 * (a / max(1, spread)) ** 2 * 0 and u > 1.0 - 0.15 * (1 - (a / max(1.0, spread)) ** 2):
                    return False
                idx = 3 if (int(x * 0.7) + int(a)) % 3 else 2
                return M(ramp, idx, group="tail", alpha=self.fin_alpha)
        c.paint_fn(inside, None)

    def fin_poly(self, anchor_t, side, pts_rel):
        """Build polygon from points relative to body edge at anchor_t.

        pts_rel: list of (dt, h) where dt is along body length in units of L
        and h is height in units of H (positive = away from body).
        """
        pts = []
        for dt, h in pts_rel:
            t = anchor_t + dt
            if side == "top":
                base = self.top(max(0.01, min(0.99, t)))
                pts.append((self.xt + t * self.L, base - h * self.H))
            else:
                base = self.bottom(max(0.01, min(0.99, t)))
                pts.append((self.xt + t * self.L, base + h * self.H))
        return pts

    def paint_poly_fin(self, c, pts, ramp=None, base=3, sway=0.0, group="fin", alpha=None, rays=True):
        ramp = ramp or self.fin
        alpha = self.fin_alpha if alpha is None else alpha
        from pixel import point_in_poly

        def inside(x, y):
            x, y = self.warp(x, y)
            if point_in_poly(x, y, pts):
                idx = base
                if rays and (int(x) + int(y * 0.5)) % 3 == 0:
                    idx -= 1
                return M(ramp, idx, group=group, alpha=alpha)
            return False
        c.paint_fn(inside, None)

    def paint_default_back_fins(self, c: Canvas, scale=1.0):
        d = self.dorsal * scale
        sw = math.sin(self.phase) * 0.03
        dorsal = self.fin_poly(0.4, "top", [(-0.1, -0.2), (0.06 + sw, 0.45 * d), (0.2 + sw, 0.42 * d), (0.3, -0.2)])
        self.paint_poly_fin(c, dorsal)
        pelvic = self.fin_poly(0.5, "bottom", [(-0.03, -0.2), (-0.1 + sw, 0.32 * scale), (0.08, -0.2)])
        self.paint_poly_fin(c, pelvic, base=2)
        anal = self.fin_poly(0.2, "bottom", [(-0.04, -0.2), (-0.08 + sw, 0.22 * scale), (0.1, -0.2)])
        self.paint_poly_fin(c, anal, base=2)

    def pectoral_pts(self, length=0.26, width=0.16, angle_extra=0.0):
        t = 0.66
        top, bot = self.top(t), self.bottom(t)
        bx = self.xt + t * self.L
        by = top + (bot - top) * 0.58
        ang = math.pi + 0.35 + 0.35 * math.sin(self.phase + 1.0) * (1.0 + self.flap) + angle_extra
        ln = length * self.L
        wd = width * self.L
        tipx = bx + math.cos(ang) * ln
        tipy = by + math.sin(ang) * ln
        nx, ny = -math.sin(ang), math.cos(ang)
        return [(bx + nx * wd * 0.3, by + ny * wd * 0.3),
                (bx + math.cos(ang) * ln * 0.5 + nx * wd * 0.55, by + math.sin(ang) * ln * 0.5 + ny * wd * 0.55),
                (tipx, tipy),
                (bx - nx * wd * 0.35, by - ny * wd * 0.35)]

    def paint_default_front_fins(self, c: Canvas):
        self.paint_poly_fin(c, self.pectoral_pts(), base=4)


# ---------------------------------------------------------------- frames
SWIM_FRAMES = 4
FRAMES = [
    dict(phase=0.0, open=0.0),
    dict(phase=math.pi * 0.5, open=0.0),
    dict(phase=math.pi, open=0.0),
    dict(phase=math.pi * 1.5, open=0.0),
    dict(phase=math.pi * 0.25, open=1.0),
    dict(phase=math.pi * 0.25, open=0.45),
]


def set_frame(model: FishModel, i: int):
    f = FRAMES[i]
    model.phase = f["phase"]
    model.open = f["open"]
    model.flap = 0.0
