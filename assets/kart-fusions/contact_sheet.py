from PIL import Image,ImageDraw,ImageFont
from pathlib import Path
import json
p=Path(__file__).parent;designs=json.loads((p/'designs.json').read_text())
font=ImageFont.truetype('C:/Windows/Fonts/arialbd.ttf',25);small=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',18)
sheet=Image.new('RGB',(1500,2225),'#182d3c');draw=ImageDraw.Draw(sheet)
for i,s in enumerate(designs):
 im=Image.open(p/(s['name'].replace(' ','_')+'.png')).convert('RGB');im.thumbnail((500,389))
 x=i%3*500;y=i//3*445;sheet.paste(im,(x,y));draw.text((x+18,y+389),s['name'],font=font,fill='white');draw.text((x+18,y+421),s['addon']+'  /  '+s['rarity'].title(),font=small,fill='#86dcf8')
sheet.save(p/'fifteen-fusions-preview.jpg',quality=93)
