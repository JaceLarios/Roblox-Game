# Addon color and detail pass — 2026-09-24

Preserves the exact lookup names and eight approved v1 silhouettes. Adds brighter blue/orange/teal/violet enamel, physical fasteners, clamps, fuel/ignition lines, injector hardware, duct trim and nozzle cooling ribs. Original source and geometry remain in the parent folder.

At the user's subsequent request, V12 Engine and Rotary Engine were rebuilt with more recognizable engine architecture. V12 has 60-degree banks, carbon DOHC covers, twelve open red stacks, individual headers/collectors, belt-driven accessories and rear bellhousing. Rotary has stacked twin rotor housings, an epitrochoid-inspired chamber, curved triangular cutaway rotor, inspection pane, intake plenum, ignition leads, oil pump and flywheel. These are stylized mechanical interpretations, not branded replicas or engineering models. Reference sources: Mazda's 2003 technical review (rotary construction) and Ferrari's 330 P technical page (60-degree V12).

Source: `Junkyard-Fusion-10-Addons-Textured.blend` with packed texture images, plus the plain geometry source `Junkyard-Fusion-10-Addons.blend`. Geometry: ten named JSON files and `manifest.json`. Preview: `addon-lineup-preview.jpg` (Blender lighting; Roblox appearance differs).

Five original seamless PBR material sets in `textures/`: Cast, Brushed, Enamel, Rubber and Oxidized. Each has color, normal, roughness and metalness PNG maps. `make_textures.py` regenerates them. Imported as uniquely named AddonDetail material variants, applied only to the ten addons. Existing AddonCarbonTwill is reused; glass and emissive plasma remain intentionally smooth. `render_textured.py` creates textured Blender source and previews.

Installed and verified all ten in Edit mode. Backup: `ServerStorage.AddonBackup_BeforeColorDetail_1790310653`. Inventory viewport and welded pickup assembly checks passed; visual Studio review completed and temporary gallery removed. Output contained no new addon errors. HTTP setting restored to false and local transfer server stopped. Full live gameplay and performance remain untested. The user reported publishing the completed changes on 2026-09-24. Publication was not independently checked. This package is the subsequent GitHub backup.

`build_addons.py` is the complete reproducible builder. Blender background generation does not modify the user's open Blender scene.

Geometry validation checks finite coordinates, normals, triangle indices, mesh limits and rarity reference sizes. Roblox installation is guarded against external revisions and keeps original v1 models in ServerStorage. No gameplay scripts, economy, recipes or player data changed.

Studio installation/report and published mesh references are recorded in `studio-report.json` after verification. Full live gameplay remains untested. The user reported saving/publishing before requesting this backup.


## Recovery from GitHub

Run `restore.edit.luau` in Studio Edit mode. It embeds the model/texture manifest, recreates missing material variants and all ten addons in a new `ServerStorage.RestoredNewAddons_<timestamp>` folder. It never replaces installed ItemModels. Poll `_G.NewAddonRestore` for completion/errors, inspect the results, then back up existing same-named templates before moving restored models into ReplicatedStorage.ItemModels. Save/publish separately. This recovery script is statically checked, not executed in this backup pass.

For independent mesh rebuilding, `build_addons.py` regenerates the exact material-grouped geometry in Blender. `make_textures.py` requires NumPy and Pillow and regenerates the original PNGs and temporary image transfer JSON. `render_textured.py` packs textures into the separate textured Blender source and renders previews. `import-staging.edit.luau`, `import-textures.edit.luau`, `apply-textures.edit.luau` and `install.edit.luau` document the original import workflow; those depend on session globals and are not standalone recovery scripts. Prefer `restore.edit.luau` for restoration.

All ten raw geometry JSON files, both Blender source files and twenty texture PNGs are included. Roblox asset references are also retained; restoring by asset ID depends on Roblox permissions/availability. This is not a complete native place export or a backup of player DataStores. Other current GitHub game scripts were preserved unchanged.
