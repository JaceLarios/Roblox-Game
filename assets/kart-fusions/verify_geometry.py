import json,math
from pathlib import Path
p=Path(__file__).parent
manifest=json.loads((p/'manifest.json').read_text());designs=json.loads((p/'designs.json').read_text());assert len(manifest)==15
result=[];hashes=set();parts=0
for entry,spec in zip(manifest,designs):
 d=json.loads((p/entry['file']).read_text());assert d['name']==spec['name'] and d['addon']==spec['addon'] and d['rarity']==spec['rarity'] and d['noseAxis']=='+Z'
 points=[];wheels=set()
 for g in d['parts']:
  assert 0<len(g['triangles'])<=18000
  assert len(g['vertices'])==len(g['normals'])
  for v,n in zip(g['vertices'],g['normals']):assert all(math.isfinite(a)for a in v+n)and abs(sum(a*a for a in n)-1)<.003
  for t in g['triangles']:assert len(set(t))==3 and min(t)>=0 and max(t)<len(g['vertices'])
  if 'wheel' in g:wheels.add(g['wheel']['id']);assert g['wheel']['radius']>0
  hashes.add(g['geometryHash']);parts+=1;points+=g['vertices']
 bounds=[max(v[i]for v in points)-min(v[i]for v in points)for i in range(3)]
 assert max(abs(a-b)for a,b in zip(bounds,d['targetSize']))<.002
 assert len(wheels)==(0 if d['name']=='Hover Heap' else 4)
 assert max(bounds)<7.5,'Collectible became too large'
 result.append({'name':d['name'],'bounds':bounds,'wheels':len(wheels),'triangles':entry['triangles'],'valid':True})
(p/'geometry-validation.json').write_text(json.dumps({'models':result,'uniqueMeshes':len(hashes),'totalParts':parts},indent=2))
print(f'Validated 15 models, {parts} parts, {len(hashes)} unique meshes; recipe metadata, bounds, normals, triangles and wheels.')
