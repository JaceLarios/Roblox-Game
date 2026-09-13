local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local player = Players.LocalPlayer
local Config = require(ReplicatedStorage:WaitForChild("GamepassConfig"))
local gui = Instance.new("ScreenGui")
gui.Name = "GamepassUI"
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
	t.TextColor3 = color or Color3.fromRGB(235,235,240)
	t.Font = Enum.Font.FredokaOne
	t.TextSize = fontSize
	t.TextWrapped = true
	t.TextXAlignment = Enum.TextXAlignment.Left
	t.Parent = parent
	return t
end
-- Right rail, slot 3 (bottom) — matches GameUI.client.luau's nav-tile rail
-- exactly (same NAV_BTN_SIZE/NAV_GAP/centering math) even though this is a
-- separate script/ScreenGui, since GamepassUI predates the shared helper
-- and is just the one button — not worth a cross-script module for that.
local NAV_BTN_SIZE = 104
local NAV_GAP = 18
local RAIL_HEIGHT = 3 * NAV_BTN_SIZE + 2 * NAV_GAP
local ACCENT = Color3.fromRGB(255, 90, 180)

local open = Instance.new("TextButton")
open.Name = "OpenPasses"
open.Size = UDim2.new(0, NAV_BTN_SIZE, 0, NAV_BTN_SIZE)
open.Position = UDim2.new(1, -20 - NAV_BTN_SIZE, 0.5, 2 * (NAV_BTN_SIZE + NAV_GAP) - RAIL_HEIGHT / 2)
open.Text = ""
open.AutoButtonColor = false
open.BackgroundColor3 = ACCENT:Lerp(Color3.new(0, 0, 0), 0.7)
open.Parent = gui
corner(open, 20)

local openGradient = Instance.new("UIGradient")
openGradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, ACCENT:Lerp(Color3.new(1, 1, 1), 0.15)),
	ColorSequenceKeypoint.new(1, ACCENT:Lerp(Color3.new(0, 0, 0), 0.5)),
})
openGradient.Rotation = 90
openGradient.Parent = open

local openStroke = Instance.new("UIStroke")
openStroke.Color = ACCENT
openStroke.Thickness = 2
openStroke.Transparency = 0.25
openStroke.Parent = open

text(open, "Icon", "💎", UDim2.fromOffset(0, 10), UDim2.new(1, 0, 0, 46), 38, Color3.fromRGB(255, 255, 255))
	.TextXAlignment = Enum.TextXAlignment.Center
local openCaption = text(open, "Caption", "PASSES", UDim2.fromOffset(4, 60), UDim2.new(1, -8, 0, 18), 13, Color3.fromRGB(255, 255, 255))
openCaption.TextXAlignment = Enum.TextXAlignment.Center
openCaption.TextScaled = true

local TweenService = game:GetService("TweenService")
local openBaseSize = open.Size
local openHoverSize = UDim2.new(0, NAV_BTN_SIZE + 10, 0, NAV_BTN_SIZE + 10)
local openPressSize = UDim2.new(0, NAV_BTN_SIZE - 6, 0, NAV_BTN_SIZE - 6)
local openHovering = false

open.MouseEnter:Connect(function()
	openHovering = true
	TweenService:Create(open, TweenInfo.new(0.15, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = openHoverSize }):Play()
	TweenService:Create(openStroke, TweenInfo.new(0.15), { Thickness = 3, Transparency = 0 }):Play()
end)
open.MouseLeave:Connect(function()
	openHovering = false
	TweenService:Create(open, TweenInfo.new(0.15), { Size = openBaseSize }):Play()
	TweenService:Create(openStroke, TweenInfo.new(0.15), { Thickness = 2, Transparency = 0.25 }):Play()
end)
open.MouseButton1Down:Connect(function()
	TweenService:Create(open, TweenInfo.new(0.08), { Size = openPressSize }):Play()
end)
open.MouseButton1Up:Connect(function()
	TweenService:Create(open, TweenInfo.new(0.12, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Size = openHovering and openHoverSize or openBaseSize }):Play()
end)

local overlay = Instance.new("Frame")
overlay.Name = "Overlay"
overlay.Size = UDim2.fromScale(1,1)
overlay.BackgroundColor3 = Color3.new(0,0,0)
overlay.BackgroundTransparency = 0.3
overlay.Visible = false
overlay.Active = true
overlay.Parent = gui

local panel = Instance.new("Frame")
panel.Name = "PassPanel"
panel.AnchorPoint = Vector2.new(0.5,0.5)
panel.Position = UDim2.fromScale(0.5,0.5)
panel.Size = UDim2.fromOffset(540,490)
panel.BackgroundColor3 = Color3.fromRGB(18,18,22)
panel.Parent = overlay
corner(panel,14)
local scale = Instance.new("UIScale")
scale.Parent = panel
local function fit()
	local size = overlay.AbsoluteSize
	scale.Scale = math.min(1, math.max(0.1,(size.X-24)/540), math.max(0.1,(size.Y-24)/490))
