--[[
	FusionRecipes (ModuleScript, ReplicatedStorage) — Junkyard Fusion v1
	Recipe data + lookup. The server reads this to decide what a fusion makes.

	Every Junkyard fusion is one item plus one addon, and the better the
	car and the addon, the better the build:
	  - the addon sets the result's rarity to start with (an Uncommon addon,
	    Nitrous Tank and its two neighbours, makes an Uncommon build, up to
	    the Legendary addons, Jet Engine and up);
	  - the car moves it a rarity (its `shift`): the Scrap Kart and the Dirt
	    Bike drop it one, the Golf Cart, Muscle Car and Cop Cruiser leave it,
	    and the Box Truck and Monster Truck raise it one. A Legendary addon
	    on one of those two makes the top rarity, Godly. Nothing drops below
	    Uncommon;
	  - inside its rarity, a better car and a better addon are worth more;
	  - a fused result can take a better addon later and becomes that
	    addon's version of the same car. A same-or-worse addon is refused.
	Item + item and addon + addon make nothing.
--]]

local FusionRecipes = {}

-- One ordered ladder, shared by grabbables and fused results alike, so
-- "better than" means the same thing everywhere.
local RARITY_INDEX = {
	common = 1, uncommon = 2, rare = 3, epic = 4, mythic = 5, legendary = 6,
	-- Only builds: a Legendary addon on a Box Truck or Monster Truck.
	godly = 7,
	-- Only builds: any car with a Phantom addon (see PHANTOM ADDONS below).
	spectral = 8,
	-- Only the Secret cars (see FusionRecipes.SecretCars below).
	secret = 9,
}
FusionRecipes.RarityIndex = RARITY_INDEX

-- How exciting each rarity is, as a relative weight. This is NOT the
-- yard's spawn rate any more (each item's own `weight` below is); it is
-- kept for picks that should lean on rarity alone.
FusionRecipes.RarityWeight = {
	common    = 100,
	uncommon  = 55,
	rare      = 30,
	epic      = 16,
	mythic    = 7,
	legendary = 3,
	godly     = 2,
	spectral  = 1.5,
	secret    = 1,
}

