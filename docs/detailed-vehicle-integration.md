# Detailed Junkyard base vehicles

Installed 2026-09-23: Scrap Kart (stable key Rusted Sedan), Dirt Bike, Golf Cart, Muscle Car, Cop Cruiser, Box Truck and Monster Truck. Existing saves and recipes retain their keys. Existing fused models and addons are unchanged.

All production Studio scripts are backed up under src. This includes prior unpushed display-name fixes and leaderboard integer-save fixes. Latest recipe and permanent-pet-boost changes from main 0374760 are retained.

Recovery: restore scripts using the existing project workflow, then run assets/detailed-vehicles/restore.luau from the Studio Command Bar in Edit mode. It builds all seven models from the complete serialized hierarchy and Roblox-hosted mesh references before swapping templates; replaced templates are backed up in ServerStorage. Do not run the older junkyard-models restore afterward, because it would replace the seven detailed bases with older models. Roblox asset access is required; the binary assets are hosted by Roblox, not GitHub.

The ItemVisuals loader returns a BasePart handle with welded details and supports viewport rendering, whole-model tint/transparency and pickup resizing. GameUI, PlotManager, PickupEffects and ScrapSpawner were adapted accordingly. IndexGallery and FusionCelebrationView already accept Model templates.

Verified in Studio: 32 scale/ground/viewport checks; seven assembly movement and shrink tests; all 31 mesh/texture references loaded; Index and Inventory rendered; real Muscle Car pickup/carry retained 49 aligned parts; no errors in Output. Published-server and mobile stress tests remain untested. No place publish performed. Pre-integration backups are in ServerStorage.CodexVehicleIntegration_20260923.

UI redesign is pending confirmation of the user's earlier concept image. No new UI redesign is included in this backup.
