import bpy,math,json,random,hashlib
from pathlib import Path
from mathutils import Vector,Matrix
from collections import defaultdict
OUT=Path(__file__).parent
reference=(OUT/'base-builder-reference.py').read_text()
prefix=reference[:reference.index('# 1. Stable Rusted Sedan')]
prefix=prefix.replace("OUT.parent.parent/'new-addons/v2/textures'","OUT.parent/'new-addons/v2/textures'")
exec(prefix)
mat('Lemon','FFD52B','Enamel',.25,.3)
mat('Purple','A33BF0','Enamel',.3,.3)
mat('Copper','E39142','Brushed',.7,.4)
mat('Carbon','27323F','Carbon',.5,.36)
exec((OUT/'wheel_styles.py').read_text())
mat('Energy','43EAFF','Light',.2,.3,1.8)
designs=json.loads((OUT/'designs.json').read_text())
def hollow(name,a,b,r,ma='Chrome',inner='Iron'):
 a,b=Vector(a),Vector(b);v=(b-a).normalized();u=v.cross(Vector((1,0,0)) if abs(v.x)<.9 else Vector((0,1,0))).normalized();w=v.cross(u)
 vertices=[tuple(p+rr*(u*math.cos(j*math.tau/32)+w*math.sin(j*math.tau/32)))for p,rr in [(a,r),(b,r),(b,r*.79),(a,r*.79)]for j in range(32)]
 for k,m in [(0,ma),(1,ma),(2,inner)]:
  o=mesh(name,vertices,[(k*32+j,k*32+(j+1)%32,(k+1)*32+(j+1)%32,(k+1)*32+j)for j in range(32)],m)
  for f in o.data.polygons:f.use_smooth=True
 tor(name+' rolled lip',b,r*.91,r*.095,ma,v,32)

def engine_block(p=(0,-1.05,1.29),cylinders=4,color='Blue',length=.94):
 x,y,z=p
 box('Engine mounting cradle',(x,y,z-.255),(.88,length+.12,.13),'Steel',.035)
 for xx in [-.32,.32]:
  for yy in [-length*.32,length*.32]:box('Engine cradle support',(x+xx,y+yy,(z-.31+.48)/2),(.085,.09,max(.08,z-.79)),'Iron',.015)
 box('Cast engine block',p,(.70,length,.40),'Iron',.08)
 box('Engine gasket',(x,y,z+.22),(.74,length,.055),'Rubber',.015)
 rows=1 if cylinders==4 else 2;each=cylinders//rows
 for side in range(rows):
  xx=x+(side-.5)*.42 if rows==2 else x
  box('Colored cylinder bank',(xx,y,z+.34),(.31 if rows==2 else .66,length*.91,.20),'Carbon' if cylinders==12 else color,.055)
  for j in range(each):
   yy=y-length*.37+j*length*.74/max(1,each-1)
   hollow('Individual intake trumpet',(xx,yy,z+.43),(xx,yy,z+.62),.072,'Red' if cylinders==12 else 'Chrome')
   bolt((xx+.10,yy,z+.46),r=.019)
 for side in [-1,1]:
  for j in range(3):pipe('Swept engine header',[(x+side*.34,y-.3+j*.25,z),(x+side*.51,y-.2+j*.25,z-.16),(x+side*.50,y+.50,z-.24)],.025,'Titanium')
 cyl('Belt pulley',(x,y-length/2-.06,z),(x,y-length/2-.13,z),.16,'Chrome',n=24)
 tor('Alternator belt',(x,y-length/2-.14,z),.15,.028,'Rubber',(0,1,0),24)

