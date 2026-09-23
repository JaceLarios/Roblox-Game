# Compact Salvage Works touchup

Historical pass, superseded by the open-map rebuild described in docs/SALVAGE_WORKS_REBUILD.md. Current entry point is SalvageWorksMap; the small touchup is no longer run.

Approved direction: the first Salvage Works concept, adapted to the existing footprint rather than a larger redesign.

Implemented by `src/ServerStorage/SalvageWorksTouchup.luau`, called after YardFeatures.Build in MapBootstrap.

- Eight existing garage shells: teal, blue and orange siding; raised seams; roof repairs; safety bands; readable bay signage.
- Twelve existing climbable wreck blocks: wheels, hubs, bumpers, windows, handles, roof patches and grille detail.
- Central crane: safety stripes, repair plates, ladder and sign. Moving arm, pivot and magnet drop origin unchanged.
- Short asphalt seams, small gravel/weed details beside staging pockets, and lower color bands on eight nearby district buildings.

Studio backup: `ServerStorage.BeforeSalvageWorks_1790182426` contains the three original map folders and original MapBootstrap. Original colors/materials are also retained as attributes on repainted parts. Original label colors are stored on the affected labels.

No map expansion, plot relocation, new collision geometry, spawn adjustment, economy changes or other-island edits. Added 857 anchored decorative parts with CanCollide/CanTouch/CanQuery disabled. Original models remain recognizable block-based Roblox geometry; this is a modest dressing pass, not a reproduction of all concept-art detail.

Verification: compared all 3,776 original map parts against the backup; transforms, sizes and collision/query/touch flags match. Repeat Build returns the existing folder without duplication. Fresh Play starts correctly with eight plots; deleting and rebuilding only the decoration folder in runtime reproduced 857 parts. Crane drop origin remains present and a raycast at (30,0,0) reaches the original pickup floor at Y=1.2. Normal scrap drops appeared in Output with no errors.

Still untested: a full manual pickup/fuse/crane-event session and mobile performance. No publishing was performed.

Recovery from Git: sync the module and updated bootstrap; the next server start reconstructs the dressing. For rollback, disable the touchup call, remove Workspace.SalvageWorksTouchup, and restore the three original map folders from the Studio backup. Alternatively restore the saved original color/material/text-color attributes on changed objects. Keep backups in ServerStorage.
