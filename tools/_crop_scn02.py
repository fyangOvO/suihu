from PIL import Image
src = Image.open(r"D:\水滸g\docs\preview\flow-scn02-tutorial.png")
src.crop((470, 280, 650, 460)).resize((720, 720), Image.LANCZOS).save(r"D:\水滸g\docs\preview\_scn02-ghost.png")
