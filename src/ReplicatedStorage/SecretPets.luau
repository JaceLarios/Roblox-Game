--[[
	SecretPets (ModuleScript, ReplicatedStorage) — Junkyard Fusion

	A single Robux egg (SecretPets.EggProductId, one Developer Product)
	that rolls one of the 5 pets below, weighted so the better the pet,
	the harder it is to get — same weighted-random shape as
	FusionRecipes.RollBaseItem, just over this separate list. Two hard
	rules the rest of the codebase enforces around whatever lives here
	(see PlotManager.server.luau: itemTierInfo, canReceiveTradedItem,
	attemptFusion, and the ProcessReceipt handler):
	  1. Never fusable — can't be carried to a pad, in or out, so they can
	     never be an ingredient, and since they're not in FusionRecipes or
	     BrainrotRecipes at all, they can never be a fusion result either.
	  2. Every outcome is still worth more than the best fusion result
	     (FusionRecipes.SecretValue, 50000) — even the "common" pull from
	     this egg should feel like a real win, not a consolation prize.

	Replaces the old direct-buy version of this file (one Developer
	Product per pet) — the user wants an egg instead: one purchase, 5
	possible pets, odds shown before you buy. Roblox requires disclosing
	the odds of a randomized paid item — SecretPets.Odds() below exists
	specifically so Codex's purchase UI has a ready-made source for that,
	rather than needing to duplicate the weight math.

	EVERYTHING below is a placeholder, on purpose:
	  - `name` — TBD per pet. Needs an actual concept ("something crazy,
	    entirely different from anything in the game, designed from
	    scratch, not a generic asset" per the user) — that's a
	    Codex/design question, not a Claude one. Don't ship a name
	    invented here as if it were final.
	  - `EggProductId = 0` — a real Developer Product doesn't exist yet.
	    Create ONE on the Roblox Creator Dashboard (the egg itself — there
	    is only one product regardless of how many pets are in the list)
	    and drop the real numeric id in here (same "id = 0 means not
	    configured yet" convention already used by GamepassConfig.luau).
	  - `value`/`weight` — reasonable starting numbers, not balanced final
	    ones. Tune freely; they don't need to keep summing to anything in
	    particular.

	Add or remove pets freely; nothing else needs to change to support a
	6th, a 7th, etc. — everything that reads this list (itemTierInfo, the
	Shop UI once Codex builds it, Roll, Odds, ProcessReceipt) is generic
	over however many entries are here.
--]]

local SecretPets = { List = {} }

SecretPets.EggProductId = 0

-- weight is relative, not a percentage — Odds() below turns these into
-- real percentages. Higher value = lower weight = harder to get.
table.insert(SecretPets.List, { key = "secret_pet_1", name = "TBD Secret Pet 1", value = 70000,  weight = 50 })
table.insert(SecretPets.List, { key = "secret_pet_2", name = "TBD Secret Pet 2", value = 95000,  weight = 25 })
table.insert(SecretPets.List, { key = "secret_pet_3", name = "TBD Secret Pet 3", value = 125000, weight = 15 })
table.insert(SecretPets.List, { key = "secret_pet_4", name = "TBD Secret Pet 4", value = 160000, weight = 7 })
table.insert(SecretPets.List, { key = "secret_pet_5", name = "TBD Secret Pet 5", value = 200000, weight = 3 })

SecretPets.ByName = {}
for _, entry in ipairs(SecretPets.List) do
	SecretPets.ByName[entry.name] = entry
end

function SecretPets.IsConfigured()
	return type(SecretPets.EggProductId) == "number" and SecretPets.EggProductId > 0 and SecretPets.EggProductId % 1 == 0
end

-- Same shape as FusionRecipes.RollBaseItem: sum the weights, pick a
-- random point along that total, walk the list until it's covered.
function SecretPets.Roll()
	local total = 0
	for _, entry in ipairs(SecretPets.List) do
		total = total + entry.weight
	end

	local roll = math.random() * total
	local running = 0

	for _, entry in ipairs(SecretPets.List) do
		running = running + entry.weight
		if roll <= running then
			return entry
		end
	end

	return SecretPets.List[1]
end

-- {name, value, percent} per pet, for a purchase UI to disclose odds
-- with — required by Roblox for any randomized paid item, not just good
-- practice. percent is rounded to 1 decimal; the raw weights above are
-- the source of truth if the two ever look inconsistent.
function SecretPets.Odds()
	local total = 0
	for _, entry in ipairs(SecretPets.List) do
		total = total + entry.weight
	end

	local odds = {}
	for _, entry in ipairs(SecretPets.List) do
		table.insert(odds, {
			name = entry.name,
			value = entry.value,
			percent = math.floor((entry.weight / total) * 1000 + 0.5) / 10,
		})
	end
	return odds
end

return SecretPets
