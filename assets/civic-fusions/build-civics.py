import bpy,bmesh,math,json,re,sys
from pathlib import Path
from mathutils import Vector,Matrix
P=Path(__file__).resolve().parent;BASE=P/'source/Honda-Civic-Rusted-v2.blend'
MECH=P.parent/'new-addons/Junkyard-Fusion-10-Addons-Textured.blend';WARP=P.parent/'warp-drive-batch/Warp-Drive-v1.blend';GHOST=P.parent/'phantom-addons/Phantom-Addons.blend'
text=(P/'FusionRecipes.reference.luau').read_text(encoding='utf-8-sig');names=re.findall(r'\{ name = "([^"]+)"[^\n]*isAddon = true',text)
assert len(names)==31,len(names)
colors=[(.015,.30,.9),(.95,.46,.015),(.05,.55,.3),(.75,.025,.03),(.13,.045,.65),(.015,.5,.65),(.9,.19,.025),(.03,.14,.55),(.23,.32,.36),(.55,.02,.07),(.75,.64,.38),(.04,.65,.64),(.05,.14,.38),(.85,.28,.02),(.24,.015,.48),(.018,.05,.16)]
plans=['Twin nitrous bottles recessed in hood bay, polished clamps, pressure gauges and braided plumbing','Titanium side exhausts with fitted rocker guards','Exposed front-quarter turbo with intercooler and pressure piping','Open hood four-cylinder track conversion','Compact rotary in hood aperture with rotary port side trim','Twin-turbo hood conversion with dual charge pipes','V6 street racer with vented hood surround','Roots blower through hood and matching belt-drive detail','Diesel rally conversion with rear-quarter stacks','V8 drag hatch with broad intake banks and wider stance','V12 grand tourer with long twelve-trumpet engine bay','Four corner hover ducts replacing road wheels','Roof-spine jet duct with rear thrust outlet','Twin rear-quarter rocket pods and heat shields','Hatch reactor cradle with side conduits and cyan glow','Rear portal frame, blue energy rails and induction rings','Lantern light bar with bumper mounts and matching trim','Rear ghost exhaust integrated into bumper outlets','Low hood crystal with gold mounting claws','Gothic grille replacing stock central grille area','Rear hatch ectoplasm canister and underbody plumbing','Roof trumpet bank with horn-fed front ducts','Floating spectral rear wing with shaped sill lighting','Low roof coffin rack and gold tie-down hardware','Rear hatch cauldron conversion with mint plumbing','Roof mast, sail, reinforced roof mounts and glowing rigging','Four spectral wheels and matching illuminated sill strips','Hood-mounted soul turbo with gold charge pipe','Hearse roof canopy integrated over hatch cabin','Twin scythe quarter-panel outriggers with axle anchors','Visible ghost driver in cabin with ghost-lit exterior trim']
def slug(s):return re.sub(r'[^A-Za-z0-9]+','_',s).strip('_')
def material(name,c,metal=0,rough=.3,glow=0):
 m=bpy.data.materials.new(name);m.use_nodes=True;p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*c,1);p.inputs['Metallic'].default_value=metal;p.inputs['Roughness'].default_value=rough
 if glow:p.inputs['Emission Color'].default_value=(*c,1);p.inputs['Emission Strength'].default_value=glow
 return m
def add(o,name,m):
 o.name=name;o.data.materials.append(m)
 for c in list(o.users_collection):c.objects.unlink(o)
 COL.objects.link(o);return o
def box(name,p,d,m,bevel=.015):
 bpy.ops.mesh.primitive_cube_add(size=1,location=p);o=add(bpy.context.object,name,m);o.scale=d;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
 if bevel:b=o.modifiers.new('Machined edges','BEVEL');b.width=bevel;b.segments=3;o.modifiers.new('Weighted normals','WEIGHTED_NORMAL')
 return o
def cyl(name,a,b,r,m,n=24,r2=None):
 a,b=Vector(a),Vector(b);v=b-a;bpy.ops.mesh.primitive_cone_add(vertices=n,radius1=r,radius2=r if r2 is None else r2,depth=v.length,location=(a+b)/2);o=add(bpy.context.object,name,m);o.rotation_euler=v.to_track_quat('Z','Y').to_euler()
 for f in o.data.polygons:f.use_smooth=len(f.vertices)==4
 return o
