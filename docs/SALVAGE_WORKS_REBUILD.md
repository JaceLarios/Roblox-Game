# Enclosed Salvage Works workshops — September 23

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
