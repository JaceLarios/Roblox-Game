--[[
	ShopUI (LocalScript, StarterPlayerScripts) — Junkyard Fusion v1

	Replaces the old gamepass-only panel with a tabbed shop: PASSES (the
	original real-money gamepasses, untouched purchase logic), CODES
	(redeem a promo code for coins), and PETS (spend coins on a Tier-1
	item instead of grinding its drop rate). Pet Simulator-style tab bar
	across the top of one panel, rather than three separate popups.
--]]

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer

local Config = require(ReplicatedStorage:WaitForChild("GamepassConfig"))
local ShopPets = require(ReplicatedStorage:WaitForChild("ShopPets"))
local ItemRarity = require(ReplicatedStorage:WaitForChild("ItemRarity"))
local NavButton = require(ReplicatedStorage:WaitForChild("NavButton"))
local itemModels = ReplicatedStorage:WaitForChild("ItemModels")

local redeemCodeRemote = ReplicatedStorage:WaitForChild("RedeemCode")
local buyShopPetRemote = ReplicatedStorage:WaitForChild("BuyShopPet")

local gui = Instance.new("ScreenGui")
gui.Name = "ShopUI"
gui.ResetOnSpawn = false
gui.DisplayOrder = 20
gui.Parent = player:WaitForChild("PlayerGui")

local function corner(parent, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 10)
	c.Parent = parent
end
local function text(parent, name, value, pos, size, fontSize, color)
	local t = Instance.new("TextLabel")
	t.Name = name
	t.Text = value
	t.Position = pos
	t.Size = size
	t.BackgroundTransparency = 1
	t.TextColor3 = color or Color3.fromRGB(235, 235, 240)
	t.Font = Enum.Font.FredokaOne
	t.TextSize = fontSize
	t.TextWrapped = true
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.Parent = parent
	return t
end

-- Same signature palette as GameUI.client.luau — WHITE is this button's
-- own identity (Inventory/Index/Upgrades/Travel already claim the other
-- four), and BLUE/GREEN/RED double as the three tab accents inside.
local WHITE = Color3.fromRGB(255, 255, 255)
local BLUE  = Color3.fromRGB(70, 150, 255)
local GREEN = Color3.fromRGB(80, 220, 120)
local RED   = Color3.fromRGB(255, 80, 80)
local GOLD  = Color3.fromRGB(255, 200, 80)

-- Right rail, slot 3 (bottom) — same shared module GameUI.client.luau's
-- five nav buttons use, so this one reads as part of the same rail even
-- though it's a completely separate script/ScreenGui underneath.
local open = NavButton.Create(gui, "🛒", "SHOP", WHITE, NavButton.RailPosition("right", 3))

local overlay = Instance.new("Frame")
overlay.Name = "Overlay"
overlay.Size = UDim2.fromScale(1, 1)
overlay.BackgroundColor3 = Color3.new(0, 0, 0)
overlay.BackgroundTransparency = 0.3
overlay.Visible = false
overlay.Active = true
overlay.Parent = gui

local panel = Instance.new("Frame")
panel.Name = "ShopPanel"
panel.AnchorPoint = Vector2.new(0.5, 0.5)
panel.Position = UDim2.fromScale(0.5, 0.5)
panel.Size = UDim2.fromOffset(720, 600)
panel.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
panel.Parent = overlay
corner(panel, 14)

local panelStroke = Instance.new("UIStroke")
panelStroke.Color = Color3.fromRGB(255, 255, 255)
panelStroke.Transparency = 0.7
panelStroke.Thickness = 2
panelStroke.Parent = panel

local scale = Instance.new("UIScale")
scale.Parent = panel
local function fit()
	local size = overlay.AbsoluteSize
	scale.Scale = math.min(1, math.max(0.1, (size.X - 24) / 720), math.max(0.1, (size.Y - 24) / 600))
end
overlay:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
fit()

text(panel, "Title", "🛒 SHOP", UDim2.fromOffset(22, 16), UDim2.fromOffset(440, 34), 24, GOLD)

local close = Instance.new("TextButton")
close.Name = "Close"
close.Size = UDim2.fromOffset(34, 34)
close.Position = UDim2.new(1, -44, 0, 14)
close.Text = "X"
close.TextColor3 = Color3.fromRGB(235, 235, 240)
close.BackgroundTransparency = 1
close.Font = Enum.Font.FredokaOne
close.TextSize = 20
close.Parent = panel

------------------------------------------------------------------
-- Tabs
------------------------------------------------------------------

