# Latest handoff — rarity-colored names + a real item index (2026-09-12)

Follow-up the same day: models still needed for the new fallback hybrids (tracked separately, not done this pass — see "Not done" below), colored item names by rarity everywhere, a comprehensive item index (not just a recipe list), and a question about whether auto-pickup was a bug.

**Auto-pickup answered, not a bug:** confirmed directly against this player's save data — `magnet` upgrade level 1 (`Scrap Magnet`, purchased in the shop), which grants a 20-stud auto-grab radius (`GamepassService.Radius`). Every ~1.5s, `PlotManager`'s magnet loop grabs the nearest scrap in range whenever a slot is free. Working as designed; nothing changed here.

**Rarity-colored names.** New shared module `ReplicatedStorage/ItemRarity.luau`: `Color(tier, isSecret)` (tier1 muted gray, tier2 green, tier3 blue, tier4 purple, any secret gold regardless of tier number), `Tag(name, tier, isSecret)` wraps a name in a `<font color="...">` RichText span. Both `FusionRecipes` and `BrainrotRecipes` gained a public `GetTier(name)` (reads the same internal `nameTier` table the fallback system already built) so any caller can look up a color without knowing whether a name is a base item, curated result, or fallback hybrid. Applied everywhere a name is shown: every `BillboardGui` label (world drops, carry/pad previews, placed zone slots — direct `TextColor3`), and every place multiple names share one label or a toast (the fusion pad's "[a] + [b]" preview, the carry bar, "NEW DISCOVERY"/"SECRET RECIPE"/"LUCKY FIND"/fusion-result toasts — RichText spans, since those need more than one color in the same string). This meant flipping `RichText = true` on every label/toast/announcement in the game; harmless for any plain string without tags. Small bonus fix that fell out of this: `renderInSlot` used to take `isSecret` as a parameter and the save-restore call site hardcoded it to `false`, silently losing a restored secret's pink treatment after a server restart — now it recomputes `isSecret`/`isFallback`/tier from the item name via `FusionRecipes`, so restore gets it right automatically.

**A real item index, not just a recipe list.** The old "RECIPE BOOK" only listed curated fusion combos, Junkyard-only, secrets excluded entirely (not even a masked row). Replaced with "ITEM INDEX" (still `[B]`): two tabs (JUNKYARD / BRAINROT, switch instantly, no server round-trip), each listing *every* real item in that line — all base materials (always shown, never masked, tagged "(raw material)") plus every curated and secret result grouped by tier, masked as "??? + ??? → ???" (or "??? SECRET RECIPE ???" for an unfound secret — you now know one exists at that tier without it being handed to you). Known rows show ingredients and result each in their own rarity color. `FusionRecipes.GetRecipeBook` (Junkyard-only, no base items, secrets invisible) is gone, replaced by `GetIndex(discovered)` (mirrored in `BrainrotRecipes`, which never had a book UI at all before this) and a small `GetSecretProgress(discovered)` for the existing "Secrets X/Y" counter. `PlotManager.pushUI` now also computes Brainrot's discovered set from `Brainrot.Snapshot(player)` and sends both indexes down every push, same pattern as the old `book` field.

**Verified in Studio Play, not just read through:** confirmed the purchased-upgrade explanation directly against save data. Confirmed rarity colors end-to-end by inspecting live instances — a real Tier 2 item and a fallback Tier 2 hybrid both came back green (`#5adc78`), a live secret came back gold (`#ffcd28`), both exact hex matches for what the code should produce. Opened the real Index panel (toggled via the actual button, not simulated), inspected all 39 Junkyard rows and 17 Brainrot rows directly — masking, tier grouping, and embedded RichText tags all matched expectations. Clicked the real BRAINROT tab through an actual simulated mouse click (not just toggling a property) and watched it switch correctly. One real bug caught here: tier 1's first color choice (`210,212,216`) was nearly identical to the index's own default "known" text color (`235,235,240`) — common items were nearly invisible as a distinct color against normal white text. Darkened to `165,168,175`, confirmed by screenshot the contrast is now obvious. No console errors or warnings anywhere in this pass.

**Not done — worth calling out explicitly:** the fallback hybrid names (Scrap Hybrid, Rusty Splice, Twisted Wreck, etc. — 11 for Junkyard, 6 for Brainrot) still render as the generic neon placeholder box, not a real mesh. Giving them real models was part of the original ask but wasn't started this pass; next session should pick this up the same way the original 48-item mesh effort worked (small async batches, expect rate limits and the occasional moderation rejection on certain phrasing).

---

# Previous handoff — no more dead-end fusions, bigger items, decorated spawn areas (2026-09-12)

Three requests at once: "every item should fuse together for something instead of nothing," items should "look a bit bigger and cooler," and the areas where things spawn should feel "more decorative." Confirmed scope with AskUserQuestion first, since two of these had real cost/design tradeoffs — generic hybrid item vs. instant coins for dead ends (picked hybrid item), and scale-up-existing vs. regenerate-all-48-meshes for the model pass (picked scale-up — regenerating would have meant redoing the entire original mesh-generation session).

**Dead-end fusions, fixed at the data layer.** Only 22 of 78 possible Junkyard ingredient pairs and 6 of 36 Brainrot pairs had a curated recipe — everything else hit `FusionRecipes.Fuse`'s `return nil` and came back as "= nothing, items returned." `FusionRecipes.Fuse`/`BrainrotRecipes.Fuse` (`ReplicatedStorage`) now fall back to a generic hybrid instead of `nil`: tier = one above the stronger ingredient (capped at 4 for Junkyard / 3 for Brainrot, so fallback can never reach secret-tier value), name picked deterministically from a small per-tier pool (same pair always gives the same hybrid — a hash of the sorted ingredient key selects the name, so it reads as a rule rather than a random reroll), value = 35% of that tier's normal `TierValue` (a real reward, but always worse than finding the actual recipe, so hunting curated combos stays the better move). A fallback result is a first-class item after that — it can itself be fed into a later fusion and resolves correctly via a unified `nameTier` table covering base items, curated results, and fallback names together. **Deliberately excluded from progression**: `info.isFallback` gates the discovery/goal bookkeeping in both `PlotManager.attemptFusion` and `BrainrotService.attemptFusion`, and Brainrot's server-wide broadcast — so the "Discoveries X/22" counter, the "Discover N builds" objective, and the "player found something!" callout all stay reserved for real curated discoveries, not diluted by a hybrid you'll hit constantly. `renderInSlot` (PlotManager) now recomputes `isSecret`/`isFallback` from the item name via `FusionRecipes.IsSecretResult`/`IsFallbackResult` instead of receiving them as parameters — a nice side effect: this also fixes a pre-existing bug where a restored secret item lost its pink color after a server restart, because the old restore call hardcoded `isSecret = false`.

**Bigger models.** `ItemVisuals.GLOBAL_SCALE = 1.4` (`ReplicatedStorage/ItemVisuals.luau`) multiplies every item's size in one place — every call site across `ScrapSpawner`, `PlotManager`, and `BrainrotService` already routes through `ItemVisuals.Create`, so this one constant reaches yard drops, carried/pad-preview items, placed fused results, and Brainrot creatures with no other changes. The one place that builds its own placeholder part instead of calling `ItemVisuals.Create` (`renderInSlot`'s "no mesh yet" branch) multiplies by the same constant explicitly, so a still-unmade item's placeholder box scales in step with everything else.

