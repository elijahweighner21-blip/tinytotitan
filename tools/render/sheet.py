"""Tiles renders into a labelled contact sheet.

    python3 tools/render/sheet.py out.png cols img1.png img2.png ...
"""
import sys
from PIL import Image, ImageDraw

out, cols, files = sys.argv[1], int(sys.argv[2]), sys.argv[3:]
tile_w, tile_h = 480, 270
rows = (len(files) + cols - 1) // cols
sheet = Image.new("RGB", (cols * tile_w, rows * tile_h), (20, 20, 20))
draw = ImageDraw.Draw(sheet)
for i, f in enumerate(files):
    img = Image.open(f).convert("RGB").resize((tile_w, tile_h))
    x, y = (i % cols) * tile_w, (i // cols) * tile_h
    sheet.paste(img, (x, y))
    label = f.rsplit("/", 1)[-1].removesuffix(".png")
    draw.rectangle([x, y, x + 8 + 7 * len(label), y + 16], fill=(0, 0, 0))
    draw.text((x + 4, y + 2), label, fill=(255, 255, 255))
sheet.save(out)