def turbo(x,y,z,r=.27):
 tor('Turbo snail housing',(x,y,z),r,.10,'Steel',(0,1,0),32)
 hollow('Compressor intake',(x,y-.06,z),(x,y-.22,z),r*.62,'Chrome')
 cyl('Turbo center',(x,y-.15,z),(x,y-.19,z),.04,'Copper',n=16)
 for j in range(9):
  a=j*math.tau/9
  cyl('Compressor blade',(x,y-.17,z),(x+r*.50*math.cos(a),y-.19,z+r*.50*math.sin(a)),.012,'Chrome',n=6)
 pipe('Compressor outlet',[(x+r*.8,y,z),(x+r*1.1,y+.08,z+.2),(x+r*.4,y+.35,z+.27)],.07,'Chrome')
 for j in range(5):
  a=j*math.tau/5;bolt((x+r*math.cos(a),y-.11,z+r*math.sin(a)),(0,-1,0),.025)

def wing(y=1.72,width=2.25,height=1.55,ma='Carbon'):
 for x in [-.63,.63]:box('Wing upright',(x,y,(height+.69)/2),(.09,.14,height-.69),'Iron',.025)
 box('Rounded aero wing',(0,y,height),(width,.42,.095),ma,.04,rot=(-.1,0,0))
 for x in [-width/2,width/2]:box('Wing endplate',(x,y,height+.04),(.055,.47,.24),accent,.045)

def sill(width=1.10):
 for side in [-1,1]:
  loft('Sculpted sidepod',[( -.75, .14,.0,.13,.18),(.45,.20,.0,.20,.25),(.95,.13,.0,.13,.18)],accent).location=(side*width,0,.52)
  for y in [-.42,-.24,-.06]:box('Sidepod vent',(side*(width+.14),y,.66),(.035,.11,.12),'Black',.015)

def canopy(gt=False):
 front=-.52;back=.95;roofz=2.10 if gt else 1.99
 for side in [-1,1]:
  pipe('Cabin pillar seam',[(side*.77,front,1.10),(side*.64,-.22,roofz),(side*.67,back,roofz),(side*.80,1.15,1.01)],.042,paint)
 box('Curved cabin roof',(0,.35,roofz),(1.40,1.44,.11),paint,.10)
 quad('Panoramic windscreen',[(-.74,front,1.20),(.74,front,1.20),(.62,-.23,roofz-.03),(-.62,-.23,roofz-.03)],'Glass',True)
 if gt:
  for side in [-1,1]:quad('GT side glazing',[(side*.75,-.48,1.2),(side*.78,.91,1.2),(side*.65,.89,roofz-.03),(side*.65,-.20,roofz-.03)],'Glass',True)

def turbine(x,y,z,r=.43,length=1.1,rocket=False):
 cyl('Turbine armored barrel',(x,y-length/2,z),(x,y+length/2,z),r,'Steel',n=40)
 for yy in [y-length*.45,y,y+length*.44]:tor('Turbine reinforcement',(x,yy,z),r,.035,accent,(0,1,0),32)
 if rocket:
  cyl('Rocket combustion chamber',(x,y-.45,z),(x,y+.30,z),r*.78,paint,n=32)
  hollow('Rocket bell nozzle',(x,y+.30,z),(x,y+length*.78,z),r*1.1,'Titanium')
  tor('Rocket nozzle heat band',(x,y+length*.77,z),r*1.01,.035,'HeatBlue',(0,1,0),32)
 else:
  hollow('Jet intake mouth',(x,y-length*.54,z),(x,y-length*.68,z),r*1.04,'Chrome')
  for j in range(13):
   a=j*math.tau/13
   q=[(x+.06*math.cos(a),y-length*.68,z+.06*math.sin(a)),(x+r*.87*math.cos(a+.16),y-length*.67,z+r*.87*math.sin(a+.16)),(x+r*.87*math.cos(a+.38),y-length*.70,z+r*.87*math.sin(a+.38))]
   mesh('Jet fan blade',q,[(0,1,2)],'Chrome')
  cyl('Jet spinner',(x,y-length*.66,z),(x,y-length*.82,z),.13,'Iron',r2=.018,n=24)
  hollow('Jet afterburner outlet',(x,y+length*.50,z),(x,y+length*.70,z),r*.83,'Iron')
 tor('Engine energy rim',(x,y+length*.70,z),r*.73,.025,'Energy',(0,1,0),32)

