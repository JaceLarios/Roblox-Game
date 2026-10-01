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
  # A compact slingshot drag kart: reactor ahead of the driver, twin swept rails.
  gate((0,-1.25,.18),.43,label='Nose-mounted slingshot throat')
  for side in [-1,1]:
   loft('Swept accelerator side pod',[(-1.65,.12,-.38,-.08,.05),(-.9,.30,-.40,.0,.24),(.55,.23,-.4,-.10,.1),(1.5,.10,-.3,.12,.32)],accent).location.x=side*1.12
   pipe('Exposed slingshot conductor',[(side*.65,-1.3,.25),(side*1.15,-.65,.3),(side*1.0,.8,.32),(side*.65,1.25,.72)],.055,'WarpCopper')
   cable([(side*.4,-1.2,.25),(side*.95,-.5,.28),(side*.9,.7,.31)])
   box('Rear angled stabilizer',(side*.85,1.5,.65),(.10,.65,.55),'WarpCarbon',.025,rot=(0,side*.35,0))
   fins(side*1.15,.15,.27)
 elif base=='Dirt Bike':
  # A streamlined landspeed bike with a central tunnel under the saddle.
  cyl('Longitudinal tunnel housing',(0,-.25,.10),(0,1.35,.10),.36,'WarpCarbon',r2=.26,n=24)
  gate((0,1.38,.10),.32,label='Tail wormhole nozzle')
  for side in [-1,1]:
   loft('Swept fairing',[(-1.35,.06,-.28,.05,.22),(-.65,.18,-.35,.30,.52),(.6,.15,-.25,.25,.42),(1.35,.04,-.15,.12,.25)],accent).location.x=side*.38
   cable([(side*.46,-.85,.25),(side*.58,-.2,.35),(side*.44,.9,.26)])
   pipe('Fork brace',[(side*.24,-1.5,.20),(side*.35,-.85,.7),(side*.33,-.45,.72)],.038,'WarpCopper')
   box('Tail stabilizing blade',(side*.45,1.14,.28),(.06,.70,.30),'WarpCarbon',.018,rot=(0,side*.45,0))
 elif base=='Golf Cart':
  # Flying-saucer canopy, with the cart bench, pillars and golf bag unobstructed.
  for side in [-1,1]:
   loft('Canopy swept accelerator',[(-1.3,.10,top-.12,top+.04,top+.16),(-.6,.23,top-.10,top+.1,top+.30),(.7,.24,top-.10,top+.1,top+.24),(1.35,.08,top-.08,top+.03,top+.10)],accent).location.x=side*.95
   gate((side*.96,1.27,top+.04),.24,label='Canopy thrust aperture')
   cable([(side*.94,1.2,top),(side*1.15,.95,.7),(side*1.23,.45,-.35)])
   box('Floating running board',(side*1.35,0,-.55),(.40,1.85,.15),'WarpCarbon',.055)
   pipe('Board edge glow',[(side*1.52,-.8,-.49),(side*1.55,0,-.49),(side*1.52,.8,-.49)],.023,'WarpCyan')
  gate((0,-1.55,-.10),.32,label='Front cowl field generator')
 elif base=='Muscle Car':
  for side in [-1,1]:
   gate((side*1.2,1.3,.45),.48,label='Quarter-panel warp nacelle')
   loft('Flared quarter nacelle cover',[(.75,.38,.05,.40,.55),(1.25,.42,.03,.46,.64),(1.85,.32,.08,.32,.45)],accent).location.x=side*1.02
   cable([(side*1.1,1.2,.1),(side*1.43,.5,-.25),(side*1.4,-1.3,-.25)])
   box('Carbon rocker extension',(side*1.34,0,-.5),(.28,2.7,.12),'WarpCarbon',.035)
  box('Low swept tail aero',(0,2,.68),(2.75,.36,.10),'WarpCarbon',.055)
 elif base=='Cop Cruiser':
  # Armored interceptor: twin hood coils tucked into long armored shoulders.
  for side in [-1,1]:
   loft('Pursuit accelerator armor',[(-2.1,.16,-.15,.20,.32),(-1.5,.29,-.18,.40,.58),(-.75,.24,-.1,.42,.60),(-.2,.12,.0,.25,.32)],'White').location.x=side*.90
   gate((side*.9,-2.08,.17),.23,label='Front interceptor coil')
   cable([(side*.9,-1.9,.2),(side*1.35,-.7,.35),(side*1.40,.8,.35),(side*1.1,1.8,.48)])
   box('Rear pursuit wing pedestal',(side*.9,1.85,.65),(.13,.25,.5),'WarpCarbon',.025)
   box('Chase bumper tooth',(side*.95,-2.5,-.27),(.18,.28,.55),'WarpCarbon',.04)
  loft('Swept pursuit wing',[(1.6,1.0,.82,.86,.89),(1.9,1.55,.78,.84,.88),(2.12,1.38,.77,.80,.85)],'WarpCarbon')
 elif base=='Box Truck':
  # Space freight hauler: rear cargo portal plus side turbine rails, no side donuts.
  gate((0,length*.525,.15),1.12,label='Rear cargo loading portal')
  for side in [-1,1]:
   loft('Cargo ship engine rail',[(-2.5,.18,-.9,-.6,-.45),(-1.4,.36,-.9,-.4,-.22),(1.8,.34,-.9,-.3,-.15),(2.7,.23,-.8,-.35,-.18)],accent).location.x=side*(half+.10)
   gate((side*(half+.10),2.65,-.45),.30,label='Freighter rail nozzle')
   for y in [-.7,.05,.8,1.55]:
    box('Freight exoskeleton rib',(side*(half+.025),y,.20),(.12,.13,2.1),'WarpCarbon',.025)
    cable([(side*(half+.09),y,-.6),(side*(half+.09),y,.1),(side*(half+.09),y,.9)])
   box('Cab shoulder shield',(side*1.1,-1.8,top*.67),(.28,.95,.2),accent,.07)
 elif base=='Monster Truck':
  # Monster-truck cyclone cage: angled jaws surround a horizontal bed reactor.
  gate((0,1.0,.7),.62,(0,0,1),'Bed cyclone reactor')
  for side in [-1,1]:
   for y in [.45,1.5]:
    pipe('Reactor gripping jaw',[(side*.62,y,.32),(side*.98,y,.78),(side*.75,y,1.40),(side*.37,y,1.50)],.11,accent)
    cyl('Jaw hydraulic ram',(side*.72,y,.48),(side*.87,y,1.03),.05,'Chrome',n=12)
   loft('Front armored flared shoulder',[(-1.5,.1,.4,.55,.7),(-1.0,.35,.38,.75,.94),(-.45,.22,.40,.63,.77)],accent).location.x=side*1.10
   cable([(side*.5,1,.72),(side*.95,.6,.8),(side*1.0,-.9,.83)])
   box('Claw bumper',(side*.65,-1.9,-.15),(.34,.3,.7),'WarpCarbon',.055,rot=(0,side*.2,0))
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
  count=sum(len(o.data.loop_triangles)for o in adjustable);ratio=max(.30,(count-(total-82500))/count)
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
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'Warp-Redesign-v2.blend'))
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
