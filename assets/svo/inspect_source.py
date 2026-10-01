import bpy,json
from pathlib import Path
P=Path(__file__).resolve().parent
bpy.ops.wm.open_mainfile(filepath=str(P.parent/'game-polish-20260930/SVO-Larger-Decals-v7.blend'))
rows=[]
for o in bpy.context.scene.objects:
 if o.type!='MESH' or o.name=='Preview Floor':continue
 o.data.calc_loop_triangles()
 rows.append({'name':o.name,'triangles':len(o.data.loop_triangles),'modifiers':[(m.name,m.type)for m in o.modifiers]})
(P/'source-inspection.json').write_text(json.dumps(rows,indent=2))
print('SVO',sum(x['triangles']for x in rows),rows)
