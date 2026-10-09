"""Run with Blender --background --python-exit-code 1 --python validate-package.py.

Opens every packaged native scene without changing it, verifies packed textures,
checks copies against their approved source hashes, and validates builder inputs.
"""
import bpy
import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parent
manifest = json.loads((ROOT / 'package-manifest.json').read_text())
records = []
for record in manifest['copies']:
    path = ROOT / record['file']
    with path.open('rb') as stream:
        assert hashlib.file_digest(stream, 'sha256').hexdigest() == record['sha256'], path
    if path.suffix != '.blend':
        continue
    bpy.ops.wm.open_mainfile(filepath=str(path))
    assert bpy.data.objects.get('Honda_Civic_Body'), path
    missing = [image.name for image in bpy.data.images
               if image.source == 'FILE' and image.users and not image.packed_file]
    assert not missing, (str(path), missing)
    assert not bpy.data.libraries, 'All scene dependencies must be local or packed'
    if record['file'].startswith('v2/'):
        assert bpy.context.scene.get('CleanRestored')
        assert bpy.context.scene.get('LayoutRevision') == 'Varied placement v2'
    records.append({'file': record['file'], 'sha256MatchesApprovedSource': True,
                    'objects': len(bpy.context.scene.objects),
                    'meshes': sum(o.type == 'MESH' for o in bpy.context.scene.objects),
                    'packedFileImages': sum(bool(i.packed_file) for i in bpy.data.images),
                    'unpackedFileImages': missing})
    print('PACKAGE_OK', record['file'], flush=True)

source = (ROOT / 'build-civics.py').read_text()
scope = {'__file__': str(ROOT / 'build-civics.py')}
exec(compile(source[:source.index('start=int')], scope['__file__'], 'exec'), scope)
inputs = {}
for key in ('BASE', 'MECH', 'WARP', 'GHOST'):
    path = scope[key]
    assert path.is_file(), path
    inputs[key] = path.relative_to(ROOT.parent).as_posix()
assert len(scope['names']) == 31
assert len(records) == manifest['nativeScenes'] == 33
(ROOT / 'package-validation.json').write_text(json.dumps({
    'nativeScenesOpened': len(records), 'copyHashesChecked': len(manifest['copies']),
    'builderInputs': inputs, 'checks': records,
    'limits': 'Native Blender packaging validation only; no Roblox import or playtest.'
}, indent=2) + '\n')
print('PACKAGE_VALIDATED', len(records), flush=True)
