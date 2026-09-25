import bpy,math,json,random
from pathlib import Path
from mathutils import Vector
from collections import defaultdict
OUT=Path(__file__).parent
random.seed(924)
bpy.ops.wm.read_factory_settings(use_empty=True)
M={};META={};MODELS={};current=None
def mat(name,hex,kind='Enamel',metal=.25,rough=.35,glow=0):
 rgb=[int(hex[i:i+2],16)/255 for i in (0,2,4)]
 col=[v/12.92 if v<=.04045 else ((v+.055)/1.055)**2.4 for v in rgb]
 m=bpy.data.materials.new(name);m.use_nodes=True;m.diffuse_color=(*col,1)
 p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*col,1);p.inputs['Metallic'].default_value=metal;p.inputs['Roughness'].default_value=rough
 if glow:p.inputs['Emission Color'].default_value=(*col,1);p.inputs['Emission Strength'].default_value=glow
 texturepath=OUT.parent.parent/'new-addons/v2/textures'/f'{kind}_RoughnessMap.png'
 if texturepath.exists():
  nt=m.node_tree;tc=nt.nodes.new('ShaderNodeTexCoord');scale=nt.nodes.new('ShaderNodeVectorMath');scale.operation='SCALE';scale.inputs[3].default_value=3;nt.links.new(tc.outputs['Generated'],scale.inputs[0])
  tex=nt.nodes.new('ShaderNodeTexImage');tex.image=bpy.data.images.load(str(texturepath));tex.image.colorspace_settings.name='Non-Color';tex.image.pack();tex.projection='BOX';tex.projection_blend=.2;nt.links.new(scale.outputs[0],tex.inputs['Vector']);nt.links.new(tex.outputs['Color'],p.inputs['Roughness'])
  bump=nt.nodes.new('ShaderNodeBump');bump.inputs['Strength'].default_value=.20;bump.inputs['Distance'].default_value=.012;nt.links.new(tex.outputs['Color'],bump.inputs['Height']);nt.links.new(bump.outputs[0],p.inputs['Normal'])
 M[name]=m;META[name]={'color':col,'metal':metal,'alpha':1,'glow':glow,'finish':kind}
for name,h,kind,me,ro in [('Turquoise','00C0DC','Enamel',.25,.3),('Pink','F04B86','Enamel',.25,.3),('Green','35C35A','Enamel',.25,.3),('Orange','F66A24','Enamel',.3,.3),('Blue','1683EC','Enamel',.3,.3),('Cream','F3E6BD','Enamel',.15,.38),('White','DFE8E6','Enamel',.2,.35),('Black','172027','Enamel',.2,.4),('Steel','727E87','Cast',.75,.55),('Chrome','C4D0D5','Brushed',.9,.25),('Iron','343D43','Cast',.65,.65),('Rubber','151B20','Rubber',0,.8),('Seat','544B3D','Rubber',0,.8),('Rust','9B5427','Oxidized',.3,.85),('Glass','183D53','Glass',.65,.16),('Red','D82725','Enamel',.15,.3),('Gold','EAA530','Brushed',.7,.3)]:mat(name,h,kind,me,ro)
mat('Titanium','A6B4C4','Brushed',.9,.3)
mat('HeatBlue','3273BA','Brushed',.85,.3)
mat('HeatViolet','8862B5','Brushed',.8,.3)
mat('Upholstery','BA824D','Rubber',0,.75)
mat('Lamp','FFF1BC','Light',.05,.25,1)
mat('Brake','F32329','Light',.05,.3,.6)
mat('BlueLamp','1A7AFF','Light',.05,.3,.8)
def add(o,name,ma):
 o.name=name;o.data.materials.append(M[ma]);MODELS[current].append(o)
 for c in list(o.users_collection):c.objects.unlink(o)
 bpy.data.collections[current].objects.link(o);return o
def model(name):
 global current
 current=name;MODELS[name]=[];c=bpy.data.collections.new(name);bpy.context.scene.collection.children.link(c);print('BUILDING',name,flush=True)
def box(name,p,size,ma='Steel',bevel=.035,rot=None):
 sx,sy,sz=[a/2 for a in size]
 verts=[(-sx,-sy,-sz),(sx,-sy,-sz),(sx,sy,-sz),(-sx,sy,-sz),(-sx,-sy,sz),(sx,-sy,sz),(sx,sy,sz),(-sx,sy,sz)]
 o=mesh(name,verts,[(0,3,2,1),(4,5,6,7),(0,1,5,4),(1,2,6,5),(2,3,7,6),(3,0,4,7)],ma);o.location=p
 if rot:o.rotation_euler=rot
 if bevel:
  b=o.modifiers.new('Panel edge radius','BEVEL');b.width=bevel;b.segments=3
  o.modifiers.new('Weighted panel normals','WEIGHTED_NORMAL')
 return o
def cyl(name,a,b,r,ma='Steel',r2=None,n=32):
 a,b=Vector(a),Vector(b);v=(b-a).normalized();u=v.cross(Vector((1,0,0)) if abs(v.x)<.9 else Vector((0,1,0))).normalized();w=v.cross(u)
 verts=[tuple(c+rr*(u*math.cos(j*math.tau/n)+w*math.sin(j*math.tau/n)))for c,rr in [(a,r),(b,r if r2 is None else r2)]for j in range(n)]
 faces=[tuple(range(n-1,-1,-1)),tuple(range(n,n*2))]+[(j,(j+1)%n,(j+1)%n+n,j+n)for j in range(n)]
 o=mesh(name,verts,faces,ma)
 for f in o.data.polygons:f.use_smooth=len(f.vertices)==4
 return o
def tor(name,p,r,t,ma='Chrome',axis=(1,0,0),n=40):
 v=Vector(axis).normalized();u=v.cross(Vector((1,0,0))if abs(v.x)<.9 else Vector((0,1,0))).normalized();w=v.cross(u);c=Vector(p)
 verts=[tuple(c+(r+t*math.cos(k*math.tau/8))*(u*math.cos(j*math.tau/n)+w*math.sin(j*math.tau/n))+v*t*math.sin(k*math.tau/8))for j in range(n)for k in range(8)]
 faces=[(j*8+k,((j+1)%n)*8+k,((j+1)%n)*8+(k+1)%8,j*8+(k+1)%8)for j in range(n)for k in range(8)]
 o=mesh(name,verts,faces,ma)
 for f in o.data.polygons:f.use_smooth=True
 return o
def pipe(name,points,r,ma='Steel'):
 c=bpy.data.curves.new(name,'CURVE');c.dimensions='3D';c.resolution_u=6;c.bevel_depth=r;c.bevel_resolution=1
 if 'seam' in name.lower():
  sp=c.splines.new('POLY');sp.points.add(len(points)-1)
  for p,co in zip(sp.points,points):p.co=(*co,1)
 else:
  sp=c.splines.new('BEZIER');sp.bezier_points.add(len(points)-1)
  for p,co in zip(sp.bezier_points,points):p.co=co;p.handle_left_type='AUTO';p.handle_right_type='AUTO'
 o=bpy.data.objects.new(name,c);bpy.context.collection.objects.link(o);return add(o,name,ma)
