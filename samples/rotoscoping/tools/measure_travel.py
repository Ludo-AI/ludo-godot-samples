#!/usr/bin/env python3
"""Measure how far the real person travels during the jump, frame by frame (root motion from the reference).

    python3 tools/measure_travel.py <side-view clip.mp4> [--out data/travel.json] [--threshold 45] [--facing right]

Needs ffmpeg on the PATH, plus Python 3 with Pillow and NumPy (pip install pillow numpy).

How it works: the clip is a side view on a plain light background. Every frame is read, the person's dark pixels
are found with a brightness threshold (the black bodysuit is darker than the grey floor mat, so the mat drops out
on its own), and for each frame it records (in clip pixels, corrected for camera pan: if the camera follows the
person, the texture of the floor under him slides the other way, and the script adds that slide back)
  - cx:    the horizontal centre of those pixels (the body's centre),
  - foot:  the horizontal centre of the lowest 6 % of them (the ankles),
  - floor: the lowest dark row (the bottom of the feet),
  - top:   the highest dark row (head or raised hands).
Take-off is the first frame whose floor lifts more than 2 % of the body height off the ground, landing the first
frame after that whose floor is back down. The body height is the standing height in the first frame.

It writes JSON with every frame, the take-off and landing times, the travel in body heights and `air_curve`:
the body centre during the air time, normalised to 0 at take-off and 1 at landing, 21 samples over the air time.
The game (main.gd) moves the knight with that curve while his air frames play, scaled to `travel_heights` times
his own height. Your own clip: film 3 to 4 s, side view, whole body, steady camera, plain background, dark
clothes (or pass --invert for light clothes on a dark background), then run this on it.
"""
import argparse, json, subprocess, sys, tempfile
from pathlib import Path

import numpy as np
from PIL import Image


def frames(clip, tmp):
    subprocess.run(["ffmpeg", "-loglevel", "error", "-y", "-i", str(clip), str(Path(tmp) / "f_%04d.png")], check=True)
    fps = subprocess.run(["ffprobe", "-v", "error", "-select_streams", "v:0", "-show_entries", "stream=r_frame_rate",
                          "-of", "csv=p=0", str(clip)], capture_output=True, text=True, check=True).stdout.strip()
    num, den = (fps.split("/") + ["1"])[:2]
    return sorted(Path(tmp).glob("f_*.png")), float(num) / float(den)


def floor_band(lum):
    """Rows of a textured floor (mat, boards, tarmac) under the person: most of the row is mid-grey, not background."""
    mid = ((lum > 30) & (lum < 200)).mean(1)
    rows = np.flatnonzero(mid > 0.8)
    return (int(rows.min()) + 8, int(rows.max()) - 2) if len(rows) > 20 else None


