# Latest handoff — map refresh (2026-09-11)

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

