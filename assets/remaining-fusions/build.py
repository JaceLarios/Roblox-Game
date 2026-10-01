"""Remaining four vehicle families; individually packaged mechanical conversions."""
from pathlib import Path
import json, re
ROOT=Path(__file__).resolve().parent
A=ROOT.parent
template=(A/'warp-drive-batch/build_vehicles.py').read_text()
head=template[:template.index('manifest=[]')]
head=head.replace("(OUT/'geometry_helpers.py')","(OUT.parent/'warp-drive-batch/geometry_helpers.py')")
head=head.replace("(OUT/'base-inputs'", "(OUT.parent/'warp-drive-batch/base-inputs'")
exec(compile(head,str(ROOT/'helpers.py'),'exec'))
from mathutils import Euler
mat('Heat','71C8FF','Light',.1,.3,1.4)
mat('Violet','9C57F5','Brushed',.7,.3)
mat('Yellow','FFC62D','Enamel',.3,.3)
mat('Carbon','202933','Carbon',.55,.34)

def tube(label,a,b,r,ma='Chrome',segments=24):
 a,b=Vector(a),Vector(b);v=(b-a).normalized();u=v.cross(Vector((1,0,0))if abs(v.x)<.9 else Vector((0,1,0))).normalized();w=v.cross(u)
 vs=[tuple(c+rr*(u*math.cos(j*math.tau/segments)+w*math.sin(j*math.tau/segments)))for c,rr in [(a,r),(b,r),(b,r*.76),(a,r*.76)]for j in range(segments)]
 fs=[(k*segments+j,k*segments+(j+1)%segments,(k+1)*segments+(j+1)%segments,(k+1)*segments+j)for k in range(3)for j in range(segments)]
 o=mesh(label,vs,fs,ma)
 for f in o.data.polygons:f.use_smooth=True
 tor(label+' rolled edge',b,r*.88,r*.09,ma,v,n=segments)

