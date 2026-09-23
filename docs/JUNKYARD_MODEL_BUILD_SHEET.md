# Junkyard Model Build Sheet

2026-09-22, updated 2026-09-23 · for Codex

## What this is

Every junkyard fusion is one car plus one addon, so the recipe book is exactly 7 cars × 5 addons = 35 results. The addon sets the rarity, the car sets which result you get. That is live in the game now.

Of the 35, **all 35 now have a model in the current Studio Edit place**. The three previously missing Legendary results were installed in this pass; see `assets/legendary-jets/README.md` for recovery files and verification limits. Some older models were built for a different recipe and now have to stand for one specific car, and a few are sized out of step with their rarity. Those remaining lists are below.

The game loads a model straight out of `ReplicatedStorage.ItemModels` by the result's exact name, so a model shows up in game the moment it is in there under the right name. No code change needed for any of this.

This page covers the 35 fused results and the five addons. The seven base cars were rebuilt as detailed models on Sept 23, so nothing here asks for work on those.

### What the detailed cars changed

The seven rebuilt cars are multi-part models — 11 parts for the Dirt Bike, 159 for the Scrap Kart, 35 to 52 for the rest. **The three newly built Legendary jet results are now detailed multi-part models; the other 32 fused results still use their previous meshes**, as do the five addons.

So the ladder still runs backwards in places. The scrap a player picks up off the floor, worth 5 coins, is a detailed model, and so are the three new Jet results — but **Scrapyard God, the best item in the game at 1,667 coins/sec, is still a single mesh**, and next to Sky Marshal or Afterburner GT it now reads as the cheaper item. Same for Sonic Scrapheap, THE LAWNLORD and Jet Hauler. That gap is bigger than any single model on the lists below.

It also means **"Fine" in the table further down only means the model reads as the right vehicle.** None of them match the new cars for detail. If the fused results get a detail pass to match, the tables are already ordered for it: highest earners first, since those are the builds players keep on their pads and look at.

## What a build earns

Money comes from **placing** a build on one of your five base pads, not from selling it. A placed build earns its value ÷ 90 in coins every second, for as long as it stays on the pad, multiplied by your upgrades, rebirth, companion and pet bonuses.

Selling is the opposite: one payment, and the build is gone. A placed build earns its whole sell price back every 90 seconds, so selling is only worth it for something you have no pad space for.

Pets are not part of this at all any more. Since Sept 22 they are not items — owning one is a permanent coin and speed bonus, and they can't be placed or sold.

**Every rate on this page is the base rate**, before any of your multipliers. A rarer car earns more than a common one with the same addon, and a better addon outearns every result of the addon below it.

## Completed: three missing Legendary models

All three Legendary Jet Engine results below are now installed under their exact recipe names, with 7-stud longest sides. Their live ItemVisuals rendering and recipe lookup checks passed. The latest pass replaces the initial bolt-on builds with complete custom vehicle bodies; current backups and preview are in `assets/legendary-redesign/`, while `assets/legendary-jets/` preserves the earlier versions. This does not mean the place has been published; see the backup README for tests still outstanding.

| Model | Made from | Earns | Brief |
| --- | --- | --- | --- |
| Rocket Rider | Dirt Bike + Jet Engine | 611 coins/sec | A dirt bike with a jet turbine strapped on |
| Afterburner GT | Muscle Car + Jet Engine | 806 coins/sec | A muscle car with jet afterburners |
| Sky Marshal | Cop Cruiser + Jet Engine | 944 coins/sec | A jet-powered police cruiser |

**Checked in Studio on Sept 23:** all three are installed under their recipe names at exactly 7.0 studs on the longest side, 129 to 130 parts each, and each one builds, scales and grounds correctly through `ItemVisuals.Create`. Nothing else was needed to make them show up in game.

**What this leaves:** four of the seven Legendary results are still single meshes — Sonic Scrapheap, THE LAWNLORD, Scrapyard God and Jet Hauler. They are now the plainest-looking items in their own rarity, and Scrapyard God is the single best item in the game. Bringing those four up to the standard of the three new ones is the highest-value art job left.

## Rebuild: models that now stand for one car

These already have a model, but it was made for a different recipe. Under the new rule each one means exactly one car with one addon bolted on, so the goal for every model is: **you can tell which car it came from at a glance**, and the higher the rarity the more impressive it looks.

### Built for a different vehicle

The first five are left over from the roster that was replaced on Sept 14 and never got a `CodexModelRevision`; the last two are current models that read as the wrong vehicle.

| Model | Must read as | Earns | Today |
| --- | --- | --- | --- |
| Highway Overlord | Cop Cruiser + V8 Engine | 189 coins/sec | A truck, standing in for a police build (see the open question) |
| Construction Cartel | Box Truck + V6 Engine | 49 coins/sec | Old roster model, 5.3 studs |
| Trail Blazer | Dirt Bike + V6 Engine | 24 coins/sec | A buggy, should read as a dirt bike |
| Undercover Van | Cop Cruiser + Inline 4 | 9 coins/sec | Old roster, 4.4 studs — a van standing in for a cop cruiser |
| Soccer Mom Monster | Monster Truck + Nitrous Tank | 5 coins/sec | Old roster, 6.0 studs |
| Cone Cruiser | Cop Cruiser + Nitrous Tank | 2.8 coins/sec | Old roster, 4.9 studs |
| Cart Rocket | Golf Cart + Nitrous Tank | 2.2 coins/sec | Old roster, 4.5 studs |

