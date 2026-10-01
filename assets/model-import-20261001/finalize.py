import json,re
from pathlib import Path
P=Path(__file__).resolve().parent;R=P.parent.parent
d=json.loads((P/'installed-models.json').read_text())
assert len(d['models'])==25
names={m['name']for m in d['models']}
restore=(P.parent/'warp-drive-batch/restore.edit.luau').read_text()
start=restore.index('[==[')+4;end=restore.index(']==]',start)
(P/'restore.edit.luau').write_text(restore[:start]+json.dumps(d,separators=(',',':'))+restore[end:])
todo=R/'docs/MODELS_TODO.md';lines=todo.read_text(encoding='utf-8').splitlines()
for i,line in enumerate(lines):
 if '- [ ]'in line and any(re.search(r'(?<![\w])'+re.escape(name)+r'(?![\w])',line)for name in names):lines[i]=line.replace('- [ ]','- [x]',1)
todo.write_text('\n'.join(lines)+'\n',encoding='utf-8')
progress=R/'docs/model-production-status.json';status=json.loads(progress.read_text())
for item in status['items']:
 if item['name']in names:item['status']='installed_recipe_viewport_resize_wheel_or_hover_verified_full_playtest_pending'
progress.write_text(json.dumps(status,indent=2)+'\n')
note='''# All currently built models imported — Codex (2026-10-01)

Installed all 25 previously pending models: two approved v3 Warp redesigns (Hole in Space, Star Freighter), 15 golf-cart fusions and eight Rocket Booster/Fusion Core builds. Existing models replaced only by exact name and backed up in ServerStorage. All 25 passed recipe, rarity, mesh budget, viewport, resize and wheel/hover checks in Edit mode. Atomic Albatross retains its reactor-effect anchor. Full live racing/conveyor playtests remain. No player data changed. SVO/LogoCover, Toro and approved Lightspeed Legend preserved. Assets, uploaded mesh IDs, checks and a ServerStorage-only recovery script: assets/model-import-20261001. This makes 31 distinct checklist models installed across the recent batches; other unbuilt checklist entries remain.

This is a Studio import, not live publication or a GitHub push. Prior 'not installed' statuses in source folders describe their earlier build state and are superseded by this import record.

---

'''
h=R/'HANDOFF.md';h.write_text(note+h.read_text(encoding='utf-8'),encoding='utf-8')
for folder in ['golf-cart-fusions','legendary-production','warp-cart-truck-v3']:
 message='Installed in Studio 2026-10-01. See ../model-import-20261001 for asset IDs, backup and tests. This supersedes previous NOT INSTALLED notes. Full live race/conveyor test and live publication remain.\n'
 (P.parent/folder/'IMPORTED.txt').write_text(message)
 (P.parent/folder/'STATUS.txt').write_text(message)
 readme=P.parent/folder/'README.md'
 if readme.exists():readme.write_text('CURRENT STATUS: '+message+'\n---\nPrevious build notes:\n\n'+readme.read_text(encoding='utf-8'),encoding='utf-8')
(P/'STATUS.txt').write_text('25 models installed. Recipe, rarity, geometry budget, viewport, resize and wheel/hover tests passed in Edit mode. Full playtest remains. Not published or pushed.\nBackup: '+d['verification']['backup']+'\n')
print('Saved 25-model recovery and updated checklist/handoff')
