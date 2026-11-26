#!/usr/bin/env python3

"""A thinner copy of a TrueType font: every outline pulled in by FreeType's
FT_Outline_EmboldenXY with a negative strength (font units), the hinting
instructions dropped (they belong to the old outlines), renamed.

  python3 scripts/thin_font.py <in.ttf> <out.ttf> <strength> "<family name>"

Needs fontTools and freetype-py (pip). The menu font Bungee OpenTH Thin
(CorsixTH/Bitmap/fonts) is Bungee-Regular.ttf at strength 70.
"""
import sys
from ctypes import byref

import freetype
import freetype.raw as ftraw
from fontTools.ttLib import TTFont
from fontTools.ttLib.tables._g_l_y_f import GlyphCoordinates
from fontTools.ttLib.tables import ttProgram


def stem(glyf, name):
    """The width of a glyph's outline box (for a straight letter like I: its stem)."""
    g = glyf[name]
    g.recalcBounds(glyf)
    return g.xMax - g.xMin


def main():
    src, out, strength, family = sys.argv[1], sys.argv[2], int(sys.argv[3]), sys.argv[4]
    font = TTFont(src)
    glyf = font["glyf"]
    hmtx = font["hmtx"].metrics
    order = font.getGlyphOrder()
    face = freetype.Face(src)
    i_name = font.getBestCmap().get(ord("I"))
    before = stem(glyf, i_name)
    changed = skipped = 0
    for gid, gname in enumerate(order):
        g = glyf[gname]
        if g.isComposite() or g.numberOfContours <= 0:
            continue
        face.load_glyph(gid, freetype.FT_LOAD_NO_SCALE | freetype.FT_LOAD_NO_HINTING)
        outline = face.glyph.outline
        coords, _, _ = g.getCoordinates(glyf)
        if outline.n_points != len(coords):
            skipped += 1
            continue
        ftraw.FT_Outline_EmboldenXY(byref(outline._FT_Outline), -strength, -strength)
        # (The outline is now `strength` narrower, half of it on each side:
        # moved left by that half and the advance as much shorter, the gap
        # between letters stays as it was and words get narrower.)
        shift = strength // 2
        g.coordinates = GlyphCoordinates([(int(x) - shift, int(y)) for x, y in outline.points])
        g.recalcBounds(glyf)
        advance, _ = hmtx[gname]
        hmtx[gname] = (max(0, advance - strength), g.xMin)
        changed += 1
    # Accented letters made of other glyphs: their advance as much shorter.
    for gname in order:
        g = glyf[gname]
        if g.isComposite():
            g.recalcBounds(glyf)
            advance, _ = hmtx[gname]
            hmtx[gname] = (max(0, advance - strength), g.xMin)
    # The hinting fits the old outlines: none at all is better than wrong.
    for g in (glyf[n] for n in order):
        if hasattr(g, "program"):
            g.program = ttProgram.Program()
            g.program.fromBytecode(b"")
    for tag in ("fpgm", "prep", "cvt ", "hdmx", "LTSH", "VDMX"):
        if tag in font:
            del font[tag]
    # A name of its own (Bungee's licence reserves no name, but a modified
    # font should not pass for the original).
    post_name = family.replace(" ", "") + "-Regular"
    for rec in font["name"].names:
        if rec.nameID in (1, 16):
            rec.string = family
        elif rec.nameID == 4:
            rec.string = family + " Regular" if rec.nameID == 4 else family
        elif rec.nameID == 6:
            rec.string = post_name
        elif rec.nameID == 3:
            rec.string = post_name + ";OpenTH;2026"
    font["OS/2"].usWeightClass = 300
    font.save(out)
    after = stem(TTFont(out)["glyf"], i_name)
    print(f"{out}: {changed} glyphs thinner by {strength} units ({skipped} skipped); "
          f"the I {before} -> {after} units wide")


main()
