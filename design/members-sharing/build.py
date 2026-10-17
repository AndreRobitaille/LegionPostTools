#!/usr/bin/env python3
"""Build code-native sharing artwork and icons. No member data or web access."""
from pathlib import Path
import argparse
import hashlib
import html
import subprocess
from fontTools.ttLib import TTFont
from fontTools.pens.boundsPen import BoundsPen
from fontTools.pens.svgPathPen import SVGPathPen

SOURCE = Path(__file__).resolve().parent
parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--output", type=Path, default=SOURCE)
parser.add_argument("--post-label", default="POST 165")
parser.add_argument("--locality", default="Two Rivers")
args = parser.parse_args()
ROOT = args.output.resolve()
ROOT.mkdir(parents=True, exist_ok=True)
NAVY, GOLD, CREAM = "#0A2240", "#C6A15B", "#F4EEDD"


def run(*args):
    subprocess.run([str(arg) for arg in args], check=True)


def label(text, x, baseline, size, bold=False):
    """Outline the label so the shipped SVG needs no installed fonts."""
    family = "Liberation Sans:style=" + ("Bold" if bold else "Regular")
    path = subprocess.check_output(["fc-match", "-f", "%{file}", family], text=True)
    font = TTFont(path)
    glyphs, cmap = font.getGlyphSet(), font.getBestCmap()
    scale = size / font["head"].unitsPerEm
    cursor, paths = 0, []
    for char in text:
        glyph = glyphs[cmap[ord(char)]]
        pen = SVGPathPen(glyphs)
        glyph.draw(pen)
        if pen.getCommands():
            paths.append(f'<path transform="translate({cursor} 0)" d="{pen.getCommands()}"/>')
        cursor += glyph.width
    assert x + cursor * scale <= 1132, f"Label too wide: {text}"
    return f'<g aria-label="{html.escape(text)}" transform="translate({x} {baseline}) scale({scale} {-scale})">' + "".join(paths) + "</g>"


def svg(body, width=512, height=512, title="Post Members"):
    return f'<svg xmlns="http://www.w3.org/2000/svg" width="{width}" height="{height}" viewBox="0 0 {width} {height}" role="img"><title>{title}</title>{body}</svg>\n'


def outline_members_mark():
    """Center the unmodified Noto Sans Bold M using its visible glyph bounds."""
    font = TTFont(SOURCE / "fonts" / "NotoSans-Bold.woff")
    assert font["name"].getDebugName(1) == "Noto Sans"
    assert font["OS/2"].usWeightClass == 700
    glyphs = font.getGlyphSet()
    glyph = glyphs[font.getBestCmap()[ord("M")]]
    bounds = BoundsPen(glyphs)
    outline = SVGPathPen(glyphs)
    glyph.draw(bounds)
    glyph.draw(outline)
    left, bottom, right, top = bounds.bounds
    scale = 288 / (top - bottom)
    x = (512 - (right - left) * scale) / 2 - left * scale
    baseline = 112 + top * scale
    return (
        f'<path fill="{GOLD}" transform="translate({x} {baseline}) '
        f'scale({scale} {-scale})" d="{outline.getCommands()}"/>'
    )


def icon_body(rounded=True):
    radius = 88 if rounded else 0
    return f'<rect width="512" height="512" rx="{radius}" fill="{NAVY}"/>' + MEMBERS_MARK


MEMBERS_MARK = outline_members_mark()
(ROOT / "favicon.svg").write_text(svg(icon_body()))
(ROOT / "app-icon.svg").write_text(svg(icon_body(False)))

# Cream field and bold member identity distinguish this from the public blue Legion card.
card = f'<rect width="1200" height="630" fill="{CREAM}"/>'
card += f'<rect y="606" width="1200" height="24" fill="{GOLD}"/>'
card += '<g transform="translate(64 189) scale(0.484375)">' + icon_body() + "</g>"
card += f'<g fill="{NAVY}">'
card += label(args.post_label, 368, 222, 112, True)
card += label("MEMBERS", 368, 369, 128, True)
card += label(args.locality, 368, 480, 72)
card += "</g>"
(ROOT / "members-og.svg").write_text(svg(card, 1200, 630, f"{args.post_label.title()} Members — {args.locality}"))

run("rsvg-convert", ROOT / "members-og.svg", "-o", ROOT / "members-og.png")
run("magick", ROOT / "members-og.png", "-strip", "-sampling-factor", "4:4:4", "-quality", "94", ROOT / "members-og.jpg")
for width in (240, 320):
    run("magick", ROOT / "members-og.png", "-resize", f"{width}x", "-strip", ROOT / f"preview-{width}.png")
for size in (16, 32, 48, 96):
    run("rsvg-convert", ROOT / "favicon.svg", "-w", size, "-h", size, "-o", ROOT / f"favicon-{size}.png")
run("magick", ROOT / "favicon-16.png", ROOT / "favicon-32.png", ROOT / "favicon-48.png", ROOT / "favicon.ico")
for name, size in (("apple-touch-icon.png", 180), ("app-icon-192.png", 192), ("app-icon-512.png", 512)):
    run("rsvg-convert", ROOT / "app-icon.svg", "-w", size, "-h", size, "-o", ROOT / name)

# Review sheet: real 16/32/48px favicons sit beside enlarged, sharp-edged copies.
run("magick", "-size", "480x180", f"xc:{CREAM}",
    ROOT / "favicon-16.png", "-geometry", "+24+28", "-composite",
    ROOT / "favicon-32.png", "-geometry", "+76+20", "-composite",
    ROOT / "favicon-48.png", "-geometry", "+144+12", "-composite",
    "(", ROOT / "favicon-16.png", "-filter", "point", "-resize", "96x96", ")", "-geometry", "+24+76", "-composite",
    "(", ROOT / "favicon-32.png", "-filter", "point", "-resize", "96x96", ")", "-geometry", "+160+76", "-composite",
    "(", ROOT / "favicon-48.png", "-filter", "point", "-resize", "96x96", ")", "-geometry", "+296+76", "-composite",
    "-strip", ROOT / "favicon-review.png")

package_files = sorted(path for path in ROOT.rglob("*") if path.is_file() and path.name != "SHA256SUMS")
(ROOT / "SHA256SUMS").write_text("".join(
    f"{hashlib.sha256(path.read_bytes()).hexdigest()}  {path.relative_to(ROOT)}\n"
    for path in package_files
))
print("Built sharing artwork, thumbnails, favicons, and touch/app icons in", ROOT)
