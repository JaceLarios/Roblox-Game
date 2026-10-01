approved_hero=build_golf
hero_indices={3:0,6:1,9:2,12:3,14:4}

def custom_shell(c,a,style):
 # Every profile controls stance, nose length, canopy plan, windscreen and fenders.
 profiles={
 'sprint':(.45,.51,1.10,-1.16,1.18, .93,[(-.69,.77,2.44),(.14,.90,2.61),(.91,.78,2.42)],-1.85),
 'retro':(.48,.56,1.08,-1.14,1.20,1.04,[(-.70,.93,2.66),(.20,1.03,2.74),(1.12,.91,2.65)],-1.83),
 'rat':(.48,.62,1.13,-1.24,1.17,1.00,[(-.41,.72,2.61),(.24,.88,2.75),(.95,.83,2.55)],-1.93),
 'rotary':(.43,.49,1.17,-1.24,1.20,.91,[(-.58,.70,2.32),(.25,.91,2.50),(1.04,.85,2.27)],-1.97),
 'twin':(.49,.54,1.24,-1.29,1.21,.97,[(-.79,.74,2.50),(.13,.93,2.69),(1.04,.80,2.43)],-2.11),
 'drag':(.43,.78,1.25,-1.53,1.24,.94,[(-.38,.77,2.33),(.33,.95,2.47),(.91,.85,2.30)],-2.29),
 'diesel':(.60,.68,1.23,-1.22,1.25,1.17,[(-.68,.90,2.88),(.18,1.04,2.96),(1.05,.96,2.85)],-2.09),
 'luxury':(.47,.53,1.17,-1.64,1.21,.98,[(-.61,.78,2.51),(.20,.96,2.67),(1.14,.82,2.45)],-2.53),
 'hover':(.0,.0,1.16,-1.13,1.24,1.00,[(-.58,.76,2.48),(.25,.96,2.68),(1.22,.74,2.41)],-1.97),
 'rocket':(.44,.60,1.13,-1.41,1.25,.90,[(-.70,.66,2.40),(.16,.82,2.60),(1.08,.66,2.35)],-2.18)
 }
 rf,rr,track,front,rear,sz,canopy,nose=profiles[style]
 style_index={'sprint':0,'retro':1,'rat':2,'rotary':4,'twin':5,'drag':7,'diesel':8,'luxury':10,'rocket':13}
 if style!='hover':wheelset(style_index[style],rf,rr,track,front,rear)
 box('Cart structural floor',(0,-.08,sz-.45),(1.85,abs(nose)+1.46,.17),'Carbon' if style in ['drag','luxury','rocket','hover'] else 'Iron',.06)
 cabin(sz,.32);clubs(.59,1.14,sz+.06)
 roof('Individual shaped canopy',canopy,'Cream' if style in ['retro','luxury'] else c)
 for side in [-1,1]:
  pipe('Shaped cart canopy supports',[(side*.85,-.64,sz-.13),(side*canopy[0][1],canopy[0][0],canopy[0][2]-.08),(side*canopy[-1][1],canopy[-1][0],canopy[-1][2]-.08),(side*.91,1.17,sz-.22)],.055,'Chrome' if style in ['retro','luxury'] else 'Iron')
  box('Entry running board',(side*.99,.13,sz-.45),(.29,1.20,.13),a,.055)
  if style!='hover':
   arch(side*track,front,rf+.03,rf+.085,.34,c);arch(side*track,rear,rr+.03,rr+.085,.39,c)
  box('Rear body quarter',(side*.90,1.18,sz-.03),(.30,.87,.39),c,.095)
  for yy in [-.18,.07,.32]:box('Step anti slip strip',(side*.99,yy,sz-.375),(.22,.05,.015),'Chrome',.006)
 quad('Cart windscreen',[(-.76,-.65,sz+.38),(.76,-.65,sz+.38),(side*.0+.70,canopy[0][0]+.035,canopy[0][2]-.17),(-.70,canopy[0][0]+.035,canopy[0][2]-.17)],'Glass',True)
 return nose,sz,track

