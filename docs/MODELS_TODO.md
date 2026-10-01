# Models still to make (checked in Studio 2026-09-30)

Every base car, every addon except the Warp Drive, and both Secret cars
have their own model. What is left:

| | Count |
|---|---|
| Addon with no model | 1 (Warp Drive) |
| Builds with no model | 57 |
| Builds with an old pre-Blender model (single mesh, wheels don't roll) | 25 |
| Fixes to an existing model | 1 (Toro SVO) |

A build with no model shows a stand-in in game: the same car's build with
the first addon of that rarity (Rumble Pony shows Loud Lemon). The Scrap
Kart (Rusted Sedan) and Dirt Bike families are finished apart from their
Warp Drive builds; the other five cars still need most of theirs.

## How a finished build is set up

Follow the Scrap Kart and Dirt Bike builds (e.g. `ItemModels.Loud Lemon`):

- A `Model` in `ReplicatedStorage.ItemModels`, named exactly as below.
- Attributes: `FusionBase` (the car), `FusionAddon` (the addon),
  `DisplayName`, `NoseAxis = +Z` (front of the car along +Z).
- Wheels as separate parts tagged `WheelPivot` / `WheelRadius`, so they
  roll on the conveyor and in races.
- **Hover Fans builds have no wheels**: a `FusionBase` model with no
  `WheelPivot` parts hovers automatically (like Hover Heap and Hoverbike).
- Roughly the size of that car's base model (about 5 studs long; the Box
  Truck about 7.5) and under about 90k triangles.
- No real car brands, badges or logos.

## Priority order

1. **Warp Drive addon + its 7 builds.** Players get these from the Day 7
   streak now and see stand-ins.
2. **Legendary** (Rocket Booster, Fusion Core builds; rebuild the Jet
   Engine ones).
3. **Mythic** (V12 Engine, Hover Fans; rebuild V8).
4. **Epic** (Supercharger, Diesel Stack; rebuild V6).
5. **Rare** (Rotary Engine, Twin Turbo; rebuild Inline 4).
6. **Uncommon** (Straight Pipes, Scrap Turbo; rebuild Nitrous Tank).
7. **Toro SVO fixes.**

## The list, car by car

"NEW" = no model yet. "REBUILD" = has an old single-mesh model.

### Addon
- [ ] **Warp Drive** (Legendary, Day 7 exclusive; currently shows the Fusion Core)

### Scrap Kart (Rusted Sedan): 1
- [ ] NEW Warp Wreck (Warp Drive)

### Dirt Bike: 1
- [ ] NEW Wormhole Wheelie (Warp Drive)

### Golf Cart: 16
- [ ] REBUILD Cart Rocket (Nitrous Tank)
- [ ] NEW Putter Popper (Straight Pipes)
- [ ] NEW Turbo Tee (Scrap Turbo)
- [ ] REBUILD Lifted Cart (Inline 4)
- [ ] NEW Rotary Roller (Rotary Engine)
- [ ] NEW Double Bogey (Twin Turbo)
- [ ] REBUILD Fairway Fighter (V6 Engine)
- [ ] NEW Sand Trap Supreme (Supercharger)
- [ ] NEW Diesel Driver (Diesel Stack)
- [ ] REBUILD Cartpocalypse (V8 Engine)
- [ ] NEW Hole in Twelve (V12 Engine)
- [ ] NEW Hover Caddy (Hover Fans, hovers)
- [ ] REBUILD THE LAWNLORD (Jet Engine)
- [ ] NEW Eagle Launcher (Rocket Booster)
- [ ] NEW Atomic Albatross (Fusion Core)
- [ ] NEW Hole in Space (Warp Drive)

### Muscle Car: 16
- [ ] REBUILD Junk Mashup (Nitrous Tank)
- [ ] NEW Rumble Pony (Straight Pipes)
- [ ] NEW Boost Stallion (Scrap Turbo)
- [ ] REBUILD Undercover Muscle (Inline 4)
- [ ] NEW Rotor Rebel (Rotary Engine)
- [ ] NEW Twin Turbo Thunder (Twin Turbo)
- [ ] REBUILD Twisted Wreck (V6 Engine)
- [ ] NEW Blown Charger (Supercharger)
- [ ] NEW Coal Roller (Diesel Stack)
- [ ] REBUILD Chrome Sentinel (V8 Engine)
- [ ] NEW Grand Growler (V12 Engine)
- [ ] NEW Street Levitator (Hover Fans, hovers)
- [ ] REBUILD Afterburner GT (Jet Engine; has a body, but no rolling wheels)
- [ ] NEW Rocket Stallion (Rocket Booster)
- [ ] NEW Fusion Fury (Fusion Core)
- [ ] NEW Lightspeed Legend (Warp Drive)