def mesh(name,verts,faces,ma):
 me=bpy.data.meshes.new(name);me.from_pydata(verts,[],faces);me.update();o=bpy.data.objects.new(name,me);bpy.context.collection.objects.link(o);return add(o,name,ma)
def bolt(p,axis=(0,0,1),r=.035,ma='Chrome'):
 v=Vector(p);cyl('Hex fastener',v,v+Vector(axis)*.035,r,ma,n=6)
def quad(name,pts,ma,trim=False):
 o=mesh(name,pts,[(0,1,2,3)],ma)
 if trim:
  for j in range(4):cyl('Window seal',pts[j],pts[(j+1)%4],.019,'Rubber',n=10)
 return o
def loft(name,stations,ma):
 # y, halfwidth, bottom, shoulder, crown: crisp closed body panel sections.
 verts=[]
 for y,w,b,s,t in stations:verts.extend([(-w,y,b),(-w,y,s),(-w*.80,y,t),(w*.80,y,t),(w,y,s),(w,y,b)])
 faces=[tuple(range(5,-1,-1)),tuple(range((len(stations)-1)*6,len(stations)*6))]
 for j in range(len(stations)-1):
  for k in range(6):faces.append((j*6+k,j*6+(k+1)%6,(j+1)*6+(k+1)%6,(j+1)*6+k))
 o=mesh(name,verts,faces,ma);b=o.modifiers.new('Crisp panel bevel','BEVEL');b.width=.08;b.segments=5;o.modifiers.new('Body normals','WEIGHTED_NORMAL');return o
def wheel(x,y,z,r=.48,width=.26,rim='Chrome',offroad=False,spokes=5):
 start=len(MODELS[current])
 # Revolved tire cross-section leaves a real central opening.
 verts=[];faces=[];N=48
 section=[(-width*.50,r*.58),(-width*.53,r*.81),(-width*.37,r*.96),(0,r),(width*.37,r*.96),(width*.53,r*.81),(width*.50,r*.58)]
 for xx,rr in section:
  for j in range(N):a=j*math.tau/N;verts.append((x+xx,y+rr*math.sin(a),z+rr*math.cos(a)))
 for k in range(len(section)-1):
  for j in range(N):faces.append((k*N+j,k*N+(j+1)%N,(k+1)*N+(j+1)%N,(k+1)*N+j))
 o=mesh('Tire carcass',verts,faces,'Rubber')
 for f in o.data.polygons:f.use_smooth=True
 side=1 if x>=0 else -1
 if abs(x)<.001:side=1
 outer=x+side*width*.52
 cyl('Brake rotor',(x-width*.22,y,z),(x+width*.22,y,z),r*.48,'Steel')
 tor('Rim polished lip',(outer,y,z),r*.59,.026,rim)
 tor('Tire sidewall ridge',(outer,y,z),r*.79,.013,'Rubber')
 cyl('Wheel hub',(outer-side*.05,y,z),(outer+side*.03,y,z),r*.15,rim,n=24)
 for j in range(spokes):
  a=j*math.tau/spokes
  a2=a+.15
  cyl('Alloy spoke',(outer,y+r*.13*math.sin(a),z+r*.13*math.cos(a)),(outer,y+r*.55*math.sin(a2),z+r*.55*math.cos(a2)),r*.058,rim,n=6)
  bolt((outer+side*.035,y+r*.12*math.sin(a),z+r*.12*math.cos(a)),(side,0,0),r*.025)
 box('Brake caliper',(x,y+r*.36,z),(.12,r*.17,r*.39),'Red',.03)
 for j in range(24 if offroad else 32):
  a=j*math.tau/(24 if offroad else 32)
  for side2 in [-1,1]:
   rr=r*(.97 if offroad else .993)
   box('Raised tire tread',(x+side2*width*.23,y+rr*math.sin(a),z+rr*math.cos(a)),(width*.39,r*(.15 if offroad else .035),r*(.09 if offroad else .015)),'Rubber',.007,rot=(-a,0,side2*.20))
 for o in MODELS[current][start:]:
  o['WheelCenterY']=y
  if not o.name.startswith('Brake caliper'):
   o['WheelPivot']=[x,y,z];o['WheelRadius']=r;o['WheelId']=f'{x:.3f}_{y:.3f}'
def axle(y,z,w):
 cyl('Axle tube',(-w,y,z),(w,y,z),.07,'Iron')
 cyl('Differential housing',(-.20,y,z),(.20,y,z),.19,'Iron',n=24)
def arch(x,y,z,r,w,ma):
 # Half-ring fender with open wheelwell, separate inner dark liner.
 verts=[];faces=[];N=25
 for xx,rr in [(x-w/2,r),(x+w/2,r),(x+w/2,r+.12),(x-w/2,r+.12)]:
  for j in range(N):a=-math.pi*.05+j/(N-1)*math.pi*1.10;verts.append((xx,y-rr*math.cos(a),z+rr*math.sin(a)))
 for k in range(4):
  for j in range(N-1):faces.append((k*N+j,k*N+j+1,((k+1)%4)*N+j+1,((k+1)%4)*N+j))
 o=mesh('Sculpted open wheel arch',verts,faces,ma)
 for i,f in enumerate(o.data.polygons):f.use_smooth=i//(N-1) in [0,2]
 b=o.modifiers.new('Soft toy fender edge','BEVEL');b.width=.025;b.segments=3
 o.modifiers.new('Fender weighted normals','WEIGHTED_NORMAL')
def seat(x,y,z,w=.55):
 box('Seat cushion',(x,y,z),(w,.55,.13),'Seat',.09)
 box('Seat back',(x,y+.24,z+.33),(w,.13,.60),'Seat',.09,rot=(.10,0,0))
 for xx in [-w*.28,0,w*.28]:pipe('Seat stitching',[(x+xx,y-.22,z+.072),(x+xx,y+.17,z+.072)],.006,'Cream')
def steering(x,y,z,r=.19):
 cyl('Steering column',(x,y+.22,z-.27),(x,y,z),.035,'Iron')
 tor('Steering wheel',(x,y,z),r,.024,'Rubber',(0,-.65,.75),32)
 for j in range(3):
  a=j*math.tau/3;cyl('Steering spoke',(x,y,z),(x+r*.82*math.cos(a),y+r*.62*math.sin(a),z+r*.54*math.sin(a)),.015,'Chrome',n=8)
def grille(y,z,w,h):
 box('Recessed grille pocket',(0,y,z),(w,.055,h),'Black',.035)
 for j in range(7):box('Grille horizontal slat',(0,y-.035,z-h*.39+j*h*.13),(w*.93,.035,.023),'Chrome',.006)
