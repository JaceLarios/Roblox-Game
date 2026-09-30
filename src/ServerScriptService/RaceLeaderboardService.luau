--[[
	RaceLeaderboardService (ModuleScript, ServerScriptService) — Junkyard Fusion

	The "furthest race" ranking: the furthest each player has ever got down
	the Race Wars track, in studs (RaceConfig.DescribeDistance turns it into
	"Level 3 · 2,410 m"). A personal best only ever goes up. Same shape as
	LeaderboardService and PlaytimeLeaderboardService: its own
	OrderedDataStore, written only on PlotManager's autosave and when a
	player leaves, read at most once a minute, with everyone in this server
	folded in live. Its board stands in the Race Wars lobby
	(CentralLeaderboards).
--]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local STORE_NAME = "JunkyardFusion_RaceBest_v1"
local store = DataStoreService:GetOrderedDataStore(STORE_NAME)

local REFRESH_INTERVAL = 60

local RaceLeaderboardService = {}

local state = {} -- [player] = { best = studs }
local cachedTop = {}
local lastFetch = 0

function RaceLeaderboardService.Init(player, savedBest)
	state[player] = { best = savedBest or 0 }
end

-- A run's distance. Returns true when it beat the player's best.
function RaceLeaderboardService.Record(player, distance)
	local s = state[player]
	if not s or distance <= s.best then return false end
	s.best = distance
	return true
end

function RaceLeaderboardService.Snapshot(player)
	local s = state[player]
	return s and s.best or 0
end

function RaceLeaderboardService.PushToStore(player)
	local s = state[player]
	if not s or s.best <= 0 then return end
	pcall(function()
		store:SetAsync(tostring(player.UserId), math.floor(s.best))
	end)
end

function RaceLeaderboardService.RefreshIfStale()
	if os.time() - lastFetch < REFRESH_INTERVAL then return end
	lastFetch = os.time()

	local ok, pages = pcall(function()
		return store:GetSortedAsync(false, 100)
	end)
	if not ok or not pages then return end

	local top = {}
	for _, entry in ipairs(pages:GetCurrentPage()) do
		local userId = tonumber(entry.key)
		local nameOk, name = pcall(function()
			return Players:GetNameFromUserIdAsync(userId)
		end)
		table.insert(top, {
			userId = userId,
			name = nameOk and name or ("Player " .. tostring(userId)),
			best = entry.value,
		})
	end
	cachedTop = top
end

-- The stored ranking with everyone in this server folded in at their live
-- bests, so a new best shows before the next save reaches the store.
function RaceLeaderboardService.GetTopCached()
	local list, byId = {}, {}
	for _, entry in ipairs(cachedTop) do
		local copy = table.clone(entry)
		byId[copy.userId] = copy
		table.insert(list, copy)
	end
	for player, s in pairs(state) do
		local live = math.floor(s.best)
		if live > 0 then
			local entry = byId[player.UserId]
			if entry then
				entry.best = math.max(entry.best, live)
				entry.name = player.Name
			else
				table.insert(list, { userId = player.UserId, name = player.Name, best = live })
			end
		end
	end
	table.sort(list, function(a, b) return a.best > b.best end)
	while #list > 100 do
		table.remove(list)
	end
	return list
end

function RaceLeaderboardService.Cleanup(player)
	state[player] = nil
end

return RaceLeaderboardService
