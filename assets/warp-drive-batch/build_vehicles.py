import bpy, math, json, hashlib, bmesh
from pathlib import Path
from mathutils import Vector, Matrix
from collections import defaultdict
OUT=Path(__file__).resolve().parent
helper=(OUT/'geometry_helpers.py').read_text()
exec(helper[:helper.index('# 1. Stable Rusted Sedan')])
mat('WarpPurple','9E42EC','Enamel',.45,.28)
mat('WarpCyan','28DFFF','Light',.25,.3,1.7)
mat('WarpCopper','E69B48','Brushed',.8,.3)
mat('WarpCarbon','202933','Carbon',.5,.38)
specs=[
 ('Warp Wreck','Rusted Sedan','Rear portal roll cage with shoulder pods','FFAB27'),
 ('Wormhole Wheelie','Dirt Bike','Twin side field discs with a fork-linked flux spine','EE5046'),
 ('Hole in Space','Golf Cart','Canopy field hoops and under-seat capacitor rails','8B4EEB'),
 ('Lightspeed Legend','Muscle Car','Twin rear-quarter induction pods and low aero','FF6A24'),
 ('Warp Warden','Cop Cruiser','Patrol roof portal and reinforced pursuit bumpers','1683EC'),
 ('Star Freighter','Box Truck','Cargo-side transit gates and cab power conduits','0EC7BC'),
 ('Starcrusher','Monster Truck','Bed-mounted split gate with armored fender feeds','A2E52A')]

def load_base(name):
 d=json.loads((OUT/'base-inputs'/(name.replace(' ','_')+'.json')).read_text())
 for i,g in enumerate(d['parts']):
  ma='Base_'+str(i);m=g['material'];col=m['color']
  material=bpy.data.materials.new(ma);material.use_nodes=True
  p=material.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*col,1)
  p.inputs['Metallic'].default_value=m.get('metal',.3);p.inputs['Roughness'].default_value=.38
  if m.get('glow',0):p.inputs['Emission Color'].default_value=(*col,1);p.inputs['Emission Strength'].default_value=m['glow']
  M[ma]=material;META[ma]=m
  o=mesh(g['name'],[(x,-z,y)for x,y,z in g['vertices']],g['triangles'],ma)
  normals=[(x,-z,y)for x,y,z in g['normals']]
  for f in o.data.polygons:f.use_smooth=True
  o.data.normals_split_custom_set_from_vertices(normals)
  if g.get('wheel'):
   w=g['wheel'];o['WheelId']=w['id'];o['WheelPivot']=[w['pivot'][0],-w['pivot'][2],w['pivot'][1]];o['WheelRadius']=w['radius']
  o['SourceComponents']=len(g.get('components',[]))
 return d

def gate(center,r,axis=(0,1,0),label='Warp gate'):
 c=Vector(center);v=Vector(axis);u=v.cross(Vector((0,0,1))).normalized();w=v.cross(u)
 for depth in [-.12,.12]:
  tor(label+' cast rim',c+v*depth,r,.075,'Iron',axis,n=32)
  tor(label+' cyan aperture',c+v*(depth-.03),r*.85,.037,'WarpCyan',axis,n=32)
 for j in range(8):
  a=j*math.tau/8;p=c+(u*math.cos(a)+w*math.sin(a))*r
  cyl(label+' coil spindle',p-v*.23,p+v*.23,.055,'Chrome',n=12)
  for depth in [-.15,0,.15]:tor(label+' copper winding',p+v*depth,.079,.022,'WarpCopper',axis,n=12)
  bolt(p-v*.255,-v,.041)

def cable(points):
 pipe('Braided flux supply',points,.047,'Rubber')
 pipe('Luminous flux tracer',[Vector(p)+Vector((0,0,.048))for p in points],.016,'WarpCyan')

def fins(x,y,z,n=4):
 for i in range(n):box('Carbon heat exchanger fin',(x,y+i*.13,z),(.34,.035,.20),'WarpCarbon',.012)

