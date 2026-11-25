"""Generate the Score Book app icon: a sunset gradient with a stacked-cash mark.

Run from scorebook/:  python3 make_icon.py
"""
from PIL import Image, ImageDraw

S = 1024
img = Image.new("RGB", (S, S))
d = ImageDraw.Draw(img)
top, bot = (245, 107, 140), (52, 22, 74)
for y in range(S):
    t = y / S
    d.line([(0, y), (S, y)], fill=tuple(int(top[i] + (bot[i] - top[i]) * t) for i in range(3)))

# Three stacked bills
for i, y in enumerate((600, 500, 400)):
    x0, x1 = 232 + i * 20, 792 + i * 20
    d.rounded_rectangle([x0, y - 110, x1, y + 110], radius=36, fill=(20, 16, 30))
    d.rounded_rectangle([x0 + 18, y - 92, x1 - 18, y + 92], radius=24, outline=(132, 225, 170), width=12)
cx, cy = 552, 400
d.ellipse([cx - 62, cy - 62, cx + 62, cy + 62], outline=(132, 225, 170), width=14)

img.save("Resources/Assets.xcassets/AppIcon.appiconset/icon-1024.png")
