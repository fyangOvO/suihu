"""验收老虎伥鬼六帧：真 PNG / RGBA / 512x640 / 四角透明 / 脚底基线 612±2。

用法：python -X utf8 tools/check_corpse_ghost_spec.py
"""
from pathlib import Path
from PIL import Image

DIR = Path(__file__).resolve().parents[1] / "assets" / "anim" / "corpse_ghost"
NAMES = ["idle", "walk-a", "walk-b", "thrust", "smash", "hurt"]
SIZE = (512, 640)
BASELINE = 612


def main() -> None:
    fails = []
    for name in NAMES:
        path = DIR / f"{name}.png"
        if not path.exists():
            fails.append((name, "missing"))
            continue
        im = Image.open(path)
        im.load()
        if im.size != SIZE:
            fails.append((name, f"size={im.size}"))
        if im.mode != "RGBA":
            fails.append((name, f"mode={im.mode}"))
        a = im.split()[-1]
        if any(a.getpixel(p) != 0 for p in [(0, 0), (511, 0), (0, 639), (511, 639)]):
            fails.append((name, "corner alpha"))
        bbox = a.getbbox()
        if bbox is None:
            fails.append((name, "empty alpha"))
            continue
        bottom = bbox[3] - 1
        if abs(bottom - BASELINE) > 2:
            fails.append((name, f"bottom={bottom}"))
        print(f"{name}: bbox={bbox} h={bbox[3] - bbox[1]} bottom={bottom}")
    if fails:
        raise SystemExit(f"corpse ghost spec FAIL: {fails}")
    print("corpse ghost spec: PASS (6/6)")


if __name__ == "__main__":
    main()
