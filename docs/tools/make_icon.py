"""The app icon, drawn from the Penny Design System tokens.

Penny herself is placeholder art and far too detailed to read at 60px, so the
icon is her coin: the app's own motif. Deep teal ground so it stands out in a
home screen full of white apps, a gold coin with a copper milled rim, and one
soft highlight. No gradient mesh, no red, no green lead, no lettering (the names
are still pending a trademark search).
"""
from PIL import Image, ImageDraw, ImageFilter
import math

S = 1024
TEAL     = ( 31, 111, 120)
TEAL_DK  = ( 22,  84,  91)
COPPER   = (201, 121,  58)
COPPER_D = (166,  97,  42)
GOLD     = (244, 194,  84)
GOLD_LT  = (252, 223, 150)

img = Image.new("RGB", (S, S), TEAL)
d = ImageDraw.Draw(img)

# A soft darker pool behind the coin so it sits on the ground rather than floats.
glow = Image.new("RGB", (S, S), TEAL)
ImageDraw.Draw(glow).ellipse([S*0.14, S*0.18, S*0.86, S*0.90], fill=TEAL_DK)
img = Image.blend(img, glow.filter(ImageFilter.GaussianBlur(90)), 0.55)
d = ImageDraw.Draw(img)

cx, cy = S // 2, int(S * 0.505)
r = int(S * 0.315)

# Milled edge: short copper teeth all the way round, like a real coin.
for i in range(56):
    a = 2 * math.pi * i / 56
    x1, y1 = cx + math.cos(a) * (r + 18), cy + math.sin(a) * (r + 18)
    x2, y2 = cx + math.cos(a) * (r - 6),  cy + math.sin(a) * (r - 6)
    d.line([x1, y1, x2, y2], fill=COPPER_D, width=16)

d.ellipse([cx-r, cy-r, cx+r, cy+r], fill=COPPER)                     # rim
ri = r - 46
d.ellipse([cx-ri, cy-ri, cx+ri, cy+ri], fill=GOLD)                   # face

# Penny's shell: rows of little scales stamped into the coin face. Three plain
# arcs were the obvious drawing, but three curved bars on a round coloured badge
# is the Spotify mark, and this app already works hard not to look like anyone
# else. Scales are Penny's own and read as texture at any size.
rows = ((-0.46, 5), (-0.14, 6), (0.20, 5), (0.52, 3))
for off, n in rows:
    yy = cy + off * ri
    half = math.sqrt(max(0.0, (ri * 0.90) ** 2 - (off * ri) ** 2))
    if half < 10: continue
    step = (2 * half) / n
    w = step * 0.86
    for i in range(n):
        x = cx - half + step * (i + 0.5)
        box = [x - w / 2, yy - w * 0.46, x + w / 2, yy + w * 0.62]
        d.arc(box, start=185, end=355, fill=COPPER, width=15)

# One highlight, up and to the left, the way the 3D icons catch light.
hl = Image.new("RGB", img.size, (0, 0, 0))
ImageDraw.Draw(hl).ellipse([cx - ri*0.78, cy - ri*0.86, cx - ri*0.02, cy - ri*0.16],
                           fill=GOLD_LT)
mask = Image.new("L", img.size, 0)
ImageDraw.Draw(mask).ellipse([cx-ri, cy-ri, cx+ri, cy+ri], fill=110)
img.paste(Image.blend(img, hl.filter(ImageFilter.GaussianBlur(40)), 0.55), (0, 0), mask)

img.save("App/Assets.xcassets/AppIcon.appiconset/icon-1024.png")
print("drew App/Assets.xcassets/AppIcon.appiconset/icon-1024.png")
