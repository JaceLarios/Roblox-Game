"""Gauge cluster art for Race Wars: a speedometer face, a tachometer face
and one needle, all 512x512 with transparent corners, drawn at 4x and
scaled down for clean edges. Angles are degrees clockwise from 12 o'clock;
every dial sweeps from -135 (bottom left) to +135 (bottom right)."""
import math, os
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
S = 4                     # supersample
W = 512 * S
C = W / 2
SWEEP0, SWEEP1 = -135.0, 135.0

def font(size, bold=True):
    f = ImageFont.truetype("C:/Windows/Fonts/bahnschrift.ttf", int(size * S))
    try:
        f.set_variation_by_name("Bold" if bold else "SemiBold")
    except Exception:
        pass
    return f

def pt(angle, r):
    a = math.radians(angle)
    return (C + r * S * math.sin(a), C - r * S * math.cos(a))

def radial(inner, outer, r_in, r_out):
    """RGBA disc of radius r_out shading from `inner` at r_in to `outer`."""
    y, x = np.mgrid[0:W, 0:W]
    d = np.sqrt((x - C) ** 2 + (y - C) ** 2) / S
    t = np.clip((d - r_in) / max(r_out - r_in, 1), 0, 1)[..., None]
    rgb = (np.array(inner) * (1 - t) + np.array(outer) * t).astype(np.uint8)
    a = (d <= r_out).astype(np.uint8) * 255
    return Image.fromarray(np.dstack([rgb, a[..., None]]).squeeze(), "RGBA")

def bezel():
    """A brushed-metal ring, light at the top left and dark at the bottom right."""
    y, x = np.mgrid[0:W, 0:W]
    d = np.sqrt((x - C) ** 2 + (y - C) ** 2) / S
    light = ((C - x) + (C - y)) / (2 * C)          # -1 .. 1, top left is +
    shade = np.clip(0.5 + 0.5 * light, 0, 1)
    ring = (d <= 252) & (d >= 226)
    base = 70 + 150 * shade
    # A few concentric bands for a machined look.
    base = base + 14 * np.sin(d * 0.9)
    rgb = np.clip(np.dstack([base, base + 4, base + 10]), 0, 255).astype(np.uint8)
    a = ring.astype(np.uint8) * 255
    img = Image.fromarray(np.dstack([rgb, a]), "RGBA")
    return img

def face(max_value, major_step, minor_step, label_every, unit, redline=None, label_scale=1.0):
    img = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    img.alpha_composite(bezel())
    img.alpha_composite(radial((30, 34, 44), (9, 10, 14), 0, 227))
    draw = ImageDraw.Draw(img)
    # Thin inner rim and a faint cyan glow ring just inside it.
    draw.ellipse([C - 227 * S, C - 227 * S, C + 227 * S, C + 227 * S], outline=(18, 18, 22, 255), width=3 * S)
    glow = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    ImageDraw.Draw(glow).ellipse([C - 219 * S, C - 219 * S, C + 219 * S, C + 219 * S], outline=(60, 200, 255, 110), width=4 * S)
    img.alpha_composite(glow.filter(ImageFilter.GaussianBlur(4 * S)))
    draw = ImageDraw.Draw(img)

    def angle_of(v):
        return SWEEP0 + (SWEEP1 - SWEEP0) * v / max_value

    # Redline band.
    if redline is not None:
        band = Image.new("RGBA", (W, W), (0, 0, 0, 0))
        bd = ImageDraw.Draw(band)
        r = 214 * S
        # PIL arcs start at 3 o'clock and run clockwise, so -90 turns ours.
        bd.arc([C - r, C - r, C + r, C + r], angle_of(redline) - 90, SWEEP1 - 90, fill=(235, 40, 40, 255), width=16 * S)
        img.alpha_composite(band)
        draw = ImageDraw.Draw(img)

    # Ticks: minor, then major on top.
    v = 0.0
    while v <= max_value + 1e-6:
        a = angle_of(v)
        red = redline is not None and v >= redline - 1e-6
        major = abs(v / major_step - round(v / major_step)) < 1e-6
        if major:
            draw.line([pt(a, 222), pt(a, 188)], fill=(255, 70, 60) if red else (245, 247, 250), width=7 * S)
        else:
            draw.line([pt(a, 222), pt(a, 205)], fill=(255, 110, 100) if red else (190, 196, 206), width=3 * S)
        v += minor_step

    # Numbers.
    f = font(42 * label_scale)
    v = 0.0
    while v <= max_value + 1e-6:
        a = angle_of(v)
        text = str(int(round(v / label_every)))
        red = redline is not None and v >= redline - 1e-6
        x, y = pt(a, 152)
        draw.text((x, y), text, font=f, fill=(255, 90, 80) if red else (250, 250, 252), anchor="mm")
        v += major_step

    # Units, low in the middle, under where the digital readout sits.
    draw.text((C, C + 150 * S), unit, font=font(24, bold=False), fill=(150, 160, 175), anchor="mm")
    return img.resize((512, 512), Image.LANCZOS)

def needle():
    img = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    shadow = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    sd = ImageDraw.Draw(shadow)
    tip, tail, half = 200, 38, 9
    body = [(C - half * S, C + tail * S), (C - 2.2 * S, C - tip * S), (C + 2.2 * S, C - tip * S), (C + half * S, C + tail * S)]
    sd.polygon([(x + 5 * S, y + 6 * S) for x, y in body], fill=(0, 0, 0, 150))
    img.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(5 * S)))
    d = ImageDraw.Draw(img)
    d.polygon(body, fill=(255, 64, 40, 255))
    # A lighter stripe down one side so it reads as a lit, bevelled blade.
    d.polygon([(C - half * S * 0.2, C + tail * S), (C - 1.0 * S, C - tip * S), (C + 2.2 * S, C - tip * S), (C + half * S, C + tail * S)], fill=(255, 150, 110, 255))
    # Glow along the blade.
    glow = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    ImageDraw.Draw(glow).polygon(body, fill=(255, 80, 40, 120))
    img.alpha_composite(glow.filter(ImageFilter.GaussianBlur(8 * S)))
    d = ImageDraw.Draw(img)
    # The centre cap: dark, with a metal ring.
    for r, col in ((30, (120, 126, 136, 255)), (26, (40, 42, 50, 255)), (14, (70, 74, 84, 255))):
        d.ellipse([C - r * S, C - r * S, C + r * S, C + r * S], fill=col)
    return img.resize((512, 512), Image.LANCZOS)

os.makedirs(HERE, exist_ok=True)
face(160, 20, 5, 1, "MPH").save(os.path.join(HERE, "speedo_face.png"))
face(8000, 1000, 250, 1000, "RPM x1000", redline=6500).save(os.path.join(HERE, "tach_face.png"))
needle().save(os.path.join(HERE, "needle.png"))

# A preview of the three together, to look at before uploading.
preview = Image.new("RGBA", (1100, 560), (60, 64, 72, 255))
tach = Image.open(os.path.join(HERE, "tach_face.png"))
speed = Image.open(os.path.join(HERE, "speedo_face.png"))
n = Image.open(os.path.join(HERE, "needle.png"))
preview.alpha_composite(tach, (20, 24))
preview.alpha_composite(n.rotate(-60, resample=Image.BICUBIC), (20, 24))
preview.alpha_composite(speed, (560, 24))
preview.alpha_composite(n.rotate(-20, resample=Image.BICUBIC), (560, 24))
preview.save(os.path.join(HERE, "preview.png"))
print("done")
