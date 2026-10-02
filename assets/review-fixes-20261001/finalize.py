from pathlib import Path
import json,ast
P=Path(__file__).resolve().parent;R=P.parent.parent
snapshot=json.loads((P/'toro-live/installed-review-models.json').read_text());assert len(snapshot['models'])==18
(P/'installed-models.json').write_text(json.dumps(snapshot,separators=(',',':')))
tail=(P.parent/'remaining-fusions/make_recovery.py').read_text();tree=ast.parse(tail)
recovery=next(ast.literal_eval(n.value)for n in tree.body if isinstance(n,ast.Assign)and any(isinstance(t,ast.Name)and t.id=='tail'for t in n.targets))
(P/'restore.edit.luau').write_text("-- Restore into ServerStorage only; does not replace active models.\nassert(not game:GetService('RunService'):IsRunning(),'Stop Play')\nlocal data=game.HttpService:JSONDecode([==["+json.dumps(snapshot,separators=(',',':'))+"]==])\n"+recovery)
h=R/'HANDOFF.md';s=h.read_text(encoding='utf-8')
for n in range(1,6):s=s.replace(f'- [ ] **{n}.',f'- [x] **{n}.',1)
note='''## Codex completion — 2026-10-01

Items 1–5 are installed/documented. Restored cream/blue/orange sign art on all 13 trucks while keeping their body paint; lowered Scrap Hybrid bottles and Rattle Hauler exhaust below lettering. Rocket Freight's launch pods sit below the sign; both Legendary trucks route cables above it and cooling racks below it. Dark cast fan housings contrast with Cargo Hoverer, Street Levitator and Hover Hulk; cyan rings/blades remain.

Toro is now **80,219 triangles** (from 177,158), retains its exact 12.134843-stud bounding length, 24 rolling parts, wheel pivots/radii, paint, carbon maps and credits. Re-uploaded mesh-origin offsets were compensated to preserve rendered fit. SVO, golf-cart fit and gameplay scripts were not changed.

Backups: `BeforeClaudeReviewFixes_1790909897` (original affected templates), `BeforeReviewModels_1790910418` (17 fusion originals), `BeforeToroReviewOptimization_1790910881` (Toro original), all in ServerStorage. Source exports, optimized mesh data, Blender scenes, uploaded-ID snapshot and ServerStorage-only recovery: `assets/review-fixes-20261001`. Use this package for these 18 models; older export folders are historical versions.

Validation: all 18 passed current race construction, conveyor path/clearance and pickup-resize checks. All affected wheeled fusions passed wheel motion; all three hover controllers passed. In a short real-keyboard Toro race, it moved 265.8 studs and all 24 wheel pieces rotated. No ownership grants or test rewards. Full race completion and multiplayer/mobile performance were not tested. Studio returned to Edit; HTTP restored false; temporary previews removed. Not published live or pushed this turn.

**Toro source note:** The saved CC BY 4.0 listing record says the source was “From Lamborghini’s Website.” We have not verified that the original website asset permitted redistribution or that the uploader could license it under CC BY; customization and the current credit do not establish that missing permission. Credit unchanged; listing re-check returned 403.

**Optional cleanup:** no backups deleted. Two empty, unreferenced candidates are `WarpModelsStaging_1790862278` and `BeforeWarpBatch_1790862874`; user approval requested. Keep `SVO_Optimized_Staging` for now: two material/part differences were found versus the live SVO, so it is not an exact duplicate. Keep the old SVO rollback and other populated historical backups. Further inventory is in the package README.

'''
if '## Codex completion — 2026-10-01'not in s:s=s.replace('---\n\n# Remaining fusion families',note+'---\n\n# Remaining fusion families',1)
h.write_text(s,encoding='utf-8')
readme=P/'README.md';s=readme.read_text(encoding='utf-8').replace('duplicate staging copy; compare against live SVO before deletion.','not an exact duplicate: two part/material differences remain versus live SVO; retain.');readme.write_text(s,encoding='utf-8')
for f in P.rglob('*.json'):json.loads(f.read_text())
for f in P.glob('*.py'):ast.parse(f.read_text(encoding='utf-8'))
assert not [f for f in P.rglob('*')if f.is_file()and f.stat().st_size>=100*1024*1024]
print('Saved 18-model recovery, updated handoff, validated sources and file sizes.')
