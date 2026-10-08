# Phantom models — 2026-10-06

The user picked **option B** for the Phantom (ghost) addons: every car + Phantom addon pair gets a model of its own. That is **15 addon models and 105 build models**. Concepts with drawings: https://claude.ai/artifact/6pWuFngQZNMWdvbTRiz7TA

Everything else is already in the game (Claude, 2026-10-06): the 15 Phantom addons are sold for bolts at the **Phantom Garage** stall in the Race Wars lobby, and any car fused with one makes a **Spectral** build (a new rarity above Godly, the best earners on a pad). Until a model exists, the game borrows one and draws it see-through and ghostly (`ItemVisuals.Ghostly`): a Phantom addon borrows `Fusion Core`, a Phantom build borrows the same car's Warp Drive build. **As soon as `ReplicatedStorage.ItemModels.<exact name>` exists it is used instead, with no code change.**

## Status (2026-10-08)

- **The 15 Phantom addon models are DONE** (Claude, `assets/phantom-addons`): built in Blender, uploaded and installed in `ReplicatedStorage.ItemModels` under the exact names below, at 4.6 / 4.8 / 5.0 studs (Wisp / Wraith / Reaper). Don't rebuild them; see that folder's README for the builder and the look. The user wanted to see these before deciding who builds the rest.
- **The 105 Spectral builds are still to do.** Each should feature its own Phantom addon's look (the installed addon models are the reference).
- **7 sample builds are installed** (Claude, `assets/phantom-builds`): Wisp Kart, Skullsmoke Rider, Coffin Caddy, Banshee Muscle, Graveyard Patrol, Specter Hauler, Wraith Crusher. The user asked to see how the addons look on the cars. Each is the base car's own body in a haunted livery with the addon mounted, so it's less than the art direction below asks for. Count them as samples: a proper model under the same name replaces one (installers back up what they replace).

## The user's art direction

- "I want one car to look like it per tier, not all of the cars in the tier to look the same... everything after [the base models] starts to look like I'm seeing duplicates." So each of the 105 should read as its **own** vehicle: the car's body itself changed by its ghost theme (shape, trim, materials), not the base car with one part bolted on. The ghost part should still be the obvious feature.
- Ghost palette, so the family reads as different from every other addon: ectoplasm mint `150,255,210`, wisp blue `159,216,255`, violet `197,139,255`, bone `242,234,211`, on dark violets and black iron.
- Spectral is shown in the UI as mint letters on dark violet.

## How each model is set up

Same as the other builds (see docs/MODELS_TODO.md):

- A `Model` in `ReplicatedStorage.ItemModels`, named **exactly** as below (apostrophes included).
- Build attributes: `FusionBase` (the car), `FusionAddon` (the Phantom addon), `DisplayName`, `NoseAxis = +Z`.
- Wheels as separate parts with `WheelPivot` / `WheelRadius`, so they roll on the conveyor and in races (Wraith Wheels builds: the ghost-fire rims are the wheels).
- About the size of the car's base model (sizes per car below), under about 90k triangles. No real brands or logos.
- A Phantom **addon** model is the part on its own, about the size of the other addon models (it stands on a pedestal in the Phantom shop, Inventory and Index).

## Suggested order

1. **The 15 addon models.** Players see these first, in the Phantom shop.
2. **Wisp builds** (the 35 made with the five cheapest addons): players can afford these first.
3. **Wraith builds** (35).
4. **Reaper builds** (35).

Within a tier, one addon at a time across all seven cars keeps each ghost part consistent.

## The list

### Will-o'-Wisp Lanterns — Wisp, 40 bolts

Two iron carriage lanterns on poles over the front fenders, a green spirit flame in each; little wisps drift off and follow the car.

