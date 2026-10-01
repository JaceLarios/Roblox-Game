import bpy,os,json
from mathutils import Vector
ROOT=os.path.dirname(os.path.abspath(__file__))
body=bpy.data.objects['Body'];rows=[]
for ob in bpy.context.scene.objects:
 if not ob.name.startswith('Red SVO '):continue
 side=1 if 'Right' in ob.name else -1
 points=[ob.matrix_world@v.co for v in ob.data.vertices];cy=sum(v.y for v in points)/len(points);cz=sum(v.z for v in points)/len(points)
 inv=body.matrix_world.inverted()
 for vert,pt in zip(ob.data.vertices,points):
  y=cy+(pt.y-cy)*1.45;z=cz+(pt.z-cz)*1.45+.045
  hit,loc,n,idx=body.ray_cast(inv@Vector((side*2,y,z)),inv.to_3x3()@Vector((-side,0,0)))
  p=body.matrix_world@loc if hit else Vector((pt.x,y,z));p.x+=side*.007
  vert.co=ob.matrix_world.inverted()@p
 ob.data.update();ob.data.calc_loop_triangles();vs=[];ns=[];ts=[]
 for t in ob.data.loop_triangles:
  row=[]
  for vi in t.vertices:
   v=ob.matrix_world@ob.data.vertices[vi].co;row.append(len(vs));vs.append([v.x*2.5,v.z*2.5,-v.y*2.5]);ns.append([side,0,0])
  ts.append(row)
 rows.append({'name':ob.name,'vertices':vs,'normals':ns,'triangles':ts})
with open(os.path.join(ROOT,'svo-decals.json'),'w')as f:json.dump(rows,f)
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT,'SVO-Larger-Decals-v7.blend'))
s=bpy.context.scene;s.render.resolution_percentage=65;s.cycles.samples=24;s.render.filepath=os.path.join(ROOT,'SVO-Larger-Decals-v7.png');bpy.ops.render.render(write_still=True)