def headlamp(x,y,z,r=.14):
 cyl('Headlight housing',(x,y+.04,z),(x,y-.05,z),r*1.20,'Black',n=32)
 cyl('Headlight reflector',(x,y-.052,z),(x,y-.068,z),r,'Lamp',n=32)
 tor('Headlight chrome rim',(x,y-.075,z),r*1.05,.018,'Chrome',(0,1,0),32)
def bumper(y,z,w):
 box('Bumper impact bar',(0,y,z),(w,.20,.24),'Chrome',.085)
 for x in [-w*.28,w*.28]:box('Bumper rubber overrider',(x,y-.08,z),(.14,.13,.29),'Rubber',.035)
def spring(a,b,r=.09):
 a,b=Vector(a),Vector(b);v=b-a;u=v.cross(Vector((1,0,0))).normalized();w=v.normalized().cross(u)
 pts=[]
 for j in range(61):t=j/60;pts.append(a+v*t+r*(math.cos(t*math.tau*6)*u+math.sin(t*math.tau*6)*w))
 pipe('Coil spring',pts,.019,'Orange');cyl('Shock damper',a,b,.04,'Chrome',n=16)
def wear_panel(x,y,z,w,l):
 # Small separate exposed chips, never noise blobs over the silhouette.
 for j in range(5):
  xx=x+(random.random()-.5)*w;yy=y+(random.random()-.5)*l
  box('Paint edge chip',(xx,yy,z),(.025+random.random()*.055,.012+random.random()*.035,.006),'Rust',.003,rot=(0,0,random.random()))

# 1. Stable Rusted Sedan key; approved open Scrap Kart identity.
model('Rusted Sedan')
box('Kart floor pan',(0,.15,.43),(1.62,2.82,.21),'Iron',.075)
for y in [-1.22,1.26]:
 axle(y,.49,1.12)
 for x in [-1.11,1.11]:wheel(x,y,.50,.47,.34,'Orange',True)
loft('Rounded kart bonnet',[(-1.92,.64,.64,.88,.94),(-1.65,.84,.61,1.04,1.13),(-.67,.74,.62,1.06,1.15)],'Turquoise')
grille(-1.94,.79,.93,.22)
for x in [-.67,.67]:headlamp(x,-1.78,1.045,.17)
bumper(-2.02,.57,1.65)
for x in [-.93,.93]:
 for y in [-1.22,1.26]:arch(x,y,.50,.52,.41,'Turquoise')
 pipe('Side crash rail',[(x,-.66,.56),(x,.60,.56),(x,1.20,.72)],.048,'Chrome')
 pipe('Roll hoop',[(x*.74,.95,.56),(x*.74,1.03,1.95),(x*.44,1.04,2.15),(0,1.04,2.15)],.055,'Iron')
box('Wide upholstered seat base',(0,.22,.80),(1.08,.78,.28),'Seat',.12)
box('Plump tan seat cushion',(0,.16,.92),(.89,.64,.17),'Upholstery',.08)
box('Reclined padded seat back',(0,.57,1.22),(1.07,.24,.79),'Seat',.11,rot=(.12,0,0))
box('Tan backrest inset',(0,.425,1.25),(.82,.13,.62),'Upholstery',.065,rot=(.12,0,0))
box('Padded headrest',(0,.61,1.75),(.65,.27,.30),'Upholstery',.11)
for x in [-.48,.48]:
 box('Cushioned seat side bolster',(x,.21,1.02),(.17,.67,.24),'Upholstery',.08)
 box('Supportive backrest bolster',(x,.47,1.32),(.17,.24,.61),'Upholstery',.075,rot=(.12,0,0))
for x in [-.27,0,.27]:
 pipe('Cushion stitch seam',[(x,-.09,1.009),(x,.37,1.009)],.007,'Cream')
 pipe('Backrest stitch seam',[(x,.341,1.02),(x,.292,1.49)],.007,'Cream')
steering(0,-.41,1.32,.24)
box('Instrument dashboard',(0,-.62,1.15),(1.16,.19,.28),'Black',.05)
for x in [-.24,0,.24]:cyl('Gauge dial',(x,-.50,1.18),(x,-.485,1.18),.075,'Chrome',n=24)
box('Rear exposed engine',(0,1.19,.72),(.73,.65,.40),'Steel',.055)
for j in range(7):box('Engine cooling fin',(0,.92+j*.09,.82),(.8,.035,.3),'Iron',.01)
exhaust_start=len(MODELS[current])
for side in [-1,1]:
 x=side*.49
 pipe('Titanium exhaust header',[(side*.32,1.22,.85),(x,1.24,1.06),(x,1.07,1.31)],.082,'Titanium')
 # Continuous open-ended tube, with a dark inner wall and heat-coloured bands.
 rings=[(1.29,.09),(1.47,.10),(1.68,.10),(1.80,.115),(1.91,.115)]
 for j in range(len(rings)-1):
  za,ra=rings[j];zb,rb=rings[j+1];verts=[]
  for z,r in [(za,ra),(zb,rb)]:
   for k in range(32):
    a=k*math.tau/32;verts.append((x+r*math.cos(a),1.07+r*math.sin(a),z))
  o=mesh('Titanium heat-stained exhaust wall',verts,[(k,(k+1)%32,(k+1)%32+32,k+32)for k in range(32)],['Titanium','Titanium','HeatViolet','HeatBlue'][j])
  for f in o.data.polygons:f.use_smooth=True
 verts=[(x+.094*math.cos(k*math.tau/32),1.07+.094*math.sin(k*math.tau/32),z)for z in [1.51,1.91]for k in range(32)]
 mesh('Dark hollow exhaust bore',verts,[(k+32,(k+1)%32+32,(k+1)%32,k)for k in range(32)],'Iron')
 tor('Rolled titanium exhaust lip',(x,1.07,1.91),.104,.012,'HeatBlue',(0,0,1),32)
 tor('Exhaust mounting clamp',(x,1.07,1.40),.103,.014,'Chrome',(0,0,1),24)
 box('Exhaust clamp mounting tab',(x,1.17,1.40),(.12,.19,.07),'Titanium',.015)
 bolt((x,1.22,1.44),r=.028)
from mathutils import Matrix
bpy.context.view_layer.update()
pivot=Vector((0,1.07,1.29));turn=Matrix.Rotation(-math.pi/2,4,'X')
for obj in MODELS[current][exhaust_start:]:
 if obj.name.startswith('Titanium exhaust header'):continue
 obj.matrix_world=Matrix.Translation(pivot)@turn@Matrix.Translation(-pivot)@obj.matrix_world
box('Rear orange equipment box',(0,1.67,.67),(1.05,.38,.3),'Orange',.035)
wear_panel(0,-1.28,1.153,1.1,.6)
for x in [-.62,.62]:bolt((x,-.75,1.13),r=.044)

