# -*- coding: utf-8 -*-
"""
redraw_clean/ 全套客观 diff 辅助（只读、不修改素材）。
对每张成品统计：包围盒宽高、前景占比、主体平均亮度、亮灰半透明边缘占比、
与 idle 基准主色距离；标出离群项，供精修阶段决定是否有限次重出。
不替代人眼目视，只缩小排查范围。
"""
import json
from pathlib import Path

import numpy as np
from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "anim" / "redraw_clean"
MANIFEST = Path(__file__).resolve().parent / "redraw_manifest.json"

BUST = {"drink-prep.png", "drink-tilt.png", "drink.png", "drink-finish.png",
        "draw-knife.png", "drawknife.png"}
AIR = {"jump-up.png", "jump.png", "jump-punch.png", "jump-down.png",
       "jump-slash.png", "launched.png"}
GROUND = {"knockdown.png", "wakeup.png"}


def group_of(name: str) -> str:
    if name in BUST:
        return "bust"
    if name in GROUND:
        return "ground"
    if name in AIR:
        return "air"
    return "stand"


def main() -> int:
    items = json.loads(MANIFEST.read_text(encoding="utf-8"))["items"]
    rows = {}
    ref_mean = None
    for it in items:
        name = it["name"]
        p = OUT / name
        if not p.exists():
            print(f"MISSING {name}")
            continue
        im = np.asarray(Image.open(p).convert("RGBA"))
        a = im[..., 3]
        rgb = im[..., :3].astype(np.float32)
        fg = a > 8
        ys, xs = np.where(fg)
        bw = int(xs.max() - xs.min() + 1) if len(xs) else 0
        bh = int(ys.max() - ys.min() + 1) if len(ys) else 0
        solid = a > 128
        mean_rgb = rgb[solid].mean(axis=0) if solid.any() else np.zeros(3)
        mean_l = float(mean_rgb.mean())
        edge = (a > 0) & (a < 255)
        mx = rgb.max(axis=2)
        mn = rgb.min(axis=2)
        m = rgb.mean(axis=2)
        gray_edge = float((edge & ((mx - mn) < 30) & (m > 92)).mean())
        rows[name] = dict(group=group_of(name), bw=bw, bh=bh,
                         fg=float(fg.mean()), mean_l=mean_l,
                         gray=gray_edge, mean_rgb=mean_rgb)
        if name == "idle.png":
            ref_mean = mean_rgb

    if ref_mean is None:
        print("idle.png missing; cannot compute color distance")
        return 1

    print(f"{'frame':18s} {'grp':6s} {'bbox w×h':>11s} {'fg':>6s} {'L':>6s} {'gray%':>6s} {'dCol':>6s} flags")
    flags_all = []
    for name, r in sorted(rows.items(), key=lambda kv: kv[1]["group"]):
        dist = float(np.linalg.norm(r["mean_rgb"] - ref_mean))
        flags = []
        if r["fg"] < 0.05:
            flags.append("fg-low")
        if r["fg"] > 0.42:
            flags.append("fg-high")
        if r["gray"] > 0.035:
            flags.append("gray-edge")
        if dist > 42:
            flags.append("color-far")
        if r["group"] == "bust" and r["bh"] > 400:
            flags.append("bust-too-tall")
        if flags:
            flags_all.append((name, flags))
        print(f"{name:18s} {r['group']:6s} {r['bw']:4d}×{r['bh']:<4d} "
              f"{r['fg']:6.3f} {r['mean_l']:6.1f} {r['gray']*100:5.2f}% {dist:6.1f} {','.join(flags)}")

    print("\n--- bust 半身帧尺寸（核对与全身帧高度差）---")
    for name, r in rows.items():
        if r["group"] == "bust":
            print(f"{name:18s} bbox={r['bw']}×{r['bh']} fg={r['fg']:.3f}")

    print("\n--- 离群标记 ---")
    if not flags_all:
        print("无客观离群标记（最终仍需编辑器目视脚位/观感）")
    for name, flags in flags_all:
        print(f"{name:18s} {','.join(flags)}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
