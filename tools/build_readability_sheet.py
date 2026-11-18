"""OPT-06 可讀性統計 + 盲測拼圖。

輸入三張實際場景截圖（由 Godot 離屏腳本產生），輸出：
  docs/preview/readability-blind.png  三敵並排（無標籤，供 3 秒盲測）
  stdout READABILITY_STATS           每場景中間調檔位數、暖/冷面積占比
用法：
  python tools/build_readability_sheet.py
"""
from pathlib import Path

from PIL import Image

ROOT = Path(__file__).resolve().parent.parent
PREVIEW = ROOT.parent / "docs" / "preview"

# name, file, crop(x0,y0,x1,y1)
SHOTS = [
    ("corpse", "flow-scn02-corpse.png", (584, 296, 664, 460)),
    ("tiger", "scn03-forest.png", (630, 320, 780, 480)),
    ("boss", "boss-arena.png", (600, 170, 790, 450)),
]

PANEL_W, PANEL_H = 400, 470


def stats(img: Image.Image) -> tuple[int, float, float]:
    """回傳 (中間調檔位數, 暖色占比, 冷色占比)。忽略 HUD 邊條與純黑。"""
    rgb = img.convert("RGB")
    w, h = rgb.size
    px = rgb.load()
    bins = [0] * 20          # 0.00-1.00，步長 0.05
    warm = cool = total = 0
    for y in range(0, h, 2):
        for x in range(0, w, 2):
            r, g, b = px[x, y]
            luma = (0.2126 * r + 0.7152 * g + 0.0722 * b) / 255.0
            bins[min(19, int(luma * 20))] += 1
            total += 1
            if luma < 0.05:
                continue
            if r > 110 and r > b + 26 and r > g + 8:
                warm += 1
            elif b > 110 and b > r + 26:
                cool += 1
    mid = sum(1 for i in range(2, 16) if bins[i] >= total * 0.02)
    return mid, warm / total, cool / total


def build_blind_sheet() -> None:
    sheet = Image.new("RGB", (PANEL_W * len(SHOTS), PANEL_H), (20, 22, 26))
    for i, (name, file, crop) in enumerate(SHOTS):
        src = Image.open(PREVIEW / file).convert("RGB")
        piece = src.crop(crop)
        scale = min((PANEL_W - 32) / piece.width, (PANEL_H - 40) / piece.height)
        piece = piece.resize((int(piece.width * scale), int(piece.height * scale)), Image.LANCZOS)
        x = i * PANEL_W + (PANEL_W - piece.width) // 2
        y = (PANEL_H - piece.height) // 2
        sheet.paste(piece, (x, y))
    out = PREVIEW / "readability-blind.png"
    sheet.save(out)
    print(f"READABILITY_BLIND {out} panels={[s[0] for s in SHOTS]}")


def main() -> None:
    for name, file, crop in SHOTS:
        img = Image.open(PREVIEW / file).convert("RGB")
        mid, warm, cool = stats(img.crop(crop))
        print(f"READABILITY_STATS scene={name} midtones={mid} warm={warm:.1%} cool={cool:.1%}")
    build_blind_sheet()


if __name__ == "__main__":
    main()
