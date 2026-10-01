"""Preserve approved source files; trim four over-budget exports into import/."""
import bpy,bmesh,json,hashlib,math
from pathlib import Path
P=Path(__file__).resolve().parent
out=P/'import';out.mkdir(exist_ok=True)
report=[]
for spec in json.loads((P/'manifest.json').read_text()):
 d=json.loads((P/spec['file']).read_text());total=sum(len(g['triangles'])for g in d['parts'])
 selected=[g for g in d['parts']if not g.get('wheel') and len(g['triangles'])>2000]
 budget=sum(len(g['triangles'])for g in selected)
 ratio=(budget-max(0,total-87500))/max(1,budget)
 if total>90000:
  for g in selected:
   me=bpy.data.meshes.new('budget');me.from_pydata(g['vertices'],[],g['triangles']);me.update()
   bm=bmesh.new();bm.from_mesh(me);bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.000001);bm.to_mesh(me);bm.free()
   o=bpy.data.objects.new('budget',me);bpy.context.collection.objects.link(o);bpy.context.view_layer.objects.active=o
   for f in me.polygons:f.use_smooth=True
   mod=o.modifiers.new('Conservative production budget','DECIMATE');mod.ratio=max(.5,ratio)
   bpy.ops.object.modifier_apply(modifier=mod.name);me=o.data;me.calc_loop_triangles()
   vs=[];ns=[];ts=[];lookup={}
   for tri in me.loop_triangles:
    ids=[]
    for li in tri.loops:
     v=tuple(round(a,5)for a in me.vertices[me.loops[li].vertex_index].co);n=tuple(round(a,5)for a in me.corner_normals[li].vector);key=v+n
     if key not in lookup:lookup[key]=len(vs);vs.append(v);ns.append(n)
     ids.append(lookup[key])
    if len(set(ids))==3:ts.append(ids)
   g.update(vertices=vs,normals=ns,triangles=ts)
   g['geometryHash']=hashlib.sha256(json.dumps([vs,ns,ts],separators=(',',':')).encode()).hexdigest()
   bpy.data.objects.remove(o,do_unlink=True)
 after=sum(len(g['triangles'])for g in d['parts']);assert after<=90000,(d['name'],after)
 d['base']='Golf Cart';d['productionTriangles']=after
 (out/spec['file']).write_text(json.dumps(d,separators=(',',':')))
 report.append({'name':d['name'],'file':spec['file'],'before':total,'triangles':after,'wheelsUnmodified':True})
(out/'manifest.json').write_text(json.dumps(report,indent=2))
print('GOLF PRODUCTION EXPORTS READY')