def tor(name,p,r,w,m,axis=(0,0,1)):
 bpy.ops.mesh.primitive_torus_add(major_segments=36,minor_segments=8,major_radius=r,minor_radius=w,location=p);o=add(bpy.context.object,name,m);o.rotation_euler=Vector(axis).to_track_quat('Z','Y').to_euler();return o
def pipe(name,pts,r,m):
 cu=bpy.data.curves.new(name,'CURVE');cu.dimensions='3D';cu.bevel_depth=r;cu.bevel_resolution=3;sp=cu.splines.new('BEZIER');sp.bezier_points.add(len(pts)-1)
 for p,co in zip(sp.bezier_points,pts):p.co=co;p.handle_left_type='AUTO';p.handle_right_type='AUTO'
 ob=bpy.data.objects.new(name,cu);COL.objects.link(ob);cu.materials.append(m);return ob
def imported(name,target,size,library=MECH,rotate=0):
 with bpy.data.libraries.load(str(library),link=False)as(a,b):b.collections=[name]
 c=b.collections[0];bpy.context.scene.collection.children.link(c);c.hide_render=False;c.hide_viewport=False;bpy.context.view_layer.update();obs=[o for o in c.all_objects if o.type in ['MESH','CURVE']]
 # Evaluate bounds only after linking: library matrices are stale before scene evaluation.
 for o in obs:o.hide_render=False;o.hide_viewport=False;o.hide_set(False)
 bpy.context.view_layer.update();ps=[o.matrix_world@Vector(v)for o in obs for v in o.bound_box];lo=Vector([min(p[i]for p in ps)for i in range(3)]);hi=Vector([max(p[i]for p in ps)for i in range(3)]);center=Vector(((lo.x+hi.x)/2,(lo.y+hi.y)/2,lo.z));scale=min(size[j]/max(.001,(hi-lo)[j])for j in range(3))
 fit=Matrix.Diagonal(Vector((size[0]/(hi.x-lo.x),size[1]/(hi.y-lo.y),size[2]/(hi.z-lo.z),1))) if name=='Reaper Scythes' else Matrix.Scale(scale,4)
 transform=Matrix.Translation(Vector(target))@Matrix.Rotation(rotate,4,'Z')@fit@Matrix.Translation(-center)
 for o in obs:o.matrix_world=transform@o.matrix_world;o['FusionAddon']=name
 return obs
def opening(center,dims):
 body=bpy.data.objects['Honda_Civic_Body'];body.data=body.data.copy();bm=bmesh.new();bm.from_mesh(body.data)
 # Imported car shell is open geometry; clip a real aperture without boolean caps.
 transform=body.matrix_world;inv=transform.inverted()
 for v in bm.verts:v.co=transform@v.co
 lo=Vector(center)-Vector(dims)/2;hi=Vector(center)+Vector(dims)/2
 for axis in range(3):
  normal=Vector((0,0,0));normal[axis]=1
  for edge in [lo[axis],hi[axis]]:
   co=Vector((0,0,0));co[axis]=edge
   bmesh.ops.bisect_plane(bm,geom=list(bm.verts)+list(bm.edges)+list(bm.faces),dist=.000001,plane_co=co,plane_no=normal)
 remove=[f for f in bm.faces if all(lo[j]-.000001<=f.calc_center_median()[j]<=hi[j]+.000001 for j in range(3))]
 bmesh.ops.delete(bm,geom=remove,context='FACES')
 for v in bm.verts:v.co=inv@v.co
 bm.to_mesh(body.data);bm.free();body.data.update()
 box('Engine bay inner cradle',(center[0],center[1],center[2]-dims[2]/2+.015),(dims[0]*.99,dims[1]*.99,.025),DARK)