# 2. Narrow motocross chassis, real fork/chain/spoke silhouettes.
model('Dirt Bike')
for y in [-1.25,1.10]:wheel(0,y,.60,.57,.22,'Chrome',True,12)
for x in [-.20,.20]:
 cyl('Front fork outer',(x,-1.25,.60),(x,-.85,1.58),.052,'Gold')
 cyl('Front fork stanchion',(x,-.95,1.27),(x,-.69,1.88),.036,'Chrome')
 cyl('Rear swing arm',(x,1.10,.6),(x,.03,.90),.047,'Steel')
 pipe('Tubular perimeter frame',[(x,-.65,1.46),(x,-.22,.59),(x,.44,.69),(x,.57,1.46),(x,-.65,1.46)],.041,'Iron')
spring((0,.59,.72),(0,.16,1.36),.075)
box('Single cylinder crankcase',(0,0,.88),(.44,.57,.42),'Steel',.11)
cyl('Cylinder barrel',(0,-.07,1.01),(0,-.20,1.35),.16,'Iron')
for z in [1.10,1.16,1.22,1.28]:box('Cylinder cooling fin',(0,-.13,z),(.4,.31,.022),'Chrome',.006)
loft('Sculpted fuel tank',[(-.67,.11,1.40,1.63,1.68),(-.29,.27,1.36,1.67,1.79),(.26,.20,1.41,1.55,1.62)],'Pink')
box('Gripper saddle',(0,.58,1.55),(.40,1.05,.16),'Black',.08)
for y in [.23,.40,.57,.74,.91]:box('Seat grip rib',(0,y,1.637),(.33,.028,.014),'Rubber',.006)
loft('Raised front mudguard',[(-1.88,.09,1.15,1.21,1.24),(-1.3,.22,1.30,1.38,1.42),(-.89,.14,1.38,1.44,1.46)],'Pink')
loft('Rear tail mudguard',[(.63,.19,1.40,1.48,1.54),(1.40,.18,1.45,1.50,1.55),(1.62,.11,1.48,1.51,1.55)],'Pink')
pipe('Handlebar',[(-.67,-.63,1.97),(-.39,-.60,1.99),(-.2,-.71,1.90),(.2,-.71,1.90),(.39,-.60,1.99),(.67,-.63,1.97)],.032,'Chrome')
for x in [-.55,.55]:box('Hand grip',(x,-.625,1.97),(.23,.08,.08),'Rubber',.035)
box('Front number plate',(0,-.84,1.69),(.49,.08,.48),'White',.07,rot=(.16,0,0))
box('Number plate inset',(0,-.894,1.69),(.28,.012,.25),'Pink',.02)
pipe('Expansion chamber',[(.14,-.12,1.24),(.35,-.53,1.08),(.36,-.13,.88),(.34,.73,1.18),(.34,1.23,1.39)],.078,'Steel')
cyl('Exhaust silencer',(.34,.64,1.22),(.34,1.33,1.45),.09,'Chrome')
pipe('Drive chain',[(-.15,1.10,.73),(-.15,.06,.93),(-.15,-.02,.82),(-.15,1.10,.47),(-.15,1.23,.6),(-.15,1.10,.73)],.019,'Iron')
for x in [-.36,.36]:box('Serrated foot peg',(x,.11,.72),(.25,.14,.06),'Steel',.016)

# 3. Green leisure cart: open cabin, cream canopy and upholstered two-person bench.
model('Golf Cart')
box('Golf cart chassis',(0,0,.43),(1.76,3.12,.21),'Iron',.075)
for y in [-1.07,1.17]:
 axle(y,.47,.99)
 for x in [-1.,1.]:wheel(x,y,.48,.43,.27,'Chrome',False,6)
loft('Green cowl',[(-1.72,.86,.62,.99,1.08),(-1.38,.94,.57,1.25,1.32),(-.62,.89,.64,1.19,1.25)],'Green')
for x in [-.98,.98]:
 for y in [-1.07,1.17]:arch(x,y,.47,.48,.28,'Green')
 box('Entry step',(x,.16,.50),(.25,1.22,.13),'Black',.04)
 for y in [-.75,1.18]:cyl('Canopy upright',(x*.80,y,.80),(x*.80,y,2.89),.045,'Iron')
box('Cream canopy',(0,.24,2.96),(2.16,2.87,.17),'Cream',.18)
box('Canopy underside',(0,.24,2.86),(1.97,2.64,.06),'White',.10)
quad('Clear tinted windscreen',[(-.76,-.77,1.24),(.76,-.77,1.24),(.76,-.77,2.56),(-.76,-.77,2.56)],'Glass',True)
pipe('Windscreen hinge',[(-.75,-.79,1.91),(.75,-.79,1.91)],.022,'Chrome')
seat(-.43,.38,1.03,.76);seat(.43,.38,1.03,.76)
steering(-.43,-.38,1.48,.21)
box('Seat base storage',(0,.47,.77),(1.63,1.13,.38),'Green',.08)
box('Rear basket',(0,1.32,1.08),(1.65,.44,.44),'Iron',.035)
for x in [-.7,-.35,0,.35,.7]:box('Basket grille slot',(x,1.555,1.08),(.09,.01,.29),'Black',.008)
for bx,color in [(-.43,'Blue'),(.43,'Orange')]:
 cyl('Golf bag body',(bx,1.32,1.10),(bx,1.32,1.98),.23,color,n=24)
 tor('Padded golf bag rim',(bx,1.32,1.99),.22,.035,'Rubber',(0,0,1),24)
 cyl('Dark bag opening',(bx,1.32,1.965),(bx,1.32,1.975),.185,'Black',n=24)
 box('Golf bag side pocket',(bx,1.52,1.43),(.30,.14,.39),color,.065)
 pipe('Golf bag carry strap',[(bx+.20,1.35,1.84),(bx+.31,1.36,1.50),(bx+.20,1.35,1.22)],.025,'Cream')
 for j in range(4):
  xx=bx+(-.12+j*.08);yy=1.29+(j%2)*.10;top=2.38+(j%3)*.13
  cyl('Golf club steel shaft',(xx,yy,1.63),(xx,yy+.05,top),.018,'Chrome',n=10)
  if j==0:
   box('Oversize driver head',(xx+.07,yy+.05,top),(.23,.14,.12),'Black',.055)
   box('Driver orange crown',(xx+.07,yy+.05,top+.052),(.17,.10,.025),'Orange',.012)
  else:
   box('Angled golf iron head',(xx+.055,yy+.05,top),(.17,.055,.10),'Chrome',.025,rot=(0,.22,0))
   for k in range(3):box('Iron face groove',(xx+.055,yy+.079,top-.025+k*.022),(.12,.009,.005),'Iron',.002)
for x in [-.59,.59]:box('Inset square headlamp',(x,-1.745,.94),(.31,.04,.18),'Lamp',.045)
grille(-1.76,.70,1.06,.18);bumper(-1.83,.54,1.82)
for x in [-.53,.53]:box('Rear reflector',(x,1.70,.76),(.26,.04,.12),'Brake',.025)

