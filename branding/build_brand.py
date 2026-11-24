"""Build Pomodocus brand SVG masters (text outlined from Manrope via fontTools).

Usage: py -3 build_brand.py <fonts_dir>
"""
import sys
from pathlib import Path

from fontTools.pens.svgPathPen import SVGPathPen
from fontTools.pens.transformPen import TransformPen
from fontTools.ttLib import TTFont

FONTS = Path(sys.argv[1])
OUT = Path(__file__).parent / "logo"
OUT.mkdir(exist_ok=True)

CORAL = "#F2553D"
TEAL = "#23A58C"
INK = "#1E1F24"
PAPER = "#FBF7F3"
NIGHT = "#15171C"

# --- Symbol (concept B, refined) -------------------------------------------
# Tomato body: circle c=(128,146) r=90. The hand (white cut-out) points to 12:
# the start of a session. The stem continues the hand's axis above the fruit.
BODY = (
    "M128 56 A90 90 0 1 1 127.99 56 Z "
    "M117 94 A11 11 0 0 1 139 94 L139 148 A11 11 0 0 1 117 148 Z"
)
STEM = '<rect x="118" y="22" width="20" height="46" rx="10"/>'
LEAF = '<path d="M134 54 Q148 16 200 28 Q184 68 134 54 Z"/>'


def symbol_group(body, leaf, dx=0, dy=0, scale=1.0):
    return (
        f'<g transform="translate({dx} {dy}) scale({scale})">'
        f'<path fill="{body}" fill-rule="evenodd" d="{BODY}"/>'
        f'<g fill="{leaf}">{STEM}{LEAF}</g></g>'
    )


def text_path(text, weight, size, tracking=0.0):
    """Return (svg path d, advance width) for text at font-size `size`."""
    font = TTFont(FONTS / f"Manrope-{weight}.ttf")
    gs = font.getGlyphSet()
    cmap = font.getBestCmap()
    upm = font["head"].unitsPerEm
    s = size / upm
    pen = SVGPathPen(gs)
    x = 0.0
    for ch in text:
        name = cmap[ord(ch)]
        tp = TransformPen(pen, (s, 0, 0, -s, x, 0))
        gs[name].draw(tp)
        x += gs[name].width * s + tracking
    return pen.getCommands(), x - tracking


def svg(w, h, body, bg=None):
    rect = f'<rect width="{w}" height="{h}" fill="{bg}"/>' if bg else ""
    return (
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 {w} {h}" '
        f'width="{w}" height="{h}">{rect}{body}</svg>\n'
    )


def write(name, content):
    (OUT / name).write_text(content, encoding="utf-8")
    print("wrote", OUT / name)


# Symbol variants
write("pomodocus-symbol.svg", svg(256, 256, symbol_group(CORAL, TEAL)))
write("pomodocus-symbol-black.svg", svg(256, 256, symbol_group("#000", "#000")))
write("pomodocus-symbol-white.svg", svg(256, 256, symbol_group("#fff", "#fff")))

# Wordmark
WORD, WORD_W = text_path("pomodocus", 800, 132, tracking=-4)
TAG, TAG_W = text_path("FOCUS. WORK. REPEAT.", 700, 30, tracking=7)
SLOGAN, SLOGAN_W = text_path("Focus on what matters.", 500, 40, tracking=0)


def horizontal(word_color, tag_color, body, leaf, with_tag, bg=None):
    sym = symbol_group(body, leaf, dx=0, dy=0)
    x0 = 276
    base = 168 if not with_tag else 140
    parts = [sym, f'<path fill="{word_color}" transform="translate({x0} {base})" d="{WORD}"/>']
    if with_tag:
        parts.append(
            f'<path fill="{tag_color}" transform="translate({x0 + 6} 232)" d="{TAG}"/>'
        )
    w = int(x0 + max(WORD_W, TAG_W if with_tag else 0) + 20)
    return svg(w, 256, "".join(parts), bg)


write("pomodocus-horizontal.svg", horizontal(INK, CORAL, CORAL, TEAL, False))
write("pomodocus-horizontal-tagline.svg", horizontal(INK, CORAL, CORAL, TEAL, True))
write("pomodocus-horizontal-dark.svg", horizontal(PAPER, CORAL, CORAL, TEAL, True, NIGHT))
write("pomodocus-horizontal-black.svg", horizontal("#000", "#000", "#000", "#000", True))


def stacked(word_color, slogan_color, bg=None):
    W = int(max(WORD_W, SLOGAN_W) + 80)
    cx = W / 2
    sym = symbol_group(CORAL, TEAL, dx=cx - 128 * 1.1, dy=10, scale=1.1)
    parts = [
        sym,
        f'<path fill="{word_color}" transform="translate({cx - WORD_W / 2} 400)" d="{WORD}"/>',
        f'<path fill="{slogan_color}" transform="translate({cx - SLOGAN_W / 2} 466)" d="{SLOGAN}"/>',
    ]
    return svg(W, 500, "".join(parts), bg)


write("pomodocus-stacked.svg", stacked(INK, "#6B6E78"))
write("pomodocus-stacked-dark.svg", stacked(PAPER, "#A9ACB6", NIGHT))

# App icon sources (1024): full icon + adaptive foreground (safe zone 66%)
write(
    "app-icon.svg",
    svg(1024, 1024, f'<rect width="1024" height="1024" rx="0" fill="{PAPER}"/>'
        + symbol_group(CORAL, TEAL, dx=512 - 128 * 3.05, dy=512 - 132 * 3.05, scale=3.05)),
)
write(
    "app-icon-foreground.svg",
    svg(1024, 1024, symbol_group(CORAL, TEAL, dx=512 - 128 * 2.3, dy=512 - 132 * 2.3, scale=2.3)),
)
write(
    "app-icon-monochrome.svg",
    svg(1024, 1024, symbol_group("#000", "#000", dx=512 - 128 * 2.3, dy=512 - 132 * 2.3, scale=2.3)),
)
write(
    "splash.svg",
    svg(1024, 1024, symbol_group(CORAL, TEAL, dx=512 - 128 * 2.6, dy=512 - 132 * 2.6, scale=2.6)),
)