def pan_step(prev, cur, band, skip, max_shift=30):
    """How far the camera moved right between two frames, from the floor texture (0 if the floor is plain).
    Columns within 90 px of the person's feet are left out, so his own motion does not count."""
    y0, y1 = band
    a = prev[y0:y1].astype(float)
    b = cur[y0:y1].astype(float)
    a = a - np.convolve(a.mean(0), np.ones(31) / 31, "same")  # keep the marks, drop the lighting
    b = b - np.convolve(b.mean(0), np.ones(31) / 31, "same")
    w = a.shape[1]
    keep = np.ones(w, bool)
    for x in skip:
        keep[max(0, int(x) - 90):int(x) + 90] = False
    keep[:max_shift] = keep[w - max_shift:] = False
    scores = []
    for s in range(-max_shift, max_shift + 1):
        cols = np.flatnonzero(keep)
        cols = cols[(cols + s >= 0) & (cols + s < w)]
        scores.append(-np.mean((a[:, cols] - b[:, cols + s]) ** 2))  # content at x moves to x + s
    scores = np.array(scores)
    k = int(scores.argmax())
    if scores.max() - np.median(scores) < 1e-6:
        return 0.0
    off = 0.0
    if 0 < k < len(scores) - 1:  # parabola through the peak for a sub-pixel shift
        l, c, r = scores[k - 1:k + 2]
        den = l - 2 * c + r
        off = 0.5 * (l - r) / den if den else 0.0
    return -(k - max_shift + off)  # the scene moved by s, so the camera moved by -s


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("clip")
    ap.add_argument("--out", default="data/travel.json")
    ap.add_argument("--threshold", type=float, default=45, help="pixels darker than this (0-255) are the person")
    ap.add_argument("--invert", action="store_true", help="light person on a dark background")
    ap.add_argument("--no-pan", action="store_true", help="the camera is locked off: skip the pan tracking")
    ap.add_argument("--facing", default="right", choices=["right", "left"], help="the way the person jumps")
    a = ap.parse_args()

    rows = []
    with tempfile.TemporaryDirectory() as tmp:
        paths, fps = frames(a.clip, tmp)
        pan, prev, band = 0.0, None, None
        for i, p in enumerate(paths):
            lum = np.asarray(Image.open(p).convert("L")).astype(float)
            if band is None:
                band = floor_band(lum)
            mask = (lum > 255 - a.threshold) if a.invert else (lum < a.threshold)
            ys, xs = np.nonzero(mask)
            if len(xs) < 50:
                continue
            low = ys >= np.percentile(ys, 94)
            if prev is not None and band and not a.no_pan:
                pan += pan_step(prev, lum, band, [xs[low].mean(), rows[-1]["foot"] - rows[-1]["pan"] if rows else 0])
            prev = lum
            # world x = screen x + how far the camera has panned since the first frame
            rows.append({"t": round(i / fps, 4), "pan": pan, "cx": float(xs.mean()) + pan,
                         "foot": float(xs[low].mean()) + pan, "floor": int(ys.max()), "top": int(ys.min())})
    if not rows:
        sys.exit("no person found: try another --threshold")
    sign = 1 if a.facing == "right" else -1
    ground = rows[0]["floor"]
    height = rows[0]["floor"] - rows[0]["top"]
    lift = 0.02 * height
    up = next(i for i, r in enumerate(rows) if ground - r["floor"] > lift)
    down = next(i for i in range(up + 1, len(rows)) if ground - rows[i]["floor"] <= lift)
    t0, t1 = rows[up - 1]["t"], rows[down]["t"]  # last frame on the ground, first frame back on it
    c0, c1 = rows[up - 1]["cx"], rows[down]["cx"]
    travel_px = sign * (rows[-1]["foot"] - rows[0]["foot"])
    air = []
    for k in range(21):
        t = t0 + (t1 - t0) * k / 20
        x = np.interp(t, [r["t"] for r in rows], [r["cx"] for r in rows])
        air.append(round(float((x - c0) / (c1 - c0)), 4))
    out = {
        "clip": Path(a.clip).name, "fps": fps, "frames": len(rows),
        "body_height_px": height,
        "takeoff_s": t0, "landing_s": t1, "air_s": round(t1 - t0, 4),
        "travel_px": round(travel_px, 1),
        "travel_heights": round(travel_px / height, 4),
        "air_travel_heights": round(sign * (c1 - c0) / height, 4),
        "air_curve": air,
        "per_frame": [{k: (round(v, 2) if isinstance(v, float) else v) for k, v in r.items()} for r in rows],
    }
    Path(a.out).parent.mkdir(parents=True, exist_ok=True)
    Path(a.out).write_text(json.dumps(out, indent=1))
    print(f"{out['clip']}: body {height} px, take-off {t0:.2f} s, landing {t1:.2f} s, air {t1 - t0:.2f} s")
    print(f"feet travel {travel_px:.0f} px = {out['travel_heights']:.2f} body heights "
          f"(body centre during the air time: {out['air_travel_heights']:.2f})")
    print("air curve:", " ".join(f"{v:.2f}" for v in air))


if __name__ == "__main__":
    main()
