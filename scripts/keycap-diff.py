#!/usr/bin/env python3
"""Compare a screenshot of our keyboard against the native iOS keyboard.

We chase sub-point differences in key caps, fills and label placement, which is
not something the eye converges on. This measures both screenshots the same way
and prints the deltas.

Usage:
  scripts/keycap-diff.py ours.png native.png

Capture protocol (both shots must be comparable, or the numbers are noise):
  1. Same device, same iOS build, same appearance (light or dark), same host app
     and text field. Portrait.
  2. Same keyboard page (e.g. the number page) with no key pressed and no
     candidate row populated.
  3. Full-screen screenshots, NOT cropped — cropping loses the common origin, so
     the chrome above and below the key block becomes unmeasurable.
  4. Run this once per appearance: the fills differ between light and dark.

Reported per image, with our value first:
  - row bands (cap top/bottom, cap height, row pitch, inter-row gap)
  - per-row key rects, gaps and edge padding
  - fills: keyboard background, input cap, function cap, drop shadow
  - label ink box per key and its offset from the cap centre (dx/dy) — a non-zero
    dx is the full-width-punctuation centring bug
  - corner profile (proxy for corner radius)

3x device pixels; divide by 3 for points.
"""

import sys

import numpy as np
from PIL import Image

# A key cap is well above the keyboard background (43/255) at any appearance we
# ship; 55 separates cap from background without clipping the drop shadow.
CAP_THRESHOLD = 55
# Labels are near-white on both light and dark caps.
INK_THRESHOLD = 170


def load(path):
    return np.asarray(Image.open(path).convert("L")).astype(int)


def row_bands(gray):
    """Vertical bands that contain a key row, as (top, bottom) inclusive."""
    counts = (gray > CAP_THRESHOLD).sum(axis=1)
    width = gray.shape[1]
    bands, start = [], None
    for y, count in enumerate(counts):
        if count > width * 0.12 and start is None:
            start = y
        elif count <= width * 0.12 and start is not None:
            bands.append((start, y - 1))
            start = None
    if start is not None:
        bands.append((start, len(counts) - 1))
    # Keep only the key rows. Every key row shares one cap height, so the modal
    # height among the tall bands identifies them — that drops the home indicator
    # (too short) plus our own toolbar and native's candidate row (both a
    # one-off height, and neither is a key row).
    tall = [b for b in bands if b[1] - b[0] >= 60]
    if not tall:
        return []
    heights = [b[1] - b[0] for b in tall]
    modal = max(set(heights), key=heights.count)
    return [b for b in tall if b[1] - b[0] == modal]


def key_rects(gray, band):
    """Horizontal extent of each cap in a row band, as (x0, x1) inclusive."""
    top, bottom = band
    strip = gray[top:bottom + 1] > CAP_THRESHOLD
    height = bottom - top + 1
    counts = strip.sum(axis=0)
    rects, start = [], None
    for x, count in enumerate(counts):
        if count > height * 0.5 and start is None:
            start = x
        elif count <= height * 0.5 and start is not None:
            rects.append((start, x - 1))
            start = None
    if start is not None:
        rects.append((start, len(counts) - 1))
    return rects


def ink_box(gray, band, rect):
    """Label ink bounding box within a cap, or None for a blank cap."""
    top, bottom = band
    x0, x1 = rect
    mask = gray[top:bottom + 1, x0:x1 + 1] > INK_THRESHOLD
    ys, xs = np.nonzero(mask)
    if len(ys) == 0:
        return None
    return xs.min(), xs.max(), ys.min(), ys.max()


def fills(gray, bands):
    """Background, the two cap fills, and the drop shadow, as 0-255 levels."""
    background = int(np.bincount(gray.ravel(), minlength=256).argmax())
    caps = []
    for band in bands:
        for rect in key_rects(gray, band):
            # Sample inside the top-left corner, away from any label ink.
            patch = gray[band[0] + 6:band[0] + 16, rect[0] + 6:rect[0] + 16]
            caps.append(int(np.median(patch)))
    # Collapse JPEG noise: levels within 2 of each other are one fill.
    levels = []
    for level in sorted(set(caps)):
        if not levels or level - levels[-1] > 2:
            levels.append(level)
    # Shadow: the rows immediately under the first row's first cap.
    top, bottom = bands[0]
    x = key_rects(gray, bands[0])[0][0] + 20
    below = [int(gray[bottom + d, x]) for d in (2, 3, 4)]
    return {
        "background": background,
        "cap_fills": levels,
        "shadow": int(np.median(below)),
    }


def corner_profile(gray, band, rect):
    """Left inset of the cap edge for the first rows of a cap: radius proxy."""
    top = band[0]
    x0 = rect[0]
    profile = []
    for dy in range(12):
        row = gray[top + dy, x0 - 4:x0 + 30] > CAP_THRESHOLD
        hit = np.nonzero(row)[0]
        profile.append(int(hit[0]) - 4 if len(hit) else None)
    return profile


def describe(path):
    gray = load(path)
    bands = row_bands(gray)
    if not bands:
        raise SystemExit(f"{path}: found no key rows — is this a keyboard screenshot?")
    print(f"=== {path}  {gray.shape[1]}x{gray.shape[0]}px ===")

    print("  fills (0-255):")
    for name, value in fills(gray, bands).items():
        print(f"    {name:12s} {value}")

    print("  rows:")
    previous_top = None
    for index, (top, bottom) in enumerate(bands):
        height = bottom - top + 1
        pitch = f"pitch={top - previous_top}" if previous_top is not None else "pitch=-"
        print(f"    row{index}: y={top}..{bottom} cap_h={height} ({height / 3:.1f}pt) {pitch}")
        previous_top = top

    print("  caps and label offsets (dx/dy = ink centre - cap centre, px):")
    for index, band in enumerate(bands):
        rects = key_rects(gray, band)
        gaps = [rects[i + 1][0] - rects[i][1] - 1 for i in range(len(rects) - 1)]
        print(f"    row{index}: n={len(rects)} gaps={gaps} "
              f"pad_l={rects[0][0]} pad_r={gray.shape[1] - 1 - rects[-1][1]}")
        for rect in rects:
            box = ink_box(gray, band, rect)
            width = rect[1] - rect[0] + 1
            height = band[1] - band[0] + 1
            if box is None:
                print(f"      x{rect[0]:4d} w={width:3d}  ** NO LABEL INK **")
                continue
            x_min, x_max, y_min, y_max = box
            dx = (x_min + x_max) / 2 - width / 2
            dy = (y_min + y_max) / 2 - height / 2
            print(f"      x{rect[0]:4d} w={width:3d}  ink={x_max - x_min + 1:3d}x"
                  f"{y_max - y_min + 1:3d}  dx={dx:+6.1f} dy={dy:+6.1f}")

    print(f"  corner profile (row0 first cap): {corner_profile(gray, bands[0], key_rects(gray, bands[0])[0])}")
    print()


def main():
    if len(sys.argv) != 3:
        raise SystemExit(__doc__)
    for path in sys.argv[1:]:
        describe(path)
    print("Compare row by row. Equal-length rows with equal gaps mean the")
    print("horizontal layout matches; differing cap_h means the button insets")
    print("differ; a dx far from 0 on one side only is a label-centring bug.")


if __name__ == "__main__":
    main()
