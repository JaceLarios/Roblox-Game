# Latest handoff — detailed item models (2026-09-11)

The 12 Tier 1 base items (Rusted Sedan through Jet Engine) now have real AI-generated detailed meshes instead of the plain gray placeholder block. Fused results (Tier 2+) and secrets are NOT modeled yet — they still show the old neon indicator box on the pedestal until someone models them too.

**How it works:** each mesh is a single textured `MeshPart`, stored as a template in `ReplicatedStorage.ItemModels`, named exactly after its item (e.g. `ItemModels.Jet Engine`). A new module, `ReplicatedStorage.ItemVisuals`, exposes `Create(itemName, position, sizeScale)` (clones the template if one exists, else builds the old gray box) and `HasModel(itemName)`. `ScrapSpawner` (yard drops), `PlotManager.dropItemNearYard` (dead-end fusion returns) and `PlotManager.refreshPad` (carried-item slot display on the pad) all call `ItemVisuals.Create` now. `PlotManager.showOnPedestal` calls it only when `HasModel` is true, so unmodeled fusion results keep their original neon/secret-color look — nothing regresses for content that hasn't been modeled yet.

Golden Scrap is intentionally unchanged (still the glowing neon slab + light beam) since it isn't one of the 34 named items.

Verified in Studio Play: all 12 base items were observed spawning in the yard, carrying correctly into pad slots, and `ItemVisuals.HasModel`/`Create` were exercised directly in the command bar for both a modeled and an unmodeled name. No console errors. Not tested: an actual fusion completing on the pedestal with a modeled result (none exist yet), and the live published game (this was Edit/Play-mode Studio only, not published).

Next work on this: model the remaining 22 items (10 Tier 2, 6 Tier 3, 3 Tier 4, 3 secrets) the same way, then `showOnPedestal` will automatically start showing them instead of the neon box — no code changes needed for that part.

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