def engine(cylinders):
 length=.66 if cylinders<=6 else .86 if cylinders==8 else 1.04;y=-1.25
 opening((0,y,.75),(.78,length+.05,.48));box('Engine block',(0,y,.62),(.6,length,.25),DARK)
 banks=1 if cylinders==4 else 2;per=cylinders//banks
 for side in ([0]if banks==1 else [-1,1]):
  x=side*.21;box('Polished valve cover',(x,y,.81),(.22,length*.92,.12),ACC)
  for j in range(per):
   yy=y-length*.40+j*length*.8/max(1,per-1);cyl('Intake trumpet',(x,yy,.85),(x,yy,.98),.044,CHROME,r2=.057);tor('Rolled intake lip',(x,yy,.98),.055,.008,CHROME)
   pipe('Individual exhaust header',[(x,yy,.70),((.44 if side>=0 else -.44),yy,.61),((.46 if side>=0 else -.46),yy+.10,.48)],.022,CHROME)
  for yy in [y-length*.4,y+length*.4]:
   for xx in [x-.075,x+.075]:cyl('Valve-cover hex bolt',(xx,yy,.865),(xx,yy,.88),.009,CHROME,n=6)
 cyl('Crank drive',(0,y-length*.5-.02,.65),(0,y-length*.5-.06,.65),.08,CHROME)
def aero(i):
 if i<3:return
 for side in [-1,1]:
  box('Fitted side skirt',(side*.775,0,.16),(.07,2.1,.065),CARBON if i>=6 else ACC,.022)
 if i in [3,5,6,7,9,10,12,13,14,15]:
  for side in [-1,1]:box('Rear wing bracket',(side*.48,1.52,1.02),(.035,.10,.24),CARBON)
  box('Swept hatch rear wing',(0,1.52,1.16),(1.64,.27,.045),CARBON,.018)
  for side in [-1,1]:box('Wing endplate',(side*.80,1.52,1.17),(.025,.3,.12),ACC,.008)
  box('Fitted front chin',(0,-1.96,.14),(1.43,.20,.05),CARBON,.018)
 if i>=9 and i<16:
  for side in [-1,1]:
   for yy in [-1.24,1.237]:
    pts=[(side*.83,yy+.405*math.cos(a),.291+.405*math.sin(a))for a in [j*math.pi/16 for j in range(17)]];pipe('Contoured wheel arch extension',pts,.024,ACC)