-- Everything grabbable in the Junkyard. `value` is what it is worth: what
-- it earns placed on a pad goes by it (nothing is sold for coins, and no
-- worth is ever shown to players).
--
-- Cars ride the yard's conveyor. `weight` is how often each comes out of
-- the black box, relative to the other cars (they add up to 88, so a
-- Rusted Sedan is 24/88, about 27%). Each car's `shift` is how many
-- rarities it moves a build from its addon's (see the top), and its
-- `multiplier` is how much more its builds are worth inside their rarity.
-- On the cars that leave the rarity alone a build is worth its addon's
-- `resultValue` times the car's multiplier (see "The whole recipe book"
-- below for the rest).
--
-- Addons never spawn: they are bought in the Shop's Addons tab for their
-- `price` in coins.
FusionRecipes.BaseItems = {
	{ name = "Rusted Sedan",  rarity = "common",   value = 5,  weight = 24,  multiplier = 1.0,  shift = -1 },
	{ name = "Dirt Bike",     rarity = "common",   value = 10, weight = 24,  multiplier = 1.1,  shift = -1 },
	{ name = "Golf Cart",     rarity = "uncommon", value = 15, weight = 14,  multiplier = 1.3,  shift = 0 },
	{ name = "Muscle Car",    rarity = "uncommon", value = 25, weight = 14,  multiplier = 1.45, shift = 0 },
	{ name = "Cop Cruiser",   rarity = "rare",     value = 35, weight = 7,   multiplier = 1.7,  shift = 0 },
	{ name = "Box Truck",     rarity = "epic",     value = 55, weight = 3.5, multiplier = 2.2,  shift = 1 },
	{ name = "Monster Truck", rarity = "mythic",   value = 90, weight = 1.5, multiplier = 3.0,  shift = 1 },

	-- ADDONS, worst to best: the order is the upgrade ladder, so keep it.
	-- An addon's own rarity is where its builds start (the car moves them).
	-- Three to a rarity: the original part first, then two a little
	-- stronger (their builds are worth 5% and 9% more), so every rarity has
	-- one addon better than the rest. A better rarity always beats every
	-- build of the one below it; within a rarity the later addon is a small
	-- step up, so a build can still take it. No two things in the game are
	-- worth the same (checked below), which is why the steps are 5% and 9%
	-- and not a round 10%: that tied Hover Heap with Chaos Hybrid.
	-- The Nitrous Tank is a booster rather than an engine and exists so
	-- fusing stays frequent now that every fusion uses an addon up.
	--
	-- Prices: new players start with no coins, so the Nitrous Tank is cheap
	-- enough for the first day's daily reward, and its first fusion pays
	-- that back.
	-- Each rarity's first addon costs roughly three to four times the
	-- build it makes on a Golf Cart (doubled 2026-09-30, along with pads earning
	-- half as fast, to slow the climb to Rebirth down), so a placed build of
	-- that tier takes a while to earn its next addon; the two after it cost
	-- a bit more.
	--
	-- `standIn` is the addon whose model is shown until this one has its
	-- own in ItemModels (see FusionRecipes.StandIn).
	--
	-- `exclusive` addons are never sold and never come out of a crate: the
	-- Warp Drive only comes from the Day 7 daily streak (PlotManager's
	-- jackpot). It is the best addon in the game, one step above the Fusion
	-- Core, so it sits at the top of the ladder.
	{ name = "Nitrous Tank",   rarity = "uncommon",  value = 20,  price = 100,    isAddon = true, resultValue = 150 },
	{ name = "Straight Pipes", rarity = "uncommon",  value = 24,  price = 160,    isAddon = true, resultValue = 158, standIn = "Nitrous Tank" },
	{ name = "Scrap Turbo",    rarity = "uncommon",  value = 28,  price = 220,    isAddon = true, resultValue = 164, standIn = "Nitrous Tank" },
	{ name = "Inline 4",       rarity = "rare",      value = 45,  price = 1500,   isAddon = true, resultValue = 500 },
	{ name = "Rotary Engine",  rarity = "rare",      value = 52,  price = 1800,   isAddon = true, resultValue = 525, standIn = "Inline 4" },
	{ name = "Twin Turbo",     rarity = "rare",      value = 60,  price = 2200,   isAddon = true, resultValue = 545, standIn = "Inline 4" },
	{ name = "V6 Engine",      rarity = "epic",      value = 110, price = 8000,   isAddon = true, resultValue = 2000 },
	{ name = "Supercharger",   rarity = "epic",      value = 125, price = 9600,   isAddon = true, resultValue = 2100, standIn = "V6 Engine" },
	{ name = "Diesel Stack",   rarity = "epic",      value = 140, price = 11200,  isAddon = true, resultValue = 2180, standIn = "V6 Engine" },
	{ name = "V8 Engine",      rarity = "mythic",    value = 210, price = 40000,  isAddon = true, resultValue = 10000 },
	{ name = "V12 Engine",     rarity = "mythic",    value = 235, price = 48000,  isAddon = true, resultValue = 10500, standIn = "V8 Engine" },
	{ name = "Hover Fans",     rarity = "mythic",    value = 260, price = 56000,  isAddon = true, resultValue = 10900, standIn = "V8 Engine" },
	{ name = "Jet Engine",     rarity = "legendary", value = 300, price = 200000, isAddon = true, resultValue = 50000 },
	{ name = "Rocket Booster", rarity = "legendary", value = 335, price = 240000, isAddon = true, resultValue = 52500, standIn = "Jet Engine" },
	{ name = "Fusion Core",    rarity = "legendary", value = 360, price = 280000, isAddon = true, resultValue = 54500, standIn = "Jet Engine" },
	{ name = "Warp Drive",     rarity = "legendary", value = 390, exclusive = true, isAddon = true, resultValue = 57000, standIn = "Fusion Core" },

	-- PHANTOM ADDONS (2026-10-06): fifteen ghost addons, never in the yard,
	-- the coin Shop or a crate. They are bought with the bolts won in Race
	-- Wars (`bolts`, the price; `group`, the shop's Wisp / Wraith / Reaper
	-- shelf) at the Phantom Garage in the Race Wars lobby. Concepts:
	-- https://claude.ai/artifact/6pWuFngQZNMWdvbTRiz7TA. Any car with one
	-- makes a Spectral build, whatever the car (no shift): the best builds
	-- in the game, each worth its addon's `resultValue` times a small
	-- per-car factor (see SPECTRAL_CAR_STEP), so all 105 sit above every
	-- Godly build and below the Toro SVO. The user chose a model of its own
	-- for every one of the 105 (Codex, family by family): until a build or
	-- addon has its model it borrows one (`standIn`) and is drawn see-through
	-- and ghostly (ItemVisuals.Ghostly). Steps of 4,990 keep every value
	-- different.
	{ name = "Will-o'-Wisp Lanterns", rarity = "spectral", value = 400, bolts = 40, group = "wisp", phantom = true, isAddon = true, resultValue = 285000, standIn = "Fusion Core" },
	{ name = "Phantom Exhaust", rarity = "spectral", value = 410, bolts = 45, group = "wisp", phantom = true, isAddon = true, resultValue = 289990, standIn = "Fusion Core" },
	{ name = "Crystal Ball Ornament", rarity = "spectral", value = 420, bolts = 50, group = "wisp", phantom = true, isAddon = true, resultValue = 294980, standIn = "Fusion Core" },
	{ name = "Graveyard Grille", rarity = "spectral", value = 430, bolts = 55, group = "wisp", phantom = true, isAddon = true, resultValue = 299970, standIn = "Fusion Core" },
	{ name = "Ecto Tank", rarity = "spectral", value = 440, bolts = 60, group = "wisp", phantom = true, isAddon = true, resultValue = 304960, standIn = "Fusion Core" },
	{ name = "Banshee Horn", rarity = "spectral", value = 450, bolts = 90, group = "wraith", phantom = true, isAddon = true, resultValue = 309950, standIn = "Fusion Core" },
	{ name = "Poltergeist Spoiler", rarity = "spectral", value = 460, bolts = 100, group = "wraith", phantom = true, isAddon = true, resultValue = 314940, standIn = "Fusion Core" },
	{ name = "Coffin Carrier", rarity = "spectral", value = 470, bolts = 110, group = "wraith", phantom = true, isAddon = true, resultValue = 319930, standIn = "Fusion Core" },
	{ name = "Witch's Cauldron", rarity = "spectral", value = 480, bolts = 125, group = "wraith", phantom = true, isAddon = true, resultValue = 324920, standIn = "Fusion Core" },
	{ name = "Specter Sails", rarity = "spectral", value = 490, bolts = 140, group = "wraith", phantom = true, isAddon = true, resultValue = 329910, standIn = "Fusion Core" },
	{ name = "Wraith Wheels", rarity = "spectral", value = 500, bolts = 200, group = "reaper", phantom = true, isAddon = true, resultValue = 334900, standIn = "Fusion Core" },
	{ name = "Soul Turbo", rarity = "spectral", value = 510, bolts = 220, group = "reaper", phantom = true, isAddon = true, resultValue = 339890, standIn = "Fusion Core" },
	{ name = "Hearse Canopy", rarity = "spectral", value = 520, bolts = 240, group = "reaper", phantom = true, isAddon = true, resultValue = 344880, standIn = "Fusion Core" },
	{ name = "Reaper Scythes", rarity = "spectral", value = 530, bolts = 270, group = "reaper", phantom = true, isAddon = true, resultValue = 349870, standIn = "Fusion Core" },
	{ name = "Ghost Chauffeur", rarity = "spectral", value = 540, bolts = 300, group = "reaper", phantom = true, isAddon = true, resultValue = 354860, standIn = "Fusion Core" },
}

