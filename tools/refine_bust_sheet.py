# -*- coding: utf-8 -*-
"""
bust 与全身帧同画布对位图（只读）：所有帧按 512x640 画布 50% 并排，
画出全身脚底基线（y=612）与 bust 顶边目标线（y=132），直观核对衔接。
"""
import sys
from pathlib import Path

from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parent))
import refine_rules as R

OUT = Path(r"D:\水滸g\game\assets\anim\redraw_clean")
DEST = Path(r"D:\水滸g\docs\preview")
SCALE = 0.5
CELL_W, CELL_H = int(R.CANVAS_W * SCALE), int(R.CANVAS_H * SCALE)
BG = (22, 20, 19, 255)
FG = (210, 202, 186, 255)
LINE = (90, 150, 120, 255)
LINE2 = (170, 120, 90, 255)

FRAMES = ["idle.png", "fighter-stance.png", "walk-a.png",
          "draw-knife.png", "drawknife.png", "drink-prep.png",
          "drink-tilt.png", "drink.png", "drink-finish.png"]


def main() -> int:
    canvas = Image.new("RGBA", (len(FRAMES) * CELL_W, CELL_H + 24), BG)
    d = ImageDraw.Draw(canvas)
    for i, name in enumerate(FRAMES):
        im = Image.fromarray(R.load_rgba(OUT / name), "RGBA")
        im = im.resize((CELL_W, CELL_H), Image.LANCZOS)
        canvas.alpha_composite(im, (i * CELL_W, 24))
        m = R.metrics(R.load_rgba(OUT / name))
        d.text((i * CELL_W + 4, 6), f"{name} top={m['y0']}", fill=FG)
        d.line([(i * CELL_W, 24 + int(612 * SCALE)), (i * CELL_W + CELL_W, 24 + int(612 * SCALE))],
               fill=LINE)
        d.line([(i * CELL_W, 24 + int(R.STAND_TOP_Y * SCALE)),
                (i * CELL_W + CELL_W, 24 + int(R.STAND_TOP_Y * SCALE))], fill=LINE2)
    DEST.mkdir(parents=True, exist_ok=True)
    out = DEST / "art-bust-vs-fullbody.png"
    canvas.convert("RGB").save(out, "PNG")
    print(f"written {out} {canvas.size}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
