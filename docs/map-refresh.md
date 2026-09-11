# Foundry District map refresh — 2026-09-11

## What changed
The original eight-spoke junkyard is now a colorful industrial district:
- Eight color-coded workshop bays with canopies, tool boards, rotating fans, lights, numbered signs, and styled fusion/sell pads.
- Gateways and colored route guides around the central shared scrap yard.
- Corrugated shipping containers, stacked salvage crates, a Parts & Co. service kiosk, and a lattice crane with a gently moving magnet.
- A circular delivery lane with a cosmetic moving forklift.
- Benches, planters, street trees, rocks, distant hills, and windows/roof details on the existing skyline.
- Updated teal/orange/cream palette and afternoon lighting.
- Original walkways and curbs now end at plot entrances instead of cutting across the plots.

![Foundry District overview](foundry-district.jpg)

## Source files and reconstruction
- `src/ServerStorage/MapBaseline.luau`: a compact snapshot of 543 original instances, including the 534 scene descendants, scene root, spawn/decal and lighting objects. Stores original transforms, sizes, colors, materials, relevant properties and attributes. Roblox-reserved attributes are skipped on restoration.
- `src/ServerStorage/MapRevamp.luau`: deterministic map builder, currently version 5. Creates `Workspace.JunkyardRefresh`, applies the palette/path changes to `JunkyardScene`, and styles runtime plots.
- `src/ServerScriptService/MapBootstrap.server.luau`: restores the original map only if it is absent, builds the refresh if needed, and styles all plots.
- `src/StarterPlayer/StarterPlayerScripts/MapAmbience.client.luau`: visual-only movement capped at 30 updates/sec with distance checks. Fans/magnet use atomic streaming; the one delivery vehicle is persistent. Late-streamed models are registered.

`default.project.json` maps the repository's 12 script files into the correct Studio services. With Rojo installed, a fresh place build can load these scripts and reconstruct the map on Play. Rojo CLI build itself was NOT run on this machine (Rojo was not installed). Unknown Studio instances are preserved by the project configuration.

For Edit-mode reconstruction after importing the scripts, use the Studio Command Bar:
```lua
require(game.ServerStorage.MapBaseline).Restore()
require(game.ServerStorage.MapRevamp).Build()
```
The existing Studio session already has the map applied. Both calls are idempotent. ModuleScripts are cached by require; after editing MapRevamp in the same Edit session, use a fresh clone for preview or reopen the place. Bump the builder version before regenerating changed geometry.

For rollback, first save a place copy, remove the generated JunkyardRefresh folder and archive the current JunkyardScene, then call MapBaseline.Restore(). Disable/remove MapBootstrap and MapAmbience to prevent the refresh from being reapplied. The original snapshot is also retained in Git history.

## Verification
- All eight pre-existing gameplay and gamepass scripts were reread and preserved byte-for-byte.
- New map scripts compiled.
- Isolated reconstruction restored all 534 original scene descendants and the spawn, then recreated all 3,338 refresh descendants; repeated restore/build calls did not duplicate objects.
- Refresh contains 3,048 anchored parts, of which only 28 collide. Collision overlap checks found no new colliders in the 130x130 scrap spawn square, the eight access routes, or the eight 70x70 plot footprints.
- Final Play startup created/styled all eight plots and loaded the existing UI. Final Output contained no gameplay errors.
- Actual character navigation reached the first fusion pad with full health.
- Forklift, fan and crane movement were observed in client state; streaming-aware animation changes were retested.
- Final plot checks found no original curbs crossing the plot interiors.
- Wide and close screenshots were visually reviewed, including a runtime workshop view.
- The existing 2,580-coin balance loaded unchanged; no manual player-data edits or purchases were made.

## Limits and next steps
- This is a source-based reconstruction backup, not a native .rbxl/.rbxlx export. A native place export is still useful to preserve all Roblox settings and any future content added outside this map builder. Live DataStore records, unpublished external assets, and Creator Hub settings are not stored in Git.
- The new map is applied in Studio but NOT published to Roblox.
- Low-end device performance and full multi-player sessions have not been benchmarked. Most of the approximately 3,000 new parts are static facade/decor details; window/corrugation shadows and decorative collisions are disabled.
- The gamepasses still need real IDs, prices and live purchase testing; see HANDOFF.md.
