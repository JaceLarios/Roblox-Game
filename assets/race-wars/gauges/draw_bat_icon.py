"""Upgrade-card icon for Bat Strength, in the style of the illustrated
atlas: a chunky wooden bat on a diagonal with a thick dark outline, soft
two-tone shading, a gloss stripe, black grip tape, and an impact burst at
the barrel. 512x512, transparent, drawn at 4x."""
import math, os
from PIL import Image, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
S = 4
W = 512 * S
OUT = (22, 30, 48, 255)

def P(x, y):
    return (x * S, y * S)

def capsule_points(x0, y0, x1, y1, r0, r1, steps=48):
    """Outline of a tapered capsule from (x0,y0) radius r0 to (x1,y1) radius r1."""
    dx, dy = x1 - x0, y1 - y0
    length = math.hypot(dx, dy)
    ux, uy = dx / length, dy / length
    nx, ny = -uy, ux
    pts = []
    # side one, start to end
    pts.append((x0 + nx * r0, y0 + ny * r0))
    pts.append((x1 + nx * r1, y1 + ny * r1))
    # round cap at the end
    base = math.atan2(ny, nx)
    for i in range(1, steps):
        a = base - math.pi * i / steps
        pts.append((x1 + math.cos(a) * r1, y1 + math.sin(a) * r1))
    pts.append((x1 - nx * r1, y1 - ny * r1))
    pts.append((x0 - nx * r0, y0 - ny * r0))
    base2 = math.atan2(-ny, -nx)
    for i in range(1, steps):
        a = base2 - math.pi * i / steps
        pts.append((x0 + math.cos(a) * r0, y0 + math.sin(a) * r0))
    return [P(x, y) for x, y in pts]

def burst(draw, cx, cy, r_out, r_in, points, fill, outline):
    pts = []
    for i in range(points * 2):
        r = r_out if i % 2 == 0 else r_in
        a = math.pi * i / points - math.pi / 2
        pts.append(P(cx + math.cos(a) * r, cy + math.sin(a) * r))
    draw.polygon(pts, fill=fill, outline=outline)
    return pts

img = Image.new("RGBA", (W, W), (0, 0, 0, 0))

# Impact burst behind the barrel.
layer = Image.new("RGBA", (W, W), (0, 0, 0, 0))
d = ImageDraw.Draw(layer)
pts = burst(d, 360, 150, 118, 62, 9, (255, 196, 40, 255), None)
d.line(pts + [pts[0]], fill=OUT, width=12 * S, joint="curve")
burst(d, 360, 150, 118, 62, 9, (255, 196, 40, 255), None)
burst(d, 360, 150, 78, 40, 9, (255, 238, 150, 255), None)
img.alpha_composite(layer)

# The bat: knob at bottom left, barrel at top right.
knob = (112, 410)
tip = (372, 150)
body = capsule_points(knob[0], knob[1], tip[0], tip[1], 17, 52)
shadow = Image.new("RGBA", (W, W), (0, 0, 0, 0))
ImageDraw.Draw(shadow).polygon([(x + 10 * S, y + 14 * S) for x, y in body], fill=(10, 16, 30, 110))
img.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(10 * S)))

d = ImageDraw.Draw(img)
# Outline: the body grown by the outline width.
outline = capsule_points(knob[0], knob[1], tip[0], tip[1], 17 + 11, 52 + 11)
d.polygon(outline, fill=OUT)
d.polygon(body, fill=(214, 150, 84, 255))
# Shade: the lower half of the bat a step darker.
shade = capsule_points(knob[0] + 6, knob[1] + 6, tip[0] + 8, tip[1] + 14, 12, 40)
mask = Image.new("L", (W, W), 0)
ImageDraw.Draw(mask).polygon(body, fill=255)
shade_layer = Image.new("RGBA", (W, W), (0, 0, 0, 0))
ImageDraw.Draw(shade_layer).polygon(shade, fill=(176, 108, 54, 255))
img.paste(shade_layer, (0, 0), Image.composite(shade_layer, Image.new("RGBA", (W, W)), mask).split()[3])
d = ImageDraw.Draw(img)
# Wood grain.
for off in (-18, 0, 20):
    a = (knob[0] + 120, knob[1] - 118)
    b = (tip[0] - 20, tip[1] + 20)
    d.line([P(a[0] + off * 0.7, a[1] + off * 0.7), P(b[0] + off * 0.7, b[1] + off * 0.7)], fill=(160, 98, 50, 200), width=3 * S)
# Gloss stripe along the top edge.
gloss = capsule_points(knob[0] + 70, knob[1] - 82, tip[0] - 22, tip[1] - 14, 4, 12)
d.polygon(gloss, fill=(255, 236, 196, 235))
# Grip tape near the knob.
grip = capsule_points(knob[0] + 12, knob[1] - 12, knob[0] + 92, knob[1] - 92, 19, 24)
d.polygon(grip, fill=(44, 48, 60, 255))
for i in range(5):
    t = 0.18 + i * 0.17
    cx = knob[0] + 12 + (80) * t
    cy = knob[1] - 12 - (80) * t
    d.line([P(cx - 20, cy - 8), P(cx + 8, cy + 20)], fill=(90, 96, 112, 255), width=4 * S)
# The knob.
d.ellipse([P(knob[0] - 34, knob[1] - 34)[0], P(knob[0] - 34, knob[1] - 34)[1], P(knob[0] + 34, knob[1] + 34)[0], P(knob[0] + 34, knob[1] + 34)[1]], fill=OUT)
d.ellipse([P(knob[0] - 23, knob[1] - 23)[0], P(knob[0] - 23, knob[1] - 23)[1], P(knob[0] + 23, knob[1] + 23)[0], P(knob[0] + 23, knob[1] + 23)[1]], fill=(44, 48, 60, 255))
d.ellipse([P(knob[0] - 14, knob[1] - 18)[0], P(knob[0] - 14, knob[1] - 18)[1], P(knob[0] + 2, knob[1] - 4)[0], P(knob[0] + 2, knob[1] - 4)[1]], fill=(120, 126, 140, 255))

img = img.resize((512, 512), Image.LANCZOS)
img.save(os.path.join(HERE, "bat_icon.png"))
preview = Image.new("RGBA", (512, 512), (90, 170, 220, 255))
preview.alpha_composite(img)
preview.save(os.path.join(HERE, "bat_icon_preview.png"))
print("done")
