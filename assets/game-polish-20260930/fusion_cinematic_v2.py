import bpy,math,os,random,wave,struct
from mathutils import Vector, Matrix
ROOT=os.path.dirname(os.path.abspath(__file__));BASE=os.path.join(ROOT,'Toro-Closed-Kit-v14.blend')
ADDONS=os.path.abspath('outputs/new-addons/v2/Junkyard-Fusion-10-Addons-Textured.blend')
FPS=24;END=192
random.seed(440)
def mat(name,c,metal=0,glow=0):
 m=bpy.data.materials.new(name);m.diffuse_color=(*c,1);m.use_nodes=True;p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*c,1);p.inputs['Metallic'].default_value=metal;p.inputs['Roughness'].default_value=.3;p.inputs['Emission Color'].default_value=(*c,1);p.inputs['Emission Strength'].default_value=glow;return m
def empty(name):
 o=bpy.data.objects.new(name,None);bpy.context.collection.objects.link(o);return o
def cube(name,loc,size,m,parent=None,bevel=.025):
 bpy.ops.mesh.primitive_cube_add(size=1,location=loc);o=bpy.context.object;o.name=name;o.dimensions=size;bpy.ops.object.transform_apply(location=False,rotation=False,scale=True);o.data.materials.append(m)
 if bevel:b=o.modifiers.new('Machined edge','BEVEL');b.width=bevel;b.segments=2;o.modifiers.new('Normals','WEIGHTED_NORMAL')
 o.parent=parent;return o
def cyl(name,a,b,r,m,parent=None,vertices=20):
 a,b=Vector(a),Vector(b);d=b-a;bpy.ops.mesh.primitive_cylinder_add(vertices=vertices,radius=r,depth=d.length,location=(a+b)/2);o=bpy.context.object;o.name=name;o.rotation_euler=d.to_track_quat('Z','Y').to_euler();o.data.materials.append(m);o.parent=parent
 for f in o.data.polygons:f.use_smooth=True
 return o
def ring(name,loc,r,m,parent=None):
 bpy.ops.mesh.primitive_torus_add(major_radius=r,minor_radius=.022,major_segments=64,minor_segments=6,location=loc);o=bpy.context.object;o.name=name;o.data.materials.append(m);o.parent=parent;return o
def key(o,f,loc=None,rot=None,scale=None):
 for name,v in [('location',loc),('rotation_euler',rot),('scale',scale)]:
  if v is not None:setattr(o,name,v);o.keyframe_insert(name,frame=f)
def text(txt,loc,size,m):
 cu=bpy.data.curves.new(txt,'FONT');cu.body=txt;cu.align_x='CENTER';cu.size=size;cu.extrude=.002;o=bpy.data.objects.new(txt,cu);bpy.context.collection.objects.link(o);o.location=loc;o.rotation_euler=(math.pi/2,0,0);o.data.materials.append(m);return o
def audio(path,kind):
 import numpy as np
 sr=44100;t=np.arange(sr*8)/sr;rng=np.random.default_rng(43+kind);L=np.zeros_like(t);R=np.zeros_like(t)
 def hit(at,dur,f,amp,noise=0,pan=0):
  q=t-at;mask=(q>=0)&(q<dur);z=q[mask];v=amp*np.exp(-5*z/dur)*(np.sin(2*np.pi*(f*z-5*z*z))+noise*rng.normal(size=len(z)));L[mask]+=v*(1-pan*.45);R[mask]+=v*(1+pan*.45)
 for at,pan in [(.7,-.8),(1.0,.8),(1.6,-.6),(2.1,.6)]:hit(at,.25,105,.22,.8,pan)
 for at in np.arange(2.35,4.55,.18 if kind==0 else .29):hit(at,.09,310,.09,1.1,math.sin(at*4))
 q=np.maximum(0,t-1.6);env=np.clip(q/.7,0,1)*np.clip((5.3-t)/.4,0,1)
 phase=2*np.pi*(45*q+18*q*q+3*q*q*q);motor=(np.sin(phase)+.3*np.sin(phase*2)+.15*np.sin(phase*4))*.14*env
 L+=motor;R+=motor
 if kind==2:
  whine=np.sin(2*np.pi*(350*t+95*t*t))*.07*env;L+=whine;R+=whine
 hit(5.15,.8,48,.42,1);hit(5.2,1.1,90,.22,.15)
 for at,f in [(5.42,523.25),(5.57,659.25),(5.73,783.99),(5.9,1046.5)]:hit(at,1.2,f,.105,0)
 if kind==1:
  for at in [5.0,5.2,5.4]:hit(at,.2,70,.20,1.8)
 x=np.stack([L,R],axis=1);x=np.tanh(x*.85);x*=np.minimum(t/.06,1)[:,None]*np.minimum((8-t)/.12,1)[:,None]
 with wave.open(path,'wb')as w:w.setnchannels(2);w.setsampwidth(2);w.setframerate(sr);w.writeframes((x*30000).astype('<i2').tobytes())
