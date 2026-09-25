--[[
	FusionRecipes (ModuleScript, ReplicatedStorage) — Junkyard Fusion v1
	Recipe data + lookup. The server reads this to decide what a fusion makes.

	Every Junkyard fusion is one item plus one addon:
	  - the addon sets the result's rarity (the Uncommon addons, Nitrous
	    Tank and its two neighbours, make Uncommon results, up to the
	    Legendary ones, Jet Engine and up, which make Legendary);
	  - the car sets which result it is, and where in that rarity's value
	    range it lands (rarer cars land higher);
	  - a fused result can take a better addon later and becomes that
	    addon's version of the same car. A same-or-worse addon is refused.
	Item + item and addon + addon make nothing.
--]]

local FusionRecipes = {}

-- One ordered ladder, shared by grabbables and fused results alike, so
-- "better than" means the same thing everywhere.
local RARITY_INDEX = {
	common = 1, uncommon = 2, rare = 3, epic = 4, mythic = 5, legendary = 6,
}
FusionRecipes.RarityIndex = RARITY_INDEX

-- How exciting each rarity is, as a relative weight. This is NOT the
-- yard's spawn rate any more (each item's own `weight` below is); it is
-- kept for picks that should lean on rarity alone, like what a Crane Drop
-- crate holds.
FusionRecipes.RarityWeight = {
	common    = 100,
	uncommon  = 55,
	rare      = 30,
	epic      = 16,
	mythic    = 7,
	legendary = 3,
}

-- Everything grabbable in the Junkyard. `value` is what it sells for as a
-- loose item.
--
-- Cars ride the yard's conveyor. `weight` is how often each comes out of
-- the black box, relative to the other cars (they add up to 88, so a
-- Rusted Sedan is 24/88, about 27%). Cars carry a `multiplier`: a fused
-- result is worth its addon's `resultValue` times the car's multiplier,
-- so the rarer the car the higher its result sits in that addon's range.
--
-- Addons never spawn: they are bought in the Shop's Addons tab for their
-- `price` in coins.
FusionRecipes.BaseItems = {
	{ name = "Rusted Sedan",  rarity = "common",   value = 5,  weight = 24,  multiplier = 1.0 },
	{ name = "Dirt Bike",     rarity = "common",   value = 10, weight = 24,  multiplier = 1.1 },
	{ name = "Golf Cart",     rarity = "uncommon", value = 15, weight = 14,  multiplier = 1.3 },
	{ name = "Muscle Car",    rarity = "uncommon", value = 25, weight = 14,  multiplier = 1.45 },
	{ name = "Cop Cruiser",   rarity = "rare",     value = 35, weight = 7,   multiplier = 1.7 },
	{ name = "Box Truck",     rarity = "epic",     value = 55, weight = 3.5, multiplier = 2.2 },
	{ name = "Monster Truck", rarity = "mythic",   value = 90, weight = 1.5, multiplier = 3.0 },

	-- ADDONS, worst to best: the order is the upgrade ladder, so keep it.
	-- An addon's own rarity is also the rarity of everything it makes.
	-- Three to a rarity: the original part first, then two a little
	-- stronger (their builds are worth 5% and 10% more). A better rarity
	-- always beats every build of the one below it; within a rarity the
	-- later addon is a small step up, so a build can still take it.
	-- The Nitrous Tank is a booster rather than an engine and exists so
	-- fusing stays frequent now that every fusion uses an addon up.
	--
	-- Prices: new players start with no coins, so the Nitrous Tank costs
	-- about what a few cars sell for, and its first fusion pays that back.
	-- Each rarity's first addon costs roughly one and a half to two times
	-- the cheapest build it makes, so a placed build of that tier earns its
	-- next addon back in a few minutes; the two after it cost a bit more.
	--
	-- `standIn` is the addon whose model is shown until this one has its
	-- own in ItemModels (see FusionRecipes.StandIn).
	{ name = "Nitrous Tank",   rarity = "uncommon",  value = 20,  price = 50,     isAddon = true, resultValue = 150 },
	{ name = "Straight Pipes", rarity = "uncommon",  value = 24,  price = 80,     isAddon = true, resultValue = 158, standIn = "Nitrous Tank" },
	{ name = "Scrap Turbo",    rarity = "uncommon",  value = 28,  price = 110,    isAddon = true, resultValue = 165, standIn = "Nitrous Tank" },
	{ name = "Inline 4",       rarity = "rare",      value = 45,  price = 750,    isAddon = true, resultValue = 500 },
	{ name = "Rotary Engine",  rarity = "rare",      value = 52,  price = 900,    isAddon = true, resultValue = 525, standIn = "Inline 4" },
	{ name = "Twin Turbo",     rarity = "rare",      value = 60,  price = 1100,   isAddon = true, resultValue = 550, standIn = "Inline 4" },
	{ name = "V6 Engine",      rarity = "epic",      value = 110, price = 4000,   isAddon = true, resultValue = 2000 },
	{ name = "Supercharger",   rarity = "epic",      value = 125, price = 4800,   isAddon = true, resultValue = 2100, standIn = "V6 Engine" },
	{ name = "Diesel Stack",   rarity = "epic",      value = 140, price = 5600,   isAddon = true, resultValue = 2200, standIn = "V6 Engine" },
	{ name = "V8 Engine",      rarity = "mythic",    value = 210, price = 20000,  isAddon = true, resultValue = 10000 },
	{ name = "V12 Engine",     rarity = "mythic",    value = 235, price = 24000,  isAddon = true, resultValue = 10500, standIn = "V8 Engine" },
	{ name = "Hover Fans",     rarity = "mythic",    value = 260, price = 28000,  isAddon = true, resultValue = 11000, standIn = "V8 Engine" },
	{ name = "Jet Engine",     rarity = "legendary", value = 300, price = 100000, isAddon = true, resultValue = 50000 },
	{ name = "Rocket Booster", rarity = "legendary", value = 330, price = 120000, isAddon = true, resultValue = 52500, standIn = "Jet Engine" },
	{ name = "Fusion Core",    rarity = "legendary", value = 360, price = 140000, isAddon = true, resultValue = 55000, standIn = "Jet Engine" },
}

