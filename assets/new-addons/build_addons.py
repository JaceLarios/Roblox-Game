import bpy, math, json, random
from pathlib import Path
from mathutils import Vector, Matrix
from collections import defaultdict

OUT=Path(__file__).resolve().parent
random.seed(63)
bpy.ops.wm.read_factory_settings(use_empty=True)
M={}; META={}; MODELS={}; current=None
def material(name,col,metal=0,rough=.35,glow=0,alpha=1):
 m=bpy.data.materials.new(name);m.diffuse_color=(*col,alpha);m.use_nodes=True
 p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*col,1);p.inputs['Metallic'].default_value=metal;p.inputs['Roughness'].default_value=rough;p.inputs['Alpha'].default_value=alpha
 if glow:p.inputs['Emission Color'].default_value=(*col,1);p.inputs['Emission Strength'].default_value=glow
 M[name]=m;META[name]={'color':col,'metal':metal,'glow':glow,'alpha':alpha}
for a in [('Chrome',(.57,.66,.74),.92,.2),('Steel',(.24,.30,.34),.75,.36),('Iron',(.075,.10,.13),.7,.4),('Rubber',(.012,.021,.027),0,.65),('Rust',(.38,.14,.045),.35,.72),('Copper',(.77,.33,.075),.8,.28),('Red',(.75,.028,.018),.5,.23),('BlueHeat',(.055,.19,.65),.9,.23),('PurpleHeat',(.34,.085,.47),.9,.23),('Gold',(.95,.54,.045),.75,.25),('Cyan',(.015,.72,1),.2,.23,3),('Plasma',(.02,.23,1),.3,.18,2),('Carbon',(.035,.046,.060),.5,.32),('Glass',(.22,.64,.79),.05,.12,0,.22)]:material(*a)

def add(o,name,mat):
 o.name=name;o.data.materials.append(M[mat]);MODELS[current].append(o)
 for c in list(o.users_collection):c.objects.unlink(o)
 bpy.data.collections[current].objects.link(o)
 return o
def model(name):
 global current
 current=name;MODELS[name]=[];c=bpy.data.collections.new(name);bpy.context.scene.collection.children.link(c)
def box(name,p,size,mat='Steel',bevel=.04,rot=None):
 bpy.ops.mesh.primitive_cube_add(size=1,location=p);o=add(bpy.context.object,name,mat);o.scale=size
 bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 if rot:o.rotation_euler=rot
 if bevel:
  mod=o.modifiers.new('Machined edge radii','BEVEL');mod.width=bevel;mod.segments=2
  mod=o.modifiers.new('Panel normals','WEIGHTED_NORMAL')
 return o
def cylinder(name,a,b,r,mat='Steel',r2=None,n=24):
 a,b=Vector(a),Vector(b);d=b-a
 bpy.ops.mesh.primitive_cone_add(vertices=n,radius1=r,radius2=r if r2 is None else r2,depth=d.length,location=(a+b)/2)
 o=add(bpy.context.object,name,mat);o.rotation_euler=d.to_track_quat('Z','Y').to_euler()
 for f in o.data.polygons:f.use_smooth=len(f.vertices)==4
 return o
def sphere(name,p,r,mat='Steel',scale=(1,1,1)):
 bpy.ops.mesh.primitive_uv_sphere_add(segments=24,ring_count=12,radius=r,location=p);o=add(bpy.context.object,name,mat);o.scale=scale
 for f in o.data.polygons:f.use_smooth=True
 return o
def torus(name,p,major,minor,mat='Steel',axis=(0,0,1),seg=32):
 bpy.ops.mesh.primitive_torus_add(major_segments=seg,minor_segments=8,location=p,major_radius=major,minor_radius=minor)
 o=add(bpy.context.object,name,mat);o.rotation_euler=Vector(axis).to_track_quat('Z','Y').to_euler()
 for f in o.data.polygons:f.use_smooth=True
 return o
def pipe(name,points,r,mat='Chrome',resolution=2):
 curve=bpy.data.curves.new(name,'CURVE');curve.dimensions='3D';curve.resolution_u=6;curve.bevel_depth=r;curve.bevel_resolution=resolution
 sp=curve.splines.new('BEZIER');sp.bezier_points.add(len(points)-1)
 for p,co in zip(sp.bezier_points,points):p.co=co;p.handle_left_type='AUTO';p.handle_right_type='AUTO'
 o=bpy.data.objects.new(name,curve);bpy.context.collection.objects.link(o);add(o,name,mat);return o
def mesh(name,verts,faces,mat):
 me=bpy.data.meshes.new(name);me.from_pydata(verts,[],faces);me.update();o=bpy.data.objects.new(name,me);bpy.context.collection.objects.link(o);return add(o,name,mat)
def bolt(p,axis=(0,0,1),r=.055,mat='Chrome'):
 a=Vector(p);v=Vector(axis);cylinder('Hex fastener',a,a+v*.048,r,mat,n=6)
def bolts_ring(p,r,axis=(0,1,0),count=8):
 p=Vector(p);v=Vector(axis);u=v.cross(Vector((0,0,1))).normalized() if abs(v.z)<.9 else Vector((1,0,0));w=v.cross(u)
 for j in range(count):bolt(p+r*(u*math.cos(j*math.tau/count)+w*math.sin(j*math.tau/count)),axis)
