from PIL import Image, ImageDraw, ImageFont
from pathlib import Path
import json
p=Path(__file__).resolve().parent
items=json.loads((p/'manifest.json').read_text())
sheet=Image.new('RGB',(1600,780),(23,29,39));draw=ImageDraw.Draw(sheet)
font=ImageFont.truetype('C:/Windows/Fonts/arialbd.ttf',21)
small=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',16)
for i,item in enumerate(items):
 x=i%5*320;y=i//5*390
 im=Image.open(p/(item['name'].replace(' ','_')+'.png')).convert('RGB');im.thumbnail((316,310));sheet.paste(im,(x+(320-im.width)//2,y+10))
 draw.text((x+12,y+302),item['name'],font=font,fill='white')
 draw.text((x+12,y+332),item['rarity'].upper(),font=small,fill=(93,212,241))
sheet.save(p/'addon-lineup-preview.jpg',quality=93)
