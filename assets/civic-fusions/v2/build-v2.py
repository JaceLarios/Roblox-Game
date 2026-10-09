import sys,math,json,re
from pathlib import Path
ROOT=Path(__file__).resolve().parent.parent
source=(ROOT/'build-civics.py').read_text()
# Reuse the existing clean Civic and detailed addon tools; preserve the original batch.
__file__=str(ROOT/'build-civics.py')
exec(compile(source[:source.index('start=int')],__file__,'exec'),globals())
P=ROOT/'v2'
old_mechanical=mechanical
old_phantom=phantom
old_engine=engine
plans[16]='Paired roof lantern bar with bolted roof feet and ghost-lit sill trim'
plans[18]='Roof observatory crystal in a gold socket, leaving the Civic hood clean'
plans[27]='Exposed rear-quarter soul turbo, gold side charge pipe and subtle hatch lip'
plans[30]='Ghost driver visible through lighter cabin glass, with a flush formed rear moonroof'

plans[:16]=[
'Rear hatch nitrous cassette with twin visible bottles, bridge clamps, gauge and sill delivery lines',
'Sky-high rear-exit chrome straight pipes with hollow heat-blued tips, braces and a compact hatch ducktail',
'Large exposed passenger-side turbo beside the front wheel, charge pipes and front intercooler',
'Low four-cylinder club racer with four hood trumpets, front cooling slots and compact rear lip',
'Transverse rear rotary installation exposed through the hatch, framed cradle and twin short exhausts',
'Rear bumper delete with twin exposed rear-facing turbos, tubular mounts and polished charge piping feeding the rear engine',
'V6 tucked under a transparent hood engine window, subtle touring aero and front cooling ducts',
'Tall hood-mounted roots blower, chunky drag slicks, side headers and a clean wingless rear',
'Diesel utility hatch with stacks behind the doors, protected engine bay and reinforced sill steps',
'Rear-hatch V8 drag conversion with eight trumpets, cage bracing, wide rear tires and wheelie rollers',
'Extended-nose V12 touring hatch with twelve red intakes, fender extraction gills and a low rear blade',
'Four fan pods extending from the wheel corners, articulated arms and an integrated front lift fairing',
'Central jet emerging through the rear hatch, roof-fed intake and visible rear afterburner',
'Twin longitudinal rocket nacelles flanking the hatch, integrated heat shields and rear fins',
'Reactor replacing rear seats beneath an opened roof-hatch section, safety cage and side power rails',
'Angled portal hoop framing the rear hatch, paired induction coils along the rocker panels']

# Additional tailored surfaces are real mesh geometry, with rounded machined edges.
def shell(name,verts,faces,mat,bevel=.009):
 mesh=bpy.data.meshes.new(name);mesh.from_pydata(verts,[],faces);mesh.update();ob=bpy.data.objects.new(name,mesh);COL.objects.link(ob);mesh.materials.append(mat)
 if bevel:
  mod=ob.modifiers.new('Soft machined perimeter','BEVEL');mod.width=bevel;mod.segments=2
  ob.modifiers.new('Surface normals','WEIGHTED_NORMAL')
 return ob

def wing(kind='lip'):
 if kind=='lip':
  # Follows the Civic hatch edge instead of a generic tall racing plank.
  shell('Contoured hatch ducktail',[(-.73,1.57,.91),(-.62,1.78,.85),(0,1.83,.83),(.62,1.78,.85),(.73,1.57,.91),(-.73,1.61,1.02),(-.62,1.82,.96),(0,1.87,.94),(.62,1.82,.96),(.73,1.61,1.02)],[(0,1,2,3,4),(5,6,7,8,9),(0,5,6,1),(1,6,7,2),(2,7,8,3),(3,8,9,4),(4,9,5,0)],ACC)
 else:
  for x in [-.53,.53]:
   pipe('Low aerodynamic wing mount',[(x,1.41,.95),(x,1.49,1.07),(x,1.66,1.10)],.024,CARBON)
  shell('Curved touring wing',[(-.85,1.49,1.12),(-.53,1.67,1.09),(0,1.73,1.075),(.53,1.67,1.09),(.85,1.49,1.12),(-.85,1.74,1.14),(-.53,1.89,1.11),(0,1.94,1.095),(.53,1.89,1.11),(.85,1.74,1.14)],[(0,1,6,5),(1,2,7,6),(2,3,8,7),(3,4,9,8)],CARBON)

