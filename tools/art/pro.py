"""Professional pixel-art rendering core (numpy).

Techniques (see docs/ART.md):
  * hue-shifted colour ramps: shadows drift toward blue/violet and lose value,
    highlights drift toward yellow and lose saturation;
  * volume shading from a height field (not "pillow shading"): one consistent
    light source (top-left, slightly toward the viewer);
  * quantisation into few tones with only light ordered dithering on big
    sprites, then removal of orphan pixels so every tone forms clean clusters;
  * selective outline ("sel-out"): outlines take a darker tone of the colour
    they touch, lighter on the lit side, never flat black;
  * parts (fins, body, jaw...) are rendered and outlined separately, then
    composited back-to-front like a paper-doll rig.
"""
from __future__ import annotations

import colorsys
import math

import numpy as np
from PIL import Image
from scipy import ndimage

# light from above and slightly in front of the fish's face (sprites face right
# and are mirrored in game, so a mostly vertical light stays believable)
LIGHT = np.array([0.25, -0.8, 0.55])
LIGHT = LIGHT / np.linalg.norm(LIGHT)


# ----------------------------------------------------------------- ramps
def _shift_hue(h: float, target: float, amount: float) -> float:
    d = ((target - h + 0.5) % 1.0) - 0.5
    return (h + d * amount) % 1.0


def ramp(hex_base: str, n: int = 7, base_i: int = 4, dark=0.2, shadow_hue=0.72, shadow_shift=0.32,
         light_hue=0.14, light_shift=0.28, sat_dark=1.1, sat_light=0.45, light_gain=0.95, sat=None):
    """n-step hue-shifted ramp. Index base_i is exactly the base colour.

    Darker steps lose value, gain a little saturation and drift toward
    blue/violet; lighter steps drift toward yellow and lose saturation.
    """
    r, g, b = (int(hex_base[i:i + 2], 16) / 255.0 for i in (1, 3, 5))
    h, s, v = colorsys.rgb_to_hsv(r, g, b)
    if sat is not None:
        s = sat
    out = []
    for i in range(n):
        if i <= base_i:
            k = (base_i - i) / max(1, base_i)
            vv = v * (1.0 - (1.0 - dark) * k ** 1.05)
            hh = _shift_hue(h, shadow_hue, shadow_shift * k)
            ss = min(1.0, s * (1.0 + (sat_dark - 1.0) * math.sin(k * math.pi * 0.8)))
        else:
            k = (i - base_i) / max(1, n - 1 - base_i)
            vv = v + (1.0 - v) * k * light_gain
            hh = _shift_hue(h, light_hue, light_shift * k)
            ss = s * (1.0 - (1.0 - sat_light) * k)
        rr, gg, bb = colorsys.hsv_to_rgb(hh, max(0.0, min(1.0, ss)), max(0.0, min(1.0, vv)))
        out.append((int(round(rr * 255)), int(round(gg * 255)), int(round(bb * 255))))
    return np.array(out, dtype=np.uint8)


PAL = {
    # fish bodies (index 4 = the named colour)
    "gold": ramp("#ff8a1c"), "cream": ramp("#ffe2b0", dark=0.3), "flame": ramp("#ff5433"),
    "neon": ramp("#2f7dff"), "cyan": ramp("#46eaff"), "red": ramp("#f5303e"),
    "olive": ramp("#a09048"), "sandy": ramp("#e8c290", dark=0.28), "brown": ramp("#9a6034"),
    "silver": ramp("#b4c8dc", dark=0.24), "white": ramp("#f2f6fc", dark=0.3), "steel": ramp("#7c8cac"),
    "shark": ramp("#6e90b8"), "navy": ramp("#3a5e96"), "abyss": ramp("#5a468c"), "ink": ramp("#3a3050"),
    "violet": ramp("#9460ea"), "volt": ramp("#ffe234"), "lime": ramp("#a0ea40"), "poison": ramp("#b456e6"),
    "glow": ramp("#6cffe2", dark=0.25), "black": ramp("#3c3854", dark=0.3), "coral": ramp("#ff6a84"),
    "pink": ramp("#ffa0bc"), "bone": ramp("#f6ead0", dark=0.3), "orange": ramp("#ff961e"), "sunset": ramp("#ff7442"),
    "moss": ramp("#6a9a3a"), "sharkgrey": ramp("#5b7390"), "titan": ramp("#46606e"), "kraken": ramp("#e04a42"), "titanbelly": ramp("#b4a48c", dark=0.3), "armor": ramp("#b8ae9c", dark=0.28), "flesh": ramp("#c8424e"), "parasite": ramp("#c48cc0"), "acid": ramp("#b8e04a"), "orca": ramp("#2c3148", dark=0.3, light_gain=0.8), "eel": ramp("#5e8a3c"), "kelp": ramp("#5a8a2e"), "sand": ramp("#e6cc98", dark=0.3), "rock": ramp("#7a7090"),
    # mouths
    "mouth": np.array([(24, 6, 18), (48, 12, 30), (84, 20, 44), (122, 34, 60), (164, 56, 78), (206, 90, 106), (238, 140, 150)], dtype=np.uint8),
    "gum": ramp("#f0788e"),
    "iris_gold": ramp("#f2b820"), "iris_red": ramp("#f02828"), "iris_green": ramp("#86dc44"),
    "iris_cyan": ramp("#48dcf8"), "iris_dark": ramp("#3a3a4e", dark=0.3), "iris_white": ramp("#e8ecf4", dark=0.35),
}