**"Cooler" via a showcase glow, not new art.** `renderInSlot` now attaches a warm-gold `PointLight` to anything secret or worth 2000+ coins (tier 3+, effectively) — verified live: a freshly-discovered secret (`Cartpocalypse`) got the brighter/wider glow, a tier-2 fallback hybrid got none, exactly as designed. The placeholder-color logic also grew a third branch: no-mesh-yet stays blue, secrets stay pink, and generic hybrids are now a distinct violet, so a hybrid reads as "intentional" rather than "we haven't made this yet."

**Decorated spawn areas.** Two self-contained passes, each keeping clear of the actual gameplay field so nothing blocks a drop or a pickup:
- `MapRevamp.Map.DressYard()` (`ServerStorage/MapRevamp.luau`, called once from `MapBootstrap.server.luau` right after `Map.Build()`) rings the shared 130-stud scrap yard — the one area `Map.Build()` deliberately left clear of landmarks, so next to the fully-dressed garages and roads it read as the plainest spot on the map — with 16 bright plot-colored bollards right at the play-square edge, 8 lamp posts with real `PointLight`s just beyond that, and 10 scattered 3-ball junk-pile clusters framing the space further out. Nothing sits inside the 65-stud half-width ScrapSpawner actually drops into.
- A matching decoration block was added directly inside `BrainrotService.luau` (self-contained, matching the rest of that module's architecture) between the creature-spawn field and the ground plate's edge: alien stalks with glowing pods, clusters of glowing "berry" bushes, and two ambient pink `PointLight`s, all in bright neon colors matching the island's existing hot-pink signage.

**A real bug caught mid-build, worth remembering:** `Map.DressYard()`'s first version checked `root:FindFirstChild(...)` and parented via the `folder()` helper, which defaults to the module's `root` upvalue. That upvalue is only ever assigned inside `Map.Build()`'s *full-rebuild* branch — and `Map.Build()` almost always takes its early-return path instead, since the map is versioned and gets built once then reused across sessions. First Play-mode test threw `attempt to index nil with 'FindFirstChild'` immediately. Fixed by having `Map.DressYard()` look up `workspace:FindFirstChild("JunkyardRefresh")` directly rather than trusting a just-prior `Map.Build()` call populated a shared upvalue — a reminder that in this file, "call Build first" does not mean "Build's locals are now populated."

**Verified in Studio Play, end to end, not just by reading the code:** confirmed `FusionRecipes.Fuse`/`BrainrotRecipes.Fuse` directly (uncurated pair → hybrid; same pair reversed → same hybrid name; curated pairs unaffected; two tier-4 items with no combo capped at tier 4 instead of overflowing toward secret value). Then a full real-gameplay pass — grabbed two uncurated items, walked to the pad, fused for real through the actual prompt (not simulated): a secret (`Cartpocalypse`, from a magnet-grabbed pair) placed correctly with its glow, then a genuinely uncurated pair (`Minivan` + `Golf Cart`) produced `Scrap Hybrid`, placed in the Garage zone, size `4.9,2.8,4.9` (exactly `3.5 × 1.4`), violet placeholder color, no glow (value 87 < 2000) — every number matched what the code should produce. Yard and island decoration confirmed both structurally (exact instance counts: 16 bollards / 30 junk-pile balls / 8 lamps in the yard, 5 stalks+pods / 18 bushes / 2 lamps on the island) and visually via screenshot (this is normal 3D geometry, not the `BillboardGui` text that `screen_capture` has trouble showing — see the previous handoff entry). Zero console errors across the whole session. **Not tested:** the live published game, and the fallback-hybrid path for Brainrot Island specifically through the real UI (verified directly via `BrainrotRecipes.Fuse`, but not clicked through the actual pad prompt the way the Junkyard side was).

---

# Previous handoff — fixed unreadable billboard labels across the whole game (2026-09-11)

Bug report from a real gameplay screenshot: every in-world label — zone signs, plot signs, item name tags — was rendering at once, all the same constant on-screen size regardless of distance, piling into a huge illegible wall of overlapping text. Request: "can we fix how i can read every single pop up in this game."

**Root cause:** none of the `BillboardGui`s in the game had `MaxDistance` set, so Roblox rendered every label in the world at full legible size no matter how far away it was — dozens of overlapping labels stack visually as soon as you can see more than a few items at once, because "distance" never shrinks or culls them the way it would a normal 3D object.

**Fix:** added `MaxDistance` to every billboard-producing helper — `ScrapSpawner.server.luau`'s `addLabel`, `PlotManager.server.luau`'s `makeLabel`, and `BrainrotService.luau`'s `label` — so a label only renders once you're actually close enough to read it, and disappears once you walk away instead of staying pinned to your screen from across the map.

**The tuning trap, worth remembering:** `BillboardGui.MaxDistance` is measured from the **Camera**, not the character. Roblox's default third-person camera trails noticeably behind the character (confirmed: ~12 studs back, ~4-5 studs up), so a `MaxDistance` picked by eyeballing "how far should this be readable from the character" will cut labels off well before the player expects, including sometimes standing right next to the thing. Every value in this pass got a deliberate headroom bump over the first-guess number once this was caught (slot labels 25→50, zone signs 40→60, pad labels 40→55, plot sign 70→90, BrainrotService pad 40→55, gates 55→70, items 30→45, ScrapSpawner drops 35→45). If another billboard gets added later, size its `MaxDistance` off actual camera-to-part distance (read `workspace.CurrentCamera.CFrame.Position`), not character-to-part distance.

**Tooling limitation discovered this session, important for whoever tests billboard changes next: `screen_capture` does not reliably show `BillboardGui` text at all.** Every property was independently verified correct via direct instance inspection — `Enabled`, `Visible`, `Text`, `TextTransparency=0`, `BackgroundTransparency=1`, `ZIndex`, `StudsOffset`, and `MaxDistance` checked against the *actual* `workspace.CurrentCamera` distance (not assumed) — across three different labels, in a freshly-restarted Play session with a normal, correctly-tracking third-person camera, at close unobstructed range (as close as ~12 studs with a 90-stud `MaxDistance`). Every one of those screenshots showed no billboard text whatsoever, including on a plot-sign label that was never touched by this fix. Console output was completely clean throughout — no rendering warnings or errors. Also separately discovered: passing `camera_position`/`look_at_position` to `screen_capture` can leave `workspace.CurrentCamera` stuck at the override position afterward instead of resuming normal follow behavior (confirmed via direct `CFrame` inspection — the camera sat ~12 studs from a character that had moved, not tracking it), which further pollutes any subsequent un-overridden screenshot in the same session. Given the user's own original bug-report screenshot was taken through a real Roblox client and clearly shows billboards rendering (that's *why* the overlap was visible at all), the most consistent explanation is that this MCP's screenshot path just doesn't composite the `BillboardGui` render layer, rather than every label in the game being silently broken. **Practical upshot: don't trust `screen_capture` to confirm or deny `BillboardGui` visibility. Verify billboard changes via direct property/distance inspection (`execute_luau`), and have the user eyeball the actual result in their own Play session before treating it as confirmed.**