| Car | Build (ItemModels name) | Car size |
|---|---|---|
| Rusted Sedan | `Wisp Kart` | the Scrap Kart body, about 5 studs |
| Dirt Bike | `Wisp Rider` | about 5 studs |
| Golf Cart | `Wisp Caddy` | about 6 studs (1.2x the first Golf Cart builds, see HANDOFF) |
| Muscle Car | `Wisp Muscle` | about 5 studs |
| Cop Cruiser | `Wisp Patrol` | about 6 studs |
| Box Truck | `Wisp Hauler` | about 7.5 studs |
| Monster Truck | `Wisp Crusher` | about 5 studs |

### Phantom Exhaust — Wisp, 45 bolts

Twin exhaust pipes carved from bone, out the back; they puff green smoke rings shaped like little skulls.

| Car | Build (ItemModels name) | Car size |
|---|---|---|
| Rusted Sedan | `Skullsmoke Kart` | the Scrap Kart body, about 5 studs |
| Dirt Bike | `Skullsmoke Rider` | about 5 studs |
| Golf Cart | `Skullsmoke Caddy` | about 6 studs (1.2x the first Golf Cart builds, see HANDOFF) |
| Muscle Car | `Skullsmoke Muscle` | about 5 studs |
| Cop Cruiser | `Skullsmoke Patrol` | about 6 studs |
| Box Truck | `Skullsmoke Hauler` | about 7.5 studs |
| Monster Truck | `Skullsmoke Crusher` | about 5 studs |

### Crystal Ball Ornament — Wisp, 50 bolts

A fortune teller's glass ball on a gold claw stand on the nose of the hood; a tiny ghost spins inside.

| Car | Build (ItemModels name) | Car size |
|---|---|---|
| Rusted Sedan | `Oracle Kart` | the Scrap Kart body, about 5 studs |
| Dirt Bike | `Oracle Rider` | about 5 studs |
| Golf Cart | `Oracle Caddy` | about 6 studs (1.2x the first Golf Cart builds, see HANDOFF) |
| Muscle Car | `Oracle Muscle` | about 5 studs |
| Cop Cruiser | `Oracle Patrol` | about 6 studs |
| Box Truck | `Oracle Hauler` | about 7.5 studs |
| Monster Truck | `Oracle Crusher` | about 5 studs |

### Graveyard Grille — Wisp, 55 bolts

A wrought-iron cemetery gate as the grille and a small "RIP" tombstone as the front bumper; green mist creeps through the bars.

| Car | Build (ItemModels name) | Car size |
|---|---|---|
| Rusted Sedan | `Graveyard Kart` | the Scrap Kart body, about 5 studs |
| Dirt Bike | `Graveyard Rider` | about 5 studs |
| Golf Cart | `Graveyard Caddy` | about 6 studs (1.2x the first Golf Cart builds, see HANDOFF) |
| Muscle Car | `Graveyard Muscle` | about 5 studs |
| Cop Cruiser | `Graveyard Patrol` | about 6 studs |
| Box Truck | `Graveyard Hauler` | about 7.5 studs |
| Monster Truck | `Graveyard Crusher` | about 5 studs |

### Ecto Tank — Wisp, 60 bolts

A glass canister of glowing green ectoplasm strapped behind the cabin, with a pressure gauge; bubbles rise, the goo sloshes in turns.

| Car | Build (ItemModels name) | Car size |
|---|---|---|
| Rusted Sedan | `Ecto Kart` | the Scrap Kart body, about 5 studs |
| Dirt Bike | `Ecto Rider` | about 5 studs |
| Golf Cart | `Ecto Caddy` | about 6 studs (1.2x the first Golf Cart builds, see HANDOFF) |
| Muscle Car | `Ecto Muscle` | about 5 studs |
| Cop Cruiser | `Ecto Patrol` | about 6 studs |
| Box Truck | `Ecto Hauler` | about 7.5 studs |
| Monster Truck | `Ecto Crusher` | about 5 studs |

### Banshee Horn — Wraith, 90 bolts

A long white horn curving up off the hood whose bell is a screaming spirit's mouth; violet sound rings pulse out of it.