def footframe(w=1.8,l=2.4):
 for x in [-w/2,w/2]:box('Mounting rail',(x,0,.12),(.15,l,.16),'Iron',.025)
 for y in [-l*.4,l*.4]:box('Cross brace',(0,y,.14),(w+.24,.18,.18),'Steel',.025)
 for x in [-w/2,w/2]:
  for y in [-l*.4,l*.4]:bolt((x,y,.24),r=.065)
def engine(length=2.5,width=1.5,height=1.1,cover='Red',banks=1):
 footframe(width,length+.2);box('Cast crankcase',(0,0,.6),(width,length,.8),'Iron',.10)
 box('Gasket seam',(0,0,1),(width+.025,length+.025,.055),'Rubber',.01)
 for side in range(banks):
  x=0 if banks==1 else (-1 if side==0 else 1)*width*.29
  box('Cam cover',(x,0,1.18),(width*.9 if banks==1 else width*.43,length*.96,.34),cover,.09)
  for y in [-length*.38,length*.38]:bolt((x,y,1.365),r=.06)
 for j in range(6):box('Cast cooling rib',(0,-length*.42+j*length*.168,.65),(width+.06,.055,.5),'Steel',.015)
 cylinder('Flywheel',(0,-length/2-.08,.65),(0,-length/2-.22,.65),.46,'Steel',n=32)
 torus('Flywheel rim',(0,-length/2-.24,.65),.4,.04,'Chrome',(0,1,0));bolts_ring((0,-length/2-.25,.65),.28,count=6)
def turbo(center,scale=1,scrap=False):
 c=Vector(center);sc=scale
 def p(x,y,z):return c+Vector((x,y,z))*sc
 # Authored spiral volute, growing in thickness towards the exhaust exit.
 verts=[];faces=[]
 for i in range(49):
  t=i/48;a=t*math.tau*1.05;R=.18+.38*t;rr=.105+.105*t
  for j in range(10):
   b=j*math.tau/10;dent=(1+.055*math.sin(i*2.1+j*3)) if scrap else 1
   verts.append(tuple(p((R+rr*math.cos(b)*dent)*math.cos(a),rr*math.sin(b), (R+rr*math.cos(b)*dent)*math.sin(a))))
 for i in range(48):
  for j in range(10):k=i*10+j;q=i*10+(j+1)%10;faces.append((k,q,q+10,k+10))
 o=mesh('Dented spiral housing' if scrap else 'Compressor volute',verts,faces,'Rust' if scrap else 'Chrome')
 for f in o.data.polygons:f.use_smooth=True
 cylinder('Dark compressor mouth',p(0,-.20,0),p(0,-.24,0),.25*sc,'Rubber',n=32)
 torus('Machined inlet flange',p(0,-.25,0),.26*sc,.048*sc,'Steel' if scrap else 'Chrome',(0,1,0))
 cylinder('Compressor hub',p(0,-.23,0),p(0,-.30,0),.06*sc,'Chrome',r2=.015,n=16)
 for j in range(9):
  a=j*math.tau/9;mesh('Curved compressor vane',[p(.07*math.cos(a),-.26,.07*math.sin(a)),p(.22*math.cos(a+.25),-.22,.22*math.sin(a+.25)),p(.20*math.cos(a+.5),-.23,.20*math.sin(a+.5))],[(0,1,2)],'Steel')
 for j in range(6):
  a=j*math.tau/6;bolt(p(.34*math.cos(a),-.15,.34*math.sin(a)),(0,-1,0),r=.035*sc,mat=('Copper' if j%2 else 'Chrome') if scrap else 'Chrome')
 cylinder('Outlet coupling',p(.45,.02,.2),p(.72,.02,.2),.16*sc,'Steel')

# 1: inexpensive but unmistakably paired, hollow chrome exhausts.
model('Straight Pipes')
for x in [-.32,.32]:
 pipe('Chrome exhaust runner',[(x,1,.26),(x,.1,.26),(x,-.95,.40)],.145)
 for y,ma,r in [(-.77,'Copper',.15),(-.87,'PurpleHeat',.155),(-.98,'BlueHeat',.16)]:torus('Heat stained tip band',(x,y,.40),r,.022,ma,(0,1,0))
 cylinder('Deep open bore',(x,-.99,.4),(x,-1.01,.4),.135,'Rubber')
 torus('Rolled outlet lip',(x,-1.02,.4),.15,.022,'Chrome',(0,1,0))
 for y in [-.30,.55]:torus('Exhaust clamp',(x,y,.29),.16,.017,'Steel',(0,1,0))
box('Bolt-on mounting bracket',(0,.2,.12),(.99,.55,.14),'Steel')
for x in [-.43,.43]:bolt((x,.2,.21))

model('Scrap Turbo');footframe(1.2,1.25);turbo((0,0,.82),1.15,True)
pipe('Reclaimed hose',[(.62,0,1.05),(.88,.1,1.05),(.90,.55,.65),(.35,.7,.48)],.14,'Rubber')
for y in [.22,.3,.38]:torus('Tape wrapped hose',(.9,y,.88-(y-.22)*1.1),.15,.03,'Iron',(0,1,-1))
box('Repair patch',(-.38,.04,.84),(.28,.08,.34),'Steel',.02,rot=(0,.2,-.2))
for z in [.73,.95]:bolt((-.4,-.015,z),(0,-1,0),.045,'Copper')

