# Backup status

All thirteen current scripts are backed up, including the original map geometry snapshot and the deterministic Foundry District builder. Read [map reconstruction and verification](docs/map-refresh.md) and [latest handoff](HANDOFF.md).

The map now has a tested source reconstruction path. This is not a native place-file export; live DataStore records and Creator Hub settings are not included. Future Studio edits do not automatically sync to GitHub. The latest map and gamepass changes have not been published to Roblox.

All 34 item meshes (12 Tier 1 plus 22 fused results) are NOT backed up as repo assets — they are published Roblox mesh assets referenced by ID from `ReplicatedStorage.ItemModels`, the same way any other MeshPart's mesh/texture content lives on Roblox's asset servers rather than in Git. Only the placement/naming script logic (`ItemVisuals.luau`) is in source control. If this place file were ever lost, the meshes would need to be regenerated or re-inserted by asset ID — the IDs themselves aren't recorded anywhere in this repo.
