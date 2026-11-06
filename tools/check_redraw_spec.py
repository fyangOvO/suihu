# -*- coding: utf-8 -*-
"""redraw_clean/ 統一造型成品規格斷言：與 redraw_manifest.json 清單逐檔核對。
要求：真 PNG、RGBA、512x640、四角完全透明、前景占比 > 2%（防空圖/誤裁空）。
"""
import json
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "anim" / "redraw_clean"
MANIFEST = Path(__file__).resolve().parent / "redraw_manifest.json"

bad = 0
items = json.loads(MANIFEST.read_text(encoding="utf-8"))["items"]
for it in items:
    name = it["name"]
    p = OUT / name
    if not p.exists():
        print(f"MISSING {name}")
        bad += 1
        continue
    im = Image.open(p)
    im.load()
    w, h = im.size
    alpha = im.split()[3]
    ap = alpha.load()
    corners = [ap[0, 0], ap[w - 1, 0], ap[0, h - 1], ap[w - 1, h - 1]]
    fg = float((np.asarray(alpha) > 8).mean())
    cond = (im.mode == "RGBA" and (w, h) == (512, 640)
            and all(c == 0 for c in corners) and fg > 0.02)
    print(f"{'OK  ' if cond else 'BAD '} {name:16s} {im.mode} {im.size} "
          f"fg={fg:.4f} corner_alpha={corners}")
    if not cond:
        bad += 1

# 目录里存在但清单未登记的文件（避免遗留旧风格样板被误播）
expected = {it["name"] for it in items}
stray = [p.name for p in OUT.glob("*.png") if p.name not in expected]
if stray:
    print("STRAY unregistered:", stray)
    bad += len(stray)

print(f"redraw result: {'PASS' if bad == 0 else 'FAIL %d' % bad}")
raise SystemExit(1 if bad else 0)