def mechanical(i):
 if i==0:
  opening((0,-1.27,.79),(.73,.68,.38))
  for side in [-1,1]:
   x=side*.19;cyl('Blue nitrous bottle',(x,-1.53,.75),(x,-1.06,.75),.095,ACC)
   for yy in [-1.45,-1.14]:tor('Nitrous steel clamp',(x,yy,.75),.101,.014,CHROME,(0,1,0))
   cyl('Bottle domed shoulder',(x,-1.06,.75),(x,-1.0,.75),.095,CHROME,r2=.023)
   cyl('Nitrous brass valve',(x,-1.0,.75),(x,-.975,.75),.025,GOLD)
   pipe('Braided nitrous line',[(x,-.98,.75),(side*.32,-.99,.65),(side*.38,-1.56,.6)],.014,CHROME)
   cyl('Bottle pressure dial',(x,-1.07,.825),(x,-1.07,.85),.027,CHROME)
   cyl('White pressure gauge face',(x,-1.07,.851),(x,-1.07,.853),.022,material('Gauge ivory',(.8,.85,.9)))
  for xx in [-.34,.34]:box('Nitrous bay painted cheek',(xx,-1.27,.77),(.045,.65,.055),ACC,.015)
 elif i==1:
  for side in [-1,1]:
   pipe('Polished side exhaust',[(side*.46,-1.2,.24),(side*.88,-.65,.15),(side*.89,.73,.16)],.045,CHROME);cyl('Heat-stained exhaust tip',(side*.89,.60,.16),(side*.89,.87,.16),.055,ACC);cyl('Dark open exhaust bore',(side*.89,.868,.16),(side*.89,.875,.16),.044,DARK)
 elif i==2:
  opening((.28,-1.24,.77),(.54,.61,.45));imported('Scrap Turbo',(.28,-1.24,.57),(.58,.61,.65));pipe('Turbo charge pipe',[(.32,-1.28,.76),(.58,-1.56,.59),(.43,-1.90,.34)],.033,CHROME);box('Front intercooler',(0,-2.06,.31),(.68,.032,.15),CHROME,.006)
 elif i in [3,6,9]:engine({3:4,6:6,9:8}[i])
 elif i in [4,5,7,8,10]:
  addon=names[i];length=1.02 if i==10 else .74;opening((0,-1.22,.77),(.80,length,.5));imported(addon,(0,-1.22,.53),(.83,length, .83 if i in [7,8] else .64))
  for side in [-1,1]:pipe('Polished induction crossover',[(side*.32,-1.1,.73),(side*.50,-1.45,.68),(side*.42,-1.75,.39)],.023 if i==4 else .031,CHROME)
  if i==8:
   for side in [-1,1]:pipe('Quarter-panel diesel stack',[(side*.63,.3,.20),(side*.83,1.08,.25),(side*.85,1.16,1.45)],.055,CHROME);tor('Sooted stack lip',(side*.85,1.16,1.45),.056,.012,DARK)
 elif i==11:
  for ob in list(bpy.data.objects):
   if ob.name.startswith('Wheel_'):ob.hide_render=True;ob.hide_viewport=True
  for side in [-1,1]:
   for yy in [-1.25,1.23]:
    x=side*.82;cyl('Fan wheel-well cap',(side*.60,yy,.32),(side*.82,yy,.32),.36,CARBON)
    tor('Hover duct',(x,yy,.20),.34,.065,ACC);tor('Hover field rim',(x,yy,.21),.30,.019,GLOW)
    for k in range(10):
     a=k*math.tau/10;blade=box('Cyan lift blade',(x+.17*math.cos(a),yy+.17*math.sin(a),.19),(.26,.05,.017),GLOW,.009);blade.rotation_euler.z=a
    cyl('Fan turbine center',(x,yy,.17),(x,yy,.25),.072,CHROME)
 elif i==12:
  # Longitudinal turbine spine follows the rear hatch instead of sitting on the hood.
  y=.6;z=1.33
  cyl('Turbine armored barrel',(0,.12,z),(0,1.63,z),.23,CARBON)
  for yy in [.15,.35,.75,1.12,1.55]:tor('Jet compression ring',(0,yy,z),.235,.025,CHROME,(0,1,0))
  cyl('Front turbine intake',(0,.1,z),(0,.06,z),.19,DARK);cyl('Jet exhaust throat',(0,1.63,z),(0,1.82,z),.21,DARK,r2=.28);tor('Afterburner rim',(0,1.82,z),.255,.022,GLOW,(0,1,0))
  for k in range(12):
   a=k*math.tau/12;pipe('Turbine inlet blade',[(.04*math.cos(a),.05,z+.04*math.sin(a)),(.16*math.cos(a+.3),.05,z+.16*math.sin(a+.3))],.017,CHROME)
  for yy in [.2,1.1]:box('Roof-integrated jet saddle',(0,yy,1.19),(.43,.16,.15),ACC)
 elif i==13:
  for side in [-1,1]:
   imported('Rocket Booster',(side*.72,.99,.61),(.38,1.55,.54));pipe('Rocket chassis brace',[(side*.62,.62,.42),(side*.75,.75,.67),(side*.72,1.45,.65)],.025,CHROME)
 elif i==14:
  opening((0,1.30,1.09),(.88,1.0,.48));imported('Fusion Core',(0,1.17,.83),(.85,.85,1.02))
  for side in [-1,1]:pipe('Reactor conduit',[(side*.28,1.2,1.14),(side*.63,.65,.78),(side*.82,.12,.2),(side*.8,-1.3,.25)],.025,GLOW)
 elif i==15:
  imported('Warp Drive',(0,1.16,.87),(1.52,.75,1.15),WARP)
  for side in [-1,1]:pipe('Warp induction rail',[(side*.75,1.3,.64),(side*.8,.3,.29),(side*.8,-1.3,.29)],.027,GLOW)