def pal(name: str) -> np.ndarray:
    return PAL[name]


# ------------------------------------------------------------ geometry
def grid(w: int, h: int):
    ys, xs = np.mgrid[0:h, 0:w].astype(np.float64)
    return xs + 0.5, ys + 0.5


def poly_mask(x, y, pts):
    """Vectorised even-odd point-in-polygon for coordinate arrays x, y."""
    inside = np.zeros(x.shape, dtype=bool)
    n = len(pts)
    j = n - 1
    for i in range(n):
        xi, yi = pts[i]
        xj, yj = pts[j]
        cond = (yi > y) != (yj > y)
        with np.errstate(divide="ignore", invalid="ignore"):
            xint = (xj - xi) * (y - yi) / (yj - yi + 1e-12) + xi
        inside ^= cond & (x < xint)
        j = i
    return inside


def seg_dist(x, y, x0, y0, x1, y1):
    dx, dy = x1 - x0, y1 - y0
    l2 = dx * dx + dy * dy
    if l2 == 0:
        return np.hypot(x - x0, y - y0)
    t = np.clip(((x - x0) * dx + (y - y0) * dy) / l2, 0.0, 1.0)
    return np.hypot(x - (x0 + t * dx), y - (y0 + t * dy))


def rotate(x, y, cx, cy, ang):
    c, s = math.cos(ang), math.sin(ang)
    dx, dy = x - cx, y - cy
    return cx + dx * c - dy * s, cy + dx * s + dy * c


# ------------------------------------------------------------- shading
BAYER4 = (np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) + 0.5) / 16.0


