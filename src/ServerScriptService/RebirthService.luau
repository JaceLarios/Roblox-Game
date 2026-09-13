--[[
	RebirthService (ModuleScript, ServerScriptService) — Junkyard Fusion v1

	A permanent, account-wide coin multiplier both islands respect — same
	small shared-module shape as GamepassService, so PlotManager and
	BrainrotService can both require it without any circular dependency
	between them. PlotManager owns the actual reset (coins, placed items,
	upgrades) since it's the only place holding that state; this module
	just tracks the rebirth count and looks up the multiplier for it.
--]]

local RebirthService = {}

-- Total multiplier AT that rebirth count (not additive per tier). Index 0
-- is "never rebirthed" and has no cost — you can't buy your way into it.
-- Capped at 6 for now; add more tiers here to raise the ceiling later.
local TIERS = {
	[0] = { cost = nil,       multiplier = 1 },
	[1] = { cost = 100000,    multiplier = 1.25 },
	[2] = { cost = 500000,    multiplier = 1.60 },
	[3] = { cost = 2000000,   multiplier = 2.00 },
	[4] = { cost = 8000000,   multiplier = 2.50 },
	[5] = { cost = 30000000,  multiplier = 3.25 },
	[6] = { cost = 100000000, multiplier = 4.00 },
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

function RebirthService.NextCost(player)
	local nextTier = TIERS[RebirthService.Get(player) + 1]
	return nextTier and nextTier.cost or nil
end

function RebirthService.NextMultiplier(player)
	local nextTier = TIERS[RebirthService.Get(player) + 1]
	return nextTier and nextTier.multiplier or nil
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