-- The whole recipe book: one result per car per addon, in the addon order
-- above, three to a rarity:
--   Uncommon  Nitrous Tank, Straight Pipes, Scrap Turbo
--   Rare      Inline 4, Rotary Engine, Twin Turbo
--   Epic      V6 Engine, Supercharger, Diesel Stack
--   Mythic    V8 Engine, V12 Engine, Hover Fans
--   Legendary Jet Engine, Rocket Booster, Fusion Core
-- and then the Day 7 exclusive, the Warp Drive, last in every row.
--
-- A build's rarity is its addon's, moved by its car's `shift`. What it is
-- worth: the worth of its rarity's first build (that rarity's first
-- addon's `resultValue`, or GODLY_BASE), times its addon's step inside the
-- addon's own rarity (1, 1.05, 1.09, and 1.14 for the Warp Drive), times
-- its car's multiplier. A car that drops a build a rarity puts it near
-- the top of the rarity below (x1.25): the Scrap Kart's Uncommon builds
-- take both the Uncommon addons and the Rare ones, and the Rare ones must
-- be worth more. A car that raises a build puts it in the lower part of
-- the rarity above (x0.81: x0.8 tied two builds at 927). On the cars that leave the rarity alone, a
-- build is worth exactly its addon's resultValue times the multiplier.
-- Nothing ties and no rarity overlaps the next (both checked below).
local BOOK = {
	["Rusted Sedan"] = {
		"Rusty Splice", "Loud Lemon", "Turbo Tin Can",
		"Boosted Beater", "Spin Cycle Sedan", "Double Trouble",
		"Street Menace", "Whine Machine", "Smoke Screen Sedan",
		"Redline Reaper", "Grand Tourer Ghost", "Hover Heap",
		"Sonic Scrapheap", "Retro Rocket", "Reactor Rustbucket",
		"Warp Wreck",
	},
	["Dirt Bike"] = {
		"Bent Fusion", "Screamer Bike", "Dust Devil",
		"Pursuit Bike", "Wankel Wheelie", "Twin Spool Trail",
		"Trail Blazer", "Blower Bike", "Mud Stomper",
		"Chaos Hybrid", "Twelve Cylinder Chopper", "Hoverbike",
		"Rocket Rider", "Moonshot Moto", "Atom Rider",
		"Wormhole Wheelie",
	},
	["Golf Cart"] = {
		"Cart Rocket", "Putter Popper", "Turbo Tee",
		"Lifted Cart", "Rotary Roller", "Double Bogey",
		"Fairway Fighter", "Sand Trap Supreme", "Diesel Driver",
		"Cartpocalypse", "Hole in Twelve", "Hover Caddy",
		"THE LAWNLORD", "Eagle Launcher", "Atomic Albatross",
		"Hole in Space",
	},
	["Muscle Car"] = {
		"Junk Mashup", "Rumble Pony", "Boost Stallion",
		"Undercover Muscle", "Rotor Rebel", "Twin Turbo Thunder",
		"Twisted Wreck", "Blown Charger", "Coal Roller",
		"Chrome Sentinel", "Grand Growler", "Street Levitator",
		"Afterburner GT", "Rocket Stallion", "Fusion Fury",
		"Lightspeed Legend",
	},
	["Cop Cruiser"] = {
		"Cone Cruiser", "Siren Screamer", "Patrol Spooler",
		"Undercover Van", "Rotary Ranger", "Twin Chase",
		"Turbo Interceptor", "Supercharged Sheriff", "Riot Rig",
		"Highway Overlord", "Pursuit Prime", "Hover Patrol",
		"Sky Marshal", "Orbital Enforcer", "Plasma Patrol",
		"Warp Warden",
	},
	["Box Truck"] = {
		"Scrap Hybrid", "Rattle Hauler", "Turbo Mover",
		"Hauler Hemi", "Rotary Rig", "Twin Turbo Freight",
		"Construction Cartel", "Blown Big Rig", "Diesel Dynamo",
		"Yard Destroyer", "Titan Twelve", "Cargo Hoverer",
		"Jet Hauler", "Rocket Freight", "Core Carrier",
		"Star Freighter",
	},
	["Monster Truck"] = {
		"Soccer Mom Monster", "Stomp Pipes", "Crusher Turbo",
		"Junkyard Brute", "Rotary Wrecker", "Twin Turbo Titan",
		"Suburban Assault", "Supercharged Smasher", "Black Smoke Beast",
		"Mangled Overlord", "V12 Leviathan", "Hover Hulk",
		"Scrapyard God", "Rocket Juggernaut", "Fusion Colossus",
		"Starcrusher",
	},
}

