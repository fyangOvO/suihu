# -*- coding: utf-8 -*-
"""
素材治理施工腳本（docs/07 §5 落地）：把 game/assets/anim/ 的原始姿態檔統一加工為
「真 RGBA 透明 PNG + 同畫布 + 腳底基線對齊」的成品，輸出到 assets/anim/clean/。

設計原則（對應 docs/07 §4.2、§5.1-§5.2）：
1. **原圖不覆蓋、不移除**：所有成品寫入獨立 clean/ 目錄，源素材保留在 anim/ 根，可隨時重建。
2. 去背優先用 rembg(u2net)；模型異常或前景佔比過低時，退回近白閾值法，保證輸出不為空。
3. 統一畫布與腳底基線，避免換幀時角色水平漂移／縮放跳動；不改變角色內部比例（不強拉坐姿）。
4. 成品副檔名一律 .png 且為真 PNG，解決「JPEG 內容偽裝 .png 導致 Godot 報 corrupt」的正名問題。

用法：
    python game/tools/build_anim_frames.py                # 全量處理 anim/*.png -> clean/
    python game/tools/build_anim_frames.py --only idle.png punch-start.png
    python game/tools/build_anim_frames.py --clean-out   # 清空 clean/ 後重建（仍不動原圖）

輸出：
    assets/anim/clean/<原名>.png          # RGBA，統一畫布
    tools/clean_manifest.json             # 每張來源格式、輸出、前景佔比、採用方法
"""
import argparse
import json
import sys
from pathlib import Path

import numpy as np
from PIL import Image

SRC = Path(__file__).resolve().parent.parent / "assets" / "anim"
OUT = SRC / "clean"
MANIFEST = Path(__file__).resolve().parent / "clean_manifest.json"

# 統一畫布（docs/07 §5.2：設計高 480px；此處給出含留白的方形—豎幅畫布）
CANVAS_W = 512
CANVAS_H = 640
TARGET_BODY_H = 480.0     # 站姿裁剪後目標高度（px）
MAX_BODY_W = 420.0        # 寬姿態（橫掃、受擊後仰）不越界
BASELINE_Y = 612          # 腳底對齊的 y（距畫布下緣 28px 安全邊）
CENTER_X = CANVAS_W // 2

# 姿態分組縮放錨點（docs/07 §5.2、§6.5）：三組共用同一條底部參考線 BASELINE_Y，
# 與角色腳底物理原點、命中盒座標保持一致；差別只在目標高度與寬度上限，避免躺地圖被
# 站姿 480px 目標高撐大失真。精細像素貼位仍需在 Godot 編輯器目視微調。
GROUP_CFG = {
    "stand": {"h": TARGET_BODY_H, "maxw": MAX_BODY_W},
    "air": {"h": 300.0, "maxw": 430.0},      # 騰空 / 被擊飛：整體適中，底部參考線不變
    "ground": {"h": 210.0, "maxw": 440.0},   # 躺 / 趴 / 跪 / 起身撐地：著地邊貼線、限高防放大
}
GROUND_NAMES = {
    "knockdown.png", "side-fall.png", "prone.png", "kneel.png", "roll.png",
    "land-roll.png", "crawl-up.png", "defeat.png", "wakeup.png",
    "land-stance.png", "duck.png",
}
AIR_NAMES = {
    "launched.png", "jump-up.png", "jump.png", "jump-punch.png",
    "jump-down.png", "jump-slash.png", "dodge.png", "backstep.png",
}


def pose_group(name: str) -> str:
    if name in GROUND_NAMES:
        return "ground"
    if name in AIR_NAMES:
        return "air"
    return "stand"


def load_rgb(path: Path) -> Image.Image:
    im = Image.open(path)
    return im.convert("RGBA")


def rembg_cutout(im: Image.Image, session) -> Image.Image:
    from rembg import remove
    return remove(im, session=session)


def white_threshold_fallback(im: Image.Image) -> Image.Image:
    """近白背景 → 透明（rembg 不可用時的保底；淺灰陰影可能略有殘留，僅保可用）。"""
    arr = np.asarray(im.convert("RGBA")).astype(np.int16)
    r, g, b = arr[..., 0], arr[..., 1], arr[..., 2]
    near_white = (r > 234) & (g > 234) & (b > 234)
    # 非常接近的灰白邊緣也去背
    near_gray = (abs(r - g) < 8) & (abs(g - b) < 8) & (r > 224)
    arr[..., 3] = np.where(near_white | near_gray, 0, arr[..., 3])
    return Image.fromarray(arr.astype(np.uint8), "RGBA")


