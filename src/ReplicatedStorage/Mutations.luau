local ItemNames = require(game:GetService("ReplicatedStorage"):WaitForChild("ItemNames"))
--[[
	Mutations (ModuleScript, ReplicatedStorage) — Junkyard Fusion v1

	A second, tier-independent rarity layer rolled on fusion results. Any
	fused item, common or rare, can additionally come out
	Shiny/Toxic/Golden/Cosmic, each a flat value multiplier and
	its own glow color, so items stay worth re-fusing long after a player
	has 100%'d the Index.

	A mutated instance is identified by wrapping its base result name in
	brackets: "[Shiny] Rusted Sedan". Every recipe/visual lookup always
	needs the UNWRAPPED base name — mutations are a value/display layer on
	top, never a new recipe or a separate Index entry — so Unwrap() must
	run before calling into FusionRecipes/ItemVisuals.
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local EventConfig = require(ReplicatedStorage:WaitForChild("EventConfig"))

local Mutations = {}

-- Checked in this (rarest-first) order, each an independent roll — cosmic
-- being checked first means it can never also register as a lower tier.
local TIERS = {
	{ id = "cosmic", name = "Cosmic", color = Color3.fromRGB(230, 110, 255), chance = 1 / 2000, multiplier = 20 },
	{ id = "golden", name = "Golden", color = Color3.fromRGB(255, 205, 40),  chance = 1 / 300,   multiplier = 8 },
	{ id = "toxic",  name = "Toxic",  color = Color3.fromRGB(120, 255, 90),  chance = 1 / 75,    multiplier = 4 },
	{ id = "shiny",  name = "Shiny",  color = Color3.fromRGB(220, 235, 245), chance = 1 / 20,    multiplier = 2 },
}

-- Only rollable while EventConfig.IsActive() — see Roll() below. Still
-- registered in the same BY_ID/BY_NAME_LOWER lookup tables as the regular
-- tiers so an already-fused Frenzy item keeps unwrapping/rendering
-- correctly forever, even after the event that produced it has ended.
local EVENT_TIER = { id = "frenzy", name = "Frenzy", color = Color3.fromRGB(255, 60, 60), chance = 1 / 40, multiplier = 25 }

local BY_ID = {}
local BY_NAME_LOWER = {}
for _, tier in ipairs(TIERS) do
	BY_ID[tier.id] = tier
	BY_NAME_LOWER[tier.name:lower()] = tier
end
BY_ID[EVENT_TIER.id] = EVENT_TIER
BY_NAME_LOWER[EVENT_TIER.name:lower()] = EVENT_TIER

-- After this many fusions with no mutation at all, the next one is
-- guaranteed at least Shiny. Resets to 0 the moment any mutation lands.
Mutations.PITY_LIMIT = 150

-- luckLevel: the player's Lucky Wrench level (1 = no bonus, matching every
-- other luck-scaled roll in this game). Nudges mutation odds up a little
-- so upgrading luck keeps paying off even after a player stops caring
-- about the base-scrap-upgrade roll it was originally bought for.
function Mutations.Roll(luckLevel, pityCount)
	local luckBonus = 1 + math.max(0, (luckLevel or 1) - 1) * 0.05
	local eventActive = EventConfig.IsActive()
	local eventMult = eventActive and EventConfig.MUTATION_CHANCE_MULT or 1

	if eventActive and math.random() < EVENT_TIER.chance * luckBonus * eventMult then
		return EVENT_TIER.id
	end

	for _, tier in ipairs(TIERS) do
		if math.random() < tier.chance * luckBonus * eventMult then
			return tier.id
		end
	end

	if pityCount and pityCount >= Mutations.PITY_LIMIT then
		return "shiny"
	end

	return nil
end

function Mutations.EventActive()
	return EventConfig.IsActive()
end

-- "Rusted Sedan" + "shiny" -> "[Shiny] Rusted Sedan". Passing a nil/unknown
-- mutationId hands the base name back unchanged.
function Mutations.Wrap(baseName, mutationId)
	local tier = mutationId and BY_ID[mutationId]
	if not tier then return baseName end
	return string.format("[%s] %s", tier.name, baseName)
end

-- Returns baseName, mutationId — mutationId is nil for a plain name, and a
-- plain name is handed back untouched.
function Mutations.Unwrap(name)
	if type(name) ~= "string" then return name, nil end
	local bracket, rest = name:match("^%[(%a+)%]%s(.+)$")
	local tier = bracket and BY_NAME_LOWER[bracket:lower()]
	if tier then
		return rest, tier.id
	end
	return name, nil
end

function Mutations.IsMutated(name)
	local _, mutationId = Mutations.Unwrap(name)
	return mutationId ~= nil
end

function Mutations.ValueMultiplier(mutationId)
	local tier = mutationId and BY_ID[mutationId]
	return tier and tier.multiplier or 1
end

function Mutations.Color(mutationId)
	local tier = mutationId and BY_ID[mutationId]
	return tier and tier.color or nil
end

-- Rich-text tag for a (possibly mutated) display name. Mutation color takes
-- over from whatever rarity color the caller would otherwise use — it's
-- the more exciting signal in that moment. Callers with a plain name should
-- fall back to ItemRarity.Tag themselves; this only ever colors mutations.
function Mutations.Tag(displayName, mutationId)
	displayName = ItemNames.Display(displayName)
	local tier = mutationId and BY_ID[mutationId]
	if not tier then return displayName end
	return string.format('<font color="%s">%s</font>', "#" .. tier.color:ToHex(), displayName)
end

return Mutations
