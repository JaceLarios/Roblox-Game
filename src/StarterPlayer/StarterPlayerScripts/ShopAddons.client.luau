--[[
	ShopAddons (LocalScript, StarterPlayerScripts) — Junkyard Fusion

	The Shop's Addons tab. Addons no longer spawn in the yard — cars ride
	the conveyor and addons are bought here for coins, straight into
	Inventory (PlotManager's BuyAddon remote sets the price and checks it).

	Deliberately its own script rather than a section of ShopUI.client:
	it adds a SHOP / ADDONS tab pair to the existing Shop panel and never
	changes what the Shop tab shows. Styled with GarageTheme, the same kit
	the rest of the Shop uses, so the new tab matches it.
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Garage = require(ReplicatedStorage:WaitForChild("GarageTheme"))
local FusionRecipes = require(ReplicatedStorage:WaitForChild("FusionRecipes"))
local ItemRarity = require(ReplicatedStorage:WaitForChild("ItemRarity"))
local ItemVisuals = require(ReplicatedStorage:WaitForChild("ItemVisuals"))
local ItemNames = require(ReplicatedStorage:WaitForChild("ItemNames"))
local buyAddonRemote = ReplicatedStorage:WaitForChild("BuyAddon")

local player = Players.LocalPlayer
local shopGui = player:WaitForChild("PlayerGui"):WaitForChild("ShopUI")
local panel = shopGui:WaitForChild("Overlay"):WaitForChild("ShopPanel")
local shopSections = panel:WaitForChild("Sections")

local GOLD = Color3.fromRGB(255, 199, 47)
local BLUE = Color3.fromRGB(121, 154, 200)
local PEDESTAL = Color3.fromRGB(59, 229, 204)

local function commas(n)
	local s = tostring(math.floor(n))
	local formatted = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (formatted:gsub("^,", ""))
end

-- The Shop tab's own content area, as ShopUI lays it out; in the narrow
-- layout the tabs need a row of their own above it.
local CONTENT_TOP = 95
local TAB_ROW = 62

------------------------------------------------------------------
-- Tabs
------------------------------------------------------------------

local function tabButton(name, label)
	local b = Garage.New("TextButton", panel, name, {
		Text = label, TextSize = 26, Font = Enum.Font.FredokaOne, AutoButtonColor = true, ZIndex = 5,
	})
	Garage.Button(b, BLUE)
	return b
end

local shopTab = tabButton("ShopTab", "SHOP")
local addonsTab = tabButton("AddonsTab", "ADDONS")

------------------------------------------------------------------
-- The Addons page
------------------------------------------------------------------

local page = Garage.New("ScrollingFrame", panel, "AddonsSection", {
	BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 7,
	ScrollBarImageColor3 = Color3.fromRGB(8, 43, 77), AutomaticCanvasSize = Enum.AutomaticSize.Y,
	CanvasSize = UDim2.new(), Visible = false, ZIndex = 2,
})
Garage.New("UIListLayout", page, "Layout", { Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder })
Garage.New("UIPadding", page, "Padding", { PaddingTop = UDim.new(0, 4), PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 10) })

local intro = Garage.Text(page, "Intro",
	"Addons don't spawn in the yard any more. Buy one here, then put it on your fusion pad with a car — the better the addon, the rarer the build.",
	UDim2.new(), UDim2.new(1, -8, 0, 60), 22, Color3.new(1, 1, 1))
intro.LayoutOrder = 1
intro.TextXAlignment = Enum.TextXAlignment.Left
local introStroke = Instance.new("UIStroke")
introStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
introStroke.Color = Color3.fromRGB(8, 43, 77)
introStroke.Thickness = 2
introStroke.Parent = intro

local grid = Garage.New("Frame", page, "AddonGrid", { BackgroundTransparency = 1, LayoutOrder = 2, AutomaticSize = Enum.AutomaticSize.Y })
local gridLayout = Garage.New("UIGridLayout", grid, "Grid", {
	CellPadding = UDim2.fromOffset(12, 12), SortOrder = Enum.SortOrder.LayoutOrder,
})

-- A turntable view of the addon's own model, on a pedestal.
local spinning = {}
local function modelView(card, name)
	local view = Garage.New("ViewportFrame", card, "Model", {
		BackgroundTransparency = 1, Position = UDim2.fromOffset(8, 8), Size = UDim2.new(1, -16, 0, 158),
		Ambient = Color3.fromRGB(205, 205, 215), LightColor = Color3.new(1, 1, 1),
		LightDirection = Vector3.new(-1, -1, -1), ZIndex = 3,
	})
	local model, size = ItemVisuals.CloneForViewport(name)
	if not model then return end
	local world = Instance.new("WorldModel")
	world.Parent = view
	model.Parent = world
	Garage.Podium(model, PEDESTAL)
	local camera = Instance.new("Camera")
	camera.FieldOfView = 35
	camera.Parent = view
	view.CurrentCamera = camera
	local reach = math.max(size.X, size.Y, size.Z) * 1.78 + 0.2
	camera.CFrame = CFrame.lookAt(Vector3.new(0.6, 0.45, 0.9) * reach, Vector3.zero)
	table.insert(spinning, { model = model, base = model:GetPivot() })
end

local function outlined(label)
	local s = Instance.new("UIStroke")
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	s.Color = Color3.fromRGB(8, 43, 77)
	s.Thickness = 2
	s.Parent = label
end

local cards = {}
for order, addon in ipairs(FusionRecipes.Addons) do
	local card = Garage.New("Frame", grid, addon.name, { LayoutOrder = order })
	Garage.Inset(card)
	modelView(card, addon.name)

	local title = Garage.Text(card, "Title", ItemNames.Display(addon.name),
		UDim2.new(0, 8, 0, 170), UDim2.new(1, -16, 0, 36), 24)
	Garage.Plate(title)
	title.TextScaled = true

	local rarityName = ItemRarity.RarityName(addon.rarity) or string.upper(addon.rarity)
	local rarityColour = ItemRarity.RarityColor(addon.rarity)
	local makes = Garage.Text(card, "Makes", "Makes " .. rarityName .. " builds",
		UDim2.new(0, 8, 0, 208), UDim2.new(1, -16, 0, 24), 19, rarityColour)
	outlined(makes)

	-- What its builds are worth, so the three addons of a rarity can be
	-- told apart: each is a step up on the one before.
	local lowest, highest = FusionRecipes.BuildValueRange(addon.name)
	local worth = Garage.Text(card, "Worth", string.format("Builds worth %s–%s", commas(lowest), commas(highest)),
		UDim2.new(0, 8, 0, 234), UDim2.new(1, -16, 0, 24), 17, Color3.new(1, 1, 1))
	worth.TextScaled = true
	outlined(worth)

	-- The best addon of its rarity is the last of the three.
	local nextAddon = FusionRecipes.Addons[order + 1]
	if not nextAddon or nextAddon.rarity ~= addon.rarity then
		local best = Garage.Text(card, "Best", "BEST " .. rarityName,
			UDim2.new(1, -10, 0, 10), UDim2.fromOffset(120, 28), 16, Color3.new(1, 1, 1))
		best.AnchorPoint = Vector2.new(1, 0)
		best.TextScaled = true
		best.ZIndex = 6
		best.BackgroundTransparency = 0
		best.BackgroundColor3 = rarityColour
		Garage.New("UICorner", best, "Corner", { CornerRadius = UDim.new(0, 8) })
		outlined(best)
	end

	local buy = Garage.New("TextButton", card, "Purchase", {
		Text = commas(addon.price) .. " Coins", TextSize = 24, Font = Enum.Font.FredokaOne,
		Position = UDim2.new(0, 9, 1, -58), Size = UDim2.new(1, -18, 0, 48), ZIndex = 5,
	})
	Garage.Button(buy, GOLD)
	buy.Activated:Connect(function()
		if buy.Active then
			buyAddonRemote:FireServer(addon.name)
		end
	end)
	cards[addon.name] = { price = addon.price, button = buy, shown = 0 }
end

-- The server's answer to a purchase, shown on that addon's own button for
-- a moment. Toasts are drawn underneath the open Shop, so this is the only
-- feedback the buyer actually sees.
local RESULT_TEXT = {
	bought = "Added to Inventory!",
	full = "Inventory Full",
	coins = "Need More Coins",
}
local RESULT_SECONDS = 1.6

buyAddonRemote.OnClientEvent:Connect(function(addonName, result)
	local card = cards[addonName]
	local text = RESULT_TEXT[result]
	if not card or not text then return end
	card.shown += 1
	local shown = card.shown
	card.button.Text = text
	task.delay(RESULT_SECONDS, function()
		-- Only the latest answer puts the price back.
		if card.shown == shown then
			card.button.Text = commas(card.price) .. " Coins"
		end
	end)
end)

-- Greys out whatever you cannot afford yet. The server checks again on
-- every purchase; this is only so the button tells the truth.
local function refreshAffordable()
	local stats = player:FindFirstChild("leaderstats")
	local coins = stats and stats:FindFirstChild("Coins")
	local have = coins and coins.Value or 0
	for _, card in pairs(cards) do
		card.button.Active = have >= card.price
	end
end

task.spawn(function()
	local coins = player:WaitForChild("leaderstats"):WaitForChild("Coins")
	coins.Changed:Connect(refreshAffordable)
	refreshAffordable()
end)

------------------------------------------------------------------
-- Layout and switching
------------------------------------------------------------------

local showing = "shop"

local function layout()
	local compact = panel:GetAttribute("Compact")
	local width = compact and 600 or 1200
	local top = CONTENT_TOP
	if compact then
		-- No room beside the title: the tabs get their own row under it.
		shopTab.Position = UDim2.fromOffset(19, 92)
		addonsTab.Position = UDim2.fromOffset(19 + 150 + 10, 92)
		top = CONTENT_TOP + TAB_ROW
	else
		-- In the header, between the title plate and the close button.
		shopTab.Position = UDim2.fromOffset(width - 76 - 16 - 2 * 170 - 10, 17)
		addonsTab.Position = UDim2.fromOffset(width - 76 - 16 - 170, 17)
	end
	local tabWidth = compact and 150 or 170
	shopTab.Size = UDim2.fromOffset(tabWidth, 54)
	addonsTab.Size = UDim2.fromOffset(tabWidth, 54)

	for _, area in ipairs({ shopSections, page }) do
		area.Position = UDim2.fromOffset(19, top)
		area.Size = UDim2.new(1, -38, 1, -(top + 31))
	end

	local cols = compact and 2 or 5
	gridLayout.CellSize = UDim2.new(1 / cols, -12, 0, 330)
	grid.Size = UDim2.new(1, -4, 0, 0)
end

local function show(which)
	showing = which
	shopSections.Visible = which == "shop"
	page.Visible = which == "addons"
	shopTab.BackgroundColor3 = which == "shop" and GOLD or BLUE
	addonsTab.BackgroundColor3 = which == "addons" and GOLD or BLUE
end

shopTab.Activated:Connect(function() show("shop") end)
addonsTab.Activated:Connect(function() show("addons") end)
panel:GetAttributeChangedSignal("Compact"):Connect(layout)
layout()
show("shop")

-- A slow turn on each model while the tab is open, so it reads as a real
-- part on a display stand rather than a flat picture.
RunService.RenderStepped:Connect(function()
	if showing ~= "addons" or not page.Visible or not panel.Parent or not panel:IsDescendantOf(game) then return end
	local angle = os.clock() * 0.6
	for _, s in ipairs(spinning) do
		s.model:PivotTo(CFrame.Angles(0, angle, 0) * s.base)
	end
end)
