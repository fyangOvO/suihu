from pathlib import Path
from PIL import Image, ImageDraw

SRC = Path(r"D:\水滸g\game\assets\anim\tiger")
OUT = Path(r"D:\水滸g\docs\preview\tiger-frames-all.png")
NAMES = ["idle", "walk-1", "walk-2", "crouch", "pounce", "tail", "leap", "hurt", "hurt-2", "knockdown"]
COLS, CELL_W, CELL_H, PAD = 4, 300, 400, 10


def main() -> None:
    rows = (len(NAMES) + COLS - 1) // COLS
    sheet = Image.new("RGB", (COLS * (CELL_W + PAD) + PAD, rows * (CELL_H + PAD) + PAD), (32, 34, 38))
    draw = ImageDraw.Draw(sheet)
    for i, name in enumerate(NAMES):
        img = Image.open(SRC / f"{name}.png").convert("RGBA")
        img.thumbnail((CELL_W, CELL_H - 24), Image.LANCZOS)
        col, row = i % COLS, i // COLS
        x = PAD + col * (CELL_W + PAD)
        y = PAD + row * (CELL_H + PAD)
        draw.rectangle([x, y, x + CELL_W, y + CELL_H], fill=(45, 47, 52))
        draw.line([x, y + CELL_H - 18, x + CELL_W, y + CELL_H - 18], fill=(90, 92, 98))
        draw.text((x + 6, y + 3), name, fill=(230, 220, 200))
        sheet.paste(img, (x + (CELL_W - img.width) // 2, y + CELL_H - 18 - img.height), img)
    sheet.save(OUT)
    print("SAVED", OUT, sheet.size)


if __name__ == "__main__":
    main()
