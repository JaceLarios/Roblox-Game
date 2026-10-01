from pathlib import Path
root=Path(__file__).resolve().parent
source=(root.parent/'new-addons/build_addons.py').read_text()
exec(source[:source.index("model('Straight Pipes')")])
OUT=root
material('Enamel Purple',(.32,.055,.8),.5,.25)
material('Enamel Teal',(.01,.47,.55),.5,.26)
model('Warp Drive');footframe(2.2,2.1)
# Open toroidal throat, twin field rings, serviceable mechanical outer cage.
for y in [-.60,.60]:
 torus('Titanium field housing',(0,y,1.65),1.05,.19,'Steel',(0,1,0),48)
 torus('Polished rolled lip',(0,y-.13,1.65),1.05,.035,'Chrome',(0,1,0),48)
 torus('Continuous warp aperture',(0,y-.20,1.65),.83,.065,'Cyan',(0,1,0),48)
 bolts_ring((0,y-.23,1.65),1.06,(0,-1,0),12)
 for j in range(8):
  angle=j*math.tau/8;x=math.cos(angle)*1.13;z=1.65+math.sin(angle)*1.13
  box('Segmented purple field armor',(x,y,z),(.38,.43,.22),'Enamel Purple',.045,rot=(0,-angle,0))
  box('Copper coil saddle',(x,y,z),(.16,.48,.24),'Copper',.025,rot=(0,-angle,0))
for j in range(8):
 a=j*math.tau/8;x=math.cos(a)*1.02;z=1.65+math.sin(a)*1.02
 cylinder('Longitudinal throat rib',(x,-.42,z),(x,.42,z),.07,'Iron')
 for k in range(5):
  torus('Copper induction windings',(x,-.34+k*.17,z),.10,.026,'Copper',(0,1,0),16)
# Mechanical support and service panels, clear central hole rather than another sphere.
for x in [-.83,.83]:
 box('Cast pedestal',(x,0,.43),(.4,1.25,.55),'Enamel Teal',.08)
 box('Bolted service cover',(x,-.66,.44),(.3,.08,.34),'Chrome',.035)
 for z in [.34,.55]:bolt((x,-.72,z),(0,-1,0),.044)
 pipe('Braided power feed',[(x,.4,.45),(x*1.5,.45,.75),(x*1.5,.2,1.2),(x*1.22,-.30,1.35)],.06,'Rubber')
 pipe('Copper coolant return',[(x,-.4,.4),(x*1.42,-.35,.55),(x*1.42,.25,1.15)],.035,'Copper')
box('Front diagnostics housing',(0,-.92,.46),(.9,.38,.32),'Iron',.065)
box('Inset diagnostics screen',(0,-1.12,.49),(.58,.025,.15),'Cyan',.02)
for x in [-.34,.34]:bolt((x,-1.13,.49),(0,-1,0),.038)
for y in [-.23,0,.23]:
 box('Purple upper control bridge',(0,y,2.84),(.52,.13,.13),'Enamel Purple',.035)
# Fine cast-metal texture and machined roughness; retained in Blender source.
for key in ['Steel','Iron','Copper','Enamel Purple','Enamel Teal']:
 m=M[key];nodes=m.node_tree.nodes;links=m.node_tree.links
 n=nodes.new('ShaderNodeTexNoise');n.inputs['Scale'].default_value=95;n.inputs['Detail'].default_value=2
 bump=nodes.new('ShaderNodeBump');bump.inputs['Strength'].default_value=.14;bump.inputs['Distance'].default_value=.018
 links.new(n.outputs['Fac'],bump.inputs['Height']);links.new(bump.outputs['Normal'],nodes.get('Principled BSDF').inputs['Normal'])
export=source[source.index('# Apply modifiers, normalize'):]
export=export.replace('targets=[3,3,3.30019,3.30019,3.49989,3.49989,4,4,4.4999,4.4999]','targets=[4.5]')
export=export.replace("rarities=['uncommon']*2+['rare']*2+['epic']*2+['mythic']*2+['legendary']*2","rarities=['legendary']")
export=export.replace('Junkyard-Fusion-10-Addons.blend','Warp-Drive-v1.blend').replace('scene.cycles.samples=24','scene.cycles.samples=16')
export=export.replace('resolution_x=640','resolution_x=1000').replace('resolution_y=540','resolution_y=850')
exec(export)