| Car | Build (ItemModels name) | Car size |
|---|---|---|
| Rusted Sedan | `Banshee Kart` | the Scrap Kart body, about 5 studs |
| Dirt Bike | `Banshee Rider` | about 5 studs |
| Golf Cart | `Banshee Caddy` | about 6 studs (1.2x the first Golf Cart builds, see HANDOFF) |
| Muscle Car | `Banshee Muscle` | about 5 studs |
| Cop Cruiser | `Banshee Patrol` | about 6 studs |
| Box Truck | `Banshee Hauler` | about 7.5 studs |
| Monster Truck | `Banshee Crusher` | about 5 studs |

### Poltergeist Spoiler — Wraith, 100 bolts

A violet rear wing floating over the trunk, touching nothing, with snapped chains hanging off it; it jitters on its own.

| Car | Build (ItemModels name) | Car size |
|---|---|---|
| Rusted Sedan | `Poltergeist Kart` | the Scrap Kart body, about 5 studs |
| Dirt Bike | `Poltergeist Rider` | about 5 studs |
| Golf Cart | `Poltergeist Caddy` | about 6 studs (1.2x the first Golf Cart builds, see HANDOFF) |
| Muscle Car | `Poltergeist Muscle` | about 5 studs |
| Cop Cruiser | `Poltergeist Patrol` | about 6 studs |
| Box Truck | `Poltergeist Hauler` | about 7.5 studs |
| Monster Truck | `Poltergeist Crusher` | about 5 studs |

### Coffin Carrier — Wraith, 110 bolts

A wooden coffin on a roof rack, lid cracked open, two green eyes inside; the lid knocks over bumps.

| Car | Build (ItemModels name) | Car size |
|---|---|---|
| Rusted Sedan | `Coffin Kart` | the Scrap Kart body, about 5 studs |
| Dirt Bike | `Coffin Rider` | about 5 studs |
| Golf Cart | `Coffin Caddy` | about 6 studs (1.2x the first Golf Cart builds, see HANDOFF) |
| Muscle Car | `Coffin Muscle` | about 5 studs |
| Cop Cruiser | `Coffin Patrol` | about 6 studs |
| Box Truck | `Coffin Hauler` | about 7.5 studs |
| Monster Truck | `Coffin Crusher` | about 5 studs |

### Witch's Cauldron — Wraith, 125 bolts

An iron cauldron of purple brew sunk into the hood where an engine would poke out; bubbles pop faster with speed.

| Car | Build (ItemModels name) | Car size |
|---|---|---|
| Rusted Sedan | `Cauldron Kart` | the Scrap Kart body, about 5 studs |
| Dirt Bike | `Cauldron Rider` | about 5 studs |
| Golf Cart | `Cauldron Caddy` | about 6 studs (1.2x the first Golf Cart builds, see HANDOFF) |
| Muscle Car | `Cauldron Muscle` | about 5 studs |
| Cop Cruiser | `Cauldron Patrol` | about 6 studs |
| Box Truck | `Cauldron Hauler` | about 7.5 studs |
| Monster Truck | `Cauldron Crusher` | about 5 studs |

### Specter Sails — Wraith, 140 bolts

A ship's mast through the roof with a torn, see-through ghost sail and a green pennant; billows back with speed.

| Car | Build (ItemModels name) | Car size |
|---|---|---|
| Rusted Sedan | `Specter Kart` | the Scrap Kart body, about 5 studs |
| Dirt Bike | `Specter Rider` | about 5 studs |
| Golf Cart | `Specter Caddy` | about 6 studs (1.2x the first Golf Cart builds, see HANDOFF) |
| Muscle Car | `Specter Muscle` | about 5 studs |
| Cop Cruiser | `Specter Patrol` | about 6 studs |
| Box Truck | `Specter Hauler` | about 7.5 studs |
| Monster Truck | `Specter Crusher` | about 5 studs |

### Wraith Wheels — Reaper, 200 bolts

