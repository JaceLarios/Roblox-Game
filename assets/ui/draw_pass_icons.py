"""Gamepass icons for the three passes (upload each one as the pass's image
in Creator Hub). Built from the game's own illustrated atlas
(ui-icons.png: the coins, backpack and gift the Shop banners and HUD
already use), so the store matches the game. Each icon is a sunburst
disc in one of the game's colours, the sprite with a soft drop shadow,
a few sparkles and one bold label (2X, +50, STARTER).

Roblox shows pass icons cropped to a circle, so everything that matters
sits inside the inscribed circle. The background is full-bleed, so the
icon still looks right where it is shown square.

512x512 PNGs, drawn at 2x and scaled down. Also writes preview.png: the
three side by side, circle-cropped the way the store shows them."""
import math
import os
from PIL import Image, ImageDraw, ImageFilter, ImageFont

HERE = os.path.dirname(os.path.abspath(__file__))
OUT_DIR = os.path.join(HERE, "passes")
S = 2
W = 512 * S
OUTLINE = (22, 30, 48, 255)
FONT = "C:/Windows/Fonts/ariblk.ttf"

# Atlas cells (3x3): coins, backpack, gift.
ATLAS = Image.open(os.path.join(HERE, "ui-icons.png")).convert("RGBA")
CELL = ATLAS.width // 3


def sprite(col, row):
    cell = ATLAS.crop((col * CELL, row * CELL, (col + 1) * CELL, (row + 1) * CELL))
    return cell.crop(cell.getbbox())


def lerp(a, b, t):
    return tuple(round(a[i] + (b[i] - a[i]) * t) for i in range(3))


def background(inner, outer, rays):
    """A radial gradient disc with a sunburst, full-bleed."""
    img = Image.new("RGBA", (W, W), outer + (255,))
    d = ImageDraw.Draw(img)
    steps = 160
    reach = W * 0.75
    for i in range(steps):
        t = i / (steps - 1)
        r = reach * (1 - t)
        d.ellipse([W / 2 - r, W / 2 - r, W / 2 + r, W / 2 + r], fill=lerp(outer, inner, t ** 0.8) + (255,))

    burst = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    b = ImageDraw.Draw(burst)
    count = 18
    for i in range(count):
        a0 = (i / count) * 2 * math.pi
        a1 = a0 + math.pi / count
        b.polygon([
            (W / 2, W / 2),
            (W / 2 + math.cos(a0) * W, W / 2 + math.sin(a0) * W),
            (W / 2 + math.cos(a1) * W, W / 2 + math.sin(a1) * W),
        ], fill=rays)
    # Rays fade out toward the middle so the sprite sits on a clean glow.
    mask = Image.new("L", (W, W), 0)
    m = ImageDraw.Draw(mask)
    for i in range(100):
        t = i / 99
        r = W * 0.72 * (1 - t)
        m.ellipse([W / 2 - r, W / 2 - r, W / 2 + r, W / 2 + r], fill=round(255 * (1 - t) ** 0.6))
    burst.putalpha(Image.composite(burst.getchannel("A"), Image.new("L", (W, W), 0), mask))
    img.alpha_composite(burst)

    return img


def place(img, art, center, box):
    scale = min(box / art.width, box / art.height)
    art = art.resize((round(art.width * scale), round(art.height * scale)), Image.LANCZOS)
    x = round(center[0] - art.width / 2)
    y = round(center[1] - art.height / 2)

    shadow = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    black = Image.new("RGBA", art.size, (10, 14, 24, 120))
    shadow.paste(black, (x + 6, y + 22), art)
    img.alpha_composite(shadow.filter(ImageFilter.GaussianBlur(14)))
    img.alpha_composite(art, (x, y))


def sparkle(img, cx, cy, r, fill=(255, 255, 255, 255)):
    d = ImageDraw.Draw(img)
    def star(radius, width):
        return [
            (cx, cy - radius), (cx + width, cy - width), (cx + radius, cy), (cx + width, cy + width),
            (cx, cy + radius), (cx - width, cy + width), (cx - radius, cy), (cx - width, cy - width),
        ]
    d.polygon(star(r + 9, r * 0.28 + 6), fill=OUTLINE)
    d.polygon(star(r, r * 0.28), fill=fill)


