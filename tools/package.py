#!/usr/bin/env python3
"""Copy a video's Godot project from ludo-videos into samples/<slug>, cleaned, and check it can be shared.

    python3 tools/package.py <ludo-videos project dir> <slug> [--video <youtube id>] [--dry-run]

Leaves out the editor cache (.godot/), capture scripts, raw and backup files. Refuses to package when a check fails:
- a font that is not on FONTS_OK (Georgia, Arial and other system fonts cannot be redistributed);
- a file over 50 MB (GitHub warns at 50, refuses at 100);
- a leftover the video pipeline made (cap*.sh, *_raw.*, *.txt notes).
Lists art or sound no file names outright (names built in code show up too), so unused takes do not ship.
Then zips the result to dist/<slug>.zip for itch.io.
"""
import argparse, re, shutil, sys, zipfile
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SKIP_DIRS = {".godot", "cap", "checks", "renders", "__pycache__"}
SKIP_FILE = re.compile(r"(^cap.*\.sh$|_raw\.|\.bak$|\.orig$|\.txt$|^\.DS_Store$)")
FONTS_OK = set()  # file names of fonts under the SIL OFL or another licence that allows redistribution, checked by hand
MAX_BYTES = 50 * 1024 * 1024
ASSET_EXT = {".png", ".jpg", ".webp", ".wav", ".ogg", ".mp3", ".glb", ".ttf", ".otf"}


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("src")
    ap.add_argument("slug")
    ap.add_argument("--video", default="")
    ap.add_argument("--dry-run", action="store_true")
    a = ap.parse_args()
    src = Path(a.src).resolve()
    if not (src / "project.godot").exists():
        sys.exit(f"{src} has no project.godot")

    keep, skipped, errors = [], [], []
    for p in sorted(src.rglob("*")):
        rel = p.relative_to(src)
        if any(part in SKIP_DIRS for part in rel.parts) or not p.is_file():
            continue
        if SKIP_FILE.search(p.name):
            skipped.append(rel)
            continue
        if p.suffix.lower() in {".ttf", ".otf"} and p.name not in FONTS_OK:
            errors.append(f"font {rel}: not on FONTS_OK (swap it for an OFL font, then add it there)")
        if p.stat().st_size > MAX_BYTES:
            errors.append(f"{rel}: {p.stat().st_size // 2**20} MB, over 50 MB")
        keep.append(rel)

    text = "\n".join((src / r).read_text(errors="ignore") for r in keep if r.suffix in {".gd", ".tscn", ".tres", ".godot", ".gdshader"})
    unused = [r for r in keep if r.suffix.lower() in ASSET_EXT and r.name not in text and r.stem not in text]

    print(f"{src.name} -> samples/{a.slug}: {len(keep)} files kept, {len(skipped)} left out")
    for r in skipped:
        print(f"  left out  {r}")
    for r in unused:
        print(f"  CHECK     {r} (no file references it by name: built in code, or an unused take to delete)")
    for e in errors:
        print(f"  ERROR     {e}")
    if errors:
        sys.exit(1)
    if a.dry_run:
        return

    dst = ROOT / "samples" / a.slug
    if dst.exists():
        shutil.rmtree(dst)
    for r in keep:
        (dst / r).parent.mkdir(parents=True, exist_ok=True)
        shutil.copy2(src / r, dst / r)
    (ROOT / "dist").mkdir(exist_ok=True)
    with zipfile.ZipFile(ROOT / "dist" / f"{a.slug}.zip", "w", zipfile.ZIP_DEFLATED) as z:
        for f in sorted(dst.rglob("*")):
            if f.is_file():
                z.write(f, Path(a.slug) / f.relative_to(dst))
    print(f"wrote samples/{a.slug} and dist/{a.slug}.zip; write samples/{a.slug}/README.md")


if __name__ == "__main__":
    main()
