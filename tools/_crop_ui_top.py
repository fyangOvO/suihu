from PIL import Image
for name in ["ui-pause", "ui-settings", "ui-summary"]:
    im = Image.open(rf"D:\水滸g\docs\preview\{name}.png")
    im.crop((0, 0, 520, 220)).resize((1040, 440), Image.LANCZOS).save(rf"D:\水滸g\docs\preview\_{name}-top.png")
