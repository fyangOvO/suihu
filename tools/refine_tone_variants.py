# -*- coding: utf-8 -*-
"""压暗档位对比图（只读）：同一帧的 原图 / gain0.78 / gain0.62 并排放大，供目视定档。"""
import sys
from pathlib import Path

from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parent))
import refine_rules as R

OUT = Path(r"D:\水滸g\game\assets\anim\redraw_clean")
DEST = Path(r"D:\水滸g\docs\preview")
CELL_W, CELL_H, LABEL_H, PAD = 400, 500, 24, 8
BG = (24, 22, 20, 255)
FG = (220, 212, 196, 255)

FRAMES = ["dash.png", "hurt-head.png", "crouch-punch.png", "punch-start.png"]
GAINS = [None, 0.78, 0.62]


def main() -> int:
    canvas = Image.new("RGBA", (PAD + 3 * (CELL_W + PAD),
                                PAD + 26 + len(FRAMES) * (CELL_H + LABEL_H + PAD)), BG)
    d = ImageDraw.Draw(canvas)
    d.text((PAD, 6), "original / gain 0.78 / gain 0.62", fill=FG)
    for row, name in enumerate(FRAMES):
        base = R.load_rgba(OUT / name)
        for col, g in enumerate(GAINS):
            arr = base if g is None else R.apply_tone(base, gain=g)
            im = Image.fromarray(arr, "RGBA")
            im.thumbnail((CELL_W, CELL_H), Image.LANCZOS)
            x = PAD + col * (CELL_W + PAD)
            y = 26 + row * (CELL_H + LABEL_H + PAD)
            canvas.alpha_composite(im, (x + (CELL_W - im.width) // 2, y + LABEL_H))
            m = R.metrics(arr)
            tag = "orig" if g is None else f"g{g}"
            d.text((x + 4, y + 4), f"{name} {tag} bright={m['bright']*100:.2f}% L={m['mean_l']:.1f}",
                   fill=FG)
    DEST.mkdir(parents=True, exist_ok=True)
    out = DEST / "art-tone-variants.png"
    canvas.convert("RGB").save(out, "PNG")
    print(f"written {out} {canvas.size}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
