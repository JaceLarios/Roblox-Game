# Latest addon backup — 2026-09-24

The ten new addons have a complete authored-source package in [assets/new-addons](assets/new-addons/README.md): two Blender files, exact geometry JSON, twenty texture PNGs, asset IDs/transforms/material settings, previews and a staging-only Studio recovery script. The user reported publishing the updated models before this backup. Existing latest gameplay changes from GitHub were retained unchanged. Native place files, Creator Hub settings and player DataStores are not included.

---

# Earlier model backup — 2026-09-14

The 38 installed Junkyard models now have a [final asset manifest](assets/junkyard-models/asset-manifest.json) and [Studio recovery script](assets/junkyard-models/restore-from-assets.luau). The [original template inventory](assets/junkyard-models/original-models.json) also records the earlier mesh/texture IDs and sizes. This supersedes the historical statement below that no item IDs are recorded in GitHub.

This is a reference-based backup: actual mesh/texture binaries remain hosted on Roblox and restoration requires access to those assets. It is not a native .rbxl/.rbxlx export or a DataStore backup. Other unpushed Studio script edits are outside this model-only commit. See the [model handoff](assets/junkyard-models/HANDOFF.md) for verification and limits.

---

# Backup status

All current scripts are backed up, including the original map geometry snapshot, the deterministic Foundry District builder, and the new Brainrot Island (`BrainrotService.luau` + `BrainrotRecipes.luau`). Read [map reconstruction and verification](docs/map-refresh.md) and [latest handoff](HANDOFF.md).

The map now has a tested source reconstruction path. This is not a native place-file export; live DataStore records and Creator Hub settings are not included. Future Studio edits do not automatically sync to GitHub. The latest map and gamepass changes have not been published to Roblox.

77 item meshes have been generated across `ReplicatedStorage.ItemModels` so far (most recently: 2 replacement Junkyard base vehicles — Muscle Car, Monster Truck — and 10 replacement Brainrot base creatures, after both item lines' base rosters were redesigned). Not all 77 are currently referenced by a live recipe — swapping either roster leaves the old names' meshes in `ItemModels` unused rather than deleted, since nothing reads them by name anymore but removing them isn't necessary either. None of this is backed up as repo assets — they are published Roblox mesh assets referenced by ID from `ReplicatedStorage.ItemModels`, the same way any other MeshPart's mesh/texture content lives on Roblox's asset servers rather than in Git. Only the placement/naming script logic (`ItemVisuals.luau`) is in source control. If this place file were ever lost, the meshes would need to be regenerated or re-inserted by asset ID — the IDs themselves aren't recorded anywhere in this repo.

Each plot's fusion pedestal was replaced with three physical placement zones (Garage/Workshop/Trophy Case) built by `PlotManager.server.luau` — fully reconstructable from script, same as the rest of the plot geometry. Player save data now includes a `placed` list (which items are sitting in which zone slots) and a `brainrotDiscovered` list; both are live DataStore state, not something Git tracks, same as coins or discoveries.

Each plot's fusion pedestal was replaced with three physical placement zones (Garage/Workshop/Trophy Case) built by `PlotManager.server.luau` — fully reconstructable from script, same as the rest of the plot geometry. Player save data now includes a `placed` list (which items are sitting in which zone slots); this is live DataStore state, not something Git tracks, same as coins or discoveries.
