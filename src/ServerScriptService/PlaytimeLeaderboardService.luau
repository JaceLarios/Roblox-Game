--[[
	PlaytimeLeaderboardService (ModuleScript, ServerScriptService) — Junkyard Fusion v1

	The "most dedicated" ranking — total minutes ever spent in the game,
	across every session, forever accumulating. Same shape as
	LeaderboardService (coins) on purpose: same OrderedDataStore pattern,
	same Init/Record/Snapshot/PushToStore/RefreshIfStale/GetTopCached/
	Cleanup lifecycle, same "only the periodic autosave loop touches the
	network" rule — so the two boards on the leaderboard monument can share
	one refresh loop and one redraw helper in PlotManager.
--]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local STORE_NAME = "JunkyardFusion_PlaytimeLeaderboard_v1"
local store = DataStoreService:GetOrderedDataStore(STORE_NAME)

local REFRESH_INTERVAL = 60

local PlaytimeLeaderboardService = {}

local state = {} -- [player] = { totalMinutes = N }
local cachedTop = {}
local lastFetch = 0

function PlaytimeLeaderboardService.Init(player, savedTotalMinutes)
	state[player] = { totalMinutes = savedTotalMinutes or 0 }
end

-- Cheap, in-memory only — called once per minute per player.
function PlaytimeLeaderboardService.Record(player, minutes)
	local s = state[player]
	if not s or minutes <= 0 then return end
	s.totalMinutes = s.totalMinutes + minutes
end

function PlaytimeLeaderboardService.Snapshot(player)
	local s = state[player]
	return s and s.totalMinutes or 0
end

-- Ordered stores reject non-integers; minutes are whole today, but floor
-- anyway so a fractional Record never silently stalls the board.
function PlaytimeLeaderboardService.PushToStore(player)
	local s = state[player]
	if not s then return end
	pcall(function()
		store:SetAsync(tostring(player.UserId), math.floor(s.totalMinutes))
	end)
end

function PlaytimeLeaderboardService.RefreshIfStale()
	if os.time() - lastFetch < REFRESH_INTERVAL then return end
	lastFetch = os.time()

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
			minutes = entry.value,
		})
	end
	cachedTop = top
end

-- The stored ranking with everyone in this server folded in at their live
-- totals. The store only hears from a server every couple of minutes, so
-- without this a player would not show up until their next save reached
-- it and the next refresh read it back; a brand-new server's boards would
-- sit empty with people standing right in front of them.
function PlaytimeLeaderboardService.GetTopCached()
	local list, byId = {}, {}
	for _, entry in ipairs(cachedTop) do
		local copy = table.clone(entry)
		byId[copy.userId] = copy
		table.insert(list, copy)
	end
	for player, s in pairs(state) do
		local live = math.floor(s.totalMinutes)
		local entry = byId[player.UserId]
		if entry then
			entry.minutes = math.max(entry.minutes, live)
			entry.name = player.Name
		else
			table.insert(list, { userId = player.UserId, name = player.Name, minutes = live })
		end
	end
	table.sort(list, function(a, b) return a.minutes > b.minutes end)
	while #list > 100 do
		table.remove(list)
	end
	return list
end

function PlaytimeLeaderboardService.Cleanup(player)
	state[player] = nil
end

return PlaytimeLeaderboardService
