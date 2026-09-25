# Rolling cars update — 2026-09-24

Changes: Monster Truck widened from 2.8 to 3.55 studs, preserving the bright blue/orange cartoon design. Golf Cart now carries two colored golf bags with drivers and irons. Scrap Kart retains its cushioned seat and titanium heat-stained exhausts, now facing rearward with engine-connected headers.

All seven base cars now export wheel meshes separately from the chassis, with WheelId, WheelPivot and WheelRadius metadata. Brake calipers remain stationary. Circular wheel cross sections replace the older nonuniformly scaled tires; some vehicles consequently sit slightly lower. Exact final bounds are in manifest.json.

ItemVisuals.RollWheels advances visual wheel rotation from signed distance / radius around each axle. Resize preserves pivot, radius and current phase. Destroying an assembly clears its cached rig. ScrapSpawner calls this only while the item is still riding the conveyor. Pickups and despawns retain their existing behavior. The conveyor stays kinematic; this is not a new suspension or driving physics system. Existing RaceService/RaceDrive are unchanged.

Source: build_cars.py and Junkyard-Seven-Base-Cars.blend. Geometry exports have centered material groups for Roblox's thin-MeshPart behavior. Installation corrects wheel metadata for any final recenter offset. Old models and both scripts are preserved in ServerStorage before installation. No player data changed.

Installed and verified. See installed-models.json and verification.json. Backup: ServerStorage.CarsBeforeRolling_1790315333. All 21 scaled assemblies and the actual conveyor loop passed edit-mode checks. Multiplayer replication, mobile performance and player driving remain untested. Included in this GitHub handoff. Publishing to Roblox remains a separate Studio action.
