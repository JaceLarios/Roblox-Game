# Latest handoff — travel menu: fullscreen + hero-photo rows (2026-09-11)

Third pass on the travel menu in one day. The request: much bigger UI, image behind the name instead of beside it, image dimmed to blend with the text, and a better-composed preview scene.

**Modal size:** `travelFrame` is now scale-sized (`0.88 x 0.88` of the screen, not a fixed pixel box) so it stays "almost the whole screen" on any resolution. Title bumped to 40pt.

**Layout flip:** the `ViewportFrame` now fills the entire row (`Size = UDim2.new(1,0,1,0)`, `ZIndex = 1`) as a background photo, with a `Frame` + `UIGradient` overlay on top (`ZIndex = 2`, transparent at the top fading to ~95% opaque at the bottom) so the name/blurb/CTA text (`ZIndex = 3`) sits in a naturally darkened band at the bottom — the standard "hero card" pattern. Row height went from 168px to 300px to give the photo room to breathe.

**Preview composition — this took several iterations, worth reading before touching it again:** each world's preview is a hand-placed, static scene (`previewItems` now carry explicit `pos`/`rot` per item instead of an auto-spaced loop), 4-5 items per world instead of 2, framed by an angled-down camera over a large ground plate. The rotation/turntable animation from the previous version was dropped — a static "photo" reads more intentional at this size than a slowly-spinning wide arrangement (which looked odd swinging past the frame edges). Getting the framing right took 3 attempts: a moderate angle left too much dead black space above the ground; a steep near-top-down angle fixed the dead space but made everything tiny and distant; the setting that actually worked is a **large ground plate (70x60 studs) with a moderate angle** (`cameraPos = (0, 6, 15)`, `cameraLookAt = (0, -3, -2)`) — oversizing the ground was a more reliable fix than precisely solving the camera/FOV geometry. If a third world's preview looks off, adjust `groundSize` before fighting the camera angle.

**Tooling note, worth remembering:** the Roblox Studio `multi_edit` tool's `old_string`/`new_string` replacement silently did nothing (while still reporting success) when the exact same block appeared twice in the file — the Junkyard and Brainrot preview settings started out identical. Splitting into two edits, each with enough unique surrounding context (the `groundColor` line, which differs per world) to disambiguate, fixed it. Always spot-check with `script_read`/`script_grep` after a multi_edit that might have matched more than once — a reported success is not proof the content actually changed.

**Verified in Studio Play:** opened the modal, confirmed both rows render with the wider scene and gradient text overlay, and confirmed a row click still travels correctly and closes the modal (the click handler itself was untouched by this visual pass, but re-verified after all the ViewportFrame/camera changes anyway). No console errors. **Not tested:** the live published game, and how the fixed 300px row height reads on a much narrower (e.g. mobile portrait) screen — this game hasn't been checked for mobile layout at all yet.

---

# Previous handoff — travel menu redesign: picker modal with live previews (2026-09-11)

Follow-up polish on the travel menu from the same day: replaced the always-visible 2-button side panel with a single compact "TRAVEL" trigger button (right side, vertically centered) that opens a big modal ("WHERE TO?") listing destinations as stacked rows, each with a live rotating 3D preview of that world.

**How the preview works:** each row has a `ViewportFrame` (`BackgroundTransparency = 1`, so it reads as a floating preview rather than a screenshot) containing its own `Camera` and a small cloned "stage" — a tinted ground plate plus 1-2 signature items cloned live from `ReplicatedStorage.ItemModels` (Junkyard: Rusted Sedan + Cop Cruiser on white; Brainrot: Waffronio Pigeonelli + Meatballzilla Supremo on green). A `RunService.RenderStepped` connection per row slowly spins the stage for a turntable effect. This is a curated preview of each world's theme via its signature items, not a live camera feed of the actual place — much cheaper to build and keeps the modal clean at small size.

Clicking anywhere on a row (the whole row is one `TextButton`, not just a small button in the corner) fires `TravelTo` and closes the modal immediately. The row list is data-driven (a `WORLDS` table), so adding a third destination later is one more table entry, not new layout code.

