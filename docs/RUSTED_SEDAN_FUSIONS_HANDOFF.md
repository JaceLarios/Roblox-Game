# Rusted Sedan fusion model handoff — 2026-09-25

Installed 15 recipe-specific fusion models into ReplicatedStorage.ItemModels in place 94136201094216. This revision retains the approved Rusted Sedan/Scrap Kart body, broadens the models by 12%, and includes distinct wheels, correct addon geometry, Legendary carbon kits and Reactor Rustbucket light/wisp/spark effects. No recipes, economy values, islands or player data changed.

Canonical sources and renders: assets/kart-fusions. The installed-models.json snapshot contains actual Roblox mesh IDs, model/part attributes, materials and nested effects. installation-verification.json records installation checks and backup location. The source .blend is editable; the JSON geometry rebuild path may upload new mesh assets, whereas restore-snapshot.edit.luau stages models from existing asset IDs.

Replaced five prior models and added ten missing templates. Backup: ServerStorage.KartFusionsBeforeRebuild_1790350084. Seven approved base cars and their existing conveyor wheel update are also included in this commit under assets/base-cars and the two source files. ItemVisuals.Resize now scales attached reactor effects with the pickup animation. Studio scripts were compared against local files to preserve existing work.

Passed: all recipe names, fifteen viewport clones, forty-five assemblies at .55/1/1.3 scale, wheel movement, assembly resizing, reactor effect presence/position scaling, source whitespace checks, mesh geometry and addon/body checks. Legendary models were visually checked in Studio. One fresh mesh failed to load during upload; the isolated retry succeeded and the failed asset is absent from the installed snapshot.

Next: press Play in Studio and test fusion, inventory, carrying, pad placement, selling and reactor particle playback. Driving/seat entry/collision/suspension and mobile performance are NOT verified by these display-model checks. Existing live servers will not change until the user publishes from Studio. No publication was performed by this task.