-- The whole recipe book: one result per car per addon, in the addon order
-- above, three to a rarity:
--   Uncommon  Nitrous Tank, Straight Pipes, Scrap Turbo
--   Rare      Inline 4, Rotary Engine, Twin Turbo
--   Epic      V6 Engine, Supercharger, Diesel Stack
--   Mythic    V8 Engine, V12 Engine, Hover Fans
--   Legendary Jet Engine, Rocket Booster, Fusion Core
local BOOK = {
	["Rusted Sedan"] = {
		"Rusty Splice", "Loud Lemon", "Turbo Tin Can",
		"Boosted Beater", "Spin Cycle Sedan", "Double Trouble",
		"Street Menace", "Whine Machine", "Smoke Screen Sedan",
		"Redline Reaper", "Grand Tourer Ghost", "Hover Heap",
		"Sonic Scrapheap", "Retro Rocket", "Reactor Rustbucket",
	},
	["Dirt Bike"] = {
		"Bent Fusion", "Screamer Bike", "Dust Devil",
		"Pursuit Bike", "Wankel Wheelie", "Twin Spool Trail",
		"Trail Blazer", "Blower Bike", "Mud Stomper",
		"Chaos Hybrid", "Twelve Cylinder Chopper", "Hoverbike",
		"Rocket Rider", "Moonshot Moto", "Atom Rider",
	},
	["Golf Cart"] = {
		"Cart Rocket", "Putter Popper", "Turbo Tee",
		"Lifted Cart", "Rotary Roller", "Double Bogey",
		"Fairway Fighter", "Sand Trap Supreme", "Diesel Driver",
		"Cartpocalypse", "Hole in Twelve", "Hover Caddy",
		"THE LAWNLORD", "Eagle Launcher", "Atomic Albatross",
	},
	["Muscle Car"] = {
		"Junk Mashup", "Rumble Pony", "Boost Stallion",
		"Undercover Muscle", "Rotor Rebel", "Twin Turbo Thunder",
		"Twisted Wreck", "Blown Charger", "Coal Roller",
		"Chrome Sentinel", "Grand Growler", "Street Levitator",
		"Afterburner GT", "Rocket Stallion", "Fusion Fury",
	},
	["Cop Cruiser"] = {
		"Cone Cruiser", "Siren Screamer", "Patrol Spooler",
		"Undercover Van", "Rotary Ranger", "Twin Chase",
		"Turbo Interceptor", "Supercharged Sheriff", "Riot Rig",
		"Highway Overlord", "Pursuit Prime", "Hover Patrol",
		"Sky Marshal", "Orbital Enforcer", "Plasma Patrol",
	},
	["Box Truck"] = {
		"Scrap Hybrid", "Rattle Hauler", "Turbo Mover",
		"Hauler Hemi", "Rotary Rig", "Twin Turbo Freight",
		"Construction Cartel", "Blown Big Rig", "Diesel Dynamo",
		"Yard Destroyer", "Titan Twelve", "Cargo Hoverer",
		"Jet Hauler", "Rocket Freight", "Core Carrier",
	},
	["Monster Truck"] = {
		"Soccer Mom Monster", "Stomp Pipes", "Crusher Turbo",
		"Junkyard Brute", "Rotary Wrecker", "Twin Turbo Titan",
		"Suburban Assault", "Supercharged Smasher", "Black Smoke Beast",
		"Mangled Overlord", "V12 Leviathan", "Hover Hulk",
		"Scrapyard God", "Rocket Juggernaut", "Fusion Colossus",
	},
}

-- Older code, and the Index filters until they move to rarity, still read
-- a 1-4 fusion tier. Base items are tier 1; a result's tier is its rarity
-- step capped at 4, which also keeps the tier colours (green, blue,
-- purple) matching the rarity colours wherever a caller passes no rarity.
local MAX_TIER = 4

FusionRecipes.Items = {}    -- cars only
FusionRecipes.Addons = {}   -- addons only, worst to best

