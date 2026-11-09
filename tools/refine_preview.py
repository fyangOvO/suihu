# -*- coding: utf-8 -*-
"""
精修目视对照图（只读，不修改素材）。
左侧=当前成品，右侧=按 refine_rules 规则预览后的效果：
  上区：8 张飞白偏亮帧（高光压缩）
  下区：6 张 bust 半身帧（顶边对齐到全身帧顶边中位数）
输出 PNG 供编辑器/看图目视确认，不进入仓库素材目录。
"""
import json
import statistics
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

sys.path.insert(0, str(Path(__file__).resolve().parent))
import refine_rules as R

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "anim" / "redraw_clean"
TOOLS = Path(__file__).resolve().parent
DEST = Path(r"D:\水滸g\docs\preview")

BUST = {"drink-prep.png", "drink-tilt.png", "drink.png", "drink-finish.png",
        "draw-knife.png", "drawknife.png"}
AIR = {"jump-up.png", "jump.png", "jump-punch.png", "jump-down.png",
       "jump-slash.png", "launched.png"}
GROUND = {"knockdown.png", "wakeup.png"}

CELL_W, CELL_H = 256, 320
PAD = 10
LABEL_H = 22
BG = (26, 24, 22, 255)
FG_TXT = (214, 206, 190, 255)


def group_of(name: str) -> str:
    if name in BUST:
        return "bust"
    if name in GROUND:
        return "ground"
    if name in AIR:
        return "air"
    return "stand"


def thumb(arr: np.ndarray) -> Image.Image:
    im = Image.fromarray(arr, "RGBA")
    im.thumbnail((CELL_W, CELL_H), Image.LANCZOS)
    return im


def cell(canvas: Image.Image, img: Image.Image, x: int, y: int, label: str) -> None:
    canvas.alpha_composite(img, (x + (CELL_W - img.width) // 2,
                                y + LABEL_H + (CELL_H - img.height) // 2))
    d = ImageDraw.Draw(canvas)
    d.text((x + 4, y + 4), label, fill=FG_TXT)


def main() -> int:
    names = json.loads((TOOLS / "redraw_manifest.json").read_text(encoding="utf-8"))["items"]
    rows = {}
    for it in names:
        p = OUT / it["name"]
        if p.exists():
            rows[it["name"]] = R.metrics(R.load_rgba(p))
    stand_top = int(round(statistics.median(
        [r["y0"] for n, r in rows.items() if group_of(n) == "stand"])))
    print(f"stand top median = {stand_top}")

    tone = sorted(R.TONE_FIX_FRAMES)
    bust = sorted(n for n in rows if group_of(n) == "bust")
    cols = 4
    tone_rows = (len(tone) + cols - 1) // cols
    bust_rows = (len(bust) + cols - 1) // cols
    width = cols * (CELL_W * 2 + PAD) + PAD
    height = PAD + tone_rows * (CELL_H + LABEL_H + PAD) + PAD \
        + bust_rows * (CELL_H + LABEL_H + PAD) + PAD + 30
    canvas = Image.new("RGBA", (width, height), BG)
    d = ImageDraw.Draw(canvas)
    d.text((PAD, 6), "BEFORE | AFTER  (upper: 8 bright frames tone fix / lower: bust top align)",
           fill=FG_TXT)

    y = 26
    for i, name in enumerate(tone):
        r, c = divmod(i, cols)
        base = R.load_rgba(OUT / name)
        after = R.apply_tone(base)
        x = PAD + c * (CELL_W * 2 + PAD)
        cy = y + r * (CELL_H + LABEL_H + PAD)
        cell(canvas, thumb(base), x, cy, f"{name} L={rows[name]['mean_l']:.0f} "
             f"b={rows[name]['bright']*100:.1f}%")
        m2 = R.metrics(after)
        cell(canvas, thumb(after), x + CELL_W, cy, f"after b={m2['bright']*100:.1f}%")

    y += tone_rows * (CELL_H + LABEL_H + PAD) + PAD
    for i, name in enumerate(bust):
        r, c = divmod(i, cols)
        base = R.load_rgba(OUT / name)
        after = R.paste_at_top(base, stand_top)
        x = PAD + c * (CELL_W * 2 + PAD)
        cy = y + r * (CELL_H + LABEL_H + PAD)
        cell(canvas, thumb(base), x, cy, f"{name} top={rows[name]['y0']}")
        cell(canvas, thumb(after), x + CELL_W, cy, f"after top={stand_top}")

    DEST.mkdir(parents=True, exist_ok=True)
    out = DEST / "art-refine-before-after.png"
    canvas.convert("RGB").save(out, "PNG")
    print(f"written {out} ({canvas.width}x{canvas.height})")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