def vents(side,y,z,count=5):
 for k in range(count):
  ob=box('Recessed quarter extraction gill',(side*.807,y+k*.055,z),(.025,.028,.15),DARK,.004);ob.rotation_euler.x=-.22

def diffuser(width=1.2):
 box('Rear diffuser tray',(0,1.75,.11),(width,.30,.035),CARBON,.015)
 for xx in [-.48,-.24,0,.24,.48]:
  shell('Rear diffuser swept fin',[(xx-.008,1.59,.12),(xx-.008,1.97,.18),(xx-.008,1.93,.04),(xx+.008,1.59,.12),(xx+.008,1.97,.18),(xx+.008,1.93,.04)],[(0,1,2),(3,5,4),(0,3,4,1),(1,4,5,2),(2,5,3,0)],CARBON,.004)

def widen_rear(factor=1.23):
 for ob in bpy.data.objects:
  if ob.name in ['Wheel_RL','Wheel_RR']:
   # Mesh imported with baked axes: scale in world X around its own bounding center.
   ob.data=ob.data.copy();world=ob.matrix_world;inv=world.inverted();pts=[world@v.co for v in ob.data.vertices];cx=(min(p.x for p in pts)+max(p.x for p in pts))/2
   for v in ob.data.vertices:
    p=world@v.co;p.x=cx+(p.x-cx)*factor+(.07 if cx>0 else -.07);v.co=inv@p
 for side in [-1,1]:
  pts=[(side*.895,1.237+.414*math.cos(a),.291+.414*math.sin(a))for a in [k*math.pi/20 for k in range(21)]]
  pipe('Body-color rear arch lip',pts,.035,ACC)

def frame_bay(y,length,width=.92,z=.82):
 rear=min(1.65,y+length/2);front=y-length/2
 floor=z-.07
 opening((0,(front+rear)/2,(floor+2.4)/2),(width,rear-front,2.4-floor))
 for side in [-1,1]:
  pipe('Exposed engine perimeter rail',[(side*width/2,y-length/2,z),(side*width/2,y,z+.15),(side*width/2,y+length/2,z)],.028,CHROME)
 box('Engine compartment rear wall',(0,y-length/2+.035,z+.04),(width,.06,.28),CARBON)

# Flat white highlights are used only in the studio lights; the vehicle materials stay clean.
def aero(i):
 if i in [1,2,3,4]:wing('lip')
 if i in [6,10]:wing('touring')
 if i in [2,3,4,5,6,7,9,10,11,12,13,14,15]:
  for side in [-1,1]:
   shell('Sculpted rocker extension',[(side*.735,-.79,.19),(side*.82,-.65,.12),(side*.88,.60,.13),(side*.76,.84,.22),(side*.74,-.79,.22),(side*.82,-.65,.16),(side*.88,.60,.17),(side*.76,.84,.25)],[(0,1,2,3),(4,7,6,5),(0,4,5,1),(1,5,6,2),(2,6,7,3)],CARBON if i>=5 else ACC)
 if i in [6,10,12,13,14,15]:diffuser()
 if i in [7,9,13]:widen_rear()
 if i in [3,6,7,10]:box('Front fitted chin',(0,-1.99,.155),(1.43,.16,.045),CARBON,.017)

def compact_engine(cylinders,y,z,length=.69):
 banks=1 if cylinders==4 else 2;per=cylinders//banks
 box('Fused engine cast block',(0,y,z),(.60,length,.26),DARK)
 for side in ([0]if banks==1 else[-1,1]):
  x=side*.19;box('Engine valve bank',(x,y,z+.19),(.22,length*.93,.11),ACC)
  for k in range(per):
   yy=y-length*.39+k*length*.78/max(per-1,1)
   cyl('Bellmouth intake',(x,yy,z+.22),(x,yy,z+.38),.044,CHROME,r2=.061);tor('Intake rolled lip',(x,yy,z+.38),.060,.008,CHROME)
   cyl('Intake dark bore',(x,yy,z+.37),(x,yy,z+.382),.05,DARK)
   pipe('Swept engine header',[(x,yy,z+.1),(side*.38 if side else .38,yy,z-.06),(side*.47 if side else .47,yy+.10,z-.11)],.025,CHROME)
  for yy in [y-length*.41,y+length*.41]:
   for dx in [-.07,.07]:cyl('Valve cover bolt',(x+dx,yy,z+.245),(x+dx,yy,z+.26),.011,CHROME,n=6)

