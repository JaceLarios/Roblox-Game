--[[
	FusionRecipes (ModuleScript, ReplicatedStorage) — Junkyard Fusion v1
	Recipe data + lookup. The server reads this to decide what a fusion makes.

	Every Junkyard fusion is one item plus one addon:
	  - the addon sets the result's rarity (Nitrous Tank makes Uncommon,
	    up to the Jet Engine, which always makes Legendary);
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

-- What the yard drops. `weight` is the percent of drops that are this
-- item, and the list adds up to 100: 88 for the seven cars and 12 for the
-- addons. `value` is what it sells for as a loose item.
--
-- Cars carry a `multiplier`: a fused result is worth its addon's
-- `resultValue` times the car's multiplier, so the rarer the car the
-- higher its result sits in that addon's range.
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
	-- The Nitrous Tank is a booster rather than an engine and exists so
	-- fusing stays frequent now that every fusion uses an addon up; the
	-- engines keep their order, Inline 4 < V6 < V8 < Jet.
	{ name = "Nitrous Tank", rarity = "uncommon",  value = 20,  weight = 7.5, isAddon = true, resultValue = 150 },
	{ name = "Inline 4",     rarity = "rare",      value = 45,  weight = 2.5, isAddon = true, resultValue = 500 },
	{ name = "V6 Engine",    rarity = "epic",      value = 110, weight = 1.3, isAddon = true, resultValue = 2000 },
	{ name = "V8 Engine",    rarity = "mythic",    value = 210, weight = 0.5, isAddon = true, resultValue = 10000 },
	{ name = "Jet Engine",   rarity = "legendary", value = 300, weight = 0.2, isAddon = true, resultValue = 50000 },
}

-- The whole recipe book: one result per car per addon, in the addon order
-- above (Nitrous, Inline 4, V6, V8, Jet).
local BOOK = {
	["Rusted Sedan"]  = { "Rusty Splice",       "Boosted Beater",    "Street Menace",       "Redline Reaper",   "Sonic Scrapheap" },
	["Dirt Bike"]     = { "Bent Fusion",        "Pursuit Bike",      "Trail Blazer",        "Chaos Hybrid",     "Rocket Rider" },
	["Golf Cart"]     = { "Cart Rocket",        "Lifted Cart",       "Fairway Fighter",     "Cartpocalypse",    "THE LAWNLORD" },
	["Muscle Car"]    = { "Junk Mashup",        "Undercover Muscle", "Twisted Wreck",       "Chrome Sentinel",  "Afterburner GT" },
	["Cop Cruiser"]   = { "Cone Cruiser",       "Undercover Van",    "Turbo Interceptor",   "Highway Overlord", "Sky Marshal" },
	["Box Truck"]     = { "Scrap Hybrid",       "Hauler Hemi",       "Construction Cartel", "Yard Destroyer",   "Jet Hauler" },
	["Monster Truck"] = { "Soccer Mom Monster", "Junkyard Brute",    "Suburban Assault",    "Mangled Overlord", "Scrapyard God" },
}

-- Older code, and the Index filters until they move to rarity, still read
-- a 1-4 fusion tier. Base items are tier 1; a result's tier is its rarity
-- step capped at 4, which also keeps the tier colours (green, blue,
-- purple) matching the rarity colours wherever a caller passes no rarity.
local MAX_TIER = 4

FusionRecipes.Items = {}    -- cars only
FusionRecipes.Addons = {}   -- addons only, worst to best

local baseByName = {}
local addonRank = {}        -- [addon name] = 1 (Nitrous) .. 5 (Jet)
for _, item in ipairs(FusionRecipes.BaseItems) do
	baseByName[item.name] = item
	if item.isAddon then
		table.insert(FusionRecipes.Addons, item)
		addonRank[item.name] = #FusionRecipes.Addons
	else
		table.insert(FusionRecipes.Items, item)
	end
end

-- Share of drops that are an addon (0.12). Worked out from the weights
-- rather than set by hand, so the two can never disagree.
local addonWeight, totalWeight = 0, 0
for _, item in ipairs(FusionRecipes.BaseItems) do
	totalWeight += item.weight
	if item.isAddon then addonWeight += item.weight end
end
FusionRecipes.AddonSpawnChance = addonWeight / totalWeight

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

-- Better addons always win: the cheapest result of each addon has to be
-- worth more than the best result of the one below it. Checked here so
-- a later tweak to a value or multiplier cannot quietly break it.
do
	local bestBelow = 0
	for _, addon in ipairs(FusionRecipes.Addons) do
		local lowest, highest = math.huge, 0
		for _, car in ipairs(FusionRecipes.Items) do
			local value = results[recipe[car.name][addon.name]].value
			lowest = math.min(lowest, value)
			highest = math.max(highest, value)
		end
		assert(lowest > bestBelow, "FusionRecipes: " .. addon.name .. " results overlap the addon below it")
		bestBelow = highest
	end
end

function FusionRecipes.IsAddon(name)
	return addonRank[name] ~= nil
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
-- its addon's). Nil for a name from outside this line (a secret pet), so
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

-- The Junkyard has no secret recipes: with one result per car per addon,
-- every result is in plain sight in the book. Kept so the callers shared
-- with the Brainrot and Haunted lines, which do have secrets, still work.
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

-- What the yard drops: any car or addon, at its own weight.
function FusionRecipes.RollSpawn()
	return weightedPick(FusionRecipes.BaseItems)
end

-- Cars only. Kept separate from RollSpawn so callers that want "a
-- regular item" (the daily reward, the luck upgrade, a drop that landed
-- on something at its map limit) never hand out an addon by accident.
function FusionRecipes.RollBaseItem()
	return weightedPick(FusionRecipes.Items)
end

-- Every item in this line for the Index: the grabbables, then all 35
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
