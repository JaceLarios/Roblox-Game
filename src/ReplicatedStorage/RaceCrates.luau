--[[
	RaceCrates (ModuleScript, ReplicatedStorage) — Junkyard Fusion

	What a Race Wars crate holds, and how long it takes to open.

	Every level you clear in Race Wars puts one crate in your Inventory
	(the Crates tab). What is inside is rolled the moment you win it, from
	that level's list below, and your luck tips the roll toward the rarer
	entries. The crate then counts down before it can be opened, and the
	better the item inside, the longer the wait — so a long timer is a
	hint that something good is in there.

	PLACEHOLDER LOOT: the lists below are stand-ins made from Junkyard items
	so crates work today. Replace each level's `loot` with the real items
	when they are decided. Each entry is an item name, a weight (how often
	it comes up relative to the others in that list) and, for any item
	that is not a Junkyard item, its rarity (a Junkyard item's rarity is
	looked up for you).
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local FusionRecipes = require(ReplicatedStorage:WaitForChild("FusionRecipes"))

local RaceCrates = {}

-- Seconds to open, by the rarity of what is inside.
RaceCrates.OpenSeconds = {
	common    = 60,
	uncommon  = 3 * 60,
	rare      = 8 * 60,
	epic      = 20 * 60,
	mythic    = 45 * 60,
	legendary = 90 * 60,
}

-- The most unopened crates a player can hold. Past this, clearing a level
-- wins nothing until some are opened.
RaceCrates.CAPACITY = 20

-- One list per Race Wars level, in level order (see RaceConfig.Levels).
RaceCrates.Levels = {
	{ -- 1: Green Hills
		loot = {
			{ item = "Rusted Sedan", weight = 30 },
			{ item = "Dirt Bike",    weight = 30 },
			{ item = "Golf Cart",    weight = 18 },
			{ item = "Muscle Car",   weight = 14 },
			{ item = "Nitrous Tank", weight = 8 },
		},
	},
	{ -- 2: Dune Run
		loot = {
			{ item = "Golf Cart",    weight = 26 },
			{ item = "Muscle Car",   weight = 26 },
			{ item = "Nitrous Tank", weight = 22 },
			{ item = "Cop Cruiser",  weight = 16 },
			{ item = "Inline 4",     weight = 10 },
		},
	},
	{ -- 3: Frost Pass
		loot = {
			{ item = "Cop Cruiser",   weight = 30 },
			{ item = "Inline 4",      weight = 28 },
			{ item = "Box Truck",     weight = 20 },
			{ item = "Cone Cruiser",  weight = 14 },
			{ item = "V6 Engine",     weight = 8 },
		},
	},
	{ -- 4: Magma Mile
		loot = {
			{ item = "Box Truck",         weight = 30 },
			{ item = "V6 Engine",         weight = 28 },
			{ item = "Monster Truck",     weight = 20 },
			{ item = "Turbo Interceptor", weight = 14 },
			{ item = "V8 Engine",         weight = 8 },
		},
	},
	{ -- 5: Neon Rush
		loot = {
			{ item = "Monster Truck",    weight = 30 },
			{ item = "V8 Engine",        weight = 28 },
			{ item = "Highway Overlord", weight = 20 },
			{ item = "Jet Engine",       weight = 14 },
			{ item = "Scrapyard God",    weight = 8 },
		},
	},
}

-- The rarity of a loot entry: its own, or the Junkyard item's.
local function rarityOf(entry)
	return entry.rarity or FusionRecipes.GetRarity(entry.item) or "common"
end
RaceCrates.RarityOf = rarityOf

-- Rolls a crate for `level`. `luck` is 1 for none; above 1 multiplies the
-- weight of each entry by luck once per rarity step above common, so the
-- rarer the entry the more luck helps it. Returns the item and its rarity.
function RaceCrates.Roll(level, luck)
	local list = RaceCrates.Levels[level] or RaceCrates.Levels[#RaceCrates.Levels]
	luck = math.max(1, luck or 1)
	local weights, total = {}, 0
	for i, entry in ipairs(list.loot) do
		local steps = (FusionRecipes.RarityIndex[rarityOf(entry)] or 1) - 1
		weights[i] = entry.weight * luck ^ steps
		total += weights[i]
	end
	local roll = math.random() * total
	for i, entry in ipairs(list.loot) do
		roll -= weights[i]
		if roll <= 0 then
			return entry.item, rarityOf(entry)
		end
	end
	local last = list.loot[#list.loot]
	return last.item, rarityOf(last)
end

-- True for anything a crate can hold, so the save cleanup never throws a
-- crate prize away as an unknown item.
function RaceCrates.IsLoot(itemName)
	for _, list in ipairs(RaceCrates.Levels) do
		for _, entry in ipairs(list.loot) do
			if entry.item == itemName then return true end
		end
	end
	return false
end

return RaceCrates
