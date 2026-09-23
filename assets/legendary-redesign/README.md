# Legendary full-body redesign

Replaces the three add-on-style jet vehicles with bespoke sculpted vehicles. Recipe names and gameplay are unchanged:

- Rocket Rider: Dirt Bike + Jet Engine. Jet drag-bike with integrated central propulsion, angular fairings, extended chassis, scarlet/orange/gold paint.
- Afterburner GT: Muscle Car + Jet Engine. Low widebody fastback, rear-quarter turbine nacelles, sculpted intakes, orange/gold body and carbon aero.
- Sky Marshal: Cop Cruiser + Jet Engine. Armored pursuit interceptor, integrated rear turbine pods, police lights, black/ivory/cobalt bodywork.

The earlier procedural versions remain backed up under `assets/legendary-jets` and in Studio ServerStorage. The approved bodies now have the brightness/detail pass `LegendaryFullBody_20260923_v4` installed. Roblox publishing is separate.

## Recovery

`models.json` records every mesh/texture ID, size, transform, material, color and gameplay attribute. `restore.luau` embeds the same manifest and rebuilds all three models into `ServerStorage.LegendaryFullBodyRestore` in Edit mode. It does not replace any existing templates. Mesh and texture permissions are required; GitHub stores references, not the binary geometry/texture files hosted by Roblox.

After reviewing restored models, preserve existing same-named templates in a ServerStorage backup folder, then move the replacements into `ReplicatedStorage.ItemModels`. Save the place and publish separately when ready. Rojo script sync alone does not restore these assets.

To reproduce the current v4 finish, run `polish.luau` after installing the restored v3 models. It validates all three source revisions, stages the finish changes, then backs up originals before replacement. It removes the gray mesh tint (sets white so the painted texture keeps its original colors) and adds gold/cyan rim trim, brake rotors, drilling details, red calipers, hubs and individual wheel lugs. The approved mesh shapes and asset IDs are unchanged. Current counts: 129/129/130 BaseParts. `models.json` and `restore.luau` deliberately retain the reproducible v3 baseline; `polish.luau` is the second recovery step.

V4 was checked in fresh Play: all 16 mesh assets preloaded successfully; viewport rendering, welded movement/rotation, resizing, mutation tint and fade passed. Output showed no errors. Current `preview.png` shows the v4 result. Mobile performance remains untested.

## Verification

- All three are centered and approximately 7 studs long; base templates and recipes were unchanged.
- Rocket Rider and Afterburner GT each use 5 mesh parts; Sky Marshal uses 6.
- Fresh Studio Play: recipe mapping, ground alignment, welded movement/rotation, resizing, mutation tint and fade passed at scales .55, 1 and 1.3.
- Client viewport preview rendered all three; all 16 mesh assets preloaded successfully. Play Output showed no errors.
- Recovery script executed successfully. All 16 restored mesh/texture IDs, sizes, and positions matched installed models, then the temporary recovery folder was removed.
- `preview.png` is an actual client viewport screenshot. The Edit review display is at `Workspace.CodexLegendaryJetReview` around (71,508,0).

No inventory items were granted or removed by these tests. An actual player fusion/save round trip, published-server asset access, and mobile performance remain untested. Generated assets use an 18,000-triangle generation budget per vehicle; lower part count alone does not establish performance.

The first bike generation was rejected as too close to a normal dirt bike. The installed Rocket Rider uses asset 125653357915775; the other models use 71088991946079 (Afterburner GT) and 105488583478815 (Sky Marshal). `prompts.json` records initial art direction; `rocket-rider-final-prompt.txt` records the accepted replacement direction.
