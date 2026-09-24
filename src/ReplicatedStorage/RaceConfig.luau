--[[
	RaceConfig (ModuleScript, ReplicatedStorage) — Junkyard Fusion

	Race Wars numbers, shared by the server (RaceService, RaceTrack) and the
	client (the car picker's speed readout, the race HUD). Tuning lives
	here, not in the scripts that use it.

	A race is one straight run through the levels in order. A monster
	chases you the whole way, at the speed of whichever level you are on;
	clear a level and you win that level's crate, get caught and the run
	is over. Whether you get caught comes down to your car's top speed
	against the monster's, and how cleanly you drive round the obstacles.
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local FusionRecipes = require(ReplicatedStorage:WaitForChild("FusionRecipes"))
local Mutations = require(ReplicatedStorage:WaitForChild("Mutations"))

local RaceConfig = {}

-- Studs from the start line to the end of each level.
RaceConfig.LEVEL_LENGTH = 800

-- In order. `monsterSpeed` is studs per second while you are on that
-- level. `theme` picks the level's look in RaceTrack.
RaceConfig.Levels = {
	{ name = "Green Hills", theme = "grass",   monsterSpeed = 46 },
	{ name = "Dune Run",    theme = "desert",  monsterSpeed = 64 },
	{ name = "Frost Pass",  theme = "snow",    monsterSpeed = 84 },
	{ name = "Magma Mile",  theme = "volcano", monsterSpeed = 100 },
	{ name = "Neon Rush",   theme = "neon",    monsterSpeed = 114 },
}

-- The monster waits this long after GO before it starts running.
RaceConfig.MONSTER_DELAY = 3
-- However far ahead you get, the monster is never further behind than
-- this: it sprints to close any bigger gap. So a car slower than a level's
-- monster is caught within MAX_GAP / (difference in speed) seconds, and
-- only a fast enough car stays ahead for good.
RaceConfig.MAX_GAP = 110
-- Caught when the monster is this close behind the car.
RaceConfig.CATCH_DISTANCE = 7

-- How long the race cars are, nose to tail, whatever size the item's
-- model is in the yard.
RaceConfig.CAR_LENGTH = 13

-- Top speed comes from what the item is worth, on a log scale: every ten
-- times the value is another SPEED_PER_TENFOLD studs per second. That
-- puts a Rusted Sedan (5 coins) at about 51, a Monster Truck at 71, the
-- Inline 4 builds in the 80s, the V8 builds past 100 and the Jet builds
-- at 115 to 123 — so each better addon gets you a level further.
-- A mutation's value multiplier counts, so a mutated car is faster too.
local BASE_SPEED = 40
local SPEED_PER_TENFOLD = 16

-- Addons are engines, not vehicles: they can't be raced.
function RaceConfig.IsDrivable(itemName)
	local baseName = Mutations.Unwrap(itemName)
	return FusionRecipes.GetRarity(baseName) ~= nil and not FusionRecipes.IsAddon(baseName)
end

-- { topSpeed, accel, turnRate } for a drivable item, or nil.
function RaceConfig.CarStats(itemName)
	if not RaceConfig.IsDrivable(itemName) then return nil end
	local baseName, mutationId = Mutations.Unwrap(itemName)
	local value = FusionRecipes.GetValue(baseName) * Mutations.ValueMultiplier(mutationId)
	local topSpeed = BASE_SPEED + SPEED_PER_TENFOLD * math.log10(math.max(value, 1))
	topSpeed = math.floor(topSpeed * 10 + 0.5) / 10
	return {
		topSpeed = topSpeed,
		-- Studs per second, per second: flat out in a bit over a second.
		accel = topSpeed * 0.8,
		-- Radians per second at full lock.
		turnRate = 1.9,
	}
end

-- The furthest level a car of this top speed can expect to clear with
-- clean driving: every level whose monster it can keep ahead of.
function RaceConfig.ReachableLevel(topSpeed)
	local reached = 0
	for i, level in ipairs(RaceConfig.Levels) do
		if topSpeed + 4 < level.monsterSpeed then break end
		reached = i
	end
	return reached
end

return RaceConfig
