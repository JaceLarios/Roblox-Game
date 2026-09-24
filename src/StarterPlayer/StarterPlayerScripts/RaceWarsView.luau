--[[
	RaceWarsView (ModuleScript, StarterPlayerScripts) — Junkyard Fusion

	How Race Wars looks on screen: the lobby panel (next race, the
	line-up, your car), the Race Garage car picker, the race HUD (level,
	place, progress, the monster's gap, speed) and the big countdown and
	result banners. RaceWarsUI.client (the controller) decides WHEN
	and with WHAT; this module owns 100% of the look, so it can be
	restyled without touching any race logic. Built with GarageTheme, the
	same kit as the Shop.

	The controller calls:
	  View.ShowPicker(cars, chosen, onPick)   cars: { name, topSpeed, reach, reachName, onPad }
	  View.HidePicker()  View.PickerOpen()
	  View.UpdateLobby(info)  View.HideLobby()  View.OnChooseCar(callback)
	  View.ShowHud(levelCount)  View.UpdateHud(info)  View.HideHud()
	  View.Countdown(seconds)  View.Banner(title, subtitle, colour)
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local Garage = require(ReplicatedStorage:WaitForChild("GarageTheme"))
local UIStyle = require(ReplicatedStorage:WaitForChild("UIStyle"))
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
-- A menu like the others: opening it closes any other and hides the nav
-- buttons, which would otherwise draw over it.
UIStyle.Modal(overlay)
local picker = Garage.New("Frame", overlay, "RaceGarage", { AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5) })
-- The garage fills the whole screen: scaled so it is about 520 units tall
-- (bigger on a big screen, never too small to read on a phone), then
-- stretched to the screen's full width at that scale.
local pickerScale = Instance.new("UIScale")
pickerScale.Parent = picker
local function fitPicker()
	local v = gui.AbsoluteSize
	if v.X < 100 or v.Y < 100 then return end
	local s = math.clamp((v.Y - 16) / 520, 0.62, 1.4)
	pickerScale.Scale = s
	picker.Size = UDim2.fromOffset((v.X - 16) / s, (v.Y - 16) / s)
end
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitPicker)
fitPicker()

local title = Garage.Text(picker, "Title", "RACE GARAGE", UDim2.fromOffset(18, 14), UDim2.fromOffset(420, 62), 44, WHITE)
title.TextXAlignment = Enum.TextXAlignment.Left
local subtitle = Garage.Text(picker, "Subtitle", "Pick the car you race in next. Racing never uses it up.",
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

function View.ShowPicker(cars, chosen, onPick)
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

		local isChosen = car.name == chosen
		local go = Garage.New("TextButton", card, "Pick", {
			Text = isChosen and "RACING THIS" or "PICK", TextSize = 26, Font = Enum.Font.FredokaOne,
			Position = UDim2.new(0, 9, 1, -58), Size = UDim2.new(1, -18, 0, 48), ZIndex = 5,
		})
		Garage.Button(go, isChosen and GREEN or car.reach > 0 and GOLD or Color3.fromRGB(121, 154, 200))
		go.Activated:Connect(function()
			onPick(car.name)
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
local hudScale = Instance.new("UIScale")
hudScale.Parent = hud

local levelLabel = Garage.Text(hud, "Level", "LEVEL 1", UDim2.fromOffset(16, 6), UDim2.new(1, -32, 0, 34), 28, WHITE)
stroke(levelLabel, 2.5)
levelLabel.TextScaled = true

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

local hint = Garage.Text(gui, "BailHint", "", UDim2.new(0.5, -200, 1, -130), UDim2.fromOffset(400, 24), 17, WHITE)
stroke(hint, 2)
hint.Visible = false
local function hintText()
	if UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled then
		return "Thumbstick drives and steers · Jump bails out"
	end
	return "W/S drive · A/D steer · Space bails out"
end

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
	hint.Text = hintText()
	hint.Visible = true
end

function View.HideHud()
	hud.Visible = false
	speedo.Visible = false
	hint.Visible = false
end

-- info: level, levelName, place ("2ND / 5", or nil racing alone),
-- progress and monsterProgress (0 to 1 along the whole track), gap
-- (studs), monsterSpeed, speed, topSpeed.
function View.UpdateHud(info)
	levelLabel.Text = string.format("LEVEL %d · %s", info.level, string.upper(info.levelName))
		.. (info.place and "  ·  " .. info.place or "")
	fill.Size = UDim2.fromScale(math.clamp(info.progress, 0, 1), 1)
	carMarker.Position = UDim2.fromScale(math.clamp(info.progress, 0, 1), 0.5)
	monsterMarker.Position = UDim2.fromScale(math.clamp(info.monsterProgress, 0, 1), 0.5)
	local danger = info.gap < 35
	gapLabel.Text = string.format("MONSTER %d STUDS BEHIND · SPEED %d", math.max(0, math.floor(info.gap)), info.monsterSpeed)
	gapLabel.TextColor3 = danger and Color3.fromRGB(255, 120, 110) or WHITE
	hud.BackgroundColor3 = danger and Color3.fromRGB(90, 16, 20):Lerp(INK, (math.sin(os.clock() * 12) + 1) / 2) or INK
	speedLabel.Text = tostring(math.max(0, math.floor(info.speed)))
	speedUnit.Text = string.format("/ %d\nTOP", math.floor(info.topSpeed))
end

------------------------------------------------------------------
-- The lobby panel
------------------------------------------------------------------

local lobby = Garage.New("Frame", gui, "RaceLobby", {
	AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 10), Size = UDim2.fromOffset(460, 150),
	BackgroundColor3 = INK, BackgroundTransparency = 0.2, Visible = false,
})
Garage.New("UICorner", lobby, "Corner", { CornerRadius = UDim.new(0, 18) })
local lobbyScale = Instance.new("UIScale")
lobbyScale.Parent = lobby

local nextLabel = Garage.Text(lobby, "NextRace", "", UDim2.fromOffset(16, 8), UDim2.new(1, -32, 0, 42), 36, WHITE)
nextLabel.TextScaled = true
stroke(nextLabel, 3)
local statusLabel = Garage.Text(lobby, "Status", "", UDim2.fromOffset(16, 52), UDim2.new(1, -32, 0, 28), 22, GOLD)
statusLabel.TextScaled = true
stroke(statusLabel, 2)
local carLabel = Garage.Text(lobby, "Car", "", UDim2.fromOffset(16, 92), UDim2.new(1, -200, 0, 44), 19, WHITE)
carLabel.TextXAlignment = Enum.TextXAlignment.Left
carLabel.TextWrapped = true
carLabel.TextScaled = true
stroke(carLabel, 2)
local chooseButton = Garage.New("TextButton", lobby, "ChooseCar", {
	Text = "CHOOSE CAR", TextSize = 22, Font = Enum.Font.FredokaOne,
	Position = UDim2.new(1, -176, 0, 88), Size = UDim2.fromOffset(160, 50), ZIndex = 5,
})
Garage.Button(chooseButton, GOLD)

-- On a phone on its side the coins sit top centre, so this and the race
-- HUD go just under them, a size that still fits the short screen.
local function fitLobby()
	local v = gui.AbsoluteSize
	if v.Y < 100 then return end
	local phone = Garage.IsPhone(v)
	lobbyScale.Scale = phone and 0.8 or v.X < 1000 and math.clamp(v.X / 760, 0.85, 1.15) or 1
	lobby.Position = UDim2.new(0.5, 0, 0, phone and 72 or 10)
	hud.Position = UDim2.new(0.5, 0, 0, phone and 72 or 10)
	hudScale.Scale = phone and 0.8 or 1
end
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitLobby)
fitLobby()

local function clock(seconds)
	seconds = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

-- info: secondsLeft (to the next race), running (a race is on now),
-- inLine (how many are lined up), queued (whether you are), carName and
-- carSpeed (what you would race in, or nil with no car).
function View.UpdateLobby(info)
	if overlay.Visible or UIStyle.ModalOpen() then
		lobby.Visible = false
		return
	end
	lobby.Visible = true
	nextLabel.Text = (info.running and "RACE ON! · NEXT " or "NEXT RACE ") .. clock(info.secondsLeft)
	local others = info.inLine == 1 and "1 in line" or string.format("%d in line", info.inLine)
	if not info.carName then
		statusLabel.Text = "You need a car to race"
		statusLabel.TextColor3 = Color3.fromRGB(255, 150, 140)
	elseif info.queued then
		statusLabel.Text = "YOU'RE IN LINE! · " .. others
		statusLabel.TextColor3 = GREEN
	else
		statusLabel.Text = "Stand in the yellow box to join · " .. others
		statusLabel.TextColor3 = GOLD
	end
	carLabel.Text = info.carName
		and string.format("Racing in: %s · top speed %d", ItemNames.Display(info.carName), math.floor(info.carSpeed))
		or "Grab a car off the Junkyard conveyor"
end

function View.HideLobby()
	lobby.Visible = false
end

function View.OnChooseCar(callback)
	chooseButton.Activated:Connect(callback)
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
	-- Smaller and lower on a phone on its side, clear of the race HUD.
	local phone = Garage.IsPhone(gui.AbsoluteSize)
	banner.Position = UDim2.fromScale(0.5, phone and 0.6 or 0.38)
	local full = phone and 0.62 or 1
	bannerScale.Scale = 0.4 * full
	TweenService:Create(bannerScale, TweenInfo.new(0.25, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = full }):Play()
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
