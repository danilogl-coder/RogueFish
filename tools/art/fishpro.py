"""Professional side-view fish renderer (facing right), numpy based.

The fish is a small rig rather than a stack of overlays:
  * body: analytic profile shaded as a laterally compressed ellipsoid lit from
    the top-left-front, quantised into a few hue-shifted tones;
  * jaw: the lower jaw is a rigid piece that rotates around the corner of the
    mouth (the hinge). Opening it reveals a shaded mouth cavity with gums,
    tongue and teeth that belong to each jaw, the throat stretches and the gill
    cover flares. Nothing is painted on top of a closed head;
  * fins/tail: membranes with rays, lighter edges and follow-through, rendered
    as their own parts so the game can swap them (mutations).

Frames: 6 swim frames (travelling body wave, tail foreshortening, paddling
pectoral) + 4 bite frames (anticipation, gape, snap, recover).
"""
from __future__ import annotations

import math

import numpy as np
from PIL import Image
from scipy import ndimage

import pro
from pro import PAL, grid, poly_mask, seg_dist

TAU = math.tau
SWIM_N = 6
BITE_N = 4
N_FRAMES = SWIM_N + BITE_N

# Per-frame animation state. lunge/sx/sy give the bite its squash & stretch.
FRAMES = [dict(phase=k * TAU / SWIM_N, open=0.0, flare=0.0, lunge=0.0, sx=1.0, sy=1.0, pect=0.0) for k in range(SWIM_N)] + [
    dict(phase=TAU * 0.20, open=0.55, flare=0.5, lunge=-1.0, sx=0.98, sy=1.01, pect=0.5),   # anticipation
    dict(phase=TAU * 0.40, open=1.00, flare=1.0, lunge=1.0, sx=1.04, sy=0.98, pect=0.7),    # full gape, lunging
    dict(phase=TAU * 0.65, open=0.00, flare=0.6, lunge=2.0, sx=0.96, sy=1.03, pect=-0.6),   # snap (squash)
    dict(phase=TAU * 0.85, open=0.18, flare=0.2, lunge=1.0, sx=1.0, sy=1.0, pect=-0.2),     # recover
]

BODY_BANDS = (0.28, 0.45, 0.62, 0.82)


def _ramp(name):
    return PAL[name] if isinstance(name, str) else name


class Layer:
    """Colour-indexed layer: material id + tone per pixel, converted to RGBA with sel-out."""

    def __init__(self, w, h):
        self.w, self.h = w, h
        self.mat = np.full((h, w), -1, dtype=np.int32)
        self.tone = np.zeros((h, w), dtype=np.int32)
        self.alpha = np.full((h, w), 255, dtype=np.int32)
        self.ramps: list = []
        self.no_outline = np.zeros((h, w), dtype=bool)

    def mid(self, ramp):
        r = _ramp(ramp)
        for i, rr in enumerate(self.ramps):
            if rr is r:
                return i
        self.ramps.append(r)
        return len(self.ramps) - 1

    def paint(self, where, ramp, tone, alpha=255, outline=True):
        where = np.asarray(where, dtype=bool)
        if not where.any():
            return
        m = self.mid(ramp)
        self.mat[where] = m
        if np.isscalar(tone):
            self.tone[where] = int(tone)
        else:
            self.tone[where] = np.asarray(tone)[where]
        self.alpha[where] = alpha
        self.no_outline[where] = not outline

    def shift(self, where, delta, lo=1, hi=6):
        where = np.asarray(where, dtype=bool) & (self.mat >= 0)
        self.tone[where] = np.clip(self.tone[where] + delta, lo, hi)

    @property
    def mask(self):
        return self.mat >= 0

    def clean(self, iterations=2, protect=None):
        """Replaces isolated pixels whose (material, tone) differs from all 4 neighbours."""
        code = np.where(self.mat >= 0, self.mat * 16 + self.tone, -1)
        for _ in range(iterations):
            pad = np.pad(code, 1, constant_values=-1)
            nb = np.stack([pad[:-2, 1:-1], pad[2:, 1:-1], pad[1:-1, :-2], pad[1:-1, 2:]])
            same = (nb == code).sum(axis=0)
            valid = (nb >= 0).sum(axis=0)
            orphan = (code >= 0) & (same == 0) & (valid >= 3)
            if protect is not None:
                orphan &= ~protect
            if not orphan.any():
                break
            ys, xs = np.nonzero(orphan)
            for y, x in zip(ys, xs):
                vals = [v for v in nb[:, y, x] if v >= 0]
                best = max(set(vals), key=vals.count)
                code[y, x] = best
        m = code >= 0
        self.mat[m] = code[m] // 16
        self.tone[m] = code[m] % 16

    def to_image(self, outline=True, lit_tone=1, dark_tone=0):
        h, w = self.h, self.w
        img = np.zeros((h, w, 4), dtype=np.uint8)
        m = self.mask
        for i, r in enumerate(self.ramps):
            sel = self.mat == i
            if sel.any():
                img[sel, :3] = r[np.clip(self.tone[sel], 0, len(r) - 1)]
        img[..., 3] = np.where(m, self.alpha, 0).astype(np.uint8)
        if outline:
            om = m & ~self.no_outline
            pad = np.pad(om, 1)
            mpad = np.pad(np.where(om, self.mat, -1), 1, constant_values=-1)
            ring = (~m) & (pad[:-2, 1:-1] | pad[2:, 1:-1] | pad[1:-1, :-2] | pad[1:-1, 2:])
            # lit side = pixel above/left of the shape (its neighbour is below/right)
            order = [
                (mpad[:-2, 1:-1], dark_tone),   # shape above -> outline under it (shadow)
                (mpad[1:-1, :-2], dark_tone),   # shape left -> outline right of it
                (mpad[2:, 1:-1], lit_tone),     # shape below -> outline above it (lit)
                (mpad[1:-1, 2:], dark_tone),    # shape right -> outline left of it
            ]
            done = np.zeros_like(m)
            for nm, tone in order:
                sel = ring & (nm >= 0) & ~done
                if not sel.any():
                    continue
                for i, r in enumerate(self.ramps):
                    s2 = sel & (nm == i)
                    if s2.any():
                        img[s2, :3] = r[tone]
                        img[s2, 3] = 255
                done |= sel
            # diagonal-only corners stay empty (cleaner, rounder silhouettes)
        return Image.fromarray(img, "RGBA")


def smoothstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3 - 2 * t)