def fin(x,y,z,ma,height=.65):
 pts=[(x,y-.35,z),(x,y+.42,z),(x,y+.35,z+height),(x,y+.10,z+height*.8)]
 o=quad('Sculpted tail fin',pts,ma);sol=o.modifiers.new('Fin thickness','SOLIDIFY');sol.thickness=.065;b=o.modifiers.new('Soft fin edges','BEVEL');b.width=.028;b.segments=3

def sphere(name,p,r,ma):
 verts=[];faces=[];N=24;K=12
 for k in range(K+1):
  theta=math.pi*k/K
  for j in range(N):a=math.tau*j/N;verts.append((p[0]+r*math.sin(theta)*math.cos(a),p[1]+r*math.sin(theta)*math.sin(a),p[2]+r*math.cos(theta)))
 for k in range(K):
  for j in range(N):faces.append((k*N+j,k*N+(j+1)%N,(k+1)*N+(j+1)%N,(k+1)*N+j))
 o=mesh(name,verts,faces,ma)
 for f in o.data.polygons:f.use_smooth=True


exec((OUT/'hero_family.py').read_text())
exec((OUT/'complete_family.py').read_text())
exec((OUT/'cart_identity.py').read_text())
for index,spec in enumerate(designs):
 paint=spec['color'];accent=spec['accent'];build_golf(spec,index);restore_cart_identity(spec,index)

print('EVALUATING FUSION MODELS',flush=True)
bpy.context.view_layer.update();dg=bpy.context.evaluated_depsgraph_get();evaluated=[]
for name,objects in MODELS.items():
 for o in objects:evaluated.append((name,o,bpy.data.meshes.new_from_object(o.evaluated_get(dg)),o.matrix_world.copy(),{k:(list(v)if k=='WheelPivot' else v)for k,v in o.items()}))
for name in MODELS:MODELS[name]=[]
for name,old,me,matrix,attrs in evaluated:
 label=old.name;bpy.data.objects.remove(old,do_unlink=True);o=bpy.data.objects.new(label,me);bpy.data.collections[name].objects.link(o);MODELS[name].append(o)
 for v in me.vertices:v.co=matrix@v.co
 for k,v in attrs.items():o[k]=v
 me.update()

