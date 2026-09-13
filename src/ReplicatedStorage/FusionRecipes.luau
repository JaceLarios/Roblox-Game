--[[
	FusionRecipes (ModuleScript, ReplicatedStorage) — Junkyard Fusion v1
	Recipe data + lookup. The server reads this to decide what two items make.
--]]

local FusionRecipes = {}

-- TIER 1: what the scrap spawner drops. Higher weight = more common.
FusionRecipes.BaseItems = {
	{ name = "Rusted Sedan",       weight = 100, value = 5 },
	{ name = "Traffic Cone",       weight = 100, value = 5 },
	{ name = "Shopping Cart",      weight = 90,  value = 6 },
	{ name = "Golf Cart",          weight = 70,  value = 9 },
	{ name = "Dirt Bike",          weight = 60,  value = 12 },
	{ name = "Minivan",            weight = 55,  value = 14 },
	{ name = "Riding Mower",       weight = 45,  value = 18 },
	{ name = "Cop Cruiser",        weight = 30,  value = 30 },
	{ name = "Box Truck",          weight = 25,  value = 38 },
	{ name = "Monster Truck Tire", weight = 15,  value = 60 },
	{ name = "Nitrous Tank",       weight = 8,   value = 120 },
	{ name = "Jet Engine",         weight = 3,   value = 300 },
}

FusionRecipes.TierValue = {
	[2] = 250,
	[3] = 2000,
	[4] = 15000,
}

FusionRecipes.SecretValue = 50000

-- { ingredientA, ingredientB, result, tier } — order does not matter.
local RECIPE_LIST = {
	-- Tier 2
	{ "Rusted Sedan",  "Nitrous Tank",       "Boosted Beater",      2 },
	{ "Shopping Cart", "Dirt Bike",          "Cart Rocket",         2 },
	{ "Golf Cart",     "Monster Truck Tire", "Lifted Cart",         2 },
	{ "Minivan",       "Cop Cruiser",        "Undercover Van",      2 },
	{ "Box Truck",     "Jet Engine",         "Jet Hauler",          2 },
	{ "Riding Mower",  "Nitrous Tank",       "Lawn Missile",        2 },
	{ "Cop Cruiser",   "Dirt Bike",          "Pursuit Bike",        2 },
	{ "Minivan",       "Monster Truck Tire", "Soccer Mom Monster",  2 },
	{ "Rusted Sedan",  "Traffic Cone",       "Cone Cruiser",        2 },
	{ "Golf Cart",     "Jet Engine",         "Fairway Fighter",     2 },

	-- Tier 3
	{ "Boosted Beater", "Pursuit Bike",       "Street Menace",       3 },
	{ "Lifted Cart",    "Soccer Mom Monster", "Suburban Assault",    3 },
	{ "Jet Hauler",     "Lawn Missile",       "Yard Destroyer",      3 },
	{ "Cart Rocket",    "Fairway Fighter",    "Trolley Interceptor", 3 },
	{ "Cone Cruiser",   "Undercover Van",     "Construction Cartel", 3 },
	{ "Street Menace",  "Nitrous Tank",       "Redline Reaper",      3 },

	-- Tier 4
	{ "Yard Destroyer",      "Suburban Assault",    "THE LAWNLORD",     4 },
	{ "Redline Reaper",      "Trolley Interceptor", "Sonic Scrapheap",  4 },
	{ "Construction Cartel", "Jet Hauler",          "Highway Overlord", 4 },
}

-- Secrets: same-item fusions, so players can't stumble into them.
local SECRET_LIST = {
	{ "Traffic Cone",  "Traffic Cone",     "Cone Sentinel", 3 },
	{ "Shopping Cart", "Shopping Cart",    "Cartpocalypse", 3 },
	{ "THE LAWNLORD",  "Highway Overlord", "Scrapyard God", 5 },
}

-- Key = the two names sorted alphabetically and joined with "|".
-- Sorting is the trick: each recipe gets written once, not twice.
local function makeKey(a, b)
	if a <= b then
		return a .. "|" .. b
	else
		return b .. "|" .. a
	end
end

FusionRecipes.MakeKey = makeKey

local lookup = {}

for _, r in ipairs(RECIPE_LIST) do
	lookup[makeKey(r[1], r[2])] = { result = r[3], tier = r[4], isSecret = false }
end

for _, r in ipairs(SECRET_LIST) do
	lookup[makeKey(r[1], r[2])] = { result = r[3], tier = r[4], isSecret = true }
end

-- Fallback fusion: any pair that ISN'T one of the curated recipes above
-- still produces a hybrid instead of "nothing" — one tier above the
-- stronger ingredient, worth less than a real discovery of that tier so
-- hunting down actual recipes stays the better move.
local MAX_FALLBACK_TIER = 4

FusionRecipes.FallbackValue = {}
for tier, tierValue in pairs(FusionRecipes.TierValue) do
	FusionRecipes.FallbackValue[tier] = math.floor(tierValue * 0.35)
end

