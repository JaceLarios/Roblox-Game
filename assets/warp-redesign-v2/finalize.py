from pathlib import Path
import json,re
from PIL import Image,ImageDraw
P=Path(__file__).resolve().parent;repo=P.parent.parent
snapshot=(P/'installed-models.json').read_text()
old=(P.parent/'warp-drive-batch/restore.edit.luau').read_text()
start=old.index('[==[')+4;end=old.index(']==]',start)
(P/'restore.edit.luau').write_text(old[:start]+snapshot+old[end:])
for suffix,file in [('', 'revised-lineup.jpg'),('-rear','rear-lineup.jpg')]:
 canvas=Image.new('RGB',(1500,860),'#172330');draw=ImageDraw.Draw(canvas)
 for i,row in enumerate(json.loads((P/'vehicle-manifest.json').read_text())):
  canvas.paste(Image.open(P/(row['name'].replace(' ','_')+suffix+'.png')).convert('RGB').resize((500,400)),(i%3*500,i//3*430))
  draw.text((i%3*500+20,i//3*430+403),row['name'],fill='white')
 canvas.save(P/file)
note='''# Warp redesign and addon effects — Codex (2026-10-01)

User approved Lightspeed Legend, rejected the other six first-pass Warp builds. The muscle car geometry remains v1. Six redesigned v2 models are installed: Warp Wreck, Wormhole Wheelie, Hole in Space, Warp Warden, Star Freighter and Starcrusher. Each keeps its base vehicle and separate rolling wheels. Backup of replaced templates: ServerStorage.BeforeWarpBatch_1790866139. Source, front/rear renders, asset IDs and recovery are in assets/warp-redesign-v2. The freight rear portal was moved clear of its door after rear-view QA. All six pass recipe, geometry-budget, viewport, resize and wheel-rotation checks. User has NOT yet approved the v2 appearance.

VehicleAddonEffects (ReplicatedStorage) and its StarterPlayerScripts client controller are installed in Studio and saved in src. They cover 112 fusion results by addon and rarity. Twelve nearby cars maximum within 130 studs; local-only effects, no gameplay or data changes. All 112 profiles passed creation/resize/enable/disable/cleanup tests. The controller passed a 16-car injected-event test for its 12-car cap, animation and distance culling in Edit mode. This is NOT a live multiplayer race/conveyor test. No ItemVisuals or Claude gameplay source was changed. HTTP restored false, local transfer server stopped and QA previews removed. Not published or pushed.

---

'''
handoff=repo/'HANDOFF.md';handoff.write_text(note+handoff.read_text(encoding='utf-8'),encoding='utf-8')
with (P/'REVIEW.txt').open('a')as f:f.write('\nInstalled all six replacements. Recipe/viewport/resize/wheel checks passed. Muscle car v1 preserved. HTTP restored false. QA previews removed. No publication or push. User appearance review pending.\n')
print('Recovery, previews and handoff saved')
