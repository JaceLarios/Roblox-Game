import bpy,math,json,random,hashlib
from pathlib import Path
from mathutils import Vector,Matrix
from collections import defaultdict
OUT=Path(__file__).parent
reference=(OUT/'base-builder-reference.py').read_text()
prefix=reference[:reference.index('# 1. Stable Rusted Sedan')]
prefix=prefix.replace("OUT.parent.parent/'new-addons/v2/textures'","OUT.parent/'new-addons/textures'")
exec(prefix)
mat('Lemon','FFD52B','Enamel',.25,.3)
mat('Purple','A33BF0','Enamel',.3,.3)
mat('Copper','E39142','Brushed',.7,.4)
mat('Carbon','27323F','Carbon',.5,.36)
exec((OUT/'wheel_styles.py').read_text())
mat('Energy','43EAFF','Light',.2,.3,1.8)
designs=json.loads((OUT/'designs.json').read_text())
base=reference[reference.index("model('Rusted Sedan')"):reference.index('# 2. Narrow motocross')]
base=base.replace("model('Rusted Sedan')","model(spec['name'])")
base=base.replace("wheel(x,y,.50,.47,.34,'Orange',True)","wheel(x,y,.50,(.60 if y>0 else .40) if index==7 else .47,.42 if index==7 and y>0 else .34,'Orange',True)")
base=base.replace("arch(x,y,.50,.52,.41,'Turquoise')","arch(x,y,.50,(.66 if y>0 else .46) if index==7 else .52,.45 if index==7 else .41,'Turquoise')")

def hollow(name,a,b,r,ma='Chrome',inner='Iron'):
 a,b=Vector(a),Vector(b);v=(b-a).normalized();u=v.cross(Vector((1,0,0)) if abs(v.x)<.9 else Vector((0,1,0))).normalized();w=v.cross(u)
 vertices=[tuple(p+rr*(u*math.cos(j*math.tau/32)+w*math.sin(j*math.tau/32)))for p,rr in [(a,r),(b,r),(b,r*.79),(a,r*.79)]for j in range(32)]
 for k,m in [(0,ma),(1,ma),(2,inner)]:
  o=mesh(name,vertices,[(k*32+j,k*32+(j+1)%32,(k+1)*32+(j+1)%32,(k+1)*32+j)for j in range(32)],m)
  for f in o.data.polygons:f.use_smooth=True
 tor(name+' rolled lip',b,r*.91,r*.095,ma,v,32)

def engine_block(p=(0,-1.05,1.29),cylinders=4,color='Blue',length=.94):
 x,y,z=p
 box('Engine mounting cradle',(x,y,z-.255),(.88,length+.12,.13),'Steel',.035)
 for xx in [-.32,.32]:
  for yy in [-length*.32,length*.32]:box('Engine cradle support',(x+xx,y+yy,(z-.31+.48)/2),(.085,.09,max(.08,z-.79)),'Iron',.015)
 box('Cast engine block',p,(.70,length,.40),'Iron',.08)
 box('Engine gasket',(x,y,z+.22),(.74,length,.055),'Rubber',.015)
 rows=1 if cylinders==4 else 2;each=cylinders//rows
 for side in range(rows):
  xx=x+(side-.5)*.42 if rows==2 else x
  box('Colored cylinder bank',(xx,y,z+.34),(.31 if rows==2 else .66,length*.91,.20),'Carbon' if cylinders==12 else color,.055)
  for j in range(each):
   yy=y-length*.37+j*length*.74/max(1,each-1)
   hollow('Individual intake trumpet',(xx,yy,z+.43),(xx,yy,z+.62),.072,'Red' if cylinders==12 else 'Chrome')
   bolt((xx+.10,yy,z+.46),r=.019)
 for side in [-1,1]:
  for j in range(3):pipe('Swept engine header',[(x+side*.34,y-.3+j*.25,z),(x+side*.51,y-.2+j*.25,z-.16),(x+side*.50,y+.50,z-.24)],.025,'Titanium')
 cyl('Belt pulley',(x,y-length/2-.06,z),(x,y-length/2-.13,z),.16,'Chrome',n=24)
 tor('Alternator belt',(x,y-length/2-.14,z),.15,.028,'Rubber',(0,1,0),24)