end
overlay:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
fit()
text(panel,"Title","MAKE EACH TRIP COUNT",UDim2.fromOffset(22,16),UDim2.fromOffset(440,30),21,Color3.fromRGB(255,200,80))
text(panel,"Subtitle","One-time purchases. Keep your earned upgrades.",UDim2.fromOffset(22,50),UDim2.fromOffset(490,32),13)
local close = Instance.new("TextButton")
close.Name = "Close"
close.Size = UDim2.fromOffset(34,34)
close.Position = UDim2.new(1,-44,0,12)
close.Text = "X"
close.TextColor3 = Color3.fromRGB(235,235,240)
close.BackgroundTransparency = 1
close.Font = Enum.Font.FredokaOne
close.TextSize = 18
close.Parent = panel
local message = text(panel,"Message","",UDim2.fromOffset(22,440),UDim2.fromOffset(496,38),12,Color3.fromRGB(255,200,80))
local refreshers = {}
local pendingId = nil
-- One accent per pass so the panel doesn't read as three identical gray
-- boxes with a price sticker — each already has a distinct effect, now it
-- has a distinct color to match.
local ROW_COLORS = {
	DoubleCoins = Color3.fromRGB(255, 205, 40),
	ExtraCarry = Color3.fromRGB(90, 200, 255),
	AutoCollect = Color3.fromRGB(120, 255, 120),
}

for i,key in ipairs({"DoubleCoins","ExtraCarry","AutoCollect"}) do
	local item = Config[key]
	local accent = ROW_COLORS[key]
	local row = Instance.new("Frame")
	row.Name = key
	row.Position = UDim2.fromOffset(20,90+(i-1)*115)
	row.Size = UDim2.fromOffset(500,105)
	row.BackgroundColor3 = accent:Lerp(Color3.fromRGB(20, 20, 26), 0.82)
	row.Parent = panel
	corner(row)
	local rowStroke = Instance.new("UIStroke")
	rowStroke.Color = accent
	rowStroke.Transparency = 0.55
	rowStroke.Thickness = 1.5
	rowStroke.Parent = row
	text(row,"Title",item.name,UDim2.fromOffset(14,10),UDim2.fromOffset(318,26),18,accent)
	text(row,"Description",item.description,UDim2.fromOffset(14,38),UDim2.fromOffset(318,58),13)
	local buy = Instance.new("TextButton")
	buy.Name = "Buy"
	buy.Position = UDim2.fromOffset(346,31)
	buy.Size = UDim2.fromOffset(140,44)
	buy.Font = Enum.Font.FredokaOne
	buy.TextSize = 13
	buy.TextWrapped = true
	buy.Parent = row
	corner(buy)
	local info, loading = nil, false
	local function refresh()
		local owns = player:GetAttribute("Pass_"..key) == true
		local status = player:GetAttribute("PassStatus_"..key)
		local available = item.id > 0 and info and info.IsForSale == true and type(info.PriceInRobux) == "number"
		local enabled = not owns and available and status == "Ready" and pendingId == nil
		buy.Active = enabled == true
		buy.AutoButtonColor = enabled == true
		buy.BackgroundColor3 = enabled and Color3.fromRGB(255,200,80) or Color3.fromRGB(54,54,64)
		buy.TextColor3 = enabled and Color3.fromRGB(18,18,22) or Color3.fromRGB(210,210,220)
		if owns then buy.Text = "OWNED"
		elseif item.id <= 0 then buy.Text = "COMING SOON"
		elseif pendingId then buy.Text = "PLEASE WAIT"
		elseif status == "Retry" then buy.Text = "TRY LATER"
		elseif not status or status == "Checking" or loading then buy.Text = "CHECKING..."
		elseif available then buy.Text = tostring(info.PriceInRobux) .. " Robux"
		else buy.Text = "UNAVAILABLE" end
	end
	refreshers[key] = refresh
	player:GetAttributeChangedSignal("Pass_"..key):Connect(refresh)
	player:GetAttributeChangedSignal("PassStatus_"..key):Connect(refresh)
	buy.Activated:Connect(function()
		if not buy.Active then return end
		pendingId = item.id
		message.Text = ""
		for _,f in pairs(refreshers) do f() end
		local ok = pcall(function() MarketplaceService:PromptGamePassPurchase(player,item.id) end)
		if not ok then
			pendingId = nil
			message.Text = "Purchase prompt unavailable. Please try again."
			for _,f in pairs(refreshers) do f() end
		end
	end)
	local function loadInfo()
		if item.id <= 0 or loading then refresh() return end
		loading = true
		refresh()
		local ok,result = pcall(function()
			return MarketplaceService:GetProductInfo(item.id,Enum.InfoType.GamePass)
		end)
		info = ok and result or nil
		loading = false
		refresh()
	end
	open.Activated:Connect(function() task.spawn(loadInfo) end)
	refresh()
end
open.Activated:Connect(function()
	overlay.Visible = not overlay.Visible
	if overlay.Visible then fit() end
end)
close.Activated:Connect(function() overlay.Visible = false end)
MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(who,id,purchased)
	if who ~= player or pendingId ~= id then return end
	pendingId = nil
	message.Text = purchased and "Purchase completed. Your benefits update automatically." or ""
	for _,f in pairs(refreshers) do f() end
end)
