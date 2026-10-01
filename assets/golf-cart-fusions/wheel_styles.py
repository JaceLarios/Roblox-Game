# Distinct rotating wheel assemblies, with fixed brake calipers preserved.
_original_wheel=wheel
nt=M['Carbon'].node_tree;pbr=nt.nodes.get('Principled BSDF')
tc=nt.nodes.new('ShaderNodeTexCoord');mapping=nt.nodes.new('ShaderNodeVectorMath');mapping.operation='SCALE';mapping.inputs[3].default_value=85
nt.links.new(tc.outputs['Generated'],mapping.inputs[0])
checker=nt.nodes.new('ShaderNodeTexChecker');checker.inputs['Scale'].default_value=1
checker.inputs['Color1'].default_value=(.012,.018,.026,1);checker.inputs['Color2'].default_value=(.048,.061,.078,1)
nt.links.new(mapping.outputs[0],checker.inputs['Vector']);nt.links.new(checker.outputs['Color'],pbr.inputs['Base Color'])
bump=nt.nodes.new('ShaderNodeBump');bump.inputs['Strength'].default_value=.18;bump.inputs['Distance'].default_value=.003
nt.links.new(checker.outputs['Fac'],bump.inputs['Height']);nt.links.new(bump.outputs[0],pbr.inputs['Normal'])

def signature_wheel(x,y,z,r,width,accent,i,rear):
 start=len(MODELS[current]);side=1 if x>0 else -1;outer=x+side*width*.54
 _original_wheel(x,y,z,r,width,'Chrome',i in [2,8,14],5)
 # Replace stock spokes/hub with genuinely different wheel faces.
 for o in list(MODELS[current][start:]):
  if o.name.startswith(('Alloy spoke','Wheel hub','Hex fastener')):
   MODELS[current].remove(o);bpy.data.objects.remove(o,do_unlink=True)
 detail=len(MODELS[current])
 def ring(rad,thick,ma,offset=0):return tor('Signature rim ring',(outer+side*offset,y,z),r*rad,r*thick,ma,n=40)
 def disc(rad,ma,offset=0):return cyl('Signature wheel dish',(outer+side*offset,y,z),(outer+side*(offset+.026),y,z),r*rad,ma,n=40)
 def spoke(a,b,ma,width=.075):
  # Broad tapered, swept solid spoke, all corners modestly rounded.
  va=Vector((outer+side*.025,y+r*.15*math.sin(a),z+r*.15*math.cos(a)))
  vb=Vector((outer+side*.015,y+r*.55*math.sin(b),z+r*.55*math.cos(b)))
  o=box('Sculpted wheel spoke',tuple((va+vb)/2),(.06,width,(vb-va).length),ma,.018)
  o.rotation_euler=(vb-va).to_track_quat('Z','Y').to_euler()
 if i==0:
  disc(.51,'Steel');ring(.37,.045,'Rust',.03)
  for j in range(6):
   a=j*math.tau/6;cyl('Pressed steel recess',(outer+side*.029,y+r*.36*math.sin(a),z+r*.36*math.cos(a)),(outer+side*.033,y+r*.36*math.sin(a),z+r*.36*math.cos(a)),r*.075,'Black',n=12)
 elif i==1:
  ring(.79,.09,'Cream');disc(.40,'Chrome');ring(.47,.025,'Red',.03)
 elif i==2:
  for j in range(8):spoke(j*math.tau/8,j*math.tau/8,'Steel',.10)
  ring(.59,.055,accent,.035)
  for j in range(12):
   a=j*math.tau/12;bolt((outer+side*.065,y+r*.59*math.sin(a),z+r*.59*math.cos(a)),(side,0,0),.022)
 elif i==3:
  for j in range(4):spoke(j*math.tau/4,j*math.tau/4,'White',.15)
 elif i==4:
  for j in range(3):spoke(j*math.tau/3,j*math.tau/3+.40,'Chrome',.20)
  ring(.24,.035,accent,.04)
 elif i==5:
  for j in range(5):
   for split in [-.14,.14]:spoke(j*math.tau/5,j*math.tau/5+split,'Gold',.055)
 elif i==6:
  ring(.48,.075,'Chrome',-.025)
  for j in range(6):spoke(j*math.tau/6,j*math.tau/6+.12,accent,.12)
 elif i==7:
  if rear:
   disc(.50,'Chrome');ring(.36,.05,'Black',.04)
   for j in range(5):spoke(j*math.tau/5,j*math.tau/5,'Chrome',.12)
  else:
   for j in range(12):spoke(j*math.tau/12,j*math.tau/12,'Chrome',.032)
  ring(.85,.023,'Cream')
 elif i==8:
  disc(.52,'Steel');disc(.24,'Chrome',.055)
  for j in range(8):
   a=j*math.tau/8;bolt((outer+side*.075,y+r*.34*math.sin(a),z+r*.34*math.cos(a)),(side,0,0),.035)
 elif i==9:
  for j in range(7):
   for split in [-.20,.20]:spoke(j*math.tau/7,j*math.tau/7+split,'Gold',.042)
 elif i==10:
  for j in range(15):spoke(j*math.tau/15,j*math.tau/15+.18,'Chrome',.040)
  ring(.57,.035,'Gold',.02)
 elif i==12:
  for j in range(9):spoke(j*math.tau/9,j*math.tau/9+.42,'Titanium',.115)
  ring(.60,.035,accent,.02)
 elif i==13:
  disc(.53,'Carbon')
  for j in range(5):spoke(j*math.tau/5,j*math.tau/5+.32,'Chrome',.10)
  ring(.52,.025,'Gold',.045)
 elif i==14:
  for j in range(6):spoke(j*math.tau/6,j*math.tau/6+.30,'Carbon',.17)
  ring(.54,.035,'Energy',.04);ring(.32,.02,'Energy',.045)
 disc(.14,'Chrome' if i<9 else 'Gold',.055)
 for o in MODELS[current][detail:]:
  o['WheelCenterY']=y;o['WheelPivot']=[x,y,z];o['WheelRadius']=r;o['WheelId']=f'{x:.3f}_{y:.3f}'
