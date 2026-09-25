from pathlib import Path
import json
p=Path(__file__).parent
required=['Rounded kart bonnet','Headlight housing','Bumper impact bar','Wide upholstered seat base','Padded headrest','Roll hoop','Instrument dashboard']
results=[]
for s in json.loads((p/'designs.json').read_text()):
 d=json.loads((p/(s['name'].replace(' ','_')+'.json')).read_text())
 names=[name for g in d['parts'] for name in g['components']]
 for prefix in required:assert any(n.startswith(prefix) for n in names),(s['name'],prefix)
 results.append({'name':s['name'],'retainsApprovedBodyFeatures':True})
(p/'family-validation.json').write_text(json.dumps(results,indent=2))
print('All 15 variants retain the seven checked approved donor-body features.')
