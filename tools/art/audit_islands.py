"""Finds 'floating' pixels: tiny opaque islands detached from the rest of a
sprite frame (8-connectivity). Usage: python3 audit_islands.py [max_size]"""
import json, math, os, sys
import numpy as np
from PIL import Image
from scipy import ndimage

ROOT = os.path.join(os.path.dirname(__file__), "..", "..", "assets", "art")
MAX = int(sys.argv[1]) if len(sys.argv) > 1 else 4


def frames_of(img, w, h):
    a = np.array(img)[:, :, 3] > 0
    for fy in range(0, a.shape[0] - h + 1, h):
        for fx in range(0, a.shape[1] - w + 1, w):
            yield (fx, fy), a[fy:fy + h, fx:fx + w]


def islands(mask):
    lab, n = ndimage.label(mask, structure=np.ones((3, 3)))
    if n <= 1:
        return []
    sizes = ndimage.sum(mask, lab, range(1, n + 1))
    big = sizes.max()
    return [int(s) for s in sizes if s <= MAX and s < big]


def main():
    meta = json.load(open(os.path.join(ROOT, "art_meta.json")))
    report = []
    for key, m in meta["sheets"].items():
        path = os.path.join(ROOT, key + ".png")
        if not os.path.exists(path):
            continue
        img = Image.open(path).convert("RGBA")
        for (fx, fy), fr in frames_of(img, m["w"], m["h"]):
            isl = islands(fr)
            if isl:
                report.append((key, fx // m["w"], fy // m["h"], isl))
    for sp, pm in meta.get("player", {}).items():
        path = os.path.join(ROOT, "player", sp + ".png")
        if not os.path.exists(path):
            continue
        img = Image.open(path).convert("RGBA")
        for (fx, fy), fr in frames_of(img, pm["frame_w"], pm["frame_h"]):
            isl = islands(fr)
            if isl:
                report.append(("player/" + sp, fx // pm["frame_w"], fy // pm["frame_h"], isl))
    by = {}
    for k, x, y, isl in report:
        by.setdefault(k, []).append((x, y, isl))
    for k, v in sorted(by.items()):
        print(f"{k}: {len(v)} frames  e.g. {v[:3]}")
    print("total sheets with islands:", len(by))


if __name__ == "__main__":
    main()
