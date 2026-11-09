"""把 fx-*.png 六张特效截图拼成一张 2×3 总览（带标题条）。

用法：python -X utf8 D:\\水滸g\\game\\tools\\fx_sheet.py
输出：D:\\水滸g\\docs\\preview\\fx-sheet.png / fx-sheet.jpg
"""
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

PREVIEW = Path(r"D:\水滸g\docs\preview")
FILES = [
    ("fx-light.png", "Light / Counter  - cool white-blue"),
    ("fx-heavy.png", "Heavy / CmdTiger  - pale gold"),
    ("fx-rising.png", "CmdUp  - bright gold upward"),
    ("fx-awaken.png", "Awaken idle  - soft breathing aura"),
    ("fx-super.png", "Super  - gold pulse + wine aura"),
    ("fx-drunk.png", "CmdDrunk  - wine red aura + vapor"),
]

TILE_W, TILE_H = 640, 360
LABEL_H = 26
COLS, ROWS = 3, 2


def main() -> None:
    sheet = Image.new("RGB", (TILE_W * COLS, (TILE_H + LABEL_H) * ROWS), (12, 11, 10))
    draw = ImageDraw.Draw(sheet)
    try:
        font = ImageFont.truetype("arial.ttf", 16)
    except OSError:
        font = ImageFont.load_default()

    for i, (name, label) in enumerate(FILES):
        path = PREVIEW / name
        if not path.exists():
            raise SystemExit(f"missing {path}")
        img = Image.open(path).convert("RGB").resize((TILE_W, TILE_H), Image.LANCZOS)
        col, row = i % COLS, i // COLS
        x = col * TILE_W
        y = row * (TILE_H + LABEL_H)
        draw.rectangle([x, y, x + TILE_W - 1, y + LABEL_H - 1], fill=(24, 20, 16))
        draw.text((x + 10, y + 5), label, font=font, fill=(236, 214, 176))
        sheet.paste(img, (x, y + LABEL_H))

    png = PREVIEW / "fx-sheet.png"
    jpg = PREVIEW / "fx-sheet.jpg"
    sheet.save(png)
    sheet.save(jpg, quality=88)
    print(f"OK {png} {png.stat().st_size} bytes")
    print(f"OK {jpg} {jpg.stat().st_size} bytes")


if __name__ == "__main__":
    main()