**Verified in Studio Play:** clicked the real TRAVEL button and a real destination row (not simulated via script) and confirmed via screenshot that both previews render and spin correctly, and confirmed the character actually moved to the right position and the modal closed automatically afterward. No console errors. **Not tested:** the live published game, and ViewportFrame render cost with many players' menus open simultaneously (each open menu runs 2 RenderStepped connections client-side only, so this shouldn't affect other players, but wasn't load-tested).

---

# Previous handoff — travel menu + fixed spawn point (2026-09-11)

Follow-up to the Brainrot Island work: a side-screen menu to jump between destinations, and a fix for a real spawn-flow issue the new island exposed.

**Travel menu:** a small panel on the right side of the screen, vertically centered (`GameUI.client.luau`), with one button per destination — currently "Junkyard" and "Brainrot Island". Clicking fires a new `TravelTo` RemoteEvent with a destination key; the server (`PlotManager.server.luau`) decides the actual position and calls `character:PivotTo(...)` — the client never sends a position, only a key, same trust model as `BuyUpgrade`. Adding a third destination later is just one more `travelButton(...)` call plus a branch in the server handler; there's no dynamic list machinery since two destinations doesn't warrant it yet. First attempt at wiring the button up placed it at a bad screen position (overlapping the existing daily-rewards button, both anchored left-center) — moved the whole panel to the right-center instead, which is clear on every corner of the HUD.

**Spawn point fix:** players used to visibly spawn at the default Roblox `SpawnLocation` (world origin) for a brief moment before `CharacterAdded` teleported them to their assigned plot — harmless before, but now that a second destination (the island) exists, "spawn at the origin, then teleport" reads more like a bug. Fixed properly rather than papered over: `Players.CharacterAutoLoads` is now `false`, and each plot gets its own invisible per-plot `SpawnLocation` the moment a player is assigned it; `player.RespawnLocation` is set to it and `player:LoadCharacter()` is called explicitly once we actually know where they belong. The character now appears directly on their plot from frame one — confirmed by reading back `HumanoidRootPart.Position` immediately after spawn in Play mode, which landed exactly on `plot.centre`, no intermediate position observed. This also means any future death/reset respawns land in the right place automatically, for free.

