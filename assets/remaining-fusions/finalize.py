import json,re
from pathlib import Path
P=Path(__file__).resolve().parent;R=P.parent.parent
files=sorted((P/'installed-snapshots').glob('*.json'))
assert len(files)==52,len(files)
models=[json.loads(p.read_text())['models'][0]for p in files]
verification=json.loads((P/'installation-verification.json').read_text())
(P/'installed-models.json').write_text(json.dumps({'models':models,'verification':verification},separators=(',',':')))
names={m['name']for m in models}
todo=R/'docs/MODELS_TODO.md';text=todo.read_text(encoding='utf-8');lines=text.splitlines()
for i,line in enumerate(lines):
 if '- [ ]'in line and any(re.search(r'(?<!\w)'+re.escape(name)+r'(?!\w)',line)for name in names):lines[i]=line.replace('- [ ]','- [x]',1)
 for task in ['A lighter export','Split the merged rear wheels','Keep the `LogoCover` part']:
  if '- [ ]'in lines[i]and task in lines[i]:lines[i]=lines[i].replace('- [ ]','- [x]',1)
play=P/'playtest-results.json'
tested=play.exists()and json.loads(play.read_text()).get('bothSecretCarsPassed',False)
if tested:lines=[line.replace('- [ ]','- [x]',1)if 'Test both big Secret cars'in line else line for line in lines]
text='\n'.join(lines)+'\n';start=text.index('## How a finished build is set up')
intro='# Model production — updated 2026-10-01\n\nAll 83 model entries in this checklist are now installed in Studio, including the 52 remaining fusion variants. The SVO is 89,769 triangles with four rolling wheel groups; its 12-stud length, decals, materials and LogoCover are retained. Golf-cart source exports and recovery files preserve Claude\'s approved 1.2x fit.\n\nThe checks below track implementation, not final player art approval. Full multiplayer/mobile performance testing and live publication remain separate. See assets/remaining-fusions for source, front/rear previews, recovery files and test evidence.\n\n'
todo.write_text(intro+text[start:],encoding='utf-8')
path=R/'docs/model-production-status.json';d=json.loads(path.read_text())
for item in d['items']:
 if item['name']in names:item['status']='installed_recipe_viewport_resize_wheel_hover_and_race_constructor_verified'
 if item['section']=='Toro SVO fixes':
  item['status']='studio_playtest_verified'if 'Test both'in item['name']and tested else'installed_verified'if 'Test both'not in item['name']else'playtest_pending'
d['updated']='2026-10-01';d['latestBatch']='assets/remaining-fusions';path.write_text(json.dumps(d,indent=2)+'\n')
message='52 remaining fusion variants installed in Studio. Recipe, rarity, mesh-budget, viewport, resize and wheel/hover checks passed. Sources preserve base body identity; textures use the existing MaterialVariants. Original templates backed up in ServerStorage.'
(P/'STATUS.txt').write_text(message+'\nBackup: '+verification['backup']+'\nNot published live or pushed to GitHub in this turn.\n')
note='# Remaining fusion families and SVO — Codex (2026-10-01)\n\n'+message+' All 112 fusion-result recipes should now resolve to named authored models. Source/52 front-and-rear previews, uploaded IDs, reversible install and recovery scripts: `assets/remaining-fusions`.\n\nSVO: reduced to 89,769 triangles, 18 rolling mesh pieces in four wheel groups. No calipers/body panels roll. Preserved the 12.136-stud length, enlarged side decals, carbon accents, appearance and `LogoCover`; source backup retained. Recovery: `assets/svo/restore-optimized.edit.luau`.\n\nGolf carts: baked Claude\'s 1.2x fit into the 15 source/export models and Blender scene, updated rebuild/import paths and saved current fitted mesh-ID snapshots. Use `assets/golf-cart-fusions/restore-fit.edit.luau`; older snapshots describe pre-fit history. Live golf templates were not replaced. Claude\'s PotatoMode fix retained.\n\nTest evidence: installation-verification.json, lifecycle-verification.json and playtest-results.json in the new asset folder. No ownership grants, reset of player data, live publishing or GitHub push this turn. Full multiplayer/mobile testing remains.\n\n---\n\n'
h=R/'HANDOFF.md';h.write_text(note+h.read_text(encoding='utf-8'),encoding='utf-8')
print('Updated 52 model entries, SVO status and handoff.')