def label(img, text, center, size, fill, max_width=None):
    font = ImageFont.truetype(FONT, size)
    stroke = max(10, size // 9)
    if max_width:
        while True:
            left, _, right, _ = ImageDraw.Draw(img).textbbox((0, 0), text, font=font, stroke_width=stroke)
            if right - left <= max_width or size <= 40:
                break
            size -= 4
            font = ImageFont.truetype(FONT, size)
            stroke = max(10, size // 9)
    d = ImageDraw.Draw(img)
    # A solid drop under the letters, then the letters with a thick outline.
    d.text((center[0], center[1] + size * 0.07), text, font=font, anchor="mm",
           fill=OUTLINE, stroke_width=stroke, stroke_fill=OUTLINE)
    d.text(center, text, font=font, anchor="mm", fill=fill, stroke_width=stroke, stroke_fill=OUTLINE)
    # A gloss on the top half of the letters.
    gloss = Image.new("RGBA", (W, W), (0, 0, 0, 0))
    g = ImageDraw.Draw(gloss)
    g.text(center, text, font=font, anchor="mm", fill=(255, 255, 255, 110))
    left, top, right, bottom = g.textbbox(center, text, font=font, anchor="mm")
    cut = Image.new("L", (W, W), 0)
    ImageDraw.Draw(cut).rectangle([0, 0, W, top + (bottom - top) * 0.45], fill=255)
    gloss.putalpha(Image.composite(gloss.getchannel("A"), Image.new("L", (W, W), 0), cut))
    img.alpha_composite(gloss)


def save(img, name):
    os.makedirs(OUT_DIR, exist_ok=True)
    final = img.resize((512, 512), Image.LANCZOS)
    final.save(os.path.join(OUT_DIR, name))
    return final


icons = []

# 2x Coins: gold coins on bright green, a big gold 2X.
img = background((140, 240, 110), (22, 120, 52), (255, 255, 255, 40))
place(img, sprite(0, 0), (450, 415), 620)
sparkle(img, 790, 250, 50)
sparkle(img, 225, 215, 34, (255, 236, 120, 255))
label(img, "2X", (650, 765), 270, (255, 214, 60, 255))
icons.append(save(img, "pass_2x_coins.png"))

# +50 Inventory Space: the backpack on dark grey, a bright green +50.
img = background((104, 114, 132), (30, 34, 44), (255, 255, 255, 26))
place(img, sprite(1, 0), (455, 425), 600)
sparkle(img, 790, 250, 48, (255, 236, 120, 255))
sparkle(img, 220, 240, 34)
label(img, "+50", (620, 775), 230, (120, 240, 90, 255))
icons.append(save(img, "pass_inventory.png"))

# Starter Pack: the gift on red, STARTER across the bottom.
img = background((255, 120, 104), (150, 22, 34), (255, 255, 255, 36))
place(img, sprite(0, 1), (512, 420), 600)
sparkle(img, 810, 240, 48, (255, 236, 120, 255))
sparkle(img, 210, 260, 34)
label(img, "STARTER", (512, 810), 170, (255, 255, 255, 255), max_width=760)
icons.append(save(img, "pass_starter_pack.png"))

# Preview: circle-cropped, the way the store shows them, on a light card.
pad = 40
sheet = Image.new("RGBA", (512 * 3 + pad * 4, 512 + pad * 2), (238, 240, 244, 255))
mask = Image.new("L", (512 * 4, 512 * 4), 0)
ImageDraw.Draw(mask).ellipse([0, 0, 512 * 4 - 1, 512 * 4 - 1], fill=255)
mask = mask.resize((512, 512), Image.LANCZOS)
for i, icon in enumerate(icons):
    sheet.paste(icon, (pad + i * (512 + pad), pad), mask)
sheet.save(os.path.join(OUT_DIR, "preview.png"))
print("wrote", OUT_DIR)