def phantom(i):
 j=i-16;name=names[i]
 if j==0:imported(name,(0,-1.96,.38),(1.20,.30,.85),GHOST)
 elif j==1:
  imported(name,(0,1.77,.15),(1.1,.64,.42),GHOST)
 elif j==2:imported(name,(0,-1.18,.73),(.30,.30,.40),GHOST)
 elif j==3:imported(name,(0,-2.08,.21),(1.32,.20,.47),GHOST)
 elif j==4:
  opening((0,1.3,1.04),(.65,.65,.43));imported(name,(0,1.22,.82),(.58,.56,.85),GHOST);pipe('Ecto delivery line',[(0,1.20,1.1),(.7,.87,.6),(.81,.2,.22),(.7,-1.5,.4)],.025,GLOW)
 elif j==5:imported(name,(0,-.12,1.26),(.65,.85,.58),GHOST)
 elif j==6:imported(name,(0,1.55,.91),(1.58,.48,.66),GHOST)
 elif j==7:imported(name,(0,.41,1.22),(.90,1.85,.52),GHOST)
 elif j==8:
  opening((0,1.31,1.07),(.80,.8,.5));imported(name,(0,1.2,.85),(.72,.72,.81),GHOST)
 elif j==9:imported(name,(0,.45,1.25),(1.0,.55,1.55),GHOST)
 elif j==10:
  # Four separate wheel portals preserve recognizable Civic arches.
  for ob in list(bpy.data.objects):
   if ob.name.startswith('Wheel_'):ob.hide_render=True;ob.hide_viewport=True
  for side in [-1,1]:
   for yy in [-1.24,1.237]:
    x=side*.71;tor('Wraith wheel tire',(x,yy,.291),.345,.054,GLOW,(1,0,0));tor('Wraith wheel inner rim',(x+side*.04,yy,.291),.27,.018,GOLD,(1,0,0));cyl('Wraith wheel hub',(x-side*.08,yy,.291),(x+side*.08,yy,.291),.075,CARBON)
    for k in range(8):
     a=k*math.tau/8;pipe('Ghost wheel spoke',[(x+side*.08,yy+.075*math.cos(a),.291+.075*math.sin(a)),(x+side*.08,yy+.28*math.cos(a+.16),.291+.28*math.sin(a+.16))],.014,GLOW)
 elif j==11:
  opening((.14,-1.24,.77),(.65,.68,.48));imported(name,(.14,-1.24,.54),(.69,.70,.76),GHOST);pipe('Soul intake pipe',[(.2,-1.15,.81),(-.5,-1.4,.66),(-.46,-1.9,.34)],.034,GOLD)
 elif j==12:
  opening((0,.65,1.17),(1.10,1.8,.35));imported(name,(0,.60,.92),(1.38,2.0,1.03),GHOST)
 elif j==13:imported(name,(0,1.05,.31),(2.45,.85,1.15),GHOST)
 elif j==14:
  imported(name,(.31,-.1,.35),(.46,.64,.83),GHOST)
  p=bpy.data.materials['Glass_MAT'].node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(.72,.85,.88,1);p.inputs['Roughness'].default_value=.025
 for side in [-1,1]:pipe('Spectral sill accent',[(side*.78,-.76,.19),(side*.8,0,.17),(side*.79,.81,.20)],.012,GLOW)
 if j in [1,3,4,8,11]:
  for side in [-1,1]:box('Phantom fender accent',(side*.75,-1.11,.77),(.04,.22,.035),GOLD,.01)

