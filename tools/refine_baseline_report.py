# -*- coding: utf-8 -*-
"""全身帧脚位/重心核对（只读）：输出每组底边与基线差、包围盒中心，找浮空或压线的帧。"""
import json
import statistics
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import refine_rules as R

OUT = Path(r"D:\水滸g\game\assets\anim\redraw_clean")
TOOLS = Path(r"D:\水滸g\game\tools")
BASELINE = 612
BUST = {"drink-prep.png", "drink-tilt.png", "drink.png", "drink-finish.png",
        "draw-knife.png", "drawknife.png"}
AIR = {"jump-up.png", "jump.png", "jump-punch.png", "jump-down.png",
       "jump-slash.png", "launched.png"}
GROUND = {"knockdown.png", "wakeup.png"}


def g(name):
    if name in BUST:
        return "bust"
    if name in GROUND:
        return "ground"
    if name in AIR:
        return "air"
    return "stand"


def main() -> int:
    items = json.loads((TOOLS / "redraw_manifest.json").read_text(encoding="utf-8"))["items"]
    rows = {}
    for it in items:
        p = OUT / it["name"]
        if p.exists():
            rows[it["name"]] = R.metrics(R.load_rgba(p))
    print(f"{'frame':18s} {'grp':5s} {'top':>5s} {'bottom':>6s} {'vs612':>6s} {'h':>4s} {'cx':>6s}")
    for name, m in sorted(rows.items()):
        bottom = m["y0"] + m["bh"] - 1
        cx = m["x0"] + m["bw"] / 2.0
        print(f"{name:18s} {g(name):5s} {m['y0']:5d} {bottom:6d} {bottom - BASELINE:+6d} "
              f"{m['bh']:4d} {cx:6.1f}")
    stand = [(n, m) for n, m in rows.items() if g(n) == "stand"]
    gaps = [m["y0"] + m["bh"] - 1 - BASELINE for _n, m in stand]
    print(f"\nstand bottom 中位 {statistics.median(gaps):+.0f}px，范围 {min(gaps):+d}~{max(gaps):+d}")
    print("浮空（bottom < 609）:", [n for n, m in stand if m["y0"] + m["bh"] - 1 < 609])
    print("压线（bottom > 615）:", [n for n, m in stand if m["y0"] + m["bh"] - 1 > 615])
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
