# -*- coding: utf-8 -*-
"""把总览图另存一份 JPEG 缩略（部分查看器对超大 PNG 不友好）。"""
import sys
from pathlib import Path

from PIL import Image

src = Path(r"D:\水滸g\docs\preview\art-all-frames.png")
dst = Path(r"D:\水滸g\docs\preview\art-all-frames.jpg")
im = Image.open(src).convert("RGB")
im.thumbnail((1600, 1600), Image.LANCZOS)
im.save(dst, "JPEG", quality=88)
print(f"written {dst} {im.size} {dst.stat().st_size // 1024}KB")
