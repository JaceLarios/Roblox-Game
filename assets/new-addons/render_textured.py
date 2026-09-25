import bpy
from pathlib import Path
from mathutils import Vector
OUT=Path(__file__).parent
bpy.ops.wm.open_mainfile(filepath=str(OUT/'Junkyard-Fusion-10-Addons.blend'))
mapping={'Chrome':'Brushed','Copper':'Brushed','Gold':'Brushed','BlueHeat':'Brushed','PurpleHeat':'Brushed','Steel':'Cast','Iron':'Cast','Rubber':'Rubber','Rust':'Oxidized','Red':'Enamel','Orange':'Enamel','ElectricBlue':'Enamel','Teal':'Enamel','Violet':'Enamel'}
for name,kind in mapping.items():
 m=bpy.data.materials.get(name)
 if not m:continue
 nt=m.node_tree;bs=nt.nodes.get('Principled BSDF');base=bs.inputs['Base Color'].default_value[:]
 texco=nt.nodes.new('ShaderNodeTexCoord');mappingnode=nt.nodes.new('ShaderNodeMapping');mappingnode.inputs['Scale'].default_value=(3,3,3);nt.links.new(texco.outputs['Generated'],mappingnode.inputs['Vector'])
 for key in ['ColorMap','NormalMap','RoughnessMap','MetalnessMap']:
  tex=nt.nodes.new('ShaderNodeTexImage');tex.image=bpy.data.images.load(str(OUT/'textures'/f'{kind}_{key}.png'));tex.image.pack();tex.projection='BOX';tex.projection_blend=.2
  nt.links.new(mappingnode.outputs['Vector'],tex.inputs['Vector'])
  if key=='ColorMap':
   mix=nt.nodes.new('ShaderNodeMixRGB');mix.blend_type='MULTIPLY';mix.inputs[0].default_value=1;mix.inputs[1].default_value=base;nt.links.new(tex.outputs['Color'],mix.inputs[2]);nt.links.new(mix.outputs[0],bs.inputs['Base Color'])
  else:
   tex.image.colorspace_settings.name='Non-Color'
   if key=='NormalMap':
    normal=nt.nodes.new('ShaderNodeNormalMap');normal.space='OBJECT';normal.inputs['Strength'].default_value=.32;nt.links.new(tex.outputs['Color'],normal.inputs['Color']);nt.links.new(normal.outputs[0],bs.inputs['Normal'])
   else:nt.links.new(tex.outputs['Color'],bs.inputs['Roughness' if key=='RoughnessMap' else 'Metallic'])
# Keep editable source with packed original texture maps.
bpy.ops.wm.save_as_mainfile(filepath=str(OUT/'Junkyard-Fusion-10-Addons-Textured.blend'))
scene=bpy.context.scene;scene.render.engine='CYCLES';scene.cycles.samples=24
scene.render.resolution_x=640;scene.render.resolution_y=540;scene.render.resolution_percentage=100
scene.world=bpy.data.worlds.new('Studio');scene.world.use_nodes=True;scene.world.node_tree.nodes['Background'].inputs[0].default_value=(.15,.18,.23,1);scene.view_settings.view_transform='AgX'
bpy.ops.object.camera_add();cam=bpy.context.object;scene.camera=cam;cam.data.type='ORTHO';cam.data.ortho_scale=5.9
lights=[];settings=[((2,-4,6),1100,5),((-4,-1,3),850,4),((1,4,5),1300,3)]
for loc,power,size in settings:
 bpy.ops.object.light_add(type='AREA');o=bpy.context.object;o.data.energy=power;o.data.shape='DISK';o.data.size=size;lights.append(o)
names=['Straight Pipes','Scrap Turbo','Rotary Engine','Twin Turbo','Supercharger','Diesel Stack','V12 Engine','Hover Fans','Rocket Booster','Fusion Core']
for index,name in enumerate(names):
 for n in names:bpy.data.collections[n].hide_render=n!=name
 center=Vector(((index%5)*5.8,(index//5)*6,0));cam.location=center+Vector((5,-7,5));cam.rotation_euler=(center-cam.location).to_track_quat('-Z','Y').to_euler()
 for o,(loc,power,size) in zip(lights,settings):o.location=center+Vector(loc);o.rotation_euler=(center-o.location).to_track_quat('-Z','Y').to_euler()
 scene.render.filepath=str(OUT/(name.replace(' ','_')+'.png'));bpy.ops.render.render(write_still=True)
print('TEXTURED_PREVIEWS_COMPLETE')