def bezier(p0, p1, p2, n=48):
    t = np.linspace(0.0, 1.0, n)[:, None]
    p0, p1, p2 = (np.array(p, dtype=float) for p in (p0, p1, p2))
    return (1 - t) ** 2 * p0 + 2 * (1 - t) * t * p1 + t * t * p2


def rot(x, y, cx, cy, a):
    c, s = math.cos(a), math.sin(a)
    dx, dy = x - cx, y - cy
    return cx + dx * c - dy * s, cy + dx * s + dy * c


def band(val, bands=BODY_BANDS, lo=1):
    out = np.full(val.shape, lo, dtype=np.int32)
    for b in bands:
        out += (val > b).astype(np.int32)
    return out


# --------------------------------------------------------------------- mouth
MOUTH_DEFAULT = dict(
    v=0.56,          # lip height at the snout (0 top .. 1 bottom of the head section)
    corner_t=0.86,   # hinge position along the body
    corner_v=0.62,
    sag=0.0,         # gape curvature (x H)
    open=0.5,        # max jaw angle (radians)
    under=0.0,       # lower jaw protrusion past the upper lip (x L)
    chin=0.18,       # depth of the protruding chin (x H)
    teeth=None,      # None | 'peg' | 'triangle' | 'fang' | 'needle' | 'cone'
    teeth_n=0,
    teeth_len=0.05,  # x L
    closed_teeth=False,
    lips=None,       # ramp name for fleshy lips
    tongue=True,
    jaw_ramp=None,   # material override for the lower jaw (e.g. red jaw)
)


FIN_PROFILES = {
    # style: (height profile over the base 0..1, sweep = how far the top leans back)
    "soft": (lambda s: np.sin(np.pi * s) ** 0.55 * (1.0 - 0.3 * s), 0.45),
    "round": (lambda s: np.sin(np.pi * np.clip(s, 0, 1)) ** 0.42, 0.25),
    "tri": (lambda s: np.clip(1.0 - np.abs(s - 0.32) / np.where(s < 0.32, 0.32, 0.68), 0, 1) ** 0.85, 0.55),
    "shark": (lambda s: np.where(s < 0.34, np.clip(s / 0.34, 0, 1), np.clip((1.0 - s) / 0.66, 0, 1) ** 1.9), 0.42),
    "orca": (lambda s: np.where(s < 0.42, np.clip(s / 0.42, 0, 1) ** 0.9, np.clip((1.0 - s) / 0.58, 0, 1) ** 1.35), 0.22),
    "sail": (lambda s: np.sin(np.pi * np.clip(s, 0, 1) ** 0.75) ** 0.5, 0.35),
    "long": (lambda s: np.clip(np.sin(np.pi * s) * 5.0, 0, 1) ** 0.6 * (0.85 + 0.15 * np.sin(np.pi * s)), 0.15),
    "low": (lambda s: np.clip(np.sin(np.pi * s) * 3.0, 0, 1) * 0.7, 0.1),
    "spiny": (lambda s: np.sin(np.pi * s) ** 0.5 * (1.0 - 0.32 * ((s * 6.0) % 1.0) ** 0.8), 0.3),
    "zig": (lambda s: np.sin(np.pi * s) ** 0.5 * (0.5 + 0.5 * np.abs(((s * 4.0) % 1.0) * 2.0 - 1.0)), 0.25),
}


