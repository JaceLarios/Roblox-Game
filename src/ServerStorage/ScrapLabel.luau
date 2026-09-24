--[[
	ScrapLabel (ModuleScript, ServerStorage) — Junkyard Fusion

	The floating name over an item lying loose in the world, in one place.
	The spawner's drops, the crane's crate prizes and anything a player
	drops or gets knocked out of their hands all wear this same label, so
	they read as the same kind of thing: loot you can grab.

	Same controller/view split as FusionEffects and PickupEffects: the
	scripts that make items decide when a label goes on; this decides how
	it looks.
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local FusionRecipes = require(ReplicatedStorage:WaitForChild("FusionRecipes"))
local ItemRarity = require(ReplicatedStorage:WaitForChild("ItemRarity"))
local Mutations = require(ReplicatedStorage:WaitForChild("Mutations"))
local ItemNames = require(ReplicatedStorage:WaitForChild("ItemNames"))

local ScrapLabel = {}

-- Rounded, bubbly lettering with a dark outline, matching the menus.
local FONT = Enum.Font.FredokaOne
local OUTLINE = Color3.fromRGB(22, 26, 36)
local OUTLINE_THICKNESS = 2

-- The colour a loose item's name reads in: its mutation's colour when it
-- has one, otherwise its rarity's.
function ScrapLabel.Colour(itemName)
	local baseName, mutationId = Mutations.Unwrap(itemName)
	return Mutations.Color(mutationId)
		or ItemRarity.Color(FusionRecipes.GetTier(baseName), false, FusionRecipes.GetRarity(baseName))
end

function ScrapLabel.Attach(part, itemName)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ScrapLabel"
	billboard.Size = UDim2.new(0, 160, 0, 34)
	billboard.StudsOffset = Vector3.new(0, 2, 0)
	billboard.AlwaysOnTop = true
	-- Billboards hold a constant SCREEN size regardless of distance, so
	-- without a cutoff every drop across the whole yard stays fully
	-- legible at once and piles into an unreadable wall of text.
	billboard.MaxDistance = 45
	billboard.Parent = part

	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Font = FONT
	label.Text = ItemNames.Display(itemName)
	label.TextColor3 = ScrapLabel.Colour(itemName)
	label.TextStrokeTransparency = 1
	label.TextScaled = true
	label.Parent = billboard

	-- A UIStroke outlines the letters themselves, which is what gives the
	-- chunky cartoon look; TextStroke draws a thinner, fuzzier edge.
	local stroke = Instance.new("UIStroke")
	stroke.Color = OUTLINE
	stroke.Thickness = OUTLINE_THICKNESS
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	stroke.Parent = label

	return billboard
end

-- A countdown under a dropped item's name, ticking down the seconds until
-- it despawns: white, then red for the last ten. The caller despawns it;
-- this only shows how long is left.
function ScrapLabel.Countdown(part, seconds)
	local billboard = part:FindFirstChild("ScrapLabel")
	if not billboard then return end
	billboard.Size = UDim2.new(0, 160, 0, 56)
	local name = billboard:FindFirstChildOfClass("TextLabel")
	if name then name.Size = UDim2.fromScale(1, 0.6) end

	local timer = Instance.new("TextLabel")
	timer.Name = "Countdown"
	timer.Position = UDim2.fromScale(0, 0.6)
	timer.Size = UDim2.fromScale(1, 0.4)
	timer.BackgroundTransparency = 1
	timer.Font = FONT
	timer.TextScaled = true
	timer.TextColor3 = Color3.new(1, 1, 1)
	timer.Parent = billboard
	local stroke = Instance.new("UIStroke")
	stroke.Color = OUTLINE
	stroke.Thickness = OUTLINE_THICKNESS
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	stroke.Parent = timer

	task.spawn(function()
		for left = seconds, 1, -1 do
			if not timer.Parent then return end
			timer.Text = string.format("%ds", left)
			timer.TextColor3 = left <= 10 and Color3.fromRGB(255, 90, 80) or Color3.new(1, 1, 1)
			task.wait(1)
		end
	end)
end

return ScrapLabel
