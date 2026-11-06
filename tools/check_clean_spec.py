# -*- coding: utf-8 -*-
"""
成品規格驗收（docs/07 §5.2）：assets/anim/clean/ 每張必須是
真 PNG、RGBA、統一畫布尺寸、四角落透明（無白底殘留）。只讀檢查，不符則 exit 1。
用法：python game/tools/check_clean_spec.py
"""
from collections import Counter
from pathlib import Path
from PIL import Image

CLEAN = Path(__file__).resolve().parent.parent / "assets" / "anim" / "clean"
EXPECT_SIZE = (512, 640)

def main():
    files = sorted(CLEAN.glob("*.png"))
    size_c, mode_c = Counter(), Counter()
    bad_size, bad_mode, bad_corner, corrupt = [], [], [], []
    for f in files:
        try:
            im = Image.open(f)
            im.load()
        except Exception:
            corrupt.append(f.name)
            continue
        size_c[im.size] += 1
        mode_c[im.mode] += 1
        if im.size != EXPECT_SIZE:
            bad_size.append((f.name, im.size))
        if im.mode not in ("RGBA", "LA"):
            bad_mode.append((f.name, im.mode))
        else:
            a = im.split()[-1]
            w, h = im.size
            corners = [a.getpixel((0, 0)), a.getpixel((w - 1, 0)),
                       a.getpixel((0, h - 1)), a.getpixel((w - 1, h - 1))]
            if any(v != 0 for v in corners):
                bad_corner.append((f.name, corners))

    print(f"clean 檔數：{len(files)}")
    print("尺寸分佈：", dict(size_c))
    print("色彩模式分佈：", dict(mode_c))
    problems = corrupt or bad_size or bad_mode or bad_corner
    if corrupt:
        print("無法解碼（非真 PNG）：", corrupt)
    if bad_size:
        print("尺寸不符：", bad_size[:10])
    if bad_mode:
        print("非透明模式：", bad_mode[:10])
    if bad_corner:
        print("角落非全透明（白底殘留風險）：", bad_corner[:10])
    if problems:
        raise SystemExit(1)
    print("全部成品符合：真 PNG / RGBA / 512x640 / 四角透明。")

if __name__ == "__main__":
    main()
