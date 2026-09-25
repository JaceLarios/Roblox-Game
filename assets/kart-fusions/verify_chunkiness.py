from pathlib import Path
import json
p=Path(__file__).parent;previous=p.parent/'kart-fusions-v6'
out=[]
for spec in json.loads((p/'designs.json').read_text()):
 fn=spec['name'].replace(' ','_')+'.json';new=json.loads((p/fn).read_text());old=json.loads((previous/fn).read_text())
 assert abs(new['targetSize'][0]/old['targetSize'][0]-1.12)<.003
 nr=sorted(set(round(g['wheel']['radius'],5)for g in new['parts']if 'wheel' in g));orr=sorted(set(round(g['wheel']['radius'],5)for g in old['parts']if 'wheel' in g))
 assert nr==orr
 out.append({'name':spec['name'],'widthBefore':old['targetSize'][0],'widthAfter':new['targetSize'][0],'wheelRadiiPreserved':True})
(p/'chunkiness-validation.json').write_text(json.dumps(out,indent=2))
print('All 15 models: width increased 12 percent; rolling radii unchanged.')
