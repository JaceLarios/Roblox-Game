--[[
	TradeRequestUI (LocalScript, StarterPlayerScripts) — Junkyard Fusion

	The popup that asks whether you want to trade. Someone picking you in
	their TRADE menu sends a request; this shows who it is with ACCEPT and
	DECLINE and a bar running down, and the trade window only opens once
	you accept. Ignoring it declines when the bar runs out (the server
	times it out and says so).

	Its own script so it sits above every menu and never depends on
	GameUI's trade window. Styled with GarageTheme to match.
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Garage = require(ReplicatedStorage:WaitForChild("GarageTheme"))
local requestRemote = ReplicatedStorage:WaitForChild("TradeRequest")

local player = Players.LocalPlayer
local INK = Color3.fromRGB(8, 43, 77)
local GREEN = Color3.fromRGB(40, 200, 110)
local RED = Color3.fromRGB(226, 60, 60)
local WHITE = Color3.new(1, 1, 1)

local gui = Instance.new("ScreenGui")
gui.Name = "TradeRequestUI"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
-- Above every menu, so a request is never hidden behind an open panel.
gui.DisplayOrder = 40
gui.Parent = player:WaitForChild("PlayerGui")

-- A little below the top, clear of the HUD panels that sit there.
local card = Garage.New("Frame", gui, "TradeRequest", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.36), Size = UDim2.fromOffset(460, 190),
	Visible = false,
})
Garage.Inset(card)
card.BackgroundTransparency = 0
card.BackgroundColor3 = Color3.fromRGB(28, 120, 196)
local scale = Instance.new("UIScale")
scale.Parent = card

local avatar = Garage.New("ImageLabel", card, "Avatar", {
	Position = UDim2.fromOffset(16, 16), Size = UDim2.fromOffset(84, 84), BackgroundColor3 = Color3.fromRGB(213, 233, 242),
})
Garage.New("UICorner", avatar, "Corner", { CornerRadius = UDim.new(0, 12) })

local title = Garage.Text(card, "Title", "", UDim2.fromOffset(112, 18), UDim2.new(1, -128, 0, 44), 28, WHITE)
title.TextXAlignment = Enum.TextXAlignment.Left
title.TextScaled = true
local titleStroke = Instance.new("UIStroke")
titleStroke.Color = INK
titleStroke.Thickness = 2.5
titleStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
titleStroke.Parent = title
local subtitle = Garage.Text(card, "Subtitle", "wants to trade with you!", UDim2.fromOffset(112, 62), UDim2.new(1, -128, 0, 30), 20, Color3.fromRGB(220, 238, 250))
subtitle.TextXAlignment = Enum.TextXAlignment.Left

local accept = Garage.New("TextButton", card, "Accept", {
	Text = "ACCEPT", TextSize = 26, Font = Enum.Font.FredokaOne,
	Position = UDim2.new(0, 16, 1, -76), Size = UDim2.new(0.5, -22, 0, 56), ZIndex = 5,
})
Garage.Button(accept, GREEN)
local decline = Garage.New("TextButton", card, "Decline", {
	Text = "DECLINE", TextSize = 26, Font = Enum.Font.FredokaOne,
	Position = UDim2.new(0.5, 6, 1, -76), Size = UDim2.new(0.5, -22, 0, 56), ZIndex = 5,
})
Garage.Button(decline, RED)

local barBack = Garage.New("Frame", card, "TimeLeft", {
	Position = UDim2.new(0, 16, 1, -12), Size = UDim2.new(1, -32, 0, 6), BackgroundColor3 = INK,
})
Garage.New("UICorner", barBack, "Corner", { CornerRadius = UDim.new(1, 0) })
local bar = Garage.New("Frame", barBack, "Fill", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.fromRGB(255, 199, 47) })
Garage.New("UICorner", bar, "Corner", { CornerRadius = UDim.new(1, 0) })

local barTween = nil
local shown = 0 -- counts requests, so a stale timeout never hides a newer one

local function hide()
	card.Visible = false
	if barTween then barTween:Cancel() end
end

local function answer(accepted)
	if not card.Visible then return end
	hide()
	requestRemote:FireServer(accepted)
end

accept.Activated:Connect(function() answer(true) end)
decline.Activated:Connect(function() answer(false) end)

-- Bigger on a small screen, where the popup has to be easy to hit with a
-- thumb, but never taller than a phone on its side has room for.
local function fullScale()
	local size = gui.AbsoluteSize
	if Garage.IsPhone(size) then return 1 end
	return size.X < 900 and 1.2 or 1
end
local function fit()
	scale.Scale = fullScale()
end
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
fit()

requestRemote.OnClientEvent:Connect(function(request)
	if type(request) ~= "table" then return end
	if request.kind == "expired" then
		hide()
		return
	end
	if request.kind ~= "request" then return end
	title.Text = request.fromName
	avatar.Image = "rbxthumb://type=AvatarHeadShot&id=" .. tostring(request.fromUserId) .. "&w=150&h=150"
	card.Visible = true
	scale.Scale = fullScale() * 0.6
	TweenService:Create(scale, TweenInfo.new(0.2, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Scale = fullScale() }):Play()
	bar.Size = UDim2.fromScale(1, 1)
	if barTween then barTween:Cancel() end
	barTween = TweenService:Create(bar, TweenInfo.new(request.seconds or 15, Enum.EasingStyle.Linear), { Size = UDim2.fromScale(0, 1) })
	barTween:Play()
	-- The server says when a request runs out; this is only in case that
	-- message never comes.
	shown += 1
	local this = shown
	task.delay((request.seconds or 15) + 2, function()
		if shown == this then hide() end
	end)
end)