### Cop Cruiser: 16
- [ ] REBUILD Cone Cruiser (Nitrous Tank)
- [ ] NEW Siren Screamer (Straight Pipes)
- [ ] NEW Patrol Spooler (Scrap Turbo)
- [ ] REBUILD Undercover Van (Inline 4)
- [ ] NEW Rotary Ranger (Rotary Engine)
- [ ] NEW Twin Chase (Twin Turbo)
- [ ] REBUILD Turbo Interceptor (V6 Engine)
- [ ] NEW Supercharged Sheriff (Supercharger)
- [ ] NEW Riot Rig (Diesel Stack)
- [ ] REBUILD Highway Overlord (V8 Engine)
- [ ] NEW Pursuit Prime (V12 Engine)
- [ ] NEW Hover Patrol (Hover Fans, hovers)
- [ ] REBUILD Sky Marshal (Jet Engine; has a body, but no rolling wheels)
- [ ] NEW Orbital Enforcer (Rocket Booster)
- [ ] NEW Plasma Patrol (Fusion Core)
- [ ] NEW Warp Warden (Warp Drive)

### Box Truck: 16
- [ ] REBUILD Scrap Hybrid (Nitrous Tank)
- [ ] NEW Rattle Hauler (Straight Pipes)
- [ ] NEW Turbo Mover (Scrap Turbo)
- [ ] REBUILD Hauler Hemi (Inline 4)
- [ ] NEW Rotary Rig (Rotary Engine)
- [ ] NEW Twin Turbo Freight (Twin Turbo)
- [ ] REBUILD Construction Cartel (V6 Engine)
- [ ] NEW Blown Big Rig (Supercharger)
- [ ] NEW Diesel Dynamo (Diesel Stack)
- [ ] REBUILD Yard Destroyer (V8 Engine)
- [ ] NEW Titan Twelve (V12 Engine)
- [ ] NEW Cargo Hoverer (Hover Fans, hovers)
- [ ] REBUILD Jet Hauler (Jet Engine)
- [ ] NEW Rocket Freight (Rocket Booster)
- [ ] NEW Core Carrier (Fusion Core)
- [ ] NEW Star Freighter (Warp Drive)

### Monster Truck: 16
- [ ] REBUILD Soccer Mom Monster (Nitrous Tank)
- [ ] NEW Stomp Pipes (Straight Pipes)
- [ ] NEW Crusher Turbo (Scrap Turbo)
- [ ] REBUILD Junkyard Brute (Inline 4)
- [ ] NEW Rotary Wrecker (Rotary Engine)
- [ ] NEW Twin Turbo Titan (Twin Turbo)
- [ ] REBUILD Suburban Assault (V6 Engine)
- [ ] NEW Supercharged Smasher (Supercharger)
- [ ] NEW Black Smoke Beast (Diesel Stack)
- [ ] REBUILD Mangled Overlord (V8 Engine)
- [ ] NEW V12 Leviathan (V12 Engine)
- [ ] NEW Hover Hulk (Hover Fans, hovers)
- [ ] REBUILD Scrapyard God (Jet Engine)
- [ ] NEW Rocket Juggernaut (Rocket Booster)
- [ ] NEW Fusion Colossus (Fusion Core)
- [ ] NEW Starcrusher (Warp Drive)

### Toro SVO fixes
- [ ] Scale `ItemModels.SVO` to about 5.5 studs long (it is 12.1; the Toro is 5.4)
- [ ] A lighter export (it is about 217k triangles)
- [ ] Split the merged rear wheels and tag all wheels `WheelPivot` / `WheelRadius` so they roll
- [ ] Keep the `LogoCover` part (hides the rear "Lamborghini" lettering) and the model name `SVO`
