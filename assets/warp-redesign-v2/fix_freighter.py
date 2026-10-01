from pathlib import Path
import json
P=Path(__file__).resolve().parent
s=(P/'build_vehicles.py').read_text().replace('length*.46,.15','length*.525,.15')
(P/'build_vehicles.py').write_text(s)
s=s.replace('manifest=[]','specs=[s for s in specs if s[1]=="Box Truck"]\nmanifest=[]')
s=s.replace("(OUT/'vehicle-manifest.json').write_text(json.dumps(manifest,indent=2))","(OUT/'freighter-manifest.json').write_text(json.dumps(manifest,indent=2))")
s=s.replace('Warp-Redesign-v2.blend','StarFreighter-fit.blend')
exec(compile(s,str(P/'build_vehicles.py'),'exec'))
manifest=json.loads((P/'vehicle-manifest.json').read_text())
new=json.loads((P/'freighter-manifest.json').read_text())[0]
for i,row in enumerate(manifest):
 if row['name']==new['name']:manifest[i]=new
(P/'vehicle-manifest.json').write_text(json.dumps(manifest,indent=2))
