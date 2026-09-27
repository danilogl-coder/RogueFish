"""Seafloor: one heightmap shared by the game and the art.

The terrain is the single source of truth for the floor height. It is baked to
assets/art/terrain.json (heights every STEP px) and to chunk textures whose top
edge follows exactly the same heights, so anything placed with DB.floor_at()
touches the drawn sand.

Pixel-art rules applied here (see docs/ART.md):
  * the walkable top layer carries the detail and the highest contrast (lit
    edge, grains, pebbles); deeper layers get darker, cooler and flatter;
  * one light from above: flat ground gets a bright lip, steep faces are shaded
    and show rock strata instead of sand;
  * big props need level ground, so every prop site (caves, thickets, eel
    rocks, vents, whale fall) is carved as a flat shelf;
  * a thin "front" strip of the ground (lip + pebbles + tufts) is drawn in
    front of props, planting their bases in the sand instead of floating.
"""
from __future__ import annotations

import json
import math
import os

import numpy as np
from PIL import Image
from scipy import ndimage

import pro
from pro import PAL, ramp

W = 6000          # 4800 base ocean + 1200 "Fontes Hidrotermais" expansion (locked until bought)
BASE_W = 4800
STEP = 2
CHUNK = 240
TOP_MARGIN = 34      # room above the highest surface point for baked rocks
FILL = 120           # textured depth below the lowest surface point of a chunk
LIP = 3              # rows of ground drawn in front of props
FRONT_UP = 8         # room above the surface in the front strip (tufts, pebbles)
MAX_Y = 1490.0

# Prop sites: (kind, x, half width of the flat shelf)
SITES = [
    ("cave", 260, 70), ("cave", 1050, 70), ("cave", 3452, 70), ("cave", 4050, 70), ("cave", 4620, 70),
    ("thicket", 700, 46), ("thicket", 1700, 46), ("thicket", 2150, 46), ("thicket", 2600, 46), ("thicket", 3000, 46),
    ("eel_rock", 520, 30), ("eel_rock", 830, 30), ("eel_rock", 1310, 30),
    ("vent", 3930, 20), ("vent", 4480, 20), ("vent", 4740, 20),
    ("whale", 4300, 76),
    # Fontes Hidrotermais expansion
    ("vent", 5040, 20), ("vent", 5290, 20), ("vent", 5560, 20), ("vent", 5830, 20),
    ("cave", 5420, 70),
]

BIOMES = [("reef", 0, 1450), ("kelp", 1450, 3150), ("slope", 3150, 3750), ("abyss", 3750, BASE_W),
          ("vents", BASE_W, W)]

GROUND = {
    # top highlight, topsoil, subsoil, deep ramps + speck colours
    "reef": dict(soil=ramp("#ead3a2", dark=0.32), sub=ramp("#b08a6a", dark=0.3), deep=ramp("#5e4656", dark=0.35),
                 specks=["coral", "pink", "bone", "orange"]),
    "kelp": dict(soil=ramp("#c9ae80", dark=0.3), sub=ramp("#8a7058", dark=0.3), deep=ramp("#4a3a4c", dark=0.35),
                 specks=["olive", "bone", "moss"]),
    "slope": dict(soil=ramp("#9a8c9e", dark=0.3), sub=ramp("#6c6480", dark=0.3), deep=ramp("#3a3452", dark=0.35),
                  specks=["bone", "sandy"]),
    "abyss": dict(soil=ramp("#4e4668", dark=0.3), sub=ramp("#352f4c", dark=0.32), deep=ramp("#1e1a30", dark=0.4),
                  specks=["glow", "violet"]),
    # basalt with glowing cracks and sulphur crusts
    "vents": dict(soil=ramp("#4a3a44", dark=0.3), sub=ramp("#2e2230", dark=0.35), deep=ramp("#1a1218", dark=0.4),
                  specks=["orange", "volt", "orange"]),
}
DEEP = (22, 17, 32)


def smoothstep(e0, e1, x):
    t = np.clip((x - e0) / (e1 - e0), 0.0, 1.0)
    return t * t * (3.0 - 2.0 * t)


def value_noise(x, wavelength, seed):
    """Smooth 1D value noise in [-1, 1]."""
    rng = np.random.default_rng(seed)
    n = int(W / wavelength) + 3
    pts = rng.uniform(-1, 1, n)
    u = x / wavelength
    i = np.floor(u).astype(int)
    f = u - i
    f = f * f * (3 - 2 * f)
    return pts[i] * (1 - f) + pts[i + 1] * f


