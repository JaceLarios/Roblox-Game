"""Nav-rail icon for the QUESTS button, in the style of the illustrated
atlas (and bat_icon.png): a chunky clipboard with a metal clip, a cream
sheet with three task rows, two ticked in green and one still open, and a
gold star badge in the corner. Thick dark outline, soft two-tone shading,
a gloss stripe. 512x512, transparent, drawn at 4x and scaled down."""
import os
from PIL import Image, ImageDraw

HERE = os.path.dirname(os.path.abspath(__file__))
S = 4
W = 512 * S
OUT = (22, 30, 48, 255)
LINE = 12 * S


def P(x, y):
    return (x * S, y * S)


def box(x0, y0, x1, y1):
    return [P(x0, y0), P(x1, y1)]


img = Image.new("RGBA", (W, W), (0, 0, 0, 0))
d = ImageDraw.Draw(img)

# The board: outline first, then the wood, then a darker lower half.
d.rounded_rectangle(box(86, 70, 406, 470), radius=40 * S, fill=OUT)
d.rounded_rectangle(box(98, 82, 394, 458), radius=32 * S, fill=(196, 128, 64, 255))
d.rounded_rectangle(box(98, 300, 394, 458), radius=32 * S, fill=(170, 104, 48, 255))
d.rectangle(box(98, 300, 394, 330), fill=(170, 104, 48, 255))
# A gloss stripe down the left edge of the board.
d.rounded_rectangle(box(112, 100, 132, 430), radius=10 * S, fill=(226, 166, 104, 255))

# The sheet.
d.rounded_rectangle(box(126, 118, 366, 440), radius=18 * S, fill=OUT)
d.rounded_rectangle(box(136, 128, 356, 430), radius=12 * S, fill=(255, 248, 226, 255))
d.rectangle(box(136, 380, 356, 430), fill=(244, 232, 200, 255))
d.rounded_rectangle(box(136, 380, 356, 430), radius=12 * S, fill=(244, 232, 200, 255))

# Three rows: a box, then a line of "writing".
rows = [(186, True), (256, True), (326, False)]
for y, ticked in rows:
    d.rounded_rectangle(box(156, y - 24, 204, y + 24), radius=10 * S, fill=OUT)
    d.rounded_rectangle(box(164, y - 16, 196, y + 16), radius=6 * S,
                        fill=(92, 214, 120, 255) if ticked else (255, 255, 255, 255))
    d.rounded_rectangle(box(222, y - 9, 336, y + 9), radius=9 * S,
                        fill=(172, 160, 140, 255) if ticked else (120, 110, 96, 255))
    if ticked:
        tick = [P(166, y - 2), P(180, y + 14), P(210, y - 26)]
        d.line(tick, fill=OUT, width=18 * S, joint="curve")
        d.line(tick, fill=(40, 170, 80, 255), width=9 * S, joint="curve")

# The clip at the top.
d.rounded_rectangle(box(176, 44, 316, 112), radius=20 * S, fill=OUT)
d.rounded_rectangle(box(188, 56, 304, 100), radius=14 * S, fill=(168, 184, 200, 255))
d.rounded_rectangle(box(188, 56, 304, 72), radius=8 * S, fill=(214, 226, 238, 255))
d.ellipse(box(232, 58, 260, 86), fill=OUT)
d.ellipse(box(239, 65, 253, 79), fill=(110, 124, 140, 255))

# The gold star badge, bottom right.
import math
cx, cy, r_out, r_in = 372, 404, 84, 38
star = []
for i in range(10):
    r = r_out if i % 2 == 0 else r_in
    a = math.pi * i / 5 - math.pi / 2
    star.append(P(cx + math.cos(a) * r, cy + math.sin(a) * r))
d.line(star + [star[0]], fill=OUT, width=LINE * 2, joint="curve")
d.polygon(star, fill=(255, 196, 40, 255))
inner = []
for i in range(10):
    r = (r_out if i % 2 == 0 else r_in) * 0.62
    a = math.pi * i / 5 - math.pi / 2
    inner.append(P(cx - 6 + math.cos(a) * r, cy - 8 + math.sin(a) * r))
d.polygon(inner, fill=(255, 232, 130, 255))

img = img.resize((512, 512), Image.LANCZOS)
img.save(os.path.join(HERE, "quests_icon.png"))
print("saved", os.path.join(HERE, "quests_icon.png"))