def bayer(h, w):
    return np.tile(BAYER4, (h // 4 + 1, w // 4 + 1))[:h, :w]


def dome_height(mask: np.ndarray, radius=None) -> np.ndarray:
    """Rounded height field from the distance to the silhouette edge."""
    d = ndimage.distance_transform_edt(mask)
    r = radius if radius else max(1.0, float(d.max()))
    t = np.clip(d / r, 0.0, 1.0)
    return np.sqrt(1.0 - (1.0 - t) ** 2) * r


def normals(height: np.ndarray, smooth=0.8):
    hh = ndimage.gaussian_filter(height, smooth) if smooth > 0 else height
    gy, gx = np.gradient(hh)
    nz = np.ones_like(hh)
    n = np.stack([-gx, -gy, nz], axis=-1)
    n /= np.linalg.norm(n, axis=-1, keepdims=True)
    return n


def light(n: np.ndarray, ambient=0.28, wrap=0.15) -> np.ndarray:
    d = n @ LIGHT
    d = (d + wrap) / (1.0 + wrap)
    return np.clip(ambient + (1.0 - ambient) * np.clip(d, 0.0, 1.0), 0.0, 1.0)


def quantise(val: np.ndarray, lo: int, hi: int, dither=0.0) -> np.ndarray:
    """Map light values (0..1) to integer ramp indices lo..hi."""
    n = hi - lo + 1
    if dither > 0:
        h, w = val.shape
        val = val + (bayer(h, w) - 0.5) * dither / n
    idx = np.floor(np.clip(val, 0.0, 0.9999) * n).astype(np.int32) + lo
    return np.clip(idx, lo, hi)


def clean_orphans(idx: np.ndarray, mask: np.ndarray, iterations=1) -> np.ndarray:
    """Replace pixels whose tone differs from all 4 neighbours (noise)."""
    idx = idx.copy()
    for _ in range(iterations):
        pad = np.pad(idx, 1, mode="edge")
        mpad = np.pad(mask, 1)
        nb = [pad[:-2, 1:-1], pad[2:, 1:-1], pad[1:-1, :-2], pad[1:-1, 2:]]
        nm = [mpad[:-2, 1:-1], mpad[2:, 1:-1], mpad[1:-1, :-2], mpad[1:-1, 2:]]
        same = np.zeros(idx.shape, dtype=np.int32)
        for a, m in zip(nb, nm):
            same += (a == idx) & m
        valid = sum(m.astype(np.int32) for m in nm)
        orphan = mask & (same == 0) & (valid >= 3)
        if not orphan.any():
            break
        # most common neighbour value (use median as a cheap proxy)
        stack = np.stack(nb, axis=0)
        med = np.median(stack, axis=0).round().astype(np.int32)
        idx[orphan] = med[orphan]
    return idx


def clean_mask(mask: np.ndarray) -> np.ndarray:
    """Remove 1-pixel spikes and fill 1-pixel notches (fewer jaggies)."""
    m = mask.copy()
    cross = np.array([[0, 1, 0], [1, 1, 1], [0, 1, 0]])
    nb = ndimage.convolve(m.astype(np.int32), cross, mode="constant") - m
    m[(m) & (nb <= 1)] = False
    nb = ndimage.convolve(m.astype(np.int32), cross, mode="constant") - m
    m[(~m) & (nb >= 3)] = True
    return m


# --------------------------------------------------------------- parts
class Part:
    """One rendered layer piece: colour image + coverage mask + outline info."""

    def __init__(self, w, h):
        self.w, self.h = w, h
        self.rgb = np.zeros((h, w, 3), dtype=np.uint8)
        self.mask = np.zeros((h, w), dtype=bool)
        # per pixel outline ramp (index into ramps list) for sel-out
        self.out_ramp = np.full((h, w), -1, dtype=np.int32)
        self.ramps: list = []

    def paint(self, where: np.ndarray, ramp_arr: np.ndarray, idx: np.ndarray | int):
        where = where & True
        if not where.any():
            return
        if isinstance(idx, (int, np.integer)):
            self.rgb[where] = ramp_arr[int(np.clip(idx, 0, len(ramp_arr) - 1))]
        else:
            ii = np.clip(idx[where], 0, len(ramp_arr) - 1)
            self.rgb[where] = ramp_arr[ii]
        self.mask |= where
        key = None
        for k, r in enumerate(self.ramps):
            if r is ramp_arr:
                key = k
        if key is None:
            self.ramps.append(ramp_arr)
            key = len(self.ramps) - 1
        self.out_ramp[where] = key

    def to_image(self, outline=True, lit_outline=True, outline_alpha=255) -> Image.Image:
        img = np.zeros((self.h, self.w, 4), dtype=np.uint8)
        img[..., :3] = self.rgb
        img[..., 3] = np.where(self.mask, 255, 0)
        if outline:
            m = self.mask
            pad = np.pad(m, 1)
            rpad = np.pad(self.out_ramp, 1, constant_values=-1)
            ring = (~m) & (pad[:-2, 1:-1] | pad[2:, 1:-1] | pad[1:-1, :-2] | pad[1:-1, 2:])
            # which neighbour defines the colour: prefer the one below/right
            # (the pixel is then on the top-left = lit side)
            srcs = [
                (pad[2:, 1:-1], rpad[2:, 1:-1], True),    # neighbour below -> outline is above
                (pad[1:-1, 2:], rpad[1:-1, 2:], True),    # neighbour right -> outline is left
                (pad[:-2, 1:-1], rpad[:-2, 1:-1], False),  # neighbour above -> outline below (shadow)
                (pad[1:-1, :-2], rpad[1:-1, :-2], False),  # neighbour left -> outline right (shadow)
            ]
            done = np.zeros_like(m)
            # shadow side first so it wins over lit side on corners
            for nm, nr, lit in reversed(srcs):
                sel = ring & nm & ~done
                if not sel.any():
                    continue
                ys, xs = np.nonzero(sel)
                for y, x in zip(ys, xs):
                    k = nr[y, x]
                    rr = self.ramps[k] if k >= 0 else PAL["black"]
                    c = rr[1] if (lit and lit_outline) else rr[0]
                    img[y, x, :3] = c
                    img[y, x, 3] = outline_alpha
                done |= sel
        return Image.fromarray(img, "RGBA")


def compose(layers):
    """Alpha-composite PIL images back-to-front."""
    base = layers[0].copy()
    for l in layers[1:]:
        base.alpha_composite(l)
    return base
