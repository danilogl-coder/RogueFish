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
import critters  # noqa: E402
import fishes  # noqa: E402
import env  # noqa: E402
import fx  # noqa: E402
import ui  # noqa: E402
import props  # noqa: E402
import fx2  # noqa: E402
import terrain  # noqa: E402

ROOT = os.path.normpath(os.path.join(HERE, "..", ".."))
OUT = os.path.join(ROOT, "assets", "art")

# frames per sheet for everything that is not a single image
# (swim, action) frame split for animated creature sheets; the rest use 4 + 2
ANIM = dict(fishes.ANIM)
ANIM.update({"organ_heart": (4, 0), "organ_gland": (4, 0)})

FRAME_COUNT = {
    # creatures (fish sheets report their own counts through fishes.ANIM)
    "kraken_segment": 4, "leviathan_segment": 4,
    # env
    "surface": 4, "anemone": 4, "seagrass": 4, "kelp": 4, "plankton": 4, "thicket": 2,
    "chest": 2, "clam": 3, "tube_worms": 4, "glow_mushroom": 2,
    "detritus": 2, "boss_food": 4, "alpha_scale": 4, "phyto": 4,
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

    for name, (sw, act) in ANIM.items():
        FRAME_COUNT[name] = sw + act
    groups = [("creatures", {**critters.ALL, **fishes.ALL}, 6), ("env", {**env.ALL, **props.ALL}, 1),
              ("fx", {**fx.ALL, **fx2.ALL}, 1), ("ui", ui.ALL, 1)]
    for gname, table, default_frames in groups:
        if not want(gname):
            continue
        for name, fn in table.items():
            img = fn()
            n = FRAME_COUNT.get(name, default_frames)
            save(img, f"{gname}/{name}.png")
            rows = int(img.info.get("rows", 1))
            info = {"frames": n, "w": img.size[0] // -(-n // rows), "h": img.size[1] // rows}
            if rows > 1:
                info["rows"] = rows
            if gname == "creatures" and name not in ("kraken_segment", "leviathan_segment"):
                sw, act = ANIM.get(name, (4, 2))
                info.update(swim=sw, act=act)
            meta["sheets"][f"{gname}/{name}"] = info
            print(gname, name, img.size)

    if want("terrain"):
        d = terrain.build(os.path.join(OUT, "terrain"), os.path.join(OUT, "terrain.json"))
        print("terrain", len(d["chunks"]), "chunks")

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
            if k == "sheets":
                # drop stale sheets of regenerated groups
                for g in only:
                    for key in [key for key in old.get("sheets", {}) if key.startswith(g + "/")]:
                        del old["sheets"][key]
            old.setdefault(k, {}).update(meta[k])
        meta = old
    with open(meta_path, "w") as fh:
        json.dump(meta, fh, indent=1, sort_keys=True)


def make_app_icons():
    """Launcher / store icons: legacy 192, adaptive 432 fg+bg, store 512."""
    import math
    sheet, pmeta = player.render_atlas("dourado", 2)
    fish = player.compose_frame(sheet, pmeta, ["tail", "fins_back", "body+head_lure+skin_glow", "fins_front"], 0)
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
