import json
from pathlib import Path
p=Path(__file__).parent
checks=[
 ('Rusty Splice','Nitrous Tank',{'Blue nitrous bottle':2,'Nitrous valve':2,'Braided nitrous hose':2}),
 ('Loud Lemon','Straight Pipes',{'Straight chrome exhaust':2,'Blued straight pipe tip':2,'Exhaust bolt-on bracket':2}),
 ('Turbo Tin Can','Scrap Turbo',{'Turbo snail housing':1,'Turbo welded patch':1,'Hose tape wrap':3}),
 ('Boosted Beater','Inline 4',{'Cast engine block':1,'Colored cylinder bank':1,'Individual intake trumpet rolled lip':4}),
 ('Spin Cycle Sedan','Rotary Engine',{'Rotary housing':1,'Visible triangular Wankel rotor':1,'Rotor inspection window rim':1}),
 ('Double Trouble','Twin Turbo',{'Turbo snail housing':2,'Polished crossover':1}),
 ('Street Menace','V6 Engine',{'Colored cylinder bank':2,'Individual intake trumpet rolled lip':6}),
 ('Whine Machine','Supercharger',{'Roots blower case':1,'Oversized blower scoop':1,'Blower drive belt':1}),
 ('Smoke Screen Sedan','Diesel Stack',{'Tall truck smokestack':2,'Soot black stack tip':2}),
 ('Redline Reaper','V8 Engine',{'Colored cylinder bank':2,'Individual intake trumpet rolled lip':8}),
 ('Grand Tourer Ghost','V12 Engine',{'Colored cylinder bank':2,'Individual intake trumpet rolled lip':12}),
 ('Hover Heap','Hover Fans',{'Hover fan hub':4,'Cyan fan rotor blade':28,'Ducted hover fan':4}),
 ('Sonic Scrapheap','Jet Engine',{'Jet intake mouth':1,'Jet fan blade':13,'Jet afterburner outlet':1}),
 ('Retro Rocket','Rocket Booster',{'Rocket combustion chamber':2,'Rocket bell nozzle':2,'Rocket hazard band':12}),
 ('Reactor Rustbucket','Fusion Core',{'Plasma reactor sphere':1,'Scrap reactor containment ring':3,'Plasma power conduit':2})]
results=[]
for name,addon,required in checks:
 d=json.loads((p/(name.replace(' ','_')+'.json')).read_text());assert d['addon']==addon
 names=set(n for g in d['parts'] for n in g['components'])
 counts={prefix:sum(n.startswith(prefix) for n in names) for prefix in required}
 for prefix,minimum in required.items():assert counts[prefix]>=minimum,(name,prefix,counts[prefix],minimum)
 results.append({'model':name,'addon':addon,'geometrySignatures':counts,'valid':True})
(p/'addon-validation.json').write_text(json.dumps(results,indent=2))
print('Verified all 15 recipe/addon pairs and their identifying physical components.')
