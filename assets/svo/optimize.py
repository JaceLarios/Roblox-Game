"""Lighter separate-wheel SVO export; original v7 and LogoCover remain untouched."""
import bpy,json,math
from pathlib import Path
from mathutils import Vector
P=Path(__file__).resolve().parent;out=P/'optimized';out.mkdir(exist_ok=True)
bpy.ops.wm.open_mainfile(filepath=str(P.parent/'game-polish-20260930/SVO-Larger-Decals-v7.blend'))
dg=bpy.context.evaluated_depsgraph_get();parts=[];objects=[]
for o in list(bpy.context.scene.objects):
 if o.type!='MESH' or o.name=='Preview Floor':continue
 me=bpy.data.meshes.new_from_object(o.evaluated_get(dg));matrix=o.matrix_world.copy();label=o.name
 fresh=bpy.data.objects.new(label+' game',me);bpy.context.collection.objects.link(fresh);fresh.matrix_world=matrix
 bpy.data.objects.remove(o,do_unlink=True);fresh.name=label;objects.append(fresh)
 me.calc_loop_triangles();count=len(me.loop_triangles)
 ratio=.15 if label=='Body'else .055 if label=='Taillights'else .23 if label.startswith('Wheel')else .18 if label.startswith('Red SVO')else .42
 if count>600:
  bpy.context.view_layer.objects.active=fresh;mod=fresh.modifiers.new('Game mesh reduction','DECIMATE');mod.ratio=ratio;bpy.ops.object.modifier_apply(modifier=mod.name)
 # Recompute split normals after simplifying; stale custom normals cause rippled paint.
 fresh.data.normals_split_custom_set([(0,0,0)]*len(fresh.data.loops))
 fresh.data.set_sharp_from_angle(angle=math.radians(38))
 for f in fresh.data.polygons:f.use_smooth=True
 bpy.context.view_layer.objects.active=fresh
 mod=fresh.modifiers.new('Area weighted clean panel normals','WEIGHTED_NORMAL');mod.keep_sharp=True;mod.weight=50
 bpy.ops.object.modifier_apply(modifier=mod.name)
for o in objects:
 me=o.data;me.calc_loop_triangles();groups={}
 for t in me.loop_triangles:
  side=('L'if sum((o.matrix_world@me.vertices[v].co).x for v in t.vertices)>0 else 'R')if o.name.startswith('Wheel')else ''
  groups.setdefault((t.material_index,side),[]).append(t)
 for (mi,side),tris in groups.items():
  mn=me.materials[mi].name if mi<len(me.materials)and me.materials[mi]else'Default'
  for start in range(0,len(tris),14000):
   vs=[];ns=[];uv=[];ts=[];lookup={}
   for t in tris[start:start+14000]:
    ids=[]
    for li in t.loops:
     v=o.matrix_world@me.vertices[me.loops[li].vertex_index].co;n=o.matrix_world.to_3x3().inverted().transposed()@me.corner_normals[li].vector;n.normalize()
     pt=[round(v.x*2.5,6),round(v.z*2.5,6),round(-v.y*2.5,6)];normal=[n.x,n.z,-n.y];tex=list(me.uv_layers.active.data[li].uv)if me.uv_layers.active else[0,0];key=tuple(pt+normal+tex)
     if key not in lookup:lookup[key]=len(vs);vs.append(pt);ns.append(normal);uv.append(tex)
     ids.append(lookup[key])
    if len(set(ids))==3:ts.append(ids)
   parts.append({'name':o.name+'_'+mn+'_'+side+str(start//14000),'sourcePrefix':o.name+'_'+mn+'_','object':o.name,'wheelId':('Rear'if 'Rear'in o.name else'Front')+side if side else None,'vertices':vs,'normals':ns,'uvs':uv,'triangles':ts})
for wheel in {g['wheelId']for g in parts if g['wheelId']}:
 tire=[v for g in parts if g['wheelId']==wheel and 'Tire'in g['name']for v in g['vertices']]
 lo=[min(v[i]for v in tire)for i in range(3)];hi=[max(v[i]for v in tire)for i in range(3)]
 for g in parts:
  if g['wheelId']==wheel:g['wheel']={'id':wheel,'pivot':[(a+b)/2 for a,b in zip(lo,hi)],'radius':(hi[1]-lo[1])/2}
total=sum(len(g['triangles'])for g in parts);assert total<90000,total
for i,g in enumerate(parts):(out/f'part-{i}.json').write_text(json.dumps(g,separators=(',',':')))
manifest={'name':'SVO','parts':len(parts),'triangles':total,'wheels':sorted({g['wheelId']for g in parts if g['wheelId']}),'length':12.13484,'preserveLogoCover':True}
(out/'manifest.json').write_text(json.dumps(manifest,indent=2))
bpy.ops.wm.save_as_mainfile(filepath=str(out/'SVO-Game-Optimized.blend'))
scene=bpy.context.scene;scene.cycles.samples=16;scene.render.resolution_percentage=50
for suffix,xyz in [('front',(8,-12,6)),('rear',(-8,12,6))]:
 cam=scene.camera;center=Vector((0,0,.55));cam.location=Vector(xyz)*.40;cam.rotation_euler=(center-cam.location).to_track_quat('-Z','Y').to_euler()
 scene.render.filepath=str(out/('SVO-'+suffix+'.png'));bpy.ops.render.render(write_still=True)
print('OPTIMIZED_SVO',manifest,flush=True)
