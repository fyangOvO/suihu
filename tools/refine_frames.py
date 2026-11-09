# -*- coding: utf-8 -*-
"""
精修测量 / 应用脚本。

report：只读，输出全套客观指标（包围盒、顶/底边、水平中心、主体亮度、亮像素占比），
        并按分组给出统计与 bust 锚点不变量核对结果。
apply ：按 refine_rules 的规则就地精修：
        1) 8 张飞白偏亮帧高光压缩（只压高光，暗部不动）；
        2) bust 半身帧顶边对齐到全身 stand 帧顶边中位数（只平移不缩放，改善与全身帧切换的头顶跳变）。
        写入 tools/refine_state.json 记录 before/after 哈希，重复运行不再叠加。

用法（在 game 目录）：
  python tools/refine_frames.py report
  python tools/refine_frames.py apply --dry-run
  python tools/refine_frames.py apply
"""
import argparse
import json
import statistics
import sys
from pathlib import Path

import numpy as np
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import refine_rules as R

ROOT = Path(__file__).resolve().parent.parent
OUT = ROOT / "assets" / "anim" / "redraw_clean"
TOOLS = Path(__file__).resolve().parent
MANIFEST = TOOLS / "redraw_manifest.json"
STATE = TOOLS / "refine_state.json"

# 分组以 build_redraw_frames.py 的白名单为准（manifest 的 pose 文字是历史写法，不可靠）
BUST = {"drink-prep.png", "drink-tilt.png", "drink.png", "drink-finish.png",
        "draw-knife.png", "drawknife.png"}
AIR = {"jump-up.png", "jump.png", "jump-punch.png", "jump-down.png",
       "jump-slash.png", "launched.png", "dodge.png", "backstep.png"}
GROUND = {"knockdown.png", "side-fall.png", "prone.png", "kneel.png", "roll.png",
          "land-roll.png", "crawl-up.png", "defeat.png", "wakeup.png",
          "land-stance.png", "duck.png"}

# bust 锚点不变量：半身组统一限高、水平居中、底边随统一锚点浮动
BUST_H_RANGE = (368, 386)
BUST_CX_TOL = 3.0


def pose_tag(name: str) -> str:
    if name in BUST:
        return "bust"
    if name in GROUND:
        return "ground"
    if name in AIR:
        return "air"
    return "stand"


def collect() -> dict:
    items = json.loads(MANIFEST.read_text(encoding="utf-8"))["items"]
    rows, grp = {}, {}
    for it in items:
        name = it["name"]
        p = OUT / name
        if not p.exists():
            print(f"MISSING {name}")
            continue
        arr = R.load_rgba(p)
        rows[name] = R.metrics(arr)
        grp[name] = pose_tag(name)
    return rows, grp


