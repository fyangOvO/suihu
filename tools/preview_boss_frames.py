"""把 Boss 24 帧拼成 4×6 总览（等比缩略，不拉伸），便于目视核对体型与脚位。
用法：python -X utf8 D:\\水滸g\\game\\tools\\preview_boss_frames.py
"""
from pathlib import Path

from PIL import Image, ImageDraw

OUT_DIR = Path(r"D:\水滸g\game\assets\anim\boss")
PREVIEW = Path(r"D:\水滸g\docs\preview\boss-frames-all.png")
NAMES = [
    "boss-idle", "boss-walk-1", "boss-walk-2", "boss-crouch", "boss-hurt", "boss-knockdown",
    "boss-pounce-1", "boss-pounce-2", "boss-pounce-3", "boss-pounce-4", "boss-pounce-5", "boss-tail-1",
    "boss-rear-up", "boss-claw-1", "boss-claw-2", "boss-roar", "boss-summon", "boss-recover",
    "boss-iron-tail-1", "boss-iron-tail-2", "boss-iron-tail-3", "boss-death-pounce-1", "boss-death-pounce-2", "boss-pant",
]
TW, TH = 240, 240
COLS, ROWS = 6, 4

sheet = Image.new("RGB", (TW * COLS, (TH + 18) * ROWS), (32, 33, 31))
draw = ImageDraw.Draw(sheet)
for i, name in enumerate(NAMES):
    canvas = Image.open(OUT_DIR / f"{name}.png").convert("RGBA")
    small = canvas.copy()
    small.thumbnail((TW, TH), Image.LANCZOS)
    cell = Image.new("RGBA", (TW, TH), (32, 33, 31, 255))
    cell.alpha_composite(small, ((TW - small.width) // 2, TH - small.height))
    sx, sy = (i % COLS) * TW, (i // COLS) * (TH + 18)
    sheet.paste(cell.convert("RGB"), (sx, sy + 18))
    draw.text((sx + 6, sy + 3), name, fill=(210, 210, 200))
sheet.save(PREVIEW)
print("preview", PREVIEW)