-- Every car's Phantom builds, in the Phantom addons' order: "<ghost> <car>"
-- (Wisp Kart, Banshee Patrol, Hearse Hauler...). Added to the rows above.
do
	local PHANTOM_ROWS = {
		["Rusted Sedan"] = { "Wisp Kart", "Skullsmoke Kart", "Oracle Kart", "Graveyard Kart", "Ecto Kart", "Banshee Kart", "Poltergeist Kart", "Coffin Kart", "Cauldron Kart", "Specter Kart", "Wraith Kart", "Soul Kart", "Hearse Kart", "Reaper Kart", "Haunted Kart" },
		["Dirt Bike"] = { "Wisp Rider", "Skullsmoke Rider", "Oracle Rider", "Graveyard Rider", "Ecto Rider", "Banshee Rider", "Poltergeist Rider", "Coffin Rider", "Cauldron Rider", "Specter Rider", "Wraith Rider", "Soul Rider", "Hearse Rider", "Reaper Rider", "Haunted Rider" },
		["Golf Cart"] = { "Wisp Caddy", "Skullsmoke Caddy", "Oracle Caddy", "Graveyard Caddy", "Ecto Caddy", "Banshee Caddy", "Poltergeist Caddy", "Coffin Caddy", "Cauldron Caddy", "Specter Caddy", "Wraith Caddy", "Soul Caddy", "Hearse Caddy", "Reaper Caddy", "Haunted Caddy" },
		["Muscle Car"] = { "Wisp Muscle", "Skullsmoke Muscle", "Oracle Muscle", "Graveyard Muscle", "Ecto Muscle", "Banshee Muscle", "Poltergeist Muscle", "Coffin Muscle", "Cauldron Muscle", "Specter Muscle", "Wraith Muscle", "Soul Muscle", "Hearse Muscle", "Reaper Muscle", "Haunted Muscle" },
		["Cop Cruiser"] = { "Wisp Patrol", "Skullsmoke Patrol", "Oracle Patrol", "Graveyard Patrol", "Ecto Patrol", "Banshee Patrol", "Poltergeist Patrol", "Coffin Patrol", "Cauldron Patrol", "Specter Patrol", "Wraith Patrol", "Soul Patrol", "Hearse Patrol", "Reaper Patrol", "Haunted Patrol" },
		["Box Truck"] = { "Wisp Hauler", "Skullsmoke Hauler", "Oracle Hauler", "Graveyard Hauler", "Ecto Hauler", "Banshee Hauler", "Poltergeist Hauler", "Coffin Hauler", "Cauldron Hauler", "Specter Hauler", "Wraith Hauler", "Soul Hauler", "Hearse Hauler", "Reaper Hauler", "Haunted Hauler" },
		["Monster Truck"] = { "Wisp Crusher", "Skullsmoke Crusher", "Oracle Crusher", "Graveyard Crusher", "Ecto Crusher", "Banshee Crusher", "Poltergeist Crusher", "Coffin Crusher", "Cauldron Crusher", "Specter Crusher", "Wraith Crusher", "Soul Crusher", "Hearse Crusher", "Reaper Crusher", "Haunted Crusher" },
	}
	for car, row in pairs(PHANTOM_ROWS) do
		for _, name in ipairs(row) do
			table.insert(BOOK[car], name)
		end
	end