class Fish:
    def __init__(self, L, cx, cy, **kw):
        p = dict(
            H=0.5, peak=0.58, q=0.9, front_e=0.55, top_ratio=0.55, ped=0.22, hump=0.0, hump_t=0.72, hump_w=0.18,
            thick=0.6, body="gold", belly="cream", fin="flame", fin2=None, eye_ramp="iris_gold", belly_v=0.6,
            tail="fork", tail_len=0.45, tail_spread=1.0, tail_ramp=None,
            dorsal=("soft", 0.34, 0.74, 0.42), anal=("soft", 0.14, 0.32, 0.26), pelvic=0.26,
            pectoral=(0.26, 0.13), pect_ramp=None, eye=0.09, eye_t=0.84, eye_v=0.34, pupil=0.55,
            mouth=None, pattern=None, scales=False, lateral=False, gill=True, gill_t=0.72,
            fin_alpha=255, wag=1.0, gloss=True, rim=True, spines=False, belly_line=True, countershade=0.3, backshade=0.0,
        )
        p.update(kw)
        self.p = p
        self.L = float(L)
        self.H = p["H"] * L
        self.cx, self.cy = float(cx), float(cy)
        self.xt = self.cx - L / 2.0
        self.xn = self.cx + L / 2.0
        m = dict(MOUTH_DEFAULT)
        m.update(p["mouth"] or {})
        self.m = m
        self.extras = []        # callables(fish, st, fields, layer) painting into the body layer
        self.extra_shapes = []  # callables(fish, st, x, y) -> (mask, ramp, tone) added to the upper head
        self._setup_mouth()

    # -------------------------------------------------------------- profile
    def prof(self, t):
        p = self.p
        t = np.asarray(t, dtype=float)
        pk = p["peak"]
        inside = (t > 0.0) & (t < 1.0)
        u = (t - pk) / (1.0 - pk)
        front = np.clip(1.0 - u * u, 0.0, None) ** p["front_e"]
        ub = np.clip(t / pk, 0.0, 1.0)
        back = np.sin(ub * math.pi * 0.5) ** p["q"]
        v = np.where(t >= pk, front, back)
        ped = p["ped"] * (1.0 - t / 0.45) + v * (t / 0.45)
        v = np.where(t < 0.45, np.maximum(v, ped), v)
        return np.where(inside, v, 0.0)

    def top(self, t):
        p = self.p
        t = np.asarray(t, dtype=float)
        hump = p["hump"] * self.H * np.exp(-((t - p["hump_t"]) / p["hump_w"]) ** 2) * (self.prof(t) > 0)
        return self.cy - self.H * p["top_ratio"] * self.prof(t) - hump

    def bottom(self, t):
        return self.cy + self.H * (1.0 - self.p["top_ratio"]) * self.prof(t)

    def t_of(self, x):
        return (x - self.xt) / self.L

    def inside(self, x, y):
        t = self.t_of(x)
        return (t > 0.0) & (t < 1.0) & (y >= self.top(t)) & (y <= self.bottom(t))

    def section_y(self, t, v):
        return self.top(t) + (self.bottom(t) - self.top(t)) * v

    # ---------------------------------------------------------------- mouth
    def _setup_mouth(self):
        m = self.m
        y_lip = float(self.section_y(0.93, m["v"]))
        x_lip = self.xn
        for tt in np.arange(0.999, 0.8, -0.002):
            if self.top(tt) <= y_lip <= self.bottom(tt):
                x_lip = self.xt + tt * self.L
                break
        self.lip = (x_lip, y_lip)
        ct = m["corner_t"]
        self.hinge = (self.xt + ct * self.L, float(self.section_y(ct, m["corner_v"])))
        hx, hy = self.hinge
        ctrl = ((hx + x_lip) / 2.0, (hy + y_lip) / 2.0 + m["sag"] * self.H)
        self.gape = bezier(self.hinge, ctrl, self.lip)
        # lower jaw top edge (closed): gape plus the chin if the jaw protrudes
        self.chin_poly = None
        low_edge = self.gape.copy()
        if m["under"] > 0.0:
            ux = x_lip + m["under"] * self.L
            uy = y_lip - 0.03 * self.H
            d = m["chin"] * self.H
            tb = 0.9
            self.chin_poly = [
                (x_lip - 0.06 * self.L, y_lip + 0.2),
                (ux, uy),
                (ux + 0.01 * self.L, uy + d * 0.45),
                (ux - 0.04 * self.L, uy + d * 0.85),
                (x_lip - 0.03 * self.L, y_lip + d),
                (self.xt + tb * self.L, float(self.bottom(tb)) + 0.3),
                (self.xt + 0.84 * self.L, y_lip + 0.5),
            ]
            low_edge = np.vstack([self.gape, [[ux, uy]]])
        self.low_edge = low_edge
        self.low_tip = tuple(low_edge[-1])

    def gape_y(self, x):
        gx, gy = self.gape[:, 0], self.gape[:, 1]
        order = np.argsort(gx)
        return np.interp(x, gx[order], gy[order])

    def lower_closed(self, x, y):
        """Lower jaw region in closed pose."""
        hx, _ = self.hinge
        region = self.inside(x, y) & (x >= hx) & (y > self.gape_y(x))
        if self.chin_poly is not None:
            region |= poly_mask(x, y, self.chin_poly) & (y > self.gape_y(np.minimum(x, self.lip[0])) - 0.2)
        return region

    # ---------------------------------------------------------------- swim
    def wave(self, x, phase, kmax=1.9):
        piv = 0.62
        t = self.t_of(x)
        k = np.clip((piv - t) / piv, 0.0, kmax)
        amp = self.p["wag"] * max(0.7, 0.05 * self.L)
        return amp * k ** 1.6 * np.sin(phase - 2.2 * k)

    def to_fish(self, X, Y, st):
        lunge = st["lunge"] * max(1.0, round(self.L / 26.0))
        x = X - lunge
        x = self.cx + (x - self.cx) / st["sx"]
        y = self.cy + (Y - self.cy) / st["sy"]
        return x, y - self.wave(x, st["phase"])

    def to_screen(self, x, y, st):
        lunge = st["lunge"] * max(1.0, round(self.L / 26.0))
        y2 = y + self.wave(x, st["phase"])
        return self.cx + (x - self.cx) * st["sx"] + lunge, self.cy + (y2 - self.cy) * st["sy"]

    # --------------------------------------------------------------- shading
    def normal_light(self, sx, sy):
        """Analytic ellipsoid normal at closed-body coords -> light value 0..1."""
        th = self.p["thick"]

        def z(xx, yy):
            t = np.clip(self.t_of(xx), 0.001, 0.999)
            top, bot = self.top(t), self.bottom(t)
            hh = np.maximum(0.5, (bot - top) * 0.5)
            yc = (bot + top) * 0.5
            u = np.clip((yy - yc) / hh, -0.985, 0.985)
            return th * hh * np.sqrt(1.0 - u * u), u, hh

        z0, u, hh = z(sx, sy)
        zx = (z(sx + 0.5, sy)[0] - z(sx - 0.5, sy)[0])
        zy = -th * u / np.sqrt(1.0 - u * u)
        n = np.stack([-zx, -zy, np.ones_like(zx)], axis=-1)
        n /= np.linalg.norm(n, axis=-1, keepdims=True)
        d = n @ pro.LIGHT
        wrap = 0.2
        d = np.clip((d + wrap) / (1.0 + wrap), 0.0, 1.0)
        return 0.12 + 0.88 * d, n

    # ----------------------------------------------------------- main render
    def render(self, w, h, st, parts=("tail", "fins_back", "body", "fins_front")):
        X, Y = grid(w, h)
        x, y = self.to_fish(X, Y, st)
        out = {}
        f = self._body_fields(x, y, st)
        f["X"], f["Y"] = X, Y
        for name in parts:
            if name == "body":
                out[name] = self._render_body(w, h, x, y, st, f)
            elif name == "tail":
                out[name] = self.render_tail(w, h, x, y, st, f)
            elif name == "fins_back":
                out[name] = self.render_fins_back(w, h, x, y, st, f)
            elif name == "fins_front":
                out[name] = self.render_fins_front(w, h, x, y, st, f)
        return out

    def _body_fields(self, x, y, st):
        a = st["open"] * self.m["open"]
        hx, hy = self.hinge
        lower_id = self.lower_closed(x, y)
        body_id = self.inside(x, y)
        up = body_id & ~lower_id
        for fn in self.extra_shapes:
            msk, _, _ = fn(self, st, x, y)
            up |= msk
        sx, sy = rot(x, y, hx, hy, -a)
        jaw = self.lower_closed(sx, sy) & ~up
        cav = np.zeros_like(up)
        if a > 0.01:
            upper_edge = [tuple(p) for p in self.gape]
            low = [rot(px, py, hx, hy, a) for px, py in self.low_edge[::-1]]
            poly = upper_edge + [self.lip, low[0]] + low
            cav = poly_mask(x, y, poly) & ~up & ~jaw
        return dict(up=up, jaw=jaw, cav=cav, sx=np.where(jaw, sx, x), sy=np.where(jaw, sy, y), angle=a)

    def _render_body(self, w, h, x, y, st, f):
        p, m = self.p, self.m
        lay = Layer(w, h)
        up, jaw, cav = f["up"], f["jaw"], f["cav"]
        sx, sy = f["sx"], f["sy"]
        body = up | jaw
        # throat membrane stretches between the fixed throat and the dropped jaw
        throat = np.zeros_like(body)
        if f["angle"] > 0.05:
            sil = body | cav
            r = max(1, int(round(self.L * 0.035)))
            st_el = ndimage.generate_binary_structure(2, 1)
            closed = ndimage.binary_closing(sil, structure=st_el, iterations=r + 1)
            hx, hy = self.hinge
            throat = closed & ~sil & (x > hx - 0.22 * self.L) & (x < hx + 0.3 * self.L) & (y > hy)
        t = np.clip(self.t_of(sx), 0.0, 0.999)
        top, bot = self.top(t), self.bottom(t)
        v = np.clip((sy - top) / np.maximum(0.5, bot - top), 0.0, 1.0)
        lightv, n = self.normal_light(sx, sy)
        # countershading: real fish have a lighter belly that cancels the shadow
        lightv = lightv + p["countershade"] * smoothstep(0.3, 0.85, v)
        # darker dorsal albedo (sharks, orcas, open-water fish)
        lightv = lightv - p["backshade"] * (1.0 - smoothstep(0.12, 0.55, v))
        tone = band(lightv)
        # material: countershaded back/belly
        belly = v > p["belly_v"]
        lay.paint(body & ~belly, p["body"], tone)
        lay.paint(body & belly, p["belly"], tone)
        if m["jaw_ramp"]:
            lay.paint(jaw & (v > 0.35), m["jaw_ramp"], tone)
        lay.paint(throat, p["belly"], 2)
        fields = dict(x=x, y=y, t=t, v=v, sx=sx, sy=sy, light=lightv, n=n, body=body, up=up, jaw=jaw,
                      cav=cav, tone=tone, lay=lay, st=st, throat=throat, angle=f["angle"], X=f["X"], Y=f["Y"])
        # specular glint on the upper front (glossy scales)
        if p["gloss"] and self.L >= 16:
            glint = body & (lightv > 0.955) & (v < 0.4)
            lay.paint(glint & ~belly, p["body"], 6)
        # reflected light from below: a rim of lighter belly just above the lower outline
        if p["rim"] and self.L >= 14:
            below = np.pad(body | throat, ((0, 1), (0, 0)))[1:, :]
            rim = body & ~below & (v > 0.7)
            lay.shift(rim, +1, lo=2, hi=4)
        if p["pattern"]:
            p["pattern"](self, fields)
        for fn in self.extra_shapes:
            msk, ramp, tn = fn(self, st, x, y)
            if msk.any():
                lay.paint(msk, ramp, tn if not np.isscalar(tn) else tn)
        if p["scales"] and self.L >= 26:
            self._scales(fields)
        lay.clean()
        if p["lateral"] and self.L >= 26:
            self._lateral_line(fields)
        if p["gill"] and self.L >= 26:
            self._operculum(fields)
        self._mouth(fields)
        for fn in self.extras:
            fn(self, st, fields, lay)
        self._eye(fields)
        return lay

    # ------------------------------------------------------------- details
    def _scales(self, f):
        lay = f["lay"]
        s = max(3.0, self.L * 0.075)
        sx, sy = f["sx"], f["sy"]
        row = np.floor((sy - self.cy) / (s * 0.8))
        off = np.where(row.astype(int) % 2 == 0, 0.0, s * 0.5)
        cxs = (np.floor((sx - self.xt + off) / s) + 0.5) * s - off + self.xt
        cys = (row + 0.5) * s * 0.8 + self.cy
        dx, dy = sx - cxs, sy - cys
        d = np.hypot(dx * 1.1, dy)
        edge = (d > s * 0.42) & (d < s * 0.42 + 1.0) & (dx < -0.3)
        zone = f["body"] & (f["t"] > 0.14) & (f["t"] < p_t(self)) & (f["v"] > 0.1) & (f["v"] < self.p["belly_v"] + 0.08)
        lay.shift(edge & zone & (lay.tone >= 3), -1, lo=2)
        hl = (d < s * 0.2) & (dy < 0) & zone & (lay.tone == 4)
        lay.shift(hl, +1, hi=5)

    def _lateral_line(self, f):
        lay = f["lay"]
        v_line = 0.36 + 0.1 * f["t"]
        on = f["up"] & (np.abs(f["v"] - v_line) * (self.bottom(f["t"]) - self.top(f["t"])) < 0.5)
        on &= (f["t"] > 0.1) & (f["t"] < self.p["gill_t"] - 0.02)
        dots = on & ((np.floor(f["x"]).astype(int) % 3) != 0)
        lay.shift(dots, -1, lo=2)

    def _operculum(self, f):
        p = self.p
        lay = f["lay"]
        v = f["v"]
        xo = self.xt + self.L * (p["gill_t"] - 0.045 * np.sin(np.clip(v, 0, 1) * math.pi))
        zone = f["up"] & (v > 0.22) & (v < 0.88)
        line = zone & (np.abs(f["x"] - xo) < 0.5)
        lay.shift(line, -1, lo=1)
        if self.L >= 30:
            hl = zone & (f["x"] - xo >= 0.5) & (f["x"] - xo < 1.5) & (v < 0.55)
            lay.shift(hl, +1, hi=5)
        fl = f["st"]["flare"]
        if fl > 0.05 and self.L >= 14:
            wdt = 0.5 + max(1.0, self.L / 30.0) * fl
            gz = zone & (xo - f["x"] >= 0.5) & (xo - f["x"] < 0.5 + wdt) & (v > 0.3) & (v < 0.88)
            lay.paint(gz, "mouth", np.where(v[...] < 0.55, 4, 3))

    def _eye(self, f):
        p = self.p
        lay = f["lay"]
        ex = self.xt + p["eye_t"] * self.L
        ey = float(self.section_y(p["eye_t"], p["eye_v"]))
        ex, ey = self.to_screen(ex, ey, f["st"])
        r = p["eye"] * self.L
        X, Y = f["X"], f["Y"]
        if r < 1.25:
            px, py = int(round(ex - 0.5)), int(round(ey - 0.5))
            lay.paint((np.floor(X) == px) & (np.floor(Y) == py), "black", 0)
            return
        d = np.hypot(X - ex, Y - ey)
        # dark socket ring + iris + pupil + catch light
        if r >= 2.2:
            lay.shift((d <= r + 0.7) & (d > r) & lay.mask, -1, lo=1)
        iris = d <= r
        irt = np.where(Y < ey - r * 0.25, 3, np.where(Y > ey + r * 0.3, 5, 4))
        lay.paint(iris, p["eye_ramp"], irt)
        pr = r * p["pupil"]
        pd = np.hypot(X - (ex + r * 0.18), Y - (ey + r * 0.05))
        lay.paint(pd <= pr, "black", 0)
        if r < 2.0:
            # tiny eyes: 2x2 block with one bright pixel
            px, py = int(math.floor(ex - 0.5)), int(math.floor(ey - 0.5))
            blk = (np.floor(X) >= px) & (np.floor(X) <= px + 1) & (np.floor(Y) >= py) & (np.floor(Y) <= py + 1)
            lay.paint(blk, "black", 0)
            lay.paint((np.floor(X) == px) & (np.floor(Y) == py), "white", 6)
            return
        cx_, cy_ = ex - r * 0.25, ey - r * 0.3
        k = 1 if r < 4 else 2
        hx, hy = int(math.floor(cx_)), int(math.floor(cy_))
        glint = (np.floor(X) >= hx) & (np.floor(X) < hx + k) & (np.floor(Y) >= hy) & (np.floor(Y) < hy + k)
        lay.paint(glint & iris, "white", 6)
        if r >= 3.5:
            # small secondary reflection at the bottom right of the pupil
            sx_, sy_ = int(math.floor(ex + r * 0.45)), int(math.floor(ey + r * 0.35))
            lay.paint((np.floor(X) == sx_) & (np.floor(Y) == sy_) & iris, p["eye_ramp"], 6)

    def _mouth(self, f):
        m = self.m
        lay = f["lay"]
        up, jaw, cav = f["up"], f["jaw"], f["cav"]
        x, y = f["x"], f["y"]
        hx, hy = self.hinge
        a = f["angle"]
        down = lambda arr: np.pad(arr, ((0, 1), (0, 0)))[1:, :]
        upn = lambda arr: np.pad(arr, ((1, 0), (0, 0)))[:-1, :]
        front = x > hx + (self.lip[0] - hx) * 0.2
        if a <= 0.01:
            # closed: dark lip line along the gape
            line = up & down(jaw) & front
            lay.shift(line, -2, lo=1)
            corner = up & down(jaw) & (np.abs(x - hx - 0.5) < 1.0)
            lay.shift(corner & (self.L >= 24), -2, lo=1)
        else:
            # lips: upper lip edge in shade, lower lip edge catches the light
            lay.shift(up & down(cav), -1, lo=1)
            lay.shift(jaw & upn(cav), +1, hi=5)
            lx, ly = self.lip
            dmax = max(1.0, math.hypot(lx - hx, ly - hy))
            d = np.clip(np.hypot(x - hx, y - hy) / dmax, 0.0, 1.2)
            # deep throat is darkest; the opening gets a little light
            ctone = 1 + (d > 0.5).astype(np.int32) + (d > 0.85).astype(np.int32)
            lay.paint(cav, "mouth", ctone)
            upper_rim = cav & upn(up) & (d > 0.3)
            lower_rim = cav & down(jaw) & (d > 0.25)
            lay.paint(upper_rim, "gum", 1)
            lay.paint(lower_rim, "gum", 3)
            if m["tongue"] and self.L >= 26:
                sx, sy = rot(x, y, hx, hy, -a)
                tx0 = hx + (lx - hx) * 0.5
                ty0 = float(self.gape_y(tx0))
                tl = (lx - hx) * 0.34
                th = max(1.2, self.L * 0.035)
                tongue = cav & ~upper_rim & (((sx - tx0) / tl) ** 2 + ((sy - ty0) / th) ** 2 <= 1.0) & (sy < ty0 + 0.2)
                lay.paint(tongue, "gum", np.where(sy < ty0 - th * 0.45, 3, 2))
        if m["lips"]:
            lipz = (up & (down(jaw) | down(cav) | down(down(jaw)))) | (jaw & (upn(up) | upn(cav) | upn(upn(up))))
            lay.paint(lipz & front, m["lips"], np.clip(lay.tone, 2, 5))
        self._teeth(f)

    def _teeth(self, f):
        m = self.m
        style = m["teeth"]
        if not style:
            return
        lay = f["lay"]
        x, y = f["x"], f["y"]
        up, jaw, cav = f["up"], f["jaw"], f["cav"]
        hx, hy = self.hinge
        a = f["angle"]
        n = max(2, m["teeth_n"])
        tl = max(1.0, m["teeth_len"] * self.L)
        tw = {"peg": 0.5, "triangle": 0.55, "fang": 0.32, "needle": 0.22, "cone": 0.45}[style] * tl
        tw = max(0.6, tw)
        closed = a <= 0.01
        teeth_mask = np.zeros_like(up)
        shade = np.zeros(up.shape, dtype=np.int32)
        sx, sy = rot(x, y, hx, hy, -a)

        def tooth(px, py, qx, qy, nx, ny, length, width, X_, Y_):
            # triangle from base centre (px,py) along normal (nx,ny)
            bx0, by0 = px - qx * width, py - qy * width
            bx1, by1 = px + qx * width, py + qy * width
            tx, ty = px + nx * length, py + ny * length
            return poly_mask(X_, Y_, [(bx0, by0), (bx1, by1), (tx, ty)])

        g = self.gape
        seg = np.hypot(np.diff(g[:, 0]), np.diff(g[:, 1]))
        cum = np.concatenate([[0.0], np.cumsum(seg)])
        total = cum[-1]
        for k in range(n):
            s = total * (0.3 + 0.66 * (k + 0.5) / n)
            px = np.interp(s, cum, g[:, 0])
            py = np.interp(s, cum, g[:, 1])
            i = min(len(g) - 2, int(np.searchsorted(cum, s)))
            qx, qy = g[i + 1, 0] - g[i, 0], g[i + 1, 1] - g[i, 1]
            ql = max(1e-6, math.hypot(qx, qy))
            qx, qy = qx / ql, qy / ql
            nx, ny = -qy, qx  # points down (into the mouth) for a left->right gape
            if ny < 0:
                nx, ny = -nx, -ny
            ln = tl * (1.15 if (style == "fang" and k % 2 == 0) else (0.8 if style == "fang" else 1.0))
            # upper tooth: fixed with the head, hangs into the mouth
            ut = tooth(px, py - 0.3, qx, qy, nx, ny, ln, tw, x, y)
            if closed:
                ut &= False
            else:
                ut &= cav | (jaw & False)
            teeth_mask |= ut
            shade[ut] = 5
            # lower tooth: lives in jaw space, points up
            lpx, lpy = px + qx * tw * 1.1, py + 0.3
            lt = tooth(lpx, lpy, qx, qy, -nx, -ny, ln * (0.9 if style != "fang" else 1.0), tw, sx, sy)
            if closed:
                lt &= up if m["closed_teeth"] else False
            else:
                lt &= cav | (up & m["closed_teeth"])
            teeth_mask |= lt
            shade[lt] = 4
        # protruding chin: an extra fang at the tip
        if self.chin_poly is not None:
            ux, uy = self.low_tip
            lt = tooth(ux - tw * 1.5, uy + 0.4, 1.0, 0.0, 0.0, -1.0, tl * 1.1, tw, sx, sy) & ~jaw
            teeth_mask |= lt
            shade[lt] = 5
        if teeth_mask.any():
            lay.paint(teeth_mask, "bone", shade)
            # shade the side facing away from the light
            right = np.pad(teeth_mask, ((0, 0), (0, 1)))[:, 1:]
            lay.shift(teeth_mask & ~right, -1, lo=3)

    # --------------------------------------------------------------- fins
    def fin_pts(self, spec, side, st, flutter=1.0, n=24):
        """Smooth polygon of a median fin (dorsal/anal). spec: (style, t0, t1, height x H)."""
        style, t0, t1, hgt = spec
        prof, sweep = FIN_PROFILES[style]
        s = np.linspace(0.0, 1.0, n)
        hs = np.clip(prof(s), 0.0, 1.0)
        lag = math.sin(st["phase"] - 1.3) * 0.05 * flutter
        t = t0 + (t1 - t0) * s
        tt = np.clip(t, 0.01, 0.99)
        sign = -1.0 if side == "top" else 1.0
        edge = self.top(tt) if side == "top" else self.bottom(tt)
        hp = hs * hgt * self.H
        bx = self.xt + t * self.L
        ox = bx - sweep * hp + lag * self.L * hs
        oy = edge + sign * hp
        base = [(float(xx), float(yy) - sign * 1.5) for xx, yy in zip(bx, edge)]
        outer = [(float(xx), float(yy)) for xx, yy in zip(ox, oy)]
        return base + outer[::-1]

    def paint_fin(self, lay, x, y, pts, ramp, base_tone=3, rays=True, edge=True, alpha=None, root=None, spacing=None):
        """Membrane fin: darker at the root, soft rays, lighter rim (thin tissue lets light through)."""
        msk = poly_mask(x, y, pts)
        if not msk.any():
            return msk
        alpha = self.p["fin_alpha"] if alpha is None else alpha
        if root is None:
            n = len(pts) // 2
            bpts = pts[:n]
            (bx0, by0), (bx1, by1) = bpts[0], bpts[-1]
            d = seg_dist(x, y, bx0, by0, bx1, by1)
        else:
            bx0, by0 = root
            d = np.hypot(x - bx0, y - by0)
        dmax = max(1.0, float(d[msk].max()))
        k = d / dmax
        tone = np.where(k < 0.3, base_tone - 1, base_tone)
        tone = np.where(k > 0.78, base_tone + 1, tone)
        lay.paint(msk, ramp, tone, alpha=alpha)
        if rays and self.L >= 20:
            sp = spacing or max(2.5, self.L * 0.065)
            if root is None:
                # rays run from the base toward the outer edge (follow the fin's sweep)
                n = len(pts) // 2
                outer = pts[n:][::-1]
                ids = np.linspace(0, n - 1, max(2, int(math.hypot(bx1 - bx0, by1 - by0) / sp)) + 1)
                for i in ids[1:-1]:
                    i = int(round(i))
                    (ax, ay), (cx_, cy_) = pts[i], outer[min(len(outer) - 1, i)]
                    ln = seg_dist(x, y, ax, ay, ax + (cx_ - ax) * 0.85, ay + (cy_ - ay) * 0.85)
                    lay.shift(msk & (ln < 0.5) & (k > 0.12), -1, lo=1)
            else:
                ang = np.arctan2(y - by0, x - bx0)
                nr = max(3, int(dmax / sp * 1.6))
                rk = ang / (math.pi * 0.9) * nr
                dk = 1.0 / np.maximum(1.0, d) / (math.pi * 0.9) * nr
                lay.shift(msk & (np.floor(rk) != np.floor(rk + dk)) & (k > 0.2) & (k < 0.88), -1, lo=1)
        if edge:
            inner = ndimage.binary_erosion(msk)
            rim = msk & ~inner & (k > 0.5)
            lay.shift(rim, +1, hi=6)
        return msk

    def fan_poly(self, bx, by, ang, ln, wd, n=14):
        """Paddle-shaped paired fin (pectoral/pelvic) from a root point."""
        ca, sa = math.cos(ang), math.sin(ang)
        nx, ny = -sa, ca
        top, bot = [], []
        for i in range(n + 1):
            s = i / n
            half = wd * 0.5 * (0.25 + 0.75 * math.sin(min(1.0, s / 0.72) * math.pi * 0.5)) * math.sqrt(max(0.0, 1.0 - max(0.0, s - 0.72) ** 2 / 0.0784))
            top.append((bx + ca * ln * s + nx * half, by + sa * ln * s + ny * half))
            bot.append((bx + ca * ln * s - nx * half * 0.8, by + sa * ln * s - ny * half * 0.8))
        return top + bot[::-1]

    def render_fins_back(self, w, h, x, y, st, f, style=None):
        p = self.p
        lay = Layer(w, h)
        fr = p["fin"]
        if p["dorsal"]:
            self.paint_fin(lay, x, y, self.fin_pts(p["dorsal"], "top", st), fr, 3)
        if p.get("dorsal2"):
            self.paint_fin(lay, x, y, self.fin_pts(p["dorsal2"], "top", st), fr, 3)
        if p["anal"]:
            self.paint_fin(lay, x, y, self.fin_pts(p["anal"], "bottom", st), fr, 3)
        if p["pelvic"]:
            t0 = 0.52
            bx = self.xt + t0 * self.L
            by = float(self.bottom(t0)) - 1.0
            ang = math.pi * 0.72 + 0.12 * math.sin(st["phase"] + 0.8)
            poly = self.fan_poly(bx, by, ang, p["pelvic"] * self.L * 0.55, p["pelvic"] * self.L * 0.3)
            self.paint_fin(lay, x, y, poly, fr, 3, root=(bx, by))
        lay.clean(1)
        return lay

    def pectoral_root(self, t=0.66, v=0.58):
        return self.xt + t * self.L, float(self.section_y(t, v))

    def render_fins_front(self, w, h, x, y, st, f):
        p = self.p
        lay = Layer(w, h)
        if p["pectoral"]:
            bx, by = self.pectoral_root()
            bx, by = bx, by
            ang = math.pi * 0.86 + 0.28 * math.sin(st["phase"] + 1.0) + st["pect"] * 0.5
            poly = self.fan_poly(bx, by, ang, p["pectoral"][0] * self.L, p["pectoral"][1] * self.L)
            self.paint_fin(lay, x, y, poly, p["pect_ramp"] or p["fin"], 4, root=(bx, by))
        lay.clean(1)
        self._contact_shadow(lay, f)
        return lay

    def _contact_shadow(self, lay, f):
        """Front fins cast a 1px soft shadow on the body under them."""
        m = lay.mask
        sh = np.pad(m, ((1, 0), (1, 0)))[:-1, :-1] & ~m & (f["up"] | f["jaw"])
        if sh.any():
            lay.paint(sh, "black", 0, alpha=70, outline=False)

    # --------------------------------------------------------------- tail
    def tail_local(self, x, y, st):
        """Fish-space -> tail space (u >= 0 behind the peduncle, a = vertical)."""
        ph = st["phase"]
        fs = 1.0 - 0.26 * math.sin(ph - 0.7) ** 2
        xt = self.xt + 1.0
        xf = np.where(x < xt, xt - (xt - x) / fs, x)
        u = (xt - xf) / max(1.0, self.p["tail_len"] * self.L)
        return u, y - self.cy

    def render_tail(self, w, h, x, y, st, f, kind=None, ramp=None, tail_len=None):
        p = self.p
        lay = Layer(w, h)
        kind = kind or p["tail"]
        if not kind:
            return lay
        ramp = ramp or p["tail_ramp"] or p["fin"]
        old = p["tail_len"]
        if tail_len:
            p["tail_len"] = tail_len
        Lt = p["tail_len"] * self.L
        # the body wave already bent x/y; the tail continues it (flexible fin)
        u, a = self.tail_local(x, y, st)
        p["tail_len"] = old
        U = u * Lt
        hb = max(1.0, self.H * p["ped"] * 0.5)
        lag = math.sin(st["phase"] - 1.8)
        poly = tail_poly(kind, Lt, hb, p["tail_spread"], lag)
        msk = poly_mask(U, a, poly) & (U >= -1.0)
        tone = np.where(u < 0.3, 2, 3)
        tone = np.where(u > 0.72, 4, tone)
        lay.paint(msk, ramp, tone, alpha=p["fin_alpha"])
        if self.L >= 16 and kind != "point":
            ang = np.arctan2(a, np.maximum(0.01, U))
            nr = max(4, int(self.L / 6))
            rayk = ang / (math.pi * 0.62) * nr
            dk = 1.0 / np.maximum(1.0, U) / (math.pi * 0.62) * nr
            ray = msk & (np.floor(rayk) != np.floor(rayk + dk)) & (u > 0.15) & (u < 0.88)
            lay.shift(ray, -1, lo=1)
            inner = ndimage.binary_erosion(msk)
            lay.shift(msk & ~inner & (u > 0.5), +1, hi=6)
        lay.clean(1)
        return lay