def bonnet(nose,z,c,a,openbay=False):
 if openbay:
  for side in [-1,1]:
   box('Open bonnet shoulder',(side*.70,(nose-.69)/2,z+.11),(.28,abs(nose+.69),.30),c,.09)
   pipe('Bonnet edge piping',[(side*.69,nose+.06,z+.28),(side*.69,-.76,z+.28)],.023,a)
 else:loft('Sculpted cart bonnet',[(nose,.72,z-.08,z+.17,z+.25),(nose+.38,.93,z-.08,z+.32,z+.43),(-.68,.78,z+.04,z+.32,z+.38)],c)
 grille_nose(nose-.09,z-.03,1.30,c)
 for xx in [-.64,.64]:headlamp(xx,nose-.12,z+.18,.11)

def build_golf(spec,i):
 if i in hero_indices:return approved_hero(spec,hero_indices[i])
 model(spec['name']);c=spec['color'];a=spec['accent']
 styles={0:'sprint',1:'retro',2:'rat',4:'rotary',5:'twin',7:'drag',8:'diesel',10:'luxury',11:'hover',13:'rocket'}
 style=styles[i];nose,z,track=custom_shell(c,a,style)
 bonnet(nose,z,c,a,i in [5,7,8,10])
 if i==0:
  # Nitrous bottles form the flanks beside the rear cabin pillars.
  for side in [-1,1]:
   x=side*.99
   cyl('Nitrous bottle',(x,.81,z-.05),(x,.81,z+.70),.16,'Blue',r2=.14)
   for zz in [z+.07,z+.54]:tor('Bottle clamp',(x,.81,zz),.169,.022,'Chrome',(0,0,1))
   cyl('Nitrous brass valve',(x,.81,z+.70),(x,.81,z+.83),.05,'Gold')
   pipe('Nitrous body feed',[(x,.81,z+.76),(side*1.07,.45,z+.07),(side*.66,-1.25,z+.25)],.027,'Orange')
   box('Sprint cowl stripe',(side*.33,-1.20,z+.41),(.13,.63,.025),'Orange',.015)
  box('Sprint front lip',(0,nose-.03,z-.43),(2.05,.38,.095),'Carbon',.045)
 elif i==1:
  for side in [-1,1]:
   x=side*1.11
   pipe('Side exhaust header',[(side*.65,-1.29,z-.03),(x,-.67,z-.35),(x,.69,z-.33)],.075,'Chrome')
   hollow('Straight pipe',(x,-.63,z-.33),(x,.86,z-.33),.11,'Chrome')
   hollow('Blued rolled exhaust',(x,.79,z-.33),(x,1.10,z-.22),.12,'HeatBlue')
   tor('Violet exhaust heat band',(x,.80,z-.33),.12,.018,'HeatViolet',(0,1,0))
   box('Retro cream body spear',(side*.90,-1.13,z+.26),(.04,.61,.085),'Cream',.022)
  bumper(nose-.16,z-.35,1.92)
  for xx in [-.70,.70]:headlamp(xx,nose-.15,z+.29,.13)
 elif i==2:
  # Asymmetric rat-rod cowl: one oversize exposed turbo, visible hoses and patch plates.
  turbo(1.08,-1.12,z+.38,.31)
  box('Turbo chassis shelf',(1.0,-1.10,z+.06),(.55,.52,.12),'Steel',.04)
  pipe('Taped turbo induction',[(1.32,-.99,z+.56),(.89,-.83,z+.53),(.37,-1.10,z+.43)],.08,'Rubber')
  for xx in [.60,.72,.84]:tor('Hose tape wrap',(xx,-.91,z+.51),.087,.02,'Cream',(1,0,0))
  for xx,yy in [(-.48,-1.42),(-.21,-1.10)]:
   box('Bolted mismatched bonnet patch',(xx,yy,z+.435),(.33,.28,.028),'Rust',.025)
   for dx in [-.10,.10]:bolt((xx+dx,yy,z+.455),r=.025)
  pipe('Rat cart diagonal brace',[(-.85,1.13,z),(-.78,.08,2.65)],.05,'Cream')
 elif i==4:
  # Curved three-lobe side opening exposes the rotary next to the rear wheel.
  x=1.05;y=.79;zz=z-.04
  cyl('Rotary housing',(x-.28,y,zz),(x+.26,y,zz),.34,'Purple',n=40)
  for xx in [x-.20,x-.08,x+.04,x+.16]:tor('Rotary cooling rib',(xx,y,zz),.345,.018,'Steel')
  cyl('Rotor inspection cavity',(x+.27,y,zz),(x+.30,y,zz),.28,'Black')
  tor('Rotary window rim',(x+.31,y,zz),.28,.036,'Chrome')
  pts=[(x+.33,y+.23*math.cos(j*math.tau/3),zz+.23*math.sin(j*math.tau/3))for j in range(3)]
  o=mesh('Visible triangular rotor',pts,[(0,1,2)],'Gold');o.modifiers.new('Rotor thickness','SOLIDIFY').thickness=.035
  cyl('Rotary eccentric shaft',(x+.34,y,zz),(x+.38,y,zz),.05,'Chrome')
  box('Rotary structural cradle',(x,y,zz-.38),(.81,.83,.12),'Iron',.055)
  for side in [-1,1]:box('Rotary curved body trim',(side*.97,-.32,z-.08),(.12,.49,.29),a,.08)
 elif i==5:
  engine_block((0,-1.36,z+.04),4,'Orange',.78)
  for x in [-.74,.74]:
   turbo(x,-1.47,z+.49,.23)
   pipe('Twin turbo boost line',[(x,-1.44,z+.58),(x*.65,-.94,z+.63),(x*.30,-1.13,z+.60)],.051,'Chrome')
  pipe('Twin crossover',[(-.74,-1.59,z+.49),(-.49,-1.89,z+.48),(.49,-1.89,z+.48),(.74,-1.59,z+.49)],.049,'Chrome')
  for side in [-1,1]:
   box('Twin turbo blister',(side*1.03,-1.42,z+.07),(.22,.72,.26),c,.09)
   box('Orange race sill',(side*1.09,.10,z-.49),(.21,1.37,.12),a,.045)
 elif i==7:
  engine_block((0,-1.58,z+.07),6,'Pink',.91)
  box('Roots blower housing',(0,-1.58,z+.75),(.73,.80,.31),'Chrome',.065)
  for yy in [-1.88,-1.73,-1.58,-1.43,-1.28]:box('Blower rib',(0,yy,z+.75),(.77,.025,.27),'Steel',.01)
  box('Flared blower scoop',(0,-1.58,z+1.02),(.94,.87,.23),c,.085)
  box('Scoop mouth',(0,-2.02,z+1.02),(.77,.03,.13),'Black',.022)
  for zz in [z+.25,z+.78]:cyl('Blower pulley',(0,-2.07,zz),(0,-2.19,zz),.16,'Chrome')
  pipe('Exposed blower belt',[(-.16,-2.20,z+.25),(-.16,-2.20,z+.78),(.16,-2.20,z+.78),(.16,-2.20,z+.25),(-.16,-2.20,z+.25)],.025,'Rubber')
  for side in [-1,1]:
   pipe('Drag wheelie bar',[(side*.57,1.27,.49),(side*.60,2.15,.30)],.045,'Iron')
   cyl('Wheelie bar roller',(side*.60-.06,2.15,.28),(side*.60+.06,2.15,.28),.105,'Rubber',n=16)
  box('Drag front chin',(0,nose,z-.48),(2.16,.47,.08),'Carbon',.04)
 elif i==8:
  engine_block((0,-1.45,z+.06),6,'Copper',.94)
  for side in [-1,1]:
   x=side*.88
   pipe('Diesel chassis header',[(side*.40,-1.26,z-.02),(side*1.0,.0,z-.32),(x,1.08,z+.15)],.085,'Steel')
   hollow('Tall diesel stack',(x,1.08,z+.09),(x,1.08,3.13),.125,'Chrome')
   hollow('Soot black tip',(x,1.08,2.93),(x,1.08,3.18),.13,'Iron')
   for zz in [1.58,1.87,2.16,2.45]:tor('Stack shield band',(x,1.08,zz),.14,.024,'Copper',(0,0,1))
   box('Truck style fender armor',(side*1.09,-1.23,z+.13),(.25,.78,.17),'Cream',.055)
   spring((side*.90,-1.22,.71),(side*.81,-1.22,1.32),.095)
  pipe('Diesel bullbar',[(-1.03,-2.27,.69),(-1.03,-2.27,1.20),(1.03,-2.27,1.20),(1.03,-2.27,.69)],.07,'Iron')
 elif i==10:
  engine_block((0,-1.70,z+.04),12,'Red',1.28)
  for side in [-1,1]:
   box('Luxury gold sill',(side*1.01,.06,z-.43),(.23,1.27,.12),'Gold',.06)
   box('Long hood gold trim',(side*.66,-1.70,z+.28),(.07,1.55,.035),'Gold',.015)
   for yy in [.89,1.06,1.23]:box('Luxury rear vent',(side*1.055,yy,z+.08),(.025,.09,.16),'Black',.01)
  box('Long nose chin',(0,nose-.05,z-.43),(2.07,.42,.11),'Carbon',.055)
  cyl('Gold bonnet medallion',(0,nose-.18,z+.20),(0,nose-.20,z+.20),.075,'Gold',n=6)
 elif i==11:
  # A low hovercraft skirt joins four tilted-looking corner ducts to the floor.
  for side in [-1,1]:
   loft('Hovercraft pontoon',[(-1.64,.17,.36,.70,.80),(-.76,.28,.28,.64,.74),(.84,.28,.28,.64,.74),(1.66,.17,.36,.70,.80)],'White').location.x=side*.96
   for yy in [-1.18,1.22]:
    x=side*1.27
    cyl('Fan chassis arm',(side*.80,yy,.61),(x,yy,.61),.085,'Carbon')
    hollow('Ducted fan pod',(x,yy,.30),(x,yy,.79),.45,'Turquoise')
    tor('Cyan fan rim',(x,yy,.79),.42,.033,'Energy',(0,0,1))
    cyl('Fan center motor',(x,yy,.46),(x,yy,.71),.09,'Gold')
    for j in range(8):
     t=j*math.tau/8;mesh('Glowing fan blade',[(x,y0:=yy,.61),(x+.35*math.cos(t),yy+.35*math.sin(t),.61),(x+.35*math.cos(t+.40),yy+.35*math.sin(t+.40),.65)],[(0,1,2)],'Energy')
   pipe('Hover skirt light strip',[(side*1.14,-.78,.57),(side*1.14,.78,.57)],.026,'Energy')
 elif i==13:
  # Twin body-integrated rockets extend from swept rear quarters, not a cargo rack.
  for side in [-1,1]:
   x=side*1.27
   turbine(x,.31,1.05,.32,1.70,True)
   loft('Rocket sidepod fairing',[(-1.02,.13,.67,.98,1.09),(-.50,.26,.61,.87,.94),(.92,.25,.61,.87,.94),(1.39,.12,.68,.94,1.03)],c).location.x=x
   box('Rocket cockpit heat guard',(side*.98,.24,1.16),(.09,1.57,.58),'Carbon',.065)
   fin(side*1.30,1.13,1.23,'Blue',.63)
   for j in range(5):tor('Rocket hazard stripe',(x,-.11+j*.06,1.05),.329,.025,'Lemon' if j%2==0 else 'Black',(0,1,0))
   pipe('Rocket chassis strut',[(side*.65,.05,.51),(x,.18,.65),(x,1.1,.65)],.066,'Carbon')
  box('Rocket splitter',(0,-2.14,.42),(2.27,.48,.095),'Carbon',.05)
  roof('Rocket canopy spine',[(-.52,.10,2.53),(.18,.13,2.72),(.86,.10,2.53)],'Blue')
 spec['components']=len(MODELS[current]);spec['layout']=style
