--[[
	AreaPetsService (ModuleScript, ServerScriptService) — Junkyard Fusion v1

	Tracks each player's owned egg pets (AreaPets.luau) and the coin/speed
	multiplier they grant — same small shared-module shape as
	GamepassService/RebirthService/CompanionService, so PlotManager,
	BrainrotService and HauntedService can all apply the bonus without
	depending on each other or on PlotManager's own per-player state.

	Coins(player, amount) deliberately mirrors GamepassService.Coins'
	exact signature so every addCoins this game has (PlotManager's,
	Brainrot's, Haunted's) applies it the same one-line way right after
	the existing Gamepasses.Coins call. SpeedMultiplier(player) mirrors
	GamepassService.SpeedMultiplier the same way for updateWalkSpeed.
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local AreaPets = require(ReplicatedStorage:WaitForChild("AreaPets"))

local AreaPetsService = {}

local state = {} -- [player] = { [petKey] = true, ... }

function AreaPetsService.Init(player, savedKeys)
	local owned = {}
	for _, key in ipairs(savedKeys or {}) do
		owned[key] = true
	end
	state[player] = owned
end

-- Idempotent: granting a pet the player already owns changes nothing,
-- same "duplicates just don't add another bonus" behavior a set gives
-- for free — buying an egg again still re-rolls, it just doesn't help
-- once every pet in that egg is owned.
function AreaPetsService.Grant(player, petKey)
	local owned = state[player]
	if not owned then return end
	owned[petKey] = true
end

function AreaPetsService.Owns(player, petKey)
	local owned = state[player]
	return owned ~= nil and owned[petKey] == true
end

function AreaPetsService.Coins(player, amount)
	local owned = state[player]
	if not owned then return amount end
	return amount * AreaPets.TotalCoinMultiplier(owned)
end

function AreaPetsService.SpeedMultiplier(player)
	local owned = state[player]
	if not owned then return 1 end
	return AreaPets.TotalSpeedMultiplier(owned)
end

-- Plain array of owned pet keys, for DataManager to save.
function AreaPetsService.Snapshot(player)
	local owned = state[player]
	if not owned then return {} end

	local list = {}
	for petKey in pairs(owned) do
		table.insert(list, petKey)
	end
	return list
end

function AreaPetsService.Cleanup(player)
	state[player] = nil
end

return AreaPetsService
