from PIL import Image,ImageDraw,ImageFont
from pathlib import Path
import json
P=Path(__file__).resolve().parent
rows=json.loads((P/'vehicle-manifest.json').read_text())
font=ImageFont.truetype('C:/Windows/Fonts/arialbd.ttf',17)
for start in range(0,len(rows),12):
 for angle in ['front','rear']:
  batch=rows[start:start+12];sheet=Image.new('RGB',(1280,3*274),(235,240,244));draw=ImageDraw.Draw(sheet)
  for j,s in enumerate(batch):
   path=P/(s['name'].replace(' ','_')+'-'+angle+'.png')
   if not path.exists():continue
   picture=Image.open(path).convert('RGB');picture.thumbnail((320,240));x=j%4*320;y=j//4*274
   sheet.paste(picture,(x,y));draw.text((x+8,y+244),s['name'],fill=(15,25,40),font=font)
  sheet.save(P/f'review-{start//12+1}-{angle}.jpg',quality=92)