local TABS = {
	{ key = "passes", caption = "PASSES", accent = BLUE },
	{ key = "codes", caption = "CODES", accent = GREEN },
	{ key = "pets", caption = "PETS", accent = RED },
}

local tabBar = Instance.new("Frame")
tabBar.Size = UDim2.fromOffset(676, 44)
tabBar.Position = UDim2.fromOffset(22, 60)
tabBar.BackgroundTransparency = 1
tabBar.Parent = panel

local tabLayout = Instance.new("UIListLayout")
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.Padding = UDim.new(0, 10)
tabLayout.Parent = tabBar

local contentHolder = Instance.new("Frame")
contentHolder.Size = UDim2.fromOffset(676, 420)
contentHolder.Position = UDim2.fromOffset(22, 112)
contentHolder.BackgroundTransparency = 1
contentHolder.Parent = panel

local message = text(panel, "Message", "", UDim2.fromOffset(22, 540), UDim2.fromOffset(676, 30), 12, GOLD)

local tabButtons = {}
local tabFrames = {}
local tabAccent = {}

local function selectTab(key)
	for tabKey, btn in pairs(tabButtons) do
		local isActive = tabKey == key
		btn.BackgroundColor3 = isActive and tabAccent[tabKey] or Color3.fromRGB(40, 40, 48)
		btn.TextColor3 = isActive and NavButton.ReadableTextColor(tabAccent[tabKey]) or Color3.fromRGB(200, 200, 210)
	end
	for frameKey, frame in pairs(tabFrames) do
		frame.Visible = frameKey == key
	end
end

for i, tab in ipairs(TABS) do
	tabAccent[tab.key] = tab.accent

	local btn = Instance.new("TextButton")
	btn.Name = tab.key
	btn.Size = UDim2.fromOffset(218, 44)
	btn.LayoutOrder = i
	btn.Font = Enum.Font.LuckiestGuy
	btn.TextSize = 16
	btn.Text = tab.caption
	btn.BorderSizePixel = 0
	btn.Parent = tabBar
	corner(btn, 10)
	tabButtons[tab.key] = btn

	local frame = Instance.new("ScrollingFrame")
	frame.Name = tab.key .. "Content"
	frame.Size = UDim2.fromScale(1, 1)
	frame.CanvasSize = UDim2.new(0, 0, 0, 0)
	frame.AutomaticCanvasSize = Enum.AutomaticSize.Y
	frame.BackgroundTransparency = 1
	frame.BorderSizePixel = 0
	frame.ScrollBarThickness = 6
	frame.Visible = false
	frame.Parent = contentHolder
	tabFrames[tab.key] = frame

	btn.Activated:Connect(function() selectTab(tab.key) end)
end

selectTab("passes")

------------------------------------------------------------------
-- PASSES — unchanged purchase logic, just re-homed into its own tab.
------------------------------------------------------------------

local passesFrame = tabFrames.passes
local refreshers = {}
local pendingId = nil
-- One accent per pass so the panel doesn't read as three identical gray
-- boxes with a price sticker — each already has a distinct effect, now it
-- has a distinct color to match.
local ROW_COLORS = {
	DoubleCoins = GOLD,
	ExtraCarry = BLUE,
	AutoCollect = GREEN,
}

