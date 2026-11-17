from PIL import Image
for name in ["idle", "walk-a", "thrust", "smash"]:
    im = Image.open(rf"D:\水滸g\game\assets\anim\corpse_ghost\{name}.png").convert("RGBA")
    print(name, im.getbbox())