**Verified in Studio Play:** spawn position confirmed exact (no origin flash), both travel buttons clicked through the real UI (not simulated via script) and confirmed the server moved the character to the exact expected position each time, no console errors. Note for whoever tests this next: `user_mouse_input`'s coordinates did NOT match the coordinates a screenshot image appeared to show (the screenshot was scaled down from the actual viewport) — read `GuiObject.AbsolutePosition`/`AbsoluteSize` directly instead of estimating from a screenshot when clicking something precisely. **Not tested:** the live published game, and whether `CharacterAutoLoads = false` has any interaction with Studio's "player already in-game before script runs" quirk beyond the existing catch-up loop (which now also triggers a `LoadCharacter()`, so it should self-correct, but wasn't separately verified).

---

# Previous handoff — Brainrot Island + cars-as-transportation (2026-09-11)

First gameplay-expansion milestone (of three options offered — the other two were "vehicles/driving first" and "small taste of both"; this one was picked): a new, mostly-independent content line plus a small, low-risk hook into the existing economy.

**Cars as transportation:** each fused vehicle sitting in your Garage zone (not sold) now gives +2 WalkSpeed, on top of the base 16 — full 4-slot Garage = 24 WalkSpeed. Selling a Garage item removes its bonus immediately. This is a **speed-boost abstraction, not real driving** — that trade-off was explicit (the alternative considered was full vehicle-seat physics). See `updateWalkSpeed` in `PlotManager.server.luau`; called after every placement/sale/join/respawn so it never drifts from the actual Garage contents.

**Brainrot Island:** a new area at `(0, 0, 900)` — far from the Foundry District ring — reachable via a teleport pad at the edge of the main map (`ToBrainrotIsland`, near `(0,1,320)`) and back (`ToMainland` on the island). It has its own spawner, its own shared (not per-player) fusion pad, and its own 8-item base + 4 Tier2 + 1 Tier3 + 1 secret recipe tree (`ReplicatedStorage.BrainrotRecipes`) — **original creatures**, not the viral "Italian brainrot" characters (Tralalero Tralala, Bombardiro Crocodilo, etc. belong to other creators; the brief was explicit about this). All 14 got real AI-generated meshes the same way the vehicle line did.

Two deliberate simplifications vs. the Junkyard system, both to keep this a contained first pass rather than doubling PlotManager's complexity:
- **Fusing pays out immediately** instead of placing into passive-income zones. If this milestone lands well, upgrading it to placement zones (mirroring Garage/Workshop/Trophy Case) is the natural next step.
- **The fusion pad is shared**, first-come-first-served, not per-player — there's only one, so contention is possible with several players fusing brainrot at once.

**Architecture note for whoever touches this next:** `BrainrotService.luau` (ModuleScript, ServerScriptService) is deliberately self-contained — its own carry slots, never touches `PlotManager`'s Junkyard slots, so the two item lines can't cross. But it does NOT call `DataManager.Load`/`Save` itself: PlotManager owns the entire save-file lifecycle (autosave, `BindToClose`, `PlayerRemoving`), and a second independent save-caller would risk one overwriting the other's fields since `DataManager.Save` is a full overwrite, not a merge. Instead `BrainrotService` exposes `Init(player, discoveredList)` / `Snapshot(player)` / `Cleanup(player)`, which `PlotManager` calls at the right lifecycle points. `DataManager`'s default save data gained `brainrotDiscovered = {}`; old saves fill it in automatically via the existing "merge with defaults" load path — no migration needed.

**Regression caught while wiring this up:** none this time, but note for later — `randomSpawnPosition()` on the island originally had no exclusion zone around the fusion pad, so creatures could spawn close enough that their "Grab" prompt competed with the pad's "Fuse" prompt for focus. Fixed with an 18-stud `PAD_EXCLUSION_RADIUS`. Worth remembering if the Junkyard yard's spawn area is ever shrunk relative to the plots.

**Verified in Studio Play:** full loop tested through real ProximityPrompt-triggered gameplay — grabbed real creatures, hit a dead-end fuse (both items correctly returned to the island), and a successful Tier 2 discovery (pad cleared, coins increased by the expected amount, confirmed the payout math). Recipe logic (all tiers + secret + dead-end) additionally verified directly via command bar. Teleporter tested in the island→mainland direction (island→main and main→island use identical code, not independently re-tested). WalkSpeed boost confirmed exact (16 + 2×filled-Garage-slots). No console errors throughout. **Not tested:** the shared-pad-contention case with multiple simultaneous players, and the live published game.

---

# Previous handoff — brighter color pass on plots and zones (2026-09-11)

Follow-up polish request: "no dull colors, only bright." The plot/zone geometry built by `PlotManager.server.luau` was industrial gray (ground, sign posts, zone slot bases all muted grays); brightened all of it. Each zone now has its own vivid signature color carried through consistently — `garage`=cyan, `workshop`=magenta, `trophy`=gold — used for its sign post (Neon), its slot bases (a lighter tint via `Color3:Lerp`), and its "empty" label text, so the color-coding doubles as a reminder of which tier goes where. Plot ground went from dark gray to a bright near-white; the fusion pad and plot sign post are now Neon orange/yellow instead of muted metal tones. `ItemVisuals`'s fallback color (used only if a future item has no mesh) went from gray to bright cyan neon too.

Also brightened `MapRevamp.luau`'s `plotColors` palette (the 8 per-plot accent colors used for each plot's `FusionPad`, ground tint, and zone sign trim, and reused by the shared "BAY" canopy dressing) from muted/pastel tones to fully saturated ones. Fixed `DressPlot`'s ground recolor, which was unconditionally repainting the ground a dull blue-gray right after PlotManager built it bright — it now tints the ground a light version of the plot's own accent color instead, so the brightening actually sticks.

Did NOT touch the base `C` palette used throughout the rest of the Foundry District map generator (buildings, trees, etc.) — that's a much larger, unreviewed surface and a full rebuild; this pass was scoped to the plot/zone elements the color complaint was actually about. Verified in Studio Play: no console errors, all three zones render in their bright colors with visible per-plot ground/pad/canopy tinting, existing placed item (Lifted Cart) still renders correctly in its now-bright garage slot.

---

# Previous handoff — placement economy: passive income + tiered zones (2026-09-11)

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

