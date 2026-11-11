"""把六姿態老虎伥鬼原畫拆成 6 張透明底遊戲幀（512x640，底邊對齊 612）。

用法：python -X utf8 tools/build_corpse_ghost_frames.py "<姿態原畫>" ["<輸出目錄>"]

六格姿勢可能互相越界（木棍/手臂伸進鄰格），所以先整體去背，再按 alpha 連通域
取面積最大的 6 塊，各自按質心 x 排序，逐塊保留自己的 alpha，最後按站立幀定標、
按地面線貼位。輸出可被 rigged_fighter 的 ANIM_DIRS 直接讀取。
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw
from rembg import remove
from scipy import ndimage

OUT_DIR_DEFAULT = Path(__file__).resolve().parents[1] / "assets" / "anim" / "corpse_ghost"
CANVAS = (512, 640)
BASELINE = 612
NAMES = ["idle", "walk-a", "walk-b", "thrust", "smash", "hurt"]
TARGET_H = 285               # 比武松略矮，保留乾瘦佝僂的體型差
TARGET_W = 460
MIN_AREA = 40000


def main() -> None:
    src = Path(sys.argv[1])
    out_dir = Path(sys.argv[2]) if len(sys.argv) > 2 else OUT_DIR_DEFAULT
    rgba = np.asarray(remove(Image.open(src).convert("RGB")))
    mask = rgba[:, :, 3] > 40
    lab, n = ndimage.label(mask, structure=np.ones((3, 3)))
    sizes = ndimage.sum(mask, lab, range(1, n + 1))
    blobs = []
    for k in range(n):
        if sizes[k] < MIN_AREA:
            continue
        ys, xs = np.where(lab == k + 1)
        blobs.append((float(xs.mean()), k + 1, int(xs.min()), int(ys.min()),
                      int(xs.max()) + 1, int(ys.max()) + 1))
    if len(blobs) != len(NAMES):
        raise SystemExit(f"expected {len(NAMES)} blobs, got {len(blobs)}: {[round(b[0]) for b in blobs]}")
    blobs.sort(key=lambda b: b[0])

    pieces = []
    for idx, (_, comp, x0, y0, x1, y1) in enumerate(blobs):
        keep = (lab[y0:y1, x0:x1] == comp)
        sub = rgba[y0:y1, x0:x1].copy()
        sub[:, :, 3] = np.where(keep, sub[:, :, 3], 0)
        pieces.append((Image.fromarray(sub, mode="RGBA"), (x0, y0, x1, y1)))
        print("blob", NAMES[idx], "bbox", (x0, y0, x1, y1), "size", (x1 - x0, y1 - y0))

    ground_y = int(np.median([b[3] for _, b in pieces]))
    scale = min(TARGET_H / pieces[0][0].height, TARGET_W / pieces[0][0].width)
    print("ground_y", ground_y, "scale", round(scale, 4))

    out_dir.mkdir(parents=True, exist_ok=True)
    thumbs = []
    for i, (piece, box) in enumerate(pieces):
        piece = piece.resize((max(1, int(piece.width * scale)), max(1, int(piece.height * scale))),
                             Image.LANCZOS)
        canvas = Image.new("RGBA", CANVAS, (0, 0, 0, 0))
        bottom = BASELINE
        left = (CANVAS[0] - piece.width) // 2
        top = max(0, bottom - piece.height)
        canvas.alpha_composite(piece, (left, top))
        path = out_dir / f"{NAMES[i]}.png"
        canvas.save(path)
        print("saved", path, piece.size, "top", top, "bottom", bottom)
        thumbs.append(canvas)

    tw, th = 256, 320
    sheet = Image.new("RGB", (tw * 3, th * 2 + 24), (36, 38, 36))
    draw = ImageDraw.Draw(sheet)
    for i, t in enumerate(thumbs):
        small = t.resize((tw, th), Image.LANCZOS)
        bg = Image.new("RGBA", (tw, th), (36, 38, 36, 255))
        bg.alpha_composite(small)
        sx, sy = (i % 3) * tw, (i // 3) * (th + 12)
        sheet.paste(bg.convert("RGB"), (sx, sy))
        draw.text((sx + 6, sy + 4), NAMES[i], fill=(200, 200, 200))
    out_png = Path(r"D:\水滸g\docs\preview\corpse-ghost-frames.png")
    out_png.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(out_png)
    print("preview", out_png)


if __name__ == "__main__":
    main()
