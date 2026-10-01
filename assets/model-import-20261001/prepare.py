import json,math,hashlib
from pathlib import Path
from collections import defaultdict
P=Path(__file__).resolve().parent;A=P.parent;O=P/'data';O.mkdir(exist_ok=True)
manifest=[]
sources=[(A/'warp-cart-truck-v3/import','manifest.json'),(A/'golf-cart-fusions/import','manifest.json'),(A/'legendary-production','vehicle-manifest.json')]
for folder,filename in sources:
 for spec in json.loads((folder/filename).read_text()):
  d=json.loads((folder/spec['file']).read_text());groups=defaultdict(list)
  for g in d['parts']:
   assert len(g['vertices'])==len(g['normals'])
   assert all(math.isfinite(v)for row in g['vertices']for v in row)
   assert all(len(set(t))==3 and min(t)>=0 and max(t)<len(g['vertices'])for t in g['triangles'])
   assert len(g['triangles'])<=18000
   groups[json.dumps([g['material'],g.get('wheel')],sort_keys=True)].append(g)
  packed=[]
  for bucket in groups.values():
   current=None
   for g in bucket:
    if current is None or len(current['triangles'])+len(g['triangles'])>17000:
     current={'name':g['material']['finish']+'_'+str(len(packed)),'material':g['material'],'vertices':[],'normals':[],'triangles':[],'components':[]}
     if g.get('wheel'):current['wheel']=g['wheel']
     packed.append(current)
    offset=len(current['vertices']);current['vertices']+=g['vertices'];current['normals']+=g['normals']
    current['triangles'] += [[v+offset for v in t]for t in g['triangles']];current['components']+=g.get('components',[g['name']])
  for g in packed:g['geometryHash']=hashlib.sha256(json.dumps([g['vertices'],g['normals'],g['triangles']],separators=(',',':')).encode()).hexdigest()
  wheels={g['wheel']['id']for g in packed if g.get('wheel')};expected=0 if d['name']in ['Hover Caddy','Atomic Albatross']else 4
  assert len(wheels)==expected,(d['name'],wheels)
  count=sum(len(g['triangles'])for g in packed);assert count<90000
  d['parts']=packed;d['expectedWheels']=expected
  d['revision']='CartTruck_20261001_v3' if 'warp-cart' in str(folder)else 'GolfFusions_20261001_v5' if 'golf-cart' in str(folder)else 'Legendary_20261001_v1'
  (O/spec['file']).write_text(json.dumps(d,separators=(',',':')))
  manifest.append({'name':d['name'],'file':spec['file'],'base':d['base'],'addon':d['addon'],'rarity':d['rarity'],'wheels':expected,'triangles':count,'parts':len(packed),'source':str(folder.relative_to(A))})
assert len(manifest)==25 and len({x['name']for x in manifest})==25
(P/'manifest.json').write_text(json.dumps(manifest,indent=2))
print('Validated',len(manifest),'models,',sum(x['parts']for x in manifest),'mesh parts')
