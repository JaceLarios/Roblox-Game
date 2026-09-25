--[[
	RaceCrates (LocalScript, StarterPlayerScripts) — Junkyard Fusion

	The Inventory's Crates tab: the crates you have won in Race Wars, each
	counting down until it can be opened, and the OPEN button once it can.
	What is inside stays hidden until then (the server only sends each
	crate's level and time left; see RaceCrates.luau for how they roll).

	Its own script, like ShopAddons is for the Shop: it adds an ITEMS /
	CRATES tab pair to the existing Inventory panel and lays its board over
	the item grid and details panel while the Crates tab is showing, so it
	never touches how GameUI lays the Items tab out. Styled with
	GarageTheme to match.
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Garage = require(ReplicatedStorage:WaitForChild("GarageTheme"))
local ItemVisuals = require(ReplicatedStorage:WaitForChild("ItemVisuals"))
local ItemNames = require(ReplicatedStorage:WaitForChild("ItemNames"))
local Mutations = require(ReplicatedStorage:WaitForChild("Mutations"))
local gameUpdate = ReplicatedStorage:WaitForChild("GameUpdate")
local openRemote = ReplicatedStorage:WaitForChild("OpenCrate")

local player = Players.LocalPlayer
local junkyardUI = player:WaitForChild("PlayerGui"):WaitForChild("JunkyardUI")
local panel = junkyardUI:WaitForChild("InventoryPanel")
local gridBoard = panel:WaitForChild("GridBoard")

local INK = Color3.fromRGB(8, 43, 77)
local GOLD = Color3.fromRGB(255, 199, 47)
local BLUE = Color3.fromRGB(121, 154, 200)
local GREEN = Color3.fromRGB(40, 200, 110)
local WHITE = Color3.new(1, 1, 1)

local crates = {}        -- as the server last sent them
local receivedAt = 0     -- os.clock() when they arrived
local capacity = 20
local showing = "items"

local function stroke(label, thickness)
	local s = Instance.new("UIStroke")
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	s.Color = INK
	s.Thickness = thickness or 2
	s.Parent = label
end

local function clock(seconds)
	seconds = math.max(0, math.ceil(seconds))
	if seconds >= 3600 then
		return string.format("%d:%02d:%02d", seconds // 3600, seconds % 3600 // 60, seconds % 60)
	end
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

------------------------------------------------------------------
-- Tabs
------------------------------------------------------------------

local function tabButton(name, label)
	local b = Garage.New("TextButton", panel, name, {
		Text = label, TextSize = 20, Font = Enum.Font.FredokaOne, AutoButtonColor = true, ZIndex = 30,
	})
	Garage.Button(b, BLUE)
	return b
end
local itemsTab = tabButton("ItemsTab", "ITEMS")
local cratesTab = tabButton("CratesTab", "CRATES")

------------------------------------------------------------------
-- The Crates board
------------------------------------------------------------------

local board = Garage.New("Frame", panel, "CratesBoard", {
	BackgroundColor3 = gridBoard.BackgroundColor3, Visible = false, Active = true, ZIndex = 25,
})
Garage.New("UICorner", board, "Corner", { CornerRadius = UDim.new(0, 18) })
local boardEdge = Instance.new("UIStroke")
boardEdge.Color = Color3.fromRGB(207, 216, 209)
boardEdge.Thickness = 3
boardEdge.Parent = board

local heading = Garage.Text(board, "Heading", "RACE WARS CRATES", UDim2.fromOffset(18, 10), UDim2.new(1, -36, 0, 34), 28, INK)
heading.TextXAlignment = Enum.TextXAlignment.Left
heading.ZIndex = 26
local blurb = Garage.Text(board, "Blurb",
	"Clear levels in Race Wars to win crates. The longer a crate's timer, the better what's inside.",
	UDim2.fromOffset(18, 44), UDim2.new(1, -36, 0, 26), 17, Color3.fromRGB(90, 96, 104))
blurb.TextXAlignment = Enum.TextXAlignment.Left
blurb.ZIndex = 26

local shelf = Garage.New("ScrollingFrame", board, "Shelf", {
	Position = UDim2.fromOffset(12, 78), Size = UDim2.new(1, -24, 1, -90), BackgroundTransparency = 1,
	BorderSizePixel = 0, ScrollBarThickness = 7, ScrollBarImageColor3 = INK,
	AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(), ZIndex = 26,
})
Garage.New("UIPadding", shelf, "Padding", { PaddingTop = UDim.new(0, 6), PaddingLeft = UDim.new(0, 6), PaddingRight = UDim.new(0, 10) })
local shelfGrid = Garage.New("UIGridLayout", shelf, "Grid", {
	CellPadding = UDim2.fromOffset(12, 12), SortOrder = Enum.SortOrder.LayoutOrder,
})
local empty = Garage.Text(board, "Empty", "No crates yet. Travel to Race Wars and outrun the monster to win some!",
	UDim2.fromOffset(40, 150), UDim2.new(1, -80, 0, 70), 24, Color3.fromRGB(120, 120, 128))
empty.ZIndex = 26

-- The reveal: what came out of a crate you just opened.
local reveal = Garage.New("TextButton", board, "Reveal", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromOffset(360, 330),
	Text = "", AutoButtonColor = false, Visible = false, ZIndex = 40,
})
Garage.Inset(reveal)
reveal.BackgroundTransparency = 0
reveal.BackgroundColor3 = Color3.fromRGB(28, 120, 196)
local revealTitle = Garage.Text(reveal, "Title", "CRATE OPENED!", UDim2.fromOffset(10, 8), UDim2.new(1, -20, 0, 40), 30, GOLD)
revealTitle.ZIndex = 41
stroke(revealTitle, 3)
local revealView = Garage.New("ViewportFrame", reveal, "Model", {
	Position = UDim2.fromOffset(20, 52), Size = UDim2.new(1, -40, 0, 190), BackgroundTransparency = 1,
	Ambient = Color3.fromRGB(205, 205, 215), LightColor = WHITE, LightDirection = Vector3.new(-1, -1, -1), ZIndex = 41,
})
local revealName = Garage.Text(reveal, "ItemName", "", UDim2.new(0, 14, 1, -80), UDim2.new(1, -28, 0, 40), 26)
Garage.Plate(revealName)
revealName.TextScaled = true
revealName.ZIndex = 42
local revealHint = Garage.Text(reveal, "Hint", "Added to your Inventory", UDim2.new(0, 10, 1, -36), UDim2.new(1, -20, 0, 26), 18, WHITE)
revealHint.ZIndex = 41
stroke(revealHint, 2)
local revealSpin = nil
local revealToken = 0

local function showReveal(itemName)
	revealToken += 1
	local token = revealToken
	revealView:ClearAllChildren()
	revealSpin = nil
	local baseName, mutationId = Mutations.Unwrap(itemName)
	local model, size = ItemVisuals.CloneForViewport(baseName, nil)
	if model then
		local world = Instance.new("WorldModel")
		world.Parent = revealView
		model.Parent = world
		Garage.Podium(model, Mutations.Color(mutationId) or Color3.fromRGB(59, 229, 204))
		local camera = Instance.new("Camera")
		camera.FieldOfView = 35
		camera.Parent = revealView
		revealView.CurrentCamera = camera
		local reach = math.max(size.X, size.Y, size.Z) * 1.7 + 0.2
		camera.CFrame = CFrame.lookAt(Vector3.new(0.6, 0.45, 0.9) * reach, Vector3.zero)
		revealSpin = { model = model, base = model:GetPivot() }
	end
	revealName.Text = ItemNames.Display(itemName)
	reveal.Visible = true
	task.delay(4, function()
		if revealToken == token then reveal.Visible = false end
	end)
end
reveal.Activated:Connect(function() reveal.Visible = false end)

local cards = {} -- [crate id] = { timer, open, remaining }

local function redraw()
	for _, child in ipairs(shelf:GetChildren()) do
		if child:IsA("GuiObject") then child:Destroy() end
	end
	table.clear(cards)
	heading.Text = string.format("RACE WARS CRATES   %d / %d", #crates, capacity)
	empty.Visible = #crates == 0

	for order, crate in ipairs(crates) do
		local card = Garage.New("Frame", shelf, "Crate" .. order, { LayoutOrder = order, ZIndex = 27 })
		Garage.Inset(card)
		local art = Garage.Art(card, "crate", UDim2.new(0.15, 0, 0, 6), UDim2.new(0.7, 0, 0, 104))
		art.ZIndex = 28
		local title = Garage.Text(card, "Title", string.format("LEVEL %d CRATE", crate.level), UDim2.new(0, 8, 0, 112), UDim2.new(1, -16, 0, 30), 20)
		Garage.Plate(title)
		title.TextScaled = true
		title.ZIndex = 29
		local place = Garage.Text(card, "LevelName", crate.levelName, UDim2.new(0, 8, 0, 144), UDim2.new(1, -16, 0, 22), 16, WHITE)
		place.ZIndex = 28
		stroke(place, 2)
		local timer = Garage.Text(card, "Timer", "", UDim2.new(0, 8, 0, 166), UDim2.new(1, -16, 0, 28), 24, WHITE)
		timer.ZIndex = 28
		stroke(timer, 2.5)
		local open = Garage.New("TextButton", card, "Open", {
			Text = "OPEN", TextSize = 22, Font = Enum.Font.FredokaOne,
			Position = UDim2.new(0, 8, 1, -50), Size = UDim2.new(1, -16, 0, 42), ZIndex = 30,
		})
		Garage.Button(open, GOLD)
		local id = crate.id
		open.Activated:Connect(function()
			if open.Active then openRemote:FireServer(id) end
		end)
		cards[id] = { timer = timer, open = open, remaining = crate.remaining, ready = nil }
	end
end

-- Timers tick here rather than on every server push.
local lastTick = 0
RunService.Heartbeat:Connect(function()
	local now = os.clock()
	if now - lastTick < 0.25 then return end
	lastTick = now
	local anyReady = false
	for _, card in pairs(cards) do
		local left = card.remaining - (now - receivedAt)
		local ready = left <= 0
		anyReady = anyReady or ready
		card.timer.Text = ready and "READY!" or clock(left)
		card.timer.TextColor3 = ready and Color3.fromRGB(150, 255, 170) or WHITE
		if card.ready ~= ready then
			card.ready = ready
			card.open.Active = ready
			card.open.Text = ready and "OPEN" or "LOCKED"
		end
	end
	cratesTab.Text = #crates > 0 and string.format("CRATES (%d)", #crates) or "CRATES"
	if showing ~= "crates" then
		cratesTab.BackgroundColor3 = anyReady and GREEN or BLUE
	end
	if revealSpin and reveal.Visible then
		revealSpin.model:PivotTo(CFrame.Angles(0, now * 0.8, 0) * revealSpin.base)
	end
end)

gameUpdate.OnClientEvent:Connect(function(data)
	if type(data) ~= "table" or not data.crates then return end
	crates = data.crates
	receivedAt = os.clock()
	capacity = data.crateCapacity or capacity
	redraw()
end)

openRemote.OnClientEvent:Connect(function(_, ok, detail)
	if ok then
		showReveal(detail)
	elseif detail == "full" then
		revealToken += 1
		reveal.Visible = false
		blurb.Text = "Your Inventory is full — place or fuse something, then open it."
		blurb.TextColor3 = Color3.fromRGB(200, 60, 50)
		task.delay(3, function()
			blurb.Text = "Clear levels in Race Wars to win crates. The longer a crate's timer, the better what's inside."
			blurb.TextColor3 = Color3.fromRGB(90, 96, 104)
		end)
	end
end)

------------------------------------------------------------------
-- Layout and switching
------------------------------------------------------------------

local function layout()
	local compact = panel:GetAttribute("Compact")
	local width = compact and 600 or 1200
	local tabWidth = compact and 116 or 150
	local y = compact and 136 or 90
	cratesTab.Size = UDim2.fromOffset(tabWidth, 34)
	itemsTab.Size = UDim2.fromOffset(tabWidth, 34)
	cratesTab.Position = UDim2.fromOffset(width - 24 - tabWidth, y)
	itemsTab.Position = UDim2.fromOffset(width - 24 - tabWidth * 2 - 8, y)

	-- Over the item grid and the details panel together.
	local left = gridBoard.Position.X.Offset
	board.Position = UDim2.new(0, left, gridBoard.Position.Y.Scale, gridBoard.Position.Y.Offset)
	board.Size = UDim2.new(1, -left * 2, gridBoard.Size.Y.Scale, gridBoard.Size.Y.Offset)
	local cols = compact and 3 or 5
	shelfGrid.CellSize = UDim2.new(1 / cols, -12, 0, 250)
end

local function show(which)
	showing = which
	board.Visible = which == "crates"
	itemsTab.BackgroundColor3 = which == "items" and GOLD or BLUE
	cratesTab.BackgroundColor3 = which == "crates" and GOLD or BLUE
end

itemsTab.Activated:Connect(function() show("items") end)
cratesTab.Activated:Connect(function() show("crates") end)
panel:GetAttributeChangedSignal("Compact"):Connect(layout)
gridBoard:GetPropertyChangedSignal("Position"):Connect(layout)
gridBoard:GetPropertyChangedSignal("Size"):Connect(layout)
layout()
show("items")
redraw()
