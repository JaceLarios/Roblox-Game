import json,math,hashlib
from collections import defaultdict
from pathlib import Path
P=Path(__file__).resolve().parent;out=P/'import';out.mkdir(exist_ok=True)
manifest=json.loads((P/'vehicle-manifest.json').read_text());report=[]
for s in manifest:
 d=json.loads((P/s['file']).read_text());buckets=defaultdict(list)
 for g in d['parts']:
  if 'finish'not in g['material']:
   m=g['material'];m['finish']='Light'if m.get('glow',0)else'Brushed'if m.get('metal',0)>.7 else'Enamel'
  assert len(g['vertices'])==len(g['normals'])
  assert all(math.isfinite(v)for row in g['vertices']for v in row)
  assert all(len(set(t))==3 and min(t)>=0 and max(t)<len(g['vertices'])for t in g['triangles'])
  assert len(g['triangles'])<18000,(d['name'],g['name'])
  buckets[json.dumps([g['material'],g.get('wheel')],sort_keys=True)].append(g)
 packed=[]
 for groups in buckets.values():
  current=None
  for g in groups:
   if current is None or len(current['triangles'])+len(g['triangles'])>17000:
    current={'name':g['material']['finish']+'_'+str(len(packed)),'material':g['material'],'vertices':[],'normals':[],'triangles':[],'components':[]}
    if g.get('wheel'):current['wheel']=g['wheel']
    packed.append(current)
   offset=len(current['vertices']);current['vertices']+=g['vertices'];current['normals']+=g['normals'];current['triangles'] +=[[v+offset for v in t]for t in g['triangles']];current['components']+=g.get('components',[g['name']])
 for g in packed:g['geometryHash']=hashlib.sha256(json.dumps([g['vertices'],g['normals'],g['triangles']],separators=(',',':')).encode()).hexdigest()
 wheels={g['wheel']['id']for g in packed if g.get('wheel')};assert len(wheels)==s['expectedWheels'],d['name']
 count=sum(len(g['triangles'])for g in packed);assert count<90000
 d.update(parts=packed,expectedWheels=s['expectedWheels'],revision='RemainingFusions_20261001_v1')
 (out/s['file']).write_text(json.dumps(d,separators=(',',':')))
 report.append({**s,'parts':len(packed),'triangles':count})
(out/'manifest.json').write_text(json.dumps(report,indent=2))
print('VALIDATED',len(report),'models;',sum(s['parts']for s in report),'mesh parts')
