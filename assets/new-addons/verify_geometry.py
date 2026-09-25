import json, math
from pathlib import Path
p=Path(__file__).resolve().parent
report=[]
for item in json.loads((p/'manifest.json').read_text()):
 d=json.loads((p/item['file']).read_text());lo=[float('inf')]*3;hi=[float('-inf')]*3
 for part in d['parts']:
  assert len(part['vertices'])==len(part['normals'])
  for v,n in zip(part['vertices'],part['normals']):
   assert all(math.isfinite(x) for x in (*v,*n))
   assert abs(sum(x*x for x in n)-1)<.001
   for i in range(3):lo[i]=min(lo[i],v[i]);hi[i]=max(hi[i],v[i])
  for tri in part['triangles']:
   assert len(set(tri))==3 and all(0<=x<len(part['vertices']) for x in tri)
  assert len(part['triangles'])<20000
 size=[round(b-a,5) for a,b in zip(lo,hi)]
 assert abs(max(size)-item['maxDimension'])<.001
 report.append({'name':item['name'],'size':size,'parts':item['parts'],'triangles':item['triangles'],'geometryValidated':True})
(p/'geometry-validation.json').write_text(json.dumps(report,indent=2))
print('Validated finite geometry, unit normals, triangle indices, per-mesh triangle limits and rarity reference scale for all ten models.')
