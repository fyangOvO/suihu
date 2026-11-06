# -*- coding: utf-8 -*-
"""
统一造型重绘管线（隔离、可回退，不覆盖 assets/anim 原始素材与 clean/ 成品）。
流程：redraw_manifest.json 中的 image_edit 产物 URL -> 下载到 assets/anim/redraw/ 原图存档
      -> rembg(u2net) 去背 -> 碎块连通域清理 + 亮灰半透明边缘去灰
      -> 按 stand/air/ground/bust 分組縮放與錨點 -> 512x640 RGBA -> assets/anim/redraw_clean/。
bust 組：飲酒/拔刀半身特寫，垂直居中偏上、不貼全身腳底基線，避免與全身幀高度差突兀。
"""
import json
import urllib.request
from pathlib import Path

import numpy as np
from PIL import Image

try:
    from scipy import ndimage as _ndi
    HAVE_SCIPY = True
except Exception:
    HAVE_SCIPY = False

ROOT = Path(__file__).resolve().parent.parent
RED = ROOT / "assets" / "anim" / "redraw"
OUT = ROOT / "assets" / "anim" / "redraw_clean"
MANIFEST = Path(__file__).resolve().parent / "redraw_manifest.json"

CANVAS_W, CANVAS_H = 512, 640
BASELINE_Y = 612
CENTER_X = CANVAS_W // 2

# 孤立小连通域（碎飘带/鞋缘碎点）删除阈值（rembg 原图分辨率下的像素数）
DROP_MIN_PX = 140
# 亮灰中性半透明边缘去灰：低饱和且偏亮的半透明边按系数衰减，暗墨衣边不受影响
GRAY_EDGE_SAT = 30
GRAY_EDGE_BRIGHT = 92
GRAY_EDGE_KEEP = 0.35

AIR_NAMES = {"jump-up.png", "jump.png", "jump-punch.png", "jump-down.png",
             "jump-slash.png", "launched.png", "dodge.png", "backstep.png"}
GROUND_NAMES = {"knockdown.png", "side-fall.png", "prone.png", "kneel.png",
                "roll.png", "land-roll.png", "crawl-up.png", "defeat.png",
                "wakeup.png", "land-stance.png", "duck.png"}
# 半身特寫：飲酒（酒具）+ 拔刀（上半身），不按全身腳底錨點
BUST_NAMES = {"drink-prep.png", "drink-tilt.png", "drink.png", "drink-finish.png",
              "draw-knife.png", "drawknife.png"}
GROUP_CFG = {
    "stand": (480.0, 420.0),
    "air": (300.0, 430.0),
    "ground": (210.0, 440.0),
    "bust": (380.0, 400.0),
}


def pose_group(name: str) -> str:
    if name in BUST_NAMES:
        return "bust"
    if name in GROUND_NAMES:
        return "ground"
    if name in AIR_NAMES:
        return "air"
    return "stand"


def clean_alpha(arr: np.ndarray) -> np.ndarray:
    """碎块连通域清理 + 亮灰中性半透明边缘去灰，原地修改并返回。"""
    a = arr[..., 3]
    solid = a > 24
    if HAVE_SCIPY and solid.any():
        lab, _n = _ndi.label(
            solid,
            structure=np.array([[0, 1, 0], [1, 1, 1], [0, 1, 0]], dtype=np.int32),
        )
        sizes = np.bincount(lab.ravel())
        if sizes.size > 1:
            sizes[0] = 0
            small_ids = np.where((sizes > 0) & (sizes < DROP_MIN_PX))[0]
            if small_ids.size:
                a[np.isin(lab, small_ids)] = 0

    edge = (a > 0) & (a < 255)
    rgb = arr[..., :3].astype(np.int16)
    chan_max = rgb.max(axis=2)
    chan_min = rgb.min(axis=2)
    mean = rgb.mean(axis=2)
    neutral = (chan_max - chan_min) < GRAY_EDGE_SAT
    bright = mean > GRAY_EDGE_BRIGHT
    soft = edge & neutral & bright
    a[soft] = (a[soft].astype(np.float32) * GRAY_EDGE_KEEP).astype(np.uint8)
    arr[..., 3] = a
    return arr


def main() -> int:
    manifest = json.loads(MANIFEST.read_text(encoding="utf-8"))
    items = manifest["items"]
    RED.mkdir(parents=True, exist_ok=True)
    OUT.mkdir(parents=True, exist_ok=True)

    from rembg import new_session
    session = new_session("u2net")
    if not HAVE_SCIPY:
        print("[WARN] scipy 不可用：跳过连通域碎块清理，仅做边缘去灰")

    failures = 0
    for item in items:
        name, url = item["name"], item["url"]
        raw_path = RED / name
        req = urllib.request.Request(url, headers={"User-Agent": "Mozilla/5.0"})
        raw_path.write_bytes(urllib.request.urlopen(req, timeout=90).read())

        im = Image.open(raw_path).convert("RGBA")
        cut = __import__("rembg").remove(im, session=session)
        cut = Image.fromarray(clean_alpha(np.asarray(cut).copy()), "RGBA")

        bbox = cut.getbbox()
        if bbox is None:
            print(f"[SKIP empty] {name}")
            failures += 1
            continue
        body = cut.crop(bbox)
        group = pose_group(name)
        target_h, max_w = GROUP_CFG[group]
        bw, bh = body.size
        scale = min(target_h / bh, max_w / bw)
        nw, nh = max(1, round(bw * scale)), max(1, round(bh * scale))
        body = body.resize((nw, nh), Image.LANCZOS)

        canvas = Image.new("RGBA", (CANVAS_W, CANVAS_H), (0, 0, 0, 0))
        if group == "bust":
            oy = (CANVAS_H - nh) // 2 - 24
        else:
            oy = BASELINE_Y - nh
        ox = CENTER_X - nw // 2
        canvas.alpha_composite(body, (ox, oy))

        arr = np.asarray(canvas)
        corners = [arr[0, 0, 3], arr[0, -1, 3], arr[-1, 0, 3], arr[-1, -1, 3]]
        canvas.save(OUT / name, "PNG")
        fg = float((arr[..., 3] > 8).mean())
        print(f"[OK] {name:18s} group={group:6s} size={canvas.size} "
              f"body={nw}x{nh} fg={fg:.4f} corner_alpha={corners}")

    print(f"done {len(items) - failures}/{len(items)} -> {OUT}")
    return 1 if failures else 0


if __name__ == "__main__":
    raise SystemExit(main())
