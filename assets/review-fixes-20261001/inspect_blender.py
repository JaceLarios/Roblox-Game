import bpy,json
from pathlib import Path
from mathutils import Vector
P=Path(__file__).resolve().parent
out={}
for file in ['base-cars/Junkyard-Seven-Base-Cars.blend','game-polish-20260930/Toro-Closed-Kit-v14.blend']:
 bpy.ops.wm.open_mainfile(filepath=str(P.parent/file))
 rows=[]
 for o in bpy.context.scene.objects:
  if o.type not in ['MESH','FONT']:continue
  if 'base-cars' in file and not any(w in o.name.lower() for w in ['billboard','graphic','gear emblem']):continue
  pts=[o.matrix_world@Vector(v) for v in o.bound_box]
  lo=[min(v[i]for v in pts)for i in range(3)];hi=[max(v[i]for v in pts)for i in range(3)]
  rows.append({'name':o.name,'bounds':[lo,hi],'materials':[m.name for m in o.data.materials],'triangles':len(o.data.polygons) if o.type=='MESH'else 0})
 out[file]=rows
(P/'inspection.json').write_text(json.dumps(out,indent=2))
print('INSPECTED',[(k,len(v))for k,v in out.items()])
