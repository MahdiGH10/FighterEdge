"""Builds every raster the app needs from the logo SVG.

Source of truth: assets/images/fighter-edge-logo.svg (the app icon: a black
rounded tile with the kicking fighter, red ring and FE monogram).

Outputs (all under assets/):

  brand/logo_mark.png     the mark alone on a transparent background, tight
                          crop, 1024 px. Used inside the app (splash, auth).
  brand/splash.png        the mark centred on a transparent 1152 px canvas with
                          room for Android 12's circular splash mask.
  icon/icon.png           full-bleed opaque 1024 px launcher icon (the stores
                          and the OS round the corners themselves).
  icon/foreground.png     adaptive-icon foreground: the mark inside the 66%
                          safe zone, transparent background.

Rendering uses a headless Chromium browser (Edge or Chrome), so gradients are
drawn exactly as the SVG describes them. Usage:

    python build_assets.py --browser "C:/.../msedge.exe" --repo <fighter_edge>

Run it again after replacing the SVG with a cleaner redraw: nothing else in
the app needs to change.
"""

import argparse
import re
import subprocess
import tempfile
from pathlib import Path

import numpy as np
from PIL import Image

BACKGROUND = (8, 7, 12)  # AppColors.background, #08070C


def render(browser: str, svg: str, size: int, out: Path) -> None:
    """Renders [svg] to a transparent PNG of [size] x [size]."""
    with tempfile.TemporaryDirectory() as tmp:
        html = Path(tmp) / "page.html"
        html.write_text(
            "<!doctype html><meta charset=utf-8>"
            "<style>html,body{margin:0;background:transparent}"
            f"svg{{display:block;width:{size}px;height:{size}px}}</style>"
            + svg,
            encoding="utf-8",
        )
        subprocess.run(
            [
                browser,
                "--headless=new",
                "--disable-gpu",
                "--hide-scrollbars",
                "--default-background-color=00000000",
                f"--window-size={size},{size}",
                f"--screenshot={out}",
                html.as_uri(),
            ],
            check=True,
            capture_output=True,
        )


def crop_square(image: Image.Image, margin: float = 0.0) -> Image.Image:
    """Tight crop to the visible pixels, padded to a square."""
    box = image.getchannel("A").point(lambda a: 255 if a > 8 else 0).getbbox()
    cropped = image.crop(box)
    side = max(cropped.size)
    pad = int(side * margin)
    canvas = Image.new("RGBA", (side + 2 * pad,) * 2, (0, 0, 0, 0))
    canvas.paste(
        cropped,
        ((canvas.width - cropped.width) // 2,
         (canvas.height - cropped.height) // 2),
    )
    return canvas


def centred(mark: Image.Image, canvas: int, mark_size: int) -> Image.Image:
    resized = mark.resize((mark_size, mark_size), Image.LANCZOS)
    out = Image.new("RGBA", (canvas, canvas), (0, 0, 0, 0))
    offset = (canvas - mark_size) // 2
    out.paste(resized, (offset, offset), resized)
    return out


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--browser", required=True)
    parser.add_argument("--repo", required=True, help="the fighter_edge folder")
    args = parser.parse_args()

    repo = Path(args.repo)
    svg = (repo / "assets/images/fighter-edge-logo.svg").read_text("utf-8")

    # -- The mark alone: drop the black tile and its rim. -------------------
    tile = re.compile(r"<rect [^>]*/>\s*")
    mark_svg = tile.sub("", svg, count=2)
    assert "<rect" not in mark_svg, "expected exactly the tile and rim rects"
    work = Path(tempfile.mkdtemp())
    raw = work / "mark_raw.png"
    render(args.browser, mark_svg, 2048, raw)
    mark = crop_square(Image.open(raw).convert("RGBA"))

    brand = repo / "assets/brand"
    brand.mkdir(parents=True, exist_ok=True)
    mark.resize((1024, 1024), Image.LANCZOS).save(
        brand / "logo_mark.png", optimize=True
    )

    # -- Native splash: the mark inside the Android 12 circle (768 of 1152). --
    centred(mark, 1152, 620).save(brand / "splash.png", optimize=True)

    # -- Launcher icon: full-bleed and opaque, so the OS can round it itself.
    icon = Image.new("RGBA", (1024, 1024), (6, 6, 6, 255))
    face = centred(mark, 1024, 760)
    icon.alpha_composite(face)
    (repo / "assets/icon").mkdir(parents=True, exist_ok=True)
    icon.convert("RGB").save(repo / "assets/icon/icon.png", optimize=True)

    # -- Adaptive foreground: inside the 66% safe zone. -----------------------
    centred(mark, 1024, 640).save(
        repo / "assets/icon/foreground.png", optimize=True
    )

    for name in ("brand/logo_mark.png", "brand/splash.png",
                 "icon/icon.png", "icon/foreground.png"):
        image = Image.open(repo / "assets" / name)
        arr = np.asarray(image.convert("RGBA"))
        print(f"{name}: {image.size}, opaque pixels "
              f"{(arr[..., 3] > 8).mean():.0%}")


if __name__ == "__main__":
    main()
