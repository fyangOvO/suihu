# -*- coding: utf-8 -*-
"""
逐帧离群断言（带阈值、可回归）。只读，不改素材。

阈值分两类：
- 硬性（FAIL，退出码 1）：尺寸/锚点/前景占比/主色距 —— 这些能由管线与锚点规则直接修；
- 软性（INFO）：灰边占比 —— 水墨飞白与去背白边在数值上重叠，必须目视，不按阈值重出。

用法：python tools/check_frame_outliers.py
"""
import json
import statistics
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
import refine_rules as R

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "anim" / "redraw_clean"
TOOLS = Path(__file__).resolve().parent

BUST = {"drink-prep.png", "drink-tilt.png", "drink.png", "drink-finish.png",
        "draw-knife.png", "drawknife.png"}
AIR = {"jump-up.png", "jump.png", "jump-punch.png", "jump-down.png",
       "jump-slash.png", "launched.png", "dodge.png", "backstep.png"}
GROUND = {"knockdown.png", "side-fall.png", "prone.png", "kneel.png", "roll.png",
          "land-roll.png", "crawl-up.png", "defeat.png", "wakeup.png",
          "land-stance.png", "duck.png"}

# 阈值表
FG_MIN, FG_MAX = 0.05, 0.42
MEAN_L_MIN, MEAN_L_MAX = 42.0, 78.0
COLOR_FAR = 42.0
BRIGHT_MAX = 3.0          # 亮像素（L>200）占前景比上限；8 张飞白帧压暗后应低于此值
GRAY_EDGE_INFO = 3.5      # 灰边占比，仅提示
CX_TOL = 4.0
TOP_TOL = 6.0             # bust 顶边与全身顶边的允许差
BUST_H = (368, 386)
BASELINE_Y = 612


def group_of(name: str) -> str:
    if name in BUST:
        return "bust"
    if name in GROUND:
        return "ground"
    if name in AIR:
        return "air"
    return "stand"


def main() -> int:
    items = json.loads((TOOLS / "redraw_manifest.json").read_text(encoding="utf-8"))["items"]
    frames = {}
    for it in items:
        p = OUT / it["name"]
        if not p.exists():
            print(f"MISSING {it['name']}")
            return 1
        arr = R.load_rgba(p)
        m = R.metrics(arr)
        rgb = arr[..., :3].astype(np.float32)
        a = arr[..., 3]
        solid = a > 128
        m["mean_rgb"] = rgb[solid].mean(axis=0) if solid.any() else np.zeros(3)
        edge = (a > 0) & (a < 255)
        mx, mn, ml = rgb.max(axis=2), rgb.min(axis=2), rgb.mean(axis=2)
        m["gray"] = float((edge & ((mx - mn) < 30) & (ml > 92)).mean())
        frames[it["name"]] = m

    ref = frames.get("idle.png", {}).get("mean_rgb")
    if ref is None:
        print("idle.png missing: cannot compute color distance")
        return 1

    stand_top = statistics.median(
        [m["y0"] for n, m in frames.items() if group_of(n) == "stand"])
    fails, infos = [], []

    print(f"full-body top median = {stand_top:.0f}; bust target = {R.STAND_TOP_Y}")
    for name, m in sorted(frames.items()):
        g = group_of(name)
        cx = m["x0"] + m["bw"] / 2.0
        flags = []
        if not (FG_MIN <= m["fg"] <= FG_MAX):
            flags.append(f"fg={m['fg']:.3f}")
        if not (MEAN_L_MIN <= m["mean_l"] <= MEAN_L_MAX):
            flags.append(f"L={m['mean_l']:.1f}")
        if float(np.linalg.norm(m["mean_rgb"] - ref)) > COLOR_FAR:
            flags.append("color-far")
        if m["bright"] > BRIGHT_MAX:
            flags.append(f"bright={m['bright']*100:.2f}%")
        if abs(cx - R.CENTER_X) > CX_TOL:
            flags.append(f"cx={cx:.1f}")
        if g != "air" and g != "ground" and not (m["y0"] <= BASELINE_Y):
            flags.append("below-baseline")
        if g == "bust":
            if not (BUST_H[0] <= m["bh"] <= BUST_H[1]):
                flags.append(f"bust-h={m['bh']}")
            if abs(m["y0"] - stand_top) > TOP_TOL:
                flags.append(f"bust-top={m['y0']}(gap {m['y0'] - stand_top:+.0f})")
        if m["gray"] * 100 > GRAY_EDGE_INFO:
            infos.append((name, f"gray-edge {m['gray']*100:.2f}%"))
        if flags:
            fails.append((name, flags))

    print(f"\n{len(frames)} frames checked")
    if fails:
        print("--- FAIL ---")
        for name, flags in fails:
            print(f"{name:18s} {', '.join(flags)}")
    else:
        print("--- FAIL: none ---")
    if infos:
        print("--- INFO (需目視，不判 FAIL) ---")
        for name, s in infos:
            print(f"{name:18s} {s}")
    print(f"\nOUTLIER_CHECK result={'FAIL' if fails else 'PASS'} fails={len(fails)} info={len(infos)}")
    return 1 if fails else 0


if __name__ == "__main__":
    raise SystemExit(main())