def road_body(name,color,w=1.1,L=4.3,wheels=(-1.30,1.25),height=1.9,police=False):
 model(name);r=.47;z=.49
 box('Central underbody',(0,.1,.49),(w*1.38,L*.83,.17),'Iron',.06)
 for y in wheels:
  axle(y,z,w)
  for x in [-w,w]:wheel(x,y,z,r,.27,'Chrome',False,5 if not police else 7);arch(x*.95,y,z,r+.04,.29,color)
 # Separate front/rear panels and door sills leave real wheel openings.
 loft('Sculpted nose',[(-L/2,w*.91,.57,.84,.94),(-L/2+.27,w,.57,1.05,1.13),(-.57,w*.98,.72,1.10,1.15)],color)
 loft('Rear quarter deck',[(.87,w*.96,.66,1.12,1.18),(L/2-.18,w*.98,.60,1.06,1.13),(L/2,w*.93,.58,.94,1.00)],color)
 for side in [-1,1]:
  box('Door lower panel',(side*w*.94,.12,.88),(.10,1.67,.49),'White' if police else color,.055)
  box('Side rocker trim',(side*w,.12,.61),(.12,1.63,.10),'Chrome' if police else 'Black',.025)
  pipe('Door panel seam',[(side*w*.995,-.57,1.10),(side*w*.995,-.57,.68),(side*w*.995,.80,.68),(side*w*.995,.80,1.09)],.012,'Black')
  box('Door handle',(side*w*1.01,.45,1.07),(.055,.20,.034),'Chrome',.016)
  box('Wing mirror',(side*w*1.13,-.54,1.27),(.19,.27,.13),color,.05)
 # Glasshouse genuinely slopes into hood and trunk with separate roof/pillars.
 front=-.68;rear=1.00;roofFront=-.22;roofRear=.61;bottom=1.13;top=height
 quad('Front windscreen',[(-w*.86,front,bottom),(w*.86,front,bottom),(w*.72,roofFront,top-.08),(-w*.72,roofFront,top-.08)],'Glass',True)
 quad('Rear windscreen',[(w*.86,rear,bottom),(-w*.86,rear,bottom),(-w*.72,roofRear,top-.08),(w*.72,roofRear,top-.08)],'Glass',True)
 for side in [-1,1]:
  pts=[(side*w*.87,front+.04,bottom+.035),(side*w*.87,rear-.05,bottom+.035),(side*w*.74,roofRear,top-.08),(side*w*.74,roofFront,top-.08)]
  quad('Side window',pts,'Glass',True)
  for a,b in [(pts[0],pts[3]),(pts[1],pts[2])]:cyl('Painted cabin pillar',a,b,.044,color,n=12)
  cyl('B pillar',(side*w*.88,.30,bottom),(side*w*.75,.28,top-.08),.035,'Black',n=10)
 box('Shaped roof',(0,.20,top),(w*1.54,.94,.115),color,.11)
 bumper(-L/2-.07,.57,w*1.90);bumper(L/2+.05,.58,w*1.87)
 grille(-L/2-.035,.82,w*1.00,.27)
 for x in [-w*.74,-w*.47,w*.47,w*.74]:headlamp(x,-L/2-.045,.89,.10)
 for x in [-w*.64,w*.64]:box('Recessed tail lamp',(x,L/2+.025,.91),(.44,.045,.17),'Brake',.035)
 box('License plate recess',(0,L/2+.065,.74),(.43,.015,.16),'White',.014)
 for x in [-w*.55,w*.55]:cyl('Exhaust tip',(x,L/2-.10,.39),(x,L/2+.12,.39),.07,'Chrome');cyl('Exhaust bore',(x,L/2+.122,.39),(x,L/2+.125,.39),.052,'Black')
 for x in [-w*.36,w*.36]:seat(x,.13,.83,.54)
 steering(-w*.36,-.39,1.16,.15)
 return w,L

# 4. Low orange fastback, long hood, twin stripes and a restrained ducktail.
road_body('Muscle Car','Orange',1.05,4.6,(-1.37,1.35),1.65)
for x in [-.22,.22]:
 quad('Hood racing stripe',[(x-.105,-2.00,1.137),(x+.105,-2.00,1.137),(x+.105,-.70,1.161),(x-.105,-.70,1.161)],'Black')
 box('Roof racing stripe',(x,.20,1.709),(.21,.74,.008),'Black',.006)
box('Hood scoop',(0,-1.18,1.21),(.67,.68,.13),'Black',.065)
box('Scoop throat',(0,-1.53,1.22),(.48,.02,.075),'Iron',.017)
box('Rear ducktail',(0,2.05,1.18),(1.96,.23,.15),'Orange',.04,rot=(-.18,0,0))
for x in [-1.02,1.02]:
 for y in [-.77,-.64,-.51]:box('Fender vent blade',(x,y,1.00),(.025,.055,.18),'Black',.007,rot=(.22,0,0))

# 5. Upright black/white four-door patrol sedan with pushbar and lamp rack.
road_body('Cop Cruiser','Black',1.12,4.50,(-1.35,1.31),2.0,True)
for side in [-1,1]:
 pipe('Rear door seam',[(side*1.119,.18,1.13),(side*1.119,.18,.67)],.013,'Black')
 box('Rear door handle',(side*1.14,.77,1.06),(.04,.16,.035),'Chrome',.012)
 # Geometric shield badge, avoiding real police marks.
 verts=[(side*1.18,-.12,1.00),(side*1.18,.08,1.00),(side*1.18,.10,.82),(side*1.18,-.02,.73),(side*1.18,-.14,.82)]
 mesh('Gold patrol shield',verts,[(0,1,2,3,4)],'Gold')
 cyl('Pushbar upright',(side*.73,-2.43,.48),(side*.73,-2.43,1.22),.045,'Iron')
pipe('Pushbar cross tube',[(-.84,-2.43,.92),(.84,-2.43,.92)],.05,'Iron')
box('Lightbar mount',(0,.15,2.12),(1.55,.38,.08),'Chrome',.035)
box('Red emergency lens',(-.49,.15,2.23),(.52,.34,.19),'Brake',.05)
box('Blue emergency lens',(.49,.15,2.23),(.52,.34,.19),'BlueLamp',.05)
box('Lightbar center',(0,.15,2.22),(.36,.32,.16),'White',.03)
cyl('Radio antenna',(.79,1.73,1.16),(.79,1.73,2.11),.012,'Iron',n=8)
headlamp(-1.12,-.6,1.43,.11)

# 6. Cream cab-over delivery truck with blue ribbed box and rear roll-up door.
model('Box Truck')
box('Ladder chassis',(0,.2,.50),(1.65,4.8,.20),'Iron',.05)
for y in [-1.51,1.52]:
 axle(y,.61,1.14)
 for x in [-1.15,1.15]:wheel(x,y,.60,.57,.36,'Chrome',False,8)
