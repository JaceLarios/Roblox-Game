from pathlib import Path
import json
P=Path(__file__).resolve().parent
designs={
'Warp Wreck':'Slingshot drag kart with nose reactor, swept accelerator rails and rear stabilizers',
'Wormhole Wheelie':'Landspeed bike with under-saddle warp tunnel, sculpted fairings and tail nozzle',
'Hole in Space':'Twin canopy accelerator pods, front-cowl generator and illuminated running boards',
'Warp Warden':'Armored pursuit interceptor with twin hood accelerators and swept rear wing',
'Star Freighter':'Rear cargo portal, four-rib cargo exoskeleton and long side engine rails',
'Starcrusher':'Hydraulic cyclone cage gripping a horizontal bed reactor and flared armored shoulders'}
for folder in [P,P/'import']:
 for name,design in designs.items():
  path=folder/(name.replace(' ','_')+'.json');d=json.loads(path.read_text());d['design']=design;path.write_text(json.dumps(d,separators=(',',':')))
 path=folder/('manifest.json' if folder.name=='import' else 'vehicle-manifest.json')
 data=json.loads(path.read_text())
 for row in data:row['design']=designs[row['name']]
 path.write_text(json.dumps(data,indent=2))
# Keep the Blender builder reproducible with the reviewed geometry budget.
gen=P.parent/'warp-drive-batch/make_revision.py'
s=gen.read_text();s=s.replace("s=s.replace('Warp-Vehicles-v1.blend','Warp-Redesign-v2.blend')","s=s.replace('Warp-Vehicles-v1.blend','Warp-Redesign-v2.blend').replace('total-87500','total-82500').replace('max(.45,','max(.30,')")
gen.write_text(s)
print('Design metadata updated')
