--[[
	PhantomShop (LocalScript, StarterPlayerScripts) — Junkyard Fusion

	The Phantom Garage's shop (the stall in the Race Wars lobby, built by
	ServerStorage.PhantomGarage): the fifteen Phantom addons on three
	shelves, Wisp, Wraith and Reaper, each with its model turning on a
	pedestal, a line about it and its price in bolts. Opens from the stall's
	"Phantom Shop" prompt and closes when you walk away. Buying asks
	PlotManager's BuyPhantom, which checks everything again; its answer
	shows on the addon's own button for a moment.

	Same look as the mechanic's shop (MechanicAddons.client). Until an
	addon has its own model it shows the one it borrows, drawn ghostly
	(ItemVisuals.Ghostly).
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Garage = require(ReplicatedStorage:WaitForChild("GarageTheme"))
local FusionRecipes = require(ReplicatedStorage:WaitForChild("FusionRecipes"))
local ItemVisuals = require(ReplicatedStorage:WaitForChild("ItemVisuals"))
local ItemNames = require(ReplicatedStorage:WaitForChild("ItemNames"))
local EventAddons = require(ReplicatedStorage:WaitForChild("EventAddons"))
local buyRemote = ReplicatedStorage:WaitForChild("BuyPhantom")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local MINT = Color3.fromRGB(150, 255, 210)
local VIOLET = Color3.fromRGB(58, 34, 96)
local BUY = Color3.fromRGB(122, 64, 214)

-- One line about each, from the concept sheet.
local BLURBS = {
	["Will-o'-Wisp Lanterns"] = "Iron lanterns with green spirit flames",
	["Phantom Exhaust"] = "Bone pipes that puff skull smoke rings",
	["Crystal Ball Ornament"] = "A ghost spins inside a crystal ball",
	["Graveyard Grille"] = "A cemetery gate grille and a tombstone bumper",
	["Ecto Tank"] = "A glass tank of bubbling green goo",
	["Banshee Horn"] = "A horn whose bell is a wailing spirit",
	["Poltergeist Spoiler"] = "A wing that floats and rattles on its own",
	["Coffin Carrier"] = "A coffin on the roof, lid knocking",
	["Witch's Cauldron"] = "A cauldron of purple brew for an engine",
	["Specter Sails"] = "A torn ghost-ship sail on a mast",
	["Wraith Wheels"] = "Wheels of blue ghost fire",
	["Soul Turbo"] = "A turbo that sucks in tiny ghosts",
	["Hearse Canopy"] = "A funeral-coach roof with lace curtains",
	["Reaper Scythes"] = "Scythe blades on the wheels, chariot style",
	["Ghost Chauffeur"] = "A see-through butler ghost drives for you",
}
local SHELVES = {
	{ key = "wisp", name = "WISP", line = "Small haunted parts" },
	{ key = "wraith", name = "WRAITH", line = "Bigger pieces that change the car's shape" },
	{ key = "reaper", name = "REAPER", line = "The showpieces" },
}

local function commas(n)
	local s = tostring(math.floor(n))
	local formatted = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (formatted:gsub("^,", ""))
end
local function boltsText(n)
	return "🔩 " .. commas(n) .. (n == 1 and " bolt" or " bolts")
end

local shopGui = Instance.new("ScreenGui")
shopGui.Name = "PhantomShop"
shopGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
shopGui.ResetOnSpawn = false
shopGui.DisplayOrder = 30
shopGui.Enabled = false
shopGui.Parent = playerGui
-- Counts as an open menu, so the HUD buttons and phone controls step aside.
require(ReplicatedStorage:WaitForChild("UIStyle")).ModalGui(shopGui)

local panel = Garage.New("Frame", shopGui, "PhantomPanel", {})
Garage.Shell(panel)
Garage.Fit(panel)
local title = Garage.Text(panel, "Title", "PHANTOM GARAGE", UDim2.fromOffset(18, 14), UDim2.new(0.55, 0, 0, 54), 28)
Garage.Header(title)
title.TextScaled = true
local balance = Garage.Text(panel, "Balance", "🔩 0 bolts", UDim2.new(0.58, 0, 0, 20), UDim2.new(0.42, -88, 0, 44), 24, MINT)
balance.TextXAlignment = Enum.TextXAlignment.Right
local close = Garage.New("TextButton", panel, "Close", {
	Text = "X", Position = UDim2.new(1, -62, 0, 14), Size = UDim2.fromOffset(46, 46), ZIndex = 10,
})
Garage.Button(close, Color3.fromRGB(255, 88, 30))
close.Activated:Connect(function() shopGui.Enabled = false end)

local page = Garage.New("ScrollingFrame", panel, "Shelves", {
	BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 7,
	ScrollBarImageColor3 = VIOLET, AutomaticCanvasSize = Enum.AutomaticSize.Y,
	CanvasSize = UDim2.new(), ZIndex = 2,
})
Garage.New("UIListLayout", page, "Layout", { Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder })
Garage.New("UIPadding", page, "Padding", { PaddingTop = UDim.new(0, 4), PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 10) })

