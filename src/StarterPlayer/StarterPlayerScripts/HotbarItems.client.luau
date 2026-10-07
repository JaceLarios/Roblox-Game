--[[
	HotbarItems (LocalScript, StarterPlayerScripts) — Junkyard Fusion

	The pad prompts that go with holding an item from your hotbar (there is
	no Inventory panel since 2026-10-07; PlotManager's "The hotbar"):

	  - Your Fusion Pad's prompt says what it will do: "Load <item>" while
	    you hold one, "Fuse" while you don't.
	  - Each earning pad carries a "Place" prompt. It shows only on your own
	    next empty pad, and only while you hold a car (addons never go on a
	    pad), so it never gets in the way of anything else.

	Only on your screen; the server checks everything again on a trigger.
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local FusionRecipes = require(ReplicatedStorage:WaitForChild("FusionRecipes"))
local Mutations = require(ReplicatedStorage:WaitForChild("Mutations"))
local ItemNames = require(ReplicatedStorage:WaitForChild("ItemNames"))

local player = Players.LocalPlayer
local plotsFolder = workspace:WaitForChild("Plots")

local CHECK_EVERY = 0.15
local elapsed = 0

local function heldItem()
	local tool = player.Character and player.Character:FindFirstChildOfClass("Tool")
	return tool and tool:GetAttribute("ItemName")
end

RunService.Heartbeat:Connect(function(dt)
	elapsed += dt
	if elapsed < CHECK_EVERY then return end
	elapsed = 0

	local held = heldItem()
	local holdingCar = held ~= nil and not FusionRecipes.IsAddon((Mutations.Unwrap(held)))

	for _, plot in ipairs(plotsFolder:GetChildren()) do
		local mine = plot:GetAttribute("OwnerUserId") == player.UserId
		if mine then
			local pad = plot:FindFirstChild("FusionPad", true)
			local fuse = pad and pad:FindFirstChild("ProximityPrompt")
			if fuse then
				local text = held and ("Load " .. ItemNames.Display(held)) or "Fuse"
				if fuse.ActionText ~= text then fuse.ActionText = text end
			end
		end
		-- The next empty earning pad: pads fill in order, PetPad1 first.
		local nextFree = nil
		for slot = 1, 8 do
			local petPad = plot:FindFirstChild("PetPad" .. slot)
			if petPad and not petPad:GetAttribute("Occupied") then
				nextFree = petPad
				break
			end
		end
		for slot = 1, 8 do
			local petPad = plot:FindFirstChild("PetPad" .. slot)
			local place = petPad and petPad:FindFirstChild("PlacePrompt")
			if place then
				local want = mine and holdingCar and petPad == nextFree
				if place.Enabled ~= want then place.Enabled = want end
			end
		end
	end
end)
