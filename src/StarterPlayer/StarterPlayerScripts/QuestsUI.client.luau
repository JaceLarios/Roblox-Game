--[[
	QuestsUI (LocalScript, StarterPlayerScripts) — Junkyard Fusion

	The QUESTS button (left rail, under REWARDS) and its panel: today's three
	daily quests, how far along each one is and what it pays, the bonus
	bolts for finishing all three, and when new ones come. The server
	picks, counts and pays them (DailyQuests, PlotManager); this only shows
	what GameUpdate sends as `quests`. A quest pays the moment it is done,
	so there is nothing to claim here.
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Garage = require(ReplicatedStorage:WaitForChild("GarageTheme"))
local NavButton = require(ReplicatedStorage:WaitForChild("NavButton"))
local Style = require(ReplicatedStorage:WaitForChild("UIStyle"))
local gameUpdate = ReplicatedStorage:WaitForChild("GameUpdate")

local player = Players.LocalPlayer

local INK = Style.Palette.Ink
local GOLD = Style.Palette.Gold
local GREEN = Color3.fromRGB(40, 200, 110)
local TRACK = Color3.fromRGB(214, 206, 186)
-- Drawn for this button (assets/ui/draw_quests_icon.py): the atlas has no
-- quests picture.
local QUEST_ICON = "rbxassetid://91112768809450"

local WIDTH, HEIGHT = 860, 600

local function commas(n)
	local text = tostring(math.floor(n))
	while true do
		local next, count = text:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
		text = next
		if count == 0 then break end
	end
	return text
end

local function clock(seconds)
	seconds = math.max(0, math.floor(seconds))
	return string.format("%d:%02d:%02d", seconds // 3600, seconds % 3600 // 60, seconds % 60)
end

local gui = Instance.new("ScreenGui")
gui.Name = "QuestsUI"
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.ResetOnSpawn = false
gui.DisplayOrder = 20
gui:SetAttribute("Designed", true)
gui.Parent = player:WaitForChild("PlayerGui")

-- Second on the left rail, under REWARDS (INDEX got a stand, and the
-- INVENTORY button went with the Inventory panel).
local open = NavButton.Create(gui, "", "QUESTS", GOLD, NavButton.RailPosition("left", 2))
local railArt = open:FindFirstChild("Illustration")
if railArt then
	railArt.Image = QUEST_ICON
	railArt.ImageRectOffset = Vector2.zero
	railArt.ImageRectSize = Vector2.zero
end

local overlay = Instance.new("Frame")
overlay.Name = "Overlay"
overlay.Size = UDim2.fromScale(1, 1)
overlay.BackgroundColor3 = INK
overlay.BackgroundTransparency = 0.7
overlay.Visible = false
overlay.Parent = gui
Style.Modal(overlay)

local panel = Garage.New("Frame", overlay, "QuestsPanel", { BackgroundColor3 = Style.Palette.Cream })
Garage.Canvas(panel, WIDTH, HEIGHT)

local icon = Garage.New("ImageLabel", panel, "Icon", {
	Image = QUEST_ICON, BackgroundTransparency = 1, ScaleType = Enum.ScaleType.Fit,
	Position = UDim2.fromOffset(18, 10), Size = UDim2.fromOffset(80, 80), ZIndex = 5,
})
local title = Garage.Text(panel, "Title", "DAILY QUESTS", UDim2.fromOffset(106, 16), UDim2.fromOffset(420, 62), 40)
title.TextXAlignment = Enum.TextXAlignment.Left
local close = Garage.New("TextButton", panel, "Close", {
	Text = "X", TextSize = 30, Font = Enum.Font.FredokaOne,
	AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -20, 0, 18), Size = UDim2.fromOffset(64, 56), ZIndex = 6,
})

-- One card per quest.
local cards = {}
for i = 1, 3 do
	local card = Garage.New("Frame", panel, "Quest" .. i, {
		Position = UDim2.fromOffset(24, 108 + (i - 1) * 138), Size = UDim2.new(1, -48, 0, 124),
	})
	Garage.Inset(card)
	local text = Garage.Text(card, "Task", "", UDim2.fromOffset(22, 12), UDim2.new(1, -290, 0, 44), 28)
	text.TextXAlignment = Enum.TextXAlignment.Left
	text.TextScaled = true
	local bar = Garage.New("Frame", card, "Bar", {
		Position = UDim2.fromOffset(22, 70), Size = UDim2.new(1, -290, 0, 34), BackgroundColor3 = TRACK, ZIndex = 4,
	})
	Garage.New("UICorner", bar, "Corner", { CornerRadius = UDim.new(0, 17) })
	local fill = Garage.New("Frame", bar, "Fill", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = GOLD, ZIndex = 5 })
	Garage.New("UICorner", fill, "Corner", { CornerRadius = UDim.new(0, 17) })
	local count = Garage.Text(bar, "Count", "", UDim2.new(), UDim2.fromScale(1, 1), 22)
	count.ZIndex = 6
	local reward = Garage.Text(card, "Reward", "", UDim2.new(1, -250, 0, 30), UDim2.fromOffset(228, 60), 26)
	reward.TextScaled = true
	Garage.Plate(reward)
	cards[i] = { card = card, text = text, fill = fill, count = count, reward = reward }
end

local bonus = Garage.Text(panel, "Bonus", "", UDim2.fromOffset(26, 524), UDim2.new(1, -300, 0, 40), 22)
bonus.TextXAlignment = Enum.TextXAlignment.Left
bonus.TextScaled = true
local resets = Garage.Text(panel, "Resets", "", UDim2.new(1, -270, 0, 524), UDim2.fromOffset(246, 40), 20)
resets.TextXAlignment = Enum.TextXAlignment.Right

Garage.Shell(panel)
Garage.Header(title)

------------------------------------------------------------------
-- Filling it in
------------------------------------------------------------------

local quests = nil
local receivedAt = 0

local function redraw()
	if not quests then return end
	for i, view in ipairs(cards) do
		local quest = quests.list[i]
		view.card.Visible = quest ~= nil
		if quest then
			view.text.Text = quest.text
			view.fill.Size = UDim2.fromScale(math.clamp(quest.progress / math.max(quest.goal, 1), 0, 1), 1)
			view.fill.BackgroundColor3 = quest.done and GREEN or GOLD
			view.count.Text = quest.done and "DONE!" or string.format("%d / %d", quest.progress, quest.goal)
			view.reward.Text = quest.done and "PAID ✓" or ("+" .. commas(quest.reward) .. " coins")
			view.reward.BackgroundColor3 = quest.done and Color3.fromRGB(190, 240, 200) or Color3.fromRGB(255, 244, 211)
		end
	end
	bonus.Text = quests.bonusCrate
		and "All three done — you won 5 bonus bolts!"
		or "Finish all three for 5 bonus bolts!"
end

local function tick()
	if quests then
		resets.Text = "New quests in " .. clock(quests.resetsIn - (os.clock() - receivedAt))
	end
end

gameUpdate.OnClientEvent:Connect(function(data)
	if type(data) == "table" and type(data.quests) == "table" then
		quests = data.quests
		receivedAt = os.clock()
		redraw()
		tick()
	end
end)

task.spawn(function()
	while true do
		task.wait(1)
		if overlay.Visible then tick() end
	end
end)

open.MouseButton1Click:Connect(function()
	overlay.Visible = not overlay.Visible
end)
close.Activated:Connect(function()
	overlay.Visible = false
end)
