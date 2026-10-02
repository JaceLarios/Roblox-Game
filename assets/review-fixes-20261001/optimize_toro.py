import bpy,json,math,bmesh
from pathlib import Path
P=Path(__file__).resolve().parent;src=P/'toro-live';out=P/'toro-optimized';out.mkdir(exist_ok=True)
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
records=json.loads((src/'manifest.json').read_text());summary=[]
for r in records:
 d=json.loads((src/r['file']).read_text());me=bpy.data.meshes.new(r['name']);me.from_pydata(d['vertices'],[],d['triangles']);me.update()
 uv=me.uv_layers.new(name='UVMap')
 for loop in me.loops:uv.data[loop.index].uv=d['uvs'][loop.vertex_index]
 o=bpy.data.objects.new(r['name'],me);bpy.context.collection.objects.link(o);bpy.context.view_layer.objects.active=o
 bm=bmesh.new();bm.from_mesh(me);bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.000001);bm.to_mesh(me);bm.free()
 if r['triangles']>120:
  mod=o.modifiers.new('Preserve silhouette game reduction','DECIMATE');mod.ratio=.40 if r['wheel']else .54;bpy.ops.object.modifier_apply(modifier=mod.name)
 me=o.data
 me.set_sharp_from_angle(angle=math.radians(38))
 for f in me.polygons:f.use_smooth=True
 mod=o.modifiers.new('Clean panel normals','WEIGHTED_NORMAL');mod.keep_sharp=True;bpy.ops.object.modifier_apply(modifier=mod.name)
 me=o.data;me.calc_loop_triangles();vs=[];ns=[];uvs=[];ts=[]
 for t in me.loop_triangles:
  row=[]
  for li in t.loops:
   row.append(len(vs));vs.append(list(me.vertices[me.loops[li].vertex_index].co));ns.append(list(me.corner_normals[li].vector));uvs.append(list(me.uv_layers.active.data[li].uv))
  ts.append(row)
 (out/r['file']).write_text(json.dumps({'name':r['name'],'vertices':vs,'normals':ns,'uvs':uvs,'triangles':ts},separators=(',',':')))
 summary.append({**r,'originalTriangles':r['triangles'],'triangles':len(ts)})
 print('OPTIMIZED',r['name'],r['triangles'],len(ts),flush=True)
total=sum(r['triangles']for r in summary);assert total<90000,total
(out/'manifest.json').write_text(json.dumps({'parts':summary,'triangles':total,'originalTriangles':sum(r['triangles']for r in records),'rollingParts':sum(r['wheel']for r in records)},indent=2))
bpy.ops.wm.save_as_mainfile(filepath=str(out/'Toro-Optimized-Meshes.blend'))
print('COMPLETE',total,flush=True)