local function outline(label)
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	stroke.Color = Color3.fromRGB(20, 12, 36)
	stroke.Thickness = 2
	stroke.Parent = label
end

local intro = Garage.Text(page, "Intro",
	"Win bolts in Race Wars and trade them here for ghost addons. Put one on any car or build at your Fusion Pad: it turns into a ghost for good and earns more. One phantom per car.",
	UDim2.new(), UDim2.new(1, -8, 0, 64), 21, Color3.new(1, 1, 1))
intro.LayoutOrder = 0
intro.TextXAlignment = Enum.TextXAlignment.Left
outline(intro)

-- A turntable view of the addon's model, on a pedestal.
local spinning = {}
local function modelView(card, name)
	local view = Garage.New("ViewportFrame", card, "Model", {
		BackgroundTransparency = 1, Position = UDim2.fromOffset(8, 8), Size = UDim2.new(1, -16, 0, 150),
		Ambient = Color3.fromRGB(205, 205, 215), LightColor = Color3.new(1, 1, 1),
		LightDirection = Vector3.new(-1, -1, -1), ZIndex = 3,
	})
	local model, size = ItemVisuals.CloneForViewport(name)
	if not model then return end
	local world = Instance.new("WorldModel")
	world.Parent = view
	model.Parent = world
	Garage.Podium(model, MINT)
	local camera = Instance.new("Camera")
	camera.FieldOfView = 35
	camera.Parent = view
	view.CurrentCamera = camera
	local reach = math.max(size.X, size.Y, size.Z) * 1.78 + 0.2
	camera.CFrame = CFrame.lookAt(Vector3.new(0.6, 0.45, 0.9) * reach, Vector3.zero)
	table.insert(spinning, { model = model, base = model:GetPivot() })
end

local cards = {}
local grids = {}
for order, shelf in ipairs(SHELVES) do
	-- The shelf's earnings range (each Phantom's `earn`, see EventAddons).
	local low, high = math.huge, 0
	for _, addon in ipairs(FusionRecipes.PhantomAddons) do
		if addon.group == shelf.key then low, high = math.min(low, addon.earn), math.max(high, addon.earn) end
	end
	local heading = Garage.Text(page, shelf.key .. "Heading", string.format("%s  ·  %s  ·  x%s to x%s earnings", shelf.name, shelf.line, tostring(low), tostring(high)),
		UDim2.new(), UDim2.new(1, -8, 0, 36), 24, MINT)
	heading.LayoutOrder = order * 2 - 1
	heading.TextXAlignment = Enum.TextXAlignment.Left
	outline(heading)
	local grid = Garage.New("Frame", page, shelf.key .. "Shelf", {
		BackgroundTransparency = 1, LayoutOrder = order * 2, AutomaticSize = Enum.AutomaticSize.Y,
	})
	grids[shelf.key] = Garage.New("UIGridLayout", grid, "Grid", {
		CellPadding = UDim2.fromOffset(12, 12), SortOrder = Enum.SortOrder.LayoutOrder,
	})
	grids[shelf.key .. "Frame"] = grid
end

