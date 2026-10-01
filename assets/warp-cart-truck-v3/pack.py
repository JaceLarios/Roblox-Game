import json,hashlib,math
from pathlib import Path
from collections import defaultdict
P=Path(__file__).resolve().parent
O=P/'import';O.mkdir(exist_ok=True)
report=[]
for spec in json.loads((P/'vehicle-manifest.json').read_text()):
 d=json.loads((P/spec['file']).read_text());buckets=defaultdict(list)
 for g in d['parts']:
  assert len(g['vertices'])==len(g['normals'])
  assert all(math.isfinite(x)for v in g['vertices']for x in v)
  assert all(len(set(t))==3 and min(t)>=0 and max(t)<len(g['vertices'])for t in g['triangles'])
  buckets[json.dumps([g['material'],g.get('wheel')],sort_keys=True)].append(g)
 packed=[]
 for bucket in buckets.values():
  result=None
  for g in bucket:
   if result is None or len(result['triangles'])+len(g['triangles'])>16000:
    result={'name':g['material']['finish']+' assembly '+str(len(packed)),'material':g['material'],'vertices':[],'normals':[],'triangles':[],'components':[]}
    if g.get('wheel'):result['wheel']=g['wheel']
    packed.append(result)
   offset=len(result['vertices']);result['vertices']+=g['vertices'];result['normals']+=g['normals']
   result['triangles'] += [[i+offset for i in t]for t in g['triangles']]
   result['components']+=g['components']
 for g in packed:
  g['geometryHash']=hashlib.sha256(json.dumps([g['vertices'],g['normals'],g['triangles']],separators=(',',':')).encode()).hexdigest()
 d['parts']=packed
 assert sum(len(g['triangles'])for g in packed)<90000
 wheels={g['wheel']['id']for g in packed if g.get('wheel')}
 assert len(wheels)==(2 if d['base']=='Dirt Bike' else 4)
 (O/spec['file']).write_text(json.dumps(d,separators=(',',':')))
 report.append(dict(spec,parts=len(packed),wheels=len(wheels)))
(O/'manifest.json').write_text(json.dumps(report,indent=2))
print(json.dumps(report,indent=2))
