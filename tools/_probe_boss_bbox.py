from PIL import Image
from pathlib import Path

for name in ("boss-idle.png", "boss-walk-1.png", "boss-pounce-1.png", "boss-rear-up.png"):
    p = Path(r"D:\水滸g\game\assets\anim\boss") / name
    if not p.exists():
        print(name, "missing")
        continue
    im = Image.open(p).convert("RGBA")
    alpha = im.getchannel("A")
    bbox = alpha.getbbox()
    print(name, im.size, "bbox=", bbox, "h=", (bbox[3] - bbox[1]) if bbox else 0, "w=", (bbox[2] - bbox[0]) if bbox else 0)
