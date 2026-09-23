# Enclosed Salvage Works workshops — September 23

## Mechanic equipment (map 12)
MechanicProps adds a rolling tool cabinet with socket tray/wrench, hydraulic floor jack, compressor with motor/gauge/coiled hose, and bench hammers/wrenches/oil cans to every workshop. Cart drawers face inward. Eight small alternating cart/jack and compressor stations sit at radius 87 between return lanes, outside the 78-stud pickup disk. No signs or interaction prompts added.

Verified all eight workshop sets and eight yard stations exist; every equipment part is anchored with collision/query/touch disabled, and yard-part footprint corners remain outside the pickup disk. Actual Play visual checks and Output inspection passed. Equipment is decorative, not usable upgrade/pickup items. Backup BeforeMechanicProps_1790187591. No player data changes or Roblox publishing.

## Lighting and world boundary revision (map 11)
WorldEnvironment configures a bright blue built-in sky, native Terrain Clouds, light atmospheric haze and daylight. Each workshop now has 15 suspended ceiling lights in three rows plus three warm rear task lights. Max normal player camera zoom is 40 studs.

Continuous rock ridges, planted crests, trees and ground extensions enclose Junkyard, Brainrot and Haunted outside existing play geometry. WorldBackdrop is a Persistent model to retain the horizon under streaming. No island gameplay or item data was changed. Zone centers/radii live in WorldEnvironment and should be updated if islands move.

Verified 1,080 horizontal horizon rays per area (360 directions at heights 5, 45 and 65), 15 ceiling lights in each of eight bases, enabled clouds, player zoom cap, fresh Play without Output errors, and visual sky/interior/island checks. This covers ordinary play views, not arbitrary Studio/free-camera positions. Mobile lighting performance remains untested. Backup BeforeLightingBackdrop_1790187029 contains previous source, Lighting children/properties and previous zoom distance. Not published to Roblox.

## Latest revision: visibility windows (map version 10)
Lock buttons are now at each workshop's rear center (local X=0, Z=35), with the rear benches split to keep access clear. Decorative writing, wall artwork, floor-number signs and owner signposts have been removed. Functional prompts and gate lock status remain.

Each workshop has five large transparent, collidable glass openings: one on each side, one rear, and two flanking the front door. Walls are segmented around the glass, with low 3.5-stud sills for player-height visibility; there is no opaque wall backing. Enclosure and the eight pads are retained.

Verified all eight bases have rear-center buttons, five collidable windows and no decorative TextLabels. Window raycasts hit glass; actual Play screenshots confirm visibility outside. Exercised all eight entrance laser colliders/visuals on and off, then used the actual rear LockPrompt to activate Plot1's eight doorway beams and barrier. Fresh Play Output showed no errors. Backup: ServerStorage.BeforeWorkshopWindows_1790185531. Earlier details below describe the initial workshop pass.

Supersedes the open-map pass in 24ff658.

## Current build
- Eight enclosed mechanic workshops, 86 by 86 studs, centered 200 studs from the yard center. Each faces its own radial approach.
- Solid side/rear walls, front wings, lintel and roof. Owners also collide with workshop walls; the only ground-level entrance is the 26-stud laser doorway.
- Eight earning pads per base, four on each side. Saved slot order is preserved. Inventory fits eight slots within its available row width.
- Tall 36-stud walls reserve space for a future second floor; stairs and upper-floor gameplay are not installed.
- Original car-blueprint wall artwork, workshop signs, bench, drawers, tools, windows, vents, beams, overhead lights, rusty repairs, tyre stacks and marked pad bays.
- BaseGate validates owner, distance, living character and cooldown on the server. Visitors are blocked for 60 seconds, while owners can pass. Existing 60-second recharge and server-side theft rejection remain. Two shields cover the pad banks.
- Salvage piles use existing detailed vehicle models, support racks, containers and barrels. Pockets moved inward to avoid workshop intersections.
- Yard diameter remains 190; outer road radius is 285. Eight items can earn income, but the placed-item movement bonus stays capped at +10.
- Map version 9 is built by SalvageWorksMap and Workshop. No other-island geometry/gameplay edits. Existing global brighter Lighting settings remain.

## Verified
Fresh Play initialized all eight bases and both other islands without Output errors. Every base has eight pads in the correct four-left/four-right positions. Raycasts verified enclosing walls/roof/front wings and a clear doorway.

The real LockPrompt activated the lock. Temporary humanoid clones tested the new entrance with owner/visitor collision groups: owner crossed to X=163.74, visitor stopped at X=155.79 outside the X=157 doorway. Earlier timer testing observed reopening and recharge. BaseGate checks cover ownership, distance, duplicate activation, cooldown, recharge and unclaimed reset.

Eight owner NPC route probes reached their fusion pads in about 4.97–5.52 seconds at WalkSpeed 22. This tests geometry only: NPCs do NOT trigger the player-only lethal road lasers. It is not a timing of real player obstacle runs. Symmetric samples show equal pickup-to-pad distance distributions (mean 203.974 studs). Ground checks pass; crane DropOrigin remains.

Desktop inventory has eight cards within its row. DataManager saves/loads the entire placedPets list without a five-slot clamp; placement, redraw, UI capacity and income loops use the shared count. Existing saved items loaded in Play. No data resets or test-item grants.

Untested: saving/reloading eight occupied pads, real two-client theft/raids, mobile layout/performance, full pickup/fusion/crane playthrough.

## Recovery
Sync Workshop, BaseGate, JunkyardLayout, PlotManager, GameUI and SalvageWorksMap with the rest of the repository. MapBootstrap builds the map; PlotManager builds runtime pads and gates on fresh server start.

Studio backups: BeforeEnclosedWorkshops_1790184814, BeforeDetailedYardAndLocks_1790184185, BeforeSalvageRebuild_1790183332. Retired maps remain archived in ServerStorage. Do not reset player data on rollback. Preserve extra items if reverting to five slots after players fill eight.

Actual Play screenshots: assets/salvage-works/workshop-interior.png and workshop-locked-exterior.png. No Roblox publishing performed.
