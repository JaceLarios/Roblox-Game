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
 ('Hole in Space','Golf Cart','Pearl canopy, violet sports cowl and twin rear warp battery towers','944AFF'),
 ('Star Freighter','Box Truck','Orange tractor cab with an open armored reactor cargo chamber','FF8C24')]

def load_base(name):
 d=json.loads((OUT/'base-inputs'/(name.replace(' ','_')+'.json')).read_text())
 for i,g in enumerate(d['parts']):
  if name=='Box Truck' and not g.get('wheel'):
   if i in [20,22]:continue
   if i in [14,17,18,19,21]:
    g=dict(g);g['triangles']=[t for t in g['triangles'] if sum(g['vertices'][v][2] for v in t)/3>1.10]
  if name=='Golf Cart' and i==24:continue
  if name=='Golf Cart' and i==16:
   g=dict(g);g['triangles']=[t for t in g['triangles'] if sum(g['vertices'][v][2]for v in t)/3<2.4]
  if name=='Golf Cart' and i in [16,17]:
   g=dict(g);g['triangles']=[t for t in g['triangles'] if sum(g['vertices'][v][1]for v in t)/3<1.8]
  if not g['triangles']:continue
  ma='Base_'+str(i);m=dict(g['material']);col=m['color']
  if (name=='Golf Cart' and i==14) or (name=='Box Truck' and i==14):
   rgb=(.47,.08,.88) if name=='Golf Cart' else (1,.27,.018)
   col=list(rgb);m['color']=col

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
 if base=='Golf Cart':
  # A luxury warp buggy. Replace the roof and front cowl; retain its cart layout.
  loft('Pearl floating canopy',[(-1.7,1.18,1.87,1.96,2.02),(-1.35,1.49,1.86,2.02,2.12),(1.8,1.49,1.86,2.02,2.12),(2.55,1.2,1.87,1.94,2.00)],'Cream')
  loft('Canopy carbon underside',[(-1.65,1.16,1.80,1.85,1.87),(-1.25,1.43,1.80,1.85,1.88),(1.8,1.43,1.80,1.85,1.88),(2.48,1.16,1.80,1.85,1.87)],'WarpCarbon')
  loft('Swept violet sports cowl',[(-2.6,1.1,-1.17,-.65,-.52),(-2.3,1.44,-1.15,-.38,-.22),(-1.1,1.22,-1.05,-.48,-.30)],accent)
  box('Recessed front grille',(0,-2.61,-.87),(1.4,.12,.34),'WarpCarbon',.09)
  for side in [-1,1]:
   # Tall reactor cartridges become the rear bodywork, not ornaments on the roof.
   cyl('Rear warp cartridge',(side*1.28,1.85,-.75),(side*1.28,1.85,1.25),.23,'WarpCarbon',n=24)
   for z in [-.65,-.1,.45,1.0]:
    tor('Cartridge induction band',(side*1.28,1.85,z),.25,.055,'WarpCopper',(0,0,1),24)
    tor('Luminous cartridge seam',(side*1.28,1.85,z+.085),.24,.025,'WarpCyan',(0,0,1),24)
   pipe('Curved rear sail pillar',[(side*1.35,1.45,-.3),(side*1.50,1.65,.5),(side*1.4,1.65,1.72)],.095,accent)
   pipe('Canopy edge light',[(side*1.15,-1.65,1.98),(side*1.49,-1.25,2.00),(side*1.49,1.8,2.0),(side*1.20,2.49,1.97)],.035,'WarpCyan')
   box('Cut-in headlight pocket',(side*.95,-2.51,-.48),(.57,.17,.20),'WarpCarbon',.06)
   box('Angled LED eye',(side*.95,-2.61,-.46),(.45,.045,.07),'WarpCyan',.025)
   box('Wide boarding step',(side*1.43,.2,-1.32),(.42,1.8,.16),'WarpCarbon',.05)
   for y in [-.42,-.15,.12,.39,.66]:box('Step grip',(side*1.44,y,-1.22),(.30,.07,.04),'Chrome',.015)
   pipe('Sill power rail',[(side*1.59,-.6,-1.2),(side*1.60,.45,-1.2),(side*1.4,1.55,-.85)],.036,'WarpCyan')
  gate((0,1.9,.75),.36,label='Seat-back warp control hub')
  for side in [-1,1]:
   box('Inset canopy cooling panel',(side*.85,.55,2.125),(.37,1.20,.025),'WarpCarbon',.05)
   for j in range(7):box('Flush canopy vent slat',(side*.85,.10+j*.15,2.145),(.30,.055,.022),'Chrome',.01)

 elif base=='Box Truck':
  # Purpose-built containment truck: exposed core inside the cargo silhouette.
  loft('Chamfered armored cargo roof',[(-.98,1.35,1.93,2.03,2.10),(-.55,1.70,1.90,2.14,2.26),(3.0,1.70,1.90,2.14,2.26),(3.58,1.36,1.91,2.05,2.10)],'Blue')
  loft('Armored cargo floor',[(-1.0,1.45,-1.40,-1.20,-1.1),(-.5,1.72,-1.45,-1.18,-1.08),(3.5,1.72,-1.45,-1.18,-1.08)],'WarpCarbon')
  for y in [-.75,3.30]:
   box('Containment bulkhead',(0,y,.36),(3.15,.23,2.85),'WarpCarbon',.25)
   box('Bulkhead inset',(0,y+(-.14 if y<0 else .14),.4),(2.52,.10,2.28),'Blue',.23)
  cyl('Sealed warp reactor drum',(0,-.50,.45),(0,3.03,.45),.78,'Iron',n=40)
  for y in [-.34,.43,1.2,1.97,2.75]:
   tor('Reactor luminous collar',(0,y,.45),.84,.055,'WarpCyan',(0,1,0),32)
   tor('Reactor copper induction coil',(0,y+.13,.45),.89,.075,'WarpCopper',(0,1,0),32)
  for side in [-1,1]:
   # Open side windows reveal the machine instead of a flat billboard wall.
   for y in [-.67,3.22]:
    pipe('Sculpted orange corner frame',[(side*1.50,y,-1.08),(side*1.72,y,-.6),(side*1.72,y,1.48),(side*1.45,y,1.97)],.16,accent)
    for z in [-.75,.0,.75,1.5]:bolt((side*1.84,y,z),(side,0,0),.065)
   for z in [-.85,1.65]:
    pipe('Side window frame',[(side*1.66,-.62,z),(side*1.74,1.25,z),(side*1.66,3.20,z)],.11,accent)
    pipe('Field containment edge',[(side*1.73,-.52,z+.13),(side*1.78,1.25,z+.13),(side*1.73,3.05,z+.13)],.028,'WarpCyan')
   pipe('Diagonal containment brace',[(side*1.75,-.48,-.71),(side*1.76,1.25,.45),(side*1.75,3.08,1.55)],.065,'Chrome')
   for j in range(5):
    box('Warning stripe',(side*1.86,-.63,-.55+j*.29),(.055,.27,.10),'WarpCarbon',.015,rot=(.35,0,0))
   gate((side*1.11,3.55,-.50),.35,label='Inset rear warp exhaust')
   loft('Cab shoulder air guide',[(-3.1,.10,1.22,1.33,1.45),(-2.2,.22,1.25,1.48,1.65),(-1.1,.15,1.25,1.6,1.72)],accent).location.x=side*1.05
   box('Cab armored cheek',(side*1.22,-3.25,-.5),(.34,.30,.64),'WarpCarbon',.085)
  for y in [.05,2.25]:
   box('Reactor suspension saddle',(0,y,-.80),(2.3,.36,.40),accent,.11)
   for side in [-1,1]:
    cyl('Suspension isolator',(side*.65,y,-.80),(side*.65,y,-.1),.09,'Chrome',n=16)
    tor('Isolator collar',(side*.65,y,-.55),.13,.04,'WarpCopper',(0,0,1),16)
  for side in [-1,1]:
   box('Roof service hatch',(side*.75,1.1,2.25),(.70,2.5,.035),'WarpCarbon',.08)
   for j in range(9):box('Heat vent louver',(side*.75,.10+j*.23,2.28),(.56,.085,.05),'Blue',.018)
  box('Rear containment latch',(0,3.52,.40),(.58,.18,.65),'WarpCopper',.08)
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
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'Warp-Cart-Truck-v3.blend'))
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
