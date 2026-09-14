--[[
	ShopUI (LocalScript, StarterPlayerScripts) — Junkyard Fusion v1

	One continuous scrollable panel, no tab bar: a "redeem a code" banner
	up top, then one big animated gradient banner per gamepass, built
	generically from GamepassConfig so a brand new pass just needs a new
	config entry, not new UI code (see addFloatingIcons below).

	Pets were pulled out entirely — the old coin-purchasable pets were
	just existing discoverable items with a price tag, which undercut the
	point of a "shop exclusive." A future pass adds real shop-only pets
	that don't exist anywhere else in the game.
--]]

local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local player = Players.LocalPlayer

local Config = require(ReplicatedStorage:WaitForChild("GamepassConfig"))
local NavButton = require(ReplicatedStorage:WaitForChild("NavButton"))

local redeemCodeRemote = ReplicatedStorage:WaitForChild("RedeemCode")

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
	t.ZIndex = 2
	t.Parent = parent
	return t
end

-- Same signature palette as GameUI.client.luau.
local WHITE = Color3.fromRGB(255, 255, 255)
local BLUE  = Color3.fromRGB(70, 150, 255)
local GREEN = Color3.fromRGB(80, 220, 120)
local GOLD  = Color3.fromRGB(255, 200, 80)

-- Right rail, slot 3 (bottom) — same shared module GameUI.client.luau's
-- nav buttons use, so this one reads as part of the same rail even
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
panel.Size = UDim2.fromOffset(780, 660)
panel.BackgroundColor3 = Color3.fromRGB(18, 18, 22)
panel.Parent = overlay
corner(panel, 18)

local panelStroke = Instance.new("UIStroke")
panelStroke.Color = Color3.fromRGB(255, 255, 255)
panelStroke.Transparency = 0.7
panelStroke.Thickness = 2
panelStroke.Parent = panel

local scale = Instance.new("UIScale")
scale.Parent = panel
local function fit()
	local size = overlay.AbsoluteSize
	scale.Scale = math.min(1, math.max(0.1, (size.X - 24) / 780), math.max(0.1, (size.Y - 24) / 660))
end
overlay:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
fit()

text(panel, "Title", "🛒 SHOP", UDim2.fromOffset(24, 16), UDim2.fromOffset(440, 36), 26, GOLD)

local close = Instance.new("TextButton")
close.Name = "Close"
close.Size = UDim2.fromOffset(36, 36)
close.Position = UDim2.new(1, -46, 0, 16)
close.Text = "X"
close.TextColor3 = Color3.fromRGB(235, 235, 240)
close.BackgroundTransparency = 1
close.Font = Enum.Font.FredokaOne
close.TextSize = 20
close.ZIndex = 2
close.Parent = panel

-- One continuous scroll — no tab bar. Everything is a big bright banner
-- card stacked vertically, Pet-Simulator-shop style.
local scroll = Instance.new("ScrollingFrame")
scroll.Size = UDim2.new(1, -44, 1, -140)
scroll.Position = UDim2.fromOffset(22, 66)
scroll.BackgroundTransparency = 1
scroll.BorderSizePixel = 0
scroll.ScrollBarThickness = 8
scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
scroll.Parent = panel

local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 16)
listLayout.Parent = scroll

local message = text(panel, "Message", "", UDim2.fromOffset(24, 620), UDim2.fromOffset(732, 30), 12, GOLD)
message.TextXAlignment = Enum.TextXAlignment.Center

