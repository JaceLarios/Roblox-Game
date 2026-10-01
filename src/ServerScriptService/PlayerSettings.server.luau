--[[
	PlayerSettings (Script, ServerScriptService) — Junkyard Fusion

	Keeps each player's game settings between visits (the Settings panel,
	SettingsUI.client): music volume, sound effects on or off, and potato
	mode. They live in their own DataStore, not the main save, so changing
	a setting can never touch anyone's progress.

	On join the saved settings go on the player as attributes (MusicVolume
	0-1, SFXOn, PotatoMode, then SettingsLoaded), which the client applies.
	A change comes in through the PlayerSettings remote as (key, value), is
	checked, and is written back when the player leaves.
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local DataStoreService = game:GetService("DataStoreService")

local store = DataStoreService:GetDataStore("JunkyardFusion_Settings_v1")
local DEFAULTS = { MusicVolume = 1, SFXOn = true, PotatoMode = false }

local remote = ReplicatedStorage:FindFirstChild("PlayerSettings")
if not remote then
	remote = Instance.new("RemoteEvent")
	remote.Name = "PlayerSettings"
	remote.Parent = ReplicatedStorage
end

local changed = {} -- [player] = true once they have changed something

local function keyFor(player)
	return "player_" .. player.UserId
end

-- A setting's value if it is a valid one, else nil.
local function clean(key, value)
	if key == "MusicVolume" and type(value) == "number" and value == value then
		return math.clamp(math.round(value * 100) / 100, 0, 1)
	elseif (key == "SFXOn" or key == "PotatoMode") and type(value) == "boolean" then
		return value
	end
	return nil
end

local function load(player)
	local ok, saved = pcall(function()
		return store:GetAsync(keyFor(player))
	end)
	if not player.Parent then return end
	for key, default in pairs(DEFAULTS) do
		local value = nil
		if ok and type(saved) == "table" then
			value = clean(key, saved[key])
		end
		if value == nil then
			value = default
		end
		player:SetAttribute(key, value)
	end
	player:SetAttribute("SettingsLoaded", true)
end

local function save(player)
	if not changed[player] then return end
	changed[player] = nil
	local data = {}
	for key in pairs(DEFAULTS) do
		data[key] = player:GetAttribute(key)
	end
	local ok, err = pcall(function()
		store:SetAsync(keyFor(player), data)
	end)
	if not ok then
		warn("[PlayerSettings] Save failed for " .. player.Name .. ": " .. tostring(err))
	end
end

remote.OnServerEvent:Connect(function(player, key, value)
	if type(key) ~= "string" or DEFAULTS[key] == nil then return end
	local v = clean(key, value)
	if v == nil then return end
	player:SetAttribute(key, v)
	changed[player] = true
end)

Players.PlayerAdded:Connect(load)
for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(load, player)
end
Players.PlayerRemoving:Connect(function(player)
	save(player)
	changed[player] = nil
end)
game:BindToClose(function()
	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(save, player)
	end
	task.wait(2)
end)