### Generic hybrids that now mean one car

These were named as catch-all "hybrids" back when any leftover pair produced one. Each now has exactly one recipe, so each should read as that car.

| Model | Must read as | Earns |
| --- | --- | --- |
| Mangled Overlord | Monster Truck + V8 Engine | 333 coins/sec |
| Chaos Hybrid | Dirt Bike + V8 Engine | 122 coins/sec |
| Twisted Wreck | Muscle Car + V6 Engine | 32 coins/sec |
| Junkyard Brute | Monster Truck + Inline 4 | 17 coins/sec |
| Scrap Hybrid | Box Truck + Nitrous Tank | 3.7 coins/sec |
| Junk Mashup | Muscle Car + Nitrous Tank | 2.4 coins/sec |
| Bent Fusion | Dirt Bike + Nitrous Tank | 1.8 coins/sec |
| Rusty Splice | Rusted Sedan + Nitrous Tank | 1.7 coins/sec |

If you want an order to work in, the rows in both tables are sorted by what they earn, so the top ones are the builds players chase hardest.

## Rescale: sizes out of step with rarity

Sizes below are the longest side of the template in `ItemModels`. `ItemVisuals.GLOBAL_SCALE` multiplies everything by 1.4 in game, so these are relative numbers, not what a player sees.

| Model | What it is | Today | Target | Why |
| --- | --- | --- | --- | --- |
| Nitrous Tank | The new addon | 1.6 × 2.6 × 0.9 | 2.5 – 3 | About a quarter the bulk of the Inline 4 (2.5 × 2.2 × 2.9), and thin with it. On the yard floor it reads as debris rather than a find |
| Jet Hauler | Legendary, 1,222 coins/sec | 4.0 | ~7 | Every other Legendary is exactly 7.0 |
| Mangled Overlord | Mythic, 333 coins/sec | 3.8 | ~6.5 | The smallest Mythic, and smaller than most Rares |
| Redline Reaper | Mythic, 111 coins/sec | 4.4 | ~6 | Smaller than the Rare Boosted Beater at 5.5 |

A ladder that would make rarity readable across the whole set, longest side:

| Rarity | Addon | Target |
| --- | --- | --- |
| Uncommon | Nitrous Tank | ~4 |
| Rare | Inline 4 | ~5 |
| Epic | V6 Engine | ~6 |
| Mythic | V8 Engine | ~6.5 |
| Legendary | Jet Engine | ~7 |

Right now the ladder is not monotonic — Soccer Mom Monster is an Uncommon at 6.0, bigger than several Epics and Mythics — so size currently tells a player very little.

## All 35 results

Every row is one car plus one addon. **Rebuild** means the model is there but reads as the wrong vehicle, **Rescale** means it reads right but is the wrong size, **Detail** means it reads right and is the right size but is still a single mesh in a rarity where others are detailed, and **Fine** means leave it alone. Nothing is missing any more. That comes to 14 fine, 15 to rebuild, 4 to detail and 2 to rescale.

### Nitrous Tank — Uncommon

Every one of these is either an old-roster model or a generic hybrid name, so the whole row needs art.

| Result | Car | Earns | Model |
| --- | --- | --- | --- |
| Rusty Splice | Rusted Sedan | 1.7 /sec | Rebuild |
| Bent Fusion | Dirt Bike | 1.8 /sec | Rebuild |
| Cart Rocket | Golf Cart | 2.2 /sec | Rebuild |
| Junk Mashup | Muscle Car | 2.4 /sec | Rebuild |
| Cone Cruiser | Cop Cruiser | 2.8 /sec | Rebuild |
| Scrap Hybrid | Box Truck | 3.7 /sec | Rebuild |
| Soccer Mom Monster | Monster Truck | 5.0 /sec | Rebuild |

### Inline 4 — Rare

| Result | Car | Earns | Model |
| --- | --- | --- | --- |
| Boosted Beater | Rusted Sedan | 5.6 /sec | Fine |
| Pursuit Bike | Dirt Bike | 6.1 /sec | Fine |
| Lifted Cart | Golf Cart | 7.2 /sec | Fine |
| Undercover Muscle | Muscle Car | 8.1 /sec | Fine |
| Undercover Van | Cop Cruiser | 9.4 /sec | Rebuild |
| Hauler Hemi | Box Truck | 12 /sec | Fine |
| Junkyard Brute | Monster Truck | 17 /sec | Rebuild |

### V6 Engine — Epic

