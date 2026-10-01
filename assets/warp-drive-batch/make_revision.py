from pathlib import Path
import shutil
P=Path(__file__).resolve().parent
O=P.parent/'warp-redesign-v2';O.mkdir(exist_ok=True)
shutil.copy2(P/'geometry_helpers.py',O/'geometry_helpers.py')
shutil.copytree(P/'base-inputs',O/'base-inputs',dirs_exist_ok=True)
s=(P/'build_vehicles.py').read_text()
start=s.index(" if base=='Rusted Sedan':")
end=s.index(' # Common engineering language',start)
muscle=s[s.index(" elif base=='Muscle Car':",start):s.index(" elif base=='Cop Cruiser':",start)]
blocks=''' if base=='Rusted Sedan':
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
'''+muscle+''' elif base=='Cop Cruiser':
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
'''
s=s[:start]+blocks+s[end:]
# The approved muscle car is deliberately omitted from rebuilding/export/import.
s=s.replace(" ('Lightspeed Legend','Muscle Car','Twin rear-quarter induction pods and low aero','FF6A24'),",'')
s=s.replace('Warp-Vehicles-v1.blend','Warp-Redesign-v2.blend').replace('total-87500','total-82500').replace('max(.45,','max(.30,').replace('total-87500','total-82500').replace('max(.45,','max(.30,')
(O/'build_vehicles.py').write_text(s)
print(O)
