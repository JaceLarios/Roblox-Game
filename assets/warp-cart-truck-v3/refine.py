from pathlib import Path
P=Path(__file__).resolve().parent
f=P/'build_vehicles.py';s=f.read_text()
s=s.replace("  if name=='Golf Cart' and i in [16,17]:", "  if name=='Golf Cart' and i==24:continue\n  if name=='Golf Cart' and i==16:\n   g=dict(g);g['triangles']=[t for t in g['triangles'] if sum(g['vertices'][v][2]for v in t)/3<2.4]\n  if name=='Golf Cart' and i in [16,17]:")
s=s.replace("  gate((0,1.9,.75),.36,label='Seat-back warp control hub')", """  gate((0,1.9,.75),.36,label='Seat-back warp control hub')
  for side in [-1,1]:
   box('Inset canopy cooling panel',(side*.85,.55,2.125),(.37,1.20,.025),'WarpCarbon',.05)
   for j in range(7):box('Flush canopy vent slat',(side*.85,.10+j*.15,2.145),(.30,.055,.022),'Chrome',.01)
""")
s=s.replace("  box('Rear containment latch'", """  for y in [.05,2.25]:
   box('Reactor suspension saddle',(0,y,-.80),(2.3,.36,.40),accent,.11)
   for side in [-1,1]:
    cyl('Suspension isolator',(side*.65,y,-.80),(side*.65,y,-.1),.09,'Chrome',n=16)
    tor('Isolator collar',(side*.65,y,-.55),.13,.04,'WarpCopper',(0,0,1),16)
  for side in [-1,1]:
   box('Roof service hatch',(side*.75,1.1,2.25),(.70,2.5,.035),'WarpCarbon',.08)
   for j in range(9):box('Heat vent louver',(side*.75,.10+j*.23,2.28),(.56,.085,.05),'Blue',.018)
  box('Rear containment latch'""")
f.write_text(s)
