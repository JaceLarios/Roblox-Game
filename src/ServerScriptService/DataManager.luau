--[[
	DataManager (ModuleScript, ServerScriptService) — Junkyard Fusion

	Saves and loads player progress with DataStoreService.

	Three rules this follows, and you should follow in every DataStore
	you ever write:
	  1. Every call is wrapped in pcall. DataStores fail — network blips,
	     Roblox outages, throttling. An unprotected call errors and takes
	     the whole script down with it.
	  2. Retry a few times before giving up.
	  3. If a LOAD fails, never save over it. A failed load looks identical
	     to a new player, and saving that wipes their real progress.
	     That single mistake is the most common way Roblox games eat
	     someone's account.
--]]

local DataStoreService = game:GetService("DataStoreService")
local RunService       = game:GetService("RunService")

-- Bump this name if you ever change the shape of the saved data.
-- Old saves stay untouched under the old key, so a bad migration
-- can't destroy anything.
local STORE_NAME = "JunkyardFusion_v1"
local store = DataStoreService:GetDataStore(STORE_NAME)

local RETRIES     = 3
local RETRY_WAIT  = 2

local DataManager = {}

-- Marks players whose load failed. These are never saved.
local loadFailed = {}

local function defaultData()
	return {
		coins = 0,
		discoveredList = {},
		goalIndex = 1,
		bestTier = 1,
		secrets = 0,
		sales = 0,
		placed = {}, -- legacy: the old physical placement system. No longer written; kept so an old save still loads.
		inventory = {},
		placedPets = {}, -- up to 5 items actually earning money on a pad; see PlotManager.
		brainrotDiscovered = {},
		upgrades = { luck = 1, carry = 1, magnet = 0, value = 1, speed = 1 },
		lastDailyDay = 0,
		dailyStreak = 0,
		boosts = {},
		rebirths = 0,
		lifetimeCoins = 0,
		totalPlaytimeMinutes = 0,
		redeemedCodes = {},
	}
end

DataManager.DefaultData = defaultData

local function keyFor(player)
	return "player_" .. player.UserId
end

------------------------------------------------------------------
-- Load
------------------------------------------------------------------

function DataManager.Load(player)
	local key = keyFor(player)

	for attempt = 1, RETRIES do
		local ok, result = pcall(function()
			return store:GetAsync(key)
		end)

		if ok then
			loadFailed[player] = nil

			if result == nil then
				print("[Data] New player:", player.Name)
				return defaultData(), true
			end

			-- Fill in any field a newer version added.
			local data = defaultData()
			for field, value in pairs(result) do
				data[field] = value
			end

			print(string.format("[Data] Loaded %s — %d coins, %d discoveries",
				player.Name, data.coins, #data.discoveredList))
			return data, true
		end

		warn(string.format("[Data] Load attempt %d failed for %s: %s",
			attempt, player.Name, tostring(result)))
		task.wait(RETRY_WAIT)
	end

	-- Every attempt failed. Give them a working session, but flag it so
	-- we never overwrite whatever is really stored.
	loadFailed[player] = true
	warn("[Data] LOAD FAILED for " .. player.Name .. " — progress will not save this session.")
	return defaultData(), false
end

------------------------------------------------------------------
-- Save
------------------------------------------------------------------

function DataManager.Save(player, data)
	if not data then return false end

	if loadFailed[player] then
		warn("[Data] Refusing to save " .. player.Name .. " — their load failed.")
		return false
	end

	local key = keyFor(player)

	for attempt = 1, RETRIES do
		local ok, err = pcall(function()
			store:SetAsync(key, data)
		end)

		if ok then
			return true
		end

		warn(string.format("[Data] Save attempt %d failed for %s: %s",
			attempt, player.Name, tostring(err)))
		task.wait(RETRY_WAIT)
	end

	warn("[Data] SAVE FAILED for " .. player.Name)
	return false
end

function DataManager.Forget(player)
	loadFailed[player] = nil
end

function DataManager.IsStudio()
	return RunService:IsStudio()
end

return DataManager
