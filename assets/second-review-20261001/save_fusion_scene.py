import bpy,json
from pathlib import Path
P=Path(__file__).resolve().parent
bpy.ops.object.select_all(action='SELECT');bpy.ops.object.delete(use_global=False)
for i,r in enumerate(json.loads((P/'import/manifest.json').read_text())):
 d=json.loads((P/'import'/r['file']).read_text());c=bpy.data.collections.new(d['name']);bpy.context.scene.collection.children.link(c)
 for g in d['parts']:
  me=bpy.data.meshes.new(g['name']);me.from_pydata([(x,-z,y)for x,y,z in g['vertices']],[],g['triangles']);me.update()
  for f in me.polygons:f.use_smooth=True
  me.normals_split_custom_set_from_vertices([(x,-z,y)for x,y,z in g['normals']])
  o=bpy.data.objects.new(g['name'],me);c.objects.link(o);o.location=(i%4*12,i//4*12,0)
  m=bpy.data.materials.new(g['name']);m.use_nodes=True;p=m.node_tree.nodes.get('Principled BSDF');p.inputs['Base Color'].default_value=(*g['material']['color'],1);p.inputs['Metallic'].default_value=g['material'].get('metal',.35);p.inputs['Roughness'].default_value=.38
  if g['material']['finish']=='Light':p.inputs['Emission Color'].default_value=(*g['material']['color'],1);p.inputs['Emission Strength'].default_value=1.5
  me.materials.append(m);o['GameFinish']=g['material']['finish']
  if g.get('wheel'):o['WheelId']=g['wheel']['id'];o['WheelPivot']=g['wheel']['pivot'];o['WheelRadius']=g['wheel']['radius']
bpy.ops.wm.save_as_mainfile(filepath=str(P/'Reviewed-Fusion-Fixes.blend'))
