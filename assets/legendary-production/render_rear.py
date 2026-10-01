import bpy,json
from pathlib import Path
from mathutils import Vector
P=Path(__file__).resolve().parent
bpy.ops.wm.open_mainfile(filepath=str(P/'Legendary-Eight-v1.blend'))
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=12
scene.render.resolution_x=800;scene.render.resolution_y=640;scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('QA world');scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.12,.16,.22,1)
scene.view_settings.view_transform='AgX'
bpy.ops.object.camera_add();camera=bpy.context.object;camera.data.type='ORTHO';scene.camera=camera
lights=[]
for pos,power in [((4,6,8),1500),((-5,2,5),1000),((2,-5,7),1700)]:
 bpy.ops.object.light_add(type='AREA');o=bpy.context.object;o.data.energy=power;o.data.size=5;lights.append((o,Vector(pos)))
manifest=json.loads((P/'vehicle-manifest.json').read_text())
for i,spec in enumerate(manifest):
 for row in manifest:bpy.data.collections[row['name']].hide_render=row['name']!=spec['name']
 center=Vector((i*10,0,0));camera.location=center+Vector((-7,10,6));camera.rotation_euler=(center-camera.location).to_track_quat('-Z','Y').to_euler();camera.data.ortho_scale=max(spec['size'])*1.5
 for light,pos in lights:light.location=center+pos;light.rotation_euler=(center-light.location).to_track_quat('-Z','Y').to_euler()
 scene.render.filepath=str(P/(spec['name'].replace(' ','_')+'-rear.png'));bpy.ops.render.render(write_still=True)
