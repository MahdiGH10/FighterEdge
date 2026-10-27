"""Smooths the traced logo SVG: straight-segment outlines become curves.

assets/images/fighter-edge-logo.svg was auto-traced from a screenshot, so each
shape is a polygon of short straight segments with a little wobble. This
rasterises each shape at high resolution, softens the wobble, and re-traces it
with potrace (corner detection plus Bezier fitting), so edges become smooth
curves while real corners stay sharp.

It only improves the outlines; it cannot add detail the screenshot never had.
A clean redraw from the original artwork is still the best fix.

Usage:

    python smooth_svg.py --browser "C:/.../msedge.exe" \
        --svg ../../assets/images/fighter-edge-logo.svg --out smoothed.svg

Needs: pillow, numpy, potracer.
"""

import argparse
import re
import subprocess
import tempfile
from pathlib import Path

import numpy as np
import potrace
from PIL import Image, ImageFilter

# viewBox of the logo: x, y, width, height (user units).
VIEW = (10.0, 21.0, 340.0, 340.0)
PIXELS = 3072  # raster size per shape

# Per-shape softening, in user units (gaussian sigma), and the potrace
# settings. The organic shapes (ring, fighter) get softened; the FE letters are
# hard-edged geometry and keep their corners, so they are only re-fitted.
SHAPES = {
    "red": {"sigma": 1.1, "alphamax": 1.15, "opttolerance": 0.4},
    "disc": {"sigma": 0.9, "alphamax": 1.1, "opttolerance": 0.35},
    "silver": {"sigma": 0.0, "alphamax": 0.55, "opttolerance": 0.2},
}

PATH = re.compile(r'<path d="([^"]*)" fill="url\(#(\w+)\)"([^>]*)/>')


def render_mask(browser: str, d: str, out: Path) -> None:
    x, y, w, h = VIEW
    svg = (
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="{x} {y} {w} {h}" '
        f'width="{PIXELS}" height="{PIXELS}">'
        f'<path d="{d}" fill="#000" fill-rule="evenodd"/></svg>'
    )
    with tempfile.TemporaryDirectory() as tmp:
        page = Path(tmp) / "p.html"
        page.write_text(
            "<!doctype html><meta charset=utf-8><style>html,body{margin:0;"
            "background:transparent}svg{display:block}</style>" + svg,
            encoding="utf-8",
        )
        subprocess.run(
            [browser, "--headless=new", "--disable-gpu", "--hide-scrollbars",
             "--default-background-color=00000000",
             f"--window-size={PIXELS},{PIXELS}", f"--screenshot={out}",
             page.as_uri()],
            check=True, capture_output=True,
        )


def trace(mask: Image.Image, sigma: float, alphamax: float,
          opttolerance: float) -> str:
    alpha = mask.getchannel("A")
    if sigma > 0:
        sigma_px = sigma * PIXELS / VIEW[2]
        alpha = alpha.filter(ImageFilter.GaussianBlur(sigma_px))
    # potracer treats dark (False) pixels as the shape to trace.
    bitmap = potrace.Bitmap(np.asarray(alpha) <= 127)
    curves = bitmap.trace(
        turdsize=40,
        turnpolicy=potrace.POTRACE_TURNPOLICY_MINORITY,
        alphamax=alphamax,
        opticurve=True,
        opttolerance=opttolerance,
    )
    scale = VIEW[2] / PIXELS

    def pt(p) -> str:
        return f"{VIEW[0] + p.x * scale:.2f},{VIEW[1] + p.y * scale:.2f}"

    parts = []
    for curve in curves:
        parts.append(f"M{pt(curve.start_point)}")
        for seg in curve.segments:
            if seg.is_corner:
                parts.append(f"L{pt(seg.c)}L{pt(seg.end_point)}")
            else:
                parts.append(
                    f"C{pt(seg.c1)} {pt(seg.c2)} {pt(seg.end_point)}")
        parts.append("Z")
    return "".join(parts)


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--browser", required=True)
    parser.add_argument("--svg", required=True)
    parser.add_argument("--out", required=True)
    args = parser.parse_args()

    svg = Path(args.svg).read_text("utf-8")
    work = Path(tempfile.mkdtemp())

    def replace(match: re.Match) -> str:
        d, gradient, rest = match.group(1), match.group(2), match.group(3)
        shape = {"red": "red", "disc": "disc", "silver": "silver"}[gradient]
        mask_file = work / f"{shape}.png"
        render_mask(args.browser, d, mask_file)
        new_d = trace(Image.open(mask_file).convert("RGBA"), **SHAPES[shape])
        print(f"{shape}: {len(d)} -> {len(new_d)} chars")
        return f'<path d="{new_d}" fill="url(#{gradient})"{rest}/>'

    smoothed = PATH.sub(replace, svg)
    assert smoothed != svg, "no paths matched"
    # The top-left of the F is white on the white disc; its first gradient stop
    # (#f9f9f9) is a shade darker than the disc there (about #fefefe) and
    # showed as a faint horizontal seam. Match it.
    seam = '<stop offset="0" stop-color="#f9f9f9"/>'
    assert seam in smoothed, "silver gradient changed"
    smoothed = smoothed.replace(seam, '<stop offset="0" stop-color="#fefefe"/>')
    # The F's top edge sits exactly on the disc's lower edge; two antialiased
    # edges meeting leave a hairline gap. A hair-thin stroke of the same fill
    # overlaps the disc and closes it.
    letters = 'fill="url(#silver)" fill-rule="evenodd"'
    assert letters in smoothed, "silver path changed"
    smoothed = smoothed.replace(
        letters,
        letters + ' stroke="url(#silver)" stroke-width=".5" '
        'stroke-linejoin="round"',
    )
    smoothed = smoothed.replace(
        "Vector-traced from screenshot.",
        "Vector-traced from screenshot, outlines smoothed with potrace.",
    )
    Path(args.out).write_text(smoothed, encoding="utf-8")


if __name__ == "__main__":
    main()
