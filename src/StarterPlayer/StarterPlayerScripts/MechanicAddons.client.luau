-- Separate mechanic menu; replaces ShopAddons only when migration is applied.
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
local playerGui=player:WaitForChild("PlayerGui")
local shopGui=Instance.new("ScreenGui");shopGui.Name="MechanicShop";shopGui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling;shopGui.ResetOnSpawn=false;shopGui.DisplayOrder=30;shopGui.Enabled=false;shopGui.Parent=playerGui
-- Counts as an open menu, so the HUD buttons and phone controls step aside.
require(ReplicatedStorage:WaitForChild("UIStyle")).ModalGui(shopGui)
local panel=Garage.New("Frame",shopGui,"MechanicPanel",{})
Garage.Shell(panel);Garage.Fit(panel)
local title=Garage.Text(panel,"Title","MECHANIC - ADDONS",UDim2.fromOffset(18,14),UDim2.new(1,-94,0,54),28)
Garage.Header(title);title.TextScaled=true
local close=Garage.New("TextButton",panel,"Close",{Text="X",Position=UDim2.new(1,-62,0,14),Size=UDim2.fromOffset(46,46),ZIndex=10})
Garage.Button(close,Color3.fromRGB(255,88,30))
close.Activated:Connect(function()shopGui.Enabled=false end)
local desk
ReplicatedStorage:WaitForChild("OpenMechanicShop").OnClientEvent:Connect(function(counter)
 desk=counter;shopGui.Enabled=true
end)
local GOLD = Color3.fromRGB(255, 199, 47)
local BLUE = Color3.fromRGB(121, 154, 200)
local PEDESTAL = Color3.fromRGB(59, 229, 204)

local function commas(n)
	local s = tostring(math.floor(n))
	local formatted = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (formatted:gsub("^,", ""))
end

local page = Garage.New("ScrollingFrame", panel, "AddonsSection", {
	BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 7,
	ScrollBarImageColor3 = Color3.fromRGB(8, 43, 77), AutomaticCanvasSize = Enum.AutomaticSize.Y,
	CanvasSize = UDim2.new(), Visible = true, ZIndex = 2,
})
Garage.New("UIListLayout", page, "Layout", { Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder })
Garage.New("UIPadding", page, "Padding", { PaddingTop = UDim.new(0, 4), PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 10) })

local intro = Garage.Text(page, "Intro",
    "Pick an addon for your next build. Purchases go straight to your inventory.",
	UDim2.new(), UDim2.new(1, -8, 0, 72), 22, Color3.new(1, 1, 1))
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
		BackgroundTransparency = 1, Position = UDim2.fromOffset(8, 8), Size = UDim2.new(1, -16, 0, 176),
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

-- Only what is for sale: the Day 7 Warp Drive is never in the Shop.
local cards = {}
for order, addon in ipairs(FusionRecipes.ShopAddons) do
	local card = Garage.New("Frame", grid, addon.name, { LayoutOrder = order })
	Garage.Inset(card)
	modelView(card, addon.name)

	local title = Garage.Text(card, "Title", ItemNames.Display(addon.name),
		UDim2.new(0, 8, 0, 190), UDim2.new(1, -16, 0, 36), 24)
	Garage.Plate(title)
	title.TextScaled = true

	local rarityName = ItemRarity.RarityName(addon.rarity) or string.upper(addon.rarity)
	-- The addon's own rarity: a build starts there and its car can move it
	-- a rarity up or down (FusionRecipes), so not "Makes X builds".
	local makes = Garage.Text(card, "Makes", rarityName .. " addon",
		UDim2.new(0, 8, 0, 230), UDim2.new(1, -16, 0, 26), 19, ItemRarity.RarityColor(addon.rarity))
	local makesStroke = Instance.new("UIStroke")
	makesStroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	makesStroke.Color = Color3.fromRGB(8, 43, 77)
	makesStroke.Thickness = 2
	makesStroke.Parent = makes

	local buy = Garage.New("TextButton", card, "Purchase", {
		Text = commas(addon.price) .. " Coins", TextSize = 24, Font = Enum.Font.FredokaOne,
		Position = UDim2.new(0, 9, 1, -58), Size = UDim2.new(1, -18, 0, 48), ZIndex = 5,
	})
	Garage.Button(buy, GOLD)
	local function purchase()
		if buy.Active and shopGui.Enabled then
			buyAddonRemote:FireServer(addon.name)
		end
	end
	buy.Activated:Connect(purchase)
	-- The whole card buys, not just its button: people tap the model.
	local cardButton = Garage.New("TextButton", card, "CardButton", {
		Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 4,
	})
	cardButton.Activated:Connect(purchase)
	cards[addon.name] = { price = addon.price, button = buy, shown = 0 }
end

-- The server's answer to a purchase, shown on that addon's own button for
-- a moment. Toasts are drawn underneath the open Shop, so this is the only
-- feedback the buyer actually sees.
local RESULT_TEXT = {
	bought = "Added to Inventory!",
	away = "Visit your mechanic",
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


local function layout()
 page.Position=UDim2.fromOffset(19,84);page.Size=UDim2.new(1,-38,1,-103)
 local cols=panel:GetAttribute("Compact") and 2 or 3
 gridLayout.CellSize=UDim2.new(1/cols,-12,0,330);grid.Size=UDim2.new(1,-4,0,0)
end
panel:GetAttributeChangedSignal("Compact"):Connect(layout);layout()
RunService.RenderStepped:Connect(function()
 if not shopGui.Enabled then return end
 local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
 if not root or not desk or not desk.Parent or (root.Position-desk.Position).Magnitude>14 then shopGui.Enabled=false;return end
 local angle=os.clock()*.6
 for _,s in spinning do s.model:PivotTo(CFrame.Angles(0,angle,0)*s.base)end
end)