model('Rotary Engine');footframe(1.7,1.65)
# Broad chamber ring and a visible triangular rotor, viewed from the front.
cylinder('Rear rotor housing',(0,.25,.88),(0,.62,.88),.77,'Iron',n=48)
torus('Polished chamber rim',(0,-.15,.88),.69,.12,'Chrome',(0,1,0),48)
for y in [.1,.23,.37]:torus('Housing cooling fin',(0,y,.88),.74,.035,'Steel',(0,1,0))
cylinder('Rotor cavity',(0,-.07,.88),(0,-.10,.88),.59,'Rubber',n=48)
pts=[(math.sin(j*math.tau/3)*.48,-.18,.88+math.cos(j*math.tau/3)*.48) for j in range(3)]
o=mesh('Triangular Wankel rotor',pts+[(x,y+.12,z) for x,y,z in pts],[(0,1,2),(3,5,4),(0,3,4,1),(1,4,5,2),(2,5,3,0)],'Gold')
b=o.modifiers.new('Rotor edge radius','BEVEL');b.width=.06;b.segments=3
cylinder('Eccentric rotor shaft',(0,-.22,.88),(0,-.26,.88),.14,'Chrome',n=24)
bolts_ring((0,-.22,.88),.7,count=10)
cylinder('Inspection window',(0,-.275,.88),(0,-.285,.88),.575,'Glass',n=48)
box('Glossy top cover',(0,.27,1.64),(1.10,.72,.19),'Red',.07)
pipe('Intake elbow',[(.65,.4,1.1),(.92,.4,1.45),(.67,.4,1.75)],.12)

model('Twin Turbo');engine(2.4,1.25,cover='BlueHeat')
for x in [-.95,.95]:
 turbo((x,-.25,1.08),.75)
 pipe('Polished crossover',[(x+.5,0,1.23),(x,.5,1.8),(x*.25,.55,1.95),(x*.25,1,1.35)],.09)
 for y in [-.7,.3,.8]:pipe('Exhaust manifold',[(x*.6,y,.88),(x*.95,y,.75),(x,-.1,.88)],.065,'Copper')
box('Intercooler',(0,-1.42,.69),(1.50,.23,.64),'Chrome')
for z in [.46,.57,.68,.79,.90]:box('Intercooler fin',(0,-1.55,z),(1.37,.02,.025),'Iron',0)

model('Supercharger');footframe(1.8,2.2)
box('Intake manifold',(0,0,.42),(1.65,1.85,.44),'Steel',.09)
for x in [-.43,.43]:cylinder('Roots rotor case',(x,-.9,.85),(x,.85,.85),.44,'Chrome',n=32)
for y in [-.85,-.57,-.28,0,.28,.57,.84]:box('Blower case rib',(0,y,.99),(1.72,.045,.17),'Steel',.02)
box('Scoop riser',(0,0,1.31),(.94,1.15,.36),'Red',.07)
box('Polished intake scoop',(0,-.08,1.61),(1.68,1.52,.43),'Chrome',.16)
for x in [-.48,0,.48]:
 cylinder('Butterfly bore',(x,-.85,1.60),(x,-.87,1.60),.20,'Rubber')
 cylinder('Throttle butterfly',(x,-.88,1.60),(x,-.9,1.60),.155,'Gold',n=24)
for z,r in [(.46,.28),(.94,.35)]:
 cylinder('Drive pulley',(0,-1.0,z),(0,-1.12,z),r,'Steel',n=32);torus('Pulley flange',(0,-1.13,z),r,.028,'Chrome',(0,1,0))
pipe('Continuous drive belt',[(-.28,-1.08,.45),(-.34,-1.08,.95),(0,-1.08,1.29),(.34,-1.08,.95),(.28,-1.08,.45),(0,-1.08,.18),(-.28,-1.08,.45)],.045,'Rubber')

model('Diesel Stack');engine(2.35,1.5,cover='Gold',banks=2)
for x in [-1.0,1.0]:
 pipe('Stack manifold',[(x*.6,.7,.65),(x,.65,.75),(x,.62,1.3)],.17,'Iron')
 cylinder('Vertical exhaust stack',(x,.62,1.1),(x,.62,2.65),.19,'Chrome',n=32)
 for z in [1.30,1.46,1.62,1.78,1.94]:torus('Heat shield band',(x,.62,z),.208,.024,'Steel')
 cylinder('Soot blackened stack tip',(x,.62,2.48),(x,.62,2.70),.20,'Iron',n=32)
 cylinder('Hollow stack mouth',(x,.62,2.705),(x,.62,2.711),.17,'Rubber',n=32)
 torus('Stack rolled lip',(x,.62,2.71),.188,.018,'Steel')
box('Heavy radiator',(0,-1.4,.91),(1.72,.23,1.3),'Iron',.06)
for j in range(12):box('Radiator vertical fin',(-.73+j*.133,-1.535,.90),(.038,.05,1.1),'Steel',.01)

model('V12 Engine');engine(3.5,1.8,cover='Carbon',banks=2)
for x in [-.55,.55]:
 for j in range(6):
  y=-1.35+j*.54
  cylinder('Red intake trumpet',(x,y,1.35),(x,y,1.92),.095,'Red',r2=.18,n=24)
  torus('Trumpet bell lip',(x,y,1.92),.18,.022,'Red')
  cylinder('Dark trumpet bore',(x,y,1.926),(x,y,1.93),.148,'Rubber',n=24)
  pipe('Individual exhaust header',[(x*1.45,y,.88),(x*2.1,y,.7),(x*2.1,y+.18,.43)],.055,'Chrome')
 for j in range(7):box('Carbon weave accent',(x,-1.4+j*.44,1.365),(.30,.025,.012),'Steel',.005,rot=(0,0,.6))