manifest=[]
for index,(name,base,design,color) in enumerate(specs):
 model(name);d=load_base(base);width,height,length=d['targetSize'];half=width/2;top=height/2
 mat('Livery'+str(index),color,'Enamel',.4,.3)
 accent='Livery'+str(index)
 if base=='Rusted Sedan':
  gate((0,.95,.95),.85,label='Rear roll-cage portal')
  for side in [-1,1]:
   pipe('Portal roll-cage mount',[(side*.75,1.4,-.2),(side*.92,1.25,.6),(side*.75,.95,1.5)],.075,'Chrome')
   box('Shoulder capacitor',(side*1.1,.8,.1),(.36,.75,.38),accent,.075)
   cable([(side*.83,.95,.55),(side*1.25,.5,.2),(side*1.25,-.8,-.15)])
 elif base=='Dirt Bike':
  for side in [-1,1]:
   gate((side*.57,.25,.25),.56,(side,0,0),'Side flux disc')
   pipe('Fork to saddle energy spine',[(side*.35,-1.4,.3),(side*.4,-.65,.75),(side*.4,.6,.5)],.065,'Chrome')
   cable([(side*.52,.4,.25),(side*.45,-.3,.7),(side*.3,-1.3,.55)])
  box('Saddle capacitor',(0,1.15,.60),(.6,.45,.35),accent,.07)
 elif base=='Golf Cart':
  # Keep the cream canopy, bench and all four pillars clearly visible.
  for y in [-.6,.85]:gate((0,y,top+.22),.60,(0,0,1),'Canopy horizon coil')
  for side in [-1,1]:
   box('Under-seat field battery',(side*1.25,.25,-.4),(.32,1.6,.35),accent,.07)
   cable([(side*1.23,.8,-.3),(side*1.30,.9,.9),(side*.8,.85,top+.20)])
 elif base=='Muscle Car':
  for side in [-1,1]:
   gate((side*1.2,1.3,.45),.48,label='Quarter-panel warp nacelle')
   loft('Flared quarter nacelle cover',[(.75,.38,.05,.40,.55),(1.25,.42,.03,.46,.64),(1.85,.32,.08,.32,.45)],accent).location.x=side*1.02
   cable([(side*1.1,1.2,.1),(side*1.43,.5,-.25),(side*1.4,-1.3,-.25)])
   box('Carbon rocker extension',(side*1.34,0,-.5),(.28,2.7,.12),'WarpCarbon',.035)
  box('Low swept tail aero',(0,2,.68),(2.75,.36,.10),'WarpCarbon',.055)
 elif base=='Cop Cruiser':
  gate((0,.5,top+.2),.65,label='Pursuit roof portal')
  for side in [-1,1]:
   box('Roof coil pedestal',(side*.62,.5,top-.07),(.24,.9,.21),'White',.045)
   cable([(side*.7,.5,top),(side*1.3,1.3,.7),(side*1.5,1.8,.25)])
   box('Reinforced front push blade',(side*.95,-length*.49,-.32),(.6,.24,.3),'WarpCarbon',.05)
 elif base=='Box Truck':
  for side in [-1,1]:
   gate((side*(half+.08),.9,.3),1.0,(side,0,0),'Cargo-side transit gate')
   cable([(side*(half+.08),.9,-.65),(side*(half+.12),-.6,-.8),(side*1.25,-2.0,-.25)])
   box('Gate control enclosure',(side*(half+.08),2.25,-.35),(.18,.65,.65),accent,.065)
   fins(side*(half+.2),2.0,-.1)
  box('Cab sunshield',(0,-2.1,top*.64),(width*.88,.45,.14),'WarpCarbon',.045)
 elif base=='Monster Truck':
  gate((0,1.1,1.0),1.05,label='Bed-mounted dimensional gate')
  for side in [-1,1]:
   pipe('Gate bed support',[(side*.9,.65,.2),(side*1.0,1.1,1.0),(side*.8,1.6,.35)],.10,'Chrome')
   box('Armored fender induction plate',(side*1.0,-.95,.9),(.32,.95,.23),accent,.06)
   cable([(side*.8,1.1,1.15),(side*.9,.3,.85),(side*1.0,-1.15,.95)])
 # Common engineering language, different location and packaging per body.
 for side in [-1,1]:
  box('Warp controller',(side*min(half*.65,.9),length*.20,-.25),(.24,.42,.22),'WarpPurple',.03)
  fins(side*min(half*.65,.9),length*.20,-.10,3)
 objects=MODELS[name];dg=bpy.context.evaluated_depsgraph_get()
 for o in list(objects):
  me=bpy.data.meshes.new_from_object(o.evaluated_get(dg));matrix=o.matrix_world.copy();attrs=dict(o.items());label=o.name
  fresh=bpy.data.objects.new(label+' evaluated',me);fresh.matrix_world=matrix;bpy.data.collections[name].objects.link(fresh)
  for k,v in attrs.items():fresh[k]=v
  objects[objects.index(o)]=fresh;bpy.data.objects.remove(o,do_unlink=True)
 # Weld export's duplicate corner vertices before budget reduction on dense body meshes.
 total=sum(len(o.data.loop_triangles) if o.data.loop_triangles else len(o.data.polygons)*2 for o in objects)
 for o in objects:o.data.calc_loop_triangles()
 total=sum(len(o.data.loop_triangles)for o in objects)
 if total>88000:
  adjustable=[o for o in objects if not o.get('WheelId') and len(o.data.loop_triangles)>500]
  count=sum(len(o.data.loop_triangles)for o in adjustable);ratio=max(.45,(count-(total-87500))/count)
  for o in adjustable:
   bm=bmesh.new();bm.from_mesh(o.data);bmesh.ops.remove_doubles(bm,verts=list(bm.verts),dist=.00001);bm.to_mesh(o.data);bm.free()
   mod=o.modifiers.new('Production mesh budget','DECIMATE');mod.ratio=ratio
   bpy.context.view_layer.objects.active=o;bpy.ops.object.modifier_apply(modifier=mod.name)
 bpy.context.view_layer.update()
 pts=[o.matrix_world@v.co for o in objects for v in o.data.vertices]
 lo=Vector([min(p[i]for p in pts)for i in range(3)]);hi=Vector([max(p[i]for p in pts)for i in range(3)])
 center=(lo+hi)/2;factor=length/(hi.y-lo.y)
 for o in objects:
  transform=o.matrix_world.copy()
  for v in o.data.vertices:v.co=(transform@v.co-center)*factor
  if o.get('WheelId'):o['WheelPivot']=list((Vector(o['WheelPivot'])-center)*factor);o['WheelRadius']*=factor
  o.matrix_world=Matrix.Identity(4);o.data.update()
 groups=[]
 for o in objects:
  me=o.data;me.calc_loop_triangles();verts=[];norms=[];triangles=[];lookup={}
  for t in me.loop_triangles:
   ids=[]
   for li in t.loops:
    v=me.vertices[me.loops[li].vertex_index].co;n=me.corner_normals[li].vector
    vp=tuple(round(a,5)for a in (v.x,v.z,-v.y));np=tuple(round(a,5)for a in (n.x,n.z,-n.y));key=vp+np
    if key not in lookup:lookup[key]=len(verts);verts.append(vp);norms.append(np)
    ids.append(lookup[key])
   if len(set(ids))==3:triangles.append(ids)
  ma=o.data.materials[0].name;meta=META.get(ma,META.get(ma.split('.')[0]))
  g={'name':o.name,'material':meta,'vertices':verts,'normals':norms,'triangles':triangles,'components':[o.name]}
  if o.get('WheelId'):
   x,y,z=o['WheelPivot'];g['wheel']={'id':o['WheelId'],'pivot':[x,z,-y],'radius':o['WheelRadius']}
  g['geometryHash']=hashlib.sha256(json.dumps([verts,norms,triangles],separators=(',',':')).encode()).hexdigest()
  groups.append(g)
 pts=[v for g in groups for v in g['vertices']];size=[max(v[i]for v in pts)-min(v[i]for v in pts)for i in range(3)]
 data={'name':name,'base':base,'addon':'Warp Drive','displayName':name,'rarity':'legendary','noseAxis':'+Z','targetSize':size,'design':design,'parts':groups,'authoredComponents':sum(o.get('SourceComponents',1)for o in objects)}
 file=name.replace(' ','_')+'.json';(OUT/file).write_text(json.dumps(data,separators=(',',':')))
 count=sum(len(g['triangles'])for g in groups);assert count<90000,(name,count)
 manifest.append({'name':name,'base':base,'file':file,'triangles':count,'size':size,'parts':len(groups),'design':design})
 for o in objects:o.location+=Vector((index*10,0,0))
