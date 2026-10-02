"""Non-destructive geometry patch of the approved exports. Original sources retained."""
import json,copy,hashlib,math
from pathlib import Path
from collections import defaultdict
P=Path(__file__).resolve().parent; A=P.parent; OUT=P/'import';OUT.mkdir(exist_ok=True)
def bounds(parts):
 vs=[v for g in parts for v in g['vertices']]
 return [[min(v[i]for v in vs)for i in range(3)],[max(v[i]for v in vs)for i in range(3)]]
def linear(rgb):return [(c/255/12.92 if c/255<=.04045 else ((c/255+.055)/1.055)**2.4)for c in rgb]
def material(rgb,finish='Enamel'):return {'color':linear(rgb),'metal':.35,'finish':finish}
def subset(g,tris,name,ma):
 out={'name':name,'material':ma,'vertices':[],'normals':[],'triangles':[]};lookup={}
 for t in tris:
  row=[]
  for old in t:
   if old not in lookup:
    lookup[old]=len(out['vertices']);out['vertices'].append(g['vertices'][old]);out['normals'].append(g['normals'][old])
   row.append(lookup[old])
  out['triangles'].append(row)
 return out
sources=[A/'remaining-fusions/Jet_Hauler.json',A/'legendary-production/Rocket_Freight.json']
manifest=[];report=[]
for source in sources:
 d=json.loads(source.read_text());oldbounds=bounds(d['parts']);base=d['base'];counts={};changed=[]
 if base=='Box Truck':
  cream=next(g for g in d['parts']if g['name'].startswith('Cream_Body')); signTop=max(v[1]for v in cream['vertices']);signBottom=signTop-2.0472
  if source.parent.name=='remaining-fusions':
   new=[]
   for g in d['parts']:
    key=next((k for k in ['Cream','Blue','Orange']if g['name'].startswith(k+'_Body')),None)
    if not key:new.append(g);continue
    yes=[];no=[]
    for t in g['triangles']:
     # Sign art stands proud of the cargo wall, on both exterior sides.
     (yes if all(abs(g['vertices'][i][0])>1.58 and g['vertices'][i][2]<.7 for i in t)else no).append(t)
    assert yes,(d['name'],key)
    colors={'Cream':(243,230,189),'Blue':(22,131,236),'Orange':(246,106,36)}
    if no:new.append(subset(g,no,g['name'],g['material']))
    new.append(subset(g,yes,'Restored '+key+' billboard',material(colors[key])));counts[key]=len(yes)
   d['parts']=new
  for g in d['parts']:
   n=g['name'];shift=None
   if d['name']=='Scrap Hybrid'and any(k in n for k in ['Nitrous bottle','Bottle shoulder','Bottle valve','Bottle retaining strap','Bottle mounting tray','Braided nitrous']):shift=-1.30
   if d['name']=='Rattle Hauler'and any(k in n for k in ['Side exhaust','Heat-blued','Titanium tip','Bolted exhaust']):shift=-1.05
   if d['name']=='Rocket Freight'and any(k in n for k in ['Cargo launch pod','Heavy launch yoke']):shift=None
   if d['name']in ['Rocket Freight','Core Carrier']and 'Cargo cooling radiator'in n:shift=signBottom-.14-max(v[1]for v in g['vertices'])
   if shift:
    for v in g['vertices']:v[1]+=shift
    changed.append(n)
   if d['name']in ['Rocket Freight','Core Carrier']and any(k in n for k in ['Braided flux supply','Luminous flux tracer']):
    lo=min(v[1]for v in g['vertices']);hi=max(v[1]for v in g['vertices']);floor=signTop+.16;factor=(hi-floor)/(hi-lo)
    assert factor>0
    for v in g['vertices']:v[1]=floor+(v[1]-lo)*factor
    for normal in g['normals']:
     normal[1]/=factor;l=math.sqrt(sum(x*x for x in normal));normal[:]=[x/l for x in normal]
    changed.append(n)
 for g in d['parts']:
  if 'Ducted lift fan shroud'in g['name']:
   g['material']=material((37,48,61),'Cast');changed.append(g['name'])
 # Recessed roof-shoulder nacelles keep signs and tire silhouettes clear.
 if d['name']=='Jet Hauler':
  selected=[g for g in d['parts'] if not g.get('wheel') and any(k in g['name'] for k in ['Jet intake','Carbon turbine','Intake spinner','Swept compressor','Afterburner throat','Overlapping nozzle','Blue afterburner','Nacelle clamp','Hex fastener','Cargo structural jet','Cargo jet heat'])]
 else:
  selected=[g for g in d['parts'] if any(k in g['name'] for k in ['Cargo launch pod','Heavy launch yoke'])]
 lo=min(v[1] for g in selected for v in g['vertices']);hi=max(v[1] for g in selected for v in g['vertices'])
 floor=signTop+.055;ceiling=oldbounds[1][1]-.015;factor=(ceiling-floor)/(hi-lo)
 for g in selected:
  for v in g['vertices']:v[1]=floor+(v[1]-lo)*factor
  for n in g['normals']:
   n[1]/=factor;l=math.sqrt(sum(a*a for a in n));n[:]=[a/l for a in n]
  changed.append(g['name'])
 for g in d['parts']:
  if d['name']=='Rocket Freight' and 'Cargo cooling radiator' in g['name']:
   for v in g['vertices']:v[2]+=1.5
 newbounds=bounds(d['parts'])
 assert max(abs(a-b)for row,row2 in zip(oldbounds,newbounds)for a,b in zip(row,row2))<.015,(d['name'],oldbounds,newbounds)
 buckets=defaultdict(list)
 for g in d['parts']:
  m=g['material'];m.setdefault('finish','Light'if m.get('glow',0)else'Brushed'if m.get('metal',0)>.7 else'Enamel')
  buckets[json.dumps([m,g.get('wheel')],sort_keys=True)].append(g)
 packed=[]
 for groups in buckets.values():
  current=None
  for g in groups:
   if current is None or len(current['triangles'])+len(g['triangles'])>17000:
    current={'name':g['material']['finish']+'_'+str(len(packed)),'material':g['material'],'vertices':[],'normals':[],'triangles':[],'components':[]}
    if g.get('wheel'):current['wheel']=g['wheel']
    packed.append(current)
   offset=len(current['vertices']);current['vertices']+=g['vertices'];current['normals']+=g['normals'];current['triangles'] +=[[v+offset for v in t]for t in g['triangles']];current['components'].append(g['name'])
 for g in packed:g['geometryHash']=hashlib.sha256(json.dumps([g['vertices'],g['normals'],g['triangles']],separators=(',',':')).encode()).hexdigest()
 d['parts']=packed;d['revision']='SecondReview_20261001_v3';d['expectedWheels']=0 if d['addon']=='Hover Fans'else 4
 (OUT/source.name).write_text(json.dumps(d,separators=(',',':')))
 manifest.append({'name':d['name'],'file':source.name,'parts':len(packed)})
 report.append({'name':d['name'],'signTriangles':counts,'movedOrRecolored':changed,'boundsBefore':oldbounds,'boundsAfter':newbounds})
(OUT/'manifest.json').write_text(json.dumps(manifest,indent=2));(P/'geometry-checks.json').write_text(json.dumps(report,indent=2))
print('Patched',len(manifest),'models, preserving bounds and wheel coordinates')
