--[[
	SecretPets (ModuleScript, ReplicatedStorage) — Junkyard Fusion

	A single Robux egg (SecretPets.EggProductId, one Developer Product)
	that rolls one of the 5 egg pets below, weighted so the better the
	pet, the harder it is to get — same weighted-random shape as
	FusionRecipes.RollBaseItem, just over this separate list. Two hard
	rules the rest of the codebase enforces around every entry in this
	file, egg pets and the streak pet alike (see PlotManager.server.luau:
	itemTierInfo, canReceiveTradedItem, attemptFusion, and the
	ProcessReceipt handler):
	  1. Never fusable — can't be carried to a pad, in or out, so they can
	     never be an ingredient, and since they're not in FusionRecipes or
	     BrainrotRecipes at all, they can never be a fusion result either.
	  2. Every outcome is still worth more than the best fusion result
	     (FusionRecipes.SecretValue, 50000) — even the "common" pull from
	     this egg should feel like a real win, not a consolation prize.

	A 6th entry, StreakPet, is a Day-7-daily-streak reward, not part of
	the egg at all — granted once by PlotManager.server.luau's Day 7
	jackpot (see DAILY_REWARDS/grantReward there), never purchasable.
	It lives in this same List/ByName so it automatically inherits rule 1
	above (un-fusable) and correct itemTierInfo valuation, but two flags
	keep it out of the egg's own mechanics: `streakOnly = true` excludes
	it from Roll()/Odds() (it must never be a possible or disclosed egg
	outcome), and `untradeable = true` blocks it from being received via
	a player-to-player inventory trade (see canReceiveTradedItem) — the
	user's ask was specifically "a secret pet you can only get for
	playing the game for 7 days," which a tradeable/giftable pet would
	break.

	A 7th entry, PackPet, is the same idea for the Robux "Starter Pack"
	gamepass (see GamepassConfig.luau + PlotManager.server.luau's
	Gamepasses.Changed listener) — "a semi-good pet you can only get from
	the pack," so it gets the exact same `packOnly`/`untradeable`
	treatment as StreakPet, just excluded for a different reason. Sits
	deliberately below every egg pet's value: a cheap starter purchase
	shouldn't outshine what buying the actual egg gets you.

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
-- real percentages. Higher value = lower weight = harder to get. These
-- five weights deliberately sum to 100, so weight and percent are the
-- same number — Secret Pet 5, the best, sits at a hard-required 1%.
table.insert(SecretPets.List, { key = "secret_pet_1", name = "TBD Secret Pet 1", value = 70000,  weight = 55 })
table.insert(SecretPets.List, { key = "secret_pet_2", name = "TBD Secret Pet 2", value = 95000,  weight = 25 })
table.insert(SecretPets.List, { key = "secret_pet_3", name = "TBD Secret Pet 3", value = 125000, weight = 12 })
table.insert(SecretPets.List, { key = "secret_pet_4", name = "TBD Secret Pet 4", value = 160000, weight = 7 })
table.insert(SecretPets.List, { key = "secret_pet_5", name = "TBD Secret Pet 5", value = 200000, weight = 1 })

-- The Day-7 streak reward — no weight, since streakOnly keeps it out of
-- the weighted pool entirely (Roll()/Odds() below skip it on purpose).
-- Value is a placeholder like everything else here: comfortably above
-- the fusion best (50000) and above most egg pets, but below the egg's
-- rarest pull (200000) — the paid egg's jackpot stays the single best
-- item in the game, and this free 7-day pet is the clear second-best.
local streakPet = { key = "streak_pet_1", name = "TBD 7-Day Pet", value = 150000, streakOnly = true, untradeable = true }
table.insert(SecretPets.List, streakPet)
SecretPets.StreakPet = streakPet

-- The Starter Pack's exclusive pet — below every egg pet's value (60000
-- vs. the egg's 70000-200000 range) but still above the fusion best
-- (50000), so it's a genuine, if modest, secret pet rather than a
-- reskinned common item.
local packPet = { key = "pack_pet_1", name = "TBD Starter Pack Pet", value = 60000, packOnly = true, untradeable = true }
table.insert(SecretPets.List, packPet)
SecretPets.PackPet = packPet

SecretPets.ByName = {}
for _, entry in ipairs(SecretPets.List) do
	SecretPets.ByName[entry.name] = entry
end

function SecretPets.IsConfigured()
	return type(SecretPets.EggProductId) == "number" and SecretPets.EggProductId > 0 and SecretPets.EggProductId % 1 == 0
end

-- Anything the egg's own Roll()/Odds() should never touch — currently
-- the streak pet and the Starter Pack pet, each excluded for its own
-- reason (see the flags themselves). Centralized here so Roll/Odds don't
-- have to know each flag by name, and a future non-egg pet only needs
-- its own new flag added to this one check.
local function eggEligible(entry)
	return not entry.streakOnly and not entry.packOnly
end

-- Same shape as FusionRecipes.RollBaseItem: sum the weights, pick a
-- random point along that total, walk the list until it's covered.
function SecretPets.Roll()
	local total = 0
	for _, entry in ipairs(SecretPets.List) do
		if eggEligible(entry) then
			total = total + entry.weight
		end
	end

	local roll = math.random() * total
	local running = 0

	for _, entry in ipairs(SecretPets.List) do
		if eggEligible(entry) then
			running = running + entry.weight
			if roll <= running then
				return entry
			end
		end
	end

	return SecretPets.List[1]
end

-- {name, value, percent} per pet, for a purchase UI to disclose odds
-- with — required by Roblox for any randomized paid item, not just good
-- practice. percent is rounded to 1 decimal; the raw weights above are
-- the source of truth if the two ever look inconsistent. Disclosing
-- "odds" for a pet the egg can never actually roll would be misleading,
-- not accurate, so this skips the same entries Roll() does.
function SecretPets.Odds()
	local total = 0
	for _, entry in ipairs(SecretPets.List) do
		if eggEligible(entry) then
			total = total + entry.weight
		end
	end

	local odds = {}
	for _, entry in ipairs(SecretPets.List) do
		if eggEligible(entry) then
			table.insert(odds, {
				name = entry.name,
				value = entry.value,
				percent = math.floor((entry.weight / total) * 1000 + 0.5) / 10,
			})
		end
	end
	return odds
end

return SecretPets
