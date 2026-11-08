"""Generate an original Streaklet app icon (a flame-on-ring glyph, our own design)."""
import math
from PIL import Image, ImageDraw

SIZE = 1024
img = Image.new("RGB", (SIZE, SIZE), "#0B1220")
d = ImageDraw.Draw(img)

# Vertical gradient background.
top = (24, 38, 74)
bot = (11, 18, 32)
for y in range(SIZE):
    t = y / SIZE
    r = int(top[0] + (bot[0] - top[0]) * t)
    g = int(top[1] + (bot[1] - top[1]) * t)
    b = int(top[2] + (bot[2] - top[2]) * t)
    d.line([(0, y), (SIZE, y)], fill=(r, g, b))

cx, cy = SIZE / 2, SIZE / 2 + 20

# Progress ring (open at the bottom, like a streak ring).
ring_r = 300
ring_w = 56
bbox = [cx - ring_r, cy - ring_r, cx + ring_r, cy + ring_r]
d.arc(bbox, start=130, end=50, fill=(79, 140, 255), width=ring_w)      # accent arc
d.arc(bbox, start=50, end=130, fill=(79, 140, 255, 40), width=ring_w)  # faint remainder

# Flame in the center (streak symbol), built from an original teardrop path.
def flame(scale, color):
    pts = []
    for i in range(0, 361, 6):
        a = math.radians(i)
        # teardrop: narrow top, round bottom
        rr = 1 - 0.55 * math.cos(a)
        x = cx + scale * rr * math.sin(a)
        y = cy - scale * 1.25 * (math.cos(a)) * 0.8 + scale * 0.2
        pts.append((x, y))
    d.polygon(pts, fill=color)

flame(170, (255, 138, 76))   # outer flame
flame(110, (255, 196, 92))   # inner flame
flame(55, (255, 240, 180))   # core

img.save("Resources/Assets.xcassets/AppIcon.appiconset/icon-1024.png")
print("icon written")
