from pathlib import Path

import numpy as np
from PIL import Image

p = Path(r"D:\水滸g\docs\preview\tiger-pose-sheet-src.png")
rgb = np.asarray(Image.open(p).convert("RGB")).astype(np.float32)
mx = rgb.max(axis=2) / 255.0
sat = (rgb.max(axis=2) - rgb.min(axis=2)) / np.maximum(rgb.max(axis=2), 1.0)
fg = (mx > 0.30) | (sat > 0.30)
counts = fg.sum(axis=0)
print("total cols", len(counts), "fg frac", round(float(fg.mean()) * 100, 2))
prof = counts.astype(int)
# 每 40 列打印一次均值，观察低谷
for x in range(0, len(prof), 40):
    seg = prof[x:x + 40]
    print(x, int(seg.min()), int(seg.max()), int(seg.mean()))
runs, start = [], None
for i, c in enumerate(counts < 6):
    if c and start is None:
        start = i
    elif not c and start is not None:
        if i - start >= 8:
            runs.append((start, i, i - start))
        start = None
if start is not None and len(counts) - start >= 8:
    runs.append((start, len(counts), len(counts) - start))
print("gaps(c<6,>=8px):", runs)
