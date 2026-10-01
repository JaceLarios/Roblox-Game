from pathlib import Path
import shutil
P=Path(__file__).resolve().parent;O=P.parent/'warp-cart-truck-v3';O.mkdir(exist_ok=True)
shutil.copy2(P/'geometry_helpers.py',O/'geometry_helpers.py');shutil.copytree(P/'base-inputs',O/'base-inputs',dirs_exist_ok=True)
s=(P/'build_vehicles.py').read_text()
a=s.index('specs=[');b=s.index('\ndef load_base',a)
s=s[:a]+'''specs=[
 ('Hole in Space','Golf Cart','Pearl canopy, violet sports cowl and twin rear warp battery towers','944AFF'),
 ('Star Freighter','Box Truck','Orange tractor cab with an open armored reactor cargo chamber','FF8C24')]
'''+s[b:]
# Remove old roofs/cargo by triangle region; leave wheels, bench, cab and chassis intact.
at="  ma='Base_'+str(i);m=g['material'];col=m['color']"
replacement='''  if name=='Box Truck' and not g.get('wheel'):
   if i in [20,22]:continue
   if i in [14,17,18,19,21]:
    g=dict(g);g['triangles']=[t for t in g['triangles'] if sum(g['vertices'][v][2] for v in t)/3>1.10]
  if name=='Golf Cart' and i in [16,17]:
   g=dict(g);g['triangles']=[t for t in g['triangles'] if sum(g['vertices'][v][1]for v in t)/3<1.8]
  if not g['triangles']:continue
  ma='Base_'+str(i);m=dict(g['material']);col=m['color']
  if (name=='Golf Cart' and i==14) or (name=='Box Truck' and i==14):
   rgb=(.47,.08,.88) if name=='Golf Cart' else (1,.27,.018)
   col=list(rgb);m['color']=col
'''
s=s.replace(at,replacement)
a=s.index(" if base=='Rusted Sedan':");b=s.index(' # Common engineering language',a)
s=s[:a]+''' if base=='Golf Cart':
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
  box('Rear containment latch',(0,3.52,.40),(.58,.18,.65),'WarpCopper',.08)
'''+s[b:]
s=s.replace('Warp-Redesign-v2.blend','Warp-Cart-Truck-v3.blend')
(O/'build_vehicles.py').write_text(s)
shutil.copy2(P/'pack.py',O/'pack.py')
rear=(P/'render_rear.py').read_text().replace('Warp-Redesign-v2.blend','Warp-Cart-Truck-v3.blend')
(O/'render_rear.py').write_text(rear)
print(O)
