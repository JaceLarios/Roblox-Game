def roof(name,stations,ma):
 # y, halfwidth, upper surface height. Each canopy has its own silhouette.
 return loft(name,[(y,w,z-.10,z-.025,z)for y,w,z in stations],ma)

def cabin(z=1.00,seat_y=.30,width=.80):
 for x in [-.43,.43]:seat(x,seat_y,z,width)
 steering(-.43,-.39,z+.47,.21)
 box('Two seat bench pedestal',(0,seat_y+.06,z-.23),(1.72,.99,.34),'Iron',.07)
 box('Cart dashboard',(0,-.53,z+.32),(1.58,.22,.22),'Black',.065)
 for xx in [-.38,-.20]:cyl('Dashboard gauge',(xx,-.397,z+.34),(xx,-.381,z+.34),.065,'Chrome',n=20)

def clubs(x=.63,y=1.10,z=1.02):
 cyl('Golf bag',(x,y,z),(x,y,z+.65),.18,'Blue',n=20)
 tor('Golf bag rim',(x,y,z+.66),.17,.026,'Rubber',(0,0,1))
 for j in range(3):
  xx=x-.09+j*.08;top=z+1.03+j*.07
  cyl('Golf club',(xx,y,z+.42),(xx,y,top),.016,'Chrome',n=8)
  box('Golf iron head',(xx+.045,y,top),(.15,.08,.09),'Chrome',.025)

def wheelset(i,rfront=.48,rrear=.48,track=1.12,front=-1.16,rear=1.13):
 for yy,r in [(front,rfront),(rear,rrear)]:
  axle(yy,r+.03,track)
  for x in [-track,track]:signature_wheel(x,yy,r+.03,r,.37 if i!=9 else .51,accent,i,yy>0)

def grille_nose(y,z,w,c):
 box('Nose grille surround',(0,y,z),(w+.25,.13,.31),c,.065)
 grille(y-.074,z,w,.20)

