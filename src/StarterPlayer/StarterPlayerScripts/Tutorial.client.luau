--[[
	Tutorial (LocalScript, StarterPlayerScripts) — Junkyard Fusion

	The first-join tutorial: a card at the top of the screen that walks a
	new player through their first build, one step at a time:
	  grab a car off the conveyor -> take it home -> buy an addon in the
	  Shop -> load both onto the fusion pad from Inventory -> fuse ->
	  place the build on an earning pad.
	Each step points at what to use (a bouncing arrow by the right button,
	or a marker over the right spot in the world) and moves on by itself
	when the player has done it, worked out from what GameUpdate says they
	have, so doing things out of order or rejoining halfway just picks up
	at the right step. It can be skipped at any time.

	The server decides who sees it (GameUpdate's `tutorial`: true until it
	is finished or skipped, and never for a save that has already fused)
	and remembers that it is done (the Tutorial remote, "done"). A new
	player with too few coins for their first addon asks it for them once
	("coins"). The admin panel can replay it on the admin's own screen
	(the TutorialReplay attribute).
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Garage = require(ReplicatedStorage:WaitForChild("GarageTheme"))
local FusionRecipes = require(ReplicatedStorage:WaitForChild("FusionRecipes"))
local Mutations = require(ReplicatedStorage:WaitForChild("Mutations"))
local gameUpdate = ReplicatedStorage:WaitForChild("GameUpdate")
local tutorialRemote = ReplicatedStorage:WaitForChild("Tutorial")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local INK = Color3.fromRGB(22, 30, 48)
local GOLD = Color3.fromRGB(255, 205, 40)
local GREEN = Color3.fromRGB(40, 200, 110)
local STARTER_ADDON = "Nitrous Tank"

-- The steps, in order. `nav` is the button the arrow points at ("gui/holder"
-- in PlayerGui); `marker` is what the world marker hangs over.
local STEPS = {
	welcome = {
		title = "WELCOME TO JUNKYARD FUSION!",
		body = "You build crazy cars by fusing junk with engines. Let's make your first one together. It only takes a minute!",
		button = "LET'S GO!",
	},
	grab = {
		title = "GRAB A CAR",
		body = "Walk to the conveyor in the middle of the yard and hold E (or tap Grab) on any car riding it.",
		marker = "scrap", markerText = "GRAB A CAR",
	},
	home = {
		title = "TAKE IT HOME",
		body = "Carry it back to your base. Follow the arrows! It goes into your Inventory when you get there. Watch out, other players can knock it off you.",
		marker = "base", markerText = "YOUR BASE",
	},
	buy = {
		title = "BUY AN ADDON",
		body = "Visit the mechanic at the front of your base. Press E (or tap Addons) and buy a Nitrous Tank.",
		marker = "base", markerText = "YOUR MECHANIC",
	},
	stage = {
		title = "LOAD THE FUSION PAD",
		body = "Open your INVENTORY. Tap your car and press CARRY TO FUSE. Then open the ADDONS tab and do the same with the Nitrous Tank.",
		nav = { "JunkyardUI", "INVENTORYNavigation" },
	},
	fuse = {
		title = "FUSE!",
		body = "Go to the Fusion Pad at your base and hold E (or tap Fuse) to fuse your car and addon into a brand-new build.",
		marker = "pad", markerText = "FUSION PAD",
	},
	place = {
		title = "PUT IT TO WORK",
		body = "Open your INVENTORY, tap your new build and press PLACE ON PAD. Builds on earning pads make coins every second, even while you're away!",
		nav = { "JunkyardUI", "INVENTORYNavigation" },
	},
	finish = {
		title = "YOU'RE ALL SET!",
		body = "Keep fusing better addons onto better cars. Save up to Rebirth for bigger multipliers and to unlock Race Wars. Have fun!",
		button = "AWESOME!",
	},
}
local ORDER = { "welcome", "grab", "home", "buy", "stage", "fuse", "place", "finish" }
local NUMBER = {}
for i, key in ipairs(ORDER) do NUMBER[key] = i end

------------------------------------------------------------------
-- The card
------------------------------------------------------------------

local gui = Instance.new("ScreenGui")
gui.Name = "TutorialUI"
gui.ResetOnSpawn = false
gui.DisplayOrder = 30
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Enabled = false
gui:SetAttribute("Designed", true)
gui.Parent = playerGui

local function stroke(object, color, thickness)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness
	s.ApplyStrokeMode = object:IsA("TextLabel") and Enum.ApplyStrokeMode.Contextual or Enum.ApplyStrokeMode.Border
	s.Parent = object
	return s
end

local card = Garage.New("Frame", gui, "Card", {
	AnchorPoint = Vector2.new(0.5, 0), Size = UDim2.fromOffset(600, 176),
	BackgroundColor3 = INK, BackgroundTransparency = 0.08,
})
Garage.New("UICorner", card, "Corner", { CornerRadius = UDim.new(0, 18) })
stroke(card, GOLD, 4)
local cardScale = Garage.New("UIScale", card, "Scale", {})

local stepLabel = Garage.New("TextLabel", card, "Step", {
	BackgroundTransparency = 1, Position = UDim2.fromOffset(20, 10), Size = UDim2.fromOffset(200, 22),
	Font = Enum.Font.FredokaOne, TextSize = 18, TextColor3 = GOLD, TextXAlignment = Enum.TextXAlignment.Left, Text = "",
})
local title = Garage.New("TextLabel", card, "Title", {
	BackgroundTransparency = 1, Position = UDim2.fromOffset(20, 40), Size = UDim2.new(1, -40, 0, 36),
	Font = Enum.Font.LuckiestGuy, TextScaled = true, TextColor3 = Color3.new(1, 1, 1),
	TextXAlignment = Enum.TextXAlignment.Left, Text = "",
})
stroke(title, Color3.new(0, 0, 0), 2)
local body = Garage.New("TextLabel", card, "Body", {
	BackgroundTransparency = 1, Position = UDim2.fromOffset(20, 80), Size = UDim2.new(1, -40, 0, 86),
	Font = Enum.Font.FredokaOne, TextSize = 20, TextWrapped = true, TextColor3 = Color3.fromRGB(230, 236, 245),
	TextXAlignment = Enum.TextXAlignment.Left, TextYAlignment = Enum.TextYAlignment.Top, Text = "",
})
local skip = Garage.New("TextButton", card, "Skip", {
	AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 10), Size = UDim2.fromOffset(150, 30),
	BackgroundColor3 = Color3.fromRGB(70, 78, 96), Font = Enum.Font.FredokaOne, TextSize = 16,
	TextColor3 = Color3.new(1, 1, 1), Text = "SKIP TUTORIAL", AutoButtonColor = true,
})
Garage.New("UICorner", skip, "Corner", { CornerRadius = UDim.new(0, 10) })
local go = Garage.New("TextButton", card, "Go", {
	AnchorPoint = Vector2.new(1, 1), Position = UDim2.new(1, -16, 1, -14), Size = UDim2.fromOffset(190, 48),
	Font = Enum.Font.FredokaOne, TextSize = 24, Text = "", Visible = false,
})
Garage.Button(go, GREEN)

-- Top centre on a computer; on a phone the coins are there, so it goes to
-- the bottom centre, smaller.
local function placeCard()
	local size = gui.AbsoluteSize
	if size.Y < 100 then return end
	local phone = Garage.IsPhone(size)
	cardScale.Scale = phone and math.clamp(size.X / 1100, 0.5, 0.7) or 1
	card.AnchorPoint = phone and Vector2.new(0.5, 1) or Vector2.new(0.5, 0)
	card.Position = phone and UDim2.new(0.5, 0, 1, -8) or UDim2.new(0.5, 0, 0, 64)
end
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(placeCard)
placeCard()

-- The arrow by a nav button.
local arrow = Garage.New("TextLabel", gui, "Arrow", {
	BackgroundTransparency = 1, Size = UDim2.fromOffset(120, 60), AnchorPoint = Vector2.new(0.5, 0.5),
	Font = Enum.Font.LuckiestGuy, TextSize = 48, TextColor3 = GOLD, Text = "", Visible = false,
})
stroke(arrow, INK, 4)

------------------------------------------------------------------
-- The world marker
------------------------------------------------------------------

local markerPart = Instance.new("Part")
markerPart.Name = "TutorialMarker"
markerPart.Anchored = true
markerPart.CanCollide = false
markerPart.CanQuery = false
markerPart.CanTouch = false
markerPart.Transparency = 1
markerPart.Size = Vector3.new(1, 1, 1)
local markerGui = Instance.new("BillboardGui")
markerGui.Size = UDim2.fromOffset(220, 120)
markerGui.AlwaysOnTop = true
markerGui.LightInfluence = 0
markerGui.MaxDistance = 2000
markerGui.Adornee = markerPart
markerGui.Enabled = false
markerGui.Parent = markerPart
local markerText = Garage.New("TextLabel", markerGui, "Label", {
	BackgroundTransparency = 1, Size = UDim2.new(1, 0, 0, 44), Font = Enum.Font.LuckiestGuy,
	TextScaled = true, TextColor3 = GOLD, Text = "",
})
stroke(markerText, INK, 4)
local markerArrow = Garage.New("TextLabel", markerGui, "Arrow", {
	BackgroundTransparency = 1, Position = UDim2.fromOffset(0, 44), Size = UDim2.new(1, 0, 0, 70),
	Font = Enum.Font.LuckiestGuy, TextScaled = true, TextColor3 = GOLD, Text = "▼",
})
stroke(markerArrow, INK, 4)
markerPart.Parent = workspace

------------------------------------------------------------------
-- Working out the step
------------------------------------------------------------------

local active = false
local current = nil
local latest = nil        -- the last GameUpdate that carried the full state
local startedOnce = false -- the welcome card has been dismissed
local askedCoins = false

local function isCar(name)
	local bare = Mutations.Unwrap(name)
	for _, car in ipairs(FusionRecipes.Items) do
		if car.name == bare then return true end
	end
	return false
end

-- Which step the player's things say they are on.
local function stepFromState(data)
	if #(data.placed or {}) > 0 then return "finish" end
	local hasCar, hasAddon, hasBuild = false, false, false
	local function look(name)
		if type(name) ~= "string" then return end
		if FusionRecipes.IsAddon(Mutations.Unwrap(name)) then
			hasAddon = true
		elseif isCar(name) then
			hasCar = true
		else
			hasBuild = true
		end
	end
	for _, entry in ipairs(data.inventory or {}) do look(type(entry) == "table" and entry.name or entry) end
	local staged = 0
	for _, name in pairs(data.slots or {}) do
		staged += 1
		look(name)
	end
	if hasBuild then return "place" end
	if staged >= 2 then return "fuse" end
	if hasCar and hasAddon then return "stage" end
	if hasCar then return "buy" end
	if data.carrying then return "home" end
	return "grab"
end

local function finish()
	active = false
	gui.Enabled = false
	markerGui.Enabled = false
	arrow.Visible = false
	player:SetAttribute("TutorialReplay", nil)
	tutorialRemote:FireServer("done")
end

local function show(key)
	if current == key then return end
	current = key
	local step = STEPS[key]
	stepLabel.Text = (key == "welcome" or key == "finish") and "TUTORIAL"
		or string.format("STEP %d OF %d", NUMBER[key] - 1, #ORDER - 2)
	title.Text = step.title
	body.Text = step.body
	go.Visible = step.button ~= nil
	go.Text = step.button or ""
	body.Size = step.button and UDim2.new(1, -230, 0, 86) or UDim2.new(1, -40, 0, 86)
	skip.Visible = key ~= "finish"

	if key == "buy" and not askedCoins then
		local stats = player:FindFirstChild("leaderstats")
		local coins = stats and stats:FindFirstChild("Coins")
		if coins and coins.Value < (FusionRecipes.AddonPrice(STARTER_ADDON) or 0) then
			askedCoins = true
			tutorialRemote:FireServer("coins")
		end
	end
end

local function refresh()
	if not active then return end
	if not startedOnce then
		show("welcome")
	elseif latest then
		show(stepFromState(latest))
	end
end

local function start()
	if active then return end
	active = true
	startedOnce = false
	current = nil
	gui.Enabled = true
	refresh()
end

go.Activated:Connect(function()
	if current == "welcome" then
		startedOnce = true
		refresh()
	elseif current == "finish" then
		finish()
	end
end)
skip.Activated:Connect(finish)

gameUpdate.OnClientEvent:Connect(function(data)
	if type(data) ~= "table" or data.inventory == nil then return end
	latest = data
	if data.tutorial == true then
		start()
	elseif data.tutorial == false and active and not player:GetAttribute("TutorialReplay") then
		-- Finished or skipped on another device.
		active = false
		gui.Enabled = false
		markerGui.Enabled = false
		arrow.Visible = false
	end
	refresh()
end)

player:GetAttributeChangedSignal("TutorialReplay"):Connect(function()
	if player:GetAttribute("TutorialReplay") then start() end
end)

------------------------------------------------------------------
-- Pointing at things, every frame
------------------------------------------------------------------

local function nearestScrap(from)
	local folder = workspace:FindFirstChild("Scrap")
	if not folder then return nil end
	local best, bestDistance = nil, math.huge
	for _, child in ipairs(folder:GetChildren()) do
		local part = child:IsA("BasePart") and child or (child:IsA("Model") and (child.PrimaryPart or child:FindFirstChildWhichIsA("BasePart", true)))
		if part and not child:GetAttribute("Collected") then
			local distance = (part.Position - from).Magnitude
			if distance < bestDistance then
				best, bestDistance = part.Position, distance
			end
		end
	end
	return best
end

local function myFusionPad(centre)
	local plots = workspace:FindFirstChild("Plots")
	if not plots or not centre then return centre end
	local best, bestDistance = centre, math.huge
	for _, d in ipairs(plots:GetDescendants()) do
		if d.Name == "FusionPad" and d:IsA("BasePart") then
			local distance = (d.Position - centre).Magnitude
			if distance < bestDistance then
				best, bestDistance = d.Position, distance
			end
		end
	end
	return best
end

local lastLook = 0
local target = nil
-- Heartbeat rather than RenderStepped: it runs even when the 3D view is not
-- drawing, so the arrow never sticks where the last step left it.
RunService.Heartbeat:Connect(function()
	if not active or not current then return end
	local step = STEPS[current]
	local bob = math.sin(os.clock() * 6) * 8

	-- Arrow by a nav button.
	local holder = nil
	if step.nav then
		local screen = playerGui:FindFirstChild(step.nav[1])
		holder = screen and screen:FindFirstChild(step.nav[2])
	end
	if holder and holder.AbsoluteSize.X > 0 then
		local onRight = holder.AbsolutePosition.X > gui.AbsoluteSize.X / 2
		local centre = holder.AbsolutePosition + holder.AbsoluteSize / 2
		arrow.Text = onRight and "▶" or "◀"
		arrow.Position = UDim2.fromOffset(
			centre.X + (onRight and -1 or 1) * (holder.AbsoluteSize.X / 2 + 40 + bob), centre.Y)
		arrow.Visible = true
	else
		arrow.Visible = false
	end

	-- Marker over a spot in the world, looked up a few times a second.
	if step.marker then
		local now = os.clock()
		if now - lastLook > 0.4 then
			lastLook = now
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local centre = latest and latest.baseCentre
			if step.marker == "scrap" then
				target = root and nearestScrap(root.Position) or nil
			elseif step.marker == "base" then
				target = centre
			elseif step.marker == "pad" then
				target = myFusionPad(centre)
			end
		end
		if typeof(target) == "Vector3" then
			markerPart.CFrame = CFrame.new(target + Vector3.new(0, 9 + bob / 8, 0))
			markerText.Text = step.markerText
			markerGui.Enabled = true
		else
			markerGui.Enabled = false
		end
	else
		markerGui.Enabled = false
	end
end)
