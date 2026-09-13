--[[
	FusionRecipes (ModuleScript, ReplicatedStorage) — Junkyard Fusion v1
	Recipe data + lookup. The server reads this to decide what two items make.
--]]

local FusionRecipes = {}

-- TIER 1: what the scrap spawner drops. Higher weight = more common.
-- Trimmed to 8 focused vehicles (was 12, including two non-vehicle "junk"
-- items nobody was excited to grab) — a shorter, punchier roster reads
-- better than a long one padded with mundane filler.
FusionRecipes.BaseItems = {
	{ name = "Rusted Sedan",  weight = 100, value = 5 },
	{ name = "Dirt Bike",     weight = 85,  value = 10 },
	{ name = "Golf Cart",     weight = 65,  value = 15 },
	{ name = "Muscle Car",    weight = 45,  value = 25 },
	{ name = "Cop Cruiser",   weight = 30,  value = 35 },
	{ name = "Box Truck",     weight = 18,  value = 55 },
	{ name = "Monster Truck", weight = 8,   value = 90 },
	{ name = "Jet Engine",    weight = 3,   value = 300 },
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
	{ "Rusted Sedan", "Dirt Bike",   "Trail Blazer",      2 },
	{ "Rusted Sedan", "Jet Engine",  "Boosted Beater",    2 },
	{ "Golf Cart",    "Jet Engine",  "Fairway Fighter",   2 },
	{ "Golf Cart",    "Monster Truck", "Lifted Cart",     2 },
	{ "Muscle Car",   "Cop Cruiser", "Undercover Muscle", 2 },
	{ "Dirt Bike",    "Cop Cruiser", "Pursuit Bike",      2 },
	{ "Box Truck",    "Jet Engine",  "Jet Hauler",        2 },
	{ "Muscle Car",   "Box Truck",   "Hauler Hemi",       2 },

	-- Tier 3
	{ "Boosted Beater",  "Pursuit Bike",      "Street Menace",     3 },
	{ "Lifted Cart",     "Undercover Muscle", "Suburban Assault",  3 },
	{ "Jet Hauler",      "Trail Blazer",      "Yard Destroyer",    3 },
	{ "Fairway Fighter", "Hauler Hemi",       "Turbo Interceptor", 3 },
	{ "Street Menace",   "Jet Engine",        "Redline Reaper",    3 },

	-- Tier 4
	{ "Yard Destroyer", "Suburban Assault", "THE LAWNLORD",     4 },
	{ "Redline Reaper",  "Turbo Interceptor", "Sonic Scrapheap", 4 },
	{ "Suburban Assault", "Jet Hauler",      "Highway Overlord", 4 },
}

-- Secrets: same-item fusions, so players can't stumble into them.
local SECRET_LIST = {
	{ "Muscle Car", "Muscle Car",      "Chrome Sentinel", 3 },
	{ "Golf Cart",  "Golf Cart",       "Cartpocalypse",   3 },
	{ "THE LAWNLORD", "Highway Overlord", "Scrapyard God", 5 },
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

-- Tier of any name this module knows about (base item, curated result, or
-- fallback hybrid) — used to color-code names by rarity wherever they're
-- displayed. Defaults to 1 (common) for a name it's never seen.
function FusionRecipes.GetTier(name)
	return nameTier[name] or 1
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

-- How many secrets this player has found, for the "Secrets X/Y" counter.
-- Masking (not revealing WHICH ones) happens by simply not listing them
-- anywhere the client can read — this is just a count.
function FusionRecipes.GetSecretProgress(discovered)
	discovered = discovered or {}
	local found = 0
	for _, r in ipairs(SECRET_LIST) do
		if discovered[r[3]] then
			found = found + 1
		end
	end
	return found, #SECRET_LIST
end

function FusionRecipes.IsSecretResult(name)
	for _, r in ipairs(SECRET_LIST) do
		if r[3] == name then
			return true
		end
	end
	return false
end

-- Every REAL item in this line — base scrap plus every curated result,
-- secrets included as masked rows — for the item index. Deliberately
-- excludes fallback hybrids: those aren't part of the collection to hunt
-- for, same as they're excluded from discoveries/goals. Only the final
-- name is exposed — the index is a collection list, not a recipe book,
-- so ingredients never leave the server.
function FusionRecipes.GetIndex(discovered)
	discovered = discovered or {}
	local items = {}

	for _, base in ipairs(FusionRecipes.BaseItems) do
		table.insert(items, { name = base.name, tier = 1, isSecret = false, isBase = true, known = true })
	end

	local function addResult(r, isSecret)
		local known = discovered[r[3]] == true
		table.insert(items, {
			name     = known and r[3] or "???",
			tier     = r[4],
			isSecret = isSecret,
			isBase   = false,
			known    = known,
		})
	end

	for _, r in ipairs(RECIPE_LIST) do addResult(r, false) end
	for _, r in ipairs(SECRET_LIST) do addResult(r, true) end

	table.sort(items, function(x, y)
		if x.tier ~= y.tier then return x.tier < y.tier end
		if x.isSecret ~= y.isSecret then return not x.isSecret end
		return x.name < y.name
	end)

	return items
end

return FusionRecipes