def build_golf(spec,i):
 model(spec['name']);c=spec['color'];a=spec['accent']
 if i==0: # tall, short-roof desert buggy, exposed suspension and four cylinder nose.
  wheelset(3,.65,.70,1.17,-1.28,1.20)
  box('Lifted cart backbone',(0,0,.88),(1.67,3.00,.20),'Iron',.065)
  cabin(1.20,.26);clubs(.57,1.08,1.34)
  roof('Short dune canopy',[(-.46,.76,2.96),(.02,.95,3.03),(.84,.92,2.93)],c)
  for side in [-1,1]:
   pipe('Exposed dune cage',[(side*.91,-.72,.98),(side*.78,-.39,2.85),(side*.86,.75,2.88),(side*.95,1.18,.91)],.072,'Iron')
   pipe('Diagonal cage brace',[(side*.94,1.14,1.03),(side*.81,.18,2.93)],.052,'Blue')
   box('Dune side sill',(side*.97,.12,.85),(.22,1.07,.16),'Blue',.065)
   for yy,r in [(-1.28,.65),(1.20,.70)]:
    arch(side*1.16,yy,r+.03,r+.08,.33,c)
    spring((side*.84,yy,.76),(side*.70,yy,1.41),.10)
   box('Front dune hood rail',(side*.61,-1.37,1.26),(.27,1.23,.21),c,.075)
  engine_block((0,-1.37,1.18),4,'Blue',.83)
  pipe('Dune front bullbar',[(-.94,-2.01,.83),(-.82,-2.05,1.26),(.82,-2.05,1.26),(.94,-2.01,.83)],.075,'Iron')
  for xx in [-.57,.57]:headlamp(xx,-2.04,1.30,.16)
  for xx in [-.50,-.17,.17,.50]:headlamp(xx,-.52,2.95,.09)
  quad('Short buggy windscreen',[(-.76,-.63,1.69),(.76,-.63,1.69),(.72,-.46,2.30),(-.72,-.46,2.30)],'Glass',True)
  spec['layout']='Tall dune buggy, short canopy, exposed suspension, front inline four'
 elif i==1: # low, swept two-seat fairway racer.
  wheelset(6,.46,.51,1.22,-1.29,1.28)
  box('Low race floor',(0,.04,.43),(1.97,3.48,.16),'Carbon',.05)
  cabin(.86,.36);clubs(.64,1.30,.99)
  roof('Swept racing canopy',[(-.79,.72,2.32),(-.20,.93,2.51),(.99,.86,2.28)],'Red')
  for side in [-1,1]:
   pipe('Swept cabin pillars',[(side*.87,-.62,1.04),(side*.72,-.71,2.24),(side*.83,.95,2.21),(side*.95,1.20,.69)],.05,'Carbon')
   loft('Race side skirt',[(-.77,.11,.34,.46,.50),(.49,.17,.34,.51,.56),(1.32,.13,.39,.68,.74)],'Carbon').location.x=side*1.04
   box('Racer rear haunch',(side*.99,1.29,.95),(.34,.87,.53),c,.13)
   arch(side*1.21,-1.29,.49,.53,.35,c);arch(side*1.21,1.28,.54,.58,.38,c)
   box('Race hood cheek',(side*.68,-1.47,.95),(.29,1.44,.26),c,.09)
   pipe('Racer white stripe',[(side*.65,-2.04,1.10),(side*.66,-.94,1.10)],.029,'White')
   box('Blade headlamp',(side*.71,-2.08,.88),(.35,.06,.10),'Lamp',.04)
  engine_block((0,-1.38,1.00),6,'Red',.90)
  box('Wide racing splitter',(0,-1.94,.44),(2.53,.66,.10),'Carbon',.06)
  grille_nose(-2.17,.66,1.49,c)
  quad('Raked racing windscreen',[(-.77,-.62,1.19),(.77,-.62,1.19),(.70,-.75,2.19),(-.70,-.75,2.19)],'Glass',True)
  for xx in [-.63,.63]:box('Ducktail mount',(xx,1.70,1.21),(.10,.12,.34),'Carbon',.025)
  box('Race ducktail',(0,1.70,1.39),(2.05,.38,.10),'White',.055)
  spec['layout']='Low wide V6 circuit cart, swept canopy, front engine and ducktail'
 elif i==2: # rear-big-tire V8 bruiser, cut roof, armored nose.
  wheelset(9,.52,.88,1.29,-1.28,1.18)
  box('V8 ladder chassis',(0,.05,.62),(1.98,3.41,.21),'Iron',.075)
  cabin(1.04,.15)
  roof('Armored chopped canopy',[(-.59,.88,2.46),(.11,1.01,2.56),(.74,.97,2.46)],'Carbon')
  for side in [-1,1]:
   pipe('V8 protective cage',[(side*.90,-.61,.73),(side*.87,-.53,2.40),(side*.94,.66,2.40),(side*.93,.92,.78)],.075,c)
   arch(side*1.27,-1.28,.55,.60,.38,c);arch(side*1.28,1.18,.91,.96,.47,c)
   box('Armor shoulder',(side*.88,-1.14,1.12),(.36,1.51,.49),c,.11)
   for yy in [-1.58,-1.32,-1.06]:bolt((side*.96,yy,1.38),r=.05)
   box('Armored step',(side*1.05,.07,.59),(.33,1.12,.19),'Iron',.055)
   hollow('V8 side exhaust',(side*.91,.70,1.13),(side*1.03,1.76,1.57),.12,'Titanium')
   box('Engine armored rear quarter',(side*.72,1.22,1.16),(.24,.87,.45),c,.09)
  loft('Armored snub bonnet',[(-1.98,.80,.81,1.17,1.27),(-1.24,.94,.91,1.32,1.43),(-.72,.79,1.00,1.31,1.38)],c)
  engine_block((0,1.17,1.31),8,'Purple',.97)
  for xx in [-.24,.24]:hollow('V8 velocity stack',(xx,1.17,1.95),(xx,1.17,2.24),.13,'Chrome')
  pipe('Engine rollover guard',[(-.61,.87,1.22),(-.63,.85,2.20),(.63,.85,2.20),(.61,.87,1.22)],.058,'Purple')
  box('Armored bumper',(0,-2.08,.71),(2.29,.32,.27),'Iron',.075)
  for xx in [-.55,.55]:headlamp(xx,-2.08,1.09,.13)
  quad('Chopped cart windscreen',[(-.79,-.65,1.46),(.79,-.65,1.46),(.82,-.57,2.32),(-.82,-.57,2.32)],'Glass',True)
  spec['layout']='Rear-big-tire V8 bruiser, armored snub nose and chopped canopy'
 elif i==3: # roof literally wraps the jet as the aircraft fuselage.
  wheelset(12,.45,.55,1.19,-1.34,1.30)
  box('Jet carbon tub',(0,.03,.46),(1.87,3.53,.18),'Carbon',.075)
  cabin(.92,.34);clubs(.62,1.20,.95)
  roof('Jet canopy wings',[(-1.03,.57,2.44),(-.49,.96,2.64),(.83,1.18,2.63),(1.49,.81,2.42)],c)
  turbine(0,.20,2.88,.42,2.02)
  for side in [-1,1]:
   # Full sculpted fairings join turbine and canopy, not a barrel balanced on a roof.
   loft('Turbine fuselage fairing',[(-.91,.14,2.48,2.72,2.83),(-.32,.26,2.52,2.87,2.94),(.78,.25,2.47,2.81,2.91),(1.30,.12,2.42,2.62,2.74)],c).location.x=side*.42
   pipe('Jet swept cabin arch',[(side*.85,-.77,.81),(side*.71,-.94,2.36),(side*1.01,.82,2.50),(side*.98,1.32,.70)],.072,'Carbon')
   arch(side*1.18,-1.34,.48,.54,.34,c);arch(side*1.18,1.30,.58,.63,.38,c)
   loft('Jet nose flank',[(-2.12,.15,.50,.75,.82),(-1.51,.24,.54,1.04,1.12),(-.69,.21,.54,1.08,1.16)],c).location.x=side*.76
   fin(side*.96,1.12,2.49,'Black',.68)
   box('Jet side intake',(side*1.04,.74,1.01),(.18,.71,.48),'Black',.075)
   box('Jet intake splitter',(side*1.15,.75,1.02),(.055,.62,.07),c,.025)
   box('Jet headlight',(side*.76,-2.05,.86),(.27,.06,.12),'Lamp',.045)
  loft('Aircraft center nose',[(-2.21,.28,.51,.67,.79),(-1.22,.64,.61,1.08,1.20),(-.64,.72,.70,1.13,1.20)],'Carbon')
  quad('Swept aircraft windscreen',[(-.77,-.68,1.26),(.77,-.68,1.26),(.63,-.91,2.31),(-.63,-.91,2.31)],'Glass',True)
  box('Jet front chin',(0,-2.08,.45),(2.39,.48,.105),'Carbon',.055)
  spec['layout']='Jet fuselage canopy, swept fins, aircraft nose and side intakes'
 else: # two floating hulls, open core held in the bridge joining them.
  box('Floating cockpit bridge',(0,.39,.71),(1.67,1.78,.16),'Carbon',.06)
  cabin(.98,.43);clubs(.61,1.24,1.09)
  roof('Split floating canopy',[(-.54,.62,2.55),(.20,.86,2.72),(1.34,.69,2.51)],'Purple')
  for side in [-1,1]:
   x=side*1.03
   loft('Separate floating hull',[(-1.98,.20,.47,.84,.93),(-1.43,.38,.39,1.08,1.19),(-.29,.35,.47,.97,1.05),(1.41,.31,.43,1.00,1.13),(1.80,.17,.58,.84,.94)],c).location.x=x
   pipe('Floating hull luminous seam',[(x,-1.92,.75),(side*1.39,-1.22,.77),(side*1.36,.63,.71),(x,1.72,.83)],.035,'Energy')
   pipe('Curved floating roof support',[(side*.88,1.22,.88),(side*.73,1.15,2.46),(side*.61,-.42,2.51)],.062,'Carbon')
   for yy in [-1.13,1.13]:
    cyl('Lift pod crown',(x,yy,.27),(x,yy,.59),.37,'Carbon',r2=.28)
    tor('Magnetic hover ring',(x,yy,.29),.41,.055,'Energy',(0,0,1))
    cyl('Energy hover pad',(x,yy,.17),(x,yy,.28),.28,'Energy',r2=.35)
   box('Hull inset headlight',(x,-1.96,.86),(.25,.075,.11),'Lamp',.045)
   cyl('Core bridge strut',(side*.95,-1.05,.78),(side*.43,-1.05,.93),.072,'Copper')
   pipe('Reactor front claw',[(side*.85,-1.67,.81),(side*.53,-1.43,1.19),(side*.34,-1.10,1.61)],.054,'Carbon')
  sphere('Plasma reactor sphere',(0,-1.05,1.16),.44,'Energy')
  for axis in [(1,0,0),(0,1,0),(0,0,1)]:tor('Reactor containment cage',(0,-1.05,1.16),.51,.035,'Iron',axis)
  tor('Floating core equator',(0,-1.05,1.16),.52,.021,'Energy',(0,0,1))
  quad('Floating cart half windscreen',[(-.65,-.47,1.33),(.65,-.47,1.33),(.61,-.47,2.05),(-.61,-.47,2.05)],'Glass',True)
  spec['layout']='Split levitating hulls joined by an exposed reactor bridge'
 spec['components']=len(MODELS[current])
