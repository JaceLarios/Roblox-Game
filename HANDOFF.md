# Latest handoff — placement economy: passive income + tiered zones (2026-09-11)

The core loop changed: fusing no longer puts the result on a single pedestal for one manual sell. Instead it **auto-places into one of three zones on your plot**, based on tier, where it earns coins every few seconds for as long as it stays — sell it anytime instead for an instant (smaller) payout. This replaces the "fuse → sell → repeat" loop with "fuse → build a collection → passive income scales with how many rare things you've placed."

**Zones** (physically built into each of the 8 plots, behind the fusion pad): `GARAGE` (Tier 2, 4 slots), `WORKSHOP` (Tier 3 non-secret, 3 slots), `TROPHY CASE` (Tier 4+ and all secrets regardless of tier, 2 slots). A result auto-places into the first empty slot of its zone; if that zone is full, the result drops back into the shared yard instead of being lost, with a toast telling the player to clear a slot.

**Income formula:** each placed item earns `value / 90` coins/sec (a `PLACEMENT_PAYBACK_SECONDS` constant — roughly how long it takes passive income to match a manual sell, after which it's pure profit for as long as it's placed). The Haggler upgrade and the timed 2x-sell boost both apply to this rate too, not just manual sells (see `valueMultiplier` in PlotManager). Income is credited server-side every 3 seconds (`INCOME_TICK_SECONDS`) by summing all filled slots across a player's zones.

**Persistence:** `DataManager`'s default save data gained a `placed` field — a list of `{zone, slot, itemName, value}` records, written by `snapshotPlaced` (in the same autosave/leave/shutdown paths as everything else) and restored on join by re-rendering each saved slot. Old saves without this field default to `{}` via the existing "fill in any field a newer version added" merge, so no migration was needed.

**Regression caught and fixed:** removing the single "Pedestal" part broke `MapRevamp.DressPlot`'s `plot:WaitForChild("Pedestal", 10)` dependency (a 10s no-op wait, not a crash, but per-plot cosmetic dressing — pad color, trim — silently stopped applying). Fixed: `DressPlot` now trims the three zone sign posts instead of the old pedestal, and `MapBootstrap` waits on `garageSign` instead of `Pedestal`. Worth remembering: MapRevamp/MapBootstrap look up PlotManager's part names by string, so future PlotManager renames should grep MapRevamp for the old name first.

**Verified in Studio Play**, end to end, via actual ProximityPrompt-triggered gameplay (not just command-bar calls): grabbed real items, fused a valid Tier 2 recipe, confirmed it rendered in the correct zone slot with the correct coins/sec label, watched the coin count actually increase over several seconds from passive income alone, sold a placed item via its own prompt and confirmed the slot cleared, then **stopped and restarted Play** and confirmed the placed item was restored from the save data into the same slot. No console errors at any point. Not tested: multiple concurrent players, a zone actually filling up (the "returned to the yard" full-zone path), and the live published game.

Tuning knobs if the economy feels off: `PLACEMENT_PAYBACK_SECONDS`, `INCOME_TICK_SECONDS`, and each zone's `capacity` are all in the `ZONES` table / constants near the top of `PlotManager.server.luau`.

---

# Previous handoff — detailed item models, all 34 (2026-09-11)

All 34 items — the 12 Tier 1 base items plus all 22 fused results (10 Tier 2, 6 Tier 3, 3 Tier 4, and the 3 secrets) — now have real AI-generated detailed meshes instead of the plain gray/neon placeholder. Tier 2-3 mostly read as literal mashups of their two ingredients (e.g. Boosted Beater is a sedan with a nitrous tank bolted in); Tier 4 and the two same-item secrets (Cone Sentinel, Cartpocalypse) came out as creative robot/creature interpretations rather than more vehicles, which reads well for "boss" tier content. Scrapyard God (the Tier 5 ultimate secret) is a large mech design.

**How it works (unchanged from the Tier 1 pass, no code changes needed for this batch):** each mesh is a single textured `MeshPart` in `ReplicatedStorage.ItemModels`, named exactly after its item. `ReplicatedStorage.ItemVisuals` exposes `Create(itemName, position, sizeScale)` and `HasModel(itemName)`. `PlotManager.showOnPedestal` already checked `HasModel` before falling back to the neon box, so adding these 22 templates made real meshes start appearing on the pedestal automatically — that fallback path is now effectively dead in practice (every item has a model), but it's left in place in case a 35th item ever gets added without a model yet.

Two prompts hit Roblox's content moderation on the first try and needed rewording: anything phrased as "police pursuit vehicle" (Pursuit Bike) and the word "sonic" alone (Sonic Scrapheap) triggered rejection. Reworded to "warning light bar / racing livery" and "flame-covered drag racer parts" respectively — both then succeeded. Keep this in mind if modeling more items later.

Verified in Studio Play: no console errors during a full play session with items spawning/carrying. `ItemVisuals.HasModel`/`Create` were directly exercised in the command bar for one item per tier (Boosted Beater, Redline Reaper, THE LAWNLORD, Scrapyard God) confirming each resolves to the real mesh. Not tested: an actual live fusion completing on the pedestal through the real UI/ProximityPrompt flow (only the underlying function calls were tested directly), and the live published game (this was Edit/Play-mode Studio only, not published).

Nothing left to model for the current 34-item recipe list. Next work would be new content (new recipes) or the still-outstanding gamepass setup (see the previous handoff below).

---

