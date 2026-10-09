"""Badge pictures for the Roblox badges (ServerStorage.Badges, docs/BADGES.md).

python make_badges.py  -> one 512x512 PNG per badge here, plus badges-sheet.png.
Built from the game's own model renders: the picture in a disc, a coloured
ring and a short label. Roblox shows badge pictures as circles, so
everything that matters stays inside the disc.
"""
from pathlib import Path
from PIL import Image, ImageDraw, ImageFont, ImageEnhance, ImageOps

HERE = Path(__file__).resolve().parent
ASSETS = HERE.parent
SIZE = 512
FONT = 'C:/Windows/Fonts/impact.ttf'


def square(path, zoom=0.82, shift=(0, 0)):
    im = Image.open(ASSETS / path).convert('RGB')
    w, h = im.size
    side = int(min(w, h) * zoom)
    cx, cy = w // 2 + int(shift[0] * w), h // 2 + int(shift[1] * h)
    return im.crop((cx - side // 2, cy - side // 2, cx + side // 2, cy + side // 2))


def grid(paths, n):
    cell = 512 // n
    out = Image.new('RGB', (cell * n, cell * n), (30, 26, 44))
    for i, p in enumerate(paths[:n * n]):
        out.paste(square(p, 0.9).resize((cell, cell), Image.LANCZOS), ((i % n) * cell, (i // n) * cell))
    return out


def badge(name, picture, ring, label, tint=None):
    canvas = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    disc = picture.resize((452, 452), Image.LANCZOS).convert('RGB')
    if tint:
        disc = Image.blend(disc, Image.new('RGB', disc.size, tint[0]), tint[1])
    mask = Image.new('L', disc.size, 0)
    ImageDraw.Draw(mask).ellipse((0, 0, 451, 451), fill=255)
    canvas.paste(disc, (30, 30), mask)
    d = ImageDraw.Draw(canvas)
    dark = tuple(int(c * .45) for c in ring)
    d.ellipse((14, 14, 497, 497), outline=dark, width=30)
    d.ellipse((20, 20, 491, 491), outline=ring, width=20)
    d.ellipse((38, 38, 473, 473), outline=(255, 255, 255, 120), width=3)
    font = ImageFont.truetype(FONT, 64 if len(label) <= 8 else 52)
    tw = d.textlength(label, font=font)
    box = (256 - tw / 2 - 26, 372, 256 + tw / 2 + 26, 452)
    d.rounded_rectangle(box, radius=22, fill=ring, outline=dark, width=6)
    d.text((256, 410), label, font=font, fill=(255, 255, 255), anchor='mm', stroke_width=4, stroke_fill=dark)
    canvas.save(HERE / f'{name}.png')
    return canvas


def silhouette(path):
    im = square(path)
    grey = ImageOps.grayscale(im)
    return Image.merge('RGB', [grey.point(lambda v: 18 if v < 150 else 70)] * 3)


def with_mark(picture, mark, colour):
    picture = picture.copy().resize((452, 452))
    d = ImageDraw.Draw(picture)
    font = ImageFont.truetype(FONT, 230)
    d.text((226, 190), mark, font=font, fill=colour, anchor='mm', stroke_width=8, stroke_fill=(20, 16, 28))
    return picture


def checker(picture):
    """The car cut out of its plain render backdrop, over a chequered flag."""
    picture = picture.copy().resize((452, 452))
    flag = Image.new('RGB', (452, 452), (255, 255, 255))
    d = ImageDraw.Draw(flag)
    for y in range(0, 452, 38):
        for x in range(0, 452, 38):
            if (x // 38 + y // 38) % 2: d.rectangle((x, y, x + 37, y + 37), fill=(24, 24, 30))
    # The backdrop is a soft grey gradient: anything close to the colour at
    # its own height (sampled at the left edge) is backdrop.
    px = picture.load()
    mask = Image.new('L', picture.size, 0)
    mp = mask.load()
    for y in range(452):
        bg = px[2, y]
        for x in range(452):
            c = px[x, y]
            if sum(abs(c[i] - bg[i]) for i in range(3)) > 36: mp[x, y] = 255
    from PIL import ImageFilter
    mask = mask.filter(ImageFilter.MedianFilter(5)).filter(ImageFilter.GaussianBlur(1))
    flag.paste(picture, (0, 0), mask)
    return flag


BUILDS = ['remaining-fusions/Scrapyard_God-front.png', 'remaining-fusions/Hover_Hulk-front.png',
          'remaining-fusions/Sky_Marshal-front.png', 'remaining-fusions/Junk_Mashup-front.png',
          'remaining-fusions/Afterburner_GT-front.png', 'remaining-fusions/Blown_Charger-front.png',
          'remaining-fusions/Riot_Rig-front.png', 'remaining-fusions/Mangled_Overlord-front.png',
          'remaining-fusions/Rotor_Rebel-front.png']
GHOSTS = ['phantom-builds/Wisp_Kart.png', 'phantom-builds/Banshee_Muscle.png',
          'phantom-builds/Specter_Hauler.png', 'phantom-builds/Wraith_Crusher.png']

made = [
    badge('welcome', square('base-cars/Rusted_Sedan.png'), (62, 196, 200), 'WELCOME'),
    badge('firstFusion', square('remaining-fusions/Junk_Mashup-front.png'), (240, 140, 50), 'FUSED!'),
    badge('firstGhost', square('phantom-builds/Wisp_Kart.png'), (90, 220, 170), 'GHOST'),
    badge('secretCar', with_mark(silhouette('base-cars/Monster_Truck.png'), '?', (255, 205, 60)), (230, 175, 40), 'SECRET'),
    badge('firstRebirth', square('base-cars/Muscle_Car.png'), (150, 90, 230), 'REBIRTH', tint=((150, 90, 230), .18)),
    badge('maxRebirth', square('warp-drive-batch/Starcrusher.png'), (255, 190, 40), 'MAX', tint=((255, 200, 60), .12)),
    badge('raceFinish', checker(square('remaining-fusions/Afterburner_GT-front.png')), (220, 60, 60), 'FINISH'),
    badge('collector', grid(BUILDS, 2), (70, 140, 240), '25'),
    badge('masterBuilder', grid(BUILDS, 3), (255, 190, 40), 'MASTER'),
    badge('ghostCollector', grid(GHOSTS, 2), (150, 90, 230), 'SPECTRAL', tint=((150, 255, 210), .12)),
]
sheet = Image.new('RGBA', (SIZE * 5, SIZE * 2), (28, 24, 40, 255))
for i, im in enumerate(made):
    sheet.alpha_composite(im, ((i % 5) * SIZE, (i // 5) * SIZE))
sheet.convert('RGB').save(HERE / 'badges-sheet.png')
print('made', len(made))
