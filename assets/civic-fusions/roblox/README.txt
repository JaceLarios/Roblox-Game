CIVIC ROBLOX IMPORT - 2026-10-09

Installed in Untitled Experience, place 94136201094216, ItemModels.
Revision Civic_20261009_v1: Civic base, 16 mechanical builds, 15 Phantom looks.
studio-models.json is the actual installed snapshot, including persistent mesh
and image IDs, material references, transforms and wheel/cabin attributes.
The source Blender scenes are unchanged. No live Roblox publish in this pass.

RECOVER EXACT INSTALLED MODELS
Run restore.edit.luau in Edit mode. It is self-contained and restores all 32
into a new Civic_Restored_<time> folder in ServerStorage. It does not overwrite
ItemModels or any game scripts. Existing materials are reused. A successful
restore sets RestoreComplete=true. The recovery was run and checked against all
32 installed templates, then its temporary duplicates were removed.
Preserve newer work and inspect before replacing any live templates. Pair the
models with the current repository's FusionRecipes and RaceService; avoid old
authoring reference modules. DriverCabin is set only on the actual window mesh.

REBUILD
From repository root:
  blender --background --python-exit-code 1 --python assets/civic-fusions/export-roblox.py -- 0 32
  python assets/civic-fusions/bake-paint.py
The second step needs Pillow. Export generates the ignored meshes/ cache and
per-model metadata. Paint baking is idempotent and preserves original tints.
Textures are capped at 2048; the rusty base uses Cycles surface bakes.
No part exceeds 6,500 triangles; each complete model is below 78,000 triangles.
The importer reuses shared meshes and records authored material-map IDs.
import.edit.luau is the original upload/staging pipeline using localhost:18773;
install.edit.luau additionally expects the private pre-import source snapshots
and an unchanged live registry. Prefer the self-contained restore for recovery.
The served FusionRecipes, RaceService and ItemVisuals copies record the versions
used for this import, not permanent sources of truth for future game updates.

MATERIALS
Roblox MeshPart.TextureID uses the baked approved diffuse colors. Glass/Metal/
Neon and existing AddonDetail_* / AddonCarbonTwill variants supply the finishes.
SurfaceAppearance was not left installed: newly uploaded PBR instances rendered
gray and one metalness asset was rejected for the requester. All authored normal,
roughness and metalness references are preserved as Authored* attributes for
later editing. Do not claim a complete Blender-to-Roblox PBR match.

VERIFICATION
import-test-report.json: overall result and explicit limits.
lifecycle-test.json: all 32 viewport/world/rolling/resize/conveyor-fit/race-build
checks, effects on all 31 fused models, all Phantom overlays and mutation cases.
live-hotbar-tests.json: all 32 actual Tool equip, HeldItem, place and unplace.
gameplay-examples.json: actual fusion/Phantom results and measured pad earnings.
race-driving-test.json: real race physics samples for Civic, Twin Turbo, Hover
Fans and Wisp Twin Turbo; acceleration, a steering turn and braking all passed.
Inputs were injected through VehicleSeat on the client Heartbeat. Virtual key
input did not register through the Studio test tool; its RenderStepped callback
also returned no frames. This is not a claim of manual driving all 32 cars.
Final Edit viewport inspection covered all 32 with native window screenshots.
Multiplayer load, device-specific inputs and mobile performance need a separate
playtest. No saved inventory or money was used or changed by these tests.

QA SCRIPTS
prepare-playtest.edit.luau temporarily isolates saved data and exposes hooks.
playtest-controller.server.luau belongs only in the isolated Play server.
Always stop Play and run restore-test-sources.edit.luau afterwards. Never publish
the QA source overrides. That cleanup was completed for this import.
snapshots/ contains ignored local recovery originals; meshes/ is rebuildable.
