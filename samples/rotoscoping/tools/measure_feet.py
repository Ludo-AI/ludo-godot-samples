#!/usr/bin/env python3
"""Measure where the planted boot sits in every cell of a jump sheet, so the game can keep the feet from sliding.

    python3 tools/measure_feet.py art/knight_jump.png --grid 7x7 --takeoff 15 --landing 34 [--out data/knight_feet.json]

Needs Python 3 with Pillow and NumPy (pip install pillow numpy).

Transfer Motion centres the character in every cell, so the feet drift inside the cells while he crouches, pushes off
and lands. For each cell it records the lowest opaque row (`bottom`), the left and right ends of the lowest 4 px row
(`heel`, `toe`, for a character facing right) and the body's centre (`centroid_x`, all opaque pixels). For the ground
frames before the jump (0 to --takeoff) and after it (--landing to the end) it tracks the planted boot: the lowest 28
rows of each frame are matched to the previous frame's by the sideways shift with the best overlap, and the shifts
add up to `boot`, the boot's x in the cell. knight.gd draws each ground frame so that `boot` stays on one spot.
Coordinates are cell pixels from the cell's left edge.
"""
import argparse, json
import numpy as np
from PIL import Image

BOOT = 28


def boot(a):
    b = int(np.where(a.any(1))[0].max())
    return a[b - BOOT + 1:b + 1]


def travel(p, q):
    """How far the boot moved (cell px, + = right) from frame p to frame q, and the overlap it found."""
    bp, bq = boot(p), boot(q)
    best = (-1.0, 0)
    for dx in range(-48, 49):
        s = np.roll(bq, dx, axis=1)
        if dx > 0:
            s[:, :dx] = False
        elif dx < 0:
            s[:, dx:] = False
        best = max(best, ((bp & s).sum() / max(1, (bp | s).sum()), -dx))
    return best[1], round(float(best[0]), 3)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("sheet")
    ap.add_argument("--grid", default="7x7", help="columns x rows")
    ap.add_argument("--frames", type=int, help="number of frames (default: all cells)")
    ap.add_argument("--takeoff", type=int, required=True, help="last frame with a foot on the ground before the jump")
    ap.add_argument("--landing", type=int, required=True, help="first frame back on the ground")
    ap.add_argument("--out", default="data/knight_feet.json")
    a = ap.parse_args()
    cols, rows = (int(v) for v in a.grid.lower().split("x"))
    img = np.asarray(Image.open(a.sheet).convert("RGBA"))[:, :, 3] > 0
    cw, ch = img.shape[1] // cols, img.shape[0] // rows
    n = a.frames or cols * rows
    A = [img[(i // cols) * ch:(i // cols + 1) * ch, (i % cols) * cw:(i % cols + 1) * cw] for i in range(n)]
    F = []
    for i, c in enumerate(A):
        r = np.where(c.any(1))[0]
        b = int(r.max())
        low = np.where(c[b - 3:b + 1].any(0))[0]
        ys, xs = np.where(c)
        F.append({"frame": i, "bottom": b, "heel": int(low.min()), "toe": int(low.max()),
                  "centroid_x": round(float(xs.mean()), 2)})
    for chain in (range(0, a.takeoff + 1), range(a.landing, n)):
        chain = list(chain)
        x = float(F[chain[0]]["heel"])
        F[chain[0]].update(boot=x, boot_iou=1.0)
        for p, q in zip(chain, chain[1:]):
            d, iou = travel(A[p], A[q])
            x += d
            F[q].update(boot=x, boot_iou=iou)
    json.dump({"source": a.sheet, "grid": a.grid, "takeoff_frames": list(range(0, a.takeoff + 1)),
               "air_frames": list(range(a.takeoff + 1, a.landing)), "landing_frames": list(range(a.landing, n)),
               "note": "boot = the planted boot's x in the cell on ground frames; keep it on one spot", "frames": F},
              open(a.out, "w"), indent=1)
    print(a.out, "boot before take-off", [F[i]["boot"] for i in range(0, a.takeoff + 1)],
          "after landing", [F[i]["boot"] for i in range(a.landing, n)])


if __name__ == "__main__":
    main()
