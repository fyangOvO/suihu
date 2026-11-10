"""把死亡演出的四张离屏截图拼成横向对照条（缩到 1600px）。"""
from pathlib import Path

from PIL import Image, ImageDraw

PREV = Path(r"D:\水滸g\docs\preview")
SHOTS = [PREV / f"death-seq-{i}.png" for i in range(1, 5)]
LABELS = ["0.20s", "0.43s", "0.70s", "0.97s"]
TILE_W = 400
GAP = 6

ims = [Image.open(p).convert("RGB") for p in SHOTS]
tile_h = int(ims[0].height * TILE_W / ims[0].width)
strip = Image.new("RGB", (TILE_W * len(ims) + GAP * (len(ims) - 1), tile_h + 24), (12, 11, 10))
draw = ImageDraw.Draw(strip)
x = 0
for im, label in zip(ims, LABELS):
    strip.paste(im.resize((TILE_W, tile_h), Image.LANCZOS), (x, 0))
    draw.text((x + 6, tile_h + 6), label, fill=(220, 214, 200))
    x += TILE_W + GAP
out = PREV / "death-mist-sequence.png"
strip.save(out)
print("saved", out, strip.size)
