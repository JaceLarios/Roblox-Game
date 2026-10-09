import bpy,json
from pathlib import Path
from mathutils import Vector
P=Path(__file__).resolve().parent
report={}
bpy.ops.wm.open_mainfile(filepath=str(P/'Straight_Pipes.blend'))
s=bpy.context.scene
ends=[o for o in s.objects if o.name.startswith('Sky pipe blue hollow outlet')]
assert len(ends)==2
maxz=max((o.matrix_world@Vector(v)).z for o in ends for v in o.bound_box)
assert maxz>2.40
assert s.get('CleanRestored') and s.get('FusionAddon')=='Straight Pipes'
report['Straight Pipes']={'openTallOutlets':len(ends),'outletHeightMeters':round(maxz,3),'roofHeightMeters':1.279,'cleanRestored':True}
bpy.ops.wm.open_mainfile(filepath=str(P/'Twin_Turbo.blend'));s=bpy.context.scene
body=bpy.data.objects['Honda_Civic_Body'];assert body.get('RearBumperDeleted')
assert body['RemovedBumperVertices']>=2248
housings=[o for o in s.objects if o.name.startswith('Rear turbo cast snail housing')];assert len(housings)==2
for o in housings:
 points=[o.matrix_world@Vector(v) for v in o.bound_box];assert min(v.y for v in points)>1.8;assert max(v.z for v in points)<.7
assert not any(o.name.startswith('Turbo mounting saddle') for o in s.objects)
assert s.get('CleanRestored') and s.get('FusionAddon')=='Twin Turbo'
report['Twin Turbo']={'rearBumperRemoved':True,'bumperAndTrimVerticesRemoved':body['RemovedBumperVertices'],'rearFacingTurboHousings':2,'cleanRestored':True}
# A straight rear inspection render shows the two turbos and deleted bumper edge.
c=s.camera;c.location=(0,7,1.95);c.rotation_euler=(Vector((0,1.25,.61))-c.location).to_track_quat('-Z','Y').to_euler();c.data.ortho_scale=3.1;s.render.filepath=str(P/'Twin_Turbo-rear-detail.png');bpy.ops.render.render(write_still=True)
report['gameIntegrated']=False
(P/'rear-exhaust-checks.json').write_text(json.dumps(report,indent=2));print('REAR_EXHAUST_CHECKS_OK',flush=True)
