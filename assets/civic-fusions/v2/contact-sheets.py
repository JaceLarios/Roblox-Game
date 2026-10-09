from PIL import Image,ImageDraw,ImageFont
from pathlib import Path
import json
P=Path(__file__).resolve().parent
rows=json.loads((P/'catalog.json').read_text())
font=ImageFont.truetype('C:/Windows/Fonts/arialbd.ttf',21)
small=ImageFont.truetype('C:/Windows/Fonts/arial.ttf',16)
labels=['Rear-hatch bottle cassette','Sky-high rear straight pipes','Exposed front-sill turbo','Club-racer hood engine','Rear rotary conversion','Bumper delete / exposed twin turbos','Flush glass engine cover','Hood blower and drag headers','B-pillar exhaust stacks','Rear V8 and wheelie bars','Long-nose V12 tourer','Four corner lift fans','Hatch turbine and roof intake','Twin rearward rocket nacelles','Open-cabin reactor cradle','Rear portal and sill coils','Roof lantern bar','Rear ghost exhaust','Roof-mounted crystal','Front gothic grille','Hatch ectoplasm tank','Roof trumpet bank','Spectral rear wing','Coffin roof carrier','Cauldron hatch','Sail and reinforced roof mast','Four ghost wheels','Rear-quarter soul turbo','Hearse roof conversion','Quarter-panel scythes','Cabin chauffeur and moonroof']
for title,a,b,file in [('CIVIC / REWORKED MECHANICAL PLACEMENTS',0,16,'mechanical-lineup.jpg'),('CIVIC / PHANTOM ADDON PLACEMENTS',16,31,'phantom-lineup.jpg')]:
 sheet=Image.new('RGB',(1680,1490),(20,28,38));d=ImageDraw.Draw(sheet);d.text((25,18),title,font=font,fill='white')
 for j,r in enumerate(rows[a:b]):
  im=Image.open(P/r['preview']).convert('RGB');im.thumbnail((420,300));x=j%4*420;y=60+j//4*355;sheet.paste(im,(x,y));d.text((x+12,y+303),r['addon'],font=font,fill='white');d.text((x+12,y+328),labels[a+j],font=small,fill=(159,193,213))
 sheet.save(P/file,quality=94)
# A closer sheet makes the new rear and side integrations easier to judge.
chosen=[2,4,9,14]
sheet=Image.new('RGB',(1680,1340),(20,28,38));d=ImageDraw.Draw(sheet)
for j,i in enumerate(chosen):
 im=Image.open(P/rows[i]['preview']).convert('RGB');x=j%2*840;y=j//2*670;sheet.paste(im,(x,y));d.text((x+24,y+606),rows[i]['addon'],font=font,fill='white');d.text((x+24,y+637),labels[i],font=small,fill=(159,193,213))
sheet.save(P/'new-placement-closeups.jpg',quality=94)
