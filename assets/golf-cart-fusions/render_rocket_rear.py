import bpy,json
from pathlib import Path
from mathutils import Vector
p=Path(__file__).parent
bpy.ops.wm.open_mainfile(filepath=str(p/'Golf-Cart-Complete-15.blend'))
d=json.loads((p/'designs.json').read_text());m=json.loads((p/'manifest.json').read_text())
s=bpy.context.scene;s.render.engine='CYCLES';s.cycles.samples=24
s.render.resolution_x=900;s.render.resolution_y=700;s.render.resolution_percentage=100
s.world=bpy.data.worlds.new('Rear showcase');s.world.use_nodes=True;s.world.node_tree.nodes['Background'].inputs[0].default_value=(.14,.17,.20,1);s.view_settings.view_transform='AgX'
bpy.ops.object.camera_add();cam=bpy.context.object;s.camera=cam;cam.data.type='ORTHO'
lights=[];settings=[((3,5,7),1500,5),((-5,2,4),1000,5),((2,-5,7),1600,4)]
for loc,power,size in settings:
 bpy.ops.object.light_add(type='AREA');o=bpy.context.object;o.data.energy=power;o.data.shape='DISK';o.data.size=size;lights.append(o)
for i,spec in enumerate(d):
 if spec['name']!='Eagle Launcher':continue
 for other in d:bpy.data.collections[other['name']].hide_render=other['name']!=spec['name']
 center=Vector((i%3*9,i//3*10,0));cam.location=center+Vector((6,9,4.5));cam.data.ortho_scale=max(m[i]['size'])*1.5;cam.rotation_euler=(center-cam.location).to_track_quat('-Z','Y').to_euler()
 for o,(loc,power,size)in zip(lights,settings):o.location=center+Vector(loc);o.rotation_euler=(center-o.location).to_track_quat('-Z','Y').to_euler()
 s.render.filepath=str(p/(spec['name'].replace(' ','_')+'-rear.png'));bpy.ops.render.render(write_still=True)