for order, addon in ipairs(FusionRecipes.PhantomAddons) do
	local grid = grids[addon.group .. "Frame"]
	local card = Garage.New("Frame", grid, addon.name, { LayoutOrder = order })
	Garage.Inset(card)
	modelView(card, addon.name)

	local name = Garage.Text(card, "Title", ItemNames.Display(addon.name),
		UDim2.new(0, 8, 0, 164), UDim2.new(1, -16, 0, 34), 22)
	Garage.Plate(name)
	name.TextScaled = true

	-- What it multiplies a car's earnings by, over the model.
	local earn = Garage.Text(card, "Earn", string.format("x%s earnings", tostring(EventAddons.AddonMultiplier(addon.name))),
		UDim2.new(0, 10, 0, 8), UDim2.new(1, -20, 0, 26), 20, MINT)
	earn.TextXAlignment = Enum.TextXAlignment.Right
	earn.ZIndex = 6
	outline(earn)

	local blurb = Garage.Text(card, "Blurb", BLURBS[addon.name] or "",
		UDim2.new(0, 8, 0, 202), UDim2.new(1, -16, 0, 44), 17, Color3.new(1, 1, 1))
	blurb.TextWrapped = true
	outline(blurb)

	local buy = Garage.New("TextButton", card, "Purchase", {
		Text = boltsText(addon.bolts), TextSize = 24, Font = Enum.Font.FredokaOne,
		Position = UDim2.new(0, 9, 1, -56), Size = UDim2.new(1, -18, 0, 46), ZIndex = 5,
	})
	Garage.Button(buy, BUY)
	local function purchase()
		if buy.Active and shopGui.Enabled then
			buyRemote:FireServer(addon.name)
		end
	end
	buy.Activated:Connect(purchase)
	-- The whole card buys, not just its button: people tap the model.
	local cardButton = Garage.New("TextButton", card, "CardButton", {
		Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 4,
	})
	cardButton.Activated:Connect(purchase)
	cards[addon.name] = { price = addon.bolts, button = buy, shown = 0 }
end

-- The server's answer, on the addon's own button for a moment (toasts are
-- drawn under an open shop).
local RESULT_TEXT = {
	bought = "Added to Inventory!",
	away = "Stand at the counter",
	full = "Inventory Full",
	bolts = "Need More Bolts",
}
buyRemote.OnClientEvent:Connect(function(addonName, result)
	local card = cards[addonName]
	local text = RESULT_TEXT[result]
	if not card or not text then return end
	card.shown += 1
	local shown = card.shown
	card.button.Text = text
	task.delay(1.6, function()
		if card.shown == shown then
			card.button.Text = boltsText(card.price)
		end
	end)
end)

-- Greys out what you cannot afford yet, and shows how many bolts you have.
-- The server checks again on every purchase.
local function refresh()
	local stats = player:FindFirstChild("leaderstats")
	local bolts = stats and stats:FindFirstChild("Bolts")
	local have = bolts and bolts.Value or 0
	balance.Text = boltsText(have)
	for _, card in pairs(cards) do
		card.button.Active = have >= card.price
		card.button.AutoButtonColor = card.button.Active
	end
end
task.spawn(function()
	local bolts = player:WaitForChild("leaderstats"):WaitForChild("Bolts", 30)
	if not bolts then return end
	bolts.Changed:Connect(refresh)
	refresh()
end)

local function layout()
	page.Position = UDim2.fromOffset(19, 84)
	page.Size = UDim2.new(1, -38, 1, -103)
	local cols = panel:GetAttribute("Compact") and 2 or 5
	for _, shelf in ipairs(SHELVES) do
		grids[shelf.key].CellSize = UDim2.new(1 / cols, -12, 0, 310)
		grids[shelf.key .. "Frame"].Size = UDim2.new(1, -4, 0, 0)
	end
end
panel:GetAttributeChangedSignal("Compact"):Connect(layout)
layout()

-- Opens from the stall's prompt; closes when you walk away from it.
local counter
task.spawn(function()
	local stall = workspace:WaitForChild("PhantomGarage", 120)
	counter = stall and stall:WaitForChild("Counter", 30)
	local prompt = counter and counter:WaitForChild("OpenPhantomShop", 30)
	if prompt then
		prompt.Triggered:Connect(function()
			refresh()
			shopGui.Enabled = true
		end)
	end
end)

RunService.Heartbeat:Connect(function()
	if not shopGui.Enabled then return end
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not root or not counter or not counter.Parent or (root.Position - counter.Position).Magnitude > 18 then
		shopGui.Enabled = false
		return
	end
	local angle = os.clock() * 0.6
	for _, s in ipairs(spinning) do
		s.model:PivotTo(CFrame.Angles(0, angle, 0) * s.base)
	end
end)
