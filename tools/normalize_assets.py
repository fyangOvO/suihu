# -*- coding: utf-8 -*-
"""
素材盤點工具（唯讀：只掃描、只輸出清單，絕不修改或搬動任何素材）
用途：配合 docs/07-動畫幀毫秒映射規格.md §4，盤點 game/assets/anim/ 下每個檔的
     真實格式、尺寸、是否有透明通道，並按推測動作分類，輸出 markdown + json。

用法（在工程根或任意目錄皆可）：
    python game/tools/normalize_assets.py
    python game/tools/normalize_assets.py --dir game/assets/anim
說明：
- 不做去背、不轉檔、不更名；那些屬於下一步人工/rembg 工序。
- 若環境裝了 Pillow，會補讀 JPEG 的尺寸；沒有則尺寸記 null，不影響格式判斷。
"""
import argparse
import json
import struct
from pathlib import Path

# 檔名關鍵字 → 推測動作分類（用於盤點匯總，不等於最終 spec 綁定）
CATEGORY_RULES = [
    ("Idle", ["idle", "fighter-stance"]),
    ("Walk", ["walk"]),
    ("Crouch", ["crouch", "duck", "guard-crouch", "kneel", "prone"]),
    ("AirJump", ["jump"]),
    ("Evade", ["dash", "dodge", "roll", "backstep", "back-dodge", "slide", "spin", "lunge"]),
    ("LightAttack", ["punch", "combo-punch", "double-palm", "rising-punch"]),
    ("HeavyAttack", ["heavy", "heavyslash", "kick", "elbow", "knee", "headbutt", "spin-kick"]),
    ("Knife", ["knife", "drawknife", "draw-knife", "sheath"]),
    ("Block", ["block", "guard"]),
    ("Hurt", ["hurt", "launched"]),
    ("Down", ["knockdown", "side-fall", "crawl", "land-", "prone"]),
    ("Drink", ["drink"]),
    ("Performance", ["defeat", "victory", "awaken", "roar", "meditate", "bow"]),
]

try:
    from PIL import Image  # type: ignore
    _PIL = True
except Exception:
    _PIL = False


def classify(name: str) -> str:
    low = name.lower()
    for cat, keys in CATEGORY_RULES:
        if any(k in low for k in keys):
            return cat
    return "Unassigned"


def inspect_png(data: bytes):
    # IHDR: width(16:20) height(20:24) bitdepth(24) colortype(25)
    w, h = struct.unpack(">II", data[16:24])
    color_type = data[25]
    has_alpha = color_type in (4, 6)  # LA / RGBA
    return w, h, has_alpha


def inspect(path: Path):
    head = path.read_bytes()[:32]
    if head[:8] == b"\x89PNG\r\n\x1a\n":
        w, h, has_alpha = inspect_png(path.read_bytes()[:33])
        return {"format": "PNG", "width": w, "height": h, "has_alpha": has_alpha}
    if head[8:12] == b"WEBP" or head[:4] == b"RIFF":
        return {"format": "WEBP", "width": None, "height": None, "has_alpha": None}
    if head[:3] == b"\xff\xd8\xff":
        # 副檔名常被偽裝成 .png；JPEG 無 alpha
        w = h = None
        has_alpha = False
        if _PIL:
            try:
                with Image.open(path) as im:
                    w, h = im.size
                    has_alpha = im.mode in ("RGBA", "LA", "PA")
            except Exception:
                pass
        return {"format": "JPEG", "width": w, "height": h, "has_alpha": has_alpha}
    return {"format": "UNKNOWN", "width": None, "height": None, "has_alpha": None}


def main():
    ap = argparse.ArgumentParser()
    default_dir = Path(__file__).resolve().parent.parent / "assets" / "anim"
    ap.add_argument("--dir", default=str(default_dir))
    args = ap.parse_args()

    folder = Path(args.dir)
    records = []
    for f in sorted(folder.glob("*.png")):
        info = inspect(f)
        info["file"] = f.name
        info["category"] = classify(f.name)
        records.append(info)

    n_png = sum(r["format"] == "PNG" for r in records)
    n_jpg = sum(r["format"] == "JPEG" for r in records)
    n_alpha = sum(1 for r in records if r["has_alpha"])
    by_cat = {}
    for r in records:
        by_cat.setdefault(r["category"], []).append(r["file"])

    out_json = folder.parent.parent / "tools" / "anim_manifest.json"
    out_md = folder.parent.parent / "tools" / "anim_manifest.md"
    out_json.write_text(json.dumps(records, ensure_ascii=False, indent=2), encoding="utf-8")

    lines = ["# anim 素材盤點（由 normalize_assets.py 唯讀生成）", ""]
    lines.append(f"- 總檔數：{len(records)}")
    lines.append(f"- 真 PNG：{n_png}；JPEG 偽裝 .png：{n_jpg}；含透明通道：{n_alpha}")
    lines.append(f"- Pillow 可用：{_PIL}")
    lines.append("")
    lines.append("| 檔名 | 真格式 | 尺寸 | 透明 | 分類 |")
    lines.append("|---|---|---|---|---|")
    for r in records:
        size = f"{r['width']}x{r['height']}" if r["width"] else "?"
        alpha = "是" if r["has_alpha"] else ("否" if r["has_alpha"] is False else "?")
        lines.append(f"| {r['file']} | {r['format']} | {size} | {alpha} | {r['category']} |")
    lines.append("")
    lines.append("## 分類匯總")
    for cat, files in sorted(by_cat.items()):
        lines.append(f"- **{cat}**（{len(files)}）：" + ", ".join(files))
    out_md.write_text("\n".join(lines), encoding="utf-8")

    print(f"scanned={len(records)} png={n_png} jpeg={n_jpg} alpha={n_alpha}")
    print("json ->", out_json)
    print("md   ->", out_md)
    if n_jpg:
        print("提醒：%d 個 JPEG 內容檔需先正名/透明化才能作為格斗序列幀（見 docs/07 §4-§5）" % n_jpg)


if __name__ == "__main__":
    main()
