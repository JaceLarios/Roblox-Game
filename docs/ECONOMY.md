# Economy check — 2026-10-09

Simulated with `tools/economy/econ_sim.py`: one efficient player who gets a third of the belt, grabs a car every 45 s, and always makes the best buy. Real players are slower; Phantoms, daily rewards, quests and offline earnings (not simulated) speed things up a little.

## What was wrong

- **Too short.** An active player hit max Rebirth (6) in about **3½ hours** (about 2 with the 2x Coins pass). After that, coins had nothing left to buy.
- **Rebirth threw your cars away**, ghost cars and Secret cars included, so Phantoms bought with bolts were lost at every Rebirth.
- **The last objective** ("Complete the index") needed all 105 ghost entries: about 14,300 bolts, roughly 1,200 races.
- **Phantoms on the same shelf all paid the same** (Wisp x1.5 at 40 or 60 bolts), so the cheapest was always the best buy.

## What changed (the user's picks)

| | Before | Now |
|---|---|---|
| Pad income (`PLACEMENT_PAYBACK_SECONDS`) | value / 180 per second | value / **360** per second (half) |
| A Rebirth takes | coins, upgrades, inventory, pads | **coins only** |
| Rebirth costs | 100k, 500k, 2M, 8M, 30M, 100M | **400k, 4M, 15M, 40M, 120M, 350M** (multipliers unchanged: x1.25 ... x4) |
| "Complete the index" | all 217 entries | every **fusion build** (the Spectral tab is its own collection, with a badge) |
| Phantom multiplier | x1.5 / x2 / x3 by shelf | **graded by price**: Wisp x1.4–1.6, Wraith x1.8–2.2, Reaper x2.6–3.0 |

Offline earnings and quest rewards are measured in pad income, so they halved too.

## Pace now (sim, median)

| Milestone | No passes | 2x Coins pass + group |
|---|---|---|
| First Rare build | 7 min | |
| First Epic | 13 min | |
| First Mythic | 21 min | |
| First Legendary | 27 min | |
| First Godly | 33 min | |
| Rebirth 1 | ~40 min | ~30 min |
| Rebirth 3 | ~1.3 h | ~0.8 h |
| Rebirth 6 (max) | **~7 h** | **~3.6 h** |

## The best earner

A car earns its value ÷ 360 coins a second on a pad, times your multipliers: Rebirth (up to x4), 2x Coins, friends and group (up to +60%), a 2x Income boost.

| | Value | Coins a second (no multipliers) |
|---|---|---|
| Best plain car: **Toro SVO** (Secret) | 400,000 | 1,111 |
| Best build: Starcrusher (Monster Truck + Warp Drive, Day 7 only) | 277,020 | 770 |
| Best build from the Shop: Fusion Colossus (Monster Truck + Fusion Core) | 264,870 | 736 |
| **Best possible: a Frenzy Toro SVO with a Ghost Chauffeur** (x25 x3) | 30,000,000 | **83,333** |
| Without a Mutation Frenzy: a Cosmic Toro SVO with a Ghost Chauffeur (x20 x3) | 24,000,000 | 66,667 |

With every multiplier maxed (Rebirth 6, 2x Coins, five friends and the group), the Frenzy Toro SVO with a Ghost Chauffeur makes about **1.07 million coins a second**, and twice that during a 2x Income boost. It is extremely rare: a Toro SVO is one car in about 1,500 off the belt, and it only comes out Frenzy-mutated during a Mutation Frenzy.

## Not changed, worth knowing

- Daily reward coins (500–7,500) and objective rewards (100–50,000) stop mattering after the first hour. They could be paid in minutes of pad income, the way quests are.
- Secret cars and ghost cars now survive Rebirth with everything else.
