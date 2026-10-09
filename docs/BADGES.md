# Roblox badges — 2026-10-09

The game already awards these (`ServerStorage.Badges`). Each one needs a badge made on the Creator Hub first; until its id is filled in, it is simply skipped.

## Making them

1. On the Creator Hub, open Junkyard Fusion and go to its **Badges** page, then **Create a Badge**.
2. Give it the **name** and **description** below and upload its **picture** (512 × 512, in `assets/badges`; Roblox shows it as a circle).
3. Copy the new badge's **id** (the number in its URL) into `src/ServerStorage/Badges.luau`, on that badge's `id = 0`.
4. Sync the script to Studio and publish.

Roblox may charge Robux for badges past a free daily allowance; the Creator Hub says what it costs before you confirm.

## The badges

| Key in Badges.luau | Name | Description | Picture (`assets/badges/<key>.png`): what it shows | Given when |
|---|---|---|---|---|
| `welcome` | Welcome to the Junkyard | Join Junkyard Fusion. | WELCOME: your first car rolling out of the yard's black box onto the belt | joining |
| `firstFusion` | First Fusion | Fuse a car with an addon at your Fusion Pad. | FUSED!: a car and a Twin Turbo on the orange Fusion Pad, lightning arcing into a fusion core | the first fusion |
| `firstGhost` | Ghost Rider | Put a Phantom on a car and make it a ghost. | GHOST RIDER: the Ghost Chauffeur on a Muscle Car that is turning ghost, front to back | the first Phantom put on a car |
| `secretCar` | Secret Find | Get one of the Secret cars. | SECRET: a shadowed car coming out of the black box in a blaze of gold, under a "?" | a Secret car in your hands, pads or inventory |
| `firstRebirth` | Born Again | Rebirth for the first time. | REBIRTH: a car on a glowing pad inside the Rebirth arrows, coins flying off | Rebirth 1 |
| `maxRebirth` | Ceiling Breaker | Reach the highest Rebirth. | MAX x4: a solid-gold Starcrusher wearing a crown, the ceiling breaking apart above it | Rebirth 6 |
| `raceFinish` | Outran the Monster | Finish a Race Wars race. | FINISHED!: a car crossing the chequered line with the Race Wars scrap beast right behind | crossing the finish line |
| `collector` | Collector | Discover 25 builds in the Index. | 25 BUILDS: a hand of Index cards in their rarity colours | 25 fusion builds discovered |
| `masterBuilder` | Master Builder | Discover every fusion build in the Index. | MASTER: the whole Index wall framed in gold, and a trophy | every fusion build (128 with the Civic) |
| `ghostCollector` | Ghost Collector | Fill the whole Spectral tab: every Phantom on every car. | SPECTRAL: a moonlit parade of ghost cars, each with a different Phantom | every Spectral entry (120 with the Civic) |

Players who already qualify (say, a tester with a Rebirth) get theirs the next time they join. Badges are only checked once per player per server, so the calls cost nothing after that.

## Remaking the pictures

Each picture is a scene of what you do to earn the badge, built from the game's own models (the JSON exports in `assets/`) plus props made for it (the black box and belt, the Fusion Pad, the Race Wars beast, Index cards), then set in a bolted ring with a banner in FredokaOne, the game's UI font.

1. `E:/blender.exe --background --factory-startup --python assets/badges/build_badges.py` renders `assets/badges/scenes/<key>.png` (add `-- welcome raceFinish` to redo only some).
2. `python assets/badges/make_badges.py` frames them into `<key>.png` and `badges-sheet.png` (all ten).

Roblox crops badges to a circle and the banner covers the bottom quarter, so keep each scene's subject in the upper middle.