pipe('Fuel rail',[(-.24,-1.5,1.48),(-.24,1.5,1.48)],.04,'Gold')
pipe('Fuel rail',[(.24,-1.5,1.48),(.24,1.5,1.48)],.04,'Gold')

model('Hover Fans')
box('Central control housing',(0,0,.34),(.9,1.25,.45),'Iron',.1)
for x in [-1.0,1.0]:
 for y in [-1.0,1.0]:
  pipe('Pod support',[(x*.2,y*.25,.28),(x,y,.28)],.10,'Steel')
  torus('Ducted fan outer shroud',(x,y,.43),.64,.105,'Chrome',seg=40)
  torus('Ducted fan carbon lip',(x,y,.58),.64,.045,'Carbon',seg=40)
  torus('Cyan perimeter lamp',(x,y,.60),.605,.022,'Cyan',seg=40)
  cylinder('Fan motor',(x,y,.25),(x,y,.54),.14,'Iron',n=24)
  for j in range(8):
   a=j*math.tau/8
   verts=[(x+r*math.cos(a+t),y+r*math.sin(a+t),.46+h) for r,t,h in [(.13,0,0),(.54,.20,.015),(.56,.47,-.035),(.20,.38,-.035)]]
   mesh('Swept cyan rotor blade',verts,[(0,1,2,3)],'Cyan')
  for a in [0,math.pi/2]:pipe('Motor cross brace',[(x-.58*math.cos(a),y-.58*math.sin(a),.23),(x+.58*math.cos(a),y+.58*math.sin(a),.23)],.025,'Steel')
for y in [-.35,0,.35]:box('Controller light',(0,y,.58),(.4,.08,.035),'Cyan',.02)

model('Rocket Booster');footframe(1.1,2.55)
cylinder('Rocket pressure vessel',(0,.95,.83),(0,-.65,.83),.52,'Steel',n=40)
sphere('Rounded pressure cap',(0,.97,.83),.52,'Steel',scale=(1,.5,1))
for y in [-.55,.0,.65]:torus('Reinforced tank hoop',(0,y,.83),.53,.065,'Chrome',(0,1,0),40)
cylinder('Combustion throat',(0,-.65,.83),(0,-.95,.83),.25,'Copper',r2=.22,n=32)
# Nozzle bell with a real open throat and inner liner.
verts=[];faces=[]
for y,r in [(-.92,.22),(-1.2,.32),(-1.6,.64),(-1.6,.57),(-1.2,.27),(-.92,.17)]:
 for j in range(40):a=j*math.tau/40;verts.append((r*math.cos(a),y,.83+r*math.sin(a)))
for k in range(5):
 for j in range(40):q=k*40+j;n=k*40+(j+1)%40;faces.append((q,n,n+40,q+40))
o=mesh('Flared open rocket nozzle',verts,faces,'Iron')
for f in o.data.polygons:f.use_smooth=True
torus('Heat stained nozzle rim',(0,-1.6,.83),.62,.032,'BlueHeat',(0,1,0),40)
torus('Ignition chamber glow',(0,-1.0,.83),.16,.026,'Cyan',(0,1,0))
for j in range(4):
 a=j*math.pi/2;u=Vector((math.cos(a),0,math.sin(a)));c=Vector((0,0,.83))
 pts=[c+u*.48+Vector((0,.7,0)),c+u*.9+Vector((0,-.25,0)),c+u*.9+Vector((0,-.65,0)),c+u*.48+Vector((0,-.65,0))]
 mesh('Stabilizer fin',pts,[(0,1,2,3)],'Gold')
for j in range(16):
 a=j*math.tau/16
 # Alternating physical hazard segments around the service collar.
 pts=[]
 for y in [.25,.50]:
  for t in [a,a+math.tau/16*.95]:pts.append((.545*math.cos(t),y,.83+.545*math.sin(t)))
 mesh('Warning stripe',pts,[(0,1,3,2)],'Gold' if j%2 else 'Rubber')
pipe('External fuel feed',[(.38,.9,.9),(.69,.5,.9),(.62,-.55,.9),(.22,-.86,.9)],.045,'Copper')

model('Fusion Core');footframe(2.0,2.0)
sphere('Plasma reactor sphere',(0,0,1.27),.69,'Plasma')
for axis in [(0,0,1),(1,0,0),(0,1,0)]:
 torus('Energized containment ring',(0,0,1.27),.735,.028,'Cyan',axis,48)
 torus('Scrap containment cage',(0,0,1.27),.91,.072,'Steel',axis,40)
for j in range(6):
 a=j*math.tau/6;x,y=math.cos(a),math.sin(a)
 box('Riveted scrap cage plate',(x*.83,y*.83,1.27),(.36,.13,.40),'Rust' if j%2 else 'Steel',.035,rot=(.1,0,a+math.pi/2))
 pipe('Cage power cable',[(x*.77,y*.77,1.6),(x*1.01,y*1.01,.83),(x*.7,y*.7,.26)],.046,'Rubber')
 bolt((x*.86,y*.86,1.50),r=.058,mat='Copper')
for x in [-.70,.70]:
 for y in [-.70,.70]:
  cylinder('Shock isolated cage foot',(x,y,.21),(x,y,.63),.13,'Iron',n=16)
  torus('Copper insulator',(x,y,.51),.15,.037,'Copper')
for j in range(3):
 pts=[]
 for k in range(15):
  a=k/14*math.pi*1.5+j*2.0;r=.70;pts.append((r*math.sin(a)*math.cos(j),r*math.sin(a)*math.sin(j),1.27+r*math.cos(a)))
 pipe('Plasma arc',pts,.017,'Cyan',1)


