CIVIC BASE AND ADDON VARIANTS
Updated 2026-10-09

The approved rusty base and 31 restored variants are backed up here as native
Blender scenes with packed textures. All 32 are now installed in Studio place
94136201094216, ReplicatedStorage.ItemModels (Civic_20261009_v1).

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
The Civic is now the eighth base car. Runtime names are Civic, Civic + <addon>
for the 16 mechanical builds, and <ghost> Civic for the 15 Index/base-car looks.
Common base value 12, weight 12, multiplier 1.18, shift -1 fit between Dirt Bike
and Golf Cart; existing relative spawn weights are preserved (total now 100).
The game's current event-layer design is preserved, including Phantoms carried
through later mechanical upgrades. Named Phantom builds are not extra recipes.

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

ROBLOX IMPORT AND RECOVERY
roblox/README.txt describes the completed import, recovery and test evidence.
All meshes face +Z. The 32 templates contain 882 parts / 471 unique meshes;
52,616-77,634 triangles per model. Geometry is shared by asset ID. Wheels have
their existing pivots/radii; Hover Fans and Wraith Civic intentionally have none.
The approved Blender scenes remain unchanged. Rust and paint colors are baked
to diffuse atlases; glass, chrome, neon and existing carbon/detail variants are
used in Studio. Authored PBR maps are retained but are not all active in Roblox.
The explicit DriverCabin part attribute keeps addon glass out of race seating.

All 32 passed viewport/world, wheels, conveyor fit, resize, race construction,
hotbar equip, earning-pad placement and unplacement checks. Live pickup/delivery,
fusion, earning, Phantom retention and four driving cases also passed. Driving
used simulated VehicleSeat input with the actual game physics; native keyboard
input did not register through the test tool. All 32 were visually checked in
the Edit viewport. Full multiplayer/mobile performance was not measured.
Tests used isolated data with saves/leaderboard writes disabled. All seven
temporary source overrides were restored and Studio returned to Edit mode.
This installs into the open Studio game; no live-place publish was performed.

PROVENANCE
source/source-record.json preserves the downloaded Civic archive name and hash.
Keep the source car and addon attribution/license records with any exports.
No new source license or publication clearance is asserted by this backup.