def turbo(x,y,z,r=.27):
 tor('Turbo snail housing',(x,y,z),r,.10,'Steel',(0,1,0),32)
 hollow('Compressor intake',(x,y-.06,z),(x,y-.22,z),r*.62,'Chrome')
 cyl('Turbo center',(x,y-.15,z),(x,y-.19,z),.04,'Copper',n=16)
 for j in range(9):
  a=j*math.tau/9
  cyl('Compressor blade',(x,y-.17,z),(x+r*.50*math.cos(a),y-.19,z+r*.50*math.sin(a)),.012,'Chrome',n=6)
 pipe('Compressor outlet',[(x+r*.8,y,z),(x+r*1.1,y+.08,z+.2),(x+r*.4,y+.35,z+.27)],.07,'Chrome')
 for j in range(5):
  a=j*math.tau/5;bolt((x+r*math.cos(a),y-.11,z+r*math.sin(a)),(0,-1,0),.025)

def wing(y=1.72,width=2.25,height=1.55,ma='Carbon'):
 for x in [-.63,.63]:box('Wing upright',(x,y,(height+.69)/2),(.09,.14,height-.69),'Iron',.025)
 box('Rounded aero wing',(0,y,height),(width,.42,.095),ma,.04,rot=(-.1,0,0))
 for x in [-width/2,width/2]:box('Wing endplate',(x,y,height+.04),(.055,.47,.24),accent,.045)

def sill(width=1.10):
 for side in [-1,1]:
  loft('Sculpted sidepod',[( -.75, .14,.0,.13,.18),(.45,.20,.0,.20,.25),(.95,.13,.0,.13,.18)],accent).location=(side*width,0,.52)
  for y in [-.42,-.24,-.06]:box('Sidepod vent',(side*(width+.14),y,.66),(.035,.11,.12),'Black',.015)

def canopy(gt=False):
 front=-.52;back=.95;roofz=2.10 if gt else 1.99
 for side in [-1,1]:
  pipe('Cabin pillar seam',[(side*.77,front,1.10),(side*.64,-.22,roofz),(side*.67,back,roofz),(side*.80,1.15,1.01)],.042,paint)
 box('Curved cabin roof',(0,.35,roofz),(1.40,1.44,.11),paint,.10)
 quad('Panoramic windscreen',[(-.74,front,1.20),(.74,front,1.20),(.62,-.23,roofz-.03),(-.62,-.23,roofz-.03)],'Glass',True)
 if gt:
  for side in [-1,1]:quad('GT side glazing',[(side*.75,-.48,1.2),(side*.78,.91,1.2),(side*.65,.89,roofz-.03),(side*.65,-.20,roofz-.03)],'Glass',True)

def turbine(x,y,z,r=.43,length=1.1,rocket=False):
 cyl('Turbine armored barrel',(x,y-length/2,z),(x,y+length/2,z),r,'Steel',n=40)
 for yy in [y-length*.45,y,y+length*.44]:tor('Turbine reinforcement',(x,yy,z),r,.035,accent,(0,1,0),32)
 if rocket:
  cyl('Rocket combustion chamber',(x,y-.45,z),(x,y+.30,z),r*.78,paint,n=32)
  hollow('Rocket bell nozzle',(x,y+.30,z),(x,y+length*.78,z),r*1.1,'Titanium')
  tor('Rocket nozzle heat band',(x,y+length*.77,z),r*1.01,.035,'HeatBlue',(0,1,0),32)
 else:
  hollow('Jet intake mouth',(x,y-length*.54,z),(x,y-length*.68,z),r*1.04,'Chrome')
  for j in range(13):
   a=j*math.tau/13
   q=[(x+.06*math.cos(a),y-length*.68,z+.06*math.sin(a)),(x+r*.87*math.cos(a+.16),y-length*.67,z+r*.87*math.sin(a+.16)),(x+r*.87*math.cos(a+.38),y-length*.70,z+r*.87*math.sin(a+.38))]
   mesh('Jet fan blade',q,[(0,1,2)],'Chrome')
  cyl('Jet spinner',(x,y-length*.66,z),(x,y-length*.82,z),.13,'Iron',r2=.018,n=24)
  hollow('Jet afterburner outlet',(x,y+length*.50,z),(x,y+length*.70,z),r*.83,'Iron')
 tor('Engine energy rim',(x,y+length*.70,z),r*.73,.025,'Energy',(0,1,0),32)

