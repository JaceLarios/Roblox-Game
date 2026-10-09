CIVIC BASE AND ADDON VARIANTS
2026-10-08

The approved rusty base and 31 restored variants are backed up here as native
Blender scenes with packed textures. They have not been installed in Roblox.

APPROVED MODELS
source/Honda-Civic-Loose-Bumper-v4.blend: weathered base with the hanging front
bumper, realistic glass, defined headlights, rust, scuffs and wheel detail.
v2/: 16 mechanical variants and 15 Phantom concepts. Every fused car has clean
paint and repaired front bodywork. catalog.json lists each design and preview.
Straight Pipes has two tall rear stacks with open, heat-blued tips. Twin Turbo
has a true rear bumper delete and two rear-facing turbos with exposed plumbing.
The native scenes are byte-for-byte copies of the approved local sources.

PREVIEWS
v2/mechanical-lineup.jpg, v2/phantom-lineup.jpg,
v2/new-placement-closeups.jpg and the individual PNGs.
v2/Twin_Turbo-rear-detail.png shows the bumper-delete construction.

LATEST GAME COMPATIBILITY
Main d36f6e3 changed Phantoms into an event layer on any car, retained through
later mechanical fusions. These 15 authored Civic Phantom variants are retained
as optional base-car/Index concepts. They are not 15 new mandatory fuse recipes.
Do not restore the obsolete per-Phantom recipe design to import this collection.
The Civic is not yet registered among FusionRecipes' seven base cars. Working
labels in this folder are not approved runtime IDs or item values.

REBUILD
Use Blender 5.2.2 (authoring version), from a complete repository checkout:
  blender --background --python-exit-code 1 --python assets/civic-fusions/v2/build-v2.py -- 0 31
Indices are zero-based with an exclusive end; -- 1 2 rebuilds Straight Pipes.
Back up any edited scenes first: the builder replaces outputs for the chosen
range and writes the full catalog. Run build-v2.py; build-civics.py supplies its
shared functions and its direct-run layout is the older version.
source/Honda-Civic-Rusted-v2.blend is the rebuild seed, not the approved base.
Addon libraries are reused from assets/new-addons, warp-drive-batch and
phantom-addons. FusionRecipes.reference.luau pins the original f6e79c6 catalog
for repeatable authoring; it must never replace the game's current module.

CHECKS
package-manifest.json records SHA256 for the copied files. validate-package.py
opens all 33 scenes (32 approved models plus the seed), checks those hashes,
packed textures and repository-relative builder dependencies.
v2/validate.py checks all 31 restored bodies, expected addons and scene bounds.
v2/check-rear-exhausts.py checks the tall outlets and genuine bumper deletion,
then renders the rear detail view. JSON reports record their results.

ROBLOX IMPORT STILL REQUIRED
Optimize geometry and bake the Blender materials to Roblox-supported textures.
Native scenes are detailed authoring assets, not a measured in-game mesh budget.
Export visible model geometry from every addon collection; omit the preview
floor, lights and cameras. Source fronts point along Blender -Y; convert to
Roblox +Z and standardize scale. Keep separate wheels and their pivots/radii.
Preserve named Glass parts/materials so the race seat goes inside the cabin.
Confirm runtime names, prices and recipes; check Phantom mount positions and
VehicleAddonEffects offsets. Glow in a render is not dynamic in-game VFX.
Test hotbar hold, conveyor, pads, fusion, seat placement and races after import.
Studio has not been modified by this backup/review pass.

PROVENANCE
source/source-record.json preserves the downloaded Civic archive name and hash.
Keep the source car and addon attribution/license records with any exports.
No new source license or publication clearance is asserted by this backup.
