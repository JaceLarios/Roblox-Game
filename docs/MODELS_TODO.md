# Model production — updated 2026-10-01

All 83 model entries in this checklist are now installed in Studio, including the 52 remaining fusion variants. The SVO is 89,769 triangles with four rolling wheel groups; its 12-stud length, decals, materials and LogoCover are retained. Golf-cart source exports and recovery files preserve Claude's approved 1.2x fit.

The checks below track implementation, not final player art approval. Full multiplayer/mobile performance testing and live publication remain separate. See assets/remaining-fusions for source, front/rear previews, recovery files and test evidence.

## How a finished build is set up

Follow the Scrap Kart and Dirt Bike builds (e.g. `ItemModels.Loud Lemon`):

- A `Model` in `ReplicatedStorage.ItemModels`, named exactly as below.
- Attributes: `FusionBase` (the car), `FusionAddon` (the addon),
  `DisplayName`, `NoseAxis = +Z` (front of the car along +Z).
- Wheels as separate parts tagged `WheelPivot` / `WheelRadius`, so they
  roll on the conveyor and in races.
- **Hover Fans builds have no wheels**: a `FusionBase` model with no
  `WheelPivot` parts hovers automatically (like Hover Heap and Hoverbike).
- Roughly the size of that car's base model (about 5 studs long; the Golf
  Cart and Cop Cruiser about 6, the Box Truck about 7.5) and under about 90k
  triangles. Compare it next to the base car before installing: the first 15
  Golf Cart builds came in 20% small and were scaled up 1.2x in Studio
  (see HANDOFF.md). (The Secret cars are
  deliberately bigger: both are about 12 studs long, the user's call.)
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
- [x] **Warp Drive** (Legendary, Day 7 exclusive; currently shows the Fusion Core)

### Scrap Kart (Rusted Sedan): 1
- [x] NEW Warp Wreck (Warp Drive)

### Dirt Bike: 1
- [x] NEW Wormhole Wheelie (Warp Drive)

### Golf Cart: 16
- [x] REBUILD Cart Rocket (Nitrous Tank)
- [x] NEW Putter Popper (Straight Pipes)
- [x] NEW Turbo Tee (Scrap Turbo)
- [x] REBUILD Lifted Cart (Inline 4)
- [x] NEW Rotary Roller (Rotary Engine)
- [x] NEW Double Bogey (Twin Turbo)
- [x] REBUILD Fairway Fighter (V6 Engine)
- [x] NEW Sand Trap Supreme (Supercharger)
- [x] NEW Diesel Driver (Diesel Stack)
- [x] REBUILD Cartpocalypse (V8 Engine)
- [x] NEW Hole in Twelve (V12 Engine)
- [x] NEW Hover Caddy (Hover Fans, hovers)
- [x] REBUILD THE LAWNLORD (Jet Engine)
- [x] NEW Eagle Launcher (Rocket Booster)
- [x] NEW Atomic Albatross (Fusion Core)
- [x] NEW Hole in Space (Warp Drive)

### Muscle Car: 16
- [x] REBUILD Junk Mashup (Nitrous Tank)
- [x] NEW Rumble Pony (Straight Pipes)
- [x] NEW Boost Stallion (Scrap Turbo)
- [x] REBUILD Undercover Muscle (Inline 4)
- [x] NEW Rotor Rebel (Rotary Engine)
- [x] NEW Twin Turbo Thunder (Twin Turbo)
- [x] REBUILD Twisted Wreck (V6 Engine)
- [x] NEW Blown Charger (Supercharger)
- [x] NEW Coal Roller (Diesel Stack)
- [x] REBUILD Chrome Sentinel (V8 Engine)
- [x] NEW Grand Growler (V12 Engine)
- [x] NEW Street Levitator (Hover Fans, hovers)
- [x] REBUILD Afterburner GT (Jet Engine; has a body, but no rolling wheels)
- [x] NEW Rocket Stallion (Rocket Booster)
- [x] NEW Fusion Fury (Fusion Core)
- [x] NEW Lightspeed Legend (Warp Drive)

### Cop Cruiser: 16
- [x] REBUILD Cone Cruiser (Nitrous Tank)
- [x] NEW Siren Screamer (Straight Pipes)
- [x] NEW Patrol Spooler (Scrap Turbo)
- [x] REBUILD Undercover Van (Inline 4)
- [x] NEW Rotary Ranger (Rotary Engine)
- [x] NEW Twin Chase (Twin Turbo)
- [x] REBUILD Turbo Interceptor (V6 Engine)
- [x] NEW Supercharged Sheriff (Supercharger)
- [x] NEW Riot Rig (Diesel Stack)
- [x] REBUILD Highway Overlord (V8 Engine)
- [x] NEW Pursuit Prime (V12 Engine)
- [x] NEW Hover Patrol (Hover Fans, hovers)
- [x] REBUILD Sky Marshal (Jet Engine; has a body, but no rolling wheels)
- [x] NEW Orbital Enforcer (Rocket Booster)
- [x] NEW Plasma Patrol (Fusion Core)
- [x] NEW Warp Warden (Warp Drive)

### Box Truck: 16
- [x] REBUILD Scrap Hybrid (Nitrous Tank)
- [x] NEW Rattle Hauler (Straight Pipes)
- [x] NEW Turbo Mover (Scrap Turbo)
- [x] REBUILD Hauler Hemi (Inline 4)
- [x] NEW Rotary Rig (Rotary Engine)
- [x] NEW Twin Turbo Freight (Twin Turbo)
- [x] REBUILD Construction Cartel (V6 Engine)
- [x] NEW Blown Big Rig (Supercharger)
- [x] NEW Diesel Dynamo (Diesel Stack)
- [x] REBUILD Yard Destroyer (V8 Engine)
- [x] NEW Titan Twelve (V12 Engine)
- [x] NEW Cargo Hoverer (Hover Fans, hovers)
- [x] REBUILD Jet Hauler (Jet Engine)
- [x] NEW Rocket Freight (Rocket Booster)
- [x] NEW Core Carrier (Fusion Core)
- [x] NEW Star Freighter (Warp Drive)

### Monster Truck: 16
- [x] REBUILD Soccer Mom Monster (Nitrous Tank)
- [x] NEW Stomp Pipes (Straight Pipes)
- [x] NEW Crusher Turbo (Scrap Turbo)
- [x] REBUILD Junkyard Brute (Inline 4)
- [x] NEW Rotary Wrecker (Rotary Engine)
- [x] NEW Twin Turbo Titan (Twin Turbo)
- [x] REBUILD Suburban Assault (V6 Engine)
- [x] NEW Supercharged Smasher (Supercharger)
- [x] NEW Black Smoke Beast (Diesel Stack)
- [x] REBUILD Mangled Overlord (V8 Engine)
- [x] NEW V12 Leviathan (V12 Engine)
- [x] NEW Hover Hulk (Hover Fans, hovers)
- [x] REBUILD Scrapyard God (Jet Engine)
- [x] NEW Rocket Juggernaut (Rocket Booster)
- [x] NEW Fusion Colossus (Fusion Core)
- [x] NEW Starcrusher (Warp Drive)

### Toro SVO fixes
Both Secret cars stay about 12 studs long on purpose (the Toro was scaled up
to match the SVO). The SVO's side decals were enlarged on 2026-09-30.
- [x] A lighter export (reduced from about 217k to 89,769 triangles)
- [x] Split the merged rear wheels and tag all wheels `WheelPivot` / `WheelRadius` so they roll
- [x] Test both big Secret cars on the conveyor and in a race (size, wheel motion and short keyboard driving verified; sustained multiplayer/mobile performance remains untested)
- [x] Keep the `LogoCover` part (hides the rear "Lamborghini" lettering) and the model name `SVO`