def turbo_pod(side,y,z,r=.19):
 x=side*.91
 # Rounded volute housing, hollow inlet, individually swept compressor vanes.
 verts=[];faces=[];segments=54;cross=12
 for j in range(segments+1):
  u=j/segments;a=-.25+u*math.tau;radius=r*(.74+.26*u);tube=.035+.06*u
  for k in range(cross):
   b=k*math.tau/cross;rr=radius+tube*math.cos(b)
   verts.append((x+side*tube*math.sin(b),y+rr*math.cos(a),z+rr*math.sin(a)))
 for j in range(segments):
  for k in range(cross):faces.append((j*cross+k,j*cross+(k+1)%cross,(j+1)*cross+(k+1)%cross,(j+1)*cross+k))
 casing=shell('Tapered cast turbo snail housing',verts,faces,CHROME,0)
 for face in casing.data.polygons:face.use_smooth=True
 cyl('Turbo dark compressor recess',(x+side*.055,y,z),(x+side*.074,y,z),r*.83,DARK)
 tor('Polished turbo inlet lip',(x+side*.09,y,z),r*.84,.017,CHROME,(side,0,0))
 cyl('Turbo impeller hub',(x+side*.075,y,z),(x+side*.095,y,z),.034,CHROME)
 for k in range(11):
  a=k*math.tau/11
  pipe('Turbo swept impeller vane',[(x+side*.087,y+.045*math.cos(a),z+.045*math.sin(a)),(x+side*.094,y+r*.7*math.cos(a+.33),z+r*.7*math.sin(a+.33))],.009,CHROME)
 for k in range(8):
  a=k*math.tau/8;cyl('Turbo housing flange bolt',(x+side*.07,y+r*math.cos(a),z+r*math.sin(a)),(x+side*.088,y+r*math.cos(a),z+r*math.sin(a)),.014,GOLD,n=6)
 pipe('Turbo scroll outlet',[(x,y,z+r),(x,y-.2,z+r),(side*.66,y-.33,z+.08)],.055,CHROME)
 cyl('Turbo turbine exhaust side',(side*.77,y,z),(side*.69,y,z),r*.70,DARK)
 pipe('Turbo charge plumbing',[(x,y-.2,z+r),(side*.60,y-.35,z+.15),(side*.34,y-.25,z-.06)],.037,CHROME)
 box('Turbo mounting saddle',(side*.78,y,z-.16),(.19,.22,.10),CARBON)


def delete_rear_bumper():
 body=bpy.data.objects['Honda_Civic_Body'];body.data=body.data.copy();bm=bmesh.new();bm.from_mesh(body.data);remaining=set(bm.verts);remove=set();cover_count=0
 while remaining:
  v=remaining.pop();stack=[v];group={v}
  while stack:
   v=stack.pop()
   for e in v.link_edges:
    w=e.other_vert(v)
    if w in remaining:remaining.remove(w);group.add(w);stack.append(w)
  ps=[body.matrix_world@v.co for v in group];lo=[min(p[i]for p in ps)for i in range(3)];hi=[max(p[i]for p in ps)for i in range(3)]
  if lo[1]>1.34 and hi[2]<.615:
   remove.update(group)
   if hi[0]-lo[0]>1.5 and len(group)>2000:cover_count+=1
 assert cover_count==1,('Expected single original rear bumper cover',cover_count)
 count=len(remove);bmesh.ops.delete(bm,geom=list(remove),context='VERTS');bm.to_mesh(body.data);bm.free();body.data.update()
 body['RearBumperDeleted']=True;body['RemovedBumperVertices']=count
 return count

def hollow_tip(name,a,b,r,inside,mat):
 a=Vector(a);b=Vector(b);axis=(b-a).normalized();u=axis.cross(Vector((1,0,0))).normalized();v=axis.cross(u);vs=[];faces=[];segments=40
 for center,radius in [(a,r),(b,r),(b,inside),(a,inside)]:
  for k in range(segments):
   p=center+radius*(u*math.cos(k*math.tau/segments)+v*math.sin(k*math.tau/segments));vs.append(tuple(p))
 for ring in range(4):
  for k in range(segments):faces.append((ring*segments+k,ring*segments+(k+1)%segments,((ring+1)%4)*segments+(k+1)%segments,((ring+1)%4)*segments+k))
 ob=shell(name,vs,faces,mat,0)
 for poly in ob.data.polygons:poly.use_smooth=True
 return ob

