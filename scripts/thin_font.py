#!/usr/bin/env python3

"""A thinner copy of a TrueType font: every outline pulled in by FreeType's
FT_Outline_EmboldenXY with a negative strength (font units), the hinting
instructions dropped (they belong to the old outlines), renamed.

  python3 scripts/thin_font.py <in.ttf> <out.ttf> <strength> "<family name>"
      [<y strength>] [--width <factor>]

<y strength>: how much thinner the horizontal strokes get (by default as
much as the upright ones; 0: as they are). --tight <gap>: every letter as
wide as its outline and <gap> units more (a font of letters all as wide,
like Press Start 2P, gets narrow ones: i, l, the full stop), --space <units>:
the space that wide. --width: every letter and gap that much as wide
afterwards (narrower letters, as high). --size: the whole font drawn that
much as large (its units per em larger). Needs fontTools
and freetype-py (pip). The menu fonts in CorsixTH/Bitmap/fonts: Bungee
OpenTH Thin is Bungee-Regular.ttf at strength 70; OpenTH Arcade is
PressStart2P-Regular.ttf at strength 80, y strength 0 (its upright strokes
are two of its pixels wide, the others one), --tight 125 (one of its pixels)
--space 500 --size 0.85.
"""
import argparse
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
    parser = argparse.ArgumentParser()
    parser.add_argument("src")
    parser.add_argument("out")
    parser.add_argument("strength", type=int)
    parser.add_argument("family")
    parser.add_argument("y_strength", type=int, nargs="?")
    parser.add_argument("--tight", type=int)
    parser.add_argument("--space", type=int)
    parser.add_argument("--width", type=float, default=1.0)
    parser.add_argument("--size", type=float, default=1.0)
    a = parser.parse_args()
    src, out, strength, family, width = a.src, a.out, a.strength, a.family, a.width
    y_strength = strength if a.y_strength is None else a.y_strength
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
        ftraw.FT_Outline_EmboldenXY(byref(outline._FT_Outline), -strength, -y_strength)
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
    if a.tight is not None:
        # Each letter as wide as it is, the same gap after it.
        shifts = {}
        for gname in order:
            g = glyf[gname]
            if g.isComposite() or g.numberOfContours <= 0:
                continue
            g.recalcBounds(glyf)
            shifts[gname] = x0 = g.xMin
            g.coordinates = GlyphCoordinates([(x - x0, y) for x, y in g.coordinates])
            g.recalcBounds(glyf)
            hmtx[gname] = (g.xMax + a.tight, 0)
        for gname in order:
            g = glyf[gname]
            if g.isComposite():
                # (An accented letter: as wide as its letter, the accent
                # where it was over it.)
                base = g.components[0].glyphName
                for c in g.components:
                    c.x += shifts.get(c.glyphName, 0) - shifts.get(base, 0)
                g.recalcBounds(glyf)
                hmtx[gname] = (hmtx[base][0], g.xMin)
    if a.space is not None:
        cmap = font.getBestCmap()
        for code in (0x20, 0xA0):
            if code in cmap:
                hmtx[cmap[code]] = (a.space, 0)
    if width != 1.0:
        # Narrower: every outline, the parts of the accented letters and
        # every advance (spaces too) times the width.
        for gname in order:
            g = glyf[gname]
            if g.isComposite():
                for c in g.components:
                    c.x = round(c.x * width)
            elif g.numberOfContours > 0:
                g.coordinates = GlyphCoordinates([(round(x * width), y) for x, y in g.coordinates])
        for gname in order:
            g = glyf[gname]
            g.recalcBounds(glyf)
            advance, _ = hmtx[gname]
            hmtx[gname] = (round(advance * width), getattr(g, "xMin", 0))
        font["hhea"].advanceWidthMax = max(adv for adv, _ in hmtx.values())
        font["OS/2"].xAvgCharWidth = round(font["OS/2"].xAvgCharWidth * width)
    # The hinting fits the old outlines: none at all is better than wrong.
    for g in (glyf[n] for n in order):
        if hasattr(g, "program"):
            g.program = ttProgram.Program()
            g.program.fromBytecode(b"")
    for tag in ("fpgm", "prep", "cvt ", "hdmx", "LTSH", "VDMX"):
        if tag in font:
            del font[tag]
    # A name of its own (Bungee's licence reserves no name, but a modified
    # font should not pass for the original; Press Start 2P's reserves its
    # name, the copyright notice stays).
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
    if a.size != 1.0:
        font["head"].unitsPerEm = round(font["head"].unitsPerEm / a.size)
    font.save(out)
    after = stem(TTFont(out)["glyf"], i_name)
    print(f"{out}: {changed} glyphs thinner by {strength} units ({skipped} skipped), "
          f"width {width}; the I {before} -> {after} units wide")


main()
