from PIL import Image
p = r"D:\水滸g\game\assets\anim\corpse_ghost\idle.png"
im = Image.open(p)
print(im.size, im.mode)
