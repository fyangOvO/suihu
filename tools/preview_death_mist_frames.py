"""把 6 张青烟帧拼成对照图（深灰底），并打印每帧 alpha 统计。

用法：python -X utf8 tools/preview_death_mist_frames.py [帧目录] [输出png]
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

SRC = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(r"D:\水滸g\game\assets\fx\death_mist")
OUT = Path(sys.argv[2]) if len(sys.argv) > 2 else Path(r"D:\水滸g\docs\preview\death-mist-frames.png")

frames = sorted(SRC.glob("mist_*.png"))
tile = (256, 320)
pad = 12
sheet = Image.new("RGB", (len(frames) * (tile[0] + pad) + pad, tile[1] + 2 * pad + 26), (18, 17, 16))
draw = ImageDraw.Draw(sheet)
for i, f in enumerate(frames, start=1):
    im = Image.open(f)
    a = np.asarray(im)[:, :, 3]
    print(f.name, "alpha max", int(a.max()), "mean", round(float(a.mean()), 1),
          "cover>32", round(float((a > 32).mean() * 100), 2), "%")
    thumb = im.resize(tile, Image.LANCZOS)
    base = Image.new("RGB", tile, (26, 24, 22))
    base = Image.alpha_composite(base.convert("RGBA"), thumb).convert("RGB")
    x = pad + (i - 1) * (tile[0] + pad)
    sheet.paste(base, (x, pad))
    draw.text((x + 4, pad + tile[1] + 6), f"mist_{i:02d}", fill=(220, 214, 200))
sheet.save(OUT)
print("saved", OUT)
