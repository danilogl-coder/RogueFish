"""Pixel tidy pass applied to every animation frame before saving.

Small blobs (<= 12 px) that are detached from the sprite, or touch it only
through a diagonal corner, read as "loose" pixels while animating (e.g. the tip
of a shark's caudal fin, whose thin tip vanished and left only its outline).
When such a blob sits within a few pixels of the body it gets re-attached with
a 4-connected line coloured like the darker pixel (usually the outline)."""
import numpy as np
from PIL import Image
from scipy import ndimage

N4 = np.array([[0, 1, 0], [1, 1, 1], [0, 1, 0]])
MAX_BLOB = 12
MAX_GAP = 4.5


def _lum(c):
    return 0.3 * float(c[0]) + 0.59 * float(c[1]) + 0.11 * float(c[2])


def _line4(y0, x0, y1, x1):
    """4-connected pixel path from (y0, x0) to (y1, x1)."""
    pts = []
    y, x = y0, x0
    while (y, x) != (y1, x1):
        dy, dx = y1 - y, x1 - x
        if abs(dx) >= abs(dy):
            x += 1 if dx > 0 else -1
        else:
            y += 1 if dy > 0 else -1
        pts.append((y, x))
    return pts[:-1]


def bridge_frame(fr, context=None):
    """context: optional bool mask of other layers drawn with this one (the
    player's body + tail). Blobs are judged on the union, but only this
    layer gets painted."""
    for _ in range(6):
        own = fr[:, :, 3] > 0
        a = own | context if context is not None else own
        lab, n = ndimage.label(a, structure=N4)
        if n <= 1:
            return fr
        sizes = ndimage.sum(a, lab, range(1, n + 1))
        main = int(np.argmax(sizes)) + 1
        dist, (iy, ix) = ndimage.distance_transform_edt(lab != main, return_indices=True)
        changed = False
        for i in range(1, n + 1):
            if i == main or sizes[i - 1] > MAX_BLOB:
                continue
            ys, xs = np.nonzero((lab == i) & own)
            if len(ys) == 0:
                continue
            k = int(np.argmin(dist[ys, xs]))
            y, x = int(ys[k]), int(xs[k])
            if dist[y, x] > MAX_GAP:
                continue
            ty, tx = int(iy[y, x]), int(ix[y, x])
            src = fr[y, x] if fr[ty, tx, 3] == 0 or _lum(fr[y, x]) < _lum(fr[ty, tx]) else fr[ty, tx]
            for py, px in _line4(y, x, ty, tx):
                if fr[py, px, 3] == 0:
                    fr[py, px] = src
                    changed = True
        if not changed:
            return fr
    return fr


def bridge_sheet(img, fw, fh):
    arr = np.array(img.convert("RGBA"))
    H, W = arr.shape[:2]
    for y in range(0, H - fh + 1, fh):
        for x in range(0, W - fw + 1, fw):
            arr[y:y + fh, x:x + fw] = bridge_frame(arr[y:y + fh, x:x + fw].copy())
    out = Image.fromarray(arr, "RGBA")
    out.info.update(img.info)
    return out


def bridge_player_atlas(img, fw, fh, layers):
    """Player atlases hold one layer per row. Each layer is tidied against the
    body + tail silhouette it is drawn with, so a loose fin tip gets attached
    to the fish, but two separate fins in one layer are never joined."""
    arr = np.array(img.convert("RGBA"))
    body_r = layers.index("body")
    tail_r = layers.index("tail")
    cols = arr.shape[1] // fw
    for c in range(cols):
        def cell(r):
            return arr[r * fh:(r + 1) * fh, c * fw:(c + 1) * fw]
        body = cell(body_r)[:, :, 3] > 0
        tail = cell(tail_r)[:, :, 3] > 0
        for r, name in enumerate(layers):
            ctx = tail if name.startswith("body") else (body if name.startswith("tail") else body | tail)
            arr[r * fh:(r + 1) * fh, c * fw:(c + 1) * fw] = bridge_frame(cell(r).copy(), ctx)
    out = Image.fromarray(arr, "RGBA")
    out.info.update(img.info)
    return out
