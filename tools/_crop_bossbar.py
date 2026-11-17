from PIL import Image
im = Image.open(r"D:\水滸g\docs\preview\ui-boss.png")
im.crop((240, 20, 725, 110)).resize((1455, 270), Image.LANCZOS).save(r"D:\水滸g\docs\preview\_bossbar-detail.png")
