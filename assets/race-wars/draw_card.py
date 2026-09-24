"""Draws the Race Wars travel-card picture: the Green Hills stretch of the
track in one-point perspective, as seen from the start line.

Run from this folder: python draw_card.py  ->  travel_card.png
"""
from PIL import Image, ImageDraw, ImageFilter

W, H = 1024, 452          # final size (the card's picture box is about 2.3:1)
SS = 3                    # supersample
w, h = W * SS, H * SS
F = 560 * SS              # focal length in pixels
CX, CY = w * 0.5, h * 0.44
CAM_Y = 12                # camera height, studs
HALF = 36                 # half the track width
WALL = 46                 # wall height
TILE = 12                 # checker square, studs
NEAR, FAR = 4, 900

img = Image.new("RGB", (w, h))
d = ImageDraw.Draw(img)

# Sky: a vertical gradient, then a few soft clouds.
top, bottom = (58, 150, 222), (170, 214, 245)
for y in range(h):
    t = min(1, y / (CY + 40))
    d.line([(0, y), (w, y)], fill=tuple(int(top[i] + (bottom[i] - top[i]) * t) for i in range(3)))
clouds = Image.new("RGBA", (w, h), (0, 0, 0, 0))
cd = ImageDraw.Draw(clouds)
for cx, cy, r in [(0.18, 0.12, 60), (0.24, 0.1, 44), (0.7, 0.16, 70), (0.78, 0.13, 50), (0.46, 0.06, 40)]:
    for dx in (-1, 0, 1):
        cd.ellipse([w * cx + dx * r * SS - r * SS, h * cy - r * SS * 0.45, w * cx + dx * r * SS + r * SS, h * cy + r * SS * 0.45], fill=(255, 255, 255, 120))
clouds = clouds.filter(ImageFilter.GaussianBlur(14 * SS))
img.paste(clouds, (0, 0), clouds)
d = ImageDraw.Draw(img)


def project(x, y, z):
    return (CX + F * x / z, CY - F * (y - CAM_Y) / z)


def quad(points3d, colour):
    d.polygon([project(*p) for p in points3d], fill=colour)


def shade(c, k):
    return tuple(max(0, min(255, int(v * k))) for v in c)


FLOOR_A, FLOOR_B = (98, 214, 76), (84, 196, 64)
WALL_A, WALL_B = (232, 150, 112), (212, 128, 92)
TRIM = (86, 186, 68)

# Far to near so nearer tiles paint over farther ones.
z = FAR
while z > NEAR:
    z0 = max(NEAR, z - TILE)
    row = int(z0 // TILE)
    fog = 0.55 + 0.45 * (1 - z / FAR)   # fade toward the sky colour far away
    for i, x0 in enumerate(range(-HALF, HALF, TILE)):
        c = FLOOR_A if (i + row) % 2 == 0 else FLOOR_B
        c = tuple(int(c[k] * fog + bottom[k] * (1 - fog)) for k in range(3))
        quad([(x0, 0, z0), (x0 + TILE, 0, z0), (x0 + TILE, 0, z), (x0, 0, z)], c)
    for side in (-1, 1):
        x = side * HALF
        for j, y0 in enumerate(range(0, WALL, TILE)):
            c = WALL_A if (j + row) % 2 == 0 else WALL_B
            c = shade(c, 0.93 if side > 0 else 1.0)
            c = tuple(int(c[k] * fog + bottom[k] * (1 - fog)) for k in range(3))
            quad([(x, y0, z0), (x, min(WALL, y0 + TILE), z0), (x, min(WALL, y0 + TILE), z), (x, y0, z)], c)
        t = tuple(int(TRIM[k] * fog + bottom[k] * (1 - fog)) for k in range(3))
        quad([(x, WALL, z0), (x, WALL + 3, z0), (x, WALL + 3, z), (x, WALL, z)], t)
        quad([(x, WALL + 3, z0), (x + side * 6, WALL + 3, z0), (x + side * 6, WALL + 3, z), (x, WALL + 3, z)], shade(t, 1.1))
    z = z0


def block(x, z, bw, bh, bd, colour):
    """A box standing on the floor, seen from the camera: front, top, and the side facing the middle."""
    x0, x1 = x - bw / 2, x + bw / 2
    z0, z1 = z - bd / 2, z + bd / 2
    side_x = x0 if x > 0 else x1
    quad([(side_x, 0, z0), (side_x, bh, z0), (side_x, bh, z1), (side_x, 0, z1)], shade(colour, 0.78))
    quad([(x0, bh, z0), (x1, bh, z0), (x1, bh, z1), (x0, bh, z1)], shade(colour, 1.15))
    quad([(x0, 0, z0), (x1, 0, z0), (x1, bh, z0), (x0, bh, z0)], colour)


HEDGE = (58, 164, 50)
# The gate at the end of the level, far off.
gz = 700
for side in (-1, 1):
    block(side * (HALF - 2), gz, 4, 34, 4, (46, 46, 52))
quad([(-HALF, 22, gz), (HALF, 22, gz), (HALF, 30, gz), (-HALF, 30, gz)], (28, 28, 34))
# Hedges, far to near.
for x, z, bw in sorted([(-14, 520, 14), (18, 470, 12), (-24, 380, 16), (10, 330, 12), (22, 250, 14),
                        (-20, 190, 13), (6, 150, 12), (-17, 90, 15), (24, 60, 13)], key=lambda h: -h[1]):
    block(x, z, bw, 6, 9, HEDGE)
    block(x + (bw * 0.2 if x < 0 else -bw * 0.2), z + 0.5, bw * 0.55, 11, 7, shade(HEDGE, 1.12))

img = img.resize((W, H), Image.LANCZOS)
img.save("travel_card.png")
print("saved", img.size)
