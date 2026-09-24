--[[
	RaceWarsUI (LocalScript, StarterPlayerScripts) — Junkyard Fusion

	The controller for Race Wars on screen: opens the Race Garage (at the
	lobby kiosk, or on arriving in the lobby), lists the cars you own with
	their race stats, starts a race in the one you pick, and keeps the race
	HUD up to date. RaceWarsView owns every bit of the look.

	Your cars come from the GameUpdate payload the Inventory already uses
	(inventory and placed), so nothing new is sent for the picker. Race
	progress comes from RaceService: the RaceEvent remote for moments
	(countdown, level cleared, caught...) and attributes on your player
	for the running numbers (level, distance, the monster's gap).
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ProximityPromptService = game:GetService("ProximityPromptService")

local RaceConfig = require(ReplicatedStorage:WaitForChild("RaceConfig"))
local View = require(script.Parent:WaitForChild("RaceWarsView"))

local player = Players.LocalPlayer
local gameUpdate = ReplicatedStorage:WaitForChild("GameUpdate")
local startRemote = ReplicatedStorage:WaitForChild("RaceStart")
local eventRemote = ReplicatedStorage:WaitForChild("RaceEvent")

local owned = { inventory = {}, placed = {} }
local racing = false
local topSpeed = 0
local trackLength = #RaceConfig.Levels * RaceConfig.LEVEL_LENGTH

gameUpdate.OnClientEvent:Connect(function(data)
	if type(data) ~= "table" then return end
	if data.inventory then owned.inventory = data.inventory end
	if data.placed then owned.placed = data.placed end
end)

-- Every drivable car you own, fastest first. One card per name: two of
-- the same car race the same.
local function carList()
	local cars, seen = {}, {}
	local function add(entry, onPad)
		local name = entry.name
		if seen[name] then
			if onPad then seen[name].onPad = true end
			return
		end
		local stats = RaceConfig.CarStats(name)
		if not stats then return end
		local reach = RaceConfig.ReachableLevel(stats.topSpeed)
		local car = {
			name = name,
			topSpeed = stats.topSpeed,
			reach = reach,
			reachName = reach > 0 and RaceConfig.Levels[reach].name or "",
			onPad = onPad,
		}
		seen[name] = car
		table.insert(cars, car)
	end
	for _, entry in ipairs(owned.placed) do add(entry, true) end
	for _, entry in ipairs(owned.inventory) do add(entry, false) end
	table.sort(cars, function(a, b) return a.topSpeed > b.topSpeed end)
	return cars
end

local function openPicker()
	if racing then return end
	View.ShowPicker(carList(), function(itemName)
		View.HidePicker()
		startRemote:FireServer(itemName)
	end)
end

ProximityPromptService.PromptTriggered:Connect(function(prompt)
	if prompt.Name == "ChooseCar" then
		openPicker()
	end
end)

eventRemote.OnClientEvent:Connect(function(event)
	if type(event) ~= "table" then return end
	local kind = event.kind
	if kind == "arrived" then
		racing = false
		View.HideHud()
		openPicker()
	elseif kind == "countdown" then
		racing = true
		topSpeed = event.topSpeed or 0
		View.HidePicker()
		View.ShowHud(#RaceConfig.Levels)
		View.Countdown(event.seconds or 3)
	elseif kind == "cleared" then
		local level = RaceConfig.Levels[event.level]
		View.Banner(string.format("LEVEL %d CLEARED!", event.level),
			event.crate and string.format("%s crate won — it's in your Inventory", level and level.name or "A")
				or "Your crate shelf is full — open some crates",
			View.Colours.green)
	elseif kind == "caught" then
		racing = false
		View.HideHud()
		View.Banner("CAUGHT!", event.cleared > 0
			and string.format("You cleared %d level%s", event.cleared, event.cleared == 1 and "" or "s")
			or "It got you on Level 1 — try a faster car", View.Colours.red)
	elseif kind == "finished" then
		racing = false
		View.HideHud()
		View.Banner("YOU ESCAPED!", "Every level cleared", View.Colours.gold)
	elseif kind == "bailed" then
		racing = false
		View.HideHud()
		View.Banner("BAILED OUT", event.cleared > 0 and string.format("You kept %d crate%s", event.cleared, event.cleared == 1 and "" or "s") or nil, View.Colours.white)
	elseif kind == "ended" then
		racing = false
		View.HideHud()
	end
end)

-- The running numbers, every frame while racing.
RunService.RenderStepped:Connect(function()
	if not racing then return end
	local levelIndex = player:GetAttribute("RaceLevel") or 1
	local distance = player:GetAttribute("RaceDistance") or 0
	local gap = player:GetAttribute("RaceGap") or RaceConfig.MAX_GAP
	local level = RaceConfig.Levels[levelIndex] or RaceConfig.Levels[1]

	local speed = 0
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local seat = humanoid and humanoid.SeatPart
	local chassis = seat and seat.Parent and seat.Parent:FindFirstChild("Chassis")
	if chassis then
		speed = chassis.AssemblyLinearVelocity:Dot(chassis.CFrame.LookVector)
	end

	View.UpdateHud({
		level = levelIndex,
		levelName = level.name,
		progress = distance / trackLength,
		monsterProgress = (distance - gap) / trackLength,
		gap = gap,
		speed = speed,
		topSpeed = topSpeed,
	})
end)