def report() -> int:
    rows, grp = collect()
    print(f"{'frame':18s} {'grp':5s} {'bbox':>11s} {'top':>5s} {'bot':>5s} {'cx':>5s} "
          f"{'L':>6s} {'bright%':>8s} {'fg':>6s}")
    for name, r in sorted(rows.items(), key=lambda kv: kv[0]):
        mark = " <TONE" if name in R.TONE_FIX_FRAMES else ""
        cx = (r["x0"] + r["bw"] / 2.0) if r["bw"] else 0.0
        print(f"{name:18s} {grp[name]:5s} {r['bw']:4d}x{r['bh']:<5d} {r['y0']:5d} "
              f"{r['y0'] + r['bh'] - 1:5d} {cx:5.1f} {r['mean_l']:6.1f} "
              f"{r['bright']*100:7.2f}% {r['fg']:6.3f}{mark}")

    stand_y0 = [r["y0"] for n, r in rows.items() if grp[n] == "stand"]
    stand_top = statistics.median(stand_y0) if stand_y0 else 0
    stand_bright = [r["bright"] for n, r in rows.items() if grp[n] == "stand"]
    tone_bright = [rows[n]["bright"] for n in R.TONE_FIX_FRAMES if n in rows]
    bust = [(n, r) for n, r in rows.items() if grp[n] == "bust"]

    print("\n--- 分组统计 ---")
    print(f"stand 顶边中位数 = {stand_top:.0f}   (顶边范围 {min(stand_y0)}–{max(stand_y0)})")
    print(f"stand 亮度占比中位数 = {statistics.median(stand_bright)*100:.2f}%")
    if tone_bright:
        print(f"8 张亮帧 亮度占比中位数 = {statistics.median(tone_bright)*100:.2f}%")

    print("\n--- bust 锚点核对 ---")
    ok = True
    for n, r in sorted(bust):
        cx = r["x0"] + r["bw"] / 2.0
        in_h = BUST_H_RANGE[0] <= r["bh"] <= BUST_H_RANGE[1]
        in_cx = abs(cx - R.CENTER_X) <= BUST_CX_TOL
        gap = r["y0"] - stand_top
        ok = ok and in_h and in_cx
        print(f"{n:18s} h={r['bh']:4d} {'ok' if in_h else 'OUT'}  "
              f"cx={cx:6.1f} {'ok' if in_cx else 'OUT'}  "
              f"top={r['y0']:4d} 與全身頂邊差 {gap:+4.0f}px")
    print(f"bust 錨點不變量 = {'PASS' if ok else 'FAIL'}")

    out = TOOLS / "refine_report.json"
    out.write_text(json.dumps(
        {"rows": rows, "groups": grp, "stand_top_median": stand_top,
         "bust_anchor_ok": ok, "tone_frames": sorted(R.TONE_FIX_FRAMES)},
        ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"\nwritten {out}")
    return 0


def load_state() -> dict:
    if STATE.exists():
        return json.loads(STATE.read_text(encoding="utf-8"))
    return {"tone": {}, "bust": {}}


def save_state(state: dict) -> None:
    STATE.write_text(json.dumps(state, ensure_ascii=False, indent=2), encoding="utf-8")


def apply(dry_run: bool, align_bust: bool, gain: float, pivot: float) -> int:
    rows, grp = collect()
    stand_top = int(round(statistics.median(
        [r["y0"] for n, r in rows.items() if grp[n] == "stand"])))
    state = load_state()
    changed = 0
    old_gain, old_pivot = R.TONE_HI_GAIN, R.TONE_PIVOT
    R.TONE_HI_GAIN, R.TONE_PIVOT = gain, pivot

    for name in sorted(R.TONE_FIX_FRAMES):
        p = OUT / name
        if not p.exists():
            print(f"SKIP tone {name}: missing")
            continue
        raw = p.read_bytes()
        if state["tone"].get(name, {}).get("after_sha1") == R.sha1_bytes(raw):
            print(f"SKIP tone {name}: already applied")
            continue
        before = rows[name]
        arr = R.apply_tone(R.load_rgba(p))
        after = R.metrics(arr)
        print(f"TONE {name:18s} bright {before['bright']*100:5.2f}% -> {after['bright']*100:5.2f}%  "
              f"L {before['mean_l']:5.1f} -> {after['mean_l']:5.1f}")
        if not dry_run:
            Image.fromarray(arr, "RGBA").save(p, "PNG")
            state["tone"][name] = {"before_sha1": R.sha1_bytes(raw),
                                   "after_sha1": R.sha1_bytes(p.read_bytes())}
        changed += 1

    if align_bust:
        for name in sorted(n for n in rows if grp[n] == "bust"):
            p = OUT / name
            raw = p.read_bytes()
            before = rows[name]
            # 以几何为准判断是否已对齐（paste_at_top 幂等，重复运行不会漂移）
            if abs(before["y0"] - stand_top) <= 2:
                print(f"SKIP bust {name}: top already aligned ({before['y0']})")
                continue
            new = R.paste_at_top(R.load_rgba(p), stand_top)
            after = R.metrics(new)
            print(f"BUST {name:18s} top {before['y0']:4d} -> {after['y0']:4d} "
                  f"(target {stand_top}) h={before['bh']}->{after['bh']} "
                  f"cx={after['x0'] + after['bw'] / 2.0:.1f}")
            if not dry_run:
                Image.fromarray(new, "RGBA").save(p, "PNG")
                state["bust"][name] = {"before_sha1": R.sha1_bytes(raw),
                                       "after_sha1": R.sha1_bytes(p.read_bytes())}
            changed += 1

    if not dry_run:
        state["stand_top"] = stand_top
        state["tone_gain"] = gain
        state["tone_pivot"] = pivot
        save_state(state)
    R.TONE_HI_GAIN, R.TONE_PIVOT = old_gain, old_pivot
    print(f"\n{'DRY-RUN' if dry_run else 'APPLIED'} changed={changed} "
          f"gain={gain} pivot={pivot}")
    return 0


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("mode", choices=["report", "apply"])
    ap.add_argument("--dry-run", action="store_true")
    ap.add_argument("--align-bust", action="store_true",
                    help="把 bust 半身帧顶边对齐到全身帧顶边中位数（只平移不缩放）")
    ap.add_argument("--gain", type=float, default=R.TONE_HI_GAIN)
    ap.add_argument("--pivot", type=float, default=R.TONE_PIVOT)
    args = ap.parse_args()
    return report() if args.mode == "report" else apply(
        args.dry_run, args.align_bust, args.gain, args.pivot)


if __name__ == "__main__":
    raise SystemExit(main())