def rear_facing_turbo(x,z,r=.18):
 y=1.94;vs=[];fs=[];seg=64;cross=12
 for j in range(seg+1):
  t=j/seg;a=-.25+t*math.tau;radius=r*(.74+.26*t);tube=.025+.047*t
  for k in range(cross):
   b=k*math.tau/cross;rr=radius+tube*math.cos(b);vs.append((x+rr*math.cos(a),y+tube*math.sin(b),z+rr*math.sin(a)))
 for j in range(seg):
  for k in range(cross):fs.append((j*cross+k,j*cross+(k+1)%cross,(j+1)*cross+(k+1)%cross,(j+1)*cross+k))
 casing=shell('Rear turbo cast snail housing',vs,fs,CHROME,0)
 for poly in casing.data.polygons:poly.use_smooth=True
 hollow_tip('Rear turbo open velocity inlet',(x,y+.035,z),(x,y+.153,z),r*.83,r*.70,CHROME)
 cyl('Rear turbo dark impeller well',(x,y+.045,z),(x,y+.048,z),r*.70,DARK)
 cyl('Rear turbo impeller spindle',(x,y+.049,z),(x,y+.090,z),.030,CHROME)
 for k in range(12):
  a=k*math.tau/12
  pipe('Rear turbo curved impeller blade',[(x+.029*math.cos(a),y+.083,z+.029*math.sin(a)),(x+r*.62*math.cos(a+.27),y+.067,z+r*.62*math.sin(a+.27))],.008,CHROME)
 for k in range(7):
  a=k*math.tau/7;cyl('Rear turbo flange hex screw',(x+r*math.cos(a),y+.053,z+r*math.sin(a)),(x+r*math.cos(a),y+.070,z+r*math.sin(a)),.012,GOLD,n=6)
 cyl('Rear turbo turbine housing',(x,1.67,z),(x,1.86,z),r*.69,DARK)
 for yy in [1.71,1.78,1.85]:tor('Turbine housing cast rib',(x,yy,z),r*.70,.013,CHROME,(0,1,0))
 pipe('Turbo scroll tangential outlet',[(x+r*.80,y,z+r*.22),(x+r*.70,y-.08,z+r*.92),(x+.03,y-.22,z+.23)],.045,CHROME)