local FALLBACK_NAMES = {
	[2] = { "Scrap Hybrid", "Junk Mashup", "Bent Fusion", "Rusty Splice" },
	[3] = { "Twisted Wreck", "Chaos Hybrid", "Scrap Titan", "Junkyard Brute" },
	[4] = { "Mangled Overlord", "Junkyard Behemoth", "Wreck Kraken" },
}

-- Tier of any name this module knows about — base items, curated results,
-- and fallback hybrids alike — so a fallback result can be fed back into
-- a later fusion (curated or another fallback) and still resolve right.
local nameTier = {}
for _, item in ipairs(FusionRecipes.BaseItems) do
	nameTier[item.name] = 1
end
for _, r in ipairs(RECIPE_LIST) do
	nameTier[r[3]] = r[4]
end
for _, r in ipairs(SECRET_LIST) do
	nameTier[r[3]] = r[4]
end

local fallbackNameSet = {}
for tier, names in pairs(FALLBACK_NAMES) do
	for _, name in ipairs(names) do
		nameTier[name] = tier
		fallbackNameSet[name] = true
	end
end

-- Same pair always lands on the same hybrid name — reads as a rule you
-- can learn, not a random reroll every time you try it.
local function pickFallbackName(itemA, itemB, tier)
	local pool = FALLBACK_NAMES[tier]
	local key = makeKey(itemA, itemB)
	local hash = 0
	for i = 1, #key do
		hash = hash + string.byte(key, i)
	end
	return pool[(hash % #pool) + 1]
end

-- Returns resultName, infoTable. Only returns nil for malformed input —
-- every valid pair of item names produces something, even without a
-- curated recipe (see the fallback block below).
function FusionRecipes.Fuse(itemA, itemB)
	if type(itemA) ~= "string" or type(itemB) ~= "string" then
		warn("[Fusion] Fuse() needs two item names as strings.")
		return nil
	end

	local entry = lookup[makeKey(itemA, itemB)]
	if entry then
		local value = FusionRecipes.TierValue[entry.tier] or 0
		if entry.isSecret then
			value = FusionRecipes.SecretValue
		end

		return entry.result, {
			tier     = entry.tier,
			isSecret = entry.isSecret,
			value    = value,
		}
	end

	local tierA = nameTier[itemA] or 1
	local tierB = nameTier[itemB] or 1
	local resultTier = math.min(MAX_FALLBACK_TIER, math.max(tierA, tierB) + 1)
	local resultName = pickFallbackName(itemA, itemB, resultTier)

	return resultName, {
		tier       = resultTier,
		isSecret   = false,
		isFallback = true,
		value      = FusionRecipes.FallbackValue[resultTier] or 0,
	}
end

function FusionRecipes.GetValue(itemName)
	for _, base in ipairs(FusionRecipes.BaseItems) do
		if base.name == itemName then
			return base.value
		end
	end

	for _, entry in pairs(lookup) do
		if entry.result == itemName then
			if entry.isSecret then
				return FusionRecipes.SecretValue
			end
			return FusionRecipes.TierValue[entry.tier] or 0
		end
	end

	if fallbackNameSet[itemName] then
		return FusionRecipes.FallbackValue[nameTier[itemName]] or 0
	end

	return 0
end

function FusionRecipes.IsFallbackResult(name)
	return fallbackNameSet[name] == true
end

-- Roll a random Tier 1 item using the weights above.
function FusionRecipes.RollBaseItem()
	local total = 0
	for _, item in ipairs(FusionRecipes.BaseItems) do
		total = total + item.weight
	end

	local roll = math.random() * total
	local running = 0

	for _, item in ipairs(FusionRecipes.BaseItems) do
		running = running + item.weight
		if roll <= running then
			return item.name
		end
	end

	return FusionRecipes.BaseItems[1].name
end

function FusionRecipes.GetAllResults()
	local results = {}
	for _, entry in pairs(lookup) do
		table.insert(results, {
			name     = entry.result,
			tier     = entry.tier,
			isSecret = entry.isSecret,
		})
	end
	return results
end

function FusionRecipes.GetTotalDiscoveries()
	local count = 0
	for _ in pairs(lookup) do
		count = count + 1
	end
	return count
end

-- Full recipe book, masked for whatever this player hasn't found yet.
-- Masking happens on the SERVER, so an exploiter reading client memory
-- still can't see the answers.
function FusionRecipes.GetRecipeBook(discovered)
	discovered = discovered or {}
	local book = {}

	for _, r in ipairs(RECIPE_LIST) do
		local known = discovered[r[3]] == true
		table.insert(book, {
			result   = known and r[3] or "???",
			a        = known and r[1] or "???",
			b        = known and r[2] or "???",
			tier     = r[4],
			known    = known,
			isSecret = false,
		})
	end

	local secretsFound = 0
	for _, r in ipairs(SECRET_LIST) do
		if discovered[r[3]] then
			secretsFound = secretsFound + 1
		end
	end

	table.sort(book, function(x, y)
		if x.tier ~= y.tier then
			return x.tier < y.tier
		end
		return x.result < y.result
	end)

	return book, secretsFound, #SECRET_LIST
end

function FusionRecipes.IsSecretResult(name)
	for _, r in ipairs(SECRET_LIST) do
		if r[3] == name then
			return true
		end
	end
	return false
end

return FusionRecipes