def _qcurve(p0, p1, p2, n=10):
    return [tuple(v) for v in bezier(p0, p1, p2, n)]


def tail_poly(kind, Lt, hb, spread=1.0, lag=0.0):
    """Caudal fin outline in tail space (U behind the peduncle, A vertical)."""
    S = spread
    shear = 0.12 * lag

    def P(u, a):
        return (u, a + shear * u)

    B1, B2 = P(-1.0, -hb), P(-1.0, hb)
    if kind == "fork":
        T1, T2, N = P(Lt, -0.78 * Lt * S), P(Lt, 0.78 * Lt * S), P(0.5 * Lt, 0.0)
        pts = _qcurve(B1, P(0.45 * Lt, -0.25 * Lt * S), T1) + _qcurve(T1, P(0.62 * Lt, -0.18 * Lt * S), N) \
            + _qcurve(N, P(0.62 * Lt, 0.18 * Lt * S), T2) + _qcurve(T2, P(0.45 * Lt, 0.25 * Lt * S), B2)
    elif kind == "hetero":
        T1, T2, N = P(Lt, -0.7 * Lt * S), P(0.55 * Lt, 0.5 * Lt * S), P(0.38 * Lt, 0.12 * hb)
        pts = _qcurve(B1, P(0.5 * Lt, -0.22 * Lt * S), T1) + _qcurve(T1, P(0.55 * Lt, -0.22 * Lt * S), N) \
            + _qcurve(N, P(0.42 * Lt, 0.2 * Lt * S), T2) + _qcurve(T2, P(0.22 * Lt, 0.2 * Lt * S), B2)
    elif kind == "lunate":
        T1, T2, N = P(0.9 * Lt, -0.95 * Lt * S), P(0.9 * Lt, 0.95 * Lt * S), P(0.42 * Lt, 0.0)
        pts = _qcurve(B1, P(0.2 * Lt, -0.55 * Lt * S), T1) + _qcurve(T1, P(0.5 * Lt, -0.35 * Lt * S), N) \
            + _qcurve(N, P(0.5 * Lt, 0.35 * Lt * S), T2) + _qcurve(T2, P(0.2 * Lt, 0.55 * Lt * S), B2)
    elif kind == "fluke":
        T1, T2, N = P(0.95 * Lt, -0.62 * Lt * S), P(0.95 * Lt, 0.62 * Lt * S), P(0.66 * Lt, 0.0)
        pts = _qcurve(B1, P(0.55 * Lt, -0.2 * Lt * S), T1) + _qcurve(T1, P(0.78 * Lt, -0.2 * Lt * S), N) \
            + _qcurve(N, P(0.78 * Lt, 0.2 * Lt * S), T2) + _qcurve(T2, P(0.55 * Lt, 0.2 * Lt * S), B2)
    elif kind == "round":
        r = Lt
        arc = [P(r * 0.72 + r * 0.28 * math.cos(t), r * 0.62 * S * math.sin(t)) for t in np.linspace(-math.pi * 0.5, math.pi * 0.5, 13)]
        pts = [B1] + _qcurve(B1, P(0.3 * Lt, -0.45 * Lt * S), arc[0])[1:] + arc[1:-1] + _qcurve(arc[-1], P(0.3 * Lt, 0.45 * Lt * S), B2)
    elif kind == "veil":
        T1, T2, N = P(Lt, -0.6 * Lt * S), P(Lt, 0.6 * Lt * S), P(0.7 * Lt, 0.0)
        pts = _qcurve(B1, P(0.25 * Lt, -0.75 * Lt * S), T1, 14) + _qcurve(T1, P(1.08 * Lt, -0.12 * Lt * S), N, 12) \
            + _qcurve(N, P(1.08 * Lt, 0.12 * Lt * S), T2, 12) + _qcurve(T2, P(0.25 * Lt, 0.75 * Lt * S), B2, 14)
    elif kind == "point":
        pts = [B1, P(Lt, 0.0), B2]
    else:
        pts = [B1, B2]
    return pts


