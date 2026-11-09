# -*- coding: utf-8 -*-
"""46 帧总览图（只读）：按分组排序，每帧 1/3 缩放贴在同一基线上，供整套目视。"""
import json
import sys
from pathlib import Path

from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parent))
import refine_rules as R

OUT = Path(r"D:\水滸g\game\assets\anim\redraw_clean")
TOOLS = Path(r"D:\水滸g\game\tools")
DEST = Path(r"D:\水滸g\docs\preview")
S = 1 / 3.0
CW, CH = int(R.CANVAS_W * S), int(R.CANVAS_H * S)   # 170x213
COLS = 8
BG = (22, 20, 19, 255)
FG = (206, 198, 182, 255)
BASE = (240, 190, 120, 255)

BUST = {"drink-prep.png", "drink-tilt.png", "drink.png", "drink-finish.png",
        "draw-knife.png", "drawknife.png"}
AIR = {"jump-up.png", "jump.png", "jump-punch.png", "jump-down.png",
       "jump-slash.png", "launched.png"}
GROUND = {"knockdown.png", "wakeup.png"}
ORDER = ["stand", "air", "ground", "bust"]


def g(name):
    if name in BUST:
        return "bust"
    if name in GROUND:
        return "ground"
    if name in AIR:
        return "air"
    return "stand"


def main() -> int:
    names = [it["name"] for it in json.loads(
        (TOOLS / "redraw_manifest.json").read_text(encoding="utf-8"))["items"]]
    names = [n for n in names if (OUT / n).exists()]
    names.sort(key=lambda n: (ORDER.index(g(n)), n))
    rows = (len(names) + COLS - 1) // COLS
    canvas = Image.new("RGBA", (COLS * CW, rows * CH), BG)
    d = ImageDraw.Draw(canvas)
    for i, name in enumerate(names):
        r, c = divmod(i, COLS)
        im = Image.fromarray(R.load_rgba(OUT / name), "RGBA").resize((CW, CH), Image.LANCZOS)
        canvas.alpha_composite(im, (c * CW, r * CH))
        d.text((c * CW + 2, r * CH + 1), name, fill=FG)
        y = r * CH + int((R.CANVAS_H - 1) * S)
        d.line([(c * CW, y), (c * CW + CW - 1, y)], fill=BASE)
    DEST.mkdir(parents=True, exist_ok=True)
    out = DEST / "art-all-frames.png"
    canvas.convert("RGB").save(out, "PNG")
    print(f"written {out} {canvas.size} frames={len(names)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
