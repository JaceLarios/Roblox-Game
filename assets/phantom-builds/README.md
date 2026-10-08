# Phantom builds (samples) — Claude (2026-10-08)

Seven sample Spectral builds, one per base car, each wearing one of the Phantom addons (`assets/phantom-addons`). The user asked for them to see how the ghost addons look once fused onto a car.

| Build | Car | Addon | How it's mounted |
|---|---|---|---|
| Wisp Kart | Rusted Sedan (Scrap Kart) | Will-o'-Wisp Lanterns | Lantern rail across the bonnet, lanterns hanging forward |
| Skullsmoke Rider | Dirt Bike | Phantom Exhaust | A bone pipe down each side of the back wheel, skulls blowing smoke rings behind |
| Coffin Caddy | Golf Cart | Coffin Carrier | Coffin on its rack on the canopy roof |
| Banshee Muscle | Muscle Car | Banshee Horn | Horn bursting out of the hood like a blower, bell and sound rings ahead |
| Graveyard Patrol | Cop Cruiser | Graveyard Grille | The cemetery gate as the push bar, tombstone and mist out front |
| Specter Hauler | Box Truck | Specter Sails | Two torn sails on masts along the cargo roof (a ghost ship) |
| Wraith Crusher | Monster Truck | Wraith Wheels | Wisp-fire tread band, sidewall ring and spokes on every wheel (they roll), flames streaming back |

Every build also wears the haunted livery: violet enamel paint, night-black and bone panels, gold calipers, ectoplasm headlights, violet tail lights and ectoplasm underglow (not on the bike).

Since the Phantoms became event addons (later on 2026-10-08, `ReplicatedStorage.EventAddons`), these seven show for a plain base car wearing that Phantom and on their Index cards; every other ghost car is its own model drawn ghostly with the Phantom mounted (ItemVisuals).

These are the base car's own body, repainted, with the addon mounted on it. `docs/PHANTOM_MODELS.md` asks for more than that from the final 105 (the body itself reshaped by its ghost theme), so treat these as samples: a proper model installed under the same name replaces one (the installers back up what they replace).

## Files

- `build_builds.py`: Blender, in the background: `E:/blender.exe --background --factory-startup --python build_builds.py` (add `-- --norender` to skip previews, or `-- "Wisp Kart"` to build some). It loads the base car from `assets/warp-drive-batch/base-inputs`, runs `assets/phantom-addons/build_phantoms.py` up to its export for the addon parts (same seed, so they match the installed addons), leaves out each addon's display stand, then scales, turns and mounts the parts with ray casts against the car body. Writes one JSON per build, `manifest.json`, `Phantom-Builds.blend`, and a front and rear PNG per build.
- `phantom-builds-sheet.jpg`: all seven, front and rear.
- JSON format: like `assets/remaining-fusions`, with `base`, `addon`, `rarity: spectral`, `expectedWheels`, `targetSize`. Base car parts carry `clone` (the base car), `center`, `size` and the new `material` (or `null` to keep the original look) instead of geometry; addon parts carry their geometry, merged by material and wheel, with `geometryHash`, and `wheel` (id, pivot, radius) on the parts that roll.
- `import.edit.luau`: Studio Edit mode. Serve this folder on `http://127.0.0.1:8768/` first. Copies each base car's parts from its model in `ItemModels` (after checking size and position match), repaints them, uploads only the new parts as Mesh assets, recentres the model and its wheel pivots, and stages the builds in `ServerStorage.PhantomBuilds_Staging_<time>`. Poll `_G.PhantomBuildImport`.
- `install.edit.luau`: checks recipe, rarity, wheel count and the 90k triangle budget, moves the builds into `ReplicatedStorage.ItemModels` (backing up any same-named model), then checks a viewport copy, a world copy, rolling wheels and resizing. Rolls back on any failure.

## In Studio (2026-10-08)

Imported and installed: 46 uploaded meshes, 178 copied base parts. Sizes match the export, every wheel rolls (the Wraith Crusher's fire wheels too), all seven sit on the ground. Model attributes: `FusionBase`, `FusionAddon`, `Rarity=spectral`, `NoseAxis=+Z`, `ExpectedWheels`, `WheelPivotRecentered`, `VisualRevision=PhantomBuilds_20261008_v1`.

| Build | Triangles | Size (X, Y, Z studs) |
|---|---|---|
| Wisp Kart | 74,456 | 3.31, 3.21, 4.95 |
| Skullsmoke Rider | 46,802 | 2.00, 2.56, 4.78 |
| Coffin Caddy | 72,082 | 3.10, 5.51, 5.86 |
| Banshee Muscle | 71,597 | 2.60, 2.51, 5.56 |
| Graveyard Patrol | 71,000 | 3.10, 2.97, 6.61 |
| Specter Hauler | 89,826 | 3.60, 7.43, 7.47 |
| Wraith Crusher | 86,062 | 3.67, 3.06, 4.78 |