def p_t(fish):
    return fish.p["gill_t"] - 0.03


# ------------------------------------------------------------------ helpers
def frame_state(i):
    return dict(FRAMES[i])


def render_sheet(make, w, h, parts=("tail", "fins_back", "body", "fins_front"), frames=None, post=None):
    """make(): returns a Fish; returns horizontal sheet of composited frames."""
    frames = frames if frames is not None else range(N_FRAMES)
    imgs = []
    for i in frames:
        fish = make()
        st = frame_state(i)
        layers = fish.render(w, h, st, parts)
        im = None
        for name in parts:
            li = layers[name].to_image()
            im = li if im is None else Image.alpha_composite(im, li)
        if post:
            im = post(fish, st, im)
        imgs.append(im)
    sheet = Image.new("RGBA", (w * len(imgs), h))
    for k, im in enumerate(imgs):
        sheet.alpha_composite(im, (k * w, 0))
    return sheet


# ------------------------------------------------------ reusable head parts
def recolor(f, where, ramp, shift=0, lo=1, hi=6):
    """Swap material keeping the lighting tone (patterns stay shaded)."""
    lay = f["lay"]
    where = where & lay.mask
    if where.any():
        lay.paint(where, ramp, np.clip(lay.tone + shift, lo, hi))


def bill_shape(length=0.4, thick=0.17, ramp="bone"):
    """Swordfish rostrum: an extension of the upper jaw (moves with the head)."""
    def fn(fish, st, x, y):
        lx, ly = fish.lip
        x0 = lx - 0.14 * fish.L
        y0 = ly - max(1.0, 0.1 * fish.H)
        x1 = lx + length * fish.L
        y1 = y0 + 0.03 * fish.H
        u = (x - x0) / (x1 - x0)
        yc = y0 + (y1 - y0) * u
        half = thick * fish.H * 0.5 * np.clip(1.0 - u, 0, 1) ** 0.85 + 0.4
        msk = (u >= 0) & (u <= 1) & (np.abs(y - yc) <= half)
        rel = (y - yc) / np.maximum(0.5, half)
        tone = np.where(rel < -0.3, 5, np.where(rel > 0.4, 3, 4))
        groove = (np.abs(rel - 0.1) < 0.5 / np.maximum(1.0, half)) & (u > 0.25) & (u < 0.85) & (half > 1.4)
        tone = np.where(groove, 3, tone)
        return msk, ramp, tone
    return fn