def fin(x,y,z,ma,height=.65):
 pts=[(x,y-.35,z),(x,y+.42,z),(x,y+.35,z+height),(x,y+.10,z+height*.8)]
 o=quad('Sculpted tail fin',pts,ma);sol=o.modifiers.new('Fin thickness','SOLIDIFY');sol.thickness=.065;b=o.modifiers.new('Soft fin edges','BEVEL');b.width=.028;b.segments=3

def sphere(name,p,r,ma):
 verts=[];faces=[];N=24;K=12
 for k in range(K+1):
  theta=math.pi*k/K
  for j in range(N):a=math.tau*j/N;verts.append((p[0]+r*math.sin(theta)*math.cos(a),p[1]+r*math.sin(theta)*math.sin(a),p[2]+r*math.cos(theta)))
 for k in range(K):
  for j in range(N):faces.append((k*N+j,k*N+(j+1)%N,(k+1)*N+(j+1)%N,(k+1)*N+j))
 o=mesh(name,verts,faces,ma)
 for f in o.data.polygons:f.use_smooth=True

exec((OUT/'legendary_finish.py').read_text())
exec((OUT/'sedan_family.py').read_text())
base="build_sedan_variant(spec,index)"

for index,spec in enumerate(designs):
 paint=spec['color'];accent=spec['accent'];exec(base)
 # Keep the approved comfortable cockpit and wheel detail. The powertrain is rebuilt per recipe.
 remove=['Rear exposed engine','Engine cooling fin','Rear orange equipment box','Titanium exhaust','Dark hollow exhaust','Rolled titanium exhaust','Exhaust mounting clamp','Exhaust clamp mounting tab']
 exhaust_members=set(MODELS[current][exhaust_start:])
 for o in list(MODELS[current]):
  if o in exhaust_members or any(o.name.startswith(n) for n in remove):MODELS[current].remove(o);bpy.data.objects.remove(o,do_unlink=True)
 # Structural silhouettes: different noses, stances, fenders, roofs, and rear frames.
 stretch=1.0
 width=1.0
 bpy.context.view_layer.update()
 dg=bpy.context.evaluated_depsgraph_get()
 frozen=[(o,bpy.data.meshes.new_from_object(o.evaluated_get(dg)),o.matrix_world.copy(),{k:(list(v)if k=='WheelPivot' else v)for k,v in o.items()})for o in MODELS[current]]
 MODELS[current]=[]
 for old,me,matrix,attrs in frozen:
  # Bake base objects before smoothly extending the nose, preserving circular wheels.
  label=old.name;bpy.data.objects.remove(old,do_unlink=True);o=bpy.data.objects.new(label,me);bpy.data.collections[current].objects.link(o);MODELS[current].append(o)
  for k,v in attrs.items():o[k]=v
  wp=Vector(o['WheelPivot']) if 'WheelPivot' in o else None
  for v in me.vertices:
   q=matrix@v.co
   if wp is not None:
    q.x+=wp.x*(width-1)
    if wp.y<-.5:q.y+=(wp.y+.5)*(stretch-1)
   else:
    q.x*=width
    if q.y<-.5:q.y=-.5+(q.y+.5)*stretch
   v.co=q
  if wp is not None:
   wp.x*=width
   if wp.y<-.5:wp.y=-.5+(wp.y+.5)*stretch
   o['WheelPivot']=list(wp)
  o.matrix_world.identity();me.update()
 # Brackets and sill panels visually carry the extra machinery.
 box('Rear powertrain platform',(0,1.35,.70),(1.70*width,1.15,.15),'Iron',.07)
 for side in [-1,1]:
  pipe('Powertrain support tube',[(side*.66,.75,.50),(side*.78,1.77,.72)],.045,'Chrome')
 if index in [3,4,5,6,7,9,10,12,13,14]:sill(width)
 if index==0:
  # Exposed side bottles: visible beside the seat rather than buried behind it.
  for side in [-1,1]:
   x=side*.97
   box('Nitrous mounting saddle',(x,.16,.70),(.30,.88,.12),'Steel',.035)
   cyl('Blue nitrous bottle',(x,-.29,.91),(x,.54,.91),.17,'Blue',r2=.15,n=32)
   for y in [-.13,.36]:tor('Bottle retaining strap',(x,y,.91),.177,.023,'Chrome',(0,1,0),24)
   cyl('Nitrous valve',(x,-.29,.91),(x,-.43,.91),.049,'Gold',n=12)
   pipe('Braided nitrous hose',[(x,-.43,.91),(x,-.62,.99),(side*.64,-.84,1.13)],.024,'Blue')
  box('Patchwork hood plate',(.19,-1.40,1.15),(.45,.42,.035),'Orange',.02)
 elif index==1:
  # Pair of straight chrome pipes, bolt-on bracket and titanium heat bands.
  for side in [-1,1]:
   x=side*.98
   pipe('Long exhaust primary',[(side*.40,1.02,.83),(x,.60,.79),(x,.12,.79)],.07,'Chrome')
   hollow('Straight chrome exhaust',(x,.12,.79),(x,1.83,.79),.105,'Chrome')
   hollow('Blued straight pipe tip',(x,1.80,.79),(x,2.04,.79),.109,'HeatBlue')
   tor('Violet exhaust heat band',(x,1.79,.79),.11,.018,'HeatViolet',(0,1,0),24)
   box('Exhaust bolt-on bracket',(x,.55,.65),(.27,.25,.09),'Steel',.025)
   for yy in [.47,.63]:bolt((x,yy,.70),r=.025)
  box('Checker cowl strip',(0,-1.28,1.153),(1.04,.20,.024),'White',.01)
 elif index==2:
  # Scrapyard turbo on the bonnet, fully visible in the inventory camera.
  turbo(.12,-1.15,1.48,.30)
  box('Scrap turbo mounting foot',(.12,-1.12,1.18),(.63,.47,.13),'Rust',.04)
  pipe('Taped turbo feed',[(.38,-1.15,1.57),(.69,-1.05,1.51),(.69,-.63,1.26)],.087,'Rubber')
  for y,z in [(-.83,1.38),(-.76,1.34),(-.69,1.30)]:tor('Hose tape wrap',(.69,y,z),.09,.015,'Cream',(0,.85,-.5),24)
  box('Turbo welded patch',(-.09,-1.18,1.75),(.16,.16,.045),'Rust',.015)
  for x,z in [(-.12,1.62),(.32,1.65),(.30,1.30)]:bolt((x,-1.27,z),(0,-1,0),.030,'Copper')
  box('Rally undertray',(0,-1.80,.52),(1.40,.50,.15),'Steel',.04)
 elif index==3:
  engine_block((0,-1.24,1.30),4,'Blue',1.10);wing(1.65,2.15,1.35)
  for x in [-.49,.49]:box('Club hood stripe',(x,-1.18,1.157),(.11,.80,.018),'Lemon',.008)
 elif index==4:
  cyl('Rotary housing',(0,-1.25,1.46),(0,-1.62,1.46),.39,'Purple',n=40)
  tor('Rotor inspection window rim',(0,-1.64,1.46),.32,.045,'Chrome',(0,1,0),32)
  cyl('Dark rotor inspection cavity',(0,-1.642,1.46),(0,-1.653,1.46),.30,'Black',n=32)
  pts=[(.23*math.cos(j*math.tau/3),-1.68,1.46+.23*math.sin(j*math.tau/3))for j in range(3)]
  o=mesh('Visible triangular Wankel rotor',pts,[(0,1,2)],'Copper');o.modifiers.new('Rotor thickness','SOLIDIFY').thickness=.045
  cyl('Rotor eccentric shaft',(0,-1.69,1.46),(0,-1.73,1.46),.065,'Chrome',n=20)
  for x in [-.48,.48]:hollow('Rotary tuned exhaust',(x,1.40,.95),(x,1.95,.95),.11,'Titanium')
  wing(1.65,2.48,1.30)
 elif index==5:
  engine_block((0,-1.0,1.30),4,'Orange',.80)
  for x in [-.73,.73]:turbo(x,-1.20,1.39,.24)
  pipe('Polished crossover',[(-.73,-1.2,1.39),(-.59,-.75,1.83),(.59,-.75,1.83),(.73,-1.2,1.39)],.045,'Chrome')
  wing(1.76,2.65,1.49)
 elif index==6:
  engine_block((0,-1.40,1.34),6,'Red',.91);wing(1.8,2.52,1.68)
  for x in [-.80,.80]:box('Street bumper blade',(x,-2.21,.62),(.47,.37,.10),'Carbon',.035)
 elif index==7:
  engine_block((0,-1.53,1.34),8,'Gold',1.10)
  box('Roots blower case',(0,-1.53,2.02),(.77,.99,.37),'Chrome',.095)
  for j in range(6):box('Blower case rib',(0,-1.94+j*.16,2.04),(.81,.026,.31),'Steel',.01)
  loft('Oversized blower scoop',[(-2.08,.43,2.14,2.34,2.40),(-1.36,.32,2.14,2.26,2.30)],'Pink')
  box('Scoop intake throat',(0,-2.10,2.27),(.70,.025,.18),'Black',.045)
  cyl('Large blower pulley',(0,-2.10,1.94),(0,-2.17,1.94),.17,'Chrome')
  pipe('Blower drive belt',[(-.13,-2.18,1.41),(-.16,-2.18,1.94),(.16,-2.18,1.94),(.13,-2.18,1.41),(-.13,-2.18,1.41)],.029,'Rubber')
  wing(1.85,2.53,1.70)
  for side in [-1,1]:pipe('Drag wheelie bar',[(side*.45,1.5,.48),(side*.40,2.35,.30)],.04,'Chrome')
 elif index==8:
  engine_block((0,-1.13,1.33),6,'Copper',.95)
  for side in [-1,1]:
   pipe('Diesel stack elbow',[(side*.50,1.30,.84),(side*.91,1.30,1.00),(side*.91,1.27,1.49)],.105,'Steel')
   hollow('Tall truck smokestack',(side*.91,1.27,1.49),(side*.91,1.27,2.37),.13,'Chrome')
   hollow('Soot black stack tip',(side*.91,1.27,2.25),(side*.91,1.27,2.40),.135,'Iron')
   box('Industrial side toolbox',(side*1.03,.32,.77),(.30,.85,.40),'Copper',.045)
   for y in [-.05,.12,.29]:box('Hazard toolbox stripe',(side*1.19,y,.77),(.018,.07,.30),'Lemon',.009)
 elif index==9:
  engine_block((0,-1.30,1.39),8,'Red',1.05);wing(1.82,2.80,1.83)
  loft('Pointed track splitter',[(-2.37,.49,.45,.50,.55),(-1.96,1.25,.45,.53,.58)],'Carbon')
  for side in [-1,1]:
   fin(side*1.0,1.44,.88,'Red',.42)
   for y in [-1.30,-1.09,-.88]:box('Track hood louver',(side*.69,y,1.158),(.30,.08,.055),'Carbon',.016)
 elif index==10:
  box('Extended V12 rear cradle',(0,2.17,.65),(1.62,1.54,.16),'Iron',.05)
  for x in [-.62,.62]:pipe('V12 cradle chassis brace',[(x,.98,.48),(x,2.80,.56)],.065,'Chrome')
  engine_block((0,1.91,1.03),12,'Purple',1.46)
  wing(2.78,2.10,1.58,'Cream')
  for side in [-1,1]:pipe('GT chrome waistline',[(side*.98,-1.85,1.07),(side*.95,.7,1.11),(side*.94,1.86,1.01)],.022,'Chrome')
 elif index==11:
  for o in list(MODELS[current]):
   if 'WheelPivot' in o or any(o.name.startswith(n)for n in ['Brake caliper','Sculpted open wheel arch','Axle tube','Differential housing']):MODELS[current].remove(o);bpy.data.objects.remove(o,do_unlink=True)
  box('Hover hull',(0,.05,.39),(2.13,3.6,.40),'Purple',.18)
  for x in [-1.33,1.33]:
   for y in [-1.13,1.20]:
    cyl('Fan mounting arm',(x*.55,y,.61),(x,y,.61),.10,'Iron')
    hollow('Ducted hover fan',(x,y,.44),(x,y,.77),.46,'Turquoise')
    tor('Cyan fan safety ring',(x,y,.78),.43,.025,'Energy',(0,0,1),32)
    cyl('Hover fan hub',(x,y,.52),(x,y,.76),.095,'Copper',n=24)
    for j in range(7):
     a=j*math.tau/7;pts=[(x+.10*math.cos(a),y+.10*math.sin(a),.66),(x+.37*math.cos(a+.15),y+.37*math.sin(a+.15),.66),(x+.36*math.cos(a+.48),y+.36*math.sin(a+.48),.69)]
     mesh('Cyan fan rotor blade',pts,[(0,1,2)],'Energy')
  wing(1.70,1.65,1.37,'Purple')
 elif index==12:
  turbine(0,2.12,1.81,.64,1.55)
  box('Wing attachment spar',(0,1.45,.83),(2.48,.19,.16),'Steel',.04)
  for x in [-.40,.40]:
   box('Jet cradle rail',(x,2.05,.82),(.16,1.90,.20),'Iron',.035)
   for y in [1.65,2.45]:box('Jet saddle bracket',(x,y,1.09),(.16,.22,.46),'Steel',.025)
  for side in [-1,1]:
   pts=[(side*.7,.47,.81),(side*1.72,1.65,.73),(side*1.71,1.96,.73),(side*.66,1.58,.92)]
   o=quad('Swept jet wing',pts,'Blue');o.modifiers.new('Wing thickness','SOLIDIFY').thickness=.085
   fin(side*1.15,1.65,.85,'Orange',.65)
 elif index==13:
  for side in [-1,1]:
   turbine(side*1.02,1.96,1.48,.39,1.40,True);fin(side*1.02,2.06,1.79,'Cream',.78)
   for j in range(6):tor('Rocket hazard band',(side*1.02,1.65+j*.055,1.48),.395,.027,'Lemon' if j%2==0 else 'Black',(0,1,0),32)
  box('Rocket nose bumper accent',(0,-2.06,.63),(1.30,.13,.11),'Cream',.04)
  for x in [-.27,.27]:box('Retro ivory racing stripe',(x,-1.15,1.163),(.10,.82,.023),'Cream',.012)
 elif index==14:
  sphere('Plasma reactor sphere',(0,1.86,1.69),.63,'Energy')
  for axis in [(1,0,0),(0,1,0),(0,0,1)]:tor('Scrap reactor containment ring',(0,1.86,1.69),.71,.055,'Iron',axis,40)
  tor('Reactor bright equator',(0,1.86,1.69),.66,.025,'Purple',(0,0,1),40)
  for side in [-1,1]:
   box('Reactor support pedestal',(side*.43,1.86,1.02),(.16,.55,.72),'Copper',.03)
   pipe('Plasma power conduit',[(side*.43,1.86,1.55),(side*.91,1.1,1.24),(side*.97,.3,.74),(side*.65,-1.2,1.12)],.05,'Purple')
   pipe('Glowing conduit core',[(side*.55,1.86,1.56),(side*.94,.9,1.14),(side*.98,.2,.81)],.023,'Energy')
   fin(side*1.12,1.5,.92,'Purple',.55)
  for j in range(3):box('Reactor armored hood',(0,-1.48+j*.27,1.17),(1.40-j*.08,.24,.08),'Green',.035)
 if index>=12:legendary_finish(index,paint,accent)
 # A few crisp fasteners and inset accent panels; keep wear readable at collectible size.
 for side in [-1,1]:
  box('Side armor insert',(side*width*.96,.12,.64),(.05,.71,.20),accent,.025)
  for y in [-.16,.37]:bolt((side*width,.0+y,.66),(side,0,0),.025)
 spec['components']=len(MODELS[current])