for kind,title in enumerate(['PIT FORGE','REDLINE OVERLOAD','MAGNETIC ASSEMBLY']):
 bpy.ops.wm.open_mainfile(filepath=BASE);s=bpy.context.scene
 for o in list(s.objects):
  if o.type in {'LIGHT','CAMERA'}or o.name=='Preview Floor':bpy.data.objects.remove(o,do_unlink=True)
 car=empty('CAR - actual Toro');wheels={}
 for o in list(s.objects):
  if o.type!='MESH':continue
  o.parent=car
  if o.name.startswith('Toro Three Piece')or o.name.startswith('Toro Star'):
   bb=[o.matrix_world@Vector(v)for v in o.bound_box];c=sum(bb,Vector())/8
   front=c.y<0;side=1 if c.x>0 else -1;k=(front,side)
   if k not in wheels:
    axle=empty('Animated wheel '+str(k));axle.location=(side*(1.056 if front else 1.071),-1.179 if front else 1.48,.35 if front else .364);axle.parent=car;wheels[k]=axle
   world=o.matrix_world.copy();o.parent=wheels[k];o.matrix_parent_inverse=Matrix.Translation(-wheels[k].location);o.matrix_basis=world
 # The original imported shell remains intact; addon is a distinct, readable assembly.
 with bpy.data.libraries.load(ADDONS,link=False)as (a,b):b.collections=['Supercharger' if kind==0 else 'Twin Turbo' if kind==1 else 'Fusion Core']
 col=b.collections[0];s.collection.children.link(col);addon=empty('ADDON - actual game model')
 obs=list(col.all_objects);pts=[o.matrix_world@Vector(c)for o in obs if o.type=='MESH' for c in o.bound_box];lo=Vector(tuple(min(v[i]for v in pts)for i in range(3)));hi=Vector(tuple(max(v[i]for v in pts)for i in range(3)));center=(lo+hi)/2;factor=1.3/max(hi-lo)
 mats={o:o.matrix_world.copy() for o in obs}
 for o in obs:
  o.parent=addon;o.matrix_parent_inverse=Matrix.Identity(4);o.matrix_basis=Matrix.Scale(factor,4)@Matrix.Translation(-center)@mats[o]
 navy=mat('Workshop enamel',(.014,.025,.05),.5);steel=mat('Brushed steel',(.22,.29,.37),.85);gold=mat('Safety amber',(1,.31,.018),.55);cyan=mat('Tool arc',(.015,.58,1),.25,7);mint=mat('Ready',(0.02,1,.47),.1,5);red=mat('Redline',(1,.035,.012),.1,6);white=mat('White',(.72,.86,1),0,2)
 cube('Workshop floor',(0,0,-.16),(16,18,.25),navy)
 cube('Lift bed',(0,0,-.02),(3,5.4,.14),steel)
 for x in [-1.42,1.42]:
  cube('Lift runway',(x,0,.04),(.11,5.2,.1),cyan)
  for y in [-2.4,2.4]:cube('Corner clamp',(x,y,.13),(.45,.5,.2),gold)
 for x in range(-7,8):cube('Floor seam',(x,0,-.026),(.014,16,.004),steel,bevel=0)
 for y in range(-7,8):cube('Floor seam',(0,y,-.024),(14,.014,.004),steel,bevel=0)
 for x in [-4.6,4.6]:
  cube('Hydraulic tower',(x,1,1.9),(.45,.55,3.8),navy)
  cube('Tower strip',(x,.7,2.0),(.055,.04,3.4),cyan)
  for z in [.4,.8,1.2]:cube('Warning stripe',(x,.7,z),(.46,.025,.10),gold)
 cube('Back wall',(0,5.8,2.1),(14,.2,4.5),navy)
 for x in [-5,-3,3,5]:cube('Wall light',(x,5.66,2.8),(.12,.06,2.7),cyan)
 text(title,(0,5.56,3.42),.48,white);text('JUNKYARD FUSION / BUILD SEQUENCE',(0,5.54,3.02),.16,gold)
 # Floor-to-ceiling scanner gives the merge a mechanical focal point.
 hoop=ring('Diagnostic halo',(0,0,.25),2.1,cyan)
 key(hoop,1,scale=(.1,.1,.1));key(hoop,32,scale=(1,1,1),loc=(0,0,.15));key(hoop,100,loc=(0,0,2.1));key(hoop,122,loc=(0,0,.15));key(hoop,132,scale=(2.4,2.4,2.4));key(hoop,145,scale=(0,0,0))
 key(addon,1,loc=(-3,0,.9),scale=(1,1,1));key(addon,42,loc=(0,.65,2.7),rot=(0,0,.3));key(addon,94,loc=(0,.65,1.75),rot=(0,0,0));key(addon,123,loc=(0,.65,1.4),scale=(.8,.8,.8));key(addon,130,scale=(.001,.001,.001))
 if kind==0:
  # Articulated pistons, swivel heads and rotating impact sockets, not floating sticks.
  for side in [-1,1]:
   for y in [-.95,1.15]:
    arm=empty('Torque robot');arm.location=(side*3.1,y,0)
    cyl('Pedestal',(0,0,0),(0,0,.45),.34,steel,arm)
    cyl('Shoulder pin',(-.22,0,.65),(.22,0,.65),.19,gold,arm)
    cyl('Lower arm',(0,0,.65),(-side*.45,0,1.65),.15,gold,arm)
    cyl('Hydraulic ram',(side*.1,.12,.5),(-side*.3,.12,1.35),.07,steel,arm)
    cyl('Elbow',(-side*.45,-.18,1.65),(-side*.45,.18,1.65),.19,steel,arm)
    cyl('Upper arm',(-side*.45,0,1.65),(-side*1.25,0,1.0),.12,gold,arm)
    cyl('Impact socket',(-side*1.25,0,1),(-side*1.5,0,1),.12,cyan,arm)
    key(arm,1,loc=(side*3.7,y,0));key(arm,52,loc=(side*2.5,y,0));key(arm,113,loc=(side*2.5,y,0));key(arm,132,loc=(side*3.8,y,0))
  cube('Hoist rail',(0,.7,3.75),(6,.16,.24),steel)
  hook=cyl('Hoist cable',(0,.65,2.9),(0,.65,3.7),.018,steel);key(hook,1,scale=(1,1,1));key(hook,123,scale=(1,1,.15));key(hook,130,scale=(0,0,0))
 elif kind==1:
  for x in [-1.05,1.05]:
   for y in [-1.18,1.48]:
    for yy in [-.2,.2]:cyl('Dyno drum',(x-.35,y+yy,.05),(x+.35,y+yy,.05),.15,steel)
  for i in range(22):
   x=-3.2+i*.30;bar=cube('RPM meter',(x,5.53,1.9),(.21,.10,.44),mint if i<14 else gold if i<19 else red)
   key(bar,1,scale=(1,1,.04));key(bar,28+i*3,scale=(1,1,1));key(bar,129,scale=(1,1,.12))
  for axle in wheels.values():key(axle,24,rot=(0,0,0));key(axle,122,rot=(30*math.pi,0,0));key(axle,160,rot=(35*math.pi,0,0))
  for side in [-1,1]:
   for j in range(8):
    o=cube('Exhaust pulse',(side*.38,2.1+j*.08,.48),(.15,.22,.15),red,bevel=.06)
    key(o,1,scale=(0,0,0));key(o,112+j,scale=(1,1+j*.3,1));key(o,136+j,scale=(0,0,0))
 else:
  for (front,side),axle in wheels.items():
   rest=axle.location.copy();key(axle,1,loc=rest);key(axle,52,loc=rest+Vector((side*.75,0,.3)),rot=(0,.3*side,0));key(axle,110,loc=rest+Vector((side*.75,0,.3)),rot=(math.pi*2,.3*side,0));key(axle,124,loc=rest,rot=(math.pi*2,0,0))
  for i in range(3):
   o=ring('Magnetic field',(0,0,.5+i*.45),2.45,cyan if i%2==0 else mint)
   key(o,1,scale=(.01,.01,.01));key(o,55,scale=(1,1,1),rot=(.15*i,.22*i,0));key(o,119,scale=(.65,.65,.65),rot=(.1,-.1,math.pi*2));key(o,133,scale=(2,2,2));key(o,144,scale=(0,0,0))
  for i in range(16):
   a=i*math.tau/16;o=cube('Magnetic fastener',(0,0,0),(.055,.055,.12),gold,bevel=.01)
   key(o,1,scale=(0,0,0));key(o,58,scale=(1,1,1),loc=(math.cos(a)*2.4,math.sin(a)*2.4,1.5));key(o,108,loc=(math.cos(a+2)*2.1,math.sin(a+2)*2.1,1.3));key(o,124,loc=(math.cos(a)*.75,math.sin(a)*.9,.8));key(o,130,scale=(0,0,0))
 # Timed welding showers and the final radial blast, tapered streak meshes.
 for i in range(90):
  a=random.random()*math.tau;z=random.uniform(.4,1.8);r=random.uniform(1.2,3.4);o=cube('Weld spark',(0,0,0),(.012,.012,random.uniform(.04,.14)),gold if i%3 else cyan,bevel=0)
  f=55+i%48 if i<45 else 122+i%5
  origin=Vector(((1 if i%2 else -1)*1.1,random.uniform(-1.3,1.3),.75)) if i<45 else Vector((0,0,.8))
  key(o,1,scale=(0,0,0));key(o,f,loc=origin,scale=(0,0,0));key(o,f+2,scale=(1,1,1));key(o,f+12,loc=origin+Vector((math.cos(a)*r,math.sin(a)*r,z)),scale=(.4,.4,.4));key(o,f+19,scale=(0,0,0))
 # Reveal lighting: strong, brief pulse followed by readable showroom light.
 bpy.ops.object.light_add(type='POINT',location=(0,0,2.2));pulse=bpy.context.object;pulse.data.color=(.08,.7,1)
 for f,e in [(1,0),(120,0),(125,1600),(131,250),(146,0)]:pulse.data.energy=e;pulse.data.keyframe_insert('energy',frame=f)
 for pos,power,size,c in [((2,-4,6),1400,5,(.7,.85,1)),((-4,-1,3),1100,4,(.15,.6,1)),((0,4,5),1900,4,(1,.45,.14))]:
  bpy.ops.object.light_add(type='AREA',location=pos);l=bpy.context.object;l.data.energy=power;l.data.shape='DISK';l.data.size=size;l.data.color=c;l.rotation_euler=(Vector((0,0,.7))-l.location).to_track_quat('-Z','Y').to_euler()
 bpy.ops.object.camera_add();cam=bpy.context.object;s.camera=cam;cam.data.lens=43
 for f,pos,target in [(1,(7,-9,4.2),(0,0,.9)),(45,(5.6,-7.4,3.4),(0,0,1.1)),(95,(4.8,-6.9,2.8),(0,.3,1)),(120,(4.5,-6.8,2.45),(0,0,.85)),(127,(5.4,-7.5,3),(0,0,.8)),(160,(6,-8,3.1),(0,0,.7)),(192,(7,-7,2.8),(0,0,.7))]:
  cam.location=pos;cam.rotation_euler=(Vector(target)-cam.location).to_track_quat('-Z','Y').to_euler();cam.keyframe_insert('location',frame=f);cam.keyframe_insert('rotation_euler',frame=f)
 s.world.use_nodes=True;s.world.node_tree.nodes['Background'].inputs[0].default_value=(.014,.022,.045,1);s.world.node_tree.nodes['Background'].inputs[1].default_value=.3
 s.render.engine='CYCLES';s.cycles.samples=12;s.cycles.use_denoising=True;s.render.resolution_x=960;s.render.resolution_y=540;s.render.resolution_percentage=100;s.render.fps=FPS;s.frame_start=1;s.frame_end=END
 s.render.use_sequencer=True;s.sequence_editor_clear();wav=os.path.join(ROOT,f'cinematic-{kind+1}.wav');audio(wav,kind);s.sequence_editor_create().strips.new_sound('Mechanical SFX mix',wav,channel=1,frame_start=1)
 s.render.image_settings.media_type='VIDEO';s.render.ffmpeg.format='MPEG4';s.render.ffmpeg.codec='H264';s.render.ffmpeg.audio_codec='AAC';s.render.filepath=os.path.join(ROOT,f'cinematic-{kind+1}.mp4')
 bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT,f'cinematic-{kind+1}.blend'))
 s.frame_set(132);s.render.image_settings.media_type='IMAGE';s.render.image_settings.file_format='PNG';s.render.filepath=os.path.join(ROOT,f'cinematic-{kind+1}.png');bpy.ops.render.render(write_still=True)
 # Render separately so setup failures cannot discard completed concepts.

