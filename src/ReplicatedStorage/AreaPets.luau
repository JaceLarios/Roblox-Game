--[[
	AreaPets (ModuleScript, ReplicatedStorage) — Junkyard Fusion v1

	Every area (Junkyard, Brainrot Island, Haunted Hollow) gets its own 3
	Robux eggs — Okay/Good/Great, each 4 regular pets plus 1 secret pet
	(5 total, same 50/25/15/9/1 weighting SecretPets.luau's own 5-pet egg
	already established). Unlike SecretPets, these pets aren't fusable
	inventory items at all — owning one is a permanent, stacking coin and
	speed multiplier (see TotalCoinMultiplier/TotalSpeedMultiplier), the
	rarer the pet the bigger its own multiplier. Names are all TBD
	placeholders — concepts/models are Codex's to design, same split as
	every other pet system in this game.

	Generated from one shared tier template per area rather than 45
	hand-written entries, since the three areas share the exact same
	weight/multiplier curve and differ only in which area owns the egg.
--]]

local AreaPets = {}

local AREA_LABELS = { junkyard = "Junkyard", brainrot = "Brainrot", haunted = "Haunted" }
AreaPets.AreaKeys = { "junkyard", "brainrot", "haunted" }

-- 4 regular pets' weights, ordered common -> rare (secret is always a
-- flat 1, same as SecretPets' own rarest tier) — summing to 100 so
-- weight doubles as the literal percent chance, no rounding involved.
local WEIGHTS = { 50, 25, 15, 9 }

-- Multipliers scale with BOTH egg tier (okay < good < great) and rarity
-- within an egg (pet 1 -> 4 gets rarer/bigger) — placeholder numbers
-- like every other economy constant this session, easy to retune here.
local TIERS = {
	{
		key = "okay", tier = 1, label = "Okay",
		coinMults = { 1.05, 1.12, 1.18, 1.25 }, speedMults = { 1.02, 1.03, 1.05, 1.06 },
		secretCoin = 1.40, secretSpeed = 1.10,
	},
	{
		key = "good", tier = 2, label = "Good",
		coinMults = { 1.30, 1.40, 1.50, 1.60 }, speedMults = { 1.08, 1.10, 1.12, 1.14 },
		secretCoin = 1.80, secretSpeed = 1.20,
	},
	{
		key = "great", tier = 3, label = "Great",
		coinMults = { 1.65, 1.80, 1.95, 2.10 }, speedMults = { 1.16, 1.19, 1.22, 1.25 },
		secretCoin = 2.50, secretSpeed = 1.35,
	},
}

AreaPets.Areas = {}

-- Flat key -> pet lookup across every area/egg, built once below —
-- what TotalCoinMultiplier/TotalSpeedMultiplier read an owned-pet-key
-- set against, and what a future shop UI would use to show a specific
-- pet's stats without walking the whole nested Areas table.
local petByKey = {}

for _, areaKey in ipairs(AreaPets.AreaKeys) do
	local areaLabel = AREA_LABELS[areaKey]
	local eggs = {}

	for _, t in ipairs(TIERS) do
		local pets = {}

		for i = 1, 4 do
			local pet = {
				key = string.format("%s_%s_%d", areaKey, t.key, i),
				name = string.format("TBD %s %s Pet %d", areaLabel, t.label, i),
				coinMult = t.coinMults[i],
				speedMult = t.speedMults[i],
				weight = WEIGHTS[i],
				secret = false,
			}
			table.insert(pets, pet)
			petByKey[pet.key] = pet
		end

		local secretPet = {
			key = string.format("%s_%s_secret", areaKey, t.key),
			name = string.format("TBD %s %s Secret Pet", areaLabel, t.label),
			coinMult = t.secretCoin,
			speedMult = t.secretSpeed,
			weight = 1,
			secret = true,
		}
		table.insert(pets, secretPet)
		petByKey[secretPet.key] = secretPet

		table.insert(eggs, {
			key = t.key,
			tier = t.tier,
			name = string.format("%s %s Egg", areaLabel, t.label),
			-- Placeholder like every other Developer Product this session
			-- (SecretPets.EggProductId, GamepassConfig.StarterPack.id) —
			-- Roblox product ids are always positive, so FindEgg below
			-- never matches 0 regardless of how many eggs still share it.
			productId = 0,
			pets = pets,
		})
	end

	AreaPets.Areas[areaKey] = { eggs = eggs }
end

function AreaPets.GetEgg(areaKey, eggKey)
	local area = AreaPets.Areas[areaKey]
	if not area then return nil end
	for _, egg in ipairs(area.eggs) do
		if egg.key == eggKey then return egg end
	end
	return nil
end

-- Linear scan over at most 9 eggs — fine at this size, and the
-- productId <= 0 guard means placeholder eggs sharing 0 can never
-- ambiguously match each other or a stray real call with a bad id.
function AreaPets.FindEgg(productId)
	if type(productId) ~= "number" or productId <= 0 then return nil end
	for _, areaKey in ipairs(AreaPets.AreaKeys) do
		for _, egg in ipairs(AreaPets.Areas[areaKey].eggs) do
			if egg.productId == productId then return areaKey, egg end
		end
	end
	return nil
end

function AreaPets.GetPet(petKey)
	return petByKey[petKey]
end

-- Weighted pick, same shape as SecretPets.Roll/BrainrotRecipes.RollBaseItem.
function AreaPets.Roll(areaKey, eggKey)
	local egg = AreaPets.GetEgg(areaKey, eggKey)
	if not egg then return nil end

	local total = 0
	for _, pet in ipairs(egg.pets) do total += pet.weight end

	local roll = math.random() * total
	local running = 0
	for _, pet in ipairs(egg.pets) do
		running += pet.weight
		if roll <= running then return pet end
	end
	return egg.pets[1]
end

-- {name, percent} per pet — Roblox requires disclosing randomized-purchase
-- odds before buying, same reason SecretPets.Odds exists.
function AreaPets.Odds(areaKey, eggKey)
	local egg = AreaPets.GetEgg(areaKey, eggKey)
	if not egg then return {} end

	local total = 0
	for _, pet in ipairs(egg.pets) do total += pet.weight end

	local odds = {}
	for _, pet in ipairs(egg.pets) do
		table.insert(odds, { name = pet.name, percent = (pet.weight / total) * 100 })
	end
	return odds
end

-- Additive percentage stacking — same model GamepassService.Coins already
-- uses ("+15% StarterPack stacks on top of whatever DoubleCoins already
-- gives"), not multiplicative chaining, so owning many pets grows your
-- bonus linearly rather than exploding combinatorially.
function AreaPets.TotalCoinMultiplier(ownedSet)
	local mult = 1
	for petKey in pairs(ownedSet or {}) do
		local pet = petByKey[petKey]
		if pet then mult += (pet.coinMult - 1) end
	end
	return mult
end

function AreaPets.TotalSpeedMultiplier(ownedSet)
	local mult = 1
	for petKey in pairs(ownedSet or {}) do
		local pet = petByKey[petKey]
		if pet then mult += (pet.speedMult - 1) end
	end
	return mult
end

return AreaPets