end

-- Older code, and the Index filters until they move to rarity, still read
-- a 1-4 fusion tier. Base items are tier 1; a result's tier is its rarity
-- step capped at 4, which also keeps the tier colours (green, blue,
-- purple) matching the rarity colours wherever a caller passes no rarity.
local MAX_TIER = 4

FusionRecipes.Items = {}    -- cars only
FusionRecipes.Addons = {}   -- addons only, worst to best
FusionRecipes.ShopAddons = {} -- the addons for sale (and in crates): not the exclusives or the Phantoms
FusionRecipes.PhantomAddons = {} -- the Phantom addons, sold for bolts (see PHANTOM ADDONS)

local baseByName = {}
local addonRank = {}        -- [addon name] = 1 (Nitrous) .. 15 (Fusion Core)
for _, item in ipairs(FusionRecipes.BaseItems) do
	baseByName[item.name] = item
	if item.isAddon then
		table.insert(FusionRecipes.Addons, item)
		addonRank[item.name] = #FusionRecipes.Addons
		if item.phantom then
			table.insert(FusionRecipes.PhantomAddons, item)
		elseif not item.exclusive then
			table.insert(FusionRecipes.ShopAddons, item)
		end
	else
		table.insert(FusionRecipes.Items, item)
	end
end

local results = {}      -- [result name] = info about it (see below)
local resultList = {}   -- in Index order: by rarity, then by car, then by addon
local recipe = {}       -- [car][addon] = result name

local GODLY_BASE = 100000
local SHIFTED_DOWN, SHIFTED_UP = 1.25, 0.81
-- A Spectral build is worth its Phantom addon's resultValue times 1 plus
-- this much of its car's multiplier over 1: from x1 (Scrap Kart) to x1.1
-- (Monster Truck). Kept small so all 105 fit between the best Godly build
-- and the Toro SVO.
local SPECTRAL_CAR_STEP = 0.05
local rarityName = {}
for name, index in pairs(RARITY_INDEX) do rarityName[index] = name end
local rarityBase = { godly = GODLY_BASE }
for _, addon in ipairs(FusionRecipes.Addons) do
	rarityBase[addon.rarity] = rarityBase[addon.rarity] or addon.resultValue
end

