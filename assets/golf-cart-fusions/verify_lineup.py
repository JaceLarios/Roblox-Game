import json
from pathlib import Path
p=Path(__file__).parent
reports=[]
for s in json.loads((p/'designs.json').read_text()):
 d=json.loads((p/(s['name'].replace(' ','_')+'.json')).read_text())
 n=[n for g in d['parts']for n in g['components']]
 for feature in ['Golf cart cream canopy','Straight golf canopy pillar','Continuous golf bench cushion','Continuous golf bench back','Golf folding windscreen','Golf windshield hinge','Golf ball holder']:
  assert any(x.startswith(feature)for x in n),(s['name'],feature)
 assert sum(x.startswith('Straight golf canopy pillar')for x in n)==4
 reports.append({'name':s['name'],'cartIdentityFeatures':True})
(p/'lineup-validation.json').write_text(json.dumps(reports,indent=2))
print('All 15 have cart canopies, four straight pillars, benches, folding windscreens and golf details.')