def hash2(a, b, seed=0):
    v = np.sin(a * 12.9898 + b * 78.233 + seed * 37.719) * 43758.5453
    return v - np.floor(v)


def biome_weights(x):
    """Soft biome membership (for blended ground materials)."""
    out = {}
    for name, x0, x1 in BIOMES:
        w = smoothstep(x0 - 60, x0 + 60, x) * (1.0 - smoothstep(x1 - 60, x1 + 60, x))
        if x0 == 0:
            w = 1.0 - smoothstep(x1 - 60, x1 + 60, x)
        if x1 == W:
            w = smoothstep(x0 - 60, x0 + 60, x)
        out[name] = w
    return out


# ----------------------------------------------------------------- heights
def build_heights():
    x = np.arange(W + 1, dtype=float)
    h = np.full_like(x, 830.0)
    # reef -> kelp forest: a soft drop
    h = h + (948.0 - 830.0) * smoothstep(1260.0, 1640.0, x)
    # reef relief: coral mounds and rocky outcrops
    for cx, amp, wd in ((140, -10, 60), (400, -16, 70), (620, -8, 50), (930, -20, 80), (1180, -12, 55)):
        h += amp * np.exp(-((x - cx) / wd) ** 2)
    # kelp forest: dunes and sand ripples
    kelp = smoothstep(1500, 1650, x) * (1.0 - smoothstep(3100, 3160, x))
    h += kelp * (6.0 * np.sin(x / 310.0 * math.tau + 1.0) + 3.0 * np.sin(x / 127.0 * math.tau))
    # continental slope: ledges separated by cliffs
    steps = [(3150, 3210, 948.0), (3260, 3330, 1060.0), (3375, 3530, 1175.0), (3580, 3650, 1300.0), (3800, W, 1470.0)]
    slope = np.full_like(x, np.nan)
    prev_end, prev_y = None, None
    for x0, x1, yy in steps:
        if prev_end is not None:
            seg = (x > prev_end) & (x < x0)
            t = smoothstep(prev_end, x0, x[seg])
            slope[seg] = prev_y + (yy - prev_y) * t
        sel = (x >= x0) & (x <= x1)
        slope[sel] = yy
        prev_end, prev_y = x1, yy
    on_slope = x >= 3150
    h = np.where(on_slope, slope, h)
    # abyssal plain: long swells
    abyss = smoothstep(3800, 3900, x) * (1.0 - smoothstep(BASE_W - 60, BASE_W + 80, x))
    h += abyss * (8.0 * np.sin(x / 420.0 * math.tau + 2.0) + 4.0 * np.sin(x / 150.0 * math.tau))
    # hydrothermal field: a volcanic ridge of basalt terraces and spires
    vents = smoothstep(BASE_W - 40, BASE_W + 160, x)
    ridge = 1470.0 - 150.0 * smoothstep(BASE_W, BASE_W + 420, x) + 40.0 * smoothstep(5650, 5950, x)
    ridge += 22.0 * np.sin(x / 260.0 * math.tau + 0.7) + 9.0 * np.abs(np.sin(x / 57.0 * math.tau))
    h = h * (1.0 - vents) + ridge * vents
    # fine irregularity everywhere except cliffs
    h += 1.6 * value_noise(x, 34.0, 7) + 0.8 * value_noise(x, 13.0, 11)
    # flat shelves for props (vents get a small mesa)
    for kind, sx, hw in SITES:
        lo, hi = sx - hw, sx + hw
        core = (x >= lo) & (x <= hi)
        level = float(np.median(h[core]))
        if kind == "vent":
            level -= 18.0
            edge = 26.0
        else:
            edge = 22.0
        wgt = smoothstep(lo - edge, lo, x) * (1.0 - smoothstep(hi, hi + edge, x))
        h = h * (1.0 - wgt) + level * wgt
    return np.minimum(h, MAX_Y)


