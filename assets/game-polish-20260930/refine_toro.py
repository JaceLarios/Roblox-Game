import bpy,bmesh,os,json,math
from mathutils import Vector
from mathutils.bvhtree import BVHTree
ROOT=os.path.dirname(os.path.abspath(__file__))
scene=bpy.context.scene
body=bpy.data.objects['TriSet_00001728_002']
tree=BVHTree.FromPolygons([body.matrix_world@v.co for v in body.data.vertices],[list(f.vertices)for f in body.data.polygons])
liner=bpy.data.materials.new('Toro molded wheelhouse');liner.diffuse_color=(.012,.016,.022,1);liner.use_nodes=True;p=liner.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(.012,.016,.022,1);p.inputs['Roughness'].default_value=.62
added=[]
for ob in list(scene.objects):
 if 'Green Wide Fender' not in ob.name:continue
 side=1 if ob.name.endswith('1')and not ob.name.endswith('-1')else -1
 bm=bmesh.new();bm.from_mesh(ob.data);vs=[];fs=[]
 for e in bm.edges:
  if not e.is_boundary:continue
  a,b=[ob.matrix_world@v.co for v in e.verts]
  # Close the extension back to the original shell, including vent aperture walls.
  ends=[]
  for v in [a,b]:
   hit,_,_,_=tree.ray_cast(Vector((side*2,v.y,v.z)),Vector((-side,0,0)),3)
   x=hit.x-side*.008 if hit else side*.82
   # Recess the return rather than adding an outside floating patch.
   ends.append(Vector((x,v.y,v.z)))
  n=len(vs);vs.extend([a,b,ends[1],ends[0]]);fs.append((n,n+1,n+2,n+3))
 bm.free()
 me=bpy.data.meshes.new(ob.name+' closed returns');me.from_pydata(vs,[],fs);me.update();me.materials.append(liner)
 o=bpy.data.objects.new(ob.name+' Inner Returns',me);scene.collection.objects.link(o);added.append(o)
 # Continuous inner wheelhouse shields ground visibility above/behind the tire.
 cy=-1.179 if 'Front' in ob.name else 1.480;cz=.36 if cy<0 else .37;r=.365 if cy<0 else .39
 vs=[];fs=[]
 for i in range(49):
  t=math.radians(-8+196*i/48)
  for x in [side*.70,side*1.045]:vs.append((x,cy+r*math.cos(t),cz+r*math.sin(t)))
 for i in range(48):fs.append((i*2,i*2+1,i*2+3,i*2+2))
 me=bpy.data.meshes.new('Wheelhouse liner');me.from_pydata(vs,[],fs);me.update();me.materials.append(liner)
 o=bpy.data.objects.new(ob.name+' Wheelhouse Liner',me);scene.collection.objects.link(o);added.append(o)
# Export only new geometry as a reversible addition to the current Studio mesh.
scale=5.5/4.754;verts=[];faces=[];normals=[]
for ob in added:
 ob.data.calc_loop_triangles()
 for t in ob.data.loop_triangles:
  row=[]
  for vi in t.vertices:
   v=ob.matrix_world@ob.data.vertices[vi].co;row.append(len(verts));verts.append([v.x*scale,v.z*scale,-v.y*scale]);n=t.normal;normals.append([n.x,n.z,-n.y])
  faces.append(row)
with open(os.path.join(ROOT,'toro-seam-closures.json'),'w')as f:json.dump({'vertices':verts,'triangles':faces,'normals':normals},f)
scene['Revision14']='Fender perimeter return walls and four continuous recessed wheelhouse liners added to close see-through kit gaps.'
bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT,'Toro-Closed-Kit-v14.blend'))
scene.render.resolution_percentage=65;scene.cycles.samples=24;scene.render.filepath=os.path.join(ROOT,'Toro-Closed-Kit-v14.png');bpy.ops.render.render(write_still=True)
print('ADDED',len(added),'TRIANGLES',len(faces))
