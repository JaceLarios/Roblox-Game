--[[
	WelcomeBack (LocalScript, StarterPlayerScripts) — Junkyard Fusion

	The "welcome back" popup: what your earning pads made while you were
	away (PlotManager's offline earnings: half the usual rate, for up to
	two hours), already added to your coins. The server sends it once, a
	moment after you join, and only when there was something to earn.
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Garage = require(ReplicatedStorage:WaitForChild("GarageTheme"))
local Style = require(ReplicatedStorage:WaitForChild("UIStyle"))
local welcomeBack = ReplicatedStorage:WaitForChild("WelcomeBack")

local player = Players.LocalPlayer

local INK = Style.Palette.Ink
local GOLD = Style.Palette.Gold

local function commas(n)
	local text = tostring(math.floor(n))
	while true do
		local next, count = text:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
		text = next
		if count == 0 then break end
	end
	return text
end

-- "3 days", "2h 05m" or "14m".
local function duration(seconds)
	if seconds >= 2 * 86400 then
		return string.format("%d days", seconds // 86400)
	elseif seconds >= 3600 then
		return string.format("%dh %02dm", seconds // 3600, seconds % 3600 // 60)
	end
	return string.format("%dm", math.max(1, seconds // 60))
end

local gui = Instance.new("ScreenGui")
gui.Name = "WelcomeBack"
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.ResetOnSpawn = false
gui.DisplayOrder = 25
gui:SetAttribute("Designed", true)
gui.Parent = player:WaitForChild("PlayerGui")

local overlay = Instance.new("Frame")
overlay.Name = "Overlay"
overlay.Size = UDim2.fromScale(1, 1)
overlay.BackgroundColor3 = INK
overlay.BackgroundTransparency = 0.6
overlay.Visible = false
overlay.Parent = gui
Style.Modal(overlay)

local panel = Garage.New("Frame", overlay, "WelcomePanel", { BackgroundColor3 = Style.Palette.Cream })
Garage.Canvas(panel, 640, 400)

Garage.Art(panel, "coins", UDim2.fromOffset(18, 8), UDim2.fromOffset(80, 80))
local title = Garage.Text(panel, "Title", "WELCOME BACK!", UDim2.fromOffset(106, 16), UDim2.fromOffset(420, 62), 40)
title.TextXAlignment = Enum.TextXAlignment.Left
local away = Garage.Text(panel, "Away", "", UDim2.fromOffset(30, 110), UDim2.new(1, -60, 0, 36), 26)
local earned = Garage.Text(panel, "Earned", "", UDim2.fromOffset(30, 156), UDim2.new(1, -60, 0, 80), 60, GOLD)
earned.TextScaled = true
local earnedOutline = Instance.new("UIStroke")
earnedOutline.Color = INK
earnedOutline.Thickness = 3
earnedOutline.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
earnedOutline.Parent = earned
local note = Garage.Text(panel, "Note", "", UDim2.fromOffset(30, 246), UDim2.new(1, -60, 0, 52), 20)
local ok = Garage.New("TextButton", panel, "Ok", {
	Text = "NICE!", TextSize = 30, Font = Enum.Font.FredokaOne,
	AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 312), Size = UDim2.fromOffset(240, 64), ZIndex = 6,
})

Garage.Shell(panel)
Garage.Header(title)
Garage.Button(ok, Color3.fromRGB(40, 200, 110))

welcomeBack.OnClientEvent:Connect(function(info)
	if type(info) ~= "table" or type(info.coins) ~= "number" or info.coins <= 0 then return end
	away.Text = string.format("You were away for %s.", duration(info.away or 0))
	earned.Text = "+" .. commas(info.coins) .. " coins"
	note.Text = (info.away or 0) > (info.counted or 0)
		and "Your earning pads kept going at half speed for the first 2 hours."
		or "Your earning pads kept going at half speed while you were gone."
	overlay.Visible = true
end)

ok.Activated:Connect(function()
	overlay.Visible = false
end)
