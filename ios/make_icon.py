"""Generate the Auction XI app icon: a cricket ball and an auction gavel on a night-sky field.

Run from ios/:  python3 make_icon.py
"""
import math
from PIL import Image, ImageDraw, ImageFilter

S = 1024
img = Image.new("RGB", (S, S))
d = ImageDraw.Draw(img)

# Night gradient
top, bot = (17, 27, 72), (5, 7, 15)
for y in range(S):
    t = y / S
    d.line([(0, y), (S, y)], fill=tuple(int(top[i] + (bot[i] - top[i]) * t) for i in range(3)))

# Floodlight glow
glow = Image.new("L", (S, S), 0)
ImageDraw.Draw(glow).ellipse([212, 140, 812, 740], fill=110)
glow = glow.filter(ImageFilter.GaussianBlur(120))
img = Image.composite(Image.new("RGB", (S, S), (251, 191, 36)), img, glow.point(lambda v: v // 3))
d = ImageDraw.Draw(img)

# Cricket ball (drawn on its own layer, clipped to a circle)
cx, cy, r = 450, 560, 260
ball = Image.new("RGB", (S, S), (196, 30, 58))
b = ImageDraw.Draw(ball)
b.ellipse([cx - r - 60, cy - r - 80, cx + r - 140, cy + 20], fill=(222, 62, 86))    # soft highlight
b.ellipse([cx - r + 260, cy + 40, cx + r + 200, cy + r + 200], fill=(150, 18, 40))  # shade
for off in (-24, 24):
    pts = [(cx + off + 70 * math.sin(a / 55), cy - r + a) for a in range(0, 2 * r + 1, 4)]
    b.line(pts, fill=(250, 240, 230), width=9)
    for i in range(0, len(pts), 6):
        x, y = pts[i]
        b.line([(x - 15, y - 6), (x + 15, y + 6)], fill=(250, 240, 230), width=5)
mask = Image.new("L", (S, S), 0)
ImageDraw.Draw(mask).ellipse([cx - r, cy - r, cx + r, cy + r], fill=255)
img.paste(ball, (0, 0), mask)
d = ImageDraw.Draw(img)

# Gavel (rotated), gold
gavel = Image.new("RGBA", (S, S), (0, 0, 0, 0))
g = ImageDraw.Draw(gavel)
gold, dark = (251, 191, 36, 255), (180, 120, 10, 255)
g.rounded_rectangle([470, 300, 610, 540], radius=26, fill=gold)      # head
g.rectangle([470, 330, 610, 350], fill=dark)
g.rectangle([470, 490, 610, 510], fill=dark)
g.rounded_rectangle([522, 520, 558, 900], radius=18, fill=gold)      # handle
gavel = gavel.rotate(-38, center=(540, 520), resample=Image.BICUBIC)
shadow = gavel.split()[3].filter(ImageFilter.GaussianBlur(14))
img.paste((0, 0, 0), (14, 18), shadow.point(lambda v: v // 2))
img.paste(gavel, (90, -40), gavel)

img.save("Resources/Assets.xcassets/AppIcon.appiconset/icon-1024.png")
print("icon written")
