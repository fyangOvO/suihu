"""把六姿態老虎原畫拆成 6 張透明底遊戲幀（512x640，底邊對齊 612）。

用法：python -X utf8 tools/build_tiger_frames.py "<姿態原畫>" "<輸出目錄>"

姿態在原畫裡會互相越界（尾巴/爪子伸進鄰格），按列切一定會帶上鄰居的殘肢。
所以先整體去背，再做連通域：取面積最大的 6 個連通域，各自按質心 x 排序，
每個連通域單獨裁框、單獨保留自己的 alpha，最後按站立幀定標並按地面線貼位。
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw
from rembg import remove
from scipy import ndimage

OUT_DIR_DEFAULT = Path(__file__).resolve().parents[1] / "assets" / "anim" / "tiger"
CANVAS = (512, 640)
BASELINE = 612
NAMES = ["idle", "crouch", "pounce", "tail", "leap", "hurt"]
GROUNDED = [0, 1, 3, 5]      # 站立 / 低伏 / 尾掃 / 受擊，腳踩地
TARGET_H = 300               # 站立幀目標高度
TARGET_W = 460               # 單幀最大寬度
MIN_AREA = 50000


def main() -> None:
    src = Path(sys.argv[1])
    out_dir = Path(sys.argv[2]) if len(sys.argv) > 2 else OUT_DIR_DEFAULT
    names = sys.argv[3].split(",") if len(sys.argv) > 3 else NAMES
    grounded = list(range(len(names))) if len(sys.argv) > 3 else GROUNDED
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
    if len(blobs) != len(names):
        raise SystemExit(f"expected {len(names)} blobs, got {len(blobs)}: {[b[0] for b in blobs]}")
    blobs.sort(key=lambda b: b[0])

    pieces = []
    for idx, (_, comp, x0, y0, x1, y1) in enumerate(blobs):
        keep = (lab[y0:y1, x0:x1] == comp)
        sub = rgba[y0:y1, x0:x1].copy()
        sub[:, :, 3] = np.where(keep, sub[:, :, 3], 0)
        pieces.append((Image.fromarray(sub, mode="RGBA"), (x0, y0, x1, y1)))
        print("blob", names[idx], "bbox", (x0, y0, x1, y1), "size", (x1 - x0, y1 - y0))

    ground_y = int(np.median([b[3] for i, (_, b) in enumerate(pieces) if i in grounded]))
    ph = pieces[0][0].height
    pw = pieces[0][0].width
    scale = min(TARGET_H / ph, TARGET_W / pw)
    print("ground_y", ground_y, "scale", round(scale, 4))

    out_dir.mkdir(parents=True, exist_ok=True)
    thumbs = []
    for i, (piece, box) in enumerate(pieces):
        piece = piece.resize((max(1, int(piece.width * scale)), max(1, int(piece.height * scale))),
                             Image.LANCZOS)
        canvas = Image.new("RGBA", CANVAS, (0, 0, 0, 0))
        if i in grounded:
            bottom = BASELINE
        else:
            bottom = min(BASELINE, BASELINE - int(round((ground_y - box[3]) * scale)))
        left = (CANVAS[0] - piece.width) // 2
        top = max(0, bottom - piece.height)
        canvas.alpha_composite(piece, (left, top))
        path = out_dir / f"{names[i]}.png"
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
        draw.text((sx + 6, sy + 4), names[i], fill=(200, 200, 200))
    out_png = Path(r"D:\水滸g\docs\preview\tiger-frames.png")
    out_png.parent.mkdir(parents=True, exist_ok=True)
    sheet.save(out_png)
    print("preview", out_png)


if __name__ == "__main__":
    main()