def mechanical(i):
 if i==0:
  frame_bay(1.25,.89,.83,.82)
  BLUE=material('Nitrous blue anodized aluminum',(.012,.13,.65),.7,.2)
  for side in [-1,1]:
   x=side*.20;z=.91
   cyl('Rear-hatch nitrous bottle',(x,.91,z),(x,1.54,z),.13,BLUE)
   cyl('Bottle rounded end',(x,1.54,z),(x,1.61,z),.13,CHROME,r2=.04)
   cyl('Bottle valve',(x,.89,z),(x,.81,z),.03,GOLD)
   for yy in [1.02,1.44]:tor('Nitrous saddle clamp',(x,yy,z),.133,.018,CHROME,(0,1,0))
   cyl('Nitrous gauge',(x,.88,z+.10),(x,.85,z+.10),.04,CHROME)
   pipe('Blue-pressure braided line',[(x,.83,z),(side*.52,.79,.76),(side*.79,.48,.24),(side*.80,-.75,.23)],.021,CHROME)
  pipe('Hatch bottle retention bar',[(-.45,1.09,.85),(-.45,1.09,1.12),(.45,1.09,1.12),(.45,1.09,.85)],.023,DARK)
 elif i==1:
  titanium=material('Blue violet heat-tinted titanium',(.025,.11,.42),.92,.19)
  purple=material('Violet exhaust heat transition',(.24,.06,.25),.92,.20)
  for side in [-1,1]:
   pipe('Sky-high rear straight pipe',[(side*.36,1.00,.24),(side*.49,1.62,.23),(side*.58,2.03,.27),(side*.62,2.23,.52),(side*.67,2.27,1.30),(side*.74,2.32,2.15)],.070,CHROME)
   start=Vector((side*.74,2.32,2.15));end=Vector((side*.766,2.339,2.46));direction=(end-start).normalized()
   hollow_tip('Sky pipe violet heat zone',start,start+(end-start)*.27,.070,.055,purple)
   hollow_tip('Sky pipe blue hollow outlet',start+(end-start)*.27,end,.070,.055,titanium)
   tor('Sky pipe rolled open rim',end,.064,.008,CHROME,direction)
   # A real interior wall leaves the top visibly open, never a capped cylinder.
   for t in [.20,.45]:
    yy=2.23+(2.32-2.23)*t;zz=.52+(2.15-.52)*t;xx=side*(.62+(.74-.62)*t)
    tor('Straight pipe polished brace clamp',(xx,yy,zz),.077,.012,CHROME,(0,0,1))
   pipe('Hatch-to-stack support brace',[(side*.57,1.75,.88),(side*.62,1.96,.88),(side*.65,2.25,.89)],.022,DARK)
   box('Stack brace mounting tab',(side*.57,1.74,.88),(.12,.035,.065),CHROME,.005)
   for dx in [-.039,.039]:cyl('Stack brace mounting screw',(side*.57+dx,1.758,.88),(side*.57+dx,1.770,.88),.008,GOLD,n=6)
  bpy.context.scene['ExhaustDesign']='Two rearward-exit pipes rise well above the roof; open heat-blued titanium tips'
 elif i==2:
  # One exposed snail at the passenger front sill, leaving the entire hood intact.
  turbo_pod(1,-.64,.55,.23)
  pipe('Turbo front intercooler feed',[(.70,-.91,.63),(.79,-1.66,.4),(.45,-2.055,.32)],.038,CHROME)
  box('Front-mounted intercooler',(0,-2.04,.34),(.74,.07,.16),CHROME,.008)
  for z in [.28,.31,.34,.37,.40]:box('Intercooler fin',(0,-2.082,z),(.66,.009,.01),DARK,.001)
  vents(-1,-.73,.57,4)
 elif i==3:
  old_engine(4)
  for side in [-1,1]:
   for k in range(3):box('Club racer hood extraction slot',(side*.55,-1.45+k*.11,.724),(.16,.029,.018),DARK,.006)
 elif i==4:
  frame_bay(1.18,1.07,.97,.79)
  imported('Rotary Engine',(0,1.22,.73),(.94,.86,.73),rotate=math.pi)
  for side in [-1,1]:
   pipe('Rotary cradle crossbrace',[(side*.43,.71,.91),(0,.81,1.07),(side*.43,1.65,.81)],.023,CHROME)
   cyl('Short rear rotary exhaust',(side*.4,1.55,.29),(side*.4,2.03,.29),.068,CHROME);cyl('Open rotary tailpipe',(side*.4,2.025,.29),(side*.4,2.04,.29),.055,DARK)
  vents(1,.7,.70,4);vents(-1,.7,.70,4)
 elif i==5:
  delete_rear_bumper()
  frame_bay(1.09,1.08,.81,.77);compact_engine(4,1.11,.68,.72)
  # Real bumper cover and lower trim removed at their original mesh seams.
  box('Exposed rear valance inner panel',(0,1.66,.46),(1.36,.05,.25),DARK,.015)
  pipe('Twin turbo tubular lower cradle',[(-.69,1.69,.24),(-.64,1.92,.17),(.64,1.92,.17),(.69,1.69,.24)],.028,CHROME)
  for side in [-1,1]:
   x=side*.43;z=.39;rear_facing_turbo(x,z,.18)
   pipe('Turbo chassis mounting diagonal',[(side*.67,1.65,.55),(side*.64,1.80,.35),(side*.48,1.94,.21)],.024,CHROME)
   box('Turbo chassis bolted mounting plate',(side*.67,1.64,.51),(.15,.045,.13),CHROME,.007)
   for dx in [-.045,.045]:
    for dz in [-.035,.035]:cyl('Turbo mount bolt',(side*.67+dx,1.669,.51+dz),(side*.67+dx,1.683,.51+dz),.009,GOLD,n=6)
   pipe('Rear engine turbine exhaust feed',[(side*.29,1.23,.72),(side*.56,1.42,.63),(side*.62,1.62,.42),(x,1.72,z)],.035,CHROME)
   pipe('Rear turbo polished charge pipe',[(x+.03,1.72,z+.23),(side*.33,1.57,.64),(side*.33,1.42,.91),(side*.09,1.11,.87)],.038,CHROME)
   cyl('Charge pipe blue silicone coupling',(side*.33,1.42,.79),(side*.33,1.42,.87),.046,ACC)
   for zz in [.795,.865]:tor('Charge-pipe stainless hose clamp',(side*.33,1.42,zz),.047,.007,CHROME)
  bpy.context.scene['RearBumperDelete']=True;bpy.context.scene['TurboPlacement']='Twin rear-facing turbochargers in deleted rear bumper opening'
 elif i==6:
  body=bpy.data.objects['Honda_Civic_Body'];mw=body.matrix_world;inv=mw.inverted()
  ys=[-1.64,-1.50,-1.3,-1.1,-.84];xs=[-.4,-.2,0,.2,.4];verts=[]
  for yy in ys:
   for xx in xs:
    hit,pt,n,idx=body.ray_cast(inv@Vector((xx,yy,2)),inv.to_3x3()@Vector((0,0,-1)))
    verts.append((xx,yy,(mw@pt).z+.014 if hit else .8))
  opening((0,-1.24,.75),(.76,.79,.50));compact_engine(6,-1.24,.27,.64)
  glass=material('Clear formed V6 hood window',(.5,.66,.7),0,.065);nodes=glass.node_tree.nodes;links=glass.node_tree.links;principled=nodes.get('Principled BSDF');principled.inputs['Transmission Weight'].default_value=.95
  transparent=nodes.new('ShaderNodeBsdfTransparent');mix=nodes.new('ShaderNodeMixShader');mix.inputs[0].default_value=.25;links.new(transparent.outputs[0],mix.inputs[1]);links.new(principled.outputs[0],mix.inputs[2]);links.new(mix.outputs[0],nodes.get('Material Output').inputs[0])
  faces=[(j*5+k,j*5+k+1,(j+1)*5+k+1,(j+1)*5+k)for j in range(4)for k in range(4)]
  ob=shell('Formed flush engine-glass hood',verts,faces,glass,0);solid=ob.modifiers.new('Hood glass thickness','SOLIDIFY');solid.thickness=.007
  border=[verts[k]for k in range(5)]+[verts[j*5+4]for j in range(1,5)]+[verts[20+k]for k in range(3,-1,-1)]+[verts[j*5]for j in range(3,-1,-1)]
  pipe('Flush carbon hood window seal',border,.014,CARBON)
  for side in [-1,1]:vents(side,-.7,.58,4)
 elif i==7:
  opening((0,-1.22,.77),(.78,.74,.52));imported('Supercharger',(0,-1.22,.56),(.84,.77,.87))
  for side in [-1,1]:
   for k in range(3):pipe('Drag header side pipe',[(side*.30,-1.10+k*.09,.52),(side*.61,-1.08+k*.09,.35),(side*.84,-.84+k*.08,.21)],.029,CHROME)
 elif i==8:
  opening((0,-1.29,.75),(.76,.68,.47));imported('Diesel Stack',(0,-1.29,.49),(.72,.68,.61))
  for side in [-1,1]:
   pipe('B-pillar diesel stack',[(side*.48,-.69,.33),(side*.89,-.43,.24),(side*.90,.39,.27),(side*.90,.48,1.47)],.061,CHROME)
   tor('Soot black stack mouth',(side*.90,.48,1.47),.061,.012,DARK)
   for z in [.62,.89,1.16]:tor('Diesel heat guard band',(side*.90,.48,z),.074,.013,DARK)
   box('Utility step',(side*.91,-.25,.145),(.19,1.01,.065),CARBON,.03)
  pipe('Front protective bumper tube',[(-.72,-2.06,.29),(-.70,-2.10,.47),(.70,-2.10,.47),(.72,-2.06,.29)],.032,DARK)
 elif i==9:
  frame_bay(1.13,1.27,1.00,.77);compact_engine(8,1.14,.79,.84)
  for side in [-1,1]:
   pipe('Rear V8 roll-cage brace',[(side*.43,.61,.85),(side*.45,.69,1.34),(side*.48,1.68,.74)],.032,CHROME)
   pipe('Drag wheelie bar',[(side*.43,1.64,.25),(side*.41,2.42,.12)],.024,CHROME)
   cyl('Wheelie roller',(side*.41-.05,2.42,.12),(side*.41+.05,2.42,.12),.09,DARK)
  pipe('Rear roll-cage bridge',[(-.45,.69,1.34),(0,.64,1.38),(.45,.69,1.34)],.032,CHROME)
 elif i==10:
  # Lengthen just the forward body and front wheels for a touring nose, retain Civic cabin.
  body=bpy.data.objects['Honda_Civic_Body'];body.data=body.data.copy();mw=body.matrix_world;inv=mw.inverted()
  for v in body.data.vertices:
   p=mw@v.co
   if p.y<-.8:p.y=-.8+(p.y+.8)*1.14
   v.co=inv@p
  for name in ['Wheel_FL','Wheel_FR']:
   ob=bpy.data.objects.get(name)
   if ob:ob.location.y-=.065
  opening((0,-1.39,.77),(.80,1.11,.50));imported('V12 Engine',(0,-1.37,.47),(.82,1.12,.65))
  for side in [-1,1]:vents(side,-.79,.57,5)
  for ob in COL.objects:
   if ob.name.startswith('Front fitted chin'):ob.location.y-=.17
 elif i==11:
  old_mechanical(i)
  for side in [-1,1]:
   for yy in [-1.25,1.23]:
    pipe('Articulated hover outrigger',[(side*.61,yy,.25),(side*.98,yy,.22),(side*1.03,yy,.21)],.055,CHROME)
  box('Hover nose lift controller',(0,-1.94,.34),(.48,.12,.12),CARBON,.03)
  for x in [-.17,0,.17]:box('Cyan hover intake slit',(x,-2.007,.34),(.08,.01,.028),GLOW,.005)
 elif i==12:
  frame_bay(1.19,1.4,.91,.79)
  z=.99
  cyl('Rear jet turbine core',(0,.53,z),(0,1.96,z),.25,CARBON)
  for yy in [.58,.81,1.16,1.55,1.85]:tor('Jet compression cage',(0,yy,z),.252,.028,CHROME,(0,1,0))
  cyl('Exposed afterburner flare',(0,1.94,z),(0,2.13,z),.26,DARK,r2=.31);tor('Blue afterburner perimeter',(0,2.13,z),.286,.017,GLOW,(0,1,0))
  cyl('Afterburner dark throat',(0,2.136,z),(0,2.14,z),.25,DARK)
  for k in range(12):
   a=k*math.tau/12;pipe('Afterburner flameholder blade',[(.09*math.cos(a),2.145,z+.09*math.sin(a)),(.23*math.cos(a+.18),2.145,z+.23*math.sin(a+.18))],.016,CHROME)
  pipe('Roof-fed turbine intake',[(0,.18,1.3),(0,.40,1.33),(0,.64,1.18)],.15,CARBON)
  tor('Roof intake bright lip',(0,.18,1.30),.152,.016,CHROME,(0,1,0))
  for side in [-1,1]:
   pipe('Jet cradle diagonal',[(side*.42,.59,.78),(side*.43,1.4,1.13),(side*.42,1.77,.72)],.028,CHROME)
 elif i==13:
  for side in [-1,1]:
   # Source nozzle points -Y; rotate 180 degrees so both rockets thrust rearward.
   imported('Rocket Booster',(side*.93,1.08,.63),(.62,1.65,.70),rotate=math.pi)
   pipe('Rocket curved chassis cradle',[(side*.71,.34,.67),(side*.97,.69,.65),(side*.97,1.63,.63),(side*.71,1.69,.65)],.031,CHROME)
   shell('Rocket quarter heatshield',[(side*.77,.36,.53),(side*.91,.55,.59),(side*1.01,1.58,.59),(side*.77,1.76,.58),(side*.79,.40,.68),(side*.94,.58,.70),(side*1.04,1.55,.70),(side*.79,1.70,.70)],[(0,1,2,3),(4,7,6,5),(1,5,6,2),(0,4,5,1),(2,6,7,3)],CARBON)
 elif i==14:
  frame_bay(.77,1.57,1.02,.83);imported('Fusion Core',(0,.77,.70),(1.05,1.00,1.20))
  for side in [-1,1]:
   pipe('Reactor structural roll hoop',[(side*.48,.20,.74),(side*.53,.32,1.37),(side*.50,1.2,1.44),(side*.48,1.58,.74)],.036,CHROME)
   pipe('Reactor sill energy cable',[(side*.38,.77,1.02),(side*.72,.52,.74),(side*.84,.18,.23),(side*.82,-1.24,.24)],.027,GLOW)
   for yy in [-.52,-.18,.16]:tor('Reactor sill cable coupling',(side*.84,yy,.23),.046,.012,CHROME,(0,1,0))
 elif i==15:
  old_mechanical(i)
  for side in [-1,1]:
   for yy in [-.4,0,.4]:
    tor('Rocker induction coil',(side*.85,yy,.29),.092,.018,CHROME,(0,1,0));tor('Rocker cyan coil',(side*.85,yy+.035,.29),.075,.012,GLOW,(0,1,0))

