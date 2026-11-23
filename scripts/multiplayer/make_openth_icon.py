# OpenTH's mark (the website's mark.svg: viewBox 40, a #0b7a62 square at
# 2..38 with radius 10, the white cross M16 9h8v7h7v8h-7v7h-8v-7H9v-8h7z) as
# the program icon: OpenTH.ico (Windows) and Icon.icns (macOS).
import sys
from PIL import Image, ImageDraw
out = sys.argv[1]
S = 4096
k = S / 40
img = Image.new("RGBA", (S, S), (0, 0, 0, 0))
d = ImageDraw.Draw(img)
d.rounded_rectangle((2 * k, 2 * k, 38 * k - 1, 38 * k - 1), radius=10 * k, fill=(11, 122, 98, 255))
d.rectangle((16 * k, 9 * k, 24 * k - 1, 31 * k - 1), fill=(255, 255, 255, 255))
d.rectangle((9 * k, 16 * k, 31 * k - 1, 24 * k - 1), fill=(255, 255, 255, 255))
big = img.resize((1024, 1024), Image.LANCZOS)
big.save(out + "/openth-icon-1024.png")
sizes = [16, 24, 32, 48, 64, 128, 256]
frames = [img.resize((s, s), Image.LANCZOS) for s in sizes]
frames[-1].save(out + "/OpenTH.ico", sizes=[(s, s) for s in sizes], append_images=frames[:-1])
big.save(out + "/Icon.icns")
sheet = Image.new("RGBA", (sum(sizes) + 10 * len(sizes), 256), (240, 240, 240, 255))
x = 0
for f in frames:
    sheet.paste(f, (x, 256 - f.size[1]), f); x += f.size[0] + 10
sheet.save(out + "/icon-sizes.png")
print("ok")
