"""BOS-02 六格原画可拆性检查：按等宽六列切分，检查主体是否越列，并出带红线的核查图。
用法：python -X utf8 D:\\水滸g\\game\\tools\\check_boss_sheets.py
输出：D:\\水滸g\\docs\\preview\\boss-sheets-check.png
"""
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(r"D:\水滸g")
PREVIEW = ROOT / "docs" / "preview"
SHEETS = [
    ("P1", PREVIEW / "boss-p1-sheet-src.png"),
    ("P2", PREVIEW / "boss-p2-sheet-src.png"),
    ("P3", PREVIEW / "boss-p3-sheet-src.png"),
]
COLS = 6
THRESHOLD = 40


def analyze(path: Path) -> list[dict]:
    image = Image.open(path).convert("RGB")
    arr = np.asarray(image).astype(np.int16)
    bg = arr[8, 8]
    dist = np.max(np.abs(arr - bg), axis=2)
    mask = dist > THRESHOLD
    col_w = image.width // COLS
    rows = []
    for i in range(COLS):
        x0, x1 = i * col_w, (i + 1) * col_w
        sub = mask[:, x0:x1]
        ys, xs = np.nonzero(sub)
        if len(xs) == 0:
            rows.append({"col": i + 1, "empty": True})
            continue
        rows.append({
            "col": i + 1,
            "empty": False,
            "bbox": (int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max())),
            "touch_left": int(xs.min()) <= 2,
            "touch_right": int(xs.max()) >= col_w - 3,
            "col_w": col_w,
        })
    return rows


def make_preview() -> None:
    panels = []
    for label, path in SHEETS:
        image = Image.open(path).convert("RGB")
        scale = 1800 / image.width
        image = image.resize((1800, max(1, int(image.height * scale))), Image.LANCZOS)
        draw = ImageDraw.Draw(image)
        for i in range(1, COLS):
            x = round(i * image.width / COLS)
            draw.line([(x, 0), (x, image.height)], fill=(220, 40, 40), width=2)
        draw.rectangle([0, 0, 74, 26], fill=(20, 20, 20))
        draw.text((6, 6), label, fill=(240, 220, 150))
        panels.append(image)
    width = max(p.width for p in panels)
    height = sum(p.height for p in panels) + 10 * (len(panels) - 1)
    sheet = Image.new("RGB", (width, height), (24, 24, 22))
    y = 0
    for panel in panels:
        sheet.paste(panel, (0, y))
        y += panel.height + 10
    sheet.save(PREVIEW / "boss-sheets-check.png")


for label, path in SHEETS:
    print(f"--- {label} {path.name}")
    for row in analyze(path):
        if row["empty"]:
            print(f"  col{row['col']}: EMPTY")
            continue
        x0, y0, x1, y1 = row["bbox"]
        print(
            f"  col{row['col']}: bbox=({x0},{y0})-({x1},{y1}) "
            f"touch_left={row['touch_left']} touch_right={row['touch_right']}"
        )

make_preview()
print("preview:", PREVIEW / "boss-sheets-check.png")