# Previous handoff — map refresh (2026-09-11)

The Foundry District map refresh is applied in Studio and backed up in this repository. Read [docs/map-refresh.md](docs/map-refresh.md) first for the exact files, verification, reconstruction steps, and remaining limitations.

**Map geometry is now backed up as reconstructable source.** MapBaseline contains the original authored parts/spawn/lighting and MapRevamp creates the new map. This supersedes the older statement below that only gameplay scripts were backed up. A native place-file export is still useful for additional settings and future content outside the builder.

Studio is in Edit mode. No Roblox publish was performed. All eight previous gameplay/gamepass scripts are unchanged. The map adds four scripts, bringing the total to twelve. The gameplay economy and player records were preserved.

Next work: create/configure the three gamepasses and their prices, test real purchases, publish when ready, and finish the earlier earn-leave-rejoin coin-persistence verification. Do not assume any of those steps was completed by the map task.

---

## Previous gamepass handoff (historical detail)

# Claude handoff — gamepasses (2026-09-11)

## Current state
The Studio edit session for place 94136201094216 (experience 10765869706) contains the gamepass integration. Studio last reported published place version 12 before these edits. These changes have NOT been published to Roblox. Studio is back in Edit mode.

Three passes are implemented but NOT created or on sale. The owner confirmed no passes exist yet. All IDs in ReplicatedStorage.GamepassConfig are 0, so purchase buttons show COMING SOON and ownership API calls are skipped. Do not claim monetization is live.

## Files
- ReplicatedStorage.GamepassConfig (ModuleScript): IDs, names, descriptions.
- ServerScriptService.GamepassService (ModuleScript): server-only ownership cache, join checks, 3 attempts on errors, periodic retry/external purchase refresh, trusted server purchase event, and benefit calculations.
- StarterPlayer.StarterPlayerScripts.GamepassUI (LocalScript): separate shop, client-fetched Roblox prices, explicit purchase button, owned/checking/unavailable states, responsive panel, no client authority over benefits.
- ServerScriptService.PlotManager (Script): uses the service for earnings, carry capacity and magnet range. Reward displays and sale previews include the coin multiplier.

Existing GameUI, FusionRecipes, ScrapSpawner and DataManager were preserved exactly. No datastore schema or stored balance reset was performed. The old unused maxSlots state field remains for minimal diff; functional capacity checks now derive from carry level plus pass ownership.

## Benefit decisions
- 2x Coins doubles newly earned sales, objectives, daily coin/jackpot rewards and playtime coins. It does not multiply loaded balances. Sale multipliers from Haggler and timed boosts apply first, then the pass multiplier applies once.
- Extra Carry adds 2 slots to earned capacity: 4 at the initial carry level, 8 at maximum earned carry.
- Auto-Collect unlocks the existing 20-stud magnet behavior. Higher coin-earned magnet levels still extend range (up to the existing 70 studs); cadence remains one nearby item per 1.5 seconds. It neither auto-sells nor auto-fuses.
- Pass ownership is queried from Roblox on join, not saved in player DataStores. A successful server purchase event applies benefits immediately. Client events cannot claim ownership.
- Ownership API failure grants nothing, shows retry state, and retries periodically. During an unresolved ownership check, the default non-owner earnings apply.

## Verification actually completed
- All 4 new/changed scripts compiled with Luau.
- 13 isolated mocked-service checks passed: zero-ID handling, normal coins/carry/magnet behavior, owned-on-join, coin multiplier, carry stacking, magnet stacking, cancelled/unknown purchases, idempotent confirmed purchase, failed lookup retries, and leave cleanup.
- Studio Play started with all 8 plots and 22 recipes. Existing main UI and new GamepassUI both loaded.
- Actual mouse clicks opened and closed the pass panel.
- All three zero-ID purchase buttons were inactive and read COMING SOON; server ownership flags remained false.
- Panel bounds fit 390x844 and 844x390 by resizing its UI container. This was a layout bounds check, not full mobile-device emulation or visual screenshot review.
- Output had no errors during the Play check. DataManager loaded 2,580 coins and 3 discoveries; coins were still 2,580 before stopping.
- All 8 script sources were reread after stopping and matched the expected unchanged/new content.

## Still needed
1. Creator Hub > Creations > this experience > Monetization > Passes: create the 3 passes with suitable icons/descriptions.
2. Copy each pass Asset ID into GamepassConfig. No prices have been chosen or configured. Agree prices with the owner and set Sales/Item for Sale in Creator Hub. Use the same experience's passes.
3. Publish the updated place to Roblox when ready.
4. Test real IDs and sale metadata, successful purchase, cancellation, entitlement restoration on rejoin, owned-benefit gameplay, and Roblox pricing in the published experience. These flows have only been mocked so far, not tested with real purchases.
5. Complete the full place-file backup: no .rbxl/.rbxlx was available in Documents/Desktop/Downloads. Repository scripts do not include the map, terrain, objects, settings, or live DataStore records.

## Other pre-existing tasks
Coin persistence earn-leave-rejoin verification remains incomplete from the earlier session. API access previously failed; today's Play successfully loaded existing data, but a new earned amount was not used to prove round-trip saving. DataManager and its Studio shutdown behavior were not changed for gamepasses.
Read current Studio sources before future edits; repository snapshots are not automatic sync.

Official references:
- https://create.roblox.com/docs/production/monetization/passes
- https://create.roblox.com/docs/reference/engine/classes/MarketplaceService

