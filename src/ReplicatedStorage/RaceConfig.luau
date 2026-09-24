--[[
	RaceConfig (ModuleScript, ReplicatedStorage) — Junkyard Fusion

	Race Wars numbers, shared by the server (RaceService, RaceTrack) and the
	client (the car picker's speed readout, the race HUD). Tuning lives
	here, not in the scripts that use it.

	Races run on a schedule, every RACE_INTERVAL seconds: everyone standing
	in the line-up in front of the start when the timer runs out races
	together. A race is one straight run through the levels in order, with
	one monster chasing the whole pack at the speed of whichever level it
	is on; it catches the racer at the back first. Clear a level and you
	win that level's crate; get caught and your run is over. Whether you
	get caught comes down to your car's top speed against the monster's,
	and how cleanly you drive round the obstacles. The monster gets a lot
	faster with every level, and the last level's monster is faster than
	the best car in the game (see MonsterSpeed).
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local FusionRecipes = require(ReplicatedStorage:WaitForChild("FusionRecipes"))
local Mutations = require(ReplicatedStorage:WaitForChild("Mutations"))

local RaceConfig = {}

-- Studs from the start line to the end of each level.
RaceConfig.LEVEL_LENGTH = 800

-- In order. `theme` picks the level's look in RaceTrack.
RaceConfig.Levels = {
	{ name = "Green Hills", theme = "grass" },
	{ name = "Dune Run",    theme = "desert" },
	{ name = "Frost Pass",  theme = "snow" },
	{ name = "Magma Mile",  theme = "volcano" },
	{ name = "Neon Rush",   theme = "neon" },
}

-- How fast the monster runs (studs per second). It starts at
-- FIRST_MONSTER_SPEED on level 1 and gets faster by the same big
-- percentage every level you clear, until on the last level it is
-- LAST_LEVEL_EDGE times as fast as the fastest car in the game. That ties
-- the whole curve to the best car: add faster cars and every level speeds
-- up with them, so the last level is only ever just possible, in the very
-- best car driven cleanly, and you can always lose.
RaceConfig.FIRST_MONSTER_SPEED = 60
RaceConfig.LAST_LEVEL_EDGE = 1.15

-- A race starts every this many seconds, with whoever is lined up.
RaceConfig.RACE_INTERVAL = 300

-- The monster waits this long after GO before it starts running.
RaceConfig.MONSTER_DELAY = 3
-- However far ahead the last racer gets, the monster is never much
-- further behind than this: past it, the monster sprints at MONSTER_SPRINT
-- times its speed to close the gap. So a car slower than a level's monster
-- is caught within about MAX_GAP / (difference in speed) seconds, and only
-- a fast enough car stays ahead for good.
RaceConfig.MAX_GAP = 110
RaceConfig.MONSTER_SPRINT = 3
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

-- The top speed of the fastest car in the game, unmutated: every car and
-- every fused result in the recipe book.
local fastest = nil
function RaceConfig.FastestCarSpeed()
	if fastest then return fastest end
	fastest = 0
	local function consider(name)
		local stats = RaceConfig.CarStats(name)
		if stats then fastest = math.max(fastest, stats.topSpeed) end
	end
	for _, car in ipairs(FusionRecipes.Items) do consider(car.name) end
	for _, result in ipairs(FusionRecipes.GetAllResults()) do consider(result.name) end
	return fastest
end

-- The monster's speed on a level (see FIRST_MONSTER_SPEED above).
function RaceConfig.MonsterSpeed(level)
	local count = #RaceConfig.Levels
	local last = RaceConfig.FastestCarSpeed() * RaceConfig.LAST_LEVEL_EDGE
	local growth = (last / RaceConfig.FIRST_MONSTER_SPEED) ^ (1 / math.max(1, count - 1))
	return RaceConfig.FIRST_MONSTER_SPEED * growth ^ (math.clamp(level, 1, count) - 1)
end

-- The furthest level a car of this top speed can expect to clear with
-- clean driving. A monster a little faster than you still needs time to
-- close the MAX_GAP head start, so a level counts as clearable while its
-- monster is no more than 8% faster than the car.
function RaceConfig.ReachableLevel(topSpeed)
	local reached = 0
	for i = 1, #RaceConfig.Levels do
		if RaceConfig.MonsterSpeed(i) > topSpeed * 1.08 then break end
		reached = i
	end
	return reached
end

return RaceConfig