All four wheels replaced by rims of blue ghost fire with spokes of light; they leave a glowing track that fades behind the car.

| Car | Build (ItemModels name) | Car size |
|---|---|---|
| Rusted Sedan | `Wraith Kart` | the Scrap Kart body, about 5 studs |
| Dirt Bike | `Wraith Rider` | about 5 studs |
| Golf Cart | `Wraith Caddy` | about 6 studs (1.2x the first Golf Cart builds, see HANDOFF) |
| Muscle Car | `Wraith Muscle` | about 5 studs |
| Cop Cruiser | `Wraith Patrol` | about 6 studs |
| Box Truck | `Wraith Hauler` | about 7.5 studs |
| Monster Truck | `Wraith Crusher` | about 5 studs |

### Soul Turbo — Reaper, 220 bolts

A turbo on top of the hood whose intake is a green vortex; tiny ghosts spiral in and get sucked into it.

| Car | Build (ItemModels name) | Car size |
|---|---|---|
| Rusted Sedan | `Soul Kart` | the Scrap Kart body, about 5 studs |
| Dirt Bike | `Soul Rider` | about 5 studs |
| Golf Cart | `Soul Caddy` | about 6 studs (1.2x the first Golf Cart builds, see HANDOFF) |
| Muscle Car | `Soul Muscle` | about 5 studs |
| Cop Cruiser | `Soul Patrol` | about 6 studs |
| Box Truck | `Soul Hauler` | about 7.5 studs |
| Monster Truck | `Soul Crusher` | about 5 studs |

### Hearse Canopy — Reaper, 240 bolts

A carved black and gold funeral-coach roof over the whole cabin, with swaying lace curtains.

| Car | Build (ItemModels name) | Car size |
|---|---|---|
| Rusted Sedan | `Hearse Kart` | the Scrap Kart body, about 5 studs |
| Dirt Bike | `Hearse Rider` | about 5 studs |
| Golf Cart | `Hearse Caddy` | about 6 studs (1.2x the first Golf Cart builds, see HANDOFF) |
| Muscle Car | `Hearse Muscle` | about 5 studs |
| Cop Cruiser | `Hearse Patrol` | about 6 studs |
| Box Truck | `Hearse Hauler` | about 7.5 studs |
| Monster Truck | `Hearse Crusher` | about 5 studs |

### Reaper Scythes — Reaper, 270 bolts

Curved silver scythe blades out of the centre of each wheel, chariot style, on glowing green hubs.

| Car | Build (ItemModels name) | Car size |
|---|---|---|
| Rusted Sedan | `Reaper Kart` | the Scrap Kart body, about 5 studs |
| Dirt Bike | `Reaper Rider` | about 5 studs |
| Golf Cart | `Reaper Caddy` | about 6 studs (1.2x the first Golf Cart builds, see HANDOFF) |
| Muscle Car | `Reaper Muscle` | about 5 studs |
| Cop Cruiser | `Reaper Patrol` | about 6 studs |
| Box Truck | `Reaper Hauler` | about 7.5 studs |
| Monster Truck | `Reaper Crusher` | about 5 studs |

### Ghost Chauffeur — Reaper, 300 bolts

A see-through butler ghost in a top hat in the driver's seat, both hands on the wheel; waves at nearby players.

| Car | Build (ItemModels name) | Car size |
|---|---|---|
| Rusted Sedan | `Haunted Kart` | the Scrap Kart body, about 5 studs |
| Dirt Bike | `Haunted Rider` | about 5 studs |
| Golf Cart | `Haunted Caddy` | about 6 studs (1.2x the first Golf Cart builds, see HANDOFF) |
| Muscle Car | `Haunted Muscle` | about 5 studs |
| Cop Cruiser | `Haunted Patrol` | about 6 studs |
| Box Truck | `Haunted Hauler` | about 7.5 studs |
| Monster Truck | `Haunted Crusher` | about 5 studs |

