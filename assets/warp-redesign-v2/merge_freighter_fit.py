import bpy
from pathlib import Path
from mathutils import Vector
P=Path(__file__).resolve().parent
bpy.ops.wm.open_mainfile(filepath=str(P/'Warp-Redesign-v2.blend'))
c=bpy.data.collections['Star Freighter']
for o in list(c.objects):bpy.data.objects.remove(o,do_unlink=True)
bpy.data.collections.remove(c)
with bpy.data.libraries.load(str(P/'StarFreighter-fit.blend'),link=False)as(src,dst):dst.collections=['Star Freighter']
c=dst.collections[0];bpy.context.scene.collection.children.link(c)
for o in c.objects:o.location+=Vector((40,0,0))
bpy.ops.wm.save_as_mainfile(filepath=str(P/'Warp-Redesign-v2.blend'))
exec(compile((P/'render_rear.py').read_text(),str(P/'render_rear.py'),'exec'))