loft('Cab lower shell',[(-2.62,1.04,.61,1.35,1.42),(-2.35,1.12,.65,1.45,1.50),(-.79,1.12,.63,1.49,1.55)],'Cream')
for x in [-1.10,1.10]:arch(x,-1.51,.60,.62,.32,'Cream')
box('Cab rear wall',(0,-.83,1.89),(2.14,.10,1.51),'Cream',.06)
box('Cab roof',(0,-1.66,2.67),(2.30,1.89,.16),'Cream',.13)
quad('Truck panoramic windshield',[(-.98,-2.59,1.55),(.98,-2.59,1.55),(.99,-2.44,2.55),(-.99,-2.44,2.55)],'Glass',True)
for side in [-1,1]:
 quad('Truck side window',[(side*1.075,-2.44,1.59),(side*1.075,-.98,1.59),(side*1.075,-.98,2.55),(side*1.075,-2.29,2.55)],'Glass',True)
 cyl('Cab front pillar',(side*1.06,-2.58,1.49),(side*1.06,-2.43,2.6),.055,'Cream')
 pipe('Door seam',[(side*1.127,-2.31,1.49),(side*1.127,-2.27,.82),(side*1.127,-.98,.82),(side*1.127,-.98,2.53)],.013,'Iron')
 box('Cab handle',(side*1.14,-1.10,1.50),(.04,.18,.06),'Chrome',.015)
 pipe('Wing mirror bracket',[(side*1.04,-2.2,2.13),(side*1.40,-2.16,2.16),(side*1.40,-2.13,1.75)],.025,'Iron')
 box('Truck side mirror',(side*1.40,-2.13,1.96),(.12,.20,.42),'Black',.04)
 box('Cab foot step',(side*1.13,-.98,.63),(.30,.60,.11),'Steel',.02)
box('Cargo box',(0,1.04,2.0),(2.43,3.57,2.49),'Blue',.07)
for side in [-1,1]:
 for y in [-.67,2.75]:box('Box corner extrusion',(side*1.24,y,2.02),(.08,.10,2.53),'Chrome',.015)
 for z in [.77,3.23]:box('Cargo side edge rail',(side*1.24,1.04,z),(.075,3.58,.09),'Chrome',.015)
 for y in [-.40,0,.4,.8,1.2,1.6,2.0,2.4]:
  box('Ribbed cargo wall',(side*1.231,y,2.02),(.029,.045,2.29),'Blue',.012)
  for z in [.90,3.08]:bolt((side*1.267,y,z),(side,0,0),.025)
 box('Orange side marker',(side*1.28,2.54,1.0),(.025,.15,.08),'Orange',.016)
box('Rear rollup door',(0,2.85,2.03),(2.12,.055,2.16),'White',.035)
for z in [.99,1.23,1.47,1.71,1.95,2.19,2.43,2.67,2.91]:box('Rollup slat seam',(0,2.89,z),(2.06,.022,.025),'Steel',.006)
for x in [-.8,.8]:box('Rear latch upright',(x,2.925,1.62),(.035,.03,1.44),'Chrome',.01)
bumper(-2.72,.66,2.35);bumper(2.89,.63,2.40);grille(-2.65,1.08,1.15,.31)
for x in [-.85,.85]:headlamp(x,-2.67,1.30,.15);box('Rear tail lamp',(x,2.94,.83),(.25,.045,.18),'Brake',.03)
for x in [-.68,0,.68]:box('Cab roof marker',(x,-2.35,2.78),(.16,.14,.075),'Orange',.03)
for x in [-.47,.47]:seat(x,-1.34,1.30,.65)
steering(-.47,-2.02,1.82,.19)

# 7. Tall blue pickup monster, open bed, orange beadlocks and exposed suspension.
model('Monster Truck')
box('Raised chassis',(0,0,.93),(1.20,3.00,.22),'Iron',.04)
for y in [-1.03,1.10]:
 axle(y,.71,1.14)
 for x in [-1.12,1.12]:
  wheel(x,y,.74,.73,.56,'Orange',True,6)
  spring((x*.77,y,.80),(x*.61,y,1.54),.095)
  cyl('Suspension link',(x*.4,0,.94),(x*.83,y,.73),.038,'Chrome')
loft('Pickup nose',[(-1.86,.75,1.34,1.72,1.80),(-1.58,.89,1.26,1.82,1.91),(-.63,.85,1.30,1.84,1.95)],'Blue')
for x in [-.98,.98]:
 for y in [-1.03,1.10]:arch(x,y,.90,.69,.30,'Blue')
 box('Cab door',(x*.82,-.13,1.55),(.10,1.02,.49),'Blue',.055)
 box('Side step',(x*.9,-.08,1.19),(.18,.81,.10),'Chrome',.03)
 box('Orange door accent',(x*.887,-.13,1.53),(.02,.69,.075),'Orange',.016)
quad('Pickup windshield',[(-.67,-.69,1.90),(.67,-.69,1.90),(.62,-.38,2.52),(-.62,-.38,2.52)],'Glass',True)
for side in [-1,1]:
 quad('Pickup side window',[(side*.76,-.6,1.88),(side*.76,.41,1.88),(side*.65,.38,2.51),(side*.65,-.36,2.51)],'Glass',True)
 cyl('Pickup A pillar',(side*.70,-.66,1.90),(side*.66,-.37,2.53),.038,'Blue')
 box('Pickup B pillar',(side*.71,.43,2.20),(.12,.12,.69),'Blue',.035)
box('Pickup roof',(0,.03,2.57),(1.50,.96,.12),'Blue',.09)
box('Cab rear panel',(0,.52,1.98),(1.53,.13,.85),'Blue',.04)
box('Bed floor',(0,1.19,1.36),(1.63,1.23,.12),'Black',.035)
for x in [-.84,.84]:box('Pickup bed side',(x,1.24,1.65),(.13,1.37,.56),'Blue',.05)
box('Tailgate',(0,1.92,1.64),(1.76,.13,.55),'Blue',.045)
for x in [-.55,-.28,0,.28,.55]:box('Bed floor rib',(x,1.23,1.435),(.047,1.20,.018),'Iron',.006)
grille(-1.90,1.63,1.03,.27)
for x in [-.64,.64]:headlamp(x,-1.90,1.75,.13)
pipe('Front bull bar',[(-.85,-2.02,1.29),(-.85,-2.02,1.57),(.85,-2.02,1.57),(.85,-2.02,1.29)],.05,'Chrome')
box('Winch',(0,-1.97,1.25),(.54,.20,.17),'Iron',.04)
for x in [-.57,-.19,.19,.57]:headlamp(x,-.28,2.78,.115)
pipe('Roof light rack',[(-.69,-.20,2.65),(.69,-.20,2.65)],.035,'Iron')
for x in [-.66,.66]:box('Pickup tail light',(x,2.001,1.62),(.17,.035,.32),'Brake',.026)
seat(-.33,.08,1.45,.55);seat(.33,.08,1.45,.55)
steering(-.33,-.43,1.92,.17)