**Not yet confirmed:** the actual visual correctness of this fix in real gameplay — pending the user's own Play-mode check, per the tooling limitation above.

---

# Previous handoff — travel menu: dropped the 3D preview for gradient + emoji cards (2026-09-11)

Fourth pass on the travel menu in one day, and the one that actually landed. Direct feedback on the hero-photo version: "the artwork... looks very terrible," wanted it to look "fun" instead, plus an emoji on the TRAVEL button.

**Decision: abandon the ViewportFrame 3D scene entirely.** Three rounds of camera/ground tuning (see the previous handoff entry) never got it past "acceptable" — a flat ground plate viewed at an angle inherently shows either dead black space above the horizon or, once you fix that by pulling the camera back, tiny distant-looking items. Rather than a fourth round of geometry tuning, replaced it with something structurally simpler and much harder to make look bad: each row is now a bold two-color `UIGradient` (`Junkyard` = gold→orange, `Brainrot Island` = pink→purple) with one giant emoji as an oversized, slightly-rotated badge (🚗 and 🧠), white text with a stroke for contrast, and a white pill button reading "TAP TO TRAVEL". The `TRAVEL` trigger button itself now reads "🚀  TRAVEL". No 3D content, no camera math, no `ItemModels` dependency for this feature anymore.

**Why this is the more reliable choice going forward:** a color gradient and an emoji glyph render identically regardless of camera angle, item mesh proportions, or lighting — there's no equivalent to the "dead black space" failure mode. If a third destination gets added, its card only needs a name, blurb, two gradient colors, and one emoji — no scene composition required. Worth remembering if there's ever a temptation to add a "live preview" back: it's a real design cost, not just a tuning problem.

**Verified in Studio Play:** confirmed via screenshot that both emoji render correctly at large size (Roblox's font rendering does support color emoji glyphs here — worth knowing since it was untested before this), confirmed a row click still travels to the right place and closes the modal, no console errors.

**Tooling note, worth remembering (came up twice today):** editing this file in Studio via `multi_edit` failed silently — reported success while leaving old content in place — twice in this session, both times because the `old_string` I sent didn't actually match what was live in Studio (once from a `replace_all` matching two identical blocks, once from drift left over by an earlier edit whose `old_string` had targeted a narrower range than I assumed). Both times, `script_read`/`script_grep` on the *current* Studio content — not trusting the success message or an earlier read — found the actual text and fixed it. Always re-read Studio content immediately before a precise multi-line `multi_edit`, especially several edits into the same file in one session.

---

# Previous handoff — travel menu: fullscreen + hero-photo rows (2026-09-11)

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