manifest=[]
for index,spec in enumerate(designs):
 name=spec['name'];objects=MODELS[name];points=[v.co for o in objects for v in o.data.vertices]
 lo=Vector([min(v[i]for v in points)for i in range(3)]);hi=Vector([max(v[i]for v in points)for i in range(3)]);center=(lo+hi)/2
 scale=1.18*1.2;size=(hi-lo)*scale
 groups={};counters=defaultdict(int)
 for o in objects:
  for v in o.data.vertices:v.co=(v.co-center)*scale
  o.data.update();ma=o.data.materials[0].name;me=o.data;me.calc_loop_triangles();bucket=ma+'_'+o.get('WheelId','Body');key=f'{bucket}_{counters[bucket]}'
  if key in groups and len(groups[key]['triangles'])+len(me.loop_triangles)>18000:counters[bucket]+=1;key=f'{bucket}_{counters[bucket]}'
  if key not in groups:groups[key]={'name':key,'material':META[ma],'vertices':[],'normals':[],'triangles':[],'components':[]}
  g=groups[key];g['components'].append(o.name)
  if 'WheelPivot' in o:
   wp=(Vector(o['WheelPivot'])-center)*scale;g['wheel']={'id':o['WheelId'],'pivot':[wp.x,wp.z,-wp.y],'radius':o['WheelRadius']*scale}
   o['WheelPivot']=list(wp);o['WheelRadius']*=scale
  lookup={}
  for tri in me.loop_triangles:
   vv=[me.vertices[i].co for i in tri.vertices];normal=(vv[1]-vv[0]).cross(vv[2]-vv[0])
   if normal.length<1e-10:continue
   normal.normalize();ids=[]
   for li in tri.loops:
    v=me.vertices[me.loops[li].vertex_index].co;n=me.corner_normals[li].vector.normalized()
    if n.length<.5:n=normal
    vp=tuple(round(a,5)for a in (v.x,v.z,-v.y));np=tuple(round(a,5)for a in(n.x,n.z,-n.y));k=vp+np
    if k not in lookup:lookup[k]=len(g['vertices']);g['vertices'].append(vp);g['normals'].append(np)
    ids.append(lookup[k])
   if len(set(ids))==3:g['triangles'].append(ids)
 for g in groups.values():
  lo=[min(v[i]for v in g['vertices'])for i in range(3)];hi=[max(v[i]for v in g['vertices'])for i in range(3)];mid=[(a+b)/2 for a,b in zip(lo,hi)]
  centered=[[round(v[i]-mid[i],4)for i in range(3)]for v in g['vertices']]
  g['geometryHash']=hashlib.sha256(json.dumps([[[round(x,3)+0 for x in v]for v in centered],[[round(x,3)+0 for x in v]for v in g['normals']],g['triangles']],separators=(',',':')).encode()).hexdigest()
 data={'name':name,'displayName':name,'rarity':spec['rarity'],'addon':spec['addon'],'targetSize':[size.x,size.z,size.y],'parts':list(groups.values()),'authoredComponents':len(objects),'noseAxis':'+Z','layout':spec.get('layout','')}
 data['fitScaleToBase']=1.2
 if name=='Atomic Albatross':
  ec=(Vector((0,-1.05,1.16))-center)*scale;data['reactorEffectCenter']=[ec.x,ec.z,-ec.y]
 file=name.replace(' ','_')+'.json';(OUT/file).write_text(json.dumps(data,separators=(',',':')))
 manifest.append({'name':name,'file':file,'rarity':spec['rarity'],'size':data['targetSize'],'parts':len(groups),'triangles':sum(len(g['triangles'])for g in groups.values())})
 bpy.data.collections[name]['FitScaleToBase']=1.2
 for o in objects:o.location=Vector((index%3*9,index//3*10,0))
(OUT/'manifest.json').write_text(json.dumps(manifest,indent=2))
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'Golf-Cart-Recognizable-15.blend'))
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=24;scene.render.resolution_x=900;scene.render.resolution_y=700;scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('Fusion showcase');scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.14,.17,.20,1);scene.view_settings.view_transform='AgX'
bpy.ops.object.camera_add();cam=bpy.context.object;scene.camera=cam;cam.data.type='ORTHO';lights=[];settings=[((3,-5,7),1500,5),((-5,-2,4),1000,5),((2,5,7),1600,4)]
for loc,power,size in settings:
 bpy.ops.object.light_add(type='AREA');o=bpy.context.object;o.data.energy=power;o.data.shape='DISK';o.data.size=size;lights.append(o)
for index,spec in enumerate(designs):
 name=spec['name']
 for n in MODELS:bpy.data.collections[n].hide_render=n!=name
 center=Vector((index%3*9,index//3*10,0));cam.data.ortho_scale=max(manifest[index]['size'])*1.42;cam.location=center+Vector((6,-9,5));cam.rotation_euler=(center-cam.location).to_track_quat('-Z','Y').to_euler()
 for o,(loc,power,size)in zip(lights,settings):o.location=center+Vector(loc);o.rotation_euler=(center-o.location).to_track_quat('-Z','Y').to_euler()
 scene.render.filepath=str(OUT/(name.replace(' ','_')+'.png'));bpy.ops.render.render(write_still=True)
print('FIFTEEN_FUSIONS_COMPLETE',flush=True)
