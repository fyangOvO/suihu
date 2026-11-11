"""把猛虎 Boss 的四张六格原画拆成 24 张透明底游戏帧（768×768，底边对齐 720）。

用法：python -X utf8 D:\\水滸g\\game\\tools\\build_boss_frames.py
说明：原画六格会出现尾巴/爪子越界，按列硬切会带邻居残肢；这里先整张 rembg，
再按连通域取最大的 6 个主体，各自裁框并只保留自己的 alpha。
每张原画用自己的参考站姿高度做统一缩放，保证四张原画之间 Boss 体型一致。
"""
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw
from rembg import remove
from scipy import ndimage

ROOT = Path(__file__).resolve().parents[1]
PREVIEW = Path(r"D:\水滸g\docs\preview")
OUT_DIR = ROOT / "assets" / "anim" / "boss"
CANVAS = (768, 768)
BASELINE = 720
TARGET_H = 460
TARGET_W = 740
MIN_AREA = 30000

SHEETS = [
    {
        "path": PREVIEW / "boss-common-sheet-src.png",
        "names": ["boss-idle", "boss-walk-1", "boss-walk-2", "boss-crouch", "boss-hurt", "boss-knockdown"],
        "ref_index": 0,
        "grounded": [0, 1, 2, 3, 4, 5],
    },
    {
        "path": PREVIEW / "boss-p1-sheet-src.png",
        "names": ["boss-pounce-1", "boss-pounce-2", "boss-pounce-3", "boss-pounce-4", "boss-pounce-5", "boss-tail-1"],
        "ref_index": 1,
        "grounded": [0, 3, 4, 5],
    },
    {
        "path": PREVIEW / "boss-p2-sheet-src.png",
        "names": ["boss-rear-up", "boss-claw-1", "boss-claw-2", "boss-roar", "boss-summon", "boss-recover"],
        "ref_index": 5,
        "grounded": [0, 1, 2, 3, 4, 5],
    },
    {
        "path": PREVIEW / "boss-p3-sheet-src.png",
        "names": ["boss-iron-tail-1", "boss-iron-tail-2", "boss-iron-tail-3", "boss-death-pounce-1", "boss-death-pounce-2", "boss-pant"],
        "ref_index": 2,
        "grounded": [0, 1, 2, 3, 5],
    },
]


def extract_pieces(path: Path, names: list[str]) -> list[tuple[Image.Image, tuple[int, int, int, int]]]:
    rgba = np.asarray(remove(Image.open(path).convert("RGB")))
    mask = rgba[:, :, 3] > 40
    lab, n = ndimage.label(mask, structure=np.ones((3, 3)))
    sizes = ndimage.sum(mask, lab, range(1, n + 1))
    blobs = []
    for k in range(n):
        if sizes[k] < MIN_AREA:
            continue
        ys, xs = np.where(lab == k + 1)
        blobs.append((float(xs.mean()), k + 1, int(xs.min()), int(ys.min()),
                      int(xs.max()) + 1, int(ys.max()) + 1, float(sizes[k])))
    if len(blobs) != len(names):
        raise SystemExit(f"{path.name}: expected {len(names)} blobs, got {len(blobs)}: "
                         f"{[(b[0], b[6]) for b in blobs]}")
    blobs.sort(key=lambda b: b[0])
    pieces = []
    for idx, (_, comp, x0, y0, x1, y1, _area) in enumerate(blobs):
        keep = (lab[y0:y1, x0:x1] == comp)
        sub = rgba[y0:y1, x0:x1].copy()
        sub[:, :, 3] = np.where(keep, sub[:, :, 3], 0)
        pieces.append((Image.fromarray(sub, mode="RGBA"), (x0, y0, x1, y1)))
        print("  blob", names[idx], "bbox", (x0, y0, x1, y1), "size", (x1 - x0, y1 - y0))
    return pieces


def main() -> None:
    all_pieces = []
    for sheet in SHEETS:
        print("sheet", sheet["path"].name)
        pieces = extract_pieces(sheet["path"], sheet["names"])
        ground_y = int(np.median([pieces[i][1][3] for i in sheet["grounded"]]))
        ref_h = pieces[sheet["ref_index"]][0].height
        max_w = max(p[0].width for p in pieces)
        scale = min(TARGET_H / ref_h, TARGET_W / max_w)
        print("  ground_y", ground_y, "ref_h", ref_h, "scale", round(scale, 4))
        for i, (piece, box) in enumerate(pieces):
            all_pieces.append({
                "name": sheet["names"][i],
                "piece": piece,
                "box": box,
                "ground_y": ground_y,
                "grounded": i in sheet["grounded"],
                "scale": scale,
            })

    OUT_DIR.mkdir(parents=True, exist_ok=True)
    thumbs = []
    for item in all_pieces:
        piece = item["piece"]
        scale = item["scale"]
        piece = piece.resize((max(1, int(piece.width * scale)), max(1, int(piece.height * scale))),
                             Image.LANCZOS)
        canvas = Image.new("RGBA", CANVAS, (0, 0, 0, 0))
        if item["grounded"]:
            bottom = BASELINE
        else:
            bottom = min(BASELINE, BASELINE - int(round((item["ground_y"] - item["box"][3]) * scale)))
        left = (CANVAS[0] - piece.width) // 2
        top = max(0, bottom - piece.height)
        canvas.alpha_composite(piece, (left, top))
        path = OUT_DIR / f"{item['name']}.png"
        canvas.save(path)
        print("saved", path.name, piece.size, "top", top, "bottom", bottom)
        thumbs.append((item["name"], canvas))

    tw, th = 240, 240
    cols, rows = 6, 4
    sheet = Image.new("RGB", (tw * cols, (th + 18) * rows), (32, 33, 31))
    draw = ImageDraw.Draw(sheet)
    for i, (name, canvas) in enumerate(thumbs):
        small = canvas.resize((tw, th), Image.LANCZOS)
        bg = Image.new("RGBA", (tw, th), (32, 33, 31, 255))
        bg.alpha_composite(small)
        sx, sy = (i % cols) * tw, (i // cols) * (th + 18)
        sheet.paste(bg.convert("RGB"), (sx, sy + 18))
        draw.text((sx + 6, sy + 3), name, fill=(210, 210, 200))
    out_png = PREVIEW / "boss-frames-all.png"
    sheet.save(out_png)
    print("preview", out_png)


if __name__ == "__main__":
    main()