| Result | Car | Earns | Model |
| --- | --- | --- | --- |
| Street Menace | Rusted Sedan | 22 /sec | Fine |
| Trail Blazer | Dirt Bike | 24 /sec | Rebuild |
| Fairway Fighter | Golf Cart | 29 /sec | Fine |
| Twisted Wreck | Muscle Car | 32 /sec | Rebuild |
| Turbo Interceptor | Cop Cruiser | 38 /sec | Fine |
| Construction Cartel | Box Truck | 49 /sec | Rebuild |
| Suburban Assault | Monster Truck | 67 /sec | Fine |

### V8 Engine — Mythic

| Result | Car | Earns | Model |
| --- | --- | --- | --- |
| Redline Reaper | Rusted Sedan | 111 /sec | Rescale |
| Chaos Hybrid | Dirt Bike | 122 /sec | Rebuild |
| Cartpocalypse | Golf Cart | 144 /sec | Fine |
| Chrome Sentinel | Muscle Car | 161 /sec | Fine |
| Highway Overlord | Cop Cruiser | 189 /sec | Rebuild |
| Yard Destroyer | Box Truck | 244 /sec | Fine |
| Mangled Overlord | Monster Truck | 333 /sec | Rebuild and rescale |

### Jet Engine — Legendary

| Result | Car | Earns | Model |
| --- | --- | --- | --- |
| Sonic Scrapheap | Rusted Sedan | 556 /sec | Detail |
| Rocket Rider | Dirt Bike | 611 /sec | Done — detailed, Sept 23 |
| THE LAWNLORD | Golf Cart | 722 /sec | Detail |
| Afterburner GT | Muscle Car | 806 /sec | Done — detailed, Sept 23 |
| Sky Marshal | Cop Cruiser | 944 /sec | Done — detailed, Sept 23 |
| Jet Hauler | Box Truck | 1,222 /sec | Rescale, then detail |
| Scrapyard God | Monster Truck | 1,667 /sec | Detail — the best item in the game |

A build can also be upgraded: put a better addon on one and it becomes that addon's version of the same car, so a player moves along a row rather than starting over. Nothing extra to model for that — it lands on a result already in this table.

## Conventions

Templates live in `ReplicatedStorage.ItemModels`, named by the item's stable key, with the `CodexModelRevision` attribute set. Since the detailed-car pass a template can be an authored **Model** with welded parts, not only a single MeshPart: `ItemVisuals.Create` handles both and hands the rest of the game a BasePart to carry, and the Index and the fusion celebration already render Model templates. `ItemVisuals.GLOBAL_SCALE` (1.4) still applies on top of the template size, and anything that recolours or fades an item goes through `ItemVisuals.Tint` and `ItemVisuals.SetTransparency` rather than setting `.Color` or `.Transparency` directly.

**Name templates by key, not by display name.** `Rusted Sedan` is the key; players see "Scrap Kart" through `ItemNames.Display`. The game looks a template up by key, so one named "Scrap Kart" would never be found. Every name on this page is a key.

**The five addons are not part of the base-car rebuild, so they are still open here.** They get looked at on their own rather than only bolted onto a car — they lie on the yard floor before anyone grabs them, and they have their own tab in the Index. Only the Jet Engine has a current revision; Nitrous Tank, Inline 4, V6 and V8 are all old-roster models.

11 models in `ItemModels` are unused by this plan — leave them where they are. Wreck Kraken, Junkyard Behemoth, Scrap Titan, Cone Sentinel, Trolley Interceptor and Lawn Missile could become secrets later; Monster Truck Tire, Traffic Cone, Shopping Cart, Riding Mower and Minivan are old spawn items with no role now.

## Still open from the fusion spec

Three items from the redesign spec have not been picked up yet:

1. **Index filters are still tier bands.** They read Base / Tier 2 / Tier 3 / Tier 4 / Secret and filter on `entry.tier`. They were meant to become Base / Uncommon / Rare / Epic / Mythic / Legendary, filtering on `entry.rarity`, which every Index entry now carries.
2. **The Secret filter is dead.** There are no secret recipes in the new book, so clicking it gives "Secret • 0 / 0 discovered — No items in this rarity yet." It disappears on its own once the filters move to rarity bands.
3. **The fusion pad's two slots are not labelled.** The pad takes one item and one addon, so labelling them (ITEM / ADDON) would stop people trying two cars. The server already sends the refusal toasts.

Two more things found while testing on Sept 23:

- **`assets/junkyard-models/verify-models.luau` is broken, not just stale.** It asserts every roster entry is a MeshPart with revision `Junkyard_20260914`, which the seven detailed cars and the three new Legendary models now fail, and it fuses every pair of its roster, which the one-item-plus-one-addon rule refuses. It needs the 7 cars, 5 addons and 35 results, fusing only car + addon pairs.
- **Text overlap in the Index:** "Select a discovered item to equip your companion" renders underneath the Search box.

## One open question

**Highway Overlord** is a truck, and it now stands for Cop Cruiser + V8 Engine — the second-best police build in the game at 189 coins/sec. Keep reusing the truck, or build a proper police model for it? Jace's call.
