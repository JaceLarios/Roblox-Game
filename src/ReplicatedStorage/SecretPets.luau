--[[
	SecretPets (ModuleScript, ReplicatedStorage) — Junkyard Fusion

	Robux-only pets, bought directly rather than fused. Two hard rules
	the rest of the codebase enforces around whatever lives in this list
	(see PlotManager.server.luau: itemTierInfo, canReceiveTradedItem,
	attemptFusion, and the ProcessReceipt handler near the old BuyShopPet
	spot):
	  1. Never fusable — can't be carried to a pad, in or out, so they can
	     never be an ingredient, and since they're not in FusionRecipes or
	     BrainrotRecipes at all, they can never be a fusion result either.
	  2. Priced and valued as the best thing in the game — see PLACEHOLDER
	     values below, meaningfully above FusionRecipes.SecretValue (the
	     current best fusion result, 50000).

	Replaces the old ShopPets.luau (coin-purchasable existing items) —
	that approach was deliberately scrapped: selling items players could
	already discover undercut the point of an exclusive. This is the real
	version of that ask.

	EVERYTHING below is a placeholder, on purpose:
	  - `name` — TBD. Needs an actual concept ("something crazy, entirely
	    different from anything in the game, designed from scratch, not a
	    generic asset" per the user) — that's a Codex/design question, not
	    a Claude one. Don't ship a name invented here as if it were final.
	  - `productId = 0` — a real Developer Product doesn't exist yet. Create
	    one per pet on the Roblox Creator Dashboard and drop the real
	    numeric id in here (same "id = 0 means not configured yet"
	    convention already used by GamepassConfig.luau).
	  - `value` — a reasonable starting number, not a balanced final one.
	    Tune freely.

	Add or remove entries freely; nothing else needs to change to support
	a 4th, 5th, etc. — every system that reads this list (itemTierInfo,
	the Shop UI once Codex builds it, ProcessReceipt) is generic over
	however many entries are here.
--]]

local SecretPets = { List = {} }

table.insert(SecretPets.List, { key = "secret_pet_1", name = "TBD Secret Pet 1", productId = 0, value = 90000 })
table.insert(SecretPets.List, { key = "secret_pet_2", name = "TBD Secret Pet 2", productId = 0, value = 115000 })
table.insert(SecretPets.List, { key = "secret_pet_3", name = "TBD Secret Pet 3", productId = 0, value = 150000 })

SecretPets.ByName = {}
SecretPets.ByProductId = {}
for _, entry in ipairs(SecretPets.List) do
	SecretPets.ByName[entry.name] = entry
	SecretPets.ByProductId[entry.productId] = entry
end

function SecretPets.IsConfigured(entry)
	return type(entry.productId) == "number" and entry.productId > 0 and entry.productId % 1 == 0
end

return SecretPets
