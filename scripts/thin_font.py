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
the space that wide. --pixel <unit>: a pixel font (its pixels <unit> font
units), each glyph made again from its pixels with only runs of two or
more pixels thinner (instead of FreeType's thinning, which takes as much
off a stroke of one pixel). --width: every letter and gap that much as wide
afterwards (narrower letters, as high). --size: the whole font drawn that
much as large (its units per em larger). Needs fontTools
and freetype-py (pip). The menu fonts in CorsixTH/Bitmap/fonts: Bungee
OpenTH Thin is Bungee-Regular.ttf at strength 70; OpenTH Arcade is
PressStart2P-Regular.ttf at strength 80, y strength 0, --pixel 125 (its
pixels are 125 units; strokes of two pixels thinner, those of one as they
are: Argus, the m looked cut off), --tight 125 (one of its pixels)
--space 500 --size 0.85.
"""
import argparse
from ctypes import byref

import freetype
import freetype.raw as ftraw
from fontTools.ttLib import TTFont
from fontTools.ttLib.tables._g_l_y_f import GlyphCoordinates
from fontTools.ttLib.tables import ttProgram
from fontTools.pens.ttGlyphPen import TTGlyphPen


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
    parser.add_argument("--pixel", type=int)
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
    unit = a.pixel
    if unit:
        face.set_pixel_sizes(0, font["head"].unitsPerEm // unit)
    for gid, gname in enumerate(order):
        g = glyf[gname]
        if g.isComposite() or g.numberOfContours <= 0:
            continue
        if unit and all(x % unit == 0 and y % unit == 0 for x, y in g.getCoordinates(glyf)[0]):
            # A pixel font: the glyph made again from its pixels, row by row;
            # a run of two pixels or more is `strength` narrower (half of it
            # on each side), a single pixel stays whole (a thin stem would
            # all but go: the m's first stroke).
            face.load_glyph(gid, freetype.FT_LOAD_RENDER | freetype.FT_LOAD_TARGET_MONO |
                            freetype.FT_LOAD_NO_HINTING)
            bm, left, top = face.glyph.bitmap, face.glyph.bitmap_left, face.glyph.bitmap_top
            pen = TTGlyphPen(None)
            for j in range(bm.rows):
                bits = [bool(bm.buffer[j * bm.pitch + i // 8] & (0x80 >> (i % 8))) for i in range(bm.width)]
                y0 = (top - 1 - j) * unit
                i = 0
                while i < bm.width:
                    if not bits[i]:
                        i += 1
                        continue
                    k = i
                    while k < bm.width and bits[k]:
                        k += 1
                    x0, x1 = (left + i) * unit, (left + k) * unit
                    if k - i >= 2:
                        x0, x1 = x0 + strength // 2, x1 - strength // 2
                    # (Clockwise, as TrueType fills.)
                    pen.moveTo((x0, y0))
                    pen.lineTo((x0, y0 + unit))
                    pen.lineTo((x1, y0 + unit))
                    pen.lineTo((x1, y0))
                    pen.closePath()
                    i = k
            new = pen.glyph()
            new.recalcBounds(glyf)
            glyf[gname] = new
            advance, _ = hmtx[gname]
            hmtx[gname] = (max(0, advance - strength), getattr(new, "xMin", 0))
            changed += 1
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
