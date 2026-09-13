--[[
	CompanionService (ModuleScript, ServerScriptService) — Junkyard Fusion v1

	Tracks each player's equipped companion (a discovered item from either
	island) and the value bonus it grants — same small shared-module shape
	as GamepassService/RebirthService, so PlotManager and BrainrotService
	can both apply the bonus without depending on each other. PlotManager
	still owns validating an equip request (it already has access to both
	recipe books and Brainrot's discovery list); this module only tracks
	the resulting state and computes the bonus from it.
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local FusionRecipes = require(ReplicatedStorage:WaitForChild("FusionRecipes"))
local BrainrotRecipes = require(ReplicatedStorage:WaitForChild("BrainrotRecipes"))

local CompanionService = {}

local TIER_BONUS = { [1] = 0.02, [2] = 0.04, [3] = 0.07, [4] = 0.10 }
local SECRET_BONUS = 0.15

local state = {} -- [player] = { name = ..., island = "junkyard"/"brainrot" } or nil

local function recipesFor(island)
	return island == "brainrot" and BrainrotRecipes or FusionRecipes
end

function CompanionService.Init(player, saved)
	state[player] = saved
end

function CompanionService.Get(player)
	return state[player]
end

function CompanionService.Set(player, companion)
	state[player] = companion
end

function CompanionService.Bonus(player)
	local companion = state[player]
	if not companion then return 1 end
	local Recipes = recipesFor(companion.island)
	if Recipes.IsSecretResult(companion.name) then
		return 1 + SECRET_BONUS
	end
	return 1 + (TIER_BONUS[Recipes.GetTier(companion.name)] or 0)
end

function CompanionService.Snapshot(player)
	return state[player]
end

function CompanionService.Cleanup(player)
	state[player] = nil
end

return CompanionService
