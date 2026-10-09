--[[
	RebirthService (ModuleScript, ServerScriptService) — Junkyard Fusion v1

	A permanent, account-wide coin multiplier — same small shared-module
	shape as GamepassService. PlotManager owns the actual reset (only coins
	since 2026-10-09: cars, inventory and upgrades stay) since it's the only
	place holding that state; this module just tracks the rebirth count and
	looks up the multiplier for it.
--]]

local RebirthService = {}

-- Total multiplier AT that rebirth count (not additive per tier). Index 0
-- is "never rebirthed" and has no cost — you can't buy your way into it.
-- Capped at 6 for now; add more tiers here to raise the ceiling later.
-- luckMultiplier added 2026-09-14 ("with every rebirth you should get
-- some type of luck and coin multiplier") — kept gentler than the coin
-- curve since it multiplies a chance that's already capped elsewhere
-- (LUCK_MAX_CHANCE in PlotManager.server.luau), so it can't compound into
-- something absurd the way an uncapped coin multiplier safely can.
-- Costs raised 2026-10-09, when a Rebirth stopped taking your cars (it
-- only takes coins now) and pads started earning half as much: an economy
-- sim of an active player (a third of the belt, a car every 45 s, the
-- best buy each time) has Rebirth 1 at about 40 minutes and Rebirth 6 at
-- about 7 hours (about 3.5 with the 2x Coins pass). Most players are slower.
local TIERS = {
	[0] = { cost = nil,       multiplier = 1,    luckMultiplier = 1 },
	[1] = { cost = 400000,    multiplier = 1.25, luckMultiplier = 1.10 },
	[2] = { cost = 4000000,   multiplier = 1.60, luckMultiplier = 1.20 },
	[3] = { cost = 15000000,  multiplier = 2.00, luckMultiplier = 1.35 },
	[4] = { cost = 40000000,  multiplier = 2.50, luckMultiplier = 1.50 },
	[5] = { cost = 120000000, multiplier = 3.25, luckMultiplier = 1.75 },
	[6] = { cost = 350000000, multiplier = 4.00, luckMultiplier = 2.00 },
}
RebirthService.MaxLevel = 6

local state = {} -- [player] = { rebirths = N }

function RebirthService.Init(player, savedRebirths)
	state[player] = { rebirths = math.clamp(savedRebirths or 0, 0, RebirthService.MaxLevel) }
end

function RebirthService.Get(player)
	local s = state[player]
	return s and s.rebirths or 0
end

function RebirthService.Multiplier(player)
	return TIERS[RebirthService.Get(player)].multiplier
end

function RebirthService.LuckMultiplier(player)
	return TIERS[RebirthService.Get(player)].luckMultiplier
end

function RebirthService.NextCost(player)
	local nextTier = TIERS[RebirthService.Get(player) + 1]
	return nextTier and nextTier.cost or nil
end

function RebirthService.NextMultiplier(player)
	local nextTier = TIERS[RebirthService.Get(player) + 1]
	return nextTier and nextTier.multiplier or nil
end

function RebirthService.NextLuckMultiplier(player)
	local nextTier = TIERS[RebirthService.Get(player) + 1]
	return nextTier and nextTier.luckMultiplier or nil
end

function RebirthService.IsMaxed(player)
	return RebirthService.Get(player) >= RebirthService.MaxLevel
end

-- Caller (PlotManager) has already verified affordability and performed
-- the actual reset — this just advances the counter.
function RebirthService.Increment(player)
	local s = state[player]
	if not s then return end
	s.rebirths = math.min(s.rebirths + 1, RebirthService.MaxLevel)
end

function RebirthService.Snapshot(player)
	return RebirthService.Get(player)
end

function RebirthService.Cleanup(player)
	state[player] = nil
end

return RebirthService
