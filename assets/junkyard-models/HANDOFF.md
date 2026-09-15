# Junkyard models installed — 2026-09-14

All 38 Junkyard collectible templates are installed in ReplicatedStorage.ItemModels in the open Studio place 94136201094216. Studio is back in Edit mode. This covers 8 base pickups, 16 curated fusion results, 3 secrets and 11 fallback hybrids.

33 existing templates were moved intact into ServerStorage.CodexJunkyardModels_20260914.Originals. Five missing recipe templates were added: Trail Blazer, Undercover Muscle, Hauler Hemi, Turbo Interceptor and Chrome Sentinel. Staging retains the generated sources and rejected prototypes; do not install Prototype_ entries. No generated preview objects remain in Workspace.

The Rusted Sedan identifier is intentionally preserved, with the approved Scrap Kart appearance. Existing recipes, discoveries and saved item names remain compatible. Model dimensions were fitted uniformly to existing footprints (with reasonable bounds), preserving proportions. Existing collision flags, attributes and tags were retained.

Verified:
- All 38 mesh/texture assets preload successfully in Edit and Play client.
- 114 clone/scale/ground-contact checks pass through ItemVisuals.Create.
- All 1,444 ordered pairs of the 38 item names resolve to a covered model.
- Play mode spawns new base meshes and displays existing saved lot items using new meshes.
- Index and inventory visibly render the new models.
- A client-only Trail Blazer fusion animation preview renders correctly; no ingredients consumed or inventory granted.
- Play-test Output contained no errors.
- All unrelated existing model mesh IDs, texture IDs and sizes match the pre-install inventory.

No gameplay/world script was edited by this task. Other script changes appeared during the session (including AreaPets and world/data modules); those changes were left intact. Do not overwrite them from older source exports.

Not tested: every fusion through the actual inventory-consuming gameplay flow, every item on every device, published live-server asset access. No player data reset or recipe migration was performed.

This directory contains the GitHub backup of the completed model work. No place publication was performed. Save the open Studio place before closing it.

Recovery:
- asset-manifest.json is the authoritative final set of 38 published model asset IDs, mesh/texture IDs and installed sizes.
- restore-from-assets.luau contains the populated asset list for Studio command-bar recovery. It was not run over the installed set.
- verify-models.luau contains the successful compatibility checks.
- Original objects remain in the Originals folder; original-models.json records their earlier IDs and dimensions.
- progress.json, resumed-progress.json, final-generation-progress.json and last-refinements.json are historical generation logs, not the final installed asset list.
