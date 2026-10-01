from pathlib import Path
exec(Path('outputs/game-polish-20260930/fusion_cinematic_v2.py').read_text().split("for kind,title in enumerate")[0])
import numpy as np
for i in [1,2,3]:
 bpy.ops.wm.open_mainfile(filepath=os.path.join(ROOT,f'cinematic-{i}.blend'));s=bpy.context.scene;s.frame_set(1)
 fire=mat('Hot welding burst',(1,.18,.015),.1,9);arc=mat('Electric impact',(0.02,.48,1),.1,12);metal=mat('Flying titanium',(.3,.4,.52),.9);gold=mat('Hot metal fragments',(1,.57,.05),.5,3)
 car=bpy.data.objects['CAR - actual Toro']
 for f,z,tilt in [(1,0,0),(109,0,0),(117,-.035,0),(126,.25 if i==3 else .11,-.035),(135,.04,.018),(145,0,0),(192,0,0)]:key(car,f,loc=(0,0,z),rot=(tilt,0,0))
 # A single strong blast with layered circular pressure fronts.
 for k in range(4):
  o=ring('Impact pressure front',(0,0,.25+k*.18),1,arc if k%2 else fire)
  for f,scale in [(1,0),(121+k,0),(124+k,.6),(133+k,5.5+k),(140+k,0)]:key(o,f,scale=(scale,scale,max(.05,scale*.15)))
 for k in range(64):
  a=random.random()*math.tau;r=random.uniform(3,6);origin=Vector((math.cos(a)*.8,math.sin(a)*.8,.6));direction=Vector((math.cos(a)*r,math.sin(a)*r,random.uniform(.3,2.4)))
  o=cube('Impact streak',origin,(.025,.025,random.uniform(.3,.8)),fire if k%2 else arc,bevel=0);o.rotation_euler=direction.to_track_quat('Z','Y').to_euler()
  f=122+k%5;key(o,1,scale=(0,0,0));key(o,f,loc=origin,scale=(0,0,0));key(o,f+2,scale=(1,1,1));key(o,f+10,loc=origin+direction,scale=(.35,.35,1.4));key(o,f+18,scale=(0,0,0))
 for k in range(20):
  a=k*math.tau/20;o=cyl('Spinning hex bolt',(0,0,0),(0,0,.16),.075,metal,vertices=6)
  key(o,1,scale=(0,0,0));key(o,52,loc=(math.cos(a)*2.1,math.sin(a)*2.1,1.5),scale=(1,1,1));key(o,103,loc=(math.cos(a+1.1)*1.7,math.sin(a+1.1)*1.7,1.5),rot=(2,4,3));key(o,119,loc=(math.cos(a)*.5,math.sin(a)*.7,.9),scale=(.3,.3,.3));key(o,126,scale=(0,0,0))
 # Exaggerated exhaust fire lives behind the car, preserving its silhouette.
 for side in [-1,1]:
  for k in range(6):
   bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1,radius=1,location=(side*.4,2.1+k*.18,.5));o=bpy.context.object;o.name='Exhaust fire pulse';o.data.materials.append(arc if k<2 else fire)
   f=122+k;key(o,1,scale=(0,0,0));key(o,f,scale=(.08,.12,.08));key(o,f+3,scale=(.16,.45,.17));key(o,f+10,scale=(0,0,0))
 for o in s.objects:
  if o.type=='LIGHT' and o.data.type=='POINT':
   for f,e in [(120,0),(124,18000),(128,1800),(136,0)]:o.data.energy=e;o.data.keyframe_insert('energy',frame=f)
 cam=s.camera
 for f,pos,target in [(110,(4.4,-6.1,2.4),(0,0,1)),(121,(3.9,-5.8,2.2),(0,0,.95)),(125,(5.6,-7.6,3.2),(0,0,.9)),(127,(5.4,-7.4,3.0),(.08,0,.84)),(130,(5.6,-7.5,3.1),(-.03,0,.9)),(138,(5.8,-7.7,3),(0,0,.8))]:
  cam.location=pos;cam.rotation_euler=(Vector(target)-cam.location).to_track_quat('-Z','Y').to_euler();cam.keyframe_insert('location',frame=f);cam.keyframe_insert('rotation_euler',frame=f)
 with wave.open(os.path.join(ROOT,f'cinematic-{i}.wav'),'rb')as w:sr=w.getframerate();x=np.frombuffer(w.readframes(w.getnframes()),dtype='<i2').reshape(-1,2).astype(float)/32768
 t=np.arange(len(x))/sr;q=t-5.13;mask=q>=0;z=np.maximum(q,0);rng=np.random.default_rng(230+i)
 punch=(.40*np.sin(2*np.pi*(48*z-6*z*z))+.19*rng.normal(size=len(t)))*np.exp(-8*z)*mask
 clang=.08*(np.sin(2*np.pi*733*z)+.45*np.sin(2*np.pi*1231*z))*np.exp(-5*z)*mask
 x[(t>4.98)&(t<5.1)]*=.22;x+=np.stack([punch+clang,punch+clang],axis=1);x=np.tanh(x*1.1)*.92
 wav=os.path.join(ROOT,f'explosive-{i}.wav')
 with wave.open(wav,'wb')as w:w.setnchannels(2);w.setsampwidth(2);w.setframerate(sr);w.writeframes((x*32767).astype('<i2').tobytes())
 s.sequence_editor_clear();s.sequence_editor_create().strips.new_sound('Engine, tools, fusion impact',wav,channel=1,frame_start=1)
 s.render.filepath=os.path.join(ROOT,f'explosive-{i}.mp4');s.render.use_persistent_data=True;s.cycles.samples=24
 bpy.ops.wm.save_as_mainfile(filepath=os.path.join(ROOT,f'explosive-{i}.blend'))