for i, key in ipairs({ "DoubleCoins", "ExtraCarry", "AutoCollect" }) do
	local item = Config[key]
	local accent = ROW_COLORS[key]
	local row = Instance.new("Frame")
	row.Name = key
	row.Position = UDim2.fromOffset(4, (i - 1) * 115)
	row.Size = UDim2.fromOffset(650, 105)
	row.BackgroundColor3 = accent:Lerp(Color3.fromRGB(20, 20, 26), 0.82)
	row.Parent = passesFrame
	corner(row)
	local rowStroke = Instance.new("UIStroke")
	rowStroke.Color = accent
	rowStroke.Transparency = 0.55
	rowStroke.Thickness = 1.5
	rowStroke.Parent = row
	text(row, "Title", item.name, UDim2.fromOffset(14, 10), UDim2.fromOffset(468, 26), 18, accent)
	text(row, "Description", item.description, UDim2.fromOffset(14, 38), UDim2.fromOffset(468, 58), 13)
	local buy = Instance.new("TextButton")
	buy.Name = "Buy"
	buy.Position = UDim2.fromOffset(496, 31)
	buy.Size = UDim2.fromOffset(140, 44)
	buy.Font = Enum.Font.FredokaOne
	buy.TextSize = 13
	buy.TextWrapped = true
	buy.Parent = row
	corner(buy)
	local info, loading = nil, false
	local function refresh()
		local owns = player:GetAttribute("Pass_" .. key) == true
		local status = player:GetAttribute("PassStatus_" .. key)
		local available = item.id > 0 and info and info.IsForSale == true and type(info.PriceInRobux) == "number"
		local enabled = not owns and available and status == "Ready" and pendingId == nil
		buy.Active = enabled == true
		buy.AutoButtonColor = enabled == true
		buy.BackgroundColor3 = enabled and GOLD or Color3.fromRGB(54, 54, 64)
		buy.TextColor3 = enabled and Color3.fromRGB(18, 18, 22) or Color3.fromRGB(210, 210, 220)
		if owns then
			buy.Text = "OWNED"
		elseif item.id <= 0 then
			buy.Text = "COMING SOON"
		elseif pendingId then
			buy.Text = "PLEASE WAIT"
		elseif status == "Retry" then
			buy.Text = "TRY LATER"
		elseif not status or status == "Checking" or loading then
			buy.Text = "CHECKING..."
		elseif available then
			buy.Text = tostring(info.PriceInRobux) .. " Robux"
		else
			buy.Text = "UNAVAILABLE"
		end
	end
	refreshers[key] = refresh
	player:GetAttributeChangedSignal("Pass_" .. key):Connect(refresh)
	player:GetAttributeChangedSignal("PassStatus_" .. key):Connect(refresh)
	buy.Activated:Connect(function()
		if not buy.Active then return end
		pendingId = item.id
		message.Text = ""
		for _, f in pairs(refreshers) do f() end
		local ok = pcall(function() MarketplaceService:PromptGamePassPurchase(player, item.id) end)
		if not ok then
			pendingId = nil
			message.Text = "Purchase prompt unavailable. Please try again."
			for _, f in pairs(refreshers) do f() end
		end
	end)
	local function loadInfo()
		if item.id <= 0 or loading then refresh() return end
		loading = true
		refresh()
		local ok, result = pcall(function()
			return MarketplaceService:GetProductInfo(item.id, Enum.InfoType.GamePass)
		end)
		info = ok and result or nil
		loading = false
		refresh()
	end
	open.Activated:Connect(function() task.spawn(loadInfo) end)
	refresh()
end

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(who, id, purchased)
	if who ~= player or pendingId ~= id then return end
	pendingId = nil
	message.Text = purchased and "Purchase completed. Your benefits update automatically." or ""
	for _, f in pairs(refreshers) do f() end
end)

------------------------------------------------------------------
-- CODES — a text box, a redeem button, and the server's toast for
-- feedback (success/failure/already-redeemed) — no separate inline
-- status needed here.
------------------------------------------------------------------

local codesFrame = tabFrames.codes

text(codesFrame, "Prompt", "Got a code? Type it in and redeem it below.",
	UDim2.fromOffset(4, 10), UDim2.fromOffset(640, 30), 16, Color3.fromRGB(235, 235, 240))

local codeBox = Instance.new("TextBox")
codeBox.Size = UDim2.fromOffset(420, 50)
codeBox.Position = UDim2.fromOffset(4, 54)
codeBox.BackgroundColor3 = Color3.fromRGB(30, 30, 36)
codeBox.Text = "" -- Instance.new("TextBox") defaults Text to "TextBox", which
-- would otherwise mask PlaceholderText below entirely.
codeBox.TextColor3 = Color3.fromRGB(235, 235, 240)
codeBox.PlaceholderText = "Enter code"
codeBox.PlaceholderColor3 = Color3.fromRGB(120, 120, 132)
codeBox.Font = Enum.Font.FredokaOne
codeBox.TextSize = 18
codeBox.ClearTextOnFocus = false
codeBox.BorderSizePixel = 0
codeBox.Parent = codesFrame
corner(codeBox, 8)
local codeBoxStroke = Instance.new("UIStroke")
codeBoxStroke.Color = GREEN
codeBoxStroke.Transparency = 0.5
codeBoxStroke.Thickness = 1.5
codeBoxStroke.Parent = codeBox

