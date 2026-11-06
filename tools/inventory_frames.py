# -*- coding: utf-8 -*-
"""盘点帧表实际引用帧：去重、按 pose_group 分类、标注是否已重绘/在 clean。
输出控制台汇总 + tools/redraw_targets.json，作为范围 C 批量重绘的客观依据。"""
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GD = ROOT / "data" / "action_frame_data.gd"
OUT_JSON = Path(__file__).resolve().parent / "redraw_targets.json"

AIR_NAMES = {"jump-up.png", "jump.png", "jump-punch.png", "jump-down.png",
             "jump-slash.png", "launched.png", "dodge.png", "backstep.png"}
GROUND_NAMES = {"knockdown.png", "side-fall.png", "prone.png", "kneel.png",
                "roll.png", "land-roll.png", "crawl-up.png", "defeat.png",
                "wakeup.png", "land-stance.png", "duck.png"}


def group_of(n: str) -> str:
    if n in GROUND_NAMES:
        return "ground"
    if n in AIR_NAMES:
        return "air"
    return "stand"


text = GD.read_text(encoding="utf-8")
current = None
action_frames: dict = {}
for line in text.splitlines():
    act = re.match(r'^\s*"([A-Za-z0-9_]+)"\s*:\s*\{', line)
    if act:
        current = act.group(1)
    fr = re.search(r'frames"\s*:\s*\[(.*?)\]', line)
    if fr and current:
        names = re.findall(r'"([^"]+\.png)"', fr.group(1))
        action_frames.setdefault(current, []).extend(names)

all_frames = sorted({n for v in action_frames.values() for n in v})
redrawn = {p.name for p in (ROOT / "assets" / "anim" / "redraw_clean").glob("*.png")}
clean = {p.name for p in (ROOT / "assets" / "anim" / "clean").glob("*.png")}

rows = []
for n in all_frames:
    rows.append({
        "frame": n,
        "group": group_of(n),
        "redrawn": n in redrawn,
        "in_clean": n in clean,
        "used_by": [a for a, fs in action_frames.items() if n in fs],
    })

pending = [r for r in rows if not r["redrawn"]]
by_group = {"stand": [], "air": [], "ground": []}
for r in pending:
    by_group[r["group"]].append(r["frame"])

OUT_JSON.write_text(json.dumps({
    "total_unique": len(all_frames),
    "redrawn": len(redrawn & set(all_frames)),
    "pending_count": len(pending),
    "pending_by_group": by_group,
    "rows": rows,
}, ensure_ascii=False, indent=2), encoding="utf-8")

print(f"唯一被引用帧={len(all_frames)}  已重绘={len(redrawn & set(all_frames))}  待处理={len(pending)}")
for g in ("stand", "air", "ground"):
    print(f"\n[{g}] 待处理 {len(by_group[g])} 张:")
    for f in by_group[g]:
        print("  -", f)
missing = [r["frame"] for r in rows if not r["in_clean"]]
if missing:
    print("\n在 clean 缺失(需原始目录兜底):", missing)
print("\n明细已写:", OUT_JSON)
