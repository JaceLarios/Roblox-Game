--[[
	LeaderboardService (ModuleScript, ServerScriptService) — Junkyard Fusion v1

	A persistent, global "lifetime coins earned" ranking — not current
	balance, since Rebirth deliberately resets that and a rebirthed
	top player shouldn't vanish from the board the moment they cash in
	their multiplier. Same small shared-module shape as GamepassService/
	RebirthService/CompanionService.

	Uses a separate OrderedDataStore from DataManager's regular one, since
	only ordered stores support a sorted top-N query. The actual DataStore
	write only happens on the existing periodic autosave cadence (see
	PlotManager's autosave loop) — recording an earning here is just an
	in-memory increment, so passive income ticking every few seconds never
	touches the network.
--]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local STORE_NAME = "JunkyardFusion_Leaderboard_v1"
local store = DataStoreService:GetOrderedDataStore(STORE_NAME)

-- Don't hit the DataStore more than once per this window, no matter how
-- many players open the leaderboard at the same time — everyone reads the
-- same short-lived cache instead of triggering their own fresh query.
local REFRESH_INTERVAL = 60

local LeaderboardService = {}

local state = {} -- [player] = { lifetimeCoins = N }
local cachedTop = {}
local lastFetch = 0

function LeaderboardService.Init(player, savedLifetimeCoins)
	state[player] = { lifetimeCoins = savedLifetimeCoins or 0 }
end

-- Cheap, in-memory only — safe to call on every single coin gain.
function LeaderboardService.Record(player, amount)
	local s = state[player]
	if not s or amount <= 0 then return end
	s.lifetimeCoins = s.lifetimeCoins + amount
end

function LeaderboardService.Snapshot(player)
	local s = state[player]
	return s and s.lifetimeCoins or 0
end

-- The real network call — deliberately only invoked from the existing
-- periodic autosave loop, never per-earning. Ordered stores reject any
-- non-integer value, and passive income / multipliers make the running
-- total fractional, so floor it on the way out (memory stays exact).
function LeaderboardService.PushToStore(player)
	local s = state[player]
	if not s then return end
	pcall(function()
		store:SetAsync(tostring(player.UserId), math.floor(s.lifetimeCoins))
	end)
end

function LeaderboardService.RefreshIfStale()
	if os.time() - lastFetch < REFRESH_INTERVAL then return end
	lastFetch = os.time() -- set before the async call so concurrent requests share one fetch

	local ok, pages = pcall(function()
		return store:GetSortedAsync(false, 100)
	end)
	if not ok or not pages then return end

	local page = pages:GetCurrentPage()
	local top = {}
	for _, entry in ipairs(page) do
		local userId = tonumber(entry.key)
		local nameOk, name = pcall(function()
			return Players:GetNameFromUserIdAsync(userId)
		end)
		table.insert(top, {
			userId = userId,
			name = nameOk and name or ("Player " .. tostring(userId)),
			coins = entry.value,
		})
	end
	cachedTop = top
end

function LeaderboardService.GetTopCached()
	return cachedTop
end

function LeaderboardService.Cleanup(player)
	state[player] = nil
end

return LeaderboardService