local redeemBtn = Instance.new("TextButton")
redeemBtn.Size = UDim2.fromOffset(200, 50)
redeemBtn.Position = UDim2.fromOffset(440, 54)
redeemBtn.BackgroundColor3 = GREEN
redeemBtn.TextColor3 = Color3.fromRGB(18, 18, 22)
redeemBtn.Font = Enum.Font.LuckiestGuy
redeemBtn.TextSize = 16
redeemBtn.Text = "REDEEM"
redeemBtn.BorderSizePixel = 0
redeemBtn.Parent = codesFrame
corner(redeemBtn, 8)

local function submitCode()
	local code = codeBox.Text
	if code == "" then return end
	redeemCodeRemote:FireServer(code)
	codeBox.Text = ""
end

redeemBtn.Activated:Connect(submitCode)
codeBox.FocusLost:Connect(function(enterPressed)
	if enterPressed then submitCode() end
end)

------------------------------------------------------------------
-- PETS — spend coins for a "leg up" instead of grinding the drop rate.
------------------------------------------------------------------

local petsFrame = tabFrames.pets
local petsLayout = Instance.new("UIGridLayout")
petsLayout.CellSize = UDim2.fromOffset(150, 210)
petsLayout.CellPadding = UDim2.fromOffset(10, 10)
petsLayout.Parent = petsFrame

local function buildPetIcon(parent, itemName)
	local viewport = Instance.new("ViewportFrame")
	viewport.Size = UDim2.new(1, -16, 0, 100)
	viewport.Position = UDim2.new(0, 8, 0, 8)
	viewport.BackgroundTransparency = 1
	viewport.Parent = parent

	local cam = Instance.new("Camera")
	viewport.CurrentCamera = cam
	cam.Parent = viewport

	local template = itemModels:FindFirstChild(itemName)
	if template then
		local clone = template:Clone()
		clone.Anchored = true
		clone.CFrame = CFrame.new(0, 0, 0)
		clone.Parent = viewport

		local size = clone.Size
		local reach = math.max(size.X, size.Y, size.Z) * 1.5 + 1.5
		cam.CFrame = CFrame.new(Vector3.new(reach * 0.6, reach * 0.5, reach * 0.85), Vector3.new(0, 0, 0))
	end
end

local petRefreshers = {}

local function refreshAllPetCards()
	for _, f in ipairs(petRefreshers) do f() end
end

for i, entry in ipairs(ShopPets) do
	local rarityColor = ItemRarity.Color(1, false)

	local card = Instance.new("Frame")
	card.LayoutOrder = i
	card.BackgroundColor3 = rarityColor:Lerp(Color3.fromRGB(18, 18, 24), 0.55)
	card.BorderSizePixel = 0
	card.Parent = petsFrame
	corner(card, 10)

	local cardStroke = Instance.new("UIStroke")
	cardStroke.Color = rarityColor
	cardStroke.Thickness = 2
	cardStroke.Parent = card

	buildPetIcon(card, entry.item)

	text(card, "Name", entry.item, UDim2.fromOffset(8, 112), UDim2.fromOffset(134, 36), 14,
		Color3.fromRGB(255, 255, 255))

	local buy = Instance.new("TextButton")
	buy.Size = UDim2.fromOffset(134, 40)
	buy.Position = UDim2.fromOffset(8, 158)
	buy.Font = Enum.Font.LuckiestGuy
	buy.TextSize = 14
	buy.BorderSizePixel = 0
	buy.Parent = card
	corner(buy, 8)

	local function refreshAfford()
		local stats = player:FindFirstChild("leaderstats")
		local coins = stats and stats:FindFirstChild("Coins")
		local balance = coins and coins.Value or 0
		local afford = balance >= entry.cost
		buy.BackgroundColor3 = afford and GOLD or Color3.fromRGB(54, 54, 64)
		buy.TextColor3 = afford and Color3.fromRGB(18, 18, 22) or Color3.fromRGB(210, 210, 220)
		buy.Text = string.format("%d coins", entry.cost)
	end

	buy.Activated:Connect(function()
		buyShopPetRemote:FireServer(i)
	end)

	table.insert(petRefreshers, refreshAfford)
	refreshAfford()
end

open.Activated:Connect(function() task.spawn(refreshAllPetCards) end)

task.spawn(function()
	local stats = player:WaitForChild("leaderstats", 20)
	if not stats then return end
	local coins = stats:WaitForChild("Coins", 20)
	if not coins then return end
	coins.Changed:Connect(refreshAllPetCards)
end)

------------------------------------------------------------------

open.Activated:Connect(function()
	overlay.Visible = not overlay.Visible
	if overlay.Visible then fit() end
end)
close.Activated:Connect(function() overlay.Visible = false end)
