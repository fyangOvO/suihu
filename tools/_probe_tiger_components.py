from pathlib import Path

import numpy as np
from PIL import Image
from rembg import remove
from scipy import ndimage

p = Path(r"D:\水滸g\docs\preview\tiger-pose-sheet-src.png")
rgba = np.asarray(remove(Image.open(p).convert("RGB")))
mask = rgba[:, :, 3] > 40
lab, n = ndimage.label(mask, structure=np.ones((3, 3)))
sizes = ndimage.sum(mask, lab, range(1, n + 1))
order = np.argsort(sizes)[::-1]
print("components", n)
for k in order[:12]:
    i = k + 1
    ys, xs = np.where(lab == i)
    print(i, "area", int(sizes[k]), "bbox", (int(xs.min()), int(ys.min()), int(xs.max()), int(ys.max())))
