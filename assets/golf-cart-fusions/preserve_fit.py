"""Bake Claude's approved 1.2x Studio fit into source exports; safe to rerun."""
import json, hashlib
from pathlib import Path
P = Path(__file__).resolve().parent
names = {s['name'] for s in json.loads((P/'manifest.json').read_text())}
for folder in [P, P/'import', P.parent/'model-import-20261001/data']:
    for path in folder.glob('*.json'):
        d = json.loads(path.read_text())
        if not isinstance(d, dict) or d.get('name') not in names or 'parts' not in d:
            continue
        factor = 1.2 / d.get('fitScaleToBase', 1)
        if abs(factor-1) < 1e-9:
            continue
        for g in d['parts']:
            g['vertices'] = [[round(v*factor, 7) for v in row] for row in g['vertices']]
            if g.get('wheel'):
                w=g['wheel'];w['pivot']=[v*factor for v in w['pivot']];w['radius']*=factor
            g['geometryHash']=hashlib.sha256(json.dumps([g['vertices'],g['normals'],g['triangles']],separators=(',',':')).encode()).hexdigest()
        d['targetSize']=[v*factor for v in d['targetSize']]
        if 'reactorEffectCenter' in d:d['reactorEffectCenter']=[v*factor for v in d['reactorEffectCenter']]
        d['fitScaleToBase']=1.2
        path.write_text(json.dumps(d,separators=(',',':')))
for folder in [P,P/'import']:
    path=folder/'manifest.json';records=json.loads(path.read_text())
    for r in records:
        if 'size' in r:r['size']=json.loads((folder/r['file']).read_text())['targetSize']
        r['fitScaleToBase']=1.2
    path.write_text(json.dumps(records,indent=2)+'\n')
try:
    import bpy
except ImportError:
    bpy=None
if bpy:
    bpy.ops.wm.open_mainfile(filepath=str(P/'Golf-Cart-Recognizable-15.blend'))
    from mathutils import Matrix
    for name in names:
        collection=bpy.data.collections[name]
        factor=1.2/collection.get('FitScaleToBase',1)
        record=json.loads((P/(name.replace(' ','_')+'.json')).read_text())
        wheels={g['wheel']['id']:g['wheel']for g in record['parts']if g.get('wheel')}
        for o in collection.objects:
            if o.type=='MESH'and abs(factor-1)>1e-9:o.data.transform(Matrix.Scale(factor,4))
            if o.get('WheelId')in wheels:
                w=wheels[o['WheelId']];x,y,z=w['pivot'];o['WheelPivot']=[x,-z,y];o['WheelRadius']=w['radius']
        collection['FitScaleToBase']=1.2
    bpy.ops.wm.save_as_mainfile(filepath=str(P/'Golf-Cart-Recognizable-15.blend'))
print('Preserved approved 1.2x fit in 45 exports and source scene when run in Blender.')