local baseByName = {}
local addonRank = {}        -- [addon name] = 1 (Nitrous) .. 15 (Fusion Core)
for _, item in ipairs(FusionRecipes.BaseItems) do
	baseByName[item.name] = item
	if item.isAddon then
		table.insert(FusionRecipes.Addons, item)
		addonRank[item.name] = #FusionRecipes.Addons
	else
		table.insert(FusionRecipes.Items, item)
	end
end

local results = {}      -- [result name] = info about it (see below)
local resultList = {}   -- in Index order: by rarity, then by car
local recipe = {}       -- [car][addon] = result name

for _, car in ipairs(FusionRecipes.Items) do
	local row = BOOK[car.name]
	assert(row and #row == #FusionRecipes.Addons, "FusionRecipes: " .. car.name .. " needs one result per addon")
	recipe[car.name] = {}
	for rank, addon in ipairs(FusionRecipes.Addons) do
		local name = row[rank]
		assert(not results[name] and not baseByName[name], "FusionRecipes: " .. name .. " is used twice")
		results[name] = {
			name = name,
			car = car.name,
			addon = addon.name,
			addonRank = rank,
			rarity = addon.rarity,
			tier = math.min(RARITY_INDEX[addon.rarity], MAX_TIER),
			value = math.round(addon.resultValue * car.multiplier),
		}
		recipe[car.name][addon.name] = name
	end
end

for _, addon in ipairs(FusionRecipes.Addons) do
	for _, car in ipairs(FusionRecipes.Items) do
		table.insert(resultList, results[recipe[car.name][addon.name]])
	end
end

-- Until a result has its own model it borrows the model of the same car's
-- build with the first addon of its rarity (Hover Heap shows as Redline
-- Reaper), which does have one.
do
	local firstOfRarity = {}
	for _, addon in ipairs(FusionRecipes.Addons) do
		firstOfRarity[addon.rarity] = firstOfRarity[addon.rarity] or addon.name
	end
	for _, entry in pairs(results) do
		local base = firstOfRarity[entry.rarity]
		if base ~= entry.addon then
			entry.standIn = recipe[entry.car][base]
		end
	end
end

-- Better rarities always win: the cheapest build of each rarity has to be
-- worth more than the best build of the rarity below it, and within a
-- rarity each addon's builds are worth more than the same car's build
-- with the addon before it. Checked here so a later tweak to a value or
-- multiplier cannot quietly break either.
do
	local bestBelow, rarityLow, rarityHigh, rarity = 0, math.huge, 0, nil
	for rank, addon in ipairs(FusionRecipes.Addons) do
		if addon.rarity ~= rarity then
			assert(rarityLow > bestBelow or rarity == nil,
				"FusionRecipes: " .. tostring(rarity) .. " builds overlap the rarity below them")
			if rarity then bestBelow = rarityHigh end
			rarity, rarityLow, rarityHigh = addon.rarity, math.huge, 0
		end
		for _, car in ipairs(FusionRecipes.Items) do
			local value = results[recipe[car.name][addon.name]].value
			rarityLow = math.min(rarityLow, value)
			rarityHigh = math.max(rarityHigh, value)
			local previous = FusionRecipes.Addons[rank - 1]
			if previous and previous.rarity == addon.rarity then
				assert(value > results[recipe[car.name][previous.name]].value,
					"FusionRecipes: " .. addon.name .. " is not a step up from " .. previous.name)
			end
		end
	end
	assert(rarityLow > bestBelow, "FusionRecipes: " .. tostring(rarity) .. " builds overlap the rarity below them")
end

function FusionRecipes.IsAddon(name)
	return addonRank[name] ~= nil
end

-- The name whose model stands in for this one until it has its own in
-- ItemModels (an addon's `standIn`, or a build's; see above), or nil.
function FusionRecipes.StandIn(name)
	local base = baseByName[name]
	if base then return base.standIn end
	local entry = results[name]
	return entry and entry.standIn
end

-- Works out what a pair makes. Returns the result's name and whether it
-- was an upgrade, or nil and the reason it cannot fuse (a sentence fit to
-- show the player). Takes bare names, without a mutation prefix.
local function resolve(itemA, itemB)
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

-- Rarity of any Junkyard name: a grabbable's own, or a result's (which is
-- its addon's). Nil for a name from outside this line, so callers fall
-- back to the tier colour for those.
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

-- The Junkyard has no secret recipes: with one result per car per addon,
-- every result is in plain sight in the book. Kept for the callers that
-- still ask (the Index's Secret filter, rarity colours).
function FusionRecipes.IsSecretResult(_name)
	return false
end

function FusionRecipes.GetSecretProgress(_discovered)
	return 0, 0
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

-- Every item in this line for the Index: the grabbables, then all 105
-- results by rarity and then by car. Each carries its `rarity` for the
-- rarity filters, and a result carries the `car` and `addon` that make it,
-- so the book can be laid out as cars by addons. An undiscovered result's
-- name stays hidden.
function FusionRecipes.GetIndex(discovered)
	discovered = discovered or {}
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

	return items
end

return FusionRecipes
