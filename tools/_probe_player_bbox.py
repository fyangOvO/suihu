from PIL import Image
from pathlib import Path

for p in [Path(r"D:\水滸g\game\assets\anim\idle.png"), Path(r"D:\水滸g\game\assets\anim\redraw_clean\idle.png")]:
    if p.exists():
        im = Image.open(p).convert("RGBA")
        b = im.getchannel("A").getbbox()
        print(p.name, im.size, b, "h=", b[3]-b[1] if b else 0, "w=", b[2]-b[0] if b else 0)
