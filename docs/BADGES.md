# Roblox badges — 2026-10-09

The game already awards these (`ServerStorage.Badges`). Each one needs a badge made on the Creator Hub first; until its id is filled in, it is simply skipped.

## Making them

1. On the Creator Hub, open Junkyard Fusion and go to its **Badges** page, then **Create a Badge**.
2. Give it the **name** and **description** below and upload its **picture** (512 × 512, in `assets/badges`; Roblox shows it as a circle).
3. Copy the new badge's **id** (the number in its URL) into `src/ServerStorage/Badges.luau`, on that badge's `id = 0`.
4. Sync the script to Studio and publish.

Roblox may charge Robux for badges past a free daily allowance; the Creator Hub says what it costs before you confirm.

## The badges

| Key in Badges.luau | Name | Description | Picture | Given when |
|---|---|---|---|---|
| `welcome` | Welcome to the Junkyard | Join Junkyard Fusion. | `welcome.png` | joining |
| `firstFusion` | First Fusion | Fuse a car with an addon at your Fusion Pad. | `firstFusion.png` | the first fusion |
| `firstGhost` | Ghost Rider | Put a Phantom on a car and make it a ghost. | `firstGhost.png` | the first Phantom put on a car |
| `secretCar` | Secret Find | Get one of the Secret cars. | `secretCar.png` | a Secret car in your hands, pads or inventory |
| `firstRebirth` | Born Again | Rebirth for the first time. | `firstRebirth.png` | Rebirth 1 |
| `maxRebirth` | Ceiling Breaker | Reach the highest Rebirth. | `maxRebirth.png` | Rebirth 6 |
| `raceFinish` | Outran the Monster | Finish a Race Wars race. | `raceFinish.png` | crossing the finish line |
| `collector` | Collector | Discover 25 builds in the Index. | `collector.png` | 25 fusion builds discovered |
| `masterBuilder` | Master Builder | Discover every fusion build in the Index. | `masterBuilder.png` | every fusion build (128 with the Civic) |
| `ghostCollector` | Ghost Collector | Fill the whole Spectral tab: every Phantom on every car. | `ghostCollector.png` | every Spectral entry (120 with the Civic) |

Players who already qualify (say, a tester with a Rebirth) get theirs the next time they join. Badges are only checked once per player per server, so the calls cost nothing after that.

`assets/badges/make_badges.py` rebuilds the pictures from the game's model renders (`python make_badges.py`); `badges-sheet.png` shows all ten.