# V2: retain the approved silhouettes; add saturated enamel and service hardware.
material('Orange', (1,.16,.008), .5,.25)
material('ElectricBlue', (.008,.25,1), .55,.23)
material('Teal', (.005,.72,.43), .5,.25)
material('Violet', (.46,.015,.8), .5,.25)
def recolor(prefix,mat):
 for o in MODELS[current]:
  if o.name.startswith(prefix):o.data.materials[0]=M[mat]
def connector(p):
 torus('Service connector collar',p,.07,.018,'Gold',seg=16)
 bolt(p,r=.04)

current='Straight Pipes'
recolor('Bolt-on mounting bracket','ElectricBlue')
for x in [-.32,.32]:
 for y in [-.30,.55]:
  box('Clamp mounting ear',(x+.18,y,.27),(.12,.09,.07),'Chrome',.01)
  bolt((x+.18,y,.31),r=.034)
 for y in [-.67,-.70,-.73]:torus('TIG weld bead',(x,y,.39),.146,.009,'Gold',(0,1,0),24)

current='Scrap Turbo'
recolor('Repair patch','Teal');recolor('Cross brace','Orange')
pipe('Braided oil feed',[(-.40,.12,.5),(-.62,.22,1.14),(-.15,.29,1.38)],.026,'Copper',1)
for p in [(-.40,.12,.5),(-.15,.29,1.38)]:connector(p)
for y in [.18,.42]:torus('Hose retaining clamp',(.9,y,.88-(y-.22)*1.1),.165,.014,'Chrome',(0,1,-1),20)
box('Orange service plate',(.25,.19,1.39),(.24,.12,.035),'Orange',.018)
for x in [.17,.33]:bolt((x,.19,1.414),r=.022)

current='Rotary Engine'
recolor('Glossy top cover','ElectricBlue')
for x in [-.4,.4]:bolt((x,.27,1.75),r=.05,mat='Gold')
torus('Anodized inspection rim',(0,-.235,.88),.625,.018,'Teal',(0,1,0),48)
for x in [-.28,0,.28]:box('Cover machined rib',(x,.28,1.742),(.025,.46,.02),'Chrome',.005)
pipe('Ignition lead',[(.55,.48,.82),(.65,.69,1.13),(.38,.54,1.53)],.028,'Orange',1)

current='Twin Turbo'
recolor('Cam cover','ElectricBlue')
for x in [-.95,.95]:
 torus('Anodized compressor ring',(x,-.44,1.08),.215,.018,'Orange',(0,1,0),32)
 cylinder('Wastegate actuator',(x,.27,1.22),(x,.45,1.22),.115,'Gold',n=20)
 pipe('Actuator signal line',[(x,.46,1.22),(x*.55,.67,1.45),(x*.3,.3,1.40)],.02,'Teal',1)
for x in [-.72,.72]:box('Intercooler colored endtank',(x,-1.43,.69),(.12,.25,.65),'ElectricBlue',.035)
for y in [-.8,-.4,0,.4,.8]:box('Coil pack',(0,y,1.405),(.3,.17,.09),'Orange',.025)

current='Supercharger'
recolor('Scoop riser','Orange')
for x in [-.82,.82]:
 for y in [-.7,-.35,0,.35,.7]:bolt((x,y,1.075),r=.041,mat='Gold')
pipe('Throttle linkage',[(-.66,-.92,1.60),(.66,-.92,1.60)],.026,'Chrome',1)
for x in [-.48,0,.48]:bolt((x,-.936,1.6),(0,-1,0),.038,'Copper')
box('Blower service plaque',(.67,-.06,1.845),(.19,.66,.027),'ElectricBlue',.02)
for y in [-.29,.17]:bolt((.67,y,1.864),r=.025)

current='Diesel Stack'
recolor('Cam cover','Orange');recolor('Cross brace','Teal')
for x in [-.43,.43]:
 for y in [-.8,-.4,0,.4,.8]:pipe('High pressure injector line',[(x,y,1.38),(x*.4,y,1.52),(x*.3,y+.07,1.4)],.023,'Copper',1)
box('Radiator surround top',(0,-1.41,1.59),(1.70,.25,.1),'Orange',.03)
for x in [-.83,.83]:
 box('Radiator side armor',(x,-1.42,.92),(.11,.25,1.2),'Orange',.025)
 for z in [.46,.9,1.43]:bolt((x,-1.565,z),(0,-1,0),.04)

current='V12 Engine'
for x in [-.55,.55]:
 for j in range(6):
  y=-1.35+j*.54
  torus('Trumpet polished collar',(x,y,1.53),.12,.018,'Gold',seg=20)
  pipe('Injector line',[(x*.44,y,1.48),(x*.68,y,1.58),(x,y,1.49)],.015,'ElectricBlue',1)
 for y in [-1.5,1.5]:bolt((x,y,1.37),r=.048,mat='Gold')
box('Central V12 spine',(0,0,1.4),(.22,2.8,.10),'Red',.035)
for y in [-1,-.5,0,.5,1]:box('Spine machined insert',(0,y,1.46),(.15,.13,.025),'Chrome',.008)

current='Hover Fans'
recolor('Central control housing','Violet')
for x in [-1.,1.]:
 for y in [-1.,1.]:
  torus('Teal duct armor ring',(x,y,.43),.72,.023,'Teal',seg=40)
  cylinder('Gold fan hub',(x,y,.54),(x,y,.60),.115,'Gold',n=20)
  for j in range(4):
   a=j*math.pi/2;bolt((x+.64*math.cos(a),y+.64*math.sin(a),.60),r=.034)
  pipe('Pod power conduit',[(x*.3,y*.4,.43),(x*.5,y*.8,.4),(x,y,.32)],.026,'Orange',1)