start=int(sys.argv[sys.argv.index('--')+1]) if '--'in sys.argv else 0
end=int(sys.argv[sys.argv.index('--')+2]) if '--'in sys.argv and len(sys.argv)>sys.argv.index('--')+2 else len(names)
for i in range(start,end):
 bpy.ops.wm.open_mainfile(filepath=str(BASE));s=bpy.context.scene;addon=names[i];label='Civic + '+addon;COL=bpy.data.collections.new(label);s.collection.children.link(COL)
 for ob in list(s.objects):
  if ob.type=='MESH' and ob.name!='PREVIEW FLOOR':
   for c in list(ob.users_collection):c.objects.unlink(ob)
   COL.objects.link(ob)
 color=colors[i]if i<16 else [(.06,.10,.18),(.10,.02,.20),(.20,.06,.30),(.13,.18,.16),(.02,.26,.19)][(i-16)%5]
 CHROME=material('Clean polished aluminum',(.55,.61,.67),.95,.15);DARK=material('Graphite mechanical housings',(.022,.03,.04),.65,.29);GOLD=material('Machined brass',(.65,.36,.065),.8,.22);ACC=material('Fusion accent',color,.5,.23);GLOW=material('Addon energy',(.01,.65,1)if i<16 else(.12,.95,.52),.05,.23,2)
 CARBON=material('Clean carbon trim',(.022,.028,.034),.35,.2)
 # Fine procedural weave for the new performance trim.
 n=CARBON.node_tree.nodes;l=CARBON.node_tree.links;tex=n.new('ShaderNodeTexChecker');tex.inputs['Scale'].default_value=140;tex.inputs['Color1'].default_value=(.01,.014,.018,1);tex.inputs['Color2'].default_value=(.038,.045,.05,1);l.new(tex.outputs['Color'],n.get('Principled BSDF').inputs['Base Color'])
 paint=bpy.data.materials['Body_MAT'];nodes=paint.node_tree.nodes;links=paint.node_tree.links;image=next(n.image for n in nodes if n.type=='TEX_IMAGE'and n.image);nodes.clear();out=nodes.new('ShaderNodeOutputMaterial');p=nodes.new('ShaderNodeBsdfPrincipled');t=nodes.new('ShaderNodeTexImage');t.image=image;mix=nodes.new('ShaderNodeMixRGB');mix.blend_type='MULTIPLY';mix.inputs[0].default_value=1;mix.inputs[2].default_value=(*color,1);links.new(t.outputs[0],mix.inputs[1]);links.new(mix.outputs[0],p.inputs['Base Color']);p.inputs['Metallic'].default_value=.32;p.inputs['Roughness'].default_value=.24;p.inputs['Coat Weight'].default_value=.65;p.inputs['Coat Roughness'].default_value=.12;links.new(p.outputs[0],out.inputs[0])
 rim=bpy.data.materials['Silver_MAT'];p=rim.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(.4,.45,.52,1) if i%3==0 else (.045,.055,.07,1) if i%3==1 else (.45,.29,.085,1);p.inputs['Roughness'].default_value=.17;p.inputs['Metallic'].default_value=.9
 for ob in COL.objects:
  ob['FusionBase']='Civic';ob['FusionAddon']=addon
 aero(i)
 if i<16:mechanical(i)
 else:phantom(i)
 s['FusionBase']='Civic';s['FusionAddon']=addon;s['Design']=plans[i];s['CleanRestored']=True;s['RuntimeIntegrated']=False
 s.render.resolution_x=840;s.render.resolution_y=600;s.render.resolution_percentage=100;s.cycles.samples=20;s.view_settings.exposure=-.3
 c=s.camera;c.data.type='ORTHO';c.data.ortho_scale=5.6 if i!=25 else 6.1;c.location=(5,-7,3.6);target=Vector((0,0,.65 if i<16 else .85));c.rotation_euler=(target-c.location).to_track_quat('-Z','Y').to_euler();s.render.filepath=str(P/(slug(addon)+'.png'))
 bpy.ops.object.select_all(action='DESELECT');bpy.context.view_layer.objects.active=bpy.data.objects['Honda_Civic_Body'];bpy.data.objects['Honda_Civic_Body'].select_set(True)
 bpy.ops.file.pack_all();bpy.ops.wm.save_as_mainfile(filepath=str(P/(slug(addon)+'.blend')));bpy.ops.render.render(write_still=True)
 print('CIVIC_DONE',i,addon,flush=True)
(P/'catalog.json').write_text(json.dumps([{'addon':n,'model':'Civic + '+n,'blend':slug(n)+'.blend','preview':slug(n)+'.png','design':plans[i],'cleanRestored':True,'sourceCatalogCommit':'f6e79c6','gameIntegrated':False}for i,n in enumerate(names)],indent=2))