print('EVALUATING FUSION MODELS',flush=True)
bpy.context.view_layer.update();dg=bpy.context.evaluated_depsgraph_get();evaluated=[]
for name,objects in MODELS.items():
 for o in objects:evaluated.append((name,o,bpy.data.meshes.new_from_object(o.evaluated_get(dg)),o.matrix_world.copy(),{k:(list(v)if k=='WheelPivot' else v)for k,v in o.items()}))
for name in MODELS:MODELS[name]=[]
for name,old,me,matrix,attrs in evaluated:
 label=old.name;bpy.data.objects.remove(old,do_unlink=True);o=bpy.data.objects.new(label,me);bpy.data.collections[name].objects.link(o);MODELS[name].append(o)
 for v in me.vertices:v.co=matrix@v.co
 for k,v in attrs.items():o[k]=v
 me.update()

# Broadening the complete assembly keeps all addon mounts aligned.
# Axle-direction width changes only; wheel radius and circular rolling profile stay intact.
for name,objects in MODELS.items():
 for o in objects:
  for v in o.data.vertices:v.co.x*=1.12
  if 'WheelPivot' in o:
   wp=list(o['WheelPivot']);wp[0]*=1.12;o['WheelPivot']=wp
  o.data.update()
manifest=[]
for index,spec in enumerate(designs):
 name=spec['name'];objects=MODELS[name];points=[v.co for o in objects for v in o.data.vertices]
 lo=Vector([min(v[i]for v in points)for i in range(3)]);hi=Vector([max(v[i]for v in points)for i in range(3)]);center=(lo+hi)/2
 scale=1.18;size=(hi-lo)*scale
 groups={};counters=defaultdict(int)
 for o in objects:
  for v in o.data.vertices:v.co=(v.co-center)*scale
  o.data.update();ma=o.data.materials[0].name;me=o.data;me.calc_loop_triangles();bucket=ma+'_'+o.get('WheelId','Body');key=f'{bucket}_{counters[bucket]}'
  if key in groups and len(groups[key]['triangles'])+len(me.loop_triangles)>18000:counters[bucket]+=1;key=f'{bucket}_{counters[bucket]}'
  if key not in groups:groups[key]={'name':key,'material':META[ma],'vertices':[],'normals':[],'triangles':[],'components':[]}
  g=groups[key];g['components'].append(o.name)
  if 'WheelPivot' in o:
   wp=(Vector(o['WheelPivot'])-center)*scale;g['wheel']={'id':o['WheelId'],'pivot':[wp.x,wp.z,-wp.y],'radius':o['WheelRadius']*scale}
  lookup={}
  for tri in me.loop_triangles:
   vv=[me.vertices[i].co for i in tri.vertices];normal=(vv[1]-vv[0]).cross(vv[2]-vv[0])
   if normal.length<1e-10:continue
   normal.normalize();ids=[]
   for li in tri.loops:
    v=me.vertices[me.loops[li].vertex_index].co;n=me.corner_normals[li].vector.normalized()
    if n.length<.5:n=normal
    vp=tuple(round(a,5)for a in (v.x,v.z,-v.y));np=tuple(round(a,5)for a in(n.x,n.z,-n.y));k=vp+np
    if k not in lookup:lookup[k]=len(g['vertices']);g['vertices'].append(vp);g['normals'].append(np)
    ids.append(lookup[k])
   if len(set(ids))==3:g['triangles'].append(ids)
 for g in groups.values():
  lo=[min(v[i]for v in g['vertices'])for i in range(3)];hi=[max(v[i]for v in g['vertices'])for i in range(3)];mid=[(a+b)/2 for a,b in zip(lo,hi)]
  centered=[[round(v[i]-mid[i],4)for i in range(3)]for v in g['vertices']]
  g['geometryHash']=hashlib.sha256(json.dumps([[[round(x,3)+0 for x in v]for v in centered],[[round(x,3)+0 for x in v]for v in g['normals']],g['triangles']],separators=(',',':')).encode()).hexdigest()
 data={'name':name,'displayName':name,'rarity':spec['rarity'],'addon':spec['addon'],'targetSize':[size.x,size.z,size.y],'parts':list(groups.values()),'authoredComponents':len(objects),'noseAxis':'+Z'}
 if name=='Reactor Rustbucket':
  ec=(Vector((0,1.86,1.69))-center)*scale;data['reactorEffectCenter']=[ec.x,ec.z,-ec.y]
 file=name.replace(' ','_')+'.json';(OUT/file).write_text(json.dumps(data,separators=(',',':')))
 manifest.append({'name':name,'file':file,'rarity':spec['rarity'],'size':data['targetSize'],'parts':len(groups),'triangles':sum(len(g['triangles'])for g in groups.values())})
 for o in objects:o.location=Vector((index%3*9,index//3*10,0))
(OUT/'manifest.json').write_text(json.dumps(manifest,indent=2))
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'Scrap-Kart-15-Fusions.blend'))
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=24;scene.render.resolution_x=900;scene.render.resolution_y=700;scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('Fusion showcase');scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.14,.17,.20,1);scene.view_settings.view_transform='AgX'
bpy.ops.object.camera_add();cam=bpy.context.object;scene.camera=cam;cam.data.type='ORTHO';lights=[];settings=[((3,-5,7),1500,5),((-5,-2,4),1000,5),((2,5,7),1600,4)]
for loc,power,size in settings:
 bpy.ops.object.light_add(type='AREA');o=bpy.context.object;o.data.energy=power;o.data.shape='DISK';o.data.size=size;lights.append(o)
for index,spec in enumerate(designs):
 name=spec['name']
 for n in MODELS:bpy.data.collections[n].hide_render=n!=name
 center=Vector((index%3*9,index//3*10,0));cam.data.ortho_scale=max(manifest[index]['size'])*1.5;cam.location=center+Vector((6,-9,5));cam.rotation_euler=(center-cam.location).to_track_quat('-Z','Y').to_euler()
 for o,(loc,power,size)in zip(lights,settings):o.location=center+Vector(loc);o.rotation_euler=(center-o.location).to_track_quat('-Z','Y').to_euler()
 scene.render.filepath=str(OUT/(name.replace(' ','_')+'.png'));bpy.ops.render.render(write_still=True)
print('FIFTEEN_FUSIONS_COMPLETE',flush=True)
