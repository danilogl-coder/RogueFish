"""Shared helpers for marketing assets (key art, GIFs, videos).

Everything is composed at the game's native pixel resolution and upscaled by
an integer factor with nearest neighbour, so pixels stay crisp."""
from __future__ import annotations

import json
import math
import os
import random
import sys

from PIL import Image, ImageDraw, ImageFilter, ImageFont

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", ".."))
sys.path.insert(0, os.path.join(ROOT, "tools", "art"))
ART = os.path.join(ROOT, "assets", "art")
META = json.load(open(os.path.join(ART, "art_meta.json")))
FONT = os.path.join(ROOT, "assets", "fonts", "PressStart2P-Regular.ttf")
FONT2 = os.path.join(ROOT, "assets", "fonts", "PixelifySans-SemiBold.ttf")
OUT = os.path.join(ROOT, "docs", "marketing")
GOLD, CYAN, NAVY = (255, 200, 70), (200, 250, 255), (6, 14, 30)


def sheet_frame(name: str, frame: int = 0, row: int = 0) -> Image.Image:
    """One frame of a creature/env sheet (see art_meta.json 'sheets')."""
    m = META["sheets"][name]
    im = Image.open(os.path.join(ART, name + ".png")).convert("RGBA")
    w, h = m["w"], m["h"]
    return im.crop((frame * w, row * h, frame * w + w, row * h + h))


def player_frame(species: str, stage: int, frame: int = 0, layers=None) -> Image.Image:
    import player as PL
    m = META["player"][f"{species}_{stage}"]
    sh = Image.open(os.path.join(ART, "player", f"{species}_{stage}.png"))
    return PL.compose_frame(sh, m, layers or ["tail", "fins_back", "body", "fins_front"], frame)


def trim(im: Image.Image) -> Image.Image:
    b = im.getbbox()
    return im.crop(b) if b else im


def flip(im: Image.Image) -> Image.Image:
    return im.transpose(Image.FLIP_LEFT_RIGHT)


def up(im: Image.Image, k: int) -> Image.Image:
    return im.resize((im.width * k, im.height * k), Image.NEAREST)


def paste(dst: Image.Image, src: Image.Image, x: float, y: float, anchor="c") -> None:
    """Paste src centred (anchor c) or by its top-left (anchor tl)."""
    if anchor == "c":
        x, y = x - src.width / 2, y - src.height / 2
    dst.alpha_composite(src, (int(round(x)), int(round(y))))


def ocean(w: int, h: int, seed: int = 3, top=(46, 132, 178), bot=(5, 16, 38), rays=True) -> Image.Image:
    """Pixel ocean backdrop: banded gradient, light rays and marine snow."""
    im = Image.new("RGBA", (w, h))
    d = ImageDraw.Draw(im)
    bands = 14
    for y in range(h):
        k = min(1.0, round(y / h * bands) / bands)
        d.line([(0, y), (w, y)], fill=tuple(int(top[i] * (1 - k) + bot[i] * k) for i in range(3)) + (255,))
    rnd = random.Random(seed)
    if rays:
        ray = Image.new("RGBA", (w, h))
        rd = ImageDraw.Draw(ray)
        for _ in range(max(3, w // 90)):
            x = rnd.randint(-w // 4, w)
            ww = rnd.randint(w // 60, w // 25)
            rd.polygon([(x, 0), (x + ww, 0), (x + ww * 3 - h // 2, h), (x - h // 2, h)], fill=(190, 245, 255, 22))
        im.alpha_composite(ray)
    for _ in range(w * h // 900):
        x, y = rnd.randrange(w), rnd.randrange(h)
        im.putpixel((x, y), (200, 240, 255, rnd.choice([60, 90, 140])))
    return im


def bubbles(im: Image.Image, n: int, seed: int = 5, area=None) -> None:
    rnd = random.Random(seed)
    d = ImageDraw.Draw(im)
    x0, y0, x1, y1 = area or (0, 0, im.width, im.height)
    for _ in range(n):
        x, y = rnd.randint(x0, x1), rnd.randint(y0, y1)
        r = rnd.choice([1, 1, 2, 2, 3])
        if r == 1:
            im.putpixel((min(x, im.width - 1), min(y, im.height - 1)), (220, 250, 255, 200))
        else:
            d.ellipse([x - r, y - r, x + r, y + r], outline=(210, 250, 255, 170))
            im.putpixel((x - r + 1, y - r + 1), (255, 255, 255, 230))


def seabed(im: Image.Image, y: int, seed: int = 9) -> None:
    """Sand dunes with a lit top edge, pebbles and a few plants."""
    rnd = random.Random(seed)
    d = ImageDraw.Draw(im)
    w, h = im.size
    for x in range(w):
        hh = int(y + 5 * math.sin(x / 23.0) + 3 * math.sin(x / 7.3 + 1))
        d.line([(x, hh), (x, h)], fill=(150, 116, 82, 255))
        d.line([(x, hh), (x, hh + 1)], fill=(222, 196, 146, 255))
        d.line([(x, hh + 2), (x, hh + 3)], fill=(190, 156, 110, 255))
        if rnd.random() < 0.04:
            d.point((x, hh + rnd.randint(5, max(6, h - hh - 1))), fill=(110, 84, 64, 255))
    for _ in range(w // 40):
        x = rnd.randrange(w)
        props = ["env/coral_fan", "env/coral_branch", "env/anemone", "env/seagrass"]
        name = rnd.choice(props)
        if name in META["sheets"]:
            p = sheet_frame(name, 0)
            paste(im, p, x, y - p.height // 2 + 4)


def text(im: Image.Image, s: str, x: float, y: float, size: int, col=GOLD, shadow=NAVY, font=FONT, anchor="c",
         outline=0) -> None:
    d = ImageDraw.Draw(im)
    f = ImageFont.truetype(font, size)
    w = d.textlength(s, font=f)
    if anchor == "c":
        x -= w / 2
    if outline:
        for dx in range(-outline, outline + 1):
            for dy in range(-outline, outline + 1):
                if dx or dy:
                    d.text((x + dx, y + dy), s, font=f, fill=shadow)
    else:
        d.text((x + max(1, size // 8), y + max(1, size // 8)), s, font=f, fill=shadow)
    d.text((x, y), s, font=f, fill=col)


def logo(width: int) -> Image.Image:
    lg = Image.open(os.path.join(ART, "ui", "logo.png")).convert("RGBA")
    k = max(1, round(width / lg.width))
    return up(trim(lg), k) if k > 1 else trim(lg)