(OUT/'vehicle-manifest.json').write_text(json.dumps(manifest,indent=2))
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'Warp-Vehicles-v1.blend'))
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=16;scene.render.resolution_x=1000;scene.render.resolution_y=800;scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('Studio');scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.12,.16,.22,1)
scene.view_settings.view_transform='AgX'
bpy.ops.object.camera_add();camera=bpy.context.object;camera.data.type='ORTHO';scene.camera=camera
lights=[]
for pos,power in [((4,-6,8),1500),((-5,-2,5),1000),((2,5,7),1700)]:
 bpy.ops.object.light_add(type='AREA');o=bpy.context.object;o.data.energy=power;o.data.size=5;lights.append((o,Vector(pos)))
for i,spec in enumerate(manifest):
 for n in MODELS:bpy.data.collections[n].hide_render=n!=spec['name']
 center=Vector((i*10,0,0));camera.location=center+Vector((7,-10,6));camera.rotation_euler=(center-camera.location).to_track_quat('-Z','Y').to_euler();camera.data.ortho_scale=max(spec['size'])*1.5
 for light,pos in lights:light.location=center+pos;light.rotation_euler=(center-light.location).to_track_quat('-Z','Y').to_euler()
 scene.render.filepath=str(OUT/(spec['name'].replace(' ','_')+'.png'));bpy.ops.render.render(write_still=True)
print('SEVEN WARP VEHICLE DRAFTS EXPORTED')
