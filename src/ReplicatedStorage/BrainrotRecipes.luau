--[[
	BrainrotRecipes (ModuleScript, ReplicatedStorage) — Junkyard Fusion v1
	Recipe data + lookup for the Brainrot Island item line. Mirrors
	FusionRecipes' shape (same API surface) but is a fully separate item
	namespace — original creatures, not the viral meme characters.
--]]

local BrainrotRecipes = {}

-- TIER 1: what the island's spawner drops. Higher weight = more common.
BrainrotRecipes.BaseItems = {
	{ name = "Waffronio Pigeonelli",   weight = 100, value = 5 },
	{ name = "Spaghettuccio Wormanini",weight = 100, value = 5 },
	{ name = "Toastarino Frogolini",   weight = 90,  value = 6 },
	{ name = "Pretzeletto Owlbini",    weight = 70,  value = 9 },
	{ name = "Meatballo Snailini",     weight = 55,  value = 14 },
	{ name = "Croissantino Batusso",   weight = 40,  value = 20 },
	{ name = "Donutello Sharkanini",   weight = 25,  value = 35 },
	{ name = "Espressimo Direwolfini", weight = 8,   value = 120 },
}

BrainrotRecipes.TierValue = {
	[2] = 250,
	[3] = 2000,
}

BrainrotRecipes.SecretValue = 50000

-- { ingredientA, ingredientB, result, tier } — order does not matter.
local RECIPE_LIST = {
	-- Tier 2
	{ "Waffronio Pigeonelli",    "Espressimo Direwolfini", "Turbowaffle Espressoni", 2 },
	{ "Spaghettuccio Wormanini", "Meatballo Snailini",     "Spagmeato Chaosini",     2 },
	{ "Pretzeletto Owlbini",     "Croissantino Batusso",   "Pretzoissant Skyterror", 2 },
	{ "Toastarino Frogolini",    "Donutello Sharkanini",   "Toastdonut Frenzicane",  2 },

	-- Tier 3
	{ "Turbowaffle Espressoni", "Spagmeato Chaosini", "OMEGA BRAINO REX", 3 },
}

-- Secrets: same-item fusions, so players can't stumble into them.
local SECRET_LIST = {
	{ "Meatballo Snailini", "Meatballo Snailini", "Meatballzilla Supremo", 3 },
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

-- Returns resultName, infoTable — or nil if there is no recipe.
function BrainrotRecipes.Fuse(itemA, itemB)
	if type(itemA) ~= "string" or type(itemB) ~= "string" then
		warn("[Brainrot] Fuse() needs two item names as strings.")
		return nil
	end

	local entry = lookup[makeKey(itemA, itemB)]
	if not entry then
		return nil
	end

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

	return 0
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

return BrainrotRecipes
