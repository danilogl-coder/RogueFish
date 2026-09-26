#!/usr/bin/env python3
"""Generates every sprite used by Rogue Fish.

Usage:  python3 tools/art/generate_all.py
Output: assets/art/** plus assets/art/art_meta.json (frame sizes, anchors).
Requires Pillow.
"""
from __future__ import annotations

import json
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
sys.path.insert(0, HERE)

from PIL import Image  # noqa: E402
import pixel  # noqa: E402
import player  # noqa: E402
import creatures  # noqa: E402
import env  # noqa: E402
import fx  # noqa: E402
import ui  # noqa: E402

ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
OUT = os.path.join(ROOT, "assets", "art")

# frames per sheet for everything that is not a single image
FRAME_COUNT = {
    # creatures
    "puffer_big": 4, "kraken_segment": 4, "leviathan_segment": 4,
    # env
    "surface": 4, "anemone": 4, "seagrass": 4, "kelp": 4, "plankton": 4, "thicket": 2,
    "chest": 2, "clam": 3,
    # fx
    "xp_small": 4, "xp_mid": 4, "xp_big": 4, "xp_huge": 4, "pearl": 4, "magnet": 4,
    "bubble": 2, "bubble_big": 2, "torpedo": 2, "ink_cloud": 4, "poison_cloud": 4, "whirlpool": 4,
    "explosion": 6, "explosion_toxic": 6, "hit_spark": 4, "light_orb": 2, "volt_ball": 2, "particles": 8,
}


def save(img: Image.Image, rel: str):
    path = os.path.join(OUT, rel)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img.save(path, optimize=True)


def main():
    only = set(sys.argv[1:])
    meta = {"player": {}, "sheets": {}, "icons": {}}

    def want(group):
        return not only or group in only

    if want("player"):
        for species in player.SPECIES:
            for stage in range(len(player.STAGE_LEN)):
                img, m = player.render_atlas(species, stage)
                save(img, f"player/{species}_{stage}.png")
                meta["player"][f"{species}_{stage}"] = m
                print("player", species, stage, img.size)

    groups = [("creatures", creatures.ALL, creatures.NF), ("env", env.ALL, 1), ("fx", fx.ALL, 1), ("ui", ui.ALL, 1)]
    for gname, table, default_frames in groups:
        if not want(gname):
            continue
        for name, fn in table.items():
            img = fn()
            n = FRAME_COUNT.get(name, default_frames)
            save(img, f"{gname}/{name}.png")
            meta["sheets"][f"{gname}/{name}"] = {"frames": n, "w": img.size[0] // n, "h": img.size[1]}
            print(gname, name, img.size)

    if want("icons"):
        atlas, names = ui.icon_atlas()
        save(atlas, "ui/icons.png")
        meta["icons"] = {n: i for i, n in enumerate(names)}

    if want("appicon"):
        make_app_icons()

    meta_path = os.path.join(OUT, "art_meta.json")
    if only and os.path.exists(meta_path):
        with open(meta_path) as fh:
            old = json.load(fh)
        for k in ("player", "sheets", "icons"):
            old.setdefault(k, {}).update(meta[k])
        meta = old
    with open(meta_path, "w") as fh:
        json.dump(meta, fh, indent=1, sort_keys=True)


def make_app_icons():
    """Launcher / store icons: legacy 192, adaptive 432 fg+bg, store 512."""
    import math
    L = player.STAGE_LEN[2]
    fw, fh = player.canvas_size(L)
    fish = None
    for ly in ["tail", "fins_back", "body", "skin_glow", "head_lure", "fins_front"]:
        row = player.render_layer("dourado", 2, ly).crop((0, 0, fw, fh))
        fish = row if fish is None else Image.alpha_composite(fish, row)
    fish = fish.crop(fish.getbbox())

    def background(size):
        img = Image.new("RGBA", (size, size))
        px = img.load()
        c1, c2 = (42, 134, 176), (12, 40, 80)
        for y in range(size):
            q = round(y / size * 6) / 6
            c = tuple(int(c1[i] + (c2[i] - c1[i]) * q) for i in range(3)) + (255,)
            for x in range(size):
                px[x, y] = c
        for bx, by, br in ((0.2, 0.26, 0.05), (0.8, 0.22, 0.035), (0.74, 0.78, 0.045), (0.22, 0.76, 0.03)):
            cx, cy, r = bx * size, by * size, br * size
            w = max(1.0, size / 150)
            for y in range(int(cy - r - 3), int(cy + r + 3)):
                for x in range(int(cx - r - 3), int(cx + r + 3)):
                    if abs(math.hypot(x - cx, y - cy) - r) < w:
                        px[x, y] = (184, 255, 244, 255)
        return img

    def put_fish(img, fit):
        k = max(1, int(fit // fish.size[0]))
        f = pixel.scale(fish, k)
        img.alpha_composite(f, ((img.size[0] - f.size[0]) // 2, (img.size[1] - f.size[1]) // 2))
        return img

    save(put_fish(background(192), 170), "../icon/icon_192.png")
    save(put_fish(Image.new("RGBA", (432, 432), (0, 0, 0, 0)), 280), "../icon/icon_fg_432.png")
    save(background(432), "../icon/icon_bg_432.png")
    save(put_fish(background(512), 440), "../icon/icon_512.png")


if __name__ == "__main__":
    main()
