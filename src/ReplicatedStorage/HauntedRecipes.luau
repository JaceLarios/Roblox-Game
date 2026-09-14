--[[
	HauntedRecipes (ModuleScript, ReplicatedStorage) — Junkyard Fusion v1
	Recipe data + lookup for Haunted Hollow's item line. Mirrors
	FusionRecipes/BrainrotRecipes' shape (same API surface) but is a fully
	separate item namespace — graveyard junk fusing into ghosts and
	spirits, not vehicles or brainrot creatures.

	Third creature roster, added 2026-09-14 alongside Haunted Hollow
	itself. Same "junk fuses into something better" loop as the other two
	islands, themed to a cursed graveyard instead of scrap metal or
	surreal meme mashups.
--]]

local HauntedRecipes = {}

-- TIER 1: what the island's spawner drops. Higher weight = more common.
HauntedRecipes.BaseItems = {
	{ name = "Rusty Chain",         weight = 100, value = 5 },
	{ name = "Cracked Tombstone",   weight = 90,  value = 7 },
	{ name = "Broken Lantern",      weight = 75,  value = 10 },
	{ name = "Tattered Shroud",     weight = 60,  value = 14 },
	{ name = "Skeleton Key",        weight = 45,  value = 20 },
	{ name = "Withered Wreath",     weight = 32,  value = 28 },
	{ name = "Ouija Board Shard",   weight = 20,  value = 40 },
	{ name = "Cursed Candle",       weight = 12,  value = 60 },
	{ name = "Shattered Mirror",    weight = 6,   value = 90 },
	{ name = "Grave Dirt Urn",      weight = 3,   value = 150 },
}

HauntedRecipes.TierValue = {
	[2] = 250,
	[3] = 2000,
	[4] = 15000,
}

HauntedRecipes.SecretValue = 50000

-- { ingredientA, ingredientB, result, tier } — order does not matter.
local RECIPE_LIST = {
	-- Tier 2
	{ "Rusty Chain",       "Cracked Tombstone", "Chained Wraith",       2 },
	{ "Broken Lantern",    "Tattered Shroud",   "Lantern Ghoul",        2 },
	{ "Skeleton Key",      "Withered Wreath",   "Bone Keeper",          2 },
	{ "Ouija Board Shard", "Cursed Candle",     "Whispering Specter",   2 },
	{ "Shattered Mirror",  "Grave Dirt Urn",    "Mirror Phantom",       2 },
	{ "Rusty Chain",       "Broken Lantern",    "Rattling Poltergeist", 2 },

	-- Tier 3
	{ "Chained Wraith", "Lantern Ghoul",        "Hollow Banshee", 3 },
	{ "Bone Keeper",    "Whispering Specter",   "Crypt Warden",   3 },
	{ "Mirror Phantom", "Rattling Poltergeist", "Shadow Reaper",  3 },

	-- Tier 4
	{ "Hollow Banshee", "Crypt Warden", "THE ETERNAL DREAD", 4 },
}

-- Secrets: same-item fusions, so players can't stumble into them.
local SECRET_LIST = {
	{ "Cursed Candle",    "Cursed Candle",    "Candle of a Thousand Souls", 3 },
	{ "Shattered Mirror", "Shattered Mirror", "Mirror World Wraith",        3 },
}

-- Key = the two names sorted alphabetically and joined with "|".
local function makeKey(a, b)
	if a <= b then
		return a .. "|" .. b
	else
		return b .. "|" .. a
	end
end

HauntedRecipes.MakeKey = makeKey

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
-- hunting down actual recipes stays the better move. Mirrors FusionRecipes.
local MAX_FALLBACK_TIER = 4

HauntedRecipes.FallbackValue = {}
for tier, tierValue in pairs(HauntedRecipes.TierValue) do
	HauntedRecipes.FallbackValue[tier] = math.floor(tierValue * 0.35)
end

local FALLBACK_NAMES = {
	[2] = { "Restless Husk", "Wailing Remnant", "Grave Shade" },
	[3] = { "Cursed Revenant", "Nightmare Wisp", "Sorrow Golem" },
	[4] = { "Apocalyptic Haunt", "Doom Specter", "Endless Nightmare" },
}

local nameTier = {}
for _, item in ipairs(HauntedRecipes.BaseItems) do
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
function HauntedRecipes.Fuse(itemA, itemB)
	if type(itemA) ~= "string" or type(itemB) ~= "string" then
		warn("[Haunted] Fuse() needs two item names as strings.")
		return nil
	end

	local entry = lookup[makeKey(itemA, itemB)]
	if entry then
		local value = HauntedRecipes.TierValue[entry.tier] or 0
		if entry.isSecret then
			value = HauntedRecipes.SecretValue
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
		value      = HauntedRecipes.FallbackValue[resultTier] or 0,
	}
end

function HauntedRecipes.GetValue(itemName)
	for _, base in ipairs(HauntedRecipes.BaseItems) do
		if base.name == itemName then
			return base.value
		end
	end

	for _, entry in pairs(lookup) do
		if entry.result == itemName then
			if entry.isSecret then
				return HauntedRecipes.SecretValue
			end
			return HauntedRecipes.TierValue[entry.tier] or 0
		end
	end

	if fallbackNameSet[itemName] then
		return HauntedRecipes.FallbackValue[nameTier[itemName]] or 0
	end

	return 0
end

function HauntedRecipes.IsFallbackResult(name)
	return fallbackNameSet[name] == true
end

function HauntedRecipes.GetTier(name)
	return nameTier[name] or 1
end

-- Roll a random Tier 1 item using the weights above.
function HauntedRecipes.RollBaseItem()
	local total = 0
	for _, item in ipairs(HauntedRecipes.BaseItems) do
		total = total + item.weight
	end

	local roll = math.random() * total
	local running = 0

	for _, item in ipairs(HauntedRecipes.BaseItems) do
		running = running + item.weight
		if roll <= running then
			return item.name
		end
	end

	return HauntedRecipes.BaseItems[1].name
end

function HauntedRecipes.GetTotalDiscoveries()
	local count = 0
	for _ in pairs(lookup) do
		count = count + 1
	end
	return count
end

function HauntedRecipes.IsSecretResult(name)
	for _, r in ipairs(SECRET_LIST) do
		if r[3] == name then
			return true
		end
	end
	return false
end

-- Mirrors FusionRecipes.GetIndex/BrainrotRecipes.GetIndex — every real
-- creature, secrets included as masked rows, fallback hybrids excluded.
-- Only the final name is exposed — the index is a collection list, not a
-- recipe book.
function HauntedRecipes.GetIndex(discovered)
	discovered = discovered or {}
	local items = {}

	for _, base in ipairs(HauntedRecipes.BaseItems) do
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

return HauntedRecipes