# Retain already varied Phantom placements, but make four more cases distinct from the old hood layout.
def phantom(i):
 j=i-16;name=names[i]
 if j==0:
  imported(name,(0,.06,1.28),(1.0,.29,.57),GHOST)
  for side in [-1,1]:
   box('Lantern rack bolted roof foot',(side*.13,.06,1.273),(.08,.12,.04),DARK,.008)
  plans[i]='Paired roof lantern bar with bolted roof feet and ghost-lit sill trim'
 elif j==2:
  imported(name,(0,-.15,1.26),(.50,.5,.59),GHOST)
  tor('Oracle roof socket',(0,-.15,1.27),.20,.025,GOLD)
  plans[i]='Roof observatory crystal in a gold socket, leaving the Civic hood clean'
 elif j==11:
  imported(name,(.89,.69,.59),(.65,.66,.78),GHOST,rotate=math.pi/2)
  pipe('Soul turbo side intake',[(.91,.69,.89),(.93,.17,.71),(.87,-.57,.29)],.042,GOLD)
  wing('lip')
  plans[i]='Exposed rear-quarter soul turbo, gold side charge pipe and subtle hatch lip'
 elif j==14:
  old_phantom(i)
  # Small moonroof follows the actual roof surface, fully behind the windshield.
  body=bpy.data.objects['Honda_Civic_Body'];mw=body.matrix_world;inv=mw.inverted();vs=[]
  xs=[-.32,0,.32];ys=[.23,.51,.79]
  for yy in ys:
   for xx in xs:
    hit,pt,n,idx=body.ray_cast(inv@Vector((xx,yy,2)),inv.to_3x3()@Vector((0,0,-1)))
    vs.append((xx,yy,(mw@pt).z+.007 if hit else 1.28))
  opening((0,.51,1.24),(.62,.54,.18))
  glass=material('Chauffeur clear formed moonroof',(.48,.74,.72),0,.05);p=glass.node_tree.nodes.get('Principled BSDF');p.inputs['Transmission Weight'].default_value=.94
  shell('Flush panoramic moonroof',vs,[(0,1,4,3),(1,2,5,4),(3,4,7,6),(4,5,8,7)],glass,0)
  pipe('Moonroof graphite rubber seal',[vs[k]for k in [0,1,2,5,8,7,6,3,0]],.009,DARK)
  plans[i]='Ghost driver visible through lighter cabin glass, with a flush formed rear moonroof'
 else:old_phantom(i)
 if j in [0,2,11]:
  for side in [-1,1]:pipe('Phantom sill glow',[(side*.78,-.76,.19),(side*.80,0,.17),(side*.79,.81,.20)],.012,GLOW)

