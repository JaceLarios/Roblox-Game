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
local equipped = {} -- [player] = petKey or nil — which owned pet's model currently follows them

function AreaPetsService.Init(player, savedKeys, savedEquipped)
	local owned = {}
	for _, key in ipairs(savedKeys or {}) do
		owned[key] = true
	end
	state[player] = owned
	-- Guard against a stray save pointing at a pet that's since been
	-- removed from AreaPets.luau, or that this owned-set doesn't actually
	-- contain (shouldn't happen, but equip should never silently show a
	-- pet the player doesn't have).
	if savedEquipped and owned[savedEquipped] then
		equipped[player] = savedEquipped
	end
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

-- Exactly one equip slot for now — same "one at a time" shape
-- CompanionService already established for fusion companions, which this
-- is deliberately separate from (a player can have both a fusion
-- companion AND an equipped egg pet active at once). Pass nil to unequip.
function AreaPetsService.SetEquipped(player, petKey)
	if petKey ~= nil and not AreaPetsService.Owns(player, petKey) then
		return false
	end
	equipped[player] = petKey
	return true
end

function AreaPetsService.GetEquipped(player)
	return equipped[player]
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
	equipped[player] = nil
end

return AreaPetsService