def foreground_ratio(im: Image.Image) -> float:
    alpha = np.asarray(im.split()[-1])
    return float((alpha > 8).mean())


def process_one(path: Path, session) -> dict:
    raw = load_rgb(path)
    method = "rembg"
    cut = None
    if session is not None:
        try:
            cand = rembg_cutout(raw, session)
            if foreground_ratio(cand) > 0.015:
                cut = cand
        except Exception as exc:  # 單張失敗不拖垮全量
            method = f"rembg-error:{type(exc).__name__}->fallback"
    if cut is None:
        cut = white_threshold_fallback(raw)
        if method == "rembg":
            method = "white-fallback"

    bbox = cut.getbbox()
    record = {"file": path.name, "method": method, "foreground_ratio": None}
    if bbox is None:
        record["method"] = "empty-skip"
        return record

    body = cut.crop(bbox)
    bw, bh = body.size
    group = pose_group(path.name)
    cfg = GROUP_CFG[group]
    # 站姿高 / 躺地矮 / 騰空適中；三組共用同一底部參考線
    scale = min(cfg["h"] / bh, cfg["maxw"] / bw)
    nw, nh = max(1, round(bw * scale)), max(1, round(bh * scale))
    body = body.resize((nw, nh), Image.LANCZOS)

    canvas = Image.new("RGBA", (CANVAS_W, CANVAS_H), (0, 0, 0, 0))
    x = CENTER_X - nw // 2
    y = BASELINE_Y - nh  # 站姿腳底 / 躺地著地邊 / 騰空最低點，對齊同一參考線
    canvas.alpha_composite(body, (x, y))

    OUT.mkdir(parents=True, exist_ok=True)
    out_path = OUT / path.name
    canvas.save(out_path, "PNG")

    record.update({
        "group": group,
        "bbox": list(bbox),
        "source_size": [bw, bh],
        "scale": round(scale, 4),
        "output_size": [CANVAS_W, CANVAS_H],
        "output": str(out_path.relative_to(Path(__file__).resolve().parent.parent)),
        "foreground_ratio": round(foreground_ratio(canvas), 4),
    })
    return record


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--only", nargs="*", default=[], help="只處理指定檔名")
    ap.add_argument("--clean-out", action="store_true", help="處理前清空 clean/")
    ap.add_argument("--no-rembg", action="store_true", help="強制使用白底閾值法（測試對比）")
    args = ap.parse_args()

    if args.clean_out and OUT.exists():
        for f in OUT.glob("*.png"):
            f.unlink()

    files = sorted(SRC.glob("*.png"))
    # 不把 clean/ 自身納入源（recursive=False 已避免；保險過濾）
    files = [f for f in files if f.parent == SRC]
    if args.only:
        want = set(args.only)
        files = [f for f in files if f.name in want]

    session = None
    if not args.no_rembg:
        try:
            from rembg import new_session
            session = new_session("u2net")
            print("rembg session ready: u2net")
        except Exception as exc:
            print(f"[warn] rembg session 不可用（{exc}），全部改用白底閾值法")

    # 清單合併：--clean-out 以本次全量為準；--only 增量更新時保留其餘歷史記錄，不丟全量盤點
    existing = {}
    if args.clean_out and MANIFEST.exists():
        MANIFEST.unlink()
    elif MANIFEST.exists():
        try:
            old = json.loads(MANIFEST.read_text(encoding="utf-8"))
            existing = {r["file"]: r for r in old if isinstance(r, dict) and "file" in r}
        except Exception:
            existing = {}

    records = []
    for i, path in enumerate(files, 1):
        rec = process_one(path, session)
        records.append(rec)
        tag = rec["method"]
        ratio = rec.get("foreground_ratio")
        print(f"[{i:02d}/{len(files)}] {path.name:20s} {tag:28s} fg={ratio}")

    merged = dict(existing)
    for rec in records:
        merged[rec.get("file", str(id(rec)))] = rec
    all_records = list(merged.values())

    MANIFEST.write_text(json.dumps(all_records, ensure_ascii=False, indent=2), encoding="utf-8")
    done_now = sum(1 for r in records if r.get("output"))
    total_ok = sum(1 for r in all_records if r.get("output"))
    from collections import Counter
    gc = Counter(r.get("group", "?") for r in all_records if r.get("output"))
    print("groups(all):", dict(gc))
    print(f"done(本次): {done_now}/{len(records)} ; manifest(全量): {total_ok} 筆 -> {OUT}")
    print("manifest ->", MANIFEST)


if __name__ == "__main__":
    sys.exit(main())