current='Rocket Booster'
recolor('Rocket pressure vessel','ElectricBlue');recolor('Rounded pressure cap','ElectricBlue')
recolor('Stabilizer fin','Orange')
for y in [-1.1,-1.2,-1.3,-1.4,-1.5]:
 r=.22+(abs(y)-.92)*.6
 torus('Nozzle cooling jacket rib',(0,y,.83),r,.014,'Copper',(0,1,0),32)
for j in range(8):
 a=j*math.tau/8;bolt((.48*math.cos(a),-.61,.83+.48*math.sin(a)),(0,-1,0),.04,'Gold')
pipe('Ignition cable',[(-.30,.85,1.20),(-.48,.30,1.23),(-.45,-.65,1.1)],.023,'Red',1)

current='Fusion Core'
recolor('Cross brace','Violet')
for j,o in enumerate([o for o in MODELS[current] if o.name.startswith('Riveted scrap cage plate')]):
 if j%2==0:o.data.materials[0]=M['Orange']
for j in range(6):
 a=j*math.tau/6;x,y=math.cos(a),math.sin(a)
 for z in [.89,1.0,1.11]:torus('Power cable ferrule',(x*.99,y*.99,z),.065,.017,'Gold',seg=16)
 sphere('Cage status diode',(x*.85,y*.85,1.46),.047,'Cyan')
for x in [-.70,.70]:
 for y in [-.70,.70]:
  for z in [.30,.36,.42]:torus('Isolator machined fin',(x,y,z),.14,.016,'ElectricBlue',seg=20)



# Mechanical silhouette rebuild requested after the first color preview.
def clear_model(name):
 global current
 current=name
 for o in MODELS[name]:bpy.data.objects.remove(o,do_unlink=True)
 MODELS[name]=[]

def open_stack(x,y):
 verts=[];faces=[];N=24
 for z,r in [(1.86,.11),(2.16,.17),(2.16,.148),(1.90,.09)]:
  for j in range(N):
   a=j*math.tau/N;verts.append((x+r*math.cos(a),y+r*math.sin(a),z))
 for k in range(3):
  for j in range(N):faces.append((k*N+j,k*N+(j+1)%N,(k+1)*N+(j+1)%N,(k+1)*N+j))
 o=mesh('Open red velocity stack',verts,faces,'Red')
 for f in o.data.polygons:f.use_smooth=True
clear_model('V12 Engine')
footframe(1.65,3.5)
box('Deep cast oil sump',(0,0,.38),(1.05,3.1,.46),'Iron',.11)
box('Sump gasket',(0,0,.59),(1.18,3.22,.055),'Rubber',.01)
box('Crankshaft bedplate',(0,0,.79),(1.25,3.12,.38),'Steel',.08)
for side in [-1,1]:
 angle=side*math.radians(30)
 # Cylinder-bank top normals diverge by 60 degrees.
 box('Angled cylinder bank',(side*.52,0,1.06),(.72,3.10,.73),'Steel',.08,rot=(0,angle,0))
 box('Machined head gasket',(side*.72,0,1.42),(.82,3.12,.045),'Iron',.01,rot=(0,angle,0))
 box('DOHC cylinder head',(side*.80,0,1.57),(.84,3.10,.28),'Chrome',.05,rot=(0,angle,0))
 box('Carbon cam cover',(side*.91,0,1.76),(.78,3.02,.20),'Carbon',.07,rot=(0,angle,0))
 box('Red cam spine',(side*.94,0,1.87),(.18,2.76,.045),'Red',.02,rot=(0,angle,0))
 for j in range(6):
  y=-1.27+j*.51
  # Visible one-to-one intake, ignition and exhaust for each of 12 cylinders.
  box('Coil connector',(side*1.15,y,1.75),(.15,.19,.11),'Rubber',.025,rot=(0,angle,0))
  bolt((side*.86,y,1.87),r=.032,mat='Gold')
  pipe('Intake runner',[(side*.62,y,1.52),(side*.36,y,1.69),(side*.30,y,1.89)],.115,'Chrome',1)
  open_stack(side*.30,y)
  torus('Red bellmouth',(side*.30,y,2.16),.17,.02,'Red',seg=24)
  cylinder('Intake dark throat',(side*.30,y,1.90),(side*.30,y,1.903),.09,'Rubber',n=24)
  pipe('Equal length exhaust header',[(side*1.02,y,1.30),(side*1.36,y,1.22),(side*1.45,y+.20,.75),(side*1.32,.90+j*.08,.57)],.058,'Chrome',1)
  pipe('Injector fuel branch',[(side*.53,y,1.77),(side*.45,y,1.87)],.019,'Copper',1)
 pipe('Fuel rail',[(side*.53,-1.43,1.77),(side*.53,1.43,1.77)],.037,'Gold',1)
 cylinder('Six into one exhaust collector',(side*1.32,.85,.57),(side*1.32,1.55,.57),.15,'BlueHeat',r2=.115)
 for y in [-1.38,1.38]:bolt((side*.62,y,1.98),r=.037)
 # Distinct front timing covers follow the two bank angles.
 box('Front timing cover',(side*.64,-1.59,1.30),(.76,.15,.86),'Steel',.15,rot=(0,angle,0))
 for y in [-1.30,-.65,0,.65,1.30]:bolt((side*.57,y,.66),r=.035)
