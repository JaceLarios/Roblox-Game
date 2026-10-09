import bpy,json,math
from pathlib import Path
from mathutils import Vector
P=Path(__file__).resolve().parent;catalog=json.loads((P/'catalog.json').read_text());report=[]
for r in catalog:
 bpy.ops.wm.open_mainfile(filepath=str(P/r['blend']));s=bpy.context.scene
 assert s.get('LayoutRevision')=='Varied placement v2'
 assert s.get('CleanRestored') and s.get('FusionAddon')==r['addon']
 assert not any('Loose front bumper' in o.name for o in s.objects)
 mat=bpy.data.materials['Body_MAT'];assert not any('Rust patch' in n.name for n in mat.node_tree.nodes)
 assert (P/r['preview']).exists();assert bpy.data.objects.get('Honda_Civic_Body')
 pts=[o.matrix_world@Vector(v)for o in s.objects if o.type=='MESH'and not o.hide_render and o.name!='PREVIEW FLOOR'for v in o.bound_box]
 report.append({'addon':r['addon'],'cleanPaint':True,'repairedBody':True,'components':sum(o.type in ['MESH','CURVE']and not o.hide_render and o.name!='PREVIEW FLOOR'for o in s.objects),'bounds':[max(v[i]for v in pts)-min(v[i]for v in pts)for i in range(3)],'gameIntegrated':False})
(P/'validation.json').write_text(json.dumps({'total':len(report),'sourceCommit':'f6e79c6','checks':report,'limits':'Blender authoring and render review only. No game registration, mesh optimization, texture baking, dynamic VFX or race playtest.'},indent=2));print('VALIDATED',len(report),flush=True)