def lure_points(fish, st):
    L, H = fish.L, fish.H
    sway = math.sin(st["phase"] - 0.9) * 0.035 * L
    bx = fish.xt + 0.8 * L
    by = float(fish.top(0.8)) + 0.8
    mid = (fish.xt + 0.99 * L, float(fish.top(0.8)) - 0.62 * H + sway * 0.4)
    tip = (fish.xn + 0.15 * L + sway * 0.3, float(fish.top(0.8)) - 0.36 * H + sway)
    pts = bezier((bx, by), mid, tip, 16)
    r = max(1.6, 0.068 * L)
    bulb = (tip[0], tip[1] + r * 0.55)
    return pts, bulb, r


def lure_shape(stalk_ramp="abyss", bulb_ramp="glow"):
    def fn(fish, st, x, y):
        pts, (cx, cy), r = lure_points(fish, st)
        wdt = max(0.55, fish.L * 0.018)
        d = np.full(x.shape, 99.0)
        for i in range(len(pts) - 1):
            d = np.minimum(d, seg_dist(x, y, pts[i, 0], pts[i, 1], pts[i + 1, 0], pts[i + 1, 1]))
        stalk = d <= wdt
        db = np.hypot(x - cx, y - cy)
        bulb = db <= r
        msk = stalk | bulb
        tone = np.where(stalk, 3, 0)
        tone = np.where(bulb, np.where(np.hypot(x - (cx - r * 0.3), y - (cy - r * 0.3)) < r * 0.55, 6, np.where(y > cy + r * 0.35, 4, 5)), tone)
        # two materials: return the stalk here, the bulb is painted by lure_detail
        return msk, stalk_ramp, tone
    return fn