for x,z,r in [(0,.72,.30),(-.7,1.25,.19),(.7,1.25,.19),(0,1.51,.13)]:
 cylinder('Accessory pulley',(x,-1.71,z),(x,-1.81,z),r,'Iron',n=32)
 torus('Pulley machined rim',(x,-1.82,z),r,.022,'Chrome',(0,1,0),24)
 bolt((x,-1.85,z),(0,-1,0),.055,'Gold')
pipe('Serpentine belt',[(-.30,-1.775,.70),(-.85,-1.775,1.25),(-.70,-1.775,1.44),(0,-1.775,1.65),(.70,-1.775,1.44),(.85,-1.775,1.25),(.30,-1.775,.70),(0,-1.775,.42),(-.30,-1.775,.70)],.032,'Rubber',1)
cylinder('Alternator barrel',(-.87,-1.12,.88),(-.87,-1.57,.88),.23,'Chrome',n=24)
for j in range(8):
 a=j*math.tau/8
 box('Alternator cooling slot',(-.87+.225*math.cos(a),-1.36,.88+.225*math.sin(a)),(.028,.27,.055),'Iron',.006,rot=(0,-a,0))
cylinder('Rear bellhousing',(0,1.56,.85),(0,1.84,.85),.56,'Steel',r2=.68,n=32)
bolts_ring((0,1.85,.85),.58,(0,1,0),10)

clear_model('Rotary Engine')
footframe(1.55,2.10)
box('Compact rotary oil pan',(0,.03,.30),(1.15,1.9,.32),'Iron',.09)
def chamber(name,y,depth,mat,hollow=False):
 verts=[];faces=[];N=64
 # Epitrochoid-inspired twin-lobed rotor chamber, not a round piston block.
 for yy,scale in [(y,1),(y+depth,1),(y+depth,.79),(y,.79)]:
  for j in range(N):
   t=j*math.tau/N
   x=(.70*math.cos(t)+.10*math.cos(3*t))*scale
   z=(.70*math.sin(t)-.10*math.sin(3*t))*scale
   verts.append((x,yy,1.13+z))
 for ring in range(4):
  if ring==2 and not hollow:continue
  for j in range(N):faces.append((ring*N+j,ring*N+(j+1)%N,((ring+1)%4)*N+(j+1)%N,((ring+1)%4)*N+j))
 if not hollow:faces.append(tuple(range(N-1,-1,-1)))
 return mesh(name,verts,faces,mat)
for y in [-.62,.18]:
 chamber('Aluminum rotor housing',y,.55,'Chrome',True)
 for yy in [y+.08,y+.21,y+.34,y+.47]:chamber('Cast cooling rib',yy,.024,'Steel',True)
for y in [-.73,-.04,.76]:chamber('Iron side housing plate',y,.10,'Iron',True)
chamber('Blue inspection cover rim',-.80,.065,'ElectricBlue',True)
# Curved triangular rotor visible in the front inspection cutaway.
corners=[Vector((.48*math.cos(j*math.tau/3),.48*math.sin(j*math.tau/3))) for j in range(3)]
outline=[]
for j in range(3):
 a,b=corners[j],corners[(j+1)%3];mid=(a+b)/2;control=mid+mid.normalized()*.18
 for k in range(12):
  t=k/12;outline.append((1-t)**2*a+2*(1-t)*t*control+t*t*b)
verts=[(v.x,yy,1.13+v.y) for yy in [-.755,-.59] for v in outline];N=len(outline)
faces=[tuple(range(N-1,-1,-1)),tuple(range(N,N*2))]+[(j,(j+1)%N,(j+1)%N+N,j+N) for j in range(N)]
mesh('Curved triangular Wankel rotor',verts,faces,'Gold')
cylinder('Rotor eccentric shaft',(0,-.79,1.13),(0,-.84,1.13),.12,'Steel',n=24)
for j in range(12):
 t=j*math.tau/12
 bolt((.73*math.cos(t)+.1*math.cos(3*t),-.825,1.13+.73*math.sin(t)-.1*math.sin(3*t)),(0,-1,0),.035)
# Transparent cutaway pane retains the user's requested rotor window.
v=[(0,-.837,1.13)]+[(.79*(.70*math.cos(j*math.tau/64)+.10*math.cos(3*j*math.tau/64)),-.837,1.13+.79*(.70*math.sin(j*math.tau/64)-.10*math.sin(3*j*math.tau/64)))for j in range(64)]
mesh('Inspection glass',v,[(0,j+1,(j+1)%64+1)for j in range(64)],'Glass')
for y in [-.36,.44]:
 pipe('Twin rotor intake runner',[(.59,y,1.52),(.86,y,1.76),(.61,y,2.05)],.10,'Chrome',1)
 pipe('Rotary exhaust runner',[(-.64,y,1.05),(-.91,y,.82),(-.88,.73,.61)],.085,'Copper',1)
 for z in [1.13,1.40]:
  cylinder('Twin spark plug insulator',(.68,y,z),(.85,y,z),.047,'Chrome',n=16)
  pipe('Spark lead',[(.85,y,z),(.97,y+.08,z+.12),(.65,.70,1.69)],.024,'Red',1)
