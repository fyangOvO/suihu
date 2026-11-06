# -*- coding: utf-8 -*-
"""
靜態交叉校驗：data/action_frame_data.gd 的每條 visual.frames 是否都能在成品目錄
（assets/anim/clean/ 優先，回退 assets/anim/）找到對應檔案；並統計 P0 實際幀數。
只讀不寫。用法：python game/tools/verify_frame_links.py
"""
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
DATA = ROOT / "data" / "action_frame_data.gd"
CLEAN = ROOT / "assets" / "anim" / "clean"
RAW = ROOT / "assets" / "anim"

text = DATA.read_text(encoding="utf-8")

# 逐行狀態機：頂層動作 key（行尾單獨 {）切換當前動作；內層 logic/visual/invuln 行排除
referenced = {}
cur = None
for line in text.splitlines():
    km = re.match(r'\s*"([A-Za-z0-9_]+)":\s*\{', line)
    if km and ("startup" not in line and '"fps"' not in line and "invuln" not in line):
        cur = km.group(1)
        continue
    fm = re.search(r'"frames"\s*:\s*\[([^\]]*)\]', line)
    if fm and cur:
        referenced[cur] = re.findall(r'"([\w.\-]+\.png)"', fm.group(1))

clean_set = {p.name for p in CLEAN.glob("*.png")} if CLEAN.exists() else set()
raw_set = {p.name for p in RAW.glob("*.png") if p.parent == RAW}

missing = []
for action, files in referenced.items():
    for f in files:
        if f not in clean_set and f not in raw_set:
            missing.append((action, f))

P0 = ["Idle", "Walk", "Light1", "Light2", "Light3", "Heavy", "Block", "HurtStand"]
print("== P0 實際引用幀數 ==")
for a in P0:
    if a in referenced:
        n = len(referenced[a])
        exist = sum(1 for f in referenced[a] if f in clean_set)
        print(f"{a:10s} 引用 {n} 幀 / clean 存在 {exist}：{referenced[a]}")

print("\n== 全部動作引用 ==")
total_ref = sum(len(v) for v in referenced.values())
print(f"動作數={len(referenced)} 引用幀槽={total_ref} clean 成品={len(clean_set)} 原始素材={len(raw_set)}")

if missing:
    print("\n== 缺失（任何目錄都找不到）==")
    for a, f in missing:
        print(f"  {a}: {f}")
    raise SystemExit(1)
print("\n全部引用檔都可在 clean/ 或原始目錄解析，無斷鏈。")
