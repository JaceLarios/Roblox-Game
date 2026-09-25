# Every recipe starts with the same approved Rusted Sedan / Scrap Kart body.
_family_source=reference[reference.index("model('Rusted Sedan')"):reference.index("box('Rear exposed engine'")]
_family_source=_family_source.replace("model('Rusted Sedan')","model(spec['name'])")
_family_source=_family_source.replace("'Turquoise'","spec['color']")
_family_source=_family_source.replace("wheel(x,y,.50,.47,.34,'Orange',True)","signature_wheel(x*track_scale,y,.50,.47,tire_width,spec['accent'],index,y>0)")
_family_source=_family_source.replace("axle(y,.49,1.12)","axle(y,.49,1.12*track_scale)")
_family_source=_family_source.replace("arch(x,y,.50,.52,.41,spec['color'])","arch(x*track_scale,y,.50,.54,.43+(tire_width-.34),spec['color'])")

def build_sedan_variant(spec,index):
 global exhaust_start
 track_scale=1.10 if index>=12 else 1.04 if index>=9 else 1.0
 tire_width=.52 if index>=12 else .44 if index>=6 else .39
 exec(_family_source,globals(),{'spec':spec,'index':index,'track_scale':track_scale,'tire_width':tire_width})
 # Original hood, twin round headlights, bumper, comfortable seat and roll hoop
 # are invariants; rarity upgrades wrap this recognizable body.
 if index>=6:
  for side in [-1,1]:
   box('Sedan sill reinforcement',(side*1.00,.03,.48),(.20,1.82,.13),'Carbon' if index>=9 else spec['accent'],.05)
 if index>=12:
  for side in [-1,1]:
   for y in [-1.22,1.26]:
    arch(side*1.04,y,.50,.525,.60,'Carbon')
    for yy in [-.22,0,.22]:bolt((side*1.345,y+yy,.99),(side,0,0),.023)
  box('Sedan carbon front lip',(0,-2.05,.435),(1.96,.26,.10),'Carbon',.045)
  for x in [-.65,-.33,0,.33,.65]:box('Rear diffuser vane',(x,1.73,.40),(.045,.48,.22),'Carbon',.018)
 # Keep a mount-ready rear deck; this belongs to the donor car, not a new chassis.
 box('Rear addon mounting deck',(0,1.47,.69),(1.62,.90,.15),'Iron',.045)
 for x in [-.68,.68]:bolt((x,1.78,.775),r=.035)
 exhaust_start=len(MODELS[current])
