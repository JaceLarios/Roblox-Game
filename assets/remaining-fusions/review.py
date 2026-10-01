import bpy,json,math,sys
from pathlib import Path
from mathutils import Vector
P=Path(__file__).resolve().parent
manifest=json.loads((P/'vehicle-manifest.json').read_text())
bpy.ops.wm.open_mainfile(filepath=str(P/'Remaining-Fusions.blend'))
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=12
scene.render.resolution_x=640;scene.render.resolution_y=480;scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('Review');scene.world.use_nodes=True
scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.18,.21,.27,1)
scene.view_settings.view_transform='AgX'
bpy.ops.object.camera_add();cam=bpy.context.object;cam.data.type='ORTHO';scene.camera=cam
lights=[]
for pos,power in [((4,-6,8),1700),((-5,-1,5),1300),((2,6,8),2000)]:
 bpy.ops.object.light_add(type='AREA');o=bpy.context.object;o.data.energy=power;o.data.size=5;lights.append((o,Vector(pos)))
for i,s in enumerate(manifest):
 if '--pipes-only'in sys.argv and s['addon']!='Straight Pipes':continue
 for entry in manifest:bpy.data.collections[entry['name']].hide_render=entry['name']!=s['name']
 center=Vector((i%4*12,i//4*13,0));cam.data.ortho_scale=max(s['size'])*1.48
 for light,pos in lights:light.location=center+pos;light.rotation_euler=(center-light.location).to_track_quat('-Z','Y').to_euler()
 for suffix,pos in [('front',(7,-10,6)),('rear',(-7,10,6))]:
  path=P/(s['name'].replace(' ','_')+'-'+suffix+'.png')
  cam.location=center+Vector(pos);cam.rotation_euler=(center-cam.location).to_track_quat('-Z','Y').to_euler()
  scene.render.filepath=str(path);bpy.ops.render.render(write_still=True)
 print('REVIEWED',s['name'],flush=True)
