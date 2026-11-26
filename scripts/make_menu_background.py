#!/usr/bin/env python3

"""Make the list menu's backgrounds (CorsixTH/Bitmap/mainmenu{2160,1440,1080,
720,480}.dat and .pal, and .bmp up to 1080) from one picture.

  python3 scripts/make_menu_background.py <picture> CorsixTH/Bitmap [x0 of the 4:3 crop, 0..1]

The picture is cut to 16:9 in the middle if it is not quite that. 2160, 1440,
1080 and 720: the whole picture. 480: a 4:3 crop (640 x 480), its left edge at
the given fraction of the room to move it (0 = left, 0.5 = centre, 1 = right).
Each is 256 colours with a 6-bit palette (the game's .pal), dithered. The .bmp
copies are for looking at and editing only (the game reads the .dat and .pal);
the big sizes have none.

The backgrounds of 2026-11-26 are Argus's picture (1376 x 768), upscaled four
times with Real-ESRGAN (realesrgan-ncnn-vulkan -n realesrgan-x4plus-anime -s 4),
x0 0.78 (the OpenTH sign stays in the 4:3 crop).
"""
import sys
import numpy as np
from PIL import Image

SIZES = [("2160", 3840, 2160, False), ("1440", 2560, 1440, False), ("1080", 1920, 1080, True),
         ("720", 1280, 720, True)]


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


def write(out_dir, name, pic, bmp):
    p, pal6 = palettised(pic)
    base = f"{out_dir}/mainmenu{name}"
    data = p.tobytes()
    assert len(data) == pic.size[0] * pic.size[1]
    with open(base + ".dat", "wb") as f:
        f.write(data)
    with open(base + ".pal", "wb") as f:
        f.write(pal6)
    if bmp:
        p.save(base + ".bmp")
    used = len(np.unique(np.frombuffer(data, np.uint8)))
    print(f"mainmenu{name}: {pic.size[0]}x{pic.size[1]}, {used} colours used")


def main():
    src, out_dir = sys.argv[1], sys.argv[2]
    x0 = float(sys.argv[3]) if len(sys.argv) > 3 else 0.5
    im = Image.open(src).convert("RGB")
    w, h = im.size
    # (16:9 from the middle.)
    if w * 9 > h * 16:
        cw = round(h * 16 / 9)
        im = im.crop(((w - cw) // 2, 0, (w - cw) // 2 + cw, h))
    elif w * 9 < h * 16:
        ch = round(w * 9 / 16)
        im = im.crop((0, (h - ch) // 2, w, (h - ch) // 2 + ch))
    w, h = im.size
    for name, sw, sh, bmp in SIZES:
        write(out_dir, name, im.resize((sw, sh), Image.LANCZOS), bmp)
    crop_w = round(h * 4 / 3)
    left = round((w - crop_w) * x0)
    write(out_dir, "480", im.crop((left, 0, left + crop_w, h)).resize((640, 480), Image.LANCZOS), True)


main()
