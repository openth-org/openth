#!/usr/bin/env python3

"""Make the list menu's backgrounds (CorsixTH/Bitmap/mainmenu{1080,720,480}.dat,
.pal and .bmp) from one 16:9 picture.

  python3 scripts/make_menu_background.py <picture> CorsixTH/Bitmap [x0 of the 4:3 crop, 0..1]

1080 and 720: the whole picture. 480: a 4:3 crop (640 x 480), its left edge at
the given fraction of the room to move it (0 = left, 0.5 = centre, 1 = right).
Each is 256 colours with a 6-bit palette (the game's .pal), dithered.

The backgrounds of 2026-11-26 are Argus's picture, x0 0.78 (the OpenTH sign
stays in the 4:3 crop).
"""
import sys
import numpy as np
from PIL import Image


def palettised(im):
    # 256 colours from the picture already rounded to the palette's 6 bits
    # (so no two become the same when rounded), then the picture mapped onto
    # exactly those colours with dithering.
    a = np.asarray(im).astype(float)
    im6 = Image.fromarray((np.round(a * 63 / 255) * 255 / 63).round().astype(np.uint8))
    q = im6.quantize(256, method=Image.Quantize.MEDIANCUT, kmeans=2, dither=Image.Dither.NONE)
    pal = q.getpalette()[:768]
    pal += [0] * (768 - len(pal))
    pal6 = [min(63, round(v * 63 / 255)) for v in pal]
    ref = Image.new("P", (1, 1))
    ref.putpalette([v * 255 // 63 for v in pal6])
    out = im.quantize(palette=ref, dither=Image.Dither.FLOYDSTEINBERG)
    return out, bytes(pal6)


def main():
    src, out_dir = sys.argv[1], sys.argv[2]
    x0 = float(sys.argv[3]) if len(sys.argv) > 3 else 0.5
    im = Image.open(src).convert("RGB")
    w, h = im.size
    if abs(w / h - 16 / 9) > 0.01:
        sys.exit(f"the picture is {w}x{h}, not 16:9")
    crop_w = round(h * 4 / 3)
    left = round((w - crop_w) * x0)
    sizes = {
        "1080": im.resize((1920, 1080), Image.LANCZOS),
        "720": im.resize((1280, 720), Image.LANCZOS),
        "480": im.crop((left, 0, left + crop_w, h)).resize((640, 480), Image.LANCZOS),
    }
    for name, pic in sizes.items():
        p, pal6 = palettised(pic)
        base = f"{out_dir}/mainmenu{name}"
        data = p.tobytes()
        assert len(data) == pic.size[0] * pic.size[1]
        open(base + ".dat", "wb").write(data)
        open(base + ".pal", "wb").write(pal6)
        p.save(base + ".bmp")
        used = len(np.unique(np.frombuffer(data, np.uint8)))
        print(f"mainmenu{name}: {pic.size[0]}x{pic.size[1]}, {used} colours used")


main()
