--[[
	BrainrotRecipes (ModuleScript, ReplicatedStorage) — Junkyard Fusion v1
	Recipe data + lookup for the Brainrot Island item line. Mirrors
	FusionRecipes' shape (same API surface) but is a fully separate item
	namespace — original creatures, not the viral meme characters.

	Second creature roster (first was all food+animal hybrids — "more
	brainrot" meant chasing the wilder object+animal mashups the actual
	meme leans on: instruments, appliances, vehicles, fused onto animals).
--]]

local BrainrotRecipes = {}

-- TIER 1: what the island's spawner drops. Higher weight = more common.
BrainrotRecipes.BaseItems = {
	{ name = "Trattorino Rexini",        weight = 100, value = 5 },
	{ name = "Saxofonio Serpentoni",     weight = 90,  value = 7 },
	{ name = "Frigorino Gattelli",       weight = 75,  value = 10 },
	{ name = "Chitarrino Lupini",        weight = 60,  value = 14 },
	{ name = "Elicottero Ranini",        weight = 45,  value = 20 },
	{ name = "Bombardino Squalini",      weight = 32,  value = 28 },
	{ name = "Aspirapolvere Coccodrilli", weight = 20, value = 40 },
	{ name = "Panino Orsetti",           weight = 12,  value = 60 },
	{ name = "Ombrellino Pinguini",      weight = 6,   value = 90 },
	{ name = "Trombetta Elefantini",     weight = 3,   value = 150 },
}

BrainrotRecipes.TierValue = {
	[2] = 250,
	[3] = 2000,
	[4] = 15000,
}

BrainrotRecipes.SecretValue = 50000

-- { ingredientA, ingredientB, result, tier } — order does not matter.
local RECIPE_LIST = {
	-- Tier 2
	{ "Trattorino Rexini",   "Saxofonio Serpentoni",      "Jazzosauro Furioso", 2 },
	{ "Frigorino Gattelli",  "Chitarrino Lupini",         "Rockabilly Gelato",  2 },
	{ "Elicottero Ranini",   "Bombardino Squalini",       "Squalo Volante",     2 },
	{ "Aspirapolvere Coccodrilli", "Panino Orsetti",      "Panzer Panino",      2 },
	{ "Ombrellino Pinguini", "Trombetta Elefantini",      "Fanfara Glaciale",   2 },
	{ "Trattorino Rexini",   "Frigorino Gattelli",        "Gelato Rex",         2 },

	-- Tier 3
	{ "Jazzosauro Furioso", "Squalo Volante",  "Sinfonia Apocalittica", 3 },
	{ "Rockabilly Gelato",  "Panzer Panino",   "Bistecca Boogaloo",     3 },
	{ "Fanfara Glaciale",   "Gelato Rex",      "Orchestra Glaciale",    3 },

	-- Tier 4
	{ "Sinfonia Apocalittica", "Bistecca Boogaloo", "IL BRAINROT SUPREMO", 4 },
}

-- Secrets: same-item fusions, so players can't stumble into them.
local SECRET_LIST = {
	{ "Panino Orsetti",       "Panino Orsetti",       "Panino Colossale",        3 },
	{ "Trombetta Elefantini", "Trombetta Elefantini", "Elefantissimo Imperiale", 3 },
}

-- Key = the two names sorted alphabetically and joined with "|".
local function makeKey(a, b)
	if a <= b then
		return a .. "|" .. b
	else
		return b .. "|" .. a
	end
end

BrainrotRecipes.MakeKey = makeKey

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

BrainrotRecipes.FallbackValue = {}
for tier, tierValue in pairs(BrainrotRecipes.TierValue) do
	BrainrotRecipes.FallbackValue[tier] = math.floor(tierValue * 0.35)
end

local FALLBACK_NAMES = {
	[2] = { "Scraprino Mutantelli", "Feralino Snacktoni", "Bentaccio Wobblini" },
	[3] = { "Chaosaurus Blobbini", "Titanello Munchzilla", "Ferocibro Chompanini" },
	[4] = { "Colosso Fallimento", "Disastro Totale", "Catastrofe Suprema" },
}

local nameTier = {}
for _, item in ipairs(BrainrotRecipes.BaseItems) do
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
function BrainrotRecipes.Fuse(itemA, itemB)
	if type(itemA) ~= "string" or type(itemB) ~= "string" then
		warn("[Brainrot] Fuse() needs two item names as strings.")
		return nil
	end

	local entry = lookup[makeKey(itemA, itemB)]
	if entry then
		local value = BrainrotRecipes.TierValue[entry.tier] or 0
		if entry.isSecret then
			value = BrainrotRecipes.SecretValue
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
		value      = BrainrotRecipes.FallbackValue[resultTier] or 0,
	}
end

function BrainrotRecipes.GetValue(itemName)
	for _, base in ipairs(BrainrotRecipes.BaseItems) do
		if base.name == itemName then
			return base.value
		end
	end

	for _, entry in pairs(lookup) do
		if entry.result == itemName then
			if entry.isSecret then
				return BrainrotRecipes.SecretValue
			end
			return BrainrotRecipes.TierValue[entry.tier] or 0
		end
	end

	if fallbackNameSet[itemName] then
		return BrainrotRecipes.FallbackValue[nameTier[itemName]] or 0
	end

	return 0
end

function BrainrotRecipes.IsFallbackResult(name)
	return fallbackNameSet[name] == true
end

function BrainrotRecipes.GetTier(name)
	return nameTier[name] or 1
end

-- Roll a random Tier 1 item using the weights above.
function BrainrotRecipes.RollBaseItem()
	local total = 0
	for _, item in ipairs(BrainrotRecipes.BaseItems) do
		total = total + item.weight
	end

	local roll = math.random() * total
	local running = 0

	for _, item in ipairs(BrainrotRecipes.BaseItems) do
		running = running + item.weight
		if roll <= running then
			return item.name
		end
	end

	return BrainrotRecipes.BaseItems[1].name
end

function BrainrotRecipes.GetTotalDiscoveries()
	local count = 0
	for _ in pairs(lookup) do
		count = count + 1
	end
	return count
end

function BrainrotRecipes.IsSecretResult(name)
	for _, r in ipairs(SECRET_LIST) do
		if r[3] == name then
			return true
		end
	end
	return false
end

-- Mirrors FusionRecipes.GetIndex — every real creature, secrets included
-- as masked rows, fallback hybrids excluded. Only the final name is
-- exposed — the index is a collection list, not a recipe book.
function BrainrotRecipes.GetIndex(discovered)
	discovered = discovered or {}
	local items = {}

	for _, base in ipairs(BrainrotRecipes.BaseItems) do
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

return BrainrotRecipes
