--[[
	RaceWarsView (ModuleScript, StarterPlayerScripts) — Junkyard Fusion

	How Race Wars looks on screen: the Race Garage car picker, the race
	HUD (level, progress, the monster's gap, speed) and the big countdown
	and result banners. RaceWarsUI.client (the controller) decides WHEN
	and with WHAT; this module owns 100% of the look, so it can be
	restyled without touching any race logic. Built with GarageTheme, the
	same kit as the Shop.

	The controller calls:
	  View.ShowPicker(cars, onRace)   cars: { name, topSpeed, reach, reachName, onPad }
	  View.HidePicker()  View.PickerOpen()
	  View.ShowHud(levelCount)  View.UpdateHud(info)  View.HideHud()
	  View.Countdown(seconds)  View.Banner(title, subtitle, colour)
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")

local Garage = require(ReplicatedStorage:WaitForChild("GarageTheme"))
local ItemVisuals = require(ReplicatedStorage:WaitForChild("ItemVisuals"))
local ItemNames = require(ReplicatedStorage:WaitForChild("ItemNames"))
local Mutations = require(ReplicatedStorage:WaitForChild("Mutations"))

local View = {}

local player = Players.LocalPlayer
local INK = Color3.fromRGB(8, 43, 77)
local GOLD = Color3.fromRGB(255, 199, 47)
local RED = Color3.fromRGB(230, 50, 50)
local GREEN = Color3.fromRGB(40, 210, 110)
local WHITE = Color3.new(1, 1, 1)
local PEDESTAL = Color3.fromRGB(59, 229, 204)

local gui = Instance.new("ScreenGui")
gui.Name = "RaceWarsUI"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.DisplayOrder = 15
gui.Parent = player:WaitForChild("PlayerGui")

local function stroke(label, thickness)
	local s = Instance.new("UIStroke")
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	s.Color = INK
	s.Thickness = thickness or 2
	s.Parent = label
	return s
end

------------------------------------------------------------------
-- The Race Garage picker
------------------------------------------------------------------

local overlay = Garage.New("Frame", gui, "PickerOverlay", {
	Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(), BackgroundTransparency = 0.6, Visible = false,
})
local picker = Garage.New("Frame", overlay, "RaceGarage", {})
Garage.Canvas(picker, 1100, 700)

local title = Garage.Text(picker, "Title", "RACE GARAGE", UDim2.fromOffset(18, 14), UDim2.fromOffset(420, 62), 44, WHITE)
title.TextXAlignment = Enum.TextXAlignment.Left
local subtitle = Garage.Text(picker, "Subtitle", "Pick a car to race. Racing never uses it up.",
	UDim2.fromOffset(456, 20), UDim2.new(1, -560, 0, 50), 21, WHITE)
subtitle.TextXAlignment = Enum.TextXAlignment.Left
stroke(subtitle, 2)
local close = Garage.New("TextButton", picker, "Close", {
	Text = "X", Position = UDim2.new(1, -76, 0, 16), Size = UDim2.fromOffset(58, 58), TextSize = 30, Font = Enum.Font.FredokaOne,
})

local list = Garage.New("ScrollingFrame", picker, "Cars", {
	Position = UDim2.fromOffset(18, 100), Size = UDim2.new(1, -36, 1, -118), BackgroundTransparency = 1,
	BorderSizePixel = 0, ScrollBarThickness = 7, ScrollBarImageColor3 = INK,
	AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(),
})
Garage.New("UIPadding", list, "Padding", { PaddingTop = UDim.new(0, 4), PaddingRight = UDim.new(0, 10) })
Garage.New("UIGridLayout", list, "Grid", {
	CellSize = UDim2.new(0.25, -12, 0, 318), CellPadding = UDim2.fromOffset(12, 12), SortOrder = Enum.SortOrder.LayoutOrder,
})
local empty = Garage.Text(picker, "Empty", "You have no cars yet — grab one off the conveyor in the Junkyard, or fuse one.",
	UDim2.fromOffset(40, 300), UDim2.new(1, -80, 0, 80), 26, WHITE)
stroke(empty, 3)
empty.Visible = false

Garage.Header(title)
Garage.Shell(picker)

local spinning = {}

local function modelView(card, itemName)
	local view = Garage.New("ViewportFrame", card, "Model", {
		BackgroundTransparency = 1, Position = UDim2.fromOffset(8, 8), Size = UDim2.new(1, -16, 0, 150),
		Ambient = Color3.fromRGB(205, 205, 215), LightColor = WHITE, LightDirection = Vector3.new(-1, -1, -1), ZIndex = 3,
	})
	local baseName, mutationId = Mutations.Unwrap(itemName)
	local model, size = ItemVisuals.CloneForViewport(baseName)
	if not model then return end
	local world = Instance.new("WorldModel")
	world.Parent = view
	model.Parent = world
	Garage.Podium(model, Mutations.Color(mutationId) or PEDESTAL)
	local camera = Instance.new("Camera")
	camera.FieldOfView = 35
	camera.Parent = view
	view.CurrentCamera = camera
	local reach = math.max(size.X, size.Y, size.Z) * 1.7 + 0.2
	camera.CFrame = CFrame.lookAt(Vector3.new(0.6, 0.45, 0.9) * reach, Vector3.zero)
	table.insert(spinning, { model = model, base = model:GetPivot() })
end

function View.ShowPicker(cars, onRace)
	for _, child in ipairs(list:GetChildren()) do
		if child:IsA("GuiObject") then child:Destroy() end
	end
	table.clear(spinning)
	empty.Visible = #cars == 0

	for order, car in ipairs(cars) do
		local card = Garage.New("Frame", list, "Car" .. order, { LayoutOrder = order })
		Garage.Inset(card)
		modelView(card, car.name)

		local name = Garage.Text(card, "CarName", ItemNames.Display(car.name), UDim2.new(0, 8, 0, 160), UDim2.new(1, -16, 0, 34), 22)
		Garage.Plate(name)
		name.TextScaled = true

		local speed = Garage.Text(card, "TopSpeed", string.format("TOP SPEED  %d", math.floor(car.topSpeed)),
			UDim2.new(0, 8, 0, 198), UDim2.new(1, -16, 0, 26), 21, WHITE)
		stroke(speed, 2)

		local reachText = car.reach > 0 and string.format("Reaches Level %d · %s", car.reach, car.reachName) or "Too slow for Level 1"
		local reach = Garage.Text(card, "Reach", reachText, UDim2.new(0, 8, 0, 224), UDim2.new(1, -16, 0, 24), 17,
			car.reach > 0 and Color3.fromRGB(150, 255, 170) or Color3.fromRGB(255, 170, 160))
		stroke(reach, 2)
		reach.TextScaled = true

		if car.onPad then
			local badge = Garage.Text(card, "OnPad", "ON A PAD", UDim2.new(1, -96, 0, 10), UDim2.fromOffset(86, 22), 15, WHITE)
			badge.BackgroundTransparency = 0
			badge.BackgroundColor3 = INK
			badge.ZIndex = 6
		end

		local go = Garage.New("TextButton", card, "Race", {
			Text = "RACE!", TextSize = 26, Font = Enum.Font.FredokaOne,
			Position = UDim2.new(0, 9, 1, -58), Size = UDim2.new(1, -18, 0, 48), ZIndex = 5,
		})
		Garage.Button(go, car.reach > 0 and GOLD or Color3.fromRGB(121, 154, 200))
		go.Activated:Connect(function()
			onRace(car.name)
		end)
	end
	overlay.Visible = true
end

function View.HidePicker()
	overlay.Visible = false
end

function View.PickerOpen()
	return overlay.Visible
end

close.Activated:Connect(View.HidePicker)

RunService.RenderStepped:Connect(function()
	if not overlay.Visible then return end
	local angle = os.clock() * 0.6
	for _, s in ipairs(spinning) do
		s.model:PivotTo(CFrame.Angles(0, angle, 0) * s.base)
	end
end)

------------------------------------------------------------------
-- The race HUD
------------------------------------------------------------------

local hud = Garage.New("Frame", gui, "RaceHud", {
	AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 10), Size = UDim2.fromOffset(620, 104),
	BackgroundColor3 = INK, BackgroundTransparency = 0.25, Visible = false,
})
Garage.New("UICorner", hud, "Corner", { CornerRadius = UDim.new(0, 18) })

local levelLabel = Garage.Text(hud, "Level", "LEVEL 1", UDim2.fromOffset(16, 6), UDim2.new(1, -32, 0, 34), 28, WHITE)
stroke(levelLabel, 2.5)

local bar = Garage.New("Frame", hud, "Progress", {
	Position = UDim2.fromOffset(20, 46), Size = UDim2.new(1, -40, 0, 14), BackgroundColor3 = Color3.fromRGB(30, 60, 96),
})
Garage.New("UICorner", bar, "Corner", { CornerRadius = UDim.new(1, 0) })
local fill = Garage.New("Frame", bar, "Fill", { Size = UDim2.fromScale(0, 1), BackgroundColor3 = GREEN })
Garage.New("UICorner", fill, "Corner", { CornerRadius = UDim.new(1, 0) })
local ticks = Garage.New("Frame", bar, "Ticks", { Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1 })

local function marker(name, colour, text)
	local m = Garage.New("TextLabel", bar, name, {
		AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0, 0.5), Size = UDim2.fromOffset(28, 28),
		BackgroundColor3 = colour, Text = text, TextSize = 16, Font = Enum.Font.FredokaOne, TextColor3 = WHITE, ZIndex = 3,
	})
	Garage.New("UICorner", m, "Corner", { CornerRadius = UDim.new(1, 0) })
	local ring = Instance.new("UIStroke")
	ring.Color = WHITE
	ring.Thickness = 2
	ring.Parent = m
	return m
end
local monsterMarker = marker("Monster", RED, "!")
local carMarker = marker("Car", GOLD, "▲")
carMarker.TextColor3 = INK

local gapLabel = Garage.Text(hud, "Gap", "", UDim2.fromOffset(16, 68), UDim2.new(1, -32, 0, 28), 21, WHITE)
stroke(gapLabel, 2)

local speedo = Garage.New("Frame", gui, "Speedometer", {
	AnchorPoint = Vector2.new(0.5, 1), Position = UDim2.new(0.5, 0, 1, -24), Size = UDim2.fromOffset(240, 78),
	BackgroundColor3 = INK, BackgroundTransparency = 0.25, Visible = false,
})
Garage.New("UICorner", speedo, "Corner", { CornerRadius = UDim.new(0, 18) })
local speedLabel = Garage.Text(speedo, "Speed", "0", UDim2.fromOffset(10, 2), UDim2.new(0.55, -10, 1, -4), 48, WHITE)
speedLabel.TextXAlignment = Enum.TextXAlignment.Right
stroke(speedLabel, 3)
local speedUnit = Garage.Text(speedo, "Unit", "/ 0\nTOP", UDim2.new(0.55, 8, 0, 8), UDim2.new(0.45, -16, 1, -16), 18, Color3.fromRGB(190, 215, 240))
speedUnit.TextXAlignment = Enum.TextXAlignment.Left

local hint = Garage.Text(gui, "BailHint", "W/S drive · A/D steer · Space bails out", UDim2.new(0.5, -200, 1, -130), UDim2.fromOffset(400, 24), 17, WHITE)
stroke(hint, 2)
hint.Visible = false

function View.ShowHud(levelCount)
	for _, child in ipairs(ticks:GetChildren()) do child:Destroy() end
	for i = 1, levelCount - 1 do
		Garage.New("Frame", ticks, "Tick", {
			AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(i / levelCount, 0.5), Size = UDim2.fromOffset(3, 20),
			BackgroundColor3 = WHITE, BackgroundTransparency = 0.3, ZIndex = 2,
		})
	end
	hud.Visible = true
	speedo.Visible = true
	hint.Visible = true
end

function View.HideHud()
	hud.Visible = false
	speedo.Visible = false
	hint.Visible = false
end

-- info: level, levelName, progress and monsterProgress (0 to 1 along the
-- whole track), gap (studs), speed, topSpeed.
function View.UpdateHud(info)
	levelLabel.Text = string.format("LEVEL %d · %s", info.level, string.upper(info.levelName))
	fill.Size = UDim2.fromScale(math.clamp(info.progress, 0, 1), 1)
	carMarker.Position = UDim2.fromScale(math.clamp(info.progress, 0, 1), 0.5)
	monsterMarker.Position = UDim2.fromScale(math.clamp(info.monsterProgress, 0, 1), 0.5)
	local danger = info.gap < 35
	gapLabel.Text = string.format("MONSTER %d STUDS BEHIND", math.max(0, math.floor(info.gap)))
	gapLabel.TextColor3 = danger and Color3.fromRGB(255, 120, 110) or WHITE
	hud.BackgroundColor3 = danger and Color3.fromRGB(90, 16, 20):Lerp(INK, (math.sin(os.clock() * 12) + 1) / 2) or INK
	speedLabel.Text = tostring(math.max(0, math.floor(info.speed)))
	speedUnit.Text = string.format("/ %d\nTOP", math.floor(info.topSpeed))
end

------------------------------------------------------------------
-- Countdown and banners
------------------------------------------------------------------

local banner = Garage.New("Frame", gui, "Banner", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.38), Size = UDim2.fromOffset(760, 190),
	BackgroundTransparency = 1, Visible = false,
})
local bannerScale = Instance.new("UIScale")
bannerScale.Parent = banner
local bannerTitle = Garage.Text(banner, "Title", "", UDim2.fromScale(0, 0), UDim2.new(1, 0, 0, 120), 96, WHITE)
bannerTitle.TextScaled = true
local bannerStroke = stroke(bannerTitle, 6)
local bannerSub = Garage.Text(banner, "Subtitle", "", UDim2.new(0, 0, 0, 124), UDim2.new(1, 0, 0, 56), 30, WHITE)
stroke(bannerSub, 3)

local bannerToken = 0

-- Pops a big title (and optional line under it) up for `seconds`.
local function pop(titleText, subText, colour, seconds)
	bannerToken += 1
	local token = bannerToken
	bannerTitle.Text = titleText
	bannerTitle.TextColor3 = colour or WHITE
	bannerStroke.Color = INK
	bannerSub.Text = subText or ""
	banner.Visible = true
	bannerScale.Scale = 0.4
	TweenService:Create(bannerScale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 }):Play()
	task.delay(seconds or 2.5, function()
		if bannerToken == token then
			banner.Visible = false
		end
	end)
end

function View.Countdown(seconds)
	task.spawn(function()
		for n = seconds, 1, -1 do
			pop(tostring(n), nil, GOLD, 1.2)
			task.wait(1)
		end
		pop("GO!", nil, GREEN, 1)
	end)
end

function View.Banner(titleText, subText, colour)
	pop(titleText, subText, colour, 3)
end

View.Colours = { gold = GOLD, red = RED, green = GREEN, white = WHITE }

return View