# --------------------------------------------------------------- materials
def ground_colors(xs, rows, top, slope, rng_seed=3):
    """Colour every pixel of a block of columns. rows: absolute y grid."""
    H, Wc = rows.shape
    xf = xs.astype(float)
    img = np.zeros((H, Wc, 3), dtype=np.float64)
    depth = rows - top[None, :]
    weights = biome_weights(xf)
    steep = np.clip(np.abs(slope) / 1.6, 0.0, 1.0)[None, :]
    # organic layer boundaries: jitter per pixel + slow variation along x
    jit = (hash2(xs[None, :] // 3, rows // 2, 5) - 0.5) * 2.5
    d = depth + jit
    soil_th = (7.0 + 3.0 * value_noise(xf, 40.0, 3) - 4.0 * steep[0])[None, :]
    sub_th = (24.0 + 7.0 * value_noise(xf, 70.0, 9))[None, :]
    # buried stones: one candidate per staggered cell
    cw_, ch_ = 19.0, 13.0
    row_i = np.floor(rows / ch_)
    off = np.where(row_i % 2 == 0, 0.0, cw_ * 0.5)
    col_i = np.floor((xs[None, :] + off) / cw_)
    sx = (col_i + 0.25 + 0.5 * hash2(col_i, row_i, 31)) * cw_ - off
    sy = (row_i + 0.3 + 0.4 * hash2(row_i, col_i, 37)) * ch_
    sr = 1.5 + 4.5 * hash2(col_i, row_i, 41) ** 1.6
    has = hash2(col_i, row_i, 43) < 0.28
    dx, dy = (xs[None, :] + 0.5 - sx) / (sr * 1.4), (rows + 0.5 - sy) / sr
    dd = dx * dx + dy * dy
    stone = has & (dd <= 1.0) & (d > soil_th + 1)
    stone_top = stone & (dy < -0.45)
    stone_bot = stone & (dy > 0.55)
    for name, wgt in weights.items():
        if not np.any(wgt > 0.001):
            continue
        g = GROUND[name]
        soil, sub, deep = g["soil"], g["sub"], g["deep"]
        tone_soil = np.where(d < 1.0, 6, np.where(d < 3.0, 5, 4))
        c_soil = soil[np.clip(tone_soil, 0, 6)]
        c_sub = sub[np.where(d < sub_th - 8, 4, 3)]
        c_deep = deep[np.where(d < 70, 3, 2)]
        col = np.where((d < soil_th)[..., None], c_soil, np.where((d < sub_th)[..., None], c_sub, c_deep))
        # sedimentary strata in rock: wavy light/dark line pairs, broken in places
        if name in ("slope", "abyss", "vents"):
            wav = (4.0 * value_noise(xf, 55.0, 23) + xf * 0.08)[None, :]
            k = np.floor(rows + wav).astype(int) % (10 if name == "slope" else 14)
            broken = hash2(xs[None, :] // 7, np.floor(rows + wav) // 10, 29) < 0.3
            strata_on = (d > soil_th + 2) & ~broken
            col = np.where((strata_on & (k == 0))[..., None], sub[2][None, None, :] * 0.6 + col * 0.4, col)
            col = np.where((strata_on & (k == 1))[..., None], sub[5][None, None, :] * 0.35 + col * 0.65, col)
        # stones: rock colour with a lit top and dark underside
        rk = sub if name not in ("abyss", "vents") else deep
        col = np.where(stone[..., None], rk[3][None, None, :] * np.ones_like(col), col)
        col = np.where(stone_top[..., None], rk[5][None, None, :] * np.ones_like(col), col)
        col = np.where(stone_bot[..., None], rk[1][None, None, :] * np.ones_like(col), col)
        # coloured bits in the topsoil (coral rubble / glowing bacteria)
        bits = (hash2(xs[None, :], rows, 57 + len(name)) < (0.02 if name == "reef" else 0.012)) & (d > 1.5) & (d < soil_th + 3)
        sp = PAL[g["specks"][0]]
        col = np.where(bits[..., None], sp[5 if name in ("abyss", "vents") else 4][None, None, :] * np.ones_like(col), col)
        if name == "vents":
            # glowing magma cracks running through the basalt
            cr = np.abs(value_noise(xf, 23.0, 61)[None, :] * 6.0 + np.sin(rows / 9.0 + xf[None, :] / 31.0) * 3.0 - (d - 18.0))
            crack = (cr < 0.7) & (d > 4) & (d < 60) & (hash2(xs[None, :] // 5, rows // 5, 67) < 0.7)
            glow = PAL["orange"]
            col = np.where(crack[..., None], glow[5][None, None, :] * np.ones_like(col), col)
            halo = (cr >= 0.7) & (cr < 1.6) & (d > 4) & (d < 60)
            col = np.where(halo[..., None], col * 0.6 + glow[3][None, None, :] * 0.4, col)
        img += col * wgt[None, :, None]
    # grains: sparse darker / lighter pixels in the topsoil
    gr = hash2(xs[None, :], rows, 21)
    dark_g = (gr > 0.935) & (depth > 1) & (depth < 16)
    light_g = (gr < 0.03) & (depth > 1) & (depth < 9)
    img = np.where(dark_g[..., None], img * 0.84, img)
    img = np.where(light_g[..., None], np.minimum(255, img * 1.12 + 6), img)
    # steep faces receive less light: dim their lip and topsoil
    face = (depth < 8) & (steep > 0.45)
    img = np.where(face[..., None], img * (1.0 - 0.18 * steep)[..., None], img)
    # depth fog: deeper rows fade toward the deep water colour
    fog = np.clip((depth - 12) / 95.0, 0.0, 1.0)[..., None] * 0.82
    img = img * (1 - fog) + np.array(DEEP)[None, None, :] * fog
    return img


# ------------------------------------------------------------ decorations
def blob(rng, w, h):
    """Rounded rock outline (polygon) of size ~w x h, flat-ish bottom."""
    n = 14
    pts = []
    for k in range(n):
        a = math.pi + k / (n - 1) * math.pi
        r = 1.0 + rng.uniform(-0.12, 0.12)
        pts.append((math.cos(a) * w * 0.5 * r, math.sin(a) * h * r))
    pts.append((w * 0.48, h * 0.25))
    pts.append((-w * 0.48, h * 0.25))
    return pts


class Canvas:
    def __init__(self, x0, y0, w, h):
        self.x0, self.y0, self.w, self.h = x0, y0, w, h
        self.rgb = np.zeros((h, w, 3), dtype=np.float64)
        self.a = np.zeros((h, w), dtype=bool)
        self.X, self.Y = np.meshgrid(np.arange(w) + x0 + 0.5, np.arange(h) + y0 + 0.5)


def paint_rock(cv, cx, base_y, w, h, rng, rock_ramp, top_arr, x_arr):
    pts = [(cx + px, base_y + py) for px, py in blob(rng, w, h)]
    m = pro.poly_mask(cv.X, cv.Y, pts)
    # the buried part stays hidden: only paint above the local surface
    colx = np.clip(np.floor(cv.X).astype(int), 0, W - 1)
    m &= cv.Y < top_arr[colx] + 1.0
    if not m.any():
        return
    # volume light from a dome height field
    hgt = pro.dome_height(m)
    nrm = pro.normals(hgt, smooth=0.6)
    li = pro.light(nrm, ambient=0.25)
    tone = pro.quantise(li, 1, 5)
    # moss / sediment cap on top for shallow biomes
    cv.rgb[m] = rock_ramp[tone[m]]
    cv.a |= m
    # sel-out outline (darker at the bottom, mid at the top)
    ring = ndimage.binary_dilation(m) & ~m & ~cv.a
    up = np.roll(m, 1, axis=0)
    cv.rgb[ring] = rock_ramp[0]
    cv.rgb[ring & up] = rock_ramp[0]
    cv.rgb[ring & ~up] = rock_ramp[1]
    cv.a |= ring


def build(out_dir, meta_path):
    heights = build_heights()
    xs_all = np.arange(W)
    top = np.round(heights[:-1] + 0.5 * (heights[1:] - heights[:-1])).astype(int)  # surface row per column
    slope = np.gradient(heights)[:-1]
    rng = np.random.default_rng(42)
    os.makedirs(out_dir, exist_ok=True)
    chunks = []
    site_mask = np.zeros(W, dtype=bool)
    for kind, sx, hw in SITES:
        site_mask[max(0, sx - hw - 30):min(W, sx + hw + 30)] = True
    # decoration plan (deterministic): big rocks baked into the back texture
    rocks = []
    x = 60
    while x < W - 60:
        b = next(n for n, x0, x1 in BIOMES if x0 <= x < x1)
        gap = {"reef": (140, 320), "kelp": (160, 360), "slope": (60, 140), "abyss": (120, 260), "vents": (70, 160)}[b]
        x += int(rng.integers(*gap))
        if x >= W - 40 or site_mask[min(W - 1, x)]:
            continue
        size = rng.uniform(0.6, 1.0)
        rw = int((16 + 26 * size) * (1.3 if b == "slope" else 1.0))
        rh = int(rw * rng.uniform(0.38, 0.55))
        lo, hi = max(0, x - rw // 2), min(W - 1, x + rw // 2)
        if top[lo:hi + 1].max() - top[lo:hi + 1].min() > max(3, rh // 4):
            continue  # boulders only rest on level ground
        rocks.append((x, rw, rh, b))
    for ci in range(0, W, CHUNK):
        cx0, cx1 = ci, min(W, ci + CHUNK)
        cols = xs_all[cx0:cx1]
        ctop = top[cx0:cx1]
        y0 = int(ctop.min()) - TOP_MARGIN
        y1 = int(ctop.max()) + FILL
        hh = y1 - y0
        rows = np.arange(y0, y1)[:, None] + np.zeros((1, cx1 - cx0), dtype=int)
        colr = ground_colors(cols, rows, ctop, slope[cx0:cx1])
        fade = np.clip((rows - (y1 - 28)) / 27.0, 0.0, 1.0)[..., None]
        colr = colr * (1.0 - fade) + np.array(DEEP)[None, None, :] * fade
        solid = rows >= ctop[None, :]
        rgba = np.zeros((hh, cx1 - cx0, 4), dtype=np.uint8)
        rgba[..., :3] = np.clip(colr, 0, 255).astype(np.uint8)
        rgba[..., 3] = np.where(solid, 255, 0)
        # contact line: 1px darker ground just under the lit lip on slopes facing away
        # baked rocks (back only)
        cv = Canvas(cx0, y0, cx1 - cx0, hh)
        for (rx, rw, rh, b) in rocks:
            if rx + rw < cx0 - 2 or rx - rw > cx1 + 2:
                continue
            lo, hi = max(0, rx - rw // 2), min(W - 1, rx + rw // 2)
            base = int(top[lo:hi + 1].max()) + int(rh * 0.3)
            rr = {"reef": PAL["rock"], "kelp": PAL["rock"], "slope": ramp("#6e6886", dark=0.28), "abyss": ramp("#403a5c", dark=0.3),
                  "vents": ramp("#3a2c34", dark=0.3)}[b]
            paint_rock(cv, rx, base, rw, rh, np.random.default_rng(rx), rr, top, xs_all)
        rg = cv.a
        rgba[rg, :3] = np.clip(cv.rgb[rg], 0, 255).astype(np.uint8)
        rgba[rg, 3] = 255
        # contact shadow on the ground right beside the rock bases
        Image.fromarray(rgba, "RGBA").save(os.path.join(out_dir, f"back_{ci // CHUNK:02d}.png"), optimize=True)
        # front strip: the lip of the ground + small surface details
        fy0 = int(ctop.min()) - FRONT_UP
        fy1 = int(ctop.max()) + LIP + 1
        fh = fy1 - fy0
        frows = np.arange(fy0, fy1)[:, None] + np.zeros((1, cx1 - cx0), dtype=int)
        fdepth = frows - ctop[None, :]
        front = np.zeros((fh, cx1 - cx0, 4), dtype=np.uint8)
        sel = (fdepth >= 0) & (fdepth < LIP)
        # copy the same ground colours for the lip rows
        src_rows = frows - y0
        valid = sel & (src_rows >= 0) & (src_rows < hh)
        ys, xs = np.nonzero(valid)
        front[ys, xs, :3] = rgba[src_rows[ys, xs], xs, :3]
        front[ys, xs, 3] = 255
        # rocks overlapping the lip stay behind (they belong to the back layer)
        paint_details(front, cols, ctop, fy0, slope[cx0:cx1], site_mask[cx0:cx1])
        Image.fromarray(front, "RGBA").save(os.path.join(out_dir, f"front_{ci // CHUNK:02d}.png"), optimize=True)
        chunks.append(dict(x=cx0, y=y0, w=cx1 - cx0, h=hh, fy=fy0, fh=fh))
    sites = {}
    for kind, sx, hw in SITES:
        sites.setdefault(kind, []).append(sx)
    data = dict(step=STEP, width=W, heights=[round(float(v), 1) for v in heights[::STEP]], chunks=chunks,
                sites=sites, rocks=[[int(r[0]), int(r[1])] for r in rocks], deep="#%02x%02x%02x" % DEEP,
                chunk_w=CHUNK)
    menu_strip().save(os.path.join(out_dir, "menu_strip.png"), optimize=True)
    with open(meta_path, "w") as fh:
        json.dump(data, fh, separators=(",", ":"))
    return data


def menu_strip(w=320, h=64):
    """Seamless reef floor strip for the main menu (periodic heights)."""
    xs = np.arange(w)
    hts = 16.0 + 4.0 * np.sin(xs / w * math.tau) + 2.0 * np.sin(xs / w * 2 * math.tau + 1.0)
    top = np.round(hts).astype(int)
    rows = np.arange(h)[:, None] + np.zeros((1, w), dtype=int)
    colr = ground_colors(xs + 300, rows, top, np.gradient(hts))
    rgba = np.zeros((h, w, 4), dtype=np.uint8)
    rgba[..., :3] = np.clip(colr, 0, 255).astype(np.uint8)
    rgba[..., 3] = np.where(rows >= top[None, :], 255, 0)
    paint_details(rgba, xs + 300, top, 0, np.gradient(hts), np.zeros(w, dtype=bool))
    return Image.fromarray(rgba, "RGBA")


def paint_details(front, cols, ctop, fy0, slope, near_site):
    """Pebbles, shells, rubble, tufts and glowing specks resting on the surface."""
    fh, cw = front.shape[:2]
    rng = np.random.default_rng(int(cols[0]) + 5)
    weights = biome_weights(cols.astype(float))
    for i in range(cw):
        if abs(slope[i]) > 1.1:
            continue
        b = max(weights, key=lambda k: weights[k][i])
        r = rng.random()
        yy = ctop[i] - fy0  # surface row inside the strip
        dens = {"reef": 0.075, "kelp": 0.06, "slope": 0.03, "abyss": 0.05, "vents": 0.08}[b]
        if r > dens:
            continue
        kind = rng.choice({"reef": ["pebble", "rubble", "rubble", "shell", "tuft"],
                           "kelp": ["pebble", "pebble", "tuft", "tuft", "shell"],
                           "slope": ["pebble", "pebble", "rubble"],
                           "abyss": ["pebble", "speck", "speck", "mat"],
                           "vents": ["pebble", "speck", "speck", "mat", "speck"]}[b])
        _detail(front, i, yy, kind, b, rng)


def _put(front, x, y, c):
    fh, cw = front.shape[:2]
    if 0 <= x < cw and 0 <= y < fh:
        front[y, x, :3] = c
        front[y, x, 3] = 255


def _detail(front, i, yy, kind, biome, rng):
    if kind == "pebble":
        pr = {"abyss": ramp("#4a4466", dark=0.3), "slope": ramp("#8a82a0", dark=0.3),
              "vents": ramp("#3e3038", dark=0.3)}.get(biome, ramp("#a0907c", dark=0.3))
        w = int(rng.integers(2, 5))
        for dx in range(w):
            _put(front, i + dx, yy - 1, pr[4 if dx < w - 1 else 3])
            _put(front, i + dx, yy, pr[2])
        if w >= 3:
            _put(front, i + 1, yy - 2, pr[5])
            _put(front, i, yy - 1, pr[5])
    elif kind == "rubble":
        rr = PAL[rng.choice(["coral", "pink", "bone", "orange"])]
        _put(front, i, yy - 1, rr[5])
        _put(front, i + 1, yy - 1, rr[4])
        _put(front, i + 1, yy - 2, rr[5])
        _put(front, i + 2, yy - 1, rr[3])
    elif kind == "shell":
        sr = PAL[rng.choice(["bone", "pink", "sandy"])]
        for dx, dy, t in ((0, -1, 4), (1, -1, 5), (2, -1, 4), (1, -2, 5), (0, 0, 2), (1, 0, 3), (2, 0, 2)):
            _put(front, i + dx, yy + dy, sr[t])
    elif kind == "tuft":
        gr = PAL[rng.choice(["moss", "kelp"])]
        n = int(rng.integers(2, 4))
        for k in range(n):
            hgt = int(rng.integers(2, 6))
            lean = rng.choice([-1, 0, 1])
            for s in range(hgt):
                _put(front, i + k * 2 + (lean if s > hgt // 2 else 0), yy - 1 - s, gr[5 if s == hgt - 1 else 3])
    elif kind == "speck":
        g = PAL[rng.choice(["orange", "volt"] if biome == "vents" else ["glow", "violet"])]
        _put(front, i, yy - 1, g[6])
    elif kind == "mat":
        m = PAL["volt"]
        w = int(rng.integers(3, 7))
        for dx in range(w):
            _put(front, i + dx, yy - 1, m[5] if (dx % 2) else m[4])


if __name__ == "__main__":
    here = os.path.dirname(os.path.abspath(__file__))
    root = os.path.normpath(os.path.join(here, "..", ".."))
    d = build(os.path.join(root, "assets", "art", "terrain"), os.path.join(root, "assets", "art", "terrain.json"))
    print(len(d["chunks"]), "chunks")
