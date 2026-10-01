from pathlib import Path
root=Path(__file__).resolve().parent
template=(root.parent/'warp-drive-batch/build_vehicles.py').read_text()
start=template.index('specs=[');end=template.index('\ndef load_base',start)
template=template[:start]+'''specs=[
 ('Rocket Stallion','Muscle Car','Rear-quarter rocket tubes, carbon sill ducts, swept stabilizer','F96D25'),
 ('Fusion Fury','Muscle Car','Hood-integrated reactor and paired rocker power channels','D739DF'),
 ('Orbital Enforcer','Cop Cruiser','Twin rear pursuit boosters, dorsal patrol stabilizer','218BEE'),
 ('Plasma Patrol','Cop Cruiser','Recessed hood reactor, armored flank power rails','1EDAD0'),
 ('Rocket Freight','Box Truck','Twin cargo-mounted launch pods with structural yokes','ECAA27'),
 ('Core Carrier','Box Truck','Exposed rooftop power plant with side cooling racks','A54FEA'),
 ('Rocket Juggernaut','Monster Truck','Bed-mounted heavy rocket with rear outrigger rails','F44837'),
 ('Fusion Colossus','Monster Truck','Bed reactor, external roll cage and fender capacitor banks','83DB32')]
''' +template[end:]
start=template.index(" if base=='Rusted Sedan':");end=template.index(' # Common engineering language',start)
template=template[:start]+''' addon='Rocket Booster' if name.startswith(('Rocket','Orbital')) else 'Fusion Core'
 payload=json.loads((OUT/'addon-inputs'/(addon.replace(' ','_')+'.json')).read_text())
 def machinery(center,size,rotation=(0,0,0),label='Integrated drive'):
  points=[Vector((x,-z,y)) for g in payload['parts'] for x,y,z in g['vertices']]
  lo=Vector([min(p[i]for p in points)for i in range(3)]);hi=Vector([max(p[i]for p in points)for i in range(3)])
  scale=size/max(hi-lo);origin=(lo+hi)/2
  from mathutils import Euler
  matrix=Euler(rotation).to_matrix();normalmat=matrix
  for j,g in enumerate(payload['parts']):
   ma='Payload'+str(j);m=g['material'];matcolor=m['color']
   material=bpy.data.materials.new(ma);material.use_nodes=True;p=material.node_tree.nodes.get('Principled BSDF')
   p.inputs['Base Color'].default_value=(*matcolor,1);p.inputs['Metallic'].default_value=m.get('metal',.5);p.inputs['Roughness'].default_value=.35
   if m.get('glow',0):p.inputs['Emission Color'].default_value=(*matcolor,1);p.inputs['Emission Strength'].default_value=1.5
   M[ma]=material;META[ma]={**m,'finish':'Light' if m.get('glow',0) else 'Brushed' if m.get('metal',0)>.7 else 'Enamel'}
   vertices=[tuple(Vector(center)+matrix@((Vector((x,-z,y))-origin)*scale))for x,y,z in g['vertices']]
   o=mesh(label+' '+g['name'],vertices,g['triangles'],ma)
   for f in o.data.polygons:f.use_smooth=True
   o.data.normals_split_custom_set_from_vertices([tuple(normalmat@Vector((x,-z,y)))for x,y,z in g['normals']])
   o['SourceComponents']=len(g.get('components',[]))
 if base=='Muscle Car':
  if addon=='Rocket Booster':
   for side in [-1,1]:machinery((side*1.15,1.10,.25),1.8,(0,0,math.pi),'Rear-quarter rocket')
  else:machinery((0,-1.20,.75),1.45,label='Hood reactor')
  for side in [-1,1]:
   box('Low carbon rocker duct',(side*1.38,.1,-.45),(.22,2.75,.23),'WarpCarbon',.035)
   cable([(side*.55,-1.2,.5),(side*1.3,-.75,.1),(side*1.3,1.65,-.25)])
   loft('Sculpted rear arch armor',[(.5,.30,.1,.4,.55),(1.25,.38,.05,.48,.65),(1.8,.29,.05,.32,.48)],accent).location.x=side*1.13
  box('Swept rear carbon stabilizer',(0,2.05,.75),(2.9,.45,.11),'WarpCarbon',.06)
 elif base=='Cop Cruiser':
  if addon=='Rocket Booster':
   for side in [-1,1]:machinery((side*1.05,1.75,.25),1.6,(0,0,math.pi),'Pursuit booster')
  else:machinery((0,-1.45,.8),1.5,label='Hood plasma unit')
  for side in [-1,1]:
   box('Armored cruiser side sill',(side*1.5,.2,-.4),(.23,3.1,.35),'WarpCarbon',.05)
   cable([(side*.50,-1.35,.6),(side*1.45,-.7,.1),(side*1.47,1.7,-.1)])
   box('Pursuit bumper shoulder',(side*1.0,-2.8,-.32),(.75,.25,.35),'White',.065)
  box('Rear stabilizer',(0,2.35,.68),(2.75,.32,.12),'WarpCarbon',.04)
 elif base=='Box Truck':
  if addon=='Rocket Booster':
   for side in [-1,1]:
    machinery((side*(half+.25),1.2,.2),2.8,(0,0,math.pi),'Cargo launch pod')
    pipe('Heavy launch yoke',[(side*half,.5,-.6),(side*(half+.65),.5,-.3),(side*(half+.65),1.9,-.3),(side*half,1.9,-.6)],.12,'Chrome')
  else:machinery((0,.9,top+.4),2.0,label='Cargo rooftop power plant')
  for side in [-1,1]:
   cable([(side*.5,.9,top+.1),(side*(half+.1),.9,top-.1),(side*(half+.1),-.8,.2),(side*1.2,-2.0,.1)])
   for j in range(5):box('Cargo cooling radiator',(side*(half+.08),1.0+j*.27,.25),(.13,.10,.9),'Chrome',.025)
 elif base=='Monster Truck':
  machinery((0,1.05,.9),2.5,(0,0,math.pi)if addon=='Rocket Booster'else(0,0,0),'Heavy bed power unit')
  for side in [-1,1]:
   pipe('Reinforced power cage',[(side*.9,.65,.05),(side*1.2,.65,1.8),(side*1.2,1.8,1.8),(side*.9,1.8,.05)],.11,'Chrome')
   box('Fender capacitor bank',(side*1.02,-.95,.9),(.36,1.05,.24),accent,.06)
   cable([(side*.75,1.0,1.0),(side*1.05,.25,.9),(side*1.05,-1.4,.85)])
''' +template[end:]
template=template.replace("'addon':'Warp Drive'","'addon':addon").replace("'Warp-Vehicles-v1.blend'","'Legendary-Eight-v1.blend'")
exec(compile(template,str(root/'generated_builder.py'),'exec'))