for carRank, car in ipairs(FusionRecipes.Items) do
	local row = BOOK[car.name]
	assert(row and #row == #FusionRecipes.Addons, "FusionRecipes: " .. car.name .. " needs one result per addon")
	recipe[car.name] = {}
	for rank, addon in ipairs(FusionRecipes.Addons) do
		local name = row[rank]
		assert(not results[name] and not baseByName[name], "FusionRecipes: " .. name .. " is used twice")
		local addonIndex = RARITY_INDEX[addon.rarity]
		local index = math.clamp(addonIndex + car.shift, RARITY_INDEX.uncommon, RARITY_INDEX.godly)
		if addon.phantom then index = RARITY_INDEX.spectral end
		local rarity = rarityName[index]
		local step = addon.resultValue / rarityBase[addon.rarity]
		local lean = index < addonIndex and SHIFTED_DOWN or index > addonIndex and SHIFTED_UP or 1
		results[name] = {
			name = name,
			car = car.name,
			carRank = carRank,
			addon = addon.name,
			addonRank = rank,
			addonRarity = addon.rarity,
			rarity = rarity,
			tier = math.min(index, MAX_TIER),
			value = addon.phantom and math.round(addon.resultValue * (1 + (car.multiplier - 1) * SPECTRAL_CAR_STEP))
				or math.round(rarityBase[rarity] * step * car.multiplier * lean),
			exclusive = addon.exclusive == true,
			phantom = addon.phantom == true,
		}
		recipe[car.name][addon.name] = name
	end
end

for _, entry in pairs(results) do
	table.insert(resultList, entry)
end
table.sort(resultList, function(a, b)
	if a.rarity ~= b.rarity then return RARITY_INDEX[a.rarity] < RARITY_INDEX[b.rarity] end
	if a.carRank ~= b.carRank then return a.carRank < b.carRank end
	return a.addonRank < b.addonRank
end)

-- Until a result has its own model it borrows the model of the same car's
-- build with the first addon of its addon's rarity (Hover Heap shows as
-- Redline Reaper), which does have one.
do
	local firstOfRarity = {}
	for _, addon in ipairs(FusionRecipes.Addons) do
		firstOfRarity[addon.rarity] = firstOfRarity[addon.rarity] or addon.name
	end
	for _, entry in pairs(results) do
		local base = firstOfRarity[entry.addonRarity]
		if base ~= entry.addon then
			entry.standIn = recipe[entry.car][base]
		end
		-- A Phantom build borrows the same car's Warp Drive build (the
		-- best model it has) until its own is made; ItemVisuals draws the
		-- borrowed one see-through and ghostly.
		if entry.phantom then
			entry.standIn = recipe[entry.car]["Warp Drive"]
		end
	end
end

-- SECRET CARS: finished supercars based on real ones, the rarest things in
-- the game. They are already built, so they never take an addon (and need
-- one model each, not a set of builds). They roll out of the black box
-- very rarely (ScrapSpawner), are worth
-- more than any build (the best earners on a pad) and are the fastest cars
-- in Race Wars. They have their own tab in the Index, "???" until found.
-- Their names are made up: real car brands are trademarks, and Roblox
-- takes games down for using them. `model` is the ItemModels entry that
-- shows the car, when its name differs. `credit` is the attribution its
-- model's licence asks for, shown on its Index card as well as in the
-- game's description. `weight` is how often it comes up when a Secret car
-- drops, relative to the others (1 if left out).
--
-- An entry with `comingSoon = true` is a slot held open for a car whose
-- model is not ready yet: the Index shows a "Coming soon" card for it and
-- it never spawns. To fill it, give it the car's real name, its `model`
-- and `credit`, and drop `comingSoon`.
FusionRecipes.SecretCars = {
	{ name = "Toro SVO", rarity = "secret", value = 400000, model = "SVO", weight = 1,
		credit = "Model by SDC PERFORMANCE (Sketchfab), CC BY 4.0, modified" },
	-- A step below the Toro SVO: worth less (so it earns less on a pad and
	-- is a little slower in Race Wars) and comes up twice as often.
	{ name = "Toro", rarity = "secret", value = 300000, weight = 2,
		credit = "Model by Harsh Palan (Sketchfab), CC BY 4.0, modified" },
}
local secretByName = {}
for _, car in ipairs(FusionRecipes.SecretCars) do
	assert(not baseByName[car.name] and not results[car.name], "FusionRecipes: " .. car.name .. " is used twice")
	secretByName[car.name] = car
	baseByName[car.name] = car
end

-- Better rarities always win: the cheapest build of each rarity has to be
-- worth more than the best build of the rarity below it. And every addon
-- is a step up: each car's build with an addon is worth more than its
-- build with the addon before it. Checked here so a later tweak to a
-- value, multiplier or shift cannot quietly break either.
do
	local low, high = {}, {}
	for _, entry in pairs(results) do
		low[entry.rarity] = math.min(low[entry.rarity] or math.huge, entry.value)
		high[entry.rarity] = math.max(high[entry.rarity] or 0, entry.value)
	end
	local below = nil
	for index = RARITY_INDEX.uncommon, RARITY_INDEX.spectral do
		local rarity = rarityName[index]
		if low[rarity] then
			assert(not below or low[rarity] > high[below],
				"FusionRecipes: " .. rarity .. " builds overlap the rarity below them")
			below = rarity
		end
	end
	for _, car in ipairs(FusionRecipes.Items) do
		for rank = 2, #FusionRecipes.Addons do
			local addon, previous = FusionRecipes.Addons[rank], FusionRecipes.Addons[rank - 1]
			assert(results[recipe[car.name][addon.name]].value > results[recipe[car.name][previous.name]].value,
				"FusionRecipes: " .. car.name .. " with " .. addon.name .. " is not a step up from " .. previous.name)
		end
	end
end