# Second design pass: signage, controls, hardware and more recognizable trim.
def lettering(label,p,size,ma='White',rot=(0,0,0)):
 c=bpy.data.curves.new(label,'FONT');c.body=label;c.align_x='CENTER';c.size=size;c.extrude=.0015;c.resolution_u=3
 fontpath='C:/Windows/Fonts/arialbd.ttf'
 try:c.font=bpy.data.fonts.load(fontpath,check_existing=True)
 except:pass
 o=bpy.data.objects.new(label,c);bpy.context.collection.objects.link(o);o.location=p;o.rotation_euler=rot;return add(o,'Raised graphic '+label,ma)
current='Box Truck'
for side in [-1,1]:
 box('Billboard dark frame',(side*1.275,1.06,2.09),(.055,3.08,1.49),'Black',.055)
 box('Cream billboard face',(side*1.311,1.06,2.09),(.025,2.96,1.36),'Cream',.035)
 # Graphics are actual crisp extruded vector shapes, no external image dependency.
 rot=(math.pi/2,0,side*math.pi/2)
 lettering('JUNKYARD',(side*1.331,1.12,2.40),.265,'Blue',rot)
 lettering('FUSION',(side*1.331,1.12,2.05),.35,'Orange',rot)
 lettering('SALVAGE / REBUILD / REPEAT',(side*1.332,1.06,1.69),.115,'Black',rot)
 for y in [-.34,2.46]:
  for z in [1.50,2.69]:bolt((side*1.339,y,z),(side,0,0),.024)
 for y in [-.24,2.35]:
  tor('Billboard gear emblem',(side*1.336,y,2.14),.135,.036,'Blue',(1,0,0),24)
  for j in range(8):
   a=j*math.tau/8;box('Gear tooth',(side*1.337,y+.177*math.sin(a),2.14+.177*math.cos(a)),(.023,.061,.067),'Blue',.004,rot=(-a,0,0))
 # Practical cab detail.
 for j in range(3):box('Cab side cooling louver',(side*1.13,-1.34+j*.15,1.12),(.015,.055,.18),'Iron',.009)
for x in [-.52,.52]:pipe('Truck windshield wiper',[(x,-2.613,1.62),(x+.22,-2.525,2.18)],.018,'Black')
current='Rusted Sedan'
for side in [-1,1]:
 spring((side*.65,-1.20,.52),(side*.57,-.86,.82),.055)
 pipe('Kart front tie rod',[(side*.4,-1.23,.51),(side*.95,-1.23,.51)],.025,'Chrome')
 cyl('Headlamp cross guard',(side*.67-.1,-1.835,1.015),(side*.67+.1,-1.835,1.015),.016,'Iron',n=8)
 cyl('Headlamp cross guard',(side*.67,-1.835,.915),(side*.67,-1.835,1.115),.016,'Iron',n=8)
for x in [-.48,.48]:
 pipe('Hood edge trim',[(x,-1.68,1.125),(x,-.81,1.154)],.016,'Orange')
 bolt((x,-1.67,1.15),r=.028)
box('Kart tow eye plate',(0,-2.10,.55),(.25,.035,.16),'Orange',.02)
tor('Kart tow ring',(0,-2.13,.49),.075,.018,'Chrome',(0,1,0),24)
current='Dirt Bike'
lettering('07',(0,-.903,1.61),.23,'Black',(math.pi/2,0,0))
for side in [-1,1]:
 box('Radiator shroud',(side*.27,-.25,1.42),(.06,.56,.31),'Pink',.035,rot=(0,side*.12,0))
 for j in range(4):box('Radiator shroud vent',(side*.307,-.43+j*.115,1.43),(.013,.040,.19),'Black',.006)
 pipe('Brake hydraulic line',[(side*.45,-.65,1.97),(side*.27,-.80,1.36),(side*.18,-1.24,.68)],.012,'Black')
for y in [-.19,-.11,-.03]:box('Cylinder rib accent',(0,y,1.20),(.38,.026,.13),'Steel',.004)
current='Golf Cart'
for side in [-1,1]:
 pipe('Passenger armrest',[(side*.85,.0,1.1),(side*.86,.05,1.46),(side*.86,.65,1.46),(side*.85,.70,1.1)],.036,'Black')
box('Golf cart dashboard',(0,-.56,1.28),(1.45,.20,.17),'Black',.04)
for x in [-.37,.37]:tor('Cup holder rim',(x,-.56,1.37),.10,.018,'Chrome',(0,0,1),24);cyl('Cup holder pocket',(x,-.56,1.32),(x,-.56,1.371),.085,'Black',n=24)
lettering('YARD CLUB',(0,-1.782,.84),.14,'Cream',(math.pi/2,0,0))
current='Muscle Car'
for x in [-.52,.52]:
 pipe('Windshield wiper',[(x,-.716,1.17),(x+.2,-.51,1.38)],.014,'Black')
 for j in range(3):box('Hood cooling slot',(x,-.82-j*.105,1.154),(.22,.04,.017),'Iron',.009)
 box('Amber corner marker',(x*1.8,-1.96,.94),(.09,.028,.08),'Orange',.018)
for side in [-1,1]:
 box('Quarter panel stripe',(side*1.038,1.75,.96),(.015,.54,.055),'Black',.01)
 box('Mirror mounting stalk',(side*1.135,-.54,1.24),(.14,.048,.06),'Chrome',.018)
lettering('FUSION',(0,2.346,.82),.10,'Chrome',(-math.pi/2,0,math.pi))
current='Cop Cruiser'
for side in [-1,1]:
 lettering('PATROL',(side*1.189,.40,.91),.115,'Black',(math.pi/2,0,side*math.pi/2))
 pipe('Mirror mounting stalk',[(side*1.07,-.54,1.24),(side*1.20,-.54,1.27)],.021,'Chrome')
for x in [-.54,.54]:pipe('Patrol wiper',[(x,-.718,1.17),(x+.20,-.47,1.60)],.015,'Black')
box('Pushbar warning stripe',(0,-2.485,.93),(.44,.012,.06),'Gold',.005)
current='Monster Truck'
for side in [-1,1]:
 pipe('Bed roll cage',[(side*.62,.62,1.46),(side*.62,.72,2.30),(side*.62,1.62,1.47)],.043,'Iron')
 pipe('Exposed exhaust header',[(side*.57,-.63,1.15),(side*.79,-.12,1.05),(side*.83,.51,1.13)],.065,'Chrome')
 box('Fender bolt plate',(side*1.00,-1.03,1.60),(.028,.51,.09),'Black',.015)
 for y in [-1.24,-1.03,-.82]:bolt((side*1.02,y,1.60),(side,0,0),.025)
lettering('YARD BEAST',(0,2.004,1.66),.15,'White',(-math.pi/2,0,math.pi))