def engine(p,cylinders=8,length=1.12):
 x,y,z=p
 box('Isolated engine cradle',(x,y,z-.22),(.9,length+.22,.13),'Iron',.04)
 box('Cast crankcase',(x,y,z),(.73,length,.42),'Steel',.075)
 banks=1 if cylinders==4 else 2
 for bank in range(banks):
  xx=x if banks==1 else x+(-.24 if bank==0 else .24)
  box('Sealed valve cover',(xx,y,z+.26),(.30 if banks==2 else .6,length*.95,.16),'Carbon'if cylinders==12 else accent,.05)
  for j in range(cylinders//banks):
   yy=y-length*.37+j*length*.74/max(1,cylinders//banks-1)
   tube('Individual intake trumpet',(xx,yy,z+.33),(xx,yy,z+.51),.073,'Red'if cylinders==12 else 'Chrome',16)
   bolt((xx+.105,yy,z+.35),r=.019)
 for side in [-1,1]:
  for j in range(4):
   yy=y-length*.33+j*length*.22
   pipe('Equal length exhaust runner',[(x+side*.35,yy,z+.10),(x+side*.53,yy,z-.10),(x+side*.54,y+length*.45,z-.28)],.042,'Titanium')
  cyl('Bolted engine foot',(x+side*.38,y-.3,z-.17),(x+side*.38,y-.3,z-.34),.07,'Rubber',n=12)
 cyl('Crank pulley',(x,y-length*.51,z),(x,y-length*.51-.1,z),.19,'Chrome',(None),24)

def turbo(p,scale=1):
 x,y,z=p;r=.27*scale
 tor('Exposed compressor snail',(x,y,z),r,.11*scale,'Steel',(0,1,0),24)
 tube('Compressor open inlet',(x,y-.06*scale,z),(x,y-.31*scale,z),.18*scale,'Chrome',24)
 cyl('Compressor spindle',(x,y-.16*scale,z),(x,y-.29*scale,z),.055*scale,'Titanium',n=16)
 for j in range(9):
  a=j*math.tau/9
  mesh('Curved compressor blade',[(x,y-.29*scale,z),(x+r*.55*math.cos(a),y-.27*scale,z+r*.55*math.sin(a)),(x+r*.55*math.cos(a+.36),y-.20*scale,z+r*.55*math.sin(a+.36))],[(0,1,2)],'Chrome')
 pipe('Turbo outlet elbow',[(x+r*.85,y,z),(x+r*1.5,y,z+.06),(x+r*1.6,y+.35*scale,z+.07)],.085*scale,'Titanium')
 for j in range(6):
  a=j*math.tau/6;bolt((x+r*math.cos(a),y-.11*scale,z+r*math.sin(a)),(0,-1,0),.026*scale)

def jet(p,r,length):
 x,y,z=p
 tube('Jet intake cowl',(x,y-length*.48,z),(x,y-length*.34,z),r,'Chrome')
 tube('Carbon turbine nacelle',(x,y-length*.35,z),(x,y+length*.26,z),r*.90,'Carbon')
 cyl('Intake spinner',(x,y-length*.40,z),(x,y-length*.53,z),r*.22,'Chrome',r2=.03)
 for j in range(12):
  a=j*math.tau/12
  mesh('Swept compressor fan',[(x+r*.20*math.cos(a),y-length*.40,z+r*.20*math.sin(a)),(x+r*.77*math.cos(a+.18),y-length*.36,z+r*.77*math.sin(a+.18)),(x+r*.75*math.cos(a+.43),y-length*.31,z+r*.75*math.sin(a+.43))],[(0,1,2)],'Titanium')
 tube('Afterburner throat',(x,y+length*.23,z),(x,y+length*.47,z),r*.74,'Iron')
 for j in range(10):
  a=j*math.tau/10
  verts=[(x+rr*math.cos(t),yy,z+rr*math.sin(t))for yy,rr in [(y+length*.21,r*.95),(y+length*.52,r*.69)]for t in [a,a+.49]]
  mesh('Overlapping nozzle petal',verts,[(0,1,3,2)],'Titanium')
 tor('Blue afterburner throat',(x,y+length*.40,z),r*.57,.035,'Heat',(0,1,0),24)
 for yy in [y-length*.25,y+length*.13]:
  tor('Nacelle clamp',(x,yy,z),r*.92,.035,'Chrome',(0,1,0),24)
  for side in [-1,1]:bolt((x+side*r*.88,yy,z),axis=(side,0,0),r=.03)

def fan(p,r):
 x,y,z=p
 tube('Ducted lift fan shroud',(x,y,z-.17),(x,y,z+.17),r,accent,32)
 tor('Fan luminous rim',(x,y,z+.17),r*.9,.027,'Heat',(0,0,1),32)
 cyl('Fan motor',(x,y,z-.09),(x,y,z+.11),r*.20,'Chrome',n=16)
 for j in range(9):
  a=j*math.tau/9
  mesh('Swept cyan lift blade',[(x+r*.2*math.cos(a),y+r*.2*math.sin(a),z),(x+r*.77*math.cos(a+.16),y+r*.77*math.sin(a+.16),z),(x+r*.77*math.cos(a+.48),y+r*.77*math.sin(a+.48),z+.065)],[(0,1,2)],'Heat')
 for side in [-1,1]:cyl('Lift fan protective brace',(x+side*r*.85,y,z+.21),(x,y,z+.21),.022,'Carbon',n=8)

def package_payload(addon,p,length,rotation=(0,0,0)):
 source=json.loads((A/'new-addons'/(addon.replace(' ','_')+'.json')).read_text())
 points=[Vector((x,-z,y))for g in source['parts']for x,y,z in g['vertices']]
 lo=Vector([min(v[i]for v in points)for i in range(3)]);hi=Vector([max(v[i]for v in points)for i in range(3)]);center=(lo+hi)/2;s=length/max(hi-lo);rot=Euler(rotation).to_matrix()
 for j,g in enumerate(source['parts']):
  ma=addon+str(j);m=g['material'];mt=bpy.data.materials.new(ma);mt.use_nodes=True;bs=mt.node_tree.nodes.get('Principled BSDF');bs.inputs['Base Color'].default_value=(*m['color'],1);bs.inputs['Metallic'].default_value=m.get('metal',.3);bs.inputs['Roughness'].default_value=.38
  M[ma]=mt;META[ma]={**m,'finish':m.get('finish','Light'if m.get('glow',0)else'Brushed'if m.get('metal',0)>.7 else'Enamel')}
  o=mesh('Integrated '+g['name'],[tuple(Vector(p)+rot@((Vector((x,-z,y))-center)*s))for x,y,z in g['vertices']],g['triangles'],ma)
  for f in o.data.polygons:f.use_smooth=True
  o.data.normals_split_custom_set_from_vertices([tuple(rot@Vector((x,-z,y)))for x,y,z in g['normals']])

status=json.loads((A.parent/'docs/model-production-status.json').read_text())
priority=['Jet Engine','V12 Engine','Hover Fans','V8 Engine','Supercharger','Diesel Stack','V6 Engine','Rotary Engine','Twin Turbo','Inline 4','Straight Pipes','Scrap Turbo','Nitrous Tank']
specs=[]
for item in status['items']:
 if item['section'].split(':')[0]not in ['Muscle Car','Cop Cruiser','Box Truck','Monster Truck']:continue
 if item['status'].startswith('installed'):continue
 addon=next((a for a in priority if '('+a in item['task']),None)
 if addon:specs.append((item['name'],item['section'].split(':')[0],addon))
specs.sort(key=lambda s:priority.index(s[2]))
design_file=ROOT/'designs.json'
if design_file.exists():specs=[tuple(row)for row in json.loads(design_file.read_text())]
else:design_file.write_text(json.dumps(specs,indent=2))
assert len(specs)==52,len(specs)
manifest=[]
palette=['FF6B24','18A8F5','FFBD27','6FD92B','E54B91','7B54E7','24C5B9']
for index,(name,base,addon)in enumerate(specs):
 model(name);d=load_base(base);width,height,length=d['targetSize'];half=width/2;top=height/2
 rank=priority.index(addon);rarity='legendary'if rank==0 else 'mythic'if rank<=3 else 'epic'if rank<=6 else 'rare'if rank<=9 else 'uncommon'
 color=palette[(rank+['Muscle Car','Cop Cruiser','Box Truck','Monster Truck'].index(base))%len(palette)]
 mat('Finish'+str(index),color,'Enamel',.35,.3);accent='Finish'+str(index)
 # Preserve original recognizable panels; brighten body paint, never wheels, glass or lamps.
 for o in MODELS[name]:
  if not o.get('WheelId'):
   ma=o.data.materials[0].name;m=META.get(ma,META.get(ma.split('.')[0]));c=m['color']
   if m['finish']=='Enamel'and max(c)-min(c)>.15 and max(c)>.3:
    o.data.materials[0]=M[accent]
 if base=='Muscle Car':hood=(0,-length*.29,top*.23);mount=(0,length*.23,top*.23)
 elif base=='Cop Cruiser':hood=(0,-length*.32,top*.06);mount=(0,length*.30,top*.07)
 elif base=='Box Truck':hood=(0,-length*.32,top*.75);mount=(0,length*.06,top+.2)
 else:hood=(0,-length*.24,top*.48);mount=(0,length*.24,top*.40)
 x,y,z=hood
 # Each family gets its own chassis-level conversion language.
 if base=='Muscle Car':
  for side in [-1,1]:
   loft('Contoured rocker blade',[(-length*.34,.08,-height*.27,-height*.21,-height*.17),(0,.15,-height*.27,-height*.19,-height*.16),(length*.33,.08,-height*.27,-height*.21,-height*.17)],'Carbon'if rank<4 else accent).location.x=side*half*.91
  box('Low deck aero',(0,length*.37,top*.36),(width*.89,.30,.09),'Carbon',.04)
 elif base=='Cop Cruiser':
  pipe('Pursuit pushbar',[(-width*.32,-length*.47,-.34),(-width*.32,-length*.47,.10),(width*.32,-length*.47,.10),(width*.32,-length*.47,-.34)],.07,'Iron')
  for side in [-1,1]:
   box('Pursuit rocker armor',(side*half*.97,0,-height*.25),(.15,length*.48,.24),'Carbon',.045)
   box('Color matched door shield',(side*half*.89,0,-.06),(.06,.48,.22),accent,.05)
 elif base=='Box Truck':
  box('Shaped cab sun visor',(0,-length*.29,top*.63),(width*.87,.42,.10),accent,.06)
  if addon not in ['Jet Engine','Hover Fans','Straight Pipes','Nitrous Tank']:
   box('Cab-top engine mounting plinth',(0,-length*.32,top*.65),(.98,1.65,.22),accent,.08)
  for side in [-1,1]:
   box('Cab access step',(side*half*.91,-length*.27,-height*.31),(.28,.77,.12),'Chrome',.04)
   for j in range(4):box('Step grip rib',(side*half*.91,-length*.27-.25+j*.16,-height*.31+.07),(.23,.033,.025),'Rubber',.006)
 elif base=='Monster Truck':
  for side in [-1,1]:
   pipe('External reinforced roll hoop',[(side*half*.53,length*.05,.2),(side*half*.53,length*.07,top*.96),(side*half*.53,length*.32,top*.67),(side*half*.53,length*.38,.2)],.08,'Chrome')
   box('Flared shoulder armor',(side*half*.48,-length*.22,top*.50),(.38,.72,.15),accent,.05)
 if addon=='Jet Engine':
  if base=='Muscle Car':
   for side in [-1,1]:
    px=side*half*.94;py=length*.22;pz=top*.37
    jet((px,py,pz),.36,length*.43)
    loft('Integrated jet quarter fairing',[(py-length*.23,.18,pz-.37,pz-.03,pz+.02),(py,.39,pz-.42,pz-.08,pz+.08),(py+length*.20,.25,pz-.32,pz-.06,pz+.02)],accent).location.x=px
   design='Twin quarter-panel turbines, vented carbon rocker blades, low deck aero'
  elif base=='Cop Cruiser':
   for side in [-1,1]:
    px=side*half*.83;py=length*.24;pz=top*.21
    jet((px,py,pz),.34,length*.35)
    pipe('Pursuit jet cradle',[(side*half*.70,py-.7,pz-.45),(px,py-.4,pz-.34),(px,py+.55,pz-.34)],.09,'Chrome')
   design='Armored rear pursuit nacelles, police roof silhouette and pushbar retained'
  elif base=='Box Truck':
   for side in [-1,1]:
    px=side*(half+.18);py=length*.17;pz=-.05
    jet((px,py,pz),.47,length*.47)
    for yy in [py-.9,py+.65]:cyl('Cargo structural jet yoke',(side*half*.7,yy,pz-.4),(px,yy,pz-.4),.105,'Chrome')
    box('Cargo jet heat shield',(side*half,py,pz+.47),(.12,length*.45,.35),'Carbon',.045)
   design='Low cargo-side jet pods on structural yokes, full box and cab remain readable'
  else:
   jet(mount,.68,length*.58)
   for side in [-1,1]:
    pipe('Bed turbine cage',[(side*.75,length*.05,0),(side*.84,length*.13,top*.90),(side*.64,length*.44,top*.6)],.1,'Chrome')
    mesh('Swept jet stabilizer',[(side*.69,length*.20,top*.64),(side*1.10,length*.41,top*1.1),(side*.76,length*.43,top*.50)],[(0,1,2)],accent)
   design='Exposed heavy bed turbine with swept fins and suspension-clear support cage'
 elif addon=='Hover Fans':
  for o in list(MODELS[name]):
   if o.get('WheelId')or o.name.startswith(('Brake','Axle','Differential')):MODELS[name].remove(o);bpy.data.objects.remove(o,do_unlink=True)
  for side in [-1,1]:
   for yy in [-length*.28,length*.28]:
    px=side*half*.83;pz=-height*.27;r=.48 if base!='Box Truck'else .57
    fan((px,yy,pz),r)
    cyl('Fan chassis outrigger',(side*half*.42,yy,pz),(px,yy,pz),.075,'Chrome')
   pipe('Hover sill power line',[(side*half*.81,-length*.25,-height*.17),(side*half*.85,0,-height*.14),(side*half*.81,length*.25,-height*.17)],.033,'Heat')
  design='Wheel-less four-corner ducted lift fans integrated into the chassis'
 elif addon in ['V12 Engine','V8 Engine','V6 Engine','Inline 4']:
  count={'V12 Engine':12,'V8 Engine':8,'V6 Engine':6,'Inline 4':4}[addon]
  pos=mount if base=='Monster Truck'else hood
  if base=='Box Truck':pos=hood
  engine(pos,count,1.42 if count==12 else 1.05)
  px,py,pz=pos
  for side in [-1,1]:
   box('Engine recess surround',(side*.56,py,pz-.15),(.13,1.56 if count==12 else 1.2,.15),accent,.04)
   pipe('Exposed engine feed',[(side*.4,py+.5,pz),(side*half*.72,py+.7,pz-.20),(side*half*.77,0,-height*.20)],.04,'Titanium')
  design=f'{count}-cylinder exposed mechanical conversion, individual trumpets and engine surround'
 elif addon=='Straight Pipes':
  for side in [-1,1]:
   xx=side*half*.99;zz=height*.05
   pipe('Side exhaust collector',[(side*.37,-length*.25,zz),(xx,-length*.11,zz),(xx,length*.045,zz)],.10,'Chrome')
   tube('Heat-blued side-exit tip',(xx,length*.04,zz),(xx,length*.16,zz+.06),.14,'HeatBlue')
   for j in range(3):tor('Titanium tip heat band',(xx,length*(.08+j*.024),zz+.04),.14,.016,'Violet'if j%2 else 'Titanium',(0,1,0),16)
   for yy in [-length*.07,length*.035]:box('Bolted exhaust hanger',(xx,yy,zz+.13),(.2,.10,.15),'Steel',.02)
  design='Full-length exposed side exhaust with titanium blued open tips and brackets'
 elif addon in ['Scrap Turbo','Twin Turbo']:
  twin=addon=='Twin Turbo';engine(hood,4,.78)
  for side in ([-1,1]if twin else [1]):
   pos=(side*.66,y,z+.22);turbo(pos,1.0 if twin else 1.28)
   pipe('Polished turbo crossover',[(side*.71,y+.30,z+.33),(side*.80,y+.48,z+.52),(0,y+.43,z+.50)],.075,'Chrome')
   if not twin:
    for j in range(3):tor('Repair tape on charge hose',(side*.8,y+.35+j*.05,z+.46),.084,.018,'Rubber',(0,1,0),16)
  box('Front mounted intercooler',(0,-length*.46,-height*.10),(width*.48,.14,.34),'Iron',.04)
  for j in range(7):box('Intercooler cooling fin',(-width*.22+j*width*.073,-length*.475,-height*.10),(.036,.07,.28),'Chrome',.007)
  design='Paired exposed hood turbos and crossover cooling circuit'if twin else 'Oversized exposed single hood turbo with repaired charge hose'
 elif addon=='Rotary Engine':
  package_payload(addon,(0,y,z+.21),1.28,rotation=(0,0,0))
  for side in [-1,1]:
   box('Rotary recessed engine mount',(side*.51,y,z-.17),(.12,.92,.18),'Chrome',.04)
   pipe('Rotary side manifold',[(side*.40,y,z+.10),(side*.65,y+.25,z-.10),(side*half*.75,length*.23,-height*.15)],.07,'HeatBlue')
  design='Compact exposed rotary with rotor inspection window and blue exhaust headers'
 elif addon=='Supercharger':
  engine(hood,8,.95)
  package_payload(addon,(0,y,z+.57),1.3)
  for side in [-1,1]:box('Blower hood cheek',(side*.66,y,z-.05),(.23,1.18,.19),accent,.06)
  design='Hood-through roots blower, scoop, visible belt drive and sculpted hood cheeks'
 elif addon=='Diesel Stack':
  engine(hood,6,1.2)
  for side in [-1,1]:
   xx=side*(half+.17 if base=='Box Truck'else half*.73);yy=length*(.07 if base=='Box Truck'else .23)
   pipe('Diesel underbody manifold',[(side*.4,y,z-.2),(xx,0,-height*.23),(xx,yy,-height*.13)],.10,'Iron')
   tube('Vertical diesel smokestack',(xx,yy,-height*.13),(xx,yy,top*1.0),.16,'Chrome')
   tube('Soot black stack mouth',(xx,yy,top*.86),(xx,yy,top*1.07),.166,'Iron')
   for j in range(5):tor('Stack perforated shield rib',(xx,yy,top*.08+j*.18),.18,.025,'Titanium',(0,0,1),16)
  design='Cab-connected twin vertical sooty stacks with manifold and heat shields'
 elif addon=='Nitrous Tank':
  for side in [-1,1]:
   px=side*(half+.12 if base=='Box Truck'else half*.68);py=length*.23;pz=top*.20
   cyl('Nitrous bottle',(px,py-.36,pz),(px,py+.36,pz),.19,'Blue',n=24)
   cyl('Bottle shoulder',(px,py-.36,pz),(px,py-.47,pz),.19,'Blue',r2=.06)
   cyl('Bottle valve',(px,py-.47,pz),(px,py-.56,pz),.045,'Gold',n=12)
   for yy in [py-.23,py+.23]:tor('Bottle retaining strap',(px,yy,pz),.195,.023,'Chrome',(0,1,0),16)
   pipe('Braided nitrous feed',[(px,py-.55,pz),(side*half*.68,0,pz-.12),(side*.25,y,z)],.029,'HeatBlue')
   box('Bottle mounting tray',(px,py,pz-.23),(.48,.92,.08),'Iron',.03)
  design='Twin strapped nitrous bottles in rear deck recesses with routed braided feeds'
 else:raise AssertionError(addon)
 # Small fitted service details scaled to rarity; keep cabin and wheel travel readable.
 for side in [-1,1]:
  for j in range(3 if rank>3 else 5):
   yy=length*.13+j*.085
   box('Rear heat outlet',(side*half*.90,yy,-height*.08),(.035,.045,.15),'Iron',.008)
 objects=MODELS[name]
 export=template[template.index(' objects=MODELS[name];dg='):template.index("(OUT/'vehicle-manifest.json')")]
 export=export.replace('center=(lo+hi)/2;factor=length/(hi.y-lo.y)','center=(lo+hi)/2;factor=1.0')
 export=export.replace("'addon':'Warp Drive'","'addon':addon").replace("'rarity':'legendary'","'rarity':rarity")
 export=export.replace("for o in objects:o.location+=Vector((index*10,0,0))","for o in objects:o.location+=Vector((index%4*12,index//4*13,0))")
 exec(compile('if True:\n'+export,str(ROOT/'export.py'),'exec'))
 manifest[-1].update(addon=addon,rarity=rarity,expectedWheels=0 if addon=='Hover Fans'else 4)
 print('EXPORTED',name,manifest[-1]['triangles'],flush=True)
(OUT/'vehicle-manifest.json').write_text(json.dumps(manifest,indent=2))
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'Remaining-Fusions.blend'))
print('ALL_52_EXPORTED',flush=True)