-- Every car, addon and build is worth something different, so nothing
-- ties with anything else and each rarity has one best.
do
	local seen = {}
	local function claim(value, name)
		assert(not seen[value], "FusionRecipes: " .. name .. " is worth the same as " .. tostring(seen[value]))
		seen[value] = name
	end
	for _, item in ipairs(FusionRecipes.BaseItems) do
		claim(item.value, item.name)
	end
	for _, entry in ipairs(resultList) do
		claim(entry.value, entry.name)
	end
end

function FusionRecipes.IsAddon(name)
	return addonRank[name] ~= nil
end

-- True for a Phantom addon and every build made with one (bare names).
function FusionRecipes.IsPhantom(name)
	local base = baseByName[name]
	if base then return base.phantom == true end
	local entry = results[name]
	return entry ~= nil and entry.phantom == true
end

-- What a Phantom addon costs in bolts, or nil for anything else.
function FusionRecipes.BoltPrice(name)
	local item = baseByName[name]
	return item and item.phantom and item.bolts or nil
end

-- True for a Secret car (bare name).
function FusionRecipes.IsSecretCar(name)
	return secretByName[name] ~= nil
end

-- The credit a Secret car's model needs shown (see SecretCars), or nil.
function FusionRecipes.Credit(name)
	local car = secretByName[name]
	return car and car.credit
end

