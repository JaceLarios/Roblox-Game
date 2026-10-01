from PIL import Image,ImageDraw,ImageFont
from pathlib import Path
import json,shutil
p=Path(__file__).parent;designs=json.loads((p/'designs.json').read_text())
font=ImageFont.truetype('C:/Windows/Fonts/arialbd.ttf',25);small=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',18)
for suffix,label in [('', 'front'),('-rear','rear')]:
 sheet=Image.new('RGB',(1500,2225),'#182d3c');draw=ImageDraw.Draw(sheet)
 for i,s in enumerate(designs):
  im=Image.open(p/(s['name'].replace(' ','_')+suffix+'.png')).convert('RGB');im.thumbnail((500,389))
  x=i%3*500;y=i//3*445;sheet.paste(im,(x,y));draw.text((x+18,y+389),s['name'],font=font,fill='white');draw.text((x+18,y+421),s['addon']+' / '+s['rarity'].title(),font=small,fill='#86dcf8')
 sheet.save(p/('golf-fusions-'+label+'.jpg'),quality=94)
 # Separate readable tier cards for review.
 for tier in range(5):sheet.crop((0,tier*445,1500,(tier+1)*445)).save(p/(f'tier-{tier+1}-{label}.jpg'),quality=94)
dest=p.parent.parent/'work/legendary-main/assets/golf-cart-fusions';dest.mkdir(parents=True,exist_ok=True)
for f in p.iterdir():
 if f.suffix in ['.json','.py','.png','.jpg','.blend','.md'] and not f.name=='finish_previews.py':shutil.copy2(f,dest/f.name)
# Build textures are siblings in the repository layout.
f=dest/'build_golf.py';s=f.read_text().replace("OUT.parent/'new-addons/v2/textures'","OUT.parent/'new-addons/textures'");f.write_text(s)
print('Saved front/rear previews, five tier cards, and local repository source/assets.')
