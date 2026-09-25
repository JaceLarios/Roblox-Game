def legendary_finish(i,paint,accent):
 # Reward-tier bolt-on kit; keep the donor bonnet/headlights fully readable.
 for side in [-1,1]:
  box('Legendary carbon side skirt',(side*1.08,.03,.43),(.38,1.98,.18),'Carbon',.065)
  pipe('Bright skirt piping',[(side*1.25,-.76,.51),(side*1.25,.07,.51),(side*1.25,.86,.54)],.032,accent)
  box('Carbon bumper corner',(side*.90,-2.10,.48),(.40,.37,.12),'Carbon',.05)
  box('Gold bumper inset',(side*.90,-2.28,.51),(.28,.035,.055),'Gold',.016)
  # Raised intakes form chunky side shoulders instead of replacing the body.
  box('Rounded intake pod',(side*1.04,.70,1.02),(.34,.61,.33),paint,.12)
  for j in range(3):box('Intake pod gill',(side*1.218,.54+j*.13,1.04),(.026,.065,.17),'Carbon',.015)
 # Gold three-dimensional star mounted on the hood as a rarity cue.
 pts=[]
 for j in range(10):
  a=j*math.pi/5;rr=.155 if j%2==0 else .075
  pts.append((rr*math.sin(a),-1.64+rr*math.cos(a),1.145))
 o=mesh('Legendary gold hood star',pts,[tuple(range(10))],'Gold');o.modifiers.new('Badge thickness','SOLIDIFY').thickness=.025
 if i==12:
  # Jet: swept carbon wings, orange endplates and a tall center rudder.
  for side in [-1,1]:
   o=quad('Jet carbon wing overlay',[(side*.73,.75,.87),(side*1.64,1.64,.83),(side*1.63,1.91,.83),(side*.72,1.51,.93)],'Carbon');o.modifiers.new('Wing overlay thickness','SOLIDIFY').thickness=.07
   pipe('Jet bright wing edge',[(side*.74,.75,.90),(side*1.64,1.64,.88),(side*1.63,1.91,.88)],.035,accent)
  fin(0,2.23,2.25,accent,.57)
  tor('Oversize jet intake halo',(0,1.07,1.81),.64,.033,'Energy',(0,1,0),40)
 elif i==13:
  # Rocket: structural twin launch rails, chunky stabilizers and hot nozzle rings.
  box('Rocket crossmember',(0,1.64,.80),(2.36,.35,.20),'Carbon',.06)
  for side in [-1,1]:
   box('Rocket launch rail',(side*1.02,1.98,1.02),(.18,1.74,.22),'Iron',.05)
   for y in [1.51,2.32]:box('Rocket saddle',(side*1.02,y,1.15),(.30,.20,.24),'Chrome',.045)
   tor('Rocket hot nozzle halo',(side*1.02,3.00,1.48),.38,.034,'Lamp',(0,1,0),40)
   fin(side*1.34,1.83,.81,accent,.47)
 elif i==14:
  # Reactor: four copper cage pylons, energy coils and a luminous waist ring.
  box('Reactor foundation',(0,1.87,.77),(1.65,1.48,.20),'Carbon',.06)
  for side in [-1,1]:
   for yy in [1.38,2.32]:
    cyl('Reactor copper pylon',(side*.55,yy,.87),(side*.55,yy,1.79),.075,'Copper',n=16)
    for zz in [1.04,1.20,1.36,1.52]:tor('Reactor energy coil',(side*.55,yy,zz),.095,.025,'Energy',(0,0,1),20)
   pipe('Reactor side energy rail',[(side*1.19,-.65,.70),(side*1.19,.10,.70),(side*1.10,.79,.90)],.03,'Energy')
  tor('Reactor cyan waist ring',(0,1.86,1.69),.735,.032,'Energy',(0,0,1),40)