------------------------------------------------------------------
-- A handful of emoji drifting slowly and looping within a card's own
-- bounds — purely decorative, the "alive" background other games use
-- behind currency/gamepass banners. Reusable: a future gamepass just
-- lists icons in GamepassConfig's bgIcons field and calls this once.
------------------------------------------------------------------
local function addFloatingIcons(parent, icons)
	if not icons then return end
	parent.ClipsDescendants = true
	for _, icon in ipairs(icons) do
		local lbl = Instance.new("TextLabel")
		lbl.BackgroundTransparency = 1
		lbl.Text = icon
		lbl.Font = Enum.Font.FredokaOne
		lbl.TextSize = math.random(26, 42)
		lbl.TextTransparency = 0.6
		lbl.Rotation = math.random(-18, 18)
		lbl.Size = UDim2.fromOffset(50, 50)
		lbl.ZIndex = 1
		local startX = math.random(0, 100) / 100
		local startY = math.random(0, 100) / 100
		lbl.Position = UDim2.fromScale(startX, startY)
		lbl.Parent = parent

		-- Slow independent drift per icon, Reverse-looped so nothing snaps
		-- back to its start — it just glides back and forth forever.
		local duration = math.random(28, 48) / 10
		local dx = math.random(-14, 14) / 100
		local dy = math.random(-14, 14) / 100
		TweenService:Create(lbl, TweenInfo.new(duration, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
			Position = UDim2.fromScale(math.clamp(startX + dx, 0, 1), math.clamp(startY + dy, 0, 1)),
		}):Play()
	end
end

------------------------------------------------------------------
-- Redeem a code — its own bright banner instead of a separate tab.
------------------------------------------------------------------

local codeBanner = Instance.new("Frame")
codeBanner.Name = "CodeBanner"
codeBanner.Size = UDim2.new(1, 0, 0, 130)
codeBanner.LayoutOrder = 1
codeBanner.BackgroundColor3 = GREEN
codeBanner.BorderSizePixel = 0
codeBanner.Parent = scroll
corner(codeBanner, 18)

local codeGradient = Instance.new("UIGradient")
codeGradient.Color = ColorSequence.new(GREEN:Lerp(Color3.new(1, 1, 1), 0.25), GREEN:Lerp(Color3.new(0, 0, 0), 0.25))
codeGradient.Rotation = 25
codeGradient.Parent = codeBanner

local codeStroke = Instance.new("UIStroke")
codeStroke.Color = Color3.new(1, 1, 1)
codeStroke.Thickness = 3
codeStroke.Transparency = 0.3
codeStroke.Parent = codeBanner

addFloatingIcons(codeBanner, { "🎁", "⭐", "🎁" })

local codeIconBadge = Instance.new("Frame")
codeIconBadge.Size = UDim2.fromOffset(90, 90)
codeIconBadge.Position = UDim2.fromOffset(18, 20)
codeIconBadge.BackgroundColor3 = Color3.new(1, 1, 1)
codeIconBadge.BackgroundTransparency = 0.15
codeIconBadge.ZIndex = 2
codeIconBadge.Parent = codeBanner
corner(codeIconBadge, 45)

local codeIcon = text(codeIconBadge, "Icon", "🎁", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 48)
codeIcon.TextXAlignment = Enum.TextXAlignment.Center
codeIcon.TextYAlignment = Enum.TextYAlignment.Center

local codeTitle = text(codeBanner, "Title", "REDEEM A CODE", UDim2.fromOffset(124, 18), UDim2.fromOffset(300, 30), 22, Color3.new(1, 1, 1))
codeTitle.TextStrokeTransparency = 0.5

local codeSub = text(codeBanner, "Sub", "Got a code? Type it in and redeem it.", UDim2.fromOffset(124, 50), UDim2.fromOffset(300, 20), 13, Color3.new(1, 1, 1))
codeSub.TextTransparency = 0.1

local codeBox = Instance.new("TextBox")
codeBox.Size = UDim2.fromOffset(320, 46)
codeBox.Position = UDim2.fromOffset(124, 76)
codeBox.BackgroundColor3 = Color3.new(1, 1, 1)
codeBox.Text = "" -- Instance.new("TextBox") defaults Text to "TextBox", which
-- would otherwise mask PlaceholderText below entirely.
codeBox.TextColor3 = Color3.fromRGB(30, 30, 36)
codeBox.PlaceholderText = "Enter code"
codeBox.PlaceholderColor3 = Color3.fromRGB(150, 150, 158)
codeBox.Font = Enum.Font.FredokaOne
codeBox.TextSize = 18
codeBox.ClearTextOnFocus = false
codeBox.BorderSizePixel = 0
codeBox.ZIndex = 2
codeBox.Parent = codeBanner
corner(codeBox, 10)

