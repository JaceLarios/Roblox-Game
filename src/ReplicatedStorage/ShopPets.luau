--[[
	ShopPets (ModuleScript, ReplicatedStorage) — Junkyard Fusion v1

	Coin-purchasable pets for the Shop UI — a "leg up" for players who'd
	rather spend coins than grind the drop-rate RNG, not a shortcut past
	the actual game. Deliberately limited to Tier 1 base items (the same
	ones the scrap spawner already drops) so nothing here bypasses the
	fusion-discovery progression itself — no curated fusion results, no
	secrets, nothing a player can't already get by playing.

	Priced at roughly 10x each item's sale value: since a placed pet earns
	coins/sec forever (value / 90 sec — see PLACEMENT_PAYBACK_SECONDS in
	PlotManager), a straight sale-price tag would make these an
	obviously-correct instant buy. ~10x prices them as "skip a bit of
	grinding," not "strictly better than playing." Tune freely — this is
	a first pass.
--]]

return {
	{ item = "Cop Cruiser", cost = 350 },
	{ item = "Box Truck", cost = 600 },
	{ item = "Monster Truck", cost = 1000 },
	{ item = "Jet Engine", cost = 3500 },
}