box('Blue intake plenum',(.28,.11,2.0),(.96,1.52,.29),'ElectricBlue',.13)
for y in [-.45,.55]:bolt((.3,y,2.15),r=.036,mat='Gold')
cylinder('Front throttle body',(.28,-.66,2),(.28,-.90,2),.20,'Chrome',n=32)
cylinder('Throttle dark bore',(.28,-.90,2),(.28,-.908,2),.164,'Rubber',n=32)
torus('Throttle rolled rim',(.28,-.91,2),.18,.023,'Chrome',(0,1,0),32)
cylinder('Rear flywheel',(0,.91,1.05),(0,1.07,1.05),.59,'Steel',n=40)
bolts_ring((0,1.08,1.05),.46,(0,1,0),8)
box('Lower front oil pump',(0,-.84,.49),(.76,.22,.32),'Steel',.065)
cylinder('Lower accessory pulley',(0,-.96,.47),(0,-1.06,.47),.22,'Iron',n=32)
torus('Accessory pulley edge',(0,-1.075,.47),.20,.02,'Chrome',(0,1,0),24)

# Apply modifiers, normalize each model to its reference's longest dimension,
# then export exact evaluated geometry and loop normals for Studio import.
names=list(MODELS)
targets=[3,3,3.30019,3.30019,3.49989,3.49989,4,4,4.4999,4.4999]
rarities=['uncommon']*2+['rare']*2+['epic']*2+['mythic']*2+['legendary']*2
manifest=[]
for index,name in enumerate(names):
 objects=MODELS[name]
 for o in objects:
  bpy.context.view_layer.objects.active=o;o.select_set(True)
  if o.type=='CURVE':bpy.ops.object.convert(target='MESH')
  for mod in list(o.modifiers):bpy.ops.object.modifier_apply(modifier=mod.name)
  o.select_set(False)
 points=[o.matrix_world@Vector(p) for o in objects for p in o.bound_box]
 lo=Vector([min(p[i] for p in points) for i in range(3)]);hi=Vector([max(p[i] for p in points) for i in range(3)])
 center=(lo+hi)/2;factor=targets[index]/max(hi-lo)
 for o in objects:
  o.location=(o.location-center)*factor;o.scale*=factor
 bpy.context.view_layer.update()
 groups=defaultdict(lambda:{'vertices':[],'normals':[],'triangles':[],'components':[]})
 for o in objects:
  mat=o.data.materials[0].name;g=groups[mat];g['components'].append(o.name)
  me=o.data;me.calc_loop_triangles();normalmatrix=o.matrix_world.to_3x3().inverted().transposed()
  # Split vertices by corner normal for a lossless small-model geometry transfer.
  lookup={}
  for tri in me.loop_triangles:
   ids=[]
   for li in tri.loops:
    v=o.matrix_world@me.vertices[me.loops[li].vertex_index].co;n=(normalmatrix@me.corner_normals[li].vector).normalized()
    # Blender Z-up -> Roblox Y-up, right-handed conversion.
    vp=(round(v.x,5),round(v.z,5),round(-v.y,5));np=(round(n.x,5),round(n.z,5),round(-n.y,5));key=vp+np
    if key not in lookup:
     lookup[key]=len(g['vertices']);g['vertices'].append(vp);g['normals'].append(np)
    ids.append(lookup[key])
   if len(set(ids))==3:g['triangles'].append(ids)
 data={'name':name,'rarity':rarities[index],'targetMax':targets[index],'parts':[],'authoredComponents':len(objects)}
 for mat,g in groups.items():data['parts'].append({'name':mat,'material':META[mat],**g})
 path=OUT/(name.replace(' ','_')+'.json');path.write_text(json.dumps(data,separators=(',',':')))
 manifest.append({'name':name,'file':path.name,'rarity':rarities[index],'maxDimension':targets[index],'parts':len(groups),'components':len(objects),'triangles':sum(len(g['triangles']) for g in groups.values())})
 # Keep each model as separately named editable objects in the .blend.
 for o in objects:o.location+=Vector(((index%5)*5.8,(index//5)*6.0,0))
(OUT/'manifest.json').write_text(json.dumps(manifest,indent=2))
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'Junkyard-Fusion-10-Addons.blend'))

# Render each item individually against a neutral studio floor.
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=24;scene.cycles.device='CPU'
scene.render.resolution_x=640;scene.render.resolution_y=540;scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('Studio');scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.15,.18,.23,1)
scene.view_settings.view_transform='AgX'
bpy.ops.object.camera_add();cam=bpy.context.object;scene.camera=cam;cam.data.type='ORTHO';cam.data.ortho_scale=5.9
lights=[]
for loc,power,size in [((2,-4,6),1100,5),((-4,-1,3),850,4),((1,4,5),1300,3)]:
 bpy.ops.object.light_add(type='AREA',location=loc);o=bpy.context.object;o.data.energy=power;o.data.shape='DISK';o.data.size=size;lights.append(o)
for index,name in enumerate(names):
 for n in names:bpy.data.collections[n].hide_render=n!=name
 center=Vector(((index%5)*5.8,(index//5)*6,0))
 cam.location=center+Vector((5,-7,5));cam.rotation_euler=(center-cam.location).to_track_quat('-Z','Y').to_euler()
 for o,(loc,power,size) in zip(lights,[((2,-4,6),1100,5),((-4,-1,3),850,4),((1,4,5),1300,3)]):
  o.location=center+Vector(loc);o.rotation_euler=(center-o.location).to_track_quat('-Z','Y').to_euler()
 scene.render.filepath=str(OUT/(name.replace(' ','_')+'.png'));bpy.ops.render.render(write_still=True)
for n in names:bpy.data.collections[n].hide_render=False
print('TEN_ADDONS_BUILT_AND_RENDERED')
