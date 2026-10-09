"""Badge pictures for the Roblox badges (ServerStorage.Badges, docs/BADGES.md).

python make_badges.py  -> one 512x512 PNG per badge here, plus badges-sheet.png.
Each picture is a scene of what you do to earn the badge (scenes/*.png,
rendered by build_badges.py in Blender from the game's own models), set in a
bolted scrap-metal ring with a banner in the game's font. Roblox shows badge
pictures as circles, so everything that matters stays inside the disc.
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageFilter

HERE = Path(__file__).resolve().parent
SIZE = 512
DISC = 452                      # the scene's circle, inset in the ring
_fonts = sorted((Path.home() / 'AppData/Local/Roblox/Versions').glob('*/content/fonts/FredokaOne-Regular.ttf'))
FONT = str(_fonts[-1]) if _fonts else 'C:/Windows/Fonts/impact.ttf'


def shade(c, k):
    return tuple(max(0, min(255, int(v * k))) for v in c[:3])


def bolt(d, x, y, r, ring):
    """A hex bolt head: the yard's scrap, and the game's Bolts."""
    import math
    pts = [(x + r * math.cos(math.pi / 6 + i * math.pi / 3), y + r * math.sin(math.pi / 6 + i * math.pi / 3)) for i in range(6)]
    d.polygon([(px + 1.5, py + 2) for px, py in pts], fill=shade(ring, .3))
    d.polygon(pts, fill=(196, 202, 212), outline=(70, 74, 84), width=2)
    d.ellipse((x - r * .45, y - r * .45, x + r * .45, y + r * .45), fill=(150, 156, 168), outline=(90, 94, 104), width=1)


def badge(name, ring, label):
    import math
    canvas = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    scene = Image.open(HERE / 'scenes' / f'{name}.png').convert('RGB').resize((DISC, DISC), Image.LANCZOS)
    mask = Image.new('L', (DISC, DISC), 0)
    ImageDraw.Draw(mask).ellipse((0, 0, DISC - 1, DISC - 1), fill=255)
    off = (SIZE - DISC) // 2
    canvas.paste(scene, (off, off), mask)
    # an inner shadow so the scene sits inside the ring
    shadow = Image.new('L', (SIZE, SIZE), 0)
    ImageDraw.Draw(shadow).ellipse((off - 6, off - 6, SIZE - off + 6, SIZE - off + 6), outline=150, width=16)
    shadow = shadow.filter(ImageFilter.GaussianBlur(7))
    clip = Image.new('L', (SIZE, SIZE), 0)
    ImageDraw.Draw(clip).ellipse((off, off, SIZE - off - 1, SIZE - off - 1), fill=255)
    from PIL import ImageChops
    canvas.paste(Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 255)), (0, 0), ImageChops.multiply(shadow, clip))
    d = ImageDraw.Draw(canvas)
    dark, light = shade(ring, .42), shade(ring, 1.25)
    d.ellipse((6, 6, SIZE - 7, SIZE - 7), outline=dark, width=30)
    d.ellipse((12, 12, SIZE - 13, SIZE - 13), outline=ring, width=20)
    d.arc((14, 14, SIZE - 15, SIZE - 15), 200, 340, fill=light, width=6)
    d.ellipse((off - 2, off - 2, SIZE - off + 1, SIZE - off + 1), outline=dark, width=4)
    for i in range(12):
        a = math.radians(i * 30 + 15)
        bolt(d, 256 + math.cos(a) * 228, 256 + math.sin(a) * 228, 9, ring)
    # the banner
    font = ImageFont.truetype(FONT, 58 if len(label) <= 7 else 50 if len(label) <= 9 else 42)
    tw = d.textlength(label, font=font)
    x0, x1, y0, y1 = 256 - tw / 2 - 30, 256 + tw / 2 + 30, 386, 456
    for side in (-1, 1):            # tails tucked behind
        tx = x0 if side < 0 else x1
        tail = [(tx - side * 10, y0 + 14), (tx + side * 34, y0 + 14), (tx + side * 20, (y0 + y1) / 2 + 7), (tx + side * 34, y1 + 2), (tx - side * 10, y1 + 2)]
        d.polygon(tail, fill=dark)
    d.rounded_rectangle((x0, y0 + 4, x1, y1 + 4), radius=20, fill=shade(ring, .25))
    d.rounded_rectangle((x0, y0, x1, y1), radius=20, fill=ring, outline=dark, width=5)
    d.rounded_rectangle((x0 + 8, y0 + 7, x1 - 8, y0 + 22), radius=8, fill=light)
    d.text((256, (y0 + y1) / 2 + 1), label, font=font, fill=(255, 255, 255), anchor='mm', stroke_width=5, stroke_fill=dark)
    canvas.save(HERE / f'{name}.png')
    return canvas


made = [
    badge('welcome', (62, 196, 200), 'WELCOME'),
    badge('firstFusion', (245, 130, 40), 'FUSED!'),
    badge('firstGhost', (70, 210, 160), 'GHOST RIDER'),
    badge('secretCar', (230, 172, 40), 'SECRET'),
    badge('firstRebirth', (150, 90, 230), 'REBIRTH'),
    badge('maxRebirth', (245, 185, 40), 'MAX x4'),
    badge('raceFinish', (225, 65, 55), 'FINISHED!'),
    badge('collector', (70, 140, 240), '25 BUILDS'),
    badge('masterBuilder', (245, 185, 40), 'MASTER'),
    badge('ghostCollector', (130, 90, 220), 'SPECTRAL'),
]
sheet = Image.new('RGBA', (SIZE * 5, SIZE * 2), (28, 24, 40, 255))
for i, im in enumerate(made):
    sheet.alpha_composite(im, ((i % 5) * SIZE, (i // 5) * SIZE))
sheet.convert('RGB').save(HERE / 'badges-sheet.png')
print('made', len(made), 'with', FONT)