# Run the original save pipeline with tailored views and fresh output names.
tail=source[source.index('start=int'):]
tail=tail.replace("s.view_settings.exposure=-.3","s.view_settings.exposure=-.65")
tail=tail.replace("s.cycles.samples=20","s.cycles.samples=24")
tail=tail.replace("s.render.filepath=str(P/(slug(addon)+'.png'))", "s.render.filepath=str(P/(slug(addon)+'.png'))\n if i in [0,1,4,5,9,12,13,14,15,17,20,22,23,24,29]:\n  c.location=(5,7,3.8);c.rotation_euler=(target-c.location).to_track_quat('-Z','Y').to_euler()\n if i==1:\n  c.location=(4.8,7,3.8);target=Vector((0,.3,1.1));c.rotation_euler=(target-c.location).to_track_quat('-Z','Y').to_euler();c.data.ortho_scale=5.9\n if i==5:\n  c.location=(4.8,7,2.8);target=Vector((0,.25,.6));c.rotation_euler=(target-c.location).to_track_quat('-Z','Y').to_euler()\n s['LayoutRevision']='Varied placement v2'")
tail=tail.replace("'gameIntegrated':False}","'gameIntegrated':False,'layoutRevision':'Varied placement v2'}")
exec(compile(tail,str(P/'build-v2.py'),'exec'),globals())
