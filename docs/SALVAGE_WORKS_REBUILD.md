# Open Salvage Works — September 23

Supersedes the subtle dressing pass in 13235b4. The user wanted a visibly new, brighter and more open junkyard, slightly larger but fair to all eight bases.

## Built

- Replaced the old skyline, thin canopies, gate lintels and scattered central obstacle piles with an open circular yard, full colored workshop shells, eight grouped scrap displays, an outer service road, low boundary landscaping and a water tower.
- Existing event crane remains at the center with its moving arm, drop origin and event reach intact.
- Yard diameter 190 studs (previous square width 160). Base-center radius 215 (previous 190). Outer service road radius 310 (previous 263). Plot size remains 70.
- Detailed props stay between approaches and outside the pickup area. Workshop shells sit behind the plot boundaries rather than blocking pad placements.
- Shared dimensions are in ReplicatedStorage.JunkyardLayout. PlotManager uses these for base centers and defense corridors; geometry and lasers remain aligned.
- Normal drops now use a uniform-area disk of radius 78 instead of a 130-wide square. All bases therefore see the same mathematical return-distance distribution. Spawn interval, cap, rewards and drop odds are unchanged.
- Owner signs moved perpendicular to each return lane after a walk probe found the former sign obstructed route 3.
- New builder is ServerStorage.SalvageWorksMap, called by MapBootstrap. MapBaseline, MapRevamp and SalvageWorksTouchup remain available in the repository but are no longer called by bootstrap.
- Daylight is brighter and less reflective; this uses shared Lighting settings. Other island geometry and scripts were not edited.

## Verified

Fresh Studio Play initializes eight plots and normal scrap drops with no Output errors. Geometry generation is idempotent. Current junkyard geometry totals 1,900 BaseParts, down from 3,776 original parts plus 857 from the superseded touchup.

All eight fusion-pad centers are 215 studs from origin. A symmetric 192-position sample gives the same mean straight-line pickup-to-pad distance (about 218.6924 studs) for every base. This is a geometry sample, not a measurement of real player matches.

Eight temporary NPC clones walked from radius 90 to the corresponding fusion pads at WalkSpeed 22. All completed in approximately 5.60 seconds, measured with 0.05-second polling and a 2-stud arrival tolerance. The initial test exposed route 3's sign obstruction; after moving the signs the full test passed. NPCs used each plot's owner collision group and were removed afterward; no inventory grants or player-data edits were performed.

Ground raycasts along the approaches passed. The central obsolete obstacles are removed, and the crane's DropOrigin marker is retained. Both other islands initialized normally. Tests are in assets/salvage-works/verify-layout.luau and verify-return-routes.luau, intended for Studio Server Play.

Still untested: multi-player combat/raiding under active defenses, manual carry/fuse and crane-drop round trips, and mobile performance. Lower part count is not a performance benchmark.

Screenshots: assets/salvage-works/rebuild-overview.png and rebuild-workshop.png show actual Studio Play. The art is implemented with Roblox parts; these are not the generated concept illustrations.

## Backups and recovery

ServerStorage.BeforeSalvageRebuild_1790183332 preserves the original MapBootstrap, PlotManager, ScrapSpawner, map folders, YardFeatures and LightingSnapshot. Earlier partial backups may also exist. LightingSnapshot stores changed global values as attributes and effect copies as children. Builder archives of retired map geometry and central obstacles remain in ServerStorage; none are review models left in Workspace.

To rebuild from Git, sync JunkyardLayout, SalvageWorksMap and the three modified server scripts, then start a fresh server. The builder replaces older authored junkyard folders with version 6, archiving those folders. To roll back in Studio, restore the three saved server scripts and map folders from the backup, remove the version-6 map folders, and restore the saved lighting settings/effects. Do not roll back player data.

Studio was returned to Edit mode. This task did not publish the place to Roblox.
