import json,math
from pathlib import Path
p=Path(__file__).parent
manifest=json.loads((p/'manifest.json').read_text());assert len(manifest)==7
out=[]
for item in manifest:
 d=json.loads((p/item['file']).read_text());assert d['noseAxis']=='+Z'
 points=[]
 for g in d['parts']:
  assert 0<len(g['triangles'])<=18000
  assert len(g['vertices'])==len(g['normals'])
  for v,n in zip(g['vertices'],g['normals']):
   assert all(math.isfinite(a)for a in v+n)
   assert abs(sum(a*a for a in n)-1)<.003
  for t in g['triangles']:assert len(set(t))==3 and min(t)>=0 and max(t)<len(g['vertices'])
  points+=g['vertices']
 bounds=[max(v[i]for v in points)-min(v[i]for v in points)for i in range(3)]
 assert all(abs(a-b)<.002 for a,b in zip(bounds,d['targetSize'])),(item['name'],bounds)
 out.append({'name':item['name'],'bounds':bounds,'parts':len(d['parts']),'triangles':item['triangles'],'valid':True})
(p/'geometry-validation.json').write_text(json.dumps(out,indent=2))
print('Seven models validated: geometry, normals, mesh limits, exact dimensions.')
