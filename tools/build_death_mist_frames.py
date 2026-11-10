"""把六格烟雾序列原画拆成 6 张透明底游戏帧（512x640，底边对齐 612）。

用法：python -X utf8 tools/build_death_mist_frames.py "<序列原画本地路径>"
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image

OUT_DIR = Path(__file__).resolve().parents[1] / "assets" / "fx" / "death_mist"
CANVAS = (512, 640)
BASELINE = 612
THRESH = 14          # 0-255，低于此视为纯黑背景
MIN_RUN = 30         # 列连通块最小宽度
MIN_GAP = 18         # 小于此空隙合并为同一格


def find_panels(lum: np.ndarray) -> list[tuple[int, int]]:
    cols = lum.max(axis=0) > THRESH
    runs: list[tuple[int, int]] = []
    start = None
    for i, on in enumerate(cols):
        if on and start is None:
            start = i
        elif not on and start is not None:
            runs.append((start, i))
            start = None
    if start is not None:
        runs.append((start, len(cols)))
    merged = []
    for r in runs:
        if merged and r[0] - merged[-1][1] < MIN_GAP:
            merged[-1] = (merged[-1][0], r[1])
        else:
            merged.append(r)
    return [r for r in merged if r[1] - r[0] >= MIN_RUN]


def build_frame(rgb: np.ndarray, box: tuple[int, int, int, int]) -> Image.Image:
    x0, x1, y0, y1 = box
    crop = rgb[y0:y1, x0:x1]
    lum = crop.max(axis=2).astype(np.float32) / 255.0
    alpha = np.clip((lum - 0.06) / 0.94, 0.0, 1.0) ** 1.05
    alpha = np.clip(alpha * 1.5, 0.0, 1.0)

    r = 0.16 + 0.36 * lum
    g = 0.28 + 0.55 * lum
    b = 0.23 + 0.38 * lum
    rgba = np.stack([r, g, b, alpha], axis=2)
    img = Image.fromarray((rgba * 255).astype(np.uint8), mode="RGBA")

    w, h = img.size
    scale = min(300.0 / w, 560.0 / h)
    img = img.resize((max(1, int(round(w * scale))), max(1, int(round(h * scale)))), Image.LANCZOS)

    canvas = Image.new("RGBA", CANVAS, (0, 0, 0, 0))
    paste_x = (CANVAS[0] - img.width) // 2
    paste_y = BASELINE - img.height
    canvas.alpha_composite(img, (paste_x, paste_y))
    return canvas


def main() -> None:
    src = Path(sys.argv[1])
    rgb = np.asarray(Image.open(src).convert("RGB"))
    lum = rgb.max(axis=2).astype(np.uint8)
    panels = find_panels(lum)
    print("panels:", panels)
    if len(panels) != 6:
        print("WARN: 未找到 6 格，改用等宽六分", file=sys.stderr)
        w = rgb.shape[1] // 6
        panels = [(i * w, (i + 1) * w) for i in range(6)]

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    for idx, (x0, x1) in enumerate(panels, start=1):
        sub = lum[:, x0:x1]
        rows = np.where(sub.max(axis=1) > THRESH)[0]
        y0 = max(0, int(rows.min()) - 6)
        y1 = min(rgb.shape[0], int(rows.max()) + 7)
        img = build_frame(rgb, (x0, x1, y0, y1))
        path = OUT_DIR / f"mist_{idx:02d}.png"
        img.save(path)
        print("saved", path, img.size)


if __name__ == "__main__":
    main()