local redeemBtn = Instance.new("TextButton")
redeemBtn.Size = UDim2.fromOffset(150, 46)
redeemBtn.Position = UDim2.fromOffset(456, 76)
redeemBtn.BackgroundColor3 = GOLD
redeemBtn.TextColor3 = Color3.fromRGB(30, 30, 36)
redeemBtn.Font = Enum.Font.LuckiestGuy
redeemBtn.TextSize = 16
redeemBtn.Text = "REDEEM"
redeemBtn.BorderSizePixel = 0
redeemBtn.ZIndex = 2
redeemBtn.Parent = codeBanner
corner(redeemBtn, 10)

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
-- Gamepasses — one big animated banner each, built generically from
-- GamepassConfig so a new pass just needs a new config entry.
------------------------------------------------------------------

local PASS_ORDER = { "DoubleCoins", "ExtraCarry", "AutoCollect" }
local PASS_ACCENTS = {
	DoubleCoins = GOLD,
	ExtraCarry = BLUE,
	AutoCollect = GREEN,
}

local refreshers = {}
local pendingId = nil

for i, key in ipairs(PASS_ORDER) do
	local item = Config[key]
	local accent = PASS_ACCENTS[key] or WHITE

	local banner = Instance.new("Frame")
	banner.Name = key
	banner.Size = UDim2.new(1, 0, 0, 150)
	banner.LayoutOrder = i + 1
	banner.BackgroundColor3 = accent
	banner.BorderSizePixel = 0
	banner.Parent = scroll
	corner(banner, 18)

	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(accent:Lerp(Color3.new(1, 1, 1), 0.3), accent:Lerp(Color3.new(0, 0, 0), 0.25))
	gradient.Rotation = 25
	gradient.Parent = banner

	local bannerStroke = Instance.new("UIStroke")
	bannerStroke.Color = Color3.new(1, 1, 1)
	bannerStroke.Thickness = 3
	bannerStroke.Transparency = 0.25
	bannerStroke.Parent = banner

	addFloatingIcons(banner, item.bgIcons)

	local iconBadge = Instance.new("Frame")
	iconBadge.Size = UDim2.fromOffset(96, 96)
	iconBadge.Position = UDim2.fromOffset(18, 27)
	iconBadge.BackgroundColor3 = Color3.new(1, 1, 1)
	iconBadge.BackgroundTransparency = 0.15
	iconBadge.ZIndex = 2
	iconBadge.Parent = banner
	corner(iconBadge, 48)

	local iconLbl = text(iconBadge, "Icon", item.icon or "⭐", UDim2.fromScale(0, 0), UDim2.fromScale(1, 1), 52)
	iconLbl.TextXAlignment = Enum.TextXAlignment.Center
	iconLbl.TextYAlignment = Enum.TextYAlignment.Center

	local nameLbl = text(banner, "Title", item.name, UDim2.fromOffset(130, 20), UDim2.fromOffset(360, 32), 24, Color3.new(1, 1, 1))
	nameLbl.TextStrokeTransparency = 0.5

	local descLbl = text(banner, "Description", item.description, UDim2.fromOffset(130, 56), UDim2.fromOffset(360, 74), 13, Color3.new(1, 1, 1))
	descLbl.TextTransparency = 0.1

	local buy = Instance.new("TextButton")
	buy.Name = "Buy"
	buy.Size = UDim2.fromOffset(160, 52)
	buy.Position = UDim2.new(1, -178, 0.5, -26)
	buy.Font = Enum.Font.FredokaOne
	buy.TextSize = 14
	buy.TextWrapped = true
	buy.ZIndex = 2
	buy.Parent = banner
	corner(buy, 12)

	local info, loading = nil, false
	local function refresh()
		local owns = player:GetAttribute("Pass_" .. key) == true
		local status = player:GetAttribute("PassStatus_" .. key)
		local available = item.id > 0 and info and info.IsForSale == true and type(info.PriceInRobux) == "number"
		local enabled = not owns and available and status == "Ready" and pendingId == nil
		buy.Active = enabled == true
		buy.AutoButtonColor = enabled == true
		buy.BackgroundColor3 = enabled and GOLD or Color3.new(1, 1, 1)
		buy.TextColor3 = Color3.fromRGB(30, 30, 36)
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

open.Activated:Connect(function()
	overlay.Visible = not overlay.Visible
	if overlay.Visible then fit() end
end)
close.Activated:Connect(function() overlay.Visible = false end)