names=list(MODELS);targets=[(3.3,2.3,4.945),(2.,2.7,4.485),(3.1,4.4,5.865),(2.6,1.8,5.175),(3.1,3.1,5.98),(3.6,4.9,7.475),(3.55,3.1,4.485)]
rarities=['common','common','uncommon','uncommon','rare','epic','mythic']
manifest=[]
print('EVALUATING MESHES',flush=True)
dg=bpy.context.evaluated_depsgraph_get();evaluated=[]
for name in names:
 for o in MODELS[name]:evaluated.append((name,o,bpy.data.meshes.new_from_object(o.evaluated_get(dg)),o.matrix_world.copy(),o.get('WheelCenterY'),{k:(list(v) if k=='WheelPivot' else v) for k,v in o.items()}))
for name in names:MODELS[name]=[]
for name,old,me,matrix,wheelY,attrs in evaluated:
 label=old.name;bpy.data.objects.remove(old,do_unlink=True);o=bpy.data.objects.new(label,me);o.matrix_world=matrix;bpy.data.collections[name].objects.link(o);MODELS[name].append(o)
 for k,v in attrs.items():o[k]=v
def lengthened(o,p):
 p=p.copy();cy=o.get('WheelCenterY');p.y=p.y*1.15 if cy is None else p.y+cy*.15;return p
for index,name in enumerate(names):
 print('EXPORTING',name,flush=True)
 objects=MODELS[name]
 points=[lengthened(o,o.matrix_world@Vector(p))for o in objects for p in o.bound_box];lo=Vector([min(p[i]for p in points)for i in range(3)]);hi=Vector([max(p[i]for p in points)for i in range(3)]);center=(lo+hi)/2
 desired=Vector((targets[index][0],targets[index][2],targets[index][1]));factor=Vector([desired[i]/(hi[i]-lo[i])for i in range(3)])
 # Bake each axis into geometry to keep the user's full width/height/length bounds.
 for o in objects:
  for v in o.data.vertices:
   p=lengthened(o,o.matrix_world@v.co)-center;v.co=Vector([p[i]*factor[i]for i in range(3)])
   if 'WheelPivot' in o:
    wp=Vector(o['WheelPivot']);wp.y*=1.15;wp-=center
    radial=min(factor.y,factor.z)
    v.co.y=wp.y*factor.y+(p.y-wp.y)*radial
    v.co.z=wp.z*factor.z+(p.z-wp.z)*radial
  if 'WheelPivot' in o:
   wp=Vector(o['WheelPivot']);wp.y*=1.15;wp-=center
   o['ExportWheelPivot']=[wp.x*factor.x,wp.z*factor.z,-wp.y*factor.y]
   o['ExportWheelRadius']=o['WheelRadius']*min(factor.y,factor.z)
  o.matrix_world.identity();o.data.update()
 bpy.context.view_layer.update()
 points=[v.co for ob in objects for v in ob.data.vertices]
 actual_lo=Vector([min(v[i]for v in points)for i in range(3)]);actual_hi=Vector([max(v[i]for v in points)for i in range(3)])
 correction=(actual_lo+actual_hi)/2;extent=actual_hi-actual_lo
 targets[index]=(extent.x,extent.z,extent.y)
 for ob in objects:
  for v in ob.data.vertices:v.co-=correction
  if 'ExportWheelPivot' in ob:
   q=ob['ExportWheelPivot'];ob['ExportWheelPivot']=[q[0]-correction.x,q[1]-correction.z,q[2]+correction.y]
  ob.data.update()
 groups={};counters=defaultdict(int)
 for o in objects:
  ma=o.data.materials[0].name;me=o.data;me.calc_loop_triangles();bucket=ma+'_'+o.get('WheelId','Body');key=f'{bucket}_{counters[bucket]}'
  if key in groups and len(groups[key]['triangles'])+len(me.loop_triangles)>18000:counters[bucket]+=1;key=f'{bucket}_{counters[bucket]}'
  if key not in groups:groups[key]={'name':key,'material':META[ma],'vertices':[],'normals':[],'triangles':[],'components':[]}
  g=groups[key];g['components'].append(o.name);lookup={}
  if 'WheelId' in o:g['wheel']={'id':o['WheelId'],'pivot':list(o['ExportWheelPivot']),'radius':o['ExportWheelRadius']}
  for tri in me.loop_triangles:
   positions=[me.vertices[i].co for i in tri.vertices];faceNormal=(positions[1]-positions[0]).cross(positions[2]-positions[0])
   if faceNormal.length<1e-10:continue
   faceNormal.normalize()
   ids=[]
   for li in tri.loops:
    v=me.vertices[me.loops[li].vertex_index].co;n=me.corner_normals[li].vector.normalized()
    if n.length<.5:n=faceNormal
    vp=tuple(round(a,5)for a in (v.x,v.z,-v.y));np=tuple(round(a,5)for a in (n.x,n.z,-n.y));k=vp+np
    if k not in lookup:lookup[k]=len(g['vertices']);g['vertices'].append(vp);g['normals'].append(np)
    ids.append(lookup[k])
   if len(set(ids))==3:g['triangles'].append(ids)
 data={'name':name,'displayName':'Scrap Kart' if index==0 else name,'rarity':rarities[index],'targetSize':targets[index],'parts':list(groups.values()),'authoredComponents':len(objects),'noseAxis':'+Z'}
 file=name.replace(' ','_')+'.json';(OUT/file).write_text(json.dumps(data,separators=(',',':')))
 manifest.append({'name':name,'file':file,'size':targets[index],'components':len(objects),'parts':len(groups),'triangles':sum(len(g['triangles'])for g in groups.values())})
 for o in objects:o.location+=Vector(((index%4)*8,(index//4)*9,0))
(OUT/'manifest.json').write_text(json.dumps(manifest,indent=2))
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'Junkyard-Seven-Base-Cars.blend'))
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=32;scene.render.resolution_x=900;scene.render.resolution_y=700;scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('Studio');scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.14,.17,.20,1);scene.view_settings.view_transform='AgX'
bpy.ops.object.camera_add();cam=bpy.context.object;scene.camera=cam;cam.data.type='ORTHO'
lights=[];settings=[((3,-5,7),1400,5),((-5,-2,4),950,5),((2,5,7),1700,4)]
for loc,power,size in settings:
 bpy.ops.object.light_add(type='AREA');o=bpy.context.object;o.data.energy=power;o.data.shape='DISK';o.data.size=size;lights.append(o)
for index,name in enumerate(names):
 for n in names:bpy.data.collections[n].hide_render=n!=name
 center=Vector(((index%4)*8,(index//4)*9,0));cam.data.ortho_scale=max(targets[index])*1.5;cam.location=center+Vector((6,-9,5));cam.rotation_euler=(center-cam.location).to_track_quat('-Z','Y').to_euler()
 for o,(loc,power,size)in zip(lights,settings):o.location=center+Vector(loc);o.rotation_euler=(center-o.location).to_track_quat('-Z','Y').to_euler()
 scene.render.filepath=str(OUT/(name.replace(' ','_')+'.png'));bpy.ops.render.render(write_still=True)
print('SEVEN_BASE_CARS_COMPLETE')