def lure_detail(bulb_ramp="glow"):
    def fn(fish, st, f, lay):
        pts, (cx, cy), r = lure_points(fish, st)
        X, Y = f["x"], f["y"]
        db = np.hypot(X - cx, Y - cy)
        bulb = db <= r
        tone = np.where(np.hypot(X - (cx - r * 0.3), Y - (cy - r * 0.3)) < r * 0.55, 6, np.where(Y > cy + r * 0.35, 4, 5))
        lay.paint(bulb, bulb_ramp, tone)
    return fn


def lure_screen(fish, st):
    _, (cx, cy), r = lure_points(fish, st)
    return fish.to_screen(cx, cy, st)


def auto_sheet(make, L, parts=("tail", "fins_back", "body", "fins_front"), frames=None, margin=1, post=None):
    """Renders every frame on a roomy canvas and crops them all to the same box
    centred on the body centre, so the sprite origin is the fish's centre (the
    game can mirror it without the body jumping) and nothing gets clipped."""
    frames = list(frames if frames is not None else range(N_FRAMES))
    W, Hh = int(L * 4) + 16, int(L * 3) + 16
    cx, cy = W // 2, Hh // 2
    imgs = []
    for i in frames:
        fish = make(cx, cy)
        st = frame_state(i)
        layers = fish.render(W, Hh, st, parts)
        im = None
        for name in parts:
            li = layers[name].to_image()
            im = li if im is None else Image.alpha_composite(im, li)
        if post:
            im = post(fish, st, im)
        imgs.append(im)
    x0, y0, x1, y1 = W, Hh, 0, 0
    for im in imgs:
        bb = im.getbbox()
        if bb:
            x0, y0 = min(x0, bb[0]), min(y0, bb[1])
            x1, y1 = max(x1, bb[2]), max(y1, bb[3])
    hw = max(cx - x0, x1 - cx) + margin
    hh = max(cy - y0, y1 - cy) + margin
    w, h = hw * 2, hh * 2
    sheet = Image.new("RGBA", (w * len(imgs), h))
    for k, im in enumerate(imgs):
        sheet.alpha_composite(im.crop((cx - hw, cy - hh, cx + hw, cy + hh)), (k * w, 0))
    return sheet