-- A Secret car at random, at its `weight`, for the rare roll out of the
-- black box, or nil while every slot is still coming soon.
function FusionRecipes.RollSecretCar()
	local ready, total = {}, 0
	for _, car in ipairs(FusionRecipes.SecretCars) do
		if not car.comingSoon then
			table.insert(ready, car)
			total += car.weight or 1
		end
	end
	if total == 0 then return nil end
	local roll = math.random() * total
	for _, car in ipairs(ready) do
		roll -= car.weight or 1
		if roll <= 0 then return car.name end
	end
	return ready[#ready].name
end

-- True for an exclusive addon (the Warp Drive) and every build made with
-- one: things that only come from the Day 7 streak, never from the Shop,
-- a crate or the secret Legendary drop. Bare names.
function FusionRecipes.IsExclusive(name)
	local base = baseByName[name]
	if base then return base.exclusive == true end
	local entry = results[name]
	return entry ~= nil and entry.exclusive
end

-- The name whose model stands in for this one until it has its own in
-- ItemModels (an addon's `standIn`, or a build's; see above), or nil.
function FusionRecipes.StandIn(name)
	local base = baseByName[name]
	if base then return base.model or base.standIn end
	local entry = results[name]
	return entry and entry.standIn
end

-- Works out what a pair makes. Returns the result's name and whether it
-- was an upgrade, or nil and the reason it cannot fuse (a sentence fit to
-- show the player). Takes bare names, without a mutation prefix.
local function resolve(itemA, itemB)
	if secretByName[itemA] or secretByName[itemB] then
		return nil, "Secret cars are already finished. They can't take an addon."
	end
	local rankA, rankB = addonRank[itemA], addonRank[itemB]
	if rankA and rankB then
		return nil, "You can't fuse two addons together. Pair an addon with a car."
	elseif not rankA and not rankB then
		return nil, "Fusing needs one item and one addon."
	end

	local addon = rankA and itemA or itemB
	local item = rankA and itemB or itemA

	local row = recipe[item]
	if row then
		return row[addon], false
	end

	-- A fused result taking a better addon becomes that addon's version
	-- of the same car, so a car is never wasted on a weak addon.
	local owned = results[item]
	if not owned then
		return nil, "That can't take an addon."
	end
	if addonRank[addon] <= owned.addonRank then
		return nil, "That addon is not better than the one it already has."
	end
	return recipe[owned.car][addon], true
end

-- Why a pair cannot fuse, or nil when it can. Bare names.
function FusionRecipes.PairProblem(itemA, itemB)
	local result, problem = resolve(itemA, itemB)
	if result then return nil end
	return problem
end

-- Returns resultName, info for a pair that fuses, or nil, reason for one
-- that does not (see resolve). Bare names; the caller deals with any
-- mutation the ingredients carried.
function FusionRecipes.Fuse(itemA, itemB)
	if type(itemA) ~= "string" or type(itemB) ~= "string" then
		warn("[Fusion] Fuse() needs two item names as strings.")
		return nil, "Fusing needs one item and one addon."
	end

	local name, upgraded = resolve(itemA, itemB)
	if not name then
		return nil, upgraded
	end

	local entry = results[name]
	return name, {
		tier       = entry.tier,
		rarity     = entry.rarity,
		value      = entry.value,
		isSecret   = false,
		car        = entry.car,
		addon      = entry.addon,
		-- The fused result that took the better addon, when this was an
		-- upgrade rather than a fresh car.
		upgradedFrom = upgraded and (addonRank[itemA] and itemB or itemA) or nil,
	}
end

-- Rarity of any Junkyard name: a grabbable's own, or a result's (its
-- addon's, moved by its car). Nil for a name from outside this line, so
-- callers fall back to the tier colour for those.
function FusionRecipes.GetRarity(name)
	local base = baseByName[name]
	if base then return base.rarity end
	local entry = results[name]
	return entry and entry.rarity
end

-- Tier of any name (see MAX_TIER above). Defaults to 1 for a name it has
-- never seen.
function FusionRecipes.GetTier(name)
	local entry = results[name]
	return entry and entry.tier or 1
end

function FusionRecipes.GetValue(itemName)
	local base = baseByName[itemName]
	if base then return base.value end
	local entry = results[itemName]
	return entry and entry.value or 0
end

-- No fusion result is secret (one result per car per addon, all in plain
-- sight in the book); the Secret cars are. Callers use this for the
-- Index's Secret tab and for sorting and colouring.
function FusionRecipes.IsSecretResult(name)
	return secretByName[name] ~= nil
end

-- How many Secret cars a player has found, out of how many. `found` is a
-- set of bare names.
function FusionRecipes.GetSecretProgress(found)
	local count = 0
	for _, car in ipairs(FusionRecipes.SecretCars) do
		if found and found[car.name] then count += 1 end
	end
	return count, #FusionRecipes.SecretCars
end

function FusionRecipes.GetAllResults()
	local list = {}
	for _, entry in ipairs(resultList) do
		table.insert(list, {
			name = entry.name, tier = entry.tier, rarity = entry.rarity, isSecret = false,
		})
	end
	return list
end

function FusionRecipes.GetTotalDiscoveries()
	return #resultList
end

local function weightedPick(pool)
	local total = 0
	for _, item in ipairs(pool) do
		total = total + item.weight
	end

	local roll = math.random() * total
	local running = 0
	for _, item in ipairs(pool) do
		running = running + item.weight
		if roll <= running then
			return item.name
		end
	end
	return pool[#pool].name
end

-- What comes out of the black box onto the conveyor: a car, at its own
-- weight. Addons never spawn; they are bought (FusionRecipes.AddonPrice).
function FusionRecipes.RollSpawn()
	return weightedPick(FusionRecipes.Items)
end

-- What an addon costs in the Shop, in coins; nil for anything that is not
-- an addon for sale.
function FusionRecipes.AddonPrice(name)
	local item = baseByName[name]
	return item and item.isAddon and item.price or nil
end

-- Cars only. Kept separate from RollSpawn so callers that want "a
-- regular item" (the daily reward, the luck upgrade, a drop that landed
-- on something at its map limit) never hand out an addon by accident.
function FusionRecipes.RollBaseItem()
	return weightedPick(FusionRecipes.Items)
end

-- Every item in this line for the Index: the grabbables, then all 112
-- results by rarity and then by car. Each carries its `rarity` for the
-- rarity filters, and a result carries the `car` and `addon` that make it,
-- so the book can be laid out as cars by addons. An undiscovered result's
-- name stays hidden. The Secret cars come last, found or not per
-- `secretFound` (a set of names), for the Index's Secret tab.
function FusionRecipes.GetIndex(discovered, secretFound)
	discovered = discovered or {}
	secretFound = secretFound or {}
	local items = {}

	for _, base in ipairs(FusionRecipes.BaseItems) do
		table.insert(items, {
			name = base.name, tier = 1, isSecret = false,
			isBase = true, isAddon = base.isAddon == true,
			rarity = base.rarity, known = true,
		})
	end

	for _, entry in ipairs(resultList) do
		local known = discovered[entry.name] == true
		table.insert(items, {
			name     = known and entry.name or "???",
			tier     = entry.tier,
			rarity   = entry.rarity,
			car      = entry.car,
			addon    = entry.addon,
			isSecret = false,
			isBase   = false,
			isAddon  = false,
			known    = known,
		})
	end

	for _, car in ipairs(FusionRecipes.SecretCars) do
		local known = not car.comingSoon and secretFound[car.name] == true
		table.insert(items, {
			name     = known and car.name or "???",
			-- For the admin panel's "show whole Index" only.
			hiddenName = not car.comingSoon and car.name or nil,
			comingSoon = car.comingSoon == true,
			-- Shown on its card, found or not (the model's licence).
			credit   = car.credit,
			tier     = MAX_TIER,
			rarity   = car.rarity,
			isSecret = true,
			isBase   = true,
			isAddon  = false,
			known    = known,
		})
	end

	return items
end

return FusionRecipes
