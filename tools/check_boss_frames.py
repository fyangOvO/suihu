"""BOS-03 验收：检查 24 张 Boss 帧的画布、透明通道、脚基线与出界。
用法：python -X utf8 D:\\水滸g\\game\\tools\\check_boss_frames.py
PASS 退出 0；FAIL 退出 1。
"""
import sys
from pathlib import Path

import numpy as np
from PIL import Image

OUT_DIR = Path(r"D:\水滸g\game\assets\anim\boss")
CANVAS = (768, 768)
BASELINE = 720
GROUNDED = {
    "boss-idle", "boss-walk-1", "boss-walk-2", "boss-crouch", "boss-hurt", "boss-knockdown",
    "boss-pounce-1", "boss-pounce-4", "boss-pounce-5", "boss-tail-1",
    "boss-rear-up", "boss-claw-1", "boss-claw-2", "boss-roar", "boss-summon", "boss-recover",
    "boss-iron-tail-1", "boss-iron-tail-2", "boss-iron-tail-3", "boss-death-pounce-1", "boss-pant",
}
AIRBORNE = {"boss-pounce-2", "boss-pounce-3", "boss-death-pounce-2"}
NAMES = [
    "boss-idle", "boss-walk-1", "boss-walk-2", "boss-crouch", "boss-hurt", "boss-knockdown",
    "boss-pounce-1", "boss-pounce-2", "boss-pounce-3", "boss-pounce-4", "boss-pounce-5", "boss-tail-1",
    "boss-rear-up", "boss-claw-1", "boss-claw-2", "boss-roar", "boss-summon", "boss-recover",
    "boss-iron-tail-1", "boss-iron-tail-2", "boss-iron-tail-3", "boss-death-pounce-1", "boss-death-pounce-2", "boss-pant",
]
fails = []


def check(name: str, ok: bool) -> None:
    if not ok:
        fails.append(name)
    print("CHECK", name, "=", "PASS" if ok else "FAIL")


for name in NAMES:
    path = OUT_DIR / f"{name}.png"
    check(f"{name} exists", path.exists())
    if not path.exists():
        continue
    image = Image.open(path)
    check(f"{name} is 768x768", image.size == CANVAS)
    rgba = np.asarray(image.convert("RGBA"))
    alpha = rgba[:, :, 3]
    ys, xs = np.nonzero(alpha > 8)
    check(f"{name} has pixels", len(xs) > 0)
    if len(xs) == 0:
        continue
    box = (int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max()))
    check(f"{name} not clipped", box[0] >= 1 and box[2] <= CANVAS[0] - 2
          and box[1] >= 0 and box[3] <= CANVAS[1] - 1)
    if name in GROUNDED:
        check(f"{name} stands on baseline", abs(box[3] - BASELINE) <= 1)
    elif name in AIRBORNE:
        check(f"{name} is airborne", box[3] < BASELINE - 20)

print("BOSS_FRAMES fails=", len(fails), "->", fails)
sys.exit(0 if not fails else 1)
