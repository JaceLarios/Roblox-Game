--[[
	RaceCrates (ModuleScript, ReplicatedStorage) — Junkyard Fusion

	What a Race Wars crate holds, and how long it takes to open.

	Every level you clear in Race Wars puts one crate in your Inventory
	(the Crates tab). Inside is an addon, rolled the moment you win the
	crate, from every addon in the game (FusionRecipes.Addons). Each addon
	comes up at its rarity's weight below, and luck tips the roll toward
	the rarer ones: yours (the same luck that helps a grab) times the
	crate's own, which is higher the further into the race you got. So a
	crate from the last level is far more likely to hold a Jet Engine than
	one from the first. The crate then counts down before it can be opened,
	and the better the addon inside, the longer the wait — so a long timer
	is a hint that something good is in there.
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

-- How often an addon of each rarity comes up, relative to the others,
-- before any luck. With none, about 1 crate in 250 holds a Legendary.
RaceCrates.RarityWeight = {
	uncommon  = 100,
	rare      = 40,
	epic      = 12,
	mythic    = 3,
	legendary = 0.6,
}

-- The crate's own luck: 1 for Level 1, times this for every level past
-- it. Level 5's crate has about 3.8 luck, which makes roughly one crate in
-- six a Legendary.
RaceCrates.LEVEL_LUCK_GROWTH = 1.4

function RaceCrates.LevelLuck(level)
	return RaceCrates.LEVEL_LUCK_GROWTH ^ (math.max(level, 1) - 1)
end

-- Rolls a crate for `level`. `luck` is the player's own, 1 for none. The
-- combined luck multiplies each addon's weight once per rarity step above
-- the lowest, so the rarer the addon the more luck helps it. Returns the
-- addon and its rarity.
function RaceCrates.Roll(level, luck)
	luck = math.max(1, luck or 1) * RaceCrates.LevelLuck(level)
	local lowest = FusionRecipes.RarityIndex.uncommon
	local weights, total = {}, 0
	for i, addon in ipairs(FusionRecipes.Addons) do
		local steps = (FusionRecipes.RarityIndex[addon.rarity] or lowest) - lowest
		weights[i] = (RaceCrates.RarityWeight[addon.rarity] or 1) * luck ^ steps
		total += weights[i]
	end
	local roll = math.random() * total
	for i, addon in ipairs(FusionRecipes.Addons) do
		roll -= weights[i]
		if roll <= 0 then
			return addon.name, addon.rarity
		end
	end
	local last = FusionRecipes.Addons[#FusionRecipes.Addons]
	return last.name, last.rarity
end

-- The rarity of anything a crate holds.
function RaceCrates.RarityOf(itemName)
	return FusionRecipes.GetRarity(itemName) or "common"
end

-- True for anything a crate can hold, so the save cleanup never throws a
-- crate prize away as an unknown item.
function RaceCrates.IsLoot(itemName)
	return FusionRecipes.IsAddon(itemName)
end

return RaceCrates
