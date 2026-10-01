def restore_cart_identity(spec,i):
 c=spec['color'];a=spec['accent']
 heights=[2.64,2.78,2.77,3.03,2.56,2.71,2.56,2.54,3.00,2.64,2.73,2.74,2.58,2.67,2.77]
 seats=[.93,1.04,1.00,1.20,.91,.97,.86,.94,1.17,1.04,.98,1.00,.92,.90,.98]
 h=heights[i];z=seats[i];sy=.15 if i==9 else .43 if i==14 else .32
 remove=('Individual shaped canopy','Short dune canopy','Swept racing canopy','Armored chopped canopy','Jet canopy wings','Split floating canopy',
 'Shaped cart canopy supports','Exposed dune cage','Diagonal cage brace','Swept cabin pillars','V8 protective cage','Jet swept cabin arch','Curved floating roof support',
 'Seat cushion','Seat back','Seat stitching','Cart windscreen','Short buggy windscreen','Raked racing windscreen','Chopped cart windscreen','Swept aircraft windscreen','Floating cart half windscreen','Window seal')
 for o in list(MODELS[current]):
  if o.name.startswith(remove):MODELS[current].remove(o);bpy.data.objects.remove(o,do_unlink=True)
 # A recognizable overhanging cart canopy and four nearly vertical supports.
 box('Golf cart cream canopy',(0,.24,h),(2.15,2.63,.15),'Cream',.14)
 box('Canopy inset underside',(0,.24,h-.095),(1.96,2.43,.05),'White',.07)
 for side in [-1,1]:
  for yy in [-.69,1.17]:
   cyl('Straight golf canopy pillar',(side*.83,yy,z-.13),(side*.83,yy,h-.10),.043,'Chrome' if i in [1,10] else 'Iron',n=16)
   box('Canopy pillar foot',(side*.83,yy,z-.12),(.14,.16,.12),c,.035)
  box('Canopy color edge',(side*1.045,.24,h-.006),(.045,2.31,.07),c,.025)
  box('Wide golf entry step',(side*.99,.18,z-.40),(.31,1.11,.12),'Black',.04)
  for yy in [-.17,.07,.31,.55]:box('Entry step tread',(side*.99,yy,z-.332),(.24,.045,.012),'Chrome',.004)
  # Armrests frame a broad two-person bench rather than racing buckets.
  pipe('Golf bench armrest',[(side*.89,sy+.21,z+.02),(side*.89,sy+.23,z+.45),(side*.89,sy-.25,z+.45)],.035,'Iron')
  box('Padded armrest',(side*.89,sy-.01,z+.47),(.13,.43,.09),'Upholstery',.04)
 box('Continuous golf bench cushion',(0,sy,z),(1.67,.66,.18),'Upholstery',.10)
 box('Continuous golf bench back',(0,sy+.30,z+.38),(1.67,.17,.61),'Upholstery',.095,rot=(.07,0,0))
 for xx in [-.55,0,.55]:pipe('Golf bench stitched seam',[(xx,sy-.22,z+.096),(xx,sy+.20,z+.096)],.005,'Cream')
 # Upright folding windshield with its familiar central hinge.
 quad('Golf folding windscreen',[(-.77,-.71,z+.38),(.77,-.71,z+.38),(.77,-.71,h-.21),(-.77,-.71,h-.21)],'Glass',True)
 hinge=(z+.38+h-.21)/2
 pipe('Golf windshield hinge',[(-.76,-.73,hinge),(.76,-.73,hinge)],.021,'Chrome')
 # Golf-cart cowl shoulders tie exposed powerplants back into the stock front shape.
 if i in [3,5,6,7,8,10]:
  for side in [-1,1]:
   box('Golf cowl rounded shoulder',(side*.71,-1.04,z+.17),(.30,.45,.30),c,.11)
 if i==14:
  box('Golf front connecting bumper',(0,-1.89,.66),(2.29,.14,.12),'Chrome',.06)
  for xx in [-.59,.59]:box('Floating cart bumper pad',(xx,-1.97,.66),(.19,.07,.15),'Rubber',.035)
 # Visible golf accessory: no extra cargo deck or machinery added here.
 box('Golf ball holder',(.51,-.44,z+.40),(.27,.11,.065),'Cream',.025)
 for xx in [.44,.54]:sphere('Golf ball',(xx,-.44,z+.46),.044,'White')
 spec['layout']=spec.get('layout','')+'; restored cart canopy, upright screen and bench'
 spec['components']=len(MODELS[current])
