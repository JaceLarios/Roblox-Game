# Junkyard addon concept build

Five standalone pickup models based on the approved green/blue/purple/red/orange concept sheet. These are the ingredients, not the fused vehicle results. Stable names: Nitrous Tank, Inline 4, V6 Engine, V8 Engine, Jet Engine.

Only appearance is being changed. Recipe mappings, rarity, value, drop odds and player data are preserved. Existing templates are backed up in Studio before replacement.

## Current weathered finish

Revision `AddonWeathered_20260923_v2` is now installed. Textures add chipped enamel, rust at seams/fasteners, worn pulleys, oily recesses and heat-stained headers while keeping the five rarity colors. Shape bounds remain within .01 studs of the approved first pass, and each model still has three MeshParts. The Nitrous Tank's original valve/gauge submodel was retained to keep its dial legible.

Current `models.json`, `restore.luau`, and `preview.png` describe the weathered version. The `*-clean-v1` files preserve the earlier appearance. Before replacement the live clean templates were moved to `ServerStorage.AddonBeforeWeathering_1790175813`.

Repeated verification: all 35 recipes, three size scales, ground placement, welded movement/resize, tint, fade and viewport cloning passed. All 15 assets preloaded successfully. The normal spawner dropped V8 Engine during testing; Output showed no errors. Recovery recreated and matched all 15 mesh/texture references and transforms. Manual pickup/fusion, save round trip and mobile performance are still untested. The place has not been published by this task.

## First-pass background

Revision `AddonConcept_20260923_v1`. All five templates are now Models containing three MeshParts each. Longest sides: Nitrous Tank 3, Inline 4 3.3, V6 Engine 3.5, V8 Engine 4, Jet Engine 4.5 studs. These are ingredient sizes, not the larger fused-result rarity ladder. Existing ItemVisuals global scaling still applies.

`concept.png` is the approved art direction; `preview.png` is the actual Studio client viewport capture. The generated geometry is a first interpretation with simpler texture detail than the illustration, not an exact reproduction. An initial upright tank was rejected; the installed asset is the corrected horizontal cradle version (92350841313878). The other generated source asset IDs are recorded in `models.json`.

The Edit review lineup is at `Workspace.CodexAddonReview` around (114,508,0). Previous live templates are preserved in `ServerStorage.AddonBeforeConceptBuild_1790175051`. No scripts, recipe values or rarity/drop settings were edited. No inventory items were granted or removed by the verification tools.

## Recovery

Run `restore.luau` in Studio Edit mode. It embeds `models.json` and reconstructs all five in `ServerStorage.AddonConceptRestore`, leaving installed templates untouched. After inspection, back up any existing same-named templates and move the restored Models into `ReplicatedStorage.ItemModels`. Save the place. Publishing remains a separate step.

The manifest stores Roblox-hosted mesh/texture references and exact transforms, not binary geometry or texture files. Roblox asset access is required. Rojo script sync does not install these meshes.

## Verified

- `verify-play.luau` passed in fresh Server Play: all 35 car/addon combinations, ground alignment, scaling at .55/1/1.3, welded translation/rotation, resize, mutation tint, transparency and viewport cloning.
- All 15 MeshPart assets preloaded successfully on the client; all five rendered in the review GUI.
- Output showed the normal spawner dropping Nitrous Tank, with no runtime errors during the test.
- The recovery script ran successfully and all 15 restored mesh/texture IDs, sizes and positions matched installed templates. Temporary recovery copies were removed.
- Studio returned to Edit mode. The review GUI was temporary and disappeared with Stop Play.

Still untested: manual pickup/fuse interaction, saved inventory round trip, published-server asset permissions and mobile performance. Generation requested at most 14,000 triangles per addon; actual performance was not benchmarked.
