"""Bake Blender's approved linear paint multiply into diffuse atlases for Roblox.
Run after export-roblox.py with Python and Pillow. Does not edit native scenes.
"""
from pathlib import Path
import json
from PIL import Image
p=Path(__file__).resolve().parent/'roblox'
original=Image.open(p/'textures/Honda_Civic_Body_BaseColor.png').convert('RGBA')
new={}
for m in json.loads((p/'manifest.json').read_text())[1:]:
 d=json.loads((p/m['file']).read_text());body=next(x for x in d['parts']if x['name'].startswith('Body_MAT'))
 col=body['appearance'].get('paintTint',body['appearance']['color'])
 name='textures/Paint-'+m['file'].replace('.json','.png');bands=[]
 for ch,scale in zip(original.split()[:3],col):
  def convert(x):
   s=x/255;v=(s/12.92 if s<=.04045 else ((s+.055)/1.055)**2.4)*scale
   return round(255*(12.92*v if v<=.0031308 else 1.055*v**(1/2.4)-.055))
  bands.append(ch.point([convert(i)for i in range(256)]))
 Image.merge('RGBA',(*bands,original.getchannel('A'))).save(p/name)
 for part in d['parts']:
  if part['name'].startswith('Body_MAT'):
   part['appearance']['maps']['ColorMap']=name
   part['appearance']['paintTint']=col;part['appearance']['color']=[1,1,1]
 (p/m['file']).write_text(json.dumps(d,indent=2))
 new[m['name']]=name
(p/'paint-files.json').write_text(json.dumps(new,indent=2))
print('Baked',len(new),'approved paint atlases')
