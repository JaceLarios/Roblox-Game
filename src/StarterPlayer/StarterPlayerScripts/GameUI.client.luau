local Garage = require(game:GetService("ReplicatedStorage"):WaitForChild("GarageTheme"))
local ItemNames = require(game:GetService("ReplicatedStorage"):WaitForChild("ItemNames"))
--[[
	GameUI (LocalScript, StarterPlayerScripts) — Junkyard Fusion v1

	Two pieces:
	  • Carry bar        (bottom)       — what's in your hands
	  • Item index       (press B)      — every item, masked until found, and what you've discovered

	(The on-screen objective card and discoveries panel were removed
	2026-09-14 at the user's request — the Index already covers "what
	have I found," and there's no need to say it twice.)

	Display only. The server decides everything and sends state down;
	this just draws it. A client that decides nothing can cheat nothing.
--]]

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService      = game:GetService("TweenService")
local UserInputService  = game:GetService("UserInputService")

local player = Players.LocalPlayer
local remote = ReplicatedStorage:WaitForChild("GameUpdate")
local buyRemote = ReplicatedStorage:WaitForChild("BuyUpgrade")
local claimRemote = ReplicatedStorage:WaitForChild("ClaimDaily")
local rebirthRemote = ReplicatedStorage:WaitForChild("RebirthPlayer")
local equipCompanionRemote = ReplicatedStorage:WaitForChild("EquipCompanion")
local sellInventoryRemote = ReplicatedStorage:WaitForChild("SellInventoryItem")
local moveToCarryRemote = ReplicatedStorage:WaitForChild("MoveToCarry")
local placePetRemote = ReplicatedStorage:WaitForChild("PlacePet")
local unplacePetRemote = ReplicatedStorage:WaitForChild("UnplacePet")
local selectTradeOfferRemote = ReplicatedStorage:WaitForChild("SelectTradeOffer")
local confirmTradeRemote = ReplicatedStorage:WaitForChild("ConfirmTrade")
local cancelTradeRemote = ReplicatedStorage:WaitForChild("CancelTrade")
local startTradeWithRemote = ReplicatedStorage:WaitForChild("StartTradeWith")

local FusionRecipes = require(ReplicatedStorage:WaitForChild("FusionRecipes"))
local BrainrotRecipes = require(ReplicatedStorage:WaitForChild("BrainrotRecipes"))
local ItemRarity = require(ReplicatedStorage:WaitForChild("ItemRarity"))
local EventConfig = require(ReplicatedStorage:WaitForChild("EventConfig"))
local Mutations = require(ReplicatedStorage:WaitForChild("Mutations"))
local NavButton = require(ReplicatedStorage:WaitForChild("NavButton"))
local UIStyle = require(ReplicatedStorage:WaitForChild("UIStyle"))
local itemModels = ReplicatedStorage:WaitForChild("ItemModels")

local ItemVisuals = require(ReplicatedStorage:WaitForChild("ItemVisuals"))

local DARK   = Color3.fromRGB(18, 18, 22)
local GOLD   = UIStyle.Palette.Gold
local LIGHT  = Color3.fromRGB(235, 235, 240)
local DIM    = Color3.fromRGB(120, 120, 132)

-- The game's signature palette — bright, saturated, cartoon-poppy (think
-- Pet Simulator's HUD) — so the whole UI reads as one consistent brand
-- instead of a grab-bag of random accent colors. Each panel/button below
-- claims one of these five as its own identity; GOLD stays reserved for
-- currency, since that convention reads instantly to any player.
local BLUE   = UIStyle.Palette.Teal
local WHITE  = UIStyle.Palette.Cream
local PURPLE = UIStyle.Palette.Steel
local GREEN  = UIStyle.Palette.Mint
local RED    = UIStyle.Palette.Copper

-- Glass look: panels let the world through, text stays fully opaque.
-- Readability comes from the stroke and the text contrast, not from
-- a solid fill.
local GLASS_PANEL = 0.35   -- big modals
local GLASS_HUD   = 0.28   -- always-on HUD cards

local gui = Instance.new("ScreenGui")
gui.Name = "JunkyardUI"
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.ResetOnSpawn = false
gui.Parent = player:WaitForChild("PlayerGui")

local function rounded(instance, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius or 8)
	c.Parent = instance
	return instance
end

local function label(parent, text, size, color, font, textSize)
	local l = Instance.new("TextLabel")
	l.Size = size
	l.BackgroundTransparency = 1
	l.Text = ItemNames.Display(text)
	l.TextColor3 = color or LIGHT
	l.Font = font or Enum.Font.FredokaOne
	l.TextSize = textSize or 14
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Parent = parent
	return l
end

------------------------------------------------------------------
-- Coin counter (top left)
------------------------------------------------------------------

local coinCard = Instance.new("Frame")
coinCard.Size = UDim2.new(0, 300, 0, 76)
coinCard.Position = UDim2.new(0, 20, 1, -136)
coinCard:SetAttribute("Floating",true)
coinCard.BackgroundColor3 = DARK
coinCard.BackgroundTransparency = GLASS_HUD
coinCard.BorderSizePixel = 0
coinCard.Parent = gui
UIStyle.Navigation(coinCard)
rounded(coinCard)

UIStyle.Art(coinCard,"DoubleCoins",UDim2.fromOffset(0,-10),UDim2.fromOffset(84,84))

local coinText = label(coinCard, "0", UDim2.new(1, -72, 0, 40), GOLD, Enum.Font.LuckiestGuy, 28)
coinText.Position = UDim2.new(0, 88, 0, 8)
UIStyle.Outline(coinText,42)
coinText.TextYAlignment = Enum.TextYAlignment.Center
coinText.TextStrokeTransparency = 0.5

local luckText = label(coinCard, "LUCK 0%", UDim2.new(0, 90, 0, 18), DIM, Enum.Font.FredokaOne, 12)
luckText.Position = UDim2.new(0, 88, 0, 56)
UIStyle.Outline(luckText,14)
luckText.TextXAlignment = Enum.TextXAlignment.Right

local companionText = label(coinCard, "No companion equipped", UDim2.new(1, -32, 0, 18), PURPLE, Enum.Font.FredokaOne, 12)
companionText.Position = UDim2.new(0, 16, 0, 80)
UIStyle.Outline(companionText,14)

local function commas(n)
	local formatted = tostring(n)
	while true do
		local replaced
		formatted, replaced = formatted:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
		if replaced == 0 then break end
	end
	return formatted
end

-- Mirrors PlotManager's server-side instanceTag: mutation color takes over
-- from rarity color when a name carries a mutation prefix, since a carried
-- or inventoried item can be either now (Move-to-Carry can put a mutated
-- item back in carry, same as it can sit in inventory).
local function instanceTag(name)
	local baseName, mutationId = Mutations.Unwrap(name)
	if mutationId then
		return Mutations.Tag(name, mutationId)
	end
	return ItemRarity.Tag(baseName, FusionRecipes.GetTier(baseName), FusionRecipes.IsSecretResult(baseName),
		FusionRecipes.GetRarity(baseName))
end

local function watchCoins()
	local stats = player:WaitForChild("leaderstats", 20)
	if not stats then return end
	local coins = stats:WaitForChild("Coins", 20)
	if not coins then return end

	local function update()
		coinText.Text = commas(coins.Value)
	end

	update()
	coins.Changed:Connect(function()
		update()
		-- Quick pop so gains are felt, not just read.
		coinText.TextSize = 46
		TweenService:Create(coinText, TweenInfo.new(0.25), { TextSize = 42 }):Play()
	end)
end

task.spawn(watchCoins)

------------------------------------------------------------------
-- Active boost chips (under the coin card)
------------------------------------------------------------------

local boostBar = Instance.new("Frame")
boostBar.Size = UDim2.new(0, 300, 0, 34)
boostBar.Position = UDim2.new(0, 20, 0, 182)
boostBar.BackgroundTransparency = 1
boostBar.Parent = gui
UIStyle.Navigation(boostBar)

local boostLayout = Instance.new("UIListLayout")
boostLayout.FillDirection = Enum.FillDirection.Horizontal
boostLayout.Padding = UDim.new(0, 6)
boostLayout.Parent = boostBar

local BOOST_STYLE = {
	luck  = { text = "LUCK", color = Color3.fromRGB(120, 200, 255) },
	value = { text = "SELL", color = Color3.fromRGB(150, 240, 165) },
}

local activeBoosts = {}

local function formatTime(seconds)
	local m = math.floor(seconds / 60)
	local s = seconds % 60
	return string.format("%d:%02d", m, s)
end

local function redrawBoosts()
	for _, child in ipairs(boostBar:GetChildren()) do
		if not child:IsA("UIListLayout") then child:Destroy() end
	end

	for i, b in ipairs(activeBoosts) do
		local style = BOOST_STYLE[b.stat] or { text = string.upper(b.stat), color = GOLD }

		local chip = Instance.new("Frame")
		chip.Size = UDim2.new(0, 118, 0, 30)
		chip.LayoutOrder = i
		chip.BackgroundColor3 = Color3.fromRGB(22, 22, 28)
		chip.BackgroundTransparency = GLASS_HUD
		chip.BorderSizePixel = 0
		chip.Parent = boostBar
		rounded(chip, 15)

		local chipStroke = Instance.new("UIStroke")
		chipStroke.Color = style.color
		chipStroke.Thickness = 1.5
		chipStroke.Transparency = 0.25
		chipStroke.Parent = chip

		local text = label(chip, string.format("%dx %s  %s", b.mult, style.text, formatTime(b.remaining)),
			UDim2.new(1, 0, 1, 0), style.color, Enum.Font.FredokaOne, 12)
		text.TextXAlignment = Enum.TextXAlignment.Center
	end
end

-- Ticks locally so the timer moves every second instead of only when
-- the server happens to push an update.
task.spawn(function()
	while true do
		task.wait(1)
		if #activeBoosts > 0 then
			local changed = false
			for i = #activeBoosts, 1, -1 do
				activeBoosts[i].remaining -= 1
				if activeBoosts[i].remaining <= 0 then
					table.remove(activeBoosts, i)
				end
				changed = true
			end
			if changed then redrawBoosts() end
		end
	end
end)

------------------------------------------------------------------
-- Daily reward calendar
-- Opens by itself on join when something is claimable. Small button
-- on the HUD reopens it.
------------------------------------------------------------------

-- Left rail, slot 1 (top). Icon, hover/press animation, and position all
-- come from the shared nav-tile helper now — only the badge and status
-- line below the caption are unique to this button.
local dailyBtn, dailyIcon, dailyCaption, dailyBtnStroke, dailyBtnGradient = NavButton.Create(gui, "🎁", "REWARDS", GOLD, NavButton.RailPosition("left", 1))

local dailyStatus = label(dailyBtn, "", UDim2.new(1, -8, 0, 16), Color3.fromRGB(230, 230, 235), Enum.Font.FredokaOne, 10)
dailyStatus.Position = UDim2.new(0, 4, 0, 98)
dailyStatus.TextXAlignment = Enum.TextXAlignment.Center
dailyStatus.TextScaled = true
-- ZIndexBehavior on this ScreenGui is Global, so this needs to explicitly
-- clear dailyBtn's own ZIndex (2) the same way NavButton's icon/caption
-- labels do, or the button's own background paints over it.
dailyStatus.ZIndex = 3

-- Red dot, only when there's something to collect.
local dailyBadge = Instance.new("Frame")
dailyBadge.Size = UDim2.new(0, 24, 0, 24)
dailyBadge.Position = UDim2.new(1, -12, 0, -12)
dailyBadge.BackgroundColor3 = Color3.fromRGB(235, 70, 70)
dailyBadge.BorderSizePixel = 0
dailyBadge.Visible = false
dailyBadge.ZIndex = 3
dailyBadge.Parent = dailyBtn
rounded(dailyBadge, 12)

local badgeMark = label(dailyBadge, "!", UDim2.new(1, 0, 1, 0), Color3.fromRGB(255, 255, 255), Enum.Font.LuckiestGuy, 15)
badgeMark.TextXAlignment = Enum.TextXAlignment.Center
badgeMark.ZIndex = 4

-- Dimmed backdrop
local dimmer = Instance.new("TextButton")
dimmer.Name = "RewardsOverlay"
dimmer:SetAttribute("KeepOverlay",true)
dimmer.Size = UDim2.new(1, 0, 1, 0)
dimmer.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
dimmer.BackgroundTransparency = 0.35
dimmer.Text = ""
dimmer.AutoButtonColor = false
dimmer.BorderSizePixel = 0
dimmer.Visible = false
UIStyle.Modal(dimmer)
dimmer.ZIndex = 5
dimmer.Parent = gui

local dailyFrame = Instance.new("Frame")
dailyFrame.Size = UDim2.new(0, 600, 0, 470)
dailyFrame.Position = UDim2.new(0.5, -300, 0.5, -235)
dailyFrame.BackgroundColor3 = Color3.fromRGB(24, 24, 30)
dailyFrame.BackgroundTransparency = GLASS_PANEL
dailyFrame.BorderSizePixel = 0
dailyFrame.ZIndex = 6
dailyFrame.Parent = dimmer
rounded(dailyFrame, 16)
-- Garage.Canvas owns reward sizing.

local frameGradient = Instance.new("UIGradient")
frameGradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(38, 34, 30)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(18, 18, 24)),
})
frameGradient.Rotation = 90
frameGradient.Parent = dailyFrame

local frameStroke = Instance.new("UIStroke")
frameStroke.Color = GOLD
frameStroke.Thickness = 2
frameStroke.Transparency = 0.55
frameStroke.Parent = dailyFrame

-- Gold accent bar across the top
local accent = Instance.new("Frame")
accent.Size = UDim2.new(1, -40, 0, 4)
accent.Position = UDim2.new(0, 20, 0, 14)
accent.BackgroundColor3 = GOLD
accent.BorderSizePixel = 0
accent.ZIndex = 7
accent.Parent = dailyFrame
rounded(accent, 2)

local accentGradient = Instance.new("UIGradient")
accentGradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 205, 60)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 140, 90)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 205, 60)),
})
accentGradient.Parent = accent

local dailyTitle = label(dailyFrame, "🎁 REWARDS", UDim2.new(1, -200, 0, 38), Color3.fromRGB(255, 245, 225), Enum.Font.LuckiestGuy, 32)
dailyTitle.Position = UDim2.new(0, 24, 0, 24)
dailyTitle.ZIndex = 7

local titleGradient = Instance.new("UIGradient")
titleGradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 236, 150)),
	ColorSequenceKeypoint.new(0.5, Color3.fromRGB(255, 160, 90)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 110, 160)),
})
titleGradient.Parent = dailyTitle

local dailySub = label(dailyFrame, "Come back every day — miss one and the streak resets!", UDim2.new(1, -200, 0, 18), Color3.fromRGB(170, 170, 190), Enum.Font.FredokaOne, 13)
dailySub.Position = UDim2.new(0, 24, 0, 58)
dailySub.ZIndex = 7

-- Streak pill
local streakPill = Instance.new("Frame")
streakPill.Size = UDim2.new(0, 132, 0, 34)
streakPill.Position = UDim2.new(1, -190, 0, 30)
streakPill.BackgroundColor3 = Color3.fromRGB(58, 44, 30)
streakPill.BorderSizePixel = 0
streakPill.ZIndex = 7
streakPill.Parent = dailyFrame
rounded(streakPill, 17)

local streakStroke = Instance.new("UIStroke")
streakStroke.Color = Color3.fromRGB(255, 150, 70)
streakStroke.Thickness = 1.5
streakStroke.Transparency = 0.3
streakStroke.Parent = streakPill

local streakLabel = label(streakPill, "🔥 0 DAY STREAK", UDim2.new(1, 0, 1, 0), Color3.fromRGB(255, 195, 120), Enum.Font.FredokaOne, 13)
streakLabel.TextXAlignment = Enum.TextXAlignment.Center
streakLabel.ZIndex = 8

local dailyClose = Instance.new("TextButton")
dailyClose.Size = UDim2.new(0, 50, 0, 50)
dailyClose.Position = UDim2.new(1, -54, 0, 20)
dailyClose.BackgroundTransparency = 1
dailyClose.Text = "X"
dailyClose.TextColor3 = DIM
dailyClose.Font = Enum.Font.FredokaOne
dailyClose.TextSize = 18
dailyClose.ZIndex = 8
dailyClose.Parent = dailyFrame

local grid = Instance.new("Frame")
grid.Size = UDim2.new(1, -48, 0, 280)
grid.Position = UDim2.new(0, 24, 0, 92)
grid.BackgroundTransparency = 1
grid.ZIndex = 6
grid.Parent = dailyFrame

local gridLayout = Instance.new("UIGridLayout")
gridLayout.CellSize = UDim2.new(0, 128, 0, 130)
gridLayout.CellPadding = UDim2.new(0, 12, 0, 14)
gridLayout.FillDirectionMaxCells = 4
gridLayout.Parent = grid

local claimBtn = Instance.new("TextButton")
claimBtn.Size = UDim2.fromOffset(550,84)
claimBtn.Position = UDim2.new(0.5,-275,1,-115)
claimBtn.BackgroundColor3 = Color3.fromRGB(96, 214, 126)
claimBtn.Text = "CLAIM"
claimBtn.TextColor3 = Color3.fromRGB(12, 30, 16)
claimBtn.Font = Enum.Font.LuckiestGuy
claimBtn.TextSize = 20
claimBtn.BorderSizePixel = 0
claimBtn.ZIndex = 7
claimBtn.Parent = dailyFrame
rounded(claimBtn, 12)

local claimGradient = Instance.new("UIGradient")
claimGradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(150, 240, 165)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(72, 190, 108)),
})
claimGradient.Rotation = 90
claimGradient.Parent = claimBtn

claimBtn.MouseEnter:Connect(function()
	TweenService:Create(claimBtn, TweenInfo.new(0.15), {
		Size = UDim2.fromOffset(566,90),
		Position = UDim2.new(0.5,-283,1,-118),
	}):Play()
end)

claimBtn.MouseLeave:Connect(function()
	TweenService:Create(claimBtn, TweenInfo.new(0.15), {
		Size = UDim2.new(0, 280, 0, 52),
		Position = UDim2.new(0.5, -140, 1, -70),
	}):Play()
end)

claimBtn.MouseButton1Click:Connect(function()
	claimRemote:FireServer()
end)

local function closeDaily()
	dimmer.Visible = false
end

local function openDaily()
 dimmer.Visible = true
end

dailyClose.MouseButton1Click:Connect(closeDaily)
dimmer.MouseButton1Click:Connect(closeDaily)
dailyBtn.MouseButton1Click:Connect(openDaily)
do
	local openRewards = Instance.new("BindableEvent")
	openRewards.Name = "OpenDailyRewards"
	openRewards.Parent = player.PlayerGui
	openRewards.Event:Connect(openDaily)
end

local autoOpened = false
local pulseCard = nil

-- One loop drives every pulse in the UI, rather than a task per element.
task.spawn(function()
	local up = true
	while true do
		task.wait(0.75)
		up = not up

		if dailyBadge.Visible then
			TweenService:Create(dailyBtnStroke, TweenInfo.new(0.7), {
				Transparency = up and 0 or 0.6,
			}):Play()
		end

		if pulseCard and pulseCard.Parent then
			local stroke = pulseCard:FindFirstChildOfClass("UIStroke")
			if stroke then
				TweenService:Create(stroke, TweenInfo.new(0.7), {
					Thickness = up and 4 or 2,
					Transparency = up and 0 or 0.35,
				}):Play()
			end
		end
	end
end)

local function redrawDaily(rewards, claimed, nextDay, available)

 for _,child in grid:GetChildren() do child:Destroy() end
 pulseCard=nil
 streakLabel.Text=string.format("🔥 %d DAY STREAK",claimed or 0)
 for day,reward in ipairs(rewards or {}) do
  local isClaimed=day<=(claimed or 0)
  local isNext=available and day==nextDay
  local accent=isNext and Color3.fromRGB(255,202,39) or isClaimed and Color3.fromRGB(39,225,158) or day==7 and Color3.fromRGB(181,66,243) or Color3.fromRGB(64,169,239)
  local bottom=day>4 local w=bottom and 360 or 267 local x=bottom and (day-5)*382 or (day-1)*285
  local card=Garage.New("Frame",grid,"Day"..day,{Position=UDim2.fromOffset(x,bottom and 280 or 0),Size=UDim2.fromOffset(w,260),BackgroundTransparency=.3,BackgroundColor3=accent,ZIndex=7})
  Garage.Inset(card)
  local dayLabel=Garage.Text(card,"Day","DAY "..day,UDim2.new(.15,0,0,8),UDim2.new(.7,0,0,34),24)
  Garage.Plate(dayLabel,isNext and GOLD or isClaimed and Color3.fromRGB(152,255,210) or Color3.fromRGB(191,226,255))
  Garage.Pedestal(card,accent,UDim2.new(.08,0,0,146),UDim2.new(.84,0,0,64))
  Garage.Art(card,reward.kind=="boost" and "boost" or reward.kind=="item" and "crate" or reward.kind=="jackpot" and "PETS" or "coins",UDim2.new(.19,0,0,40),UDim2.new(.62,0,0,128))
  local name=Garage.Text(card,"Reward",reward.label,UDim2.new(.05,0,0,182),UDim2.new(.9,0,0,31),20) Garage.Plate(name)
  local status=Garage.Text(card,"Status",isNext and "READY!" or isClaimed and "✓ CLAIMED" or "LOCKED",UDim2.new(.05,0,0,219),UDim2.new(.9,0,0,33),20)
  Garage.Plate(status,isNext and GOLD or isClaimed and Color3.fromRGB(104,251,181) or Color3.fromRGB(148,194,235))
 end

	if available then
		claimBtn.Visible = true
		claimBtn.Text = string.format("CLAIM DAY %d   •   %s", nextDay, rewards[nextDay].label)

		-- Tab lights up
		dailyBadge.Visible = true
		dailyBtnStroke.Color = Color3.fromRGB(150, 240, 175)
		dailyBtnGradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(78, 170, 104)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(44, 112, 66)),
		})
		dailyIcon.TextColor3 = Color3.fromRGB(235, 255, 240)
		dailyCaption.TextColor3 = Color3.fromRGB(235, 255, 240)
		dailyStatus.Text = rewards[nextDay].label
		dailyStatus.TextColor3 = Color3.fromRGB(200, 245, 210)

		if not autoOpened then
			autoOpened = true
			task.delay(1.5, openDaily)
		end
	else
		-- Still there, just quiet. The calendar stays openable so players
		-- can see what's coming on day 7.
		claimBtn.Visible = true
		claimBtn.Text = "COME BACK TOMORROW"

		dailyBadge.Visible = false
		dailyBtnStroke.Color = Color3.fromRGB(90, 90, 108)
		dailyBtnStroke.Transparency = 0.4
		dailyBtnGradient.Color = ColorSequence.new({
			ColorSequenceKeypoint.new(0, Color3.fromRGB(56, 56, 68)),
			ColorSequenceKeypoint.new(1, Color3.fromRGB(30, 30, 38)),
		})
		dailyIcon.TextColor3 = Color3.fromRGB(150, 150, 170)
		dailyCaption.TextColor3 = Color3.fromRGB(150, 150, 170)
		dailyStatus.Text = "claimed"
		dailyStatus.TextColor3 = Color3.fromRGB(110, 110, 130)
	end
end

------------------------------------------------------------------
-- Item index (press B) — every item in the game, colored by rarity,
-- showing what you have and haven't found yet.
------------------------------------------------------------------

-- opts lets a caller frame the preview for its own tile instead of taking
-- the default (which reserves 46px at the bottom for a name label). `zoom`
-- is the important one: a small grid tile needs tighter framing or the item
-- renders as an unreadable speck in the middle of empty space.
local function buildItemViewport(parent, itemName, tintColor, opts)
	opts = opts or {}
	local viewport = Instance.new("ViewportFrame")
	viewport.Size = opts.size or UDim2.new(1, -16, 1, -46)
	viewport.Position = opts.position or UDim2.new(0, 8, 0, 8)
	viewport.BorderSizePixel = 0
	viewport.BackgroundColor3 = Color3.new(1,1,1)
	viewport.BackgroundTransparency = 1
	viewport.Ambient = Color3.fromRGB(205,205,214)
	viewport.LightColor = Color3.new(1,1,1)
	viewport.ZIndex = opts.zIndex or 1
	viewport.Parent = parent

	local cam = Instance.new("Camera")
	cam.FieldOfView = 35
	viewport.CurrentCamera = cam
	cam.Parent = viewport

	local clone, size = ItemVisuals.CloneForViewport(itemName, tintColor)
	if clone then Garage.Podium(clone, tintColor or ItemRarity.Color(FusionRecipes.GetTier(itemName), false, FusionRecipes.GetRarity(itemName))) end
	if clone then
		clone.Parent = viewport
		local reach = math.max(size.X, size.Y, size.Z) * math.max(opts.zoom or 1.5,1.65) + 0.2
		cam.CFrame = CFrame.new(Vector3.new(reach * 0.6, reach * 0.5, reach * 0.85), Vector3.new(0, -size.Y*.12, 0))
	end
	return viewport
end


local bookBtn = NavButton.Create(gui, "📖", "INDEX", PURPLE, NavButton.RailPosition("left", 3))
local indexData = { junkyard = {}, brainrot = {}, addons = {} }
local equippedCompanion = nil
local indexGallery = require(ReplicatedStorage:WaitForChild("IndexGallery")).Create(gui, function(name, area)
	equipCompanionRemote:FireServer(name, area)
end)
local function redrawIndex()
	indexGallery.Update(indexData, equippedCompanion)
end
bookBtn.MouseButton1Click:Connect(indexGallery.Toggle)
UserInputService.InputBegan:Connect(function(input, processed)
	if not processed and input.KeyCode == Enum.KeyCode.B then indexGallery.Toggle() end
end)

------------------------------------------------------------------
-- Upgrade shop (press U)
------------------------------------------------------------------

local shopBtn = NavButton.Create(gui, "🔧", "UPGRADES", GREEN, NavButton.RailPosition("right", 2))

local shopFrame = Instance.new("Frame")
shopFrame.Name = "UpgradesPanel"
shopFrame.Size = UDim2.new(0, 1100, 0, 760)
shopFrame.Position = UDim2.new(0.5, -260, 0.5, -255)
shopFrame.BackgroundColor3 = DARK
shopFrame.BackgroundTransparency = GLASS_PANEL
shopFrame.BorderSizePixel = 0
shopFrame.Visible = false
shopFrame.Parent = gui
rounded(shopFrame, 18)
UIStyle.Modal(shopFrame)
UIStyle.Surface(shopFrame,UIStyle.Palette.Cream,5)

local shopTitle = label(shopFrame, "UPGRADES", UDim2.new(1, -30, 0, 30), Color3.fromRGB(90, 200, 255), Enum.Font.LuckiestGuy, 30)
shopTitle.Position = UDim2.fromOffset(94,-64)
shopTitle.Size=UDim2.fromOffset(520,88)
shopTitle.Text="Upgrades!"
UIStyle.Outline(shopTitle,60)
UIStyle.Art(shopFrame,"UPGRADES",UDim2.fromOffset(-12,-76),UDim2.fromOffset(112,112))

local shopClose = Instance.new("TextButton")
shopClose.Size = UDim2.new(0, 64, 0, 50)
shopClose.Position = UDim2.new(1, -76, 0, 4)
shopClose.BackgroundTransparency = 1
shopClose.Text = "X"
shopClose.TextColor3 = DIM
shopClose.Font = Enum.Font.FredokaOne
shopClose.TextSize = 18
shopClose.Parent = shopFrame
UIStyle.Close(shopClose)

local rebirthRow = Instance.new("Frame")
rebirthRow.Size = UDim2.new(1, -40, 0, 90)
rebirthRow.Position = UDim2.new(0, 20, 0, 54)
rebirthRow.BackgroundColor3 = PURPLE
rebirthRow.BackgroundTransparency = 0.65
rebirthRow.BorderSizePixel = 0
rebirthRow.Parent = shopFrame
rounded(rebirthRow, 8)

local rebirthStroke = Instance.new("UIStroke")
rebirthStroke.Color = PURPLE
rebirthStroke.Thickness = 1.5
rebirthStroke.Parent = rebirthRow

local rebirthTitle = label(rebirthRow, "REBIRTH", UDim2.new(1, -150, 0, 24), PURPLE, Enum.Font.LuckiestGuy, 18)
rebirthTitle.Position = UDim2.new(0, 14, 0, 8)

local rebirthNow = label(rebirthRow, "", UDim2.new(1, -150, 0, 20), LIGHT, Enum.Font.FredokaOne, 13)
rebirthNow.Position = UDim2.new(0, 14, 0, 34)

local rebirthNext = label(rebirthRow, "", UDim2.new(1, -150, 0, 34), DIM, Enum.Font.FredokaOne, 12)
rebirthNext.Position = UDim2.new(0, 14, 0, 54)
rebirthNext.TextWrapped = true

local rebirthBtn = Instance.new("TextButton")
rebirthBtn.Size = UDim2.new(0, 128, 0, 50)
rebirthBtn.Position = UDim2.new(1, -142, 0.5, -25)
rebirthBtn.BorderSizePixel = 0
rebirthBtn.Font = Enum.Font.LuckiestGuy
rebirthBtn.TextSize = 15
rebirthBtn.TextWrapped = true
rebirthBtn.BackgroundColor3 = PURPLE
rebirthBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
rebirthBtn.Text = "REBIRTH"
rebirthBtn.Parent = rebirthRow
rounded(rebirthBtn, 6)

local shopScroll = Instance.new("ScrollingFrame")
shopScroll.Size = UDim2.new(1, -40, 1, -170)
shopScroll.Position = UDim2.new(0, 20, 0, 154)
shopScroll.BackgroundTransparency = 1
shopScroll.BorderSizePixel = 0
shopScroll.ScrollBarThickness = 5
shopScroll.Parent = shopFrame

-- 2026-09-14 redesign: a grid of square-ish cards instead of a list of
-- wide rows (the concept the user picked from 3 options). A UIGridLayout
-- with a fixed CellSize wraps to fewer columns on its own as the panel
-- narrows (2 columns wide, 1 in compact mode) — no separate compact-mode
-- relayout function needed the way the old row design required.
local shopLayout = Instance.new("UIGridLayout")
shopLayout.CellSize = UDim2.fromOffset(320, 232)
shopLayout.CellPadding = UDim2.fromOffset(16, 16)
shopLayout.SortOrder = Enum.SortOrder.LayoutOrder
shopLayout.Parent = shopScroll
UIStyle.ScrollPadding(shopScroll)

shopScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y

local function toggleShop()
	shopFrame.Visible = not shopFrame.Visible
end

shopBtn.MouseButton1Click:Connect(toggleShop)
shopClose.MouseButton1Click:Connect(toggleShop)

-- Bound here rather than with the recipe book's handler, because
-- shopFrame doesn't exist yet at that point in the file.
UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.U then
		toggleShop()
	end
end)

-- One accent color per upgrade so the shop reads as four distinct things
-- to work toward, not four identical gray rows with different words on them.
local UPGRADE_COLORS = {
	luck = GREEN,
	carry = BLUE,
	value = RED,
	speed = Color3.fromRGB(242,85,100),
}

-- Filled/empty pip row for the level, e.g. "●●●●○○○○○○" for Lv 4/10 —
-- reads the gap to max at a glance, faster than parsing "4 / 10".
local function levelDots(level, max)
	level = math.clamp(level, 0, max)
	return string.rep("●", level) .. string.rep("○", max - level)
end

local function redrawShop(shop)
 for _,c in shopScroll:GetChildren() do if c:IsA("GuiObject") then c:Destroy() end end
 for i,entry in ipairs(shop or {}) do
  local accent=UPGRADE_COLORS[entry.key] or Color3.fromRGB(26,168,247)
  local card=Garage.New("Frame",shopScroll,entry.key,{LayoutOrder=i,BackgroundColor3=Color3.fromRGB(58,172,222)})
  Garage.Inset(card)
  Garage.Pedestal(card,accent,UDim2.fromOffset(10,170),UDim2.fromOffset(210,65))
  Garage.Art(card,entry.key,UDim2.fromOffset(15,25),UDim2.fromOffset(205,176))
  local name=Garage.Text(card,"UpgradeName",entry.name,UDim2.fromOffset(228,12),UDim2.new(1,-240,0,43),26,Color3.new(1,1,1))
  Garage.Gloss(name,accent,12)
  name.TextTransparency=1 local caption=Garage.Text(name,"Caption",entry.name,UDim2.fromOffset(6,0),UDim2.new(1,-12,1,0),26,Color3.new(1,1,1)) caption.TextStrokeColor3=Color3.fromRGB(0,35,70) caption.TextStrokeTransparency=0
  local effect=Garage.Text(card,"UpgradeNow",entry.effect,UDim2.fromOffset(228,62),UDim2.new(1,-240,0,46),18,Color3.new(1,1,1))
  local progress=Garage.New("Frame",card,"Level",{Position=UDim2.fromOffset(232,112),Size=UDim2.new(1,-252,0,19),BackgroundColor3=Color3.fromRGB(0,68,122),BorderSizePixel=0})
  rounded(progress,9)
  for level=1,entry.max do
   local segment=Garage.New("Frame",progress,"Segment",{Size=UDim2.new(1/entry.max,-3,1,-4),Position=UDim2.new((level-1)/entry.max,2,0,2),BackgroundColor3=level<=entry.level and GOLD or Color3.fromRGB(5,93,145),BorderSizePixel=0}) rounded(segment,5)
  end
  local next=Garage.Text(card,"UpgradeNext",entry.nextEffect or "MAXIMUM LEVEL",UDim2.fromOffset(228,141),UDim2.new(1,-240,0,39),16)
  Garage.Plate(next)
  local buy=Garage.New("TextButton",card,"UpgradeBuy",{Size=UDim2.new(1,-240,0,48),Position=UDim2.fromOffset(228,187),Text=entry.cost and ("Upgrade • "..commas(entry.cost)) or "MAXED",Font=Enum.Font.FredokaOne,TextSize=24,BackgroundColor3=Color3.fromRGB(20,219,126)})
  Garage.Button(buy,entry.cost and Color3.fromRGB(20,219,126) or Color3.fromRGB(92,132,174))
  if entry.cost then buy.MouseButton1Click:Connect(function() buyRemote:FireServer(entry.key) end) end
 end
end

------------------------------------------------------------------
-- Rebirth row (top of the Upgrades panel)
------------------------------------------------------------------

local rebirthArmed = false
local rebirthMaxed = false

-- Needs a deliberate second click before it actually fires — this clears
-- placed items and upgrades for good, so a single misclick shouldn't cost
-- someone their garage.
local function setRebirthArmed(armed)
	rebirthArmed = armed
	if rebirthMaxed then return end
	if armed then
		rebirthBtn.Text = "CONFIRM?"
		rebirthBtn.BackgroundColor3 = Color3.fromRGB(255, 90, 90)
	else
		rebirthBtn.Text = "REBIRTH"
		rebirthBtn.BackgroundColor3 = PURPLE
	end
end

local function redrawRebirth(info)
	if not info then return end
	rebirthMaxed = info.maxed

	rebirthTitle.Text = info.maxed
		and string.format("REBIRTH — MAX (%d)", info.level)
		or string.format("REBIRTH — Level %d / %d", info.level, info.maxLevel)
	rebirthNow.Text = string.format("Current: x%.2f coins, x%.2f luck", info.multiplier, info.luckMultiplier)

	if info.maxed then
		rebirthNext.Text = "You've hit the ceiling — nothing left to cash in for."
		rebirthBtn.Text = "MAXED"
		rebirthBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 58)
		rebirthBtn.TextColor3 = DIM
		rebirthBtn.Active = false
	else
		rebirthNext.Text = string.format(
			"Next: x%.2f coins, x%.2f luck — %d coins (clears inventory/upgrades only)",
			info.nextMultiplier, info.nextLuckMultiplier, info.nextCost)
		rebirthBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
		rebirthBtn.Active = true
		setRebirthArmed(rebirthArmed)
	end
end

rebirthBtn.MouseButton1Click:Connect(function()
	if rebirthMaxed then return end
	if not rebirthArmed then
		setRebirthArmed(true)
		task.delay(4, function()
			if rebirthArmed then setRebirthArmed(false) end
		end)
	else
		setRebirthArmed(false)
		rebirthRemote:FireServer()
	end
end)

------------------------------------------------------------------
-- Inventory (top-center — the leaderboard used to live here, but that
-- moved to a physical monument in the yard). A fusion result lands here
-- now instead of a physical display; selling or sending something back
-- to carry to re-fuse it both happen from this popup.
--
-- Wrapped in `do...end`: this section alone builds ~25 top-level locals
-- (frames, labels, buttons, layouts) that nothing outside it ever needs.
-- Luau caps a script's main chunk at 200 live top-level locals, and this
-- file crossed that line the moment this section grew to Phase 3's size
-- — a real block lets the compiler free those registers at `end` instead
-- of holding all of them for the rest of the file. redrawInventory and
-- redrawPlaced are the only two things the dispatcher (far below) still
-- needs to call, so they're predeclared here and assigned without
-- `local` inside, the same trick used for any pair of local functions
-- that call each other.
------------------------------------------------------------------

local redrawInventory, redrawPlaced
do

local currentInventory = {}
local currentInventoryCapacity = 15
local currentPlaced = {}
local currentPlacedCapacity = 8

local inventoryBtn = NavButton.Create(gui, "📦", "INVENTORY", BLUE, NavButton.RailPosition("left", 2))

-- 2026-09-15 rebuild against a reference the user supplied (Pet Simulator X's
-- inventory): big panel, generous spacing, small-but-legible tiles, and real
-- contrast. The old version's cards were fully transparent (`Floating`), which
-- is exactly why it read washed out — every tile is a solid card now.
local INK = UIStyle.Palette.Ink
local CREAM = UIStyle.Palette.Cream
local PAPER = Color3.fromRGB(245, 239, 228)
local RULE_TINT = Color3.fromRGB(226, 216, 198)

-- A blurred ellipse, softness carried in the alpha channel. Deliberately
-- WHITE, not black: ImageColor3 multiplies, so a black sprite can never be
-- tinted (0 times anything is 0) and the selection glow below would have
-- silently stayed black. White lets one sprite serve as both the neutral
-- shadow and the coloured glow.
local SHADOW_SPRITE = "rbxassetid://115061718385182"
local SHADOW_TINT = Color3.fromRGB(68, 60, 48)

-- Everything below is coloured on purpose; Style.Attach repaints anything it
-- doesn't consider "Designed" back to the default theme.
local function mark(object)
	object:SetAttribute("Designed", true)
	return object
end

local function outline(object, color, thickness)
	local s = object:FindFirstChildOfClass("UIStroke") or Instance.new("UIStroke")
	s.Color = color or INK
	s.Thickness = thickness or 3
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = object
	return s
end

-- Same gap the Item Index had before its backdrop fix: UIStyle.Fit alone
-- doesn't dim the world behind the panel, so the margin around this
-- 88%-screen panel left the yard/pads fully visible and undimmed.
local inventoryBackdrop = mark(Instance.new("Frame"))
inventoryBackdrop.Name = "InventoryBackdrop"
inventoryBackdrop.Size = UDim2.fromScale(1, 1)
inventoryBackdrop.BackgroundColor3 = Color3.new(0, 0, 0)
inventoryBackdrop.BackgroundTransparency = 0.35
inventoryBackdrop.BorderSizePixel = 0
inventoryBackdrop.Visible = false
inventoryBackdrop.Parent = gui

local inventoryFrame = Instance.new("Frame")
inventoryFrame.Name = "InventoryPanel"
inventoryFrame.BackgroundColor3 = CREAM
inventoryFrame.BorderSizePixel = 0
inventoryFrame.Visible = false
inventoryFrame.Parent = gui
rounded(inventoryFrame, 24)
UIStyle.Modal(inventoryFrame)
Garage.Fit(inventoryFrame)
UIStyle.Surface(inventoryFrame, CREAM, 5)
UIStyle.Art(inventoryFrame, "INVENTORY", UDim2.fromOffset(14, 5), UDim2.fromOffset(78, 78))

local inventoryTitle = label(inventoryFrame, "Inventory!", UDim2.fromOffset(480, 88), BLUE, Enum.Font.LuckiestGuy, 60)
inventoryTitle.Position = UDim2.fromOffset(92, -64)
inventoryTitle.TextXAlignment = Enum.TextXAlignment.Left
UIStyle.Outline(inventoryTitle, 60)

local inventoryClose = Instance.new("TextButton")
inventoryClose.Parent = inventoryFrame
UIStyle.Close(inventoryClose)

local searchBox = Instance.new("TextBox")
searchBox.Name = "Search"
searchBox.Text = ""
searchBox.PlaceholderText = "Search items..."
searchBox.ClearTextOnFocus = false
searchBox.Font = Enum.Font.FredokaOne
searchBox.TextSize = 22
searchBox.TextColor3 = INK
searchBox.Position = UDim2.new(1, -352, 0, -28)
searchBox.Size = UDim2.fromOffset(266, 50)
searchBox.Parent = inventoryFrame
rounded(searchBox, 25)
UIStyle.Surface(searchBox, Color3.new(1, 1, 1), 4)

------------------------------------------------------------------
-- "Your pets — earning" band: a centred caption with a rule running out
-- to each side, then the five pad slots. Mirrors the reference's
-- "Your Best Pets 4/4" header.
------------------------------------------------------------------

local ruleLeft = mark(Instance.new("Frame"))
ruleLeft.BackgroundColor3 = RULE_TINT
ruleLeft.BorderSizePixel = 0
ruleLeft.Size = UDim2.new(0, 220, 0, 3)
ruleLeft.Position = UDim2.new(0, 34, 0, 40)
ruleLeft.Parent = inventoryFrame

local ruleRight = mark(Instance.new("Frame"))
ruleRight.BackgroundColor3 = RULE_TINT
ruleRight.BorderSizePixel = 0
ruleRight.Size = UDim2.new(0, 220, 0, 3)
ruleRight.Position = UDim2.new(1, -254, 0, 40)
ruleRight.Parent = inventoryFrame

local placedLabel = label(inventoryFrame, "EARNING PADS  0 / 8", UDim2.fromOffset(560, 32), INK, Enum.Font.FredokaOne, 22)
placedLabel.Position = UDim2.new(0.5, -280, 0, 26)
placedLabel.TextXAlignment = Enum.TextXAlignment.Center

local inventoryCount = label(inventoryFrame, "0 / 15", UDim2.fromOffset(150, 30), UIStyle.Palette.Teal, Enum.Font.FredokaOne, 20)
inventoryCount.Position = UDim2.new(1, -184, 0, 66)
inventoryCount.TextXAlignment = Enum.TextXAlignment.Right

local placedRow = mark(Instance.new("Frame"))
placedRow.Name = "PlacedSlots"
placedRow.BackgroundTransparency = 1
placedRow.Size = UDim2.new(1, -68, 0, 108)
placedRow.Position = UDim2.new(0, 34, 0, 62)
placedRow.Parent = inventoryFrame

local placedLayout = Instance.new("UIListLayout")
placedLayout.FillDirection = Enum.FillDirection.Horizontal
placedLayout.Padding = UDim.new(0, 14)
placedLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
placedLayout.VerticalAlignment = Enum.VerticalAlignment.Center
placedLayout.SortOrder = Enum.SortOrder.LayoutOrder
placedLayout.Parent = placedRow

local divider = mark(Instance.new("Frame"))
divider.BackgroundColor3 = RULE_TINT
divider.BorderSizePixel = 0
divider.Size = UDim2.new(1, -68, 0, 3)
divider.Position = UDim2.new(0, 34, 0, 180)
divider.Parent = inventoryFrame

------------------------------------------------------------------
-- Grid + details dock
------------------------------------------------------------------

-- An inset board behind the tiles, so the grid reads as a defined area
-- rather than items floating loose on the panel.
local gridBoard = mark(Instance.new("Frame"))
gridBoard.Name = "GridBoard"
gridBoard.BackgroundColor3 = PAPER
gridBoard.BorderSizePixel = 0
gridBoard.Position = UDim2.new(0, 28, 0, 198)
gridBoard.Size = UDim2.new(1, -350, 1, -224)
gridBoard.Parent = inventoryFrame
rounded(gridBoard, 18)
outline(gridBoard, RULE_TINT, 3)

local inventoryScroll = mark(Instance.new("ScrollingFrame"))
inventoryScroll.Name = "Items"
inventoryScroll.Size = UDim2.new(1, -20, 1, -20)
inventoryScroll.Position = UDim2.new(0, 10, 0, 10)
inventoryScroll.BackgroundTransparency = 1
inventoryScroll.BorderSizePixel = 0
inventoryScroll.ScrollBarThickness = 7
inventoryScroll.ScrollBarImageColor3 = UIStyle.Palette.Steel
inventoryScroll.Parent = gridBoard

-- Without this the top row gets clipped by the ScrollingFrame's own edge:
-- anything a tile draws outside its cell bounds (previously the stroke, now
-- the shadow) falls outside the scroll area and is cut off.
local inventoryPadding = Instance.new("UIPadding")
inventoryPadding.PaddingTop = UDim.new(0, 10)
inventoryPadding.PaddingLeft = UDim.new(0, 8)
inventoryPadding.PaddingRight = UDim.new(0, 8)
inventoryPadding.PaddingBottom = UDim.new(0, 10)
inventoryPadding.Parent = inventoryScroll

local inventoryLayout = Instance.new("UIGridLayout")
inventoryLayout.CellSize = UDim2.fromOffset(126, 142)
inventoryLayout.CellPadding = UDim2.fromOffset(12, 12)
inventoryLayout.SortOrder = Enum.SortOrder.LayoutOrder
inventoryLayout.Parent = inventoryScroll

local statPanel = mark(Instance.new("Frame"))
statPanel.Name = "ItemDetails"
statPanel.BackgroundColor3 = PAPER
statPanel.BorderSizePixel = 0
statPanel.Position = UDim2.new(1, -306, 0, 198)
statPanel.Size = UDim2.new(0, 278, 1, -224)
statPanel.Parent = inventoryFrame
rounded(statPanel, 18)
outline(statPanel, INK, 4)

local statViewportHolder = mark(Instance.new("Frame"))
statViewportHolder.BackgroundColor3 = Color3.new(1, 1, 1)
statViewportHolder.BorderSizePixel = 0
statViewportHolder.Size = UDim2.new(1, -28, 0, 150)
statViewportHolder.Position = UDim2.new(0, 14, 0, 14)
statViewportHolder.Parent = statPanel
rounded(statViewportHolder, 13)
outline(statViewportHolder, INK, 3)

local statName = label(statPanel, "Select an item", UDim2.new(1, -28, 0, 44), INK, Enum.Font.FredokaOne, 19)
statName.Position = UDim2.new(0, 14, 0, 174)
statName.TextWrapped = true
statName.TextScaled = true
statName.RichText = true
statName.TextXAlignment = Enum.TextXAlignment.Left
-- TextScaled alone grows to fill the whole 44px box, which made the short
-- "Select an item" placeholder render enormous next to everything else.
-- The constraint keeps long mutation-prefixed names shrinking to fit while
-- capping how large a short one is allowed to get.
local statNameCap = Instance.new("UITextSizeConstraint")
statNameCap.MaxTextSize = 21
statNameCap.MinTextSize = 11
statNameCap.Parent = statName

local statValue = label(statPanel, "", UDim2.new(1, -28, 0, 22), Color3.fromRGB(106, 99, 87), Enum.Font.FredokaOne, 15)
statValue.Position = UDim2.new(0, 14, 0, 222)
statValue.TextXAlignment = Enum.TextXAlignment.Left

local statPerSecond = label(statPanel, "", UDim2.new(1, -28, 0, 22), Color3.fromRGB(106, 99, 87), Enum.Font.FredokaOne, 15)
statPerSecond.Position = UDim2.new(0, 14, 0, 246)
statPerSecond.TextXAlignment = Enum.TextXAlignment.Left

local function actionButton(text, fill, textColor, offsetFromBottom, name)
	local btn = mark(Instance.new("TextButton"))
	-- Named so each button is individually addressable; three identically
	-- named siblings can only ever be reached as the first one.
	btn.Name = name
	btn.Size = UDim2.new(1, -28, 0, 44)
	btn.Position = UDim2.new(0, 14, 1, -offsetFromBottom)
	btn.BackgroundColor3 = fill
	btn.Text = text
	btn.TextColor3 = textColor
	btn.Font = Enum.Font.FredokaOne
	btn.TextSize = 17
	btn.AutoButtonColor = false
	btn.BorderSizePixel = 0
	btn.Visible = false
	btn.Parent = statPanel
	rounded(btn, 11)
	outline(btn, INK, 3)
	return btn
end

local placeBtn = actionButton("PLACE ON PAD", UIStyle.Palette.Mint, INK, 158, "PlaceButton")
local moveToCarryBtn = actionButton("CARRY TO FUSE", UIStyle.Palette.Steel, Color3.new(1, 1, 1), 106, "CarryToFuseButton")
local sellBtn = actionButton("SELL", UIStyle.Palette.Copper, Color3.new(1, 1, 1), 54, "SellButton")

local emptyHint = label(statPanel, "Tap an item to see what it's worth.", UDim2.new(1, -28, 0, 44), Color3.fromRGB(140, 132, 118), Enum.Font.FredokaOne, 15)
emptyHint.Position = UDim2.new(0, 14, 0, 222)
emptyHint.TextWrapped = true
emptyHint.TextXAlignment = Enum.TextXAlignment.Left

------------------------------------------------------------------
-- Responsive layout. UIStyle.Fit flips the "Compact" attribute below
-- 650px of viewport width, which is every phone in portrait.
------------------------------------------------------------------

local COLUMNS_WIDE, COLUMNS_COMPACT = 3, 2
local detailsOpen = false

local detailScroll=mark(Instance.new("ScrollingFrame"))
detailScroll.Name="DetailScroll" detailScroll.BackgroundTransparency=1 detailScroll.BorderSizePixel=0
detailScroll.Size=UDim2.fromScale(1,1) detailScroll.ScrollBarThickness=4 detailScroll.Parent=statPanel
local detailContent=mark(Instance.new("Frame"))
detailContent.Name="Content" detailContent.BackgroundTransparency=1 detailContent.Size=UDim2.new(1,-6,0,420) detailContent.Parent=detailScroll
for _,child in statPanel:GetChildren() do if child:IsA("GuiObject") and child~=detailScroll then child.Parent=detailContent end end
local function relayout()
 local compact = inventoryFrame:GetAttribute("Compact")
 inventoryFrame.Position=UDim2.fromScale(.5,.5)
 inventoryTitle.Position=UDim2.fromOffset(98,12)
 inventoryTitle.Size=UDim2.fromOffset(compact and 270 or 400,60)
 inventoryTitle.TextSize=compact and 34 or 48
 inventoryTitle.Text="INVENTORY"
 inventoryClose.Position=UDim2.new(1,-76,0,12)
 inventoryCount.Position=UDim2.fromOffset(compact and 24 or 512,compact and 90 or 26)
 inventoryCount.Size=UDim2.fromOffset(150,30)
 inventoryCount.TextColor3=Color3.fromRGB(255,224,80)
 searchBox.Position=compact and UDim2.new(0,184,0,84) or UDim2.new(1,-420,0,18)
 searchBox.Size=compact and UDim2.new(1,-208,0,44) or UDim2.fromOffset(320,46)
 local short=inventoryFrame.Size.Y.Offset<650
 local bandY=compact and 142 or 96
 placedLabel.Position=UDim2.fromOffset(24,bandY)
 placedLabel.Size=UDim2.new(1,-48,0,26) placedLabel.TextSize=19
 placedLabel.TextXAlignment=Enum.TextXAlignment.Left
 ruleLeft.Visible=false ruleRight.Visible=false divider.Visible=false
 local gap=compact and 6 or 12
 local slotSize=math.min(compact and 90 or (short and 70 or 122), math.max(24,math.floor((inventoryFrame.AbsoluteSize.X-48-gap*(currentPlacedCapacity-1))/currentPlacedCapacity)))
 placedRow.Position=UDim2.fromOffset(24,bandY+28)
 placedRow.Size=UDim2.new(1,-48,0,slotSize+4)
 placedLayout.Padding=UDim.new(0,gap)
 for _,slot in placedRow:GetChildren() do if slot:IsA("GuiObject") then slot.Size=UDim2.fromOffset(slotSize,slotSize) end end
 local gridTop=bandY+slotSize+44
 if compact then
  gridBoard.Position=UDim2.fromOffset(16,gridTop) gridBoard.Size=UDim2.new(1,-32,1,-gridTop-16)
  statPanel.Position=gridBoard.Position statPanel.Size=gridBoard.Size statPanel.Visible=detailsOpen
 else
  gridBoard.Position=UDim2.fromOffset(18,gridTop) gridBoard.Size=UDim2.new(.69,-26,1,-gridTop-18)
  statPanel.Position=UDim2.new(.69,2,0,gridTop) statPanel.Size=UDim2.new(.31,-20,1,-gridTop-18) statPanel.Visible=true
 end
 local columns=compact and 2 or 3
 local width=compact and 516 or 744
 local cell=math.floor((width-(columns-1)*16)/columns)
 inventoryLayout.CellPadding=UDim2.fromOffset(16,18)
 inventoryLayout.CellSize=UDim2.fromOffset(cell,cell*1.08)
 local h=math.max(420,inventoryFrame.Size.Y.Offset-gridTop-18)
 detailContent.Size=UDim2.new(1,-6,0,h)
 detailScroll.CanvasSize=UDim2.fromOffset(0,h)
 local previewHeight=math.clamp(h-258,110,240)
 statViewportHolder.Position=UDim2.fromOffset(10,12) statViewportHolder.Size=UDim2.new(1,-20,0,previewHeight)
 statViewportHolder.BackgroundTransparency=1
 statName.Position=UDim2.fromOffset(14,previewHeight+22) statName.Size=UDim2.new(1,-28,0,36)
 statValue.Position=UDim2.fromOffset(14,previewHeight+64)
 statValue.Size=UDim2.new(1,-28,0,30)
 statPerSecond.Position=UDim2.fromOffset(14,previewHeight+97)
 statPerSecond.Size=UDim2.new(1,-28,0,30)
 emptyHint.Position=UDim2.fromOffset(14,previewHeight+62)
 for _,btn in {placeBtn,moveToCarryBtn,sellBtn} do btn.Size=UDim2.new(1,-28,0,42) btn.TextSize=20 end
end

inventoryFrame:GetAttributeChangedSignal("Compact"):Connect(relayout)
inventoryFrame:GetPropertyChangedSignal("Size"):Connect(relayout)

------------------------------------------------------------------
-- Tiles
------------------------------------------------------------------

local selectedIndex = nil

local function showStatsFor(entry)
	selectedIndex = entry and entry.index
	detailsOpen = entry ~= nil
	inventoryFrame:SetAttribute("DetailsOpen", detailsOpen)

	for _, c in ipairs(statViewportHolder:GetChildren()) do
		if c:IsA("ViewportFrame") then c:Destroy() end
	end

	local compact = inventoryFrame:GetAttribute("Compact")
	statPanel.Visible = detailsOpen or not compact

	if not entry then
		statName.Text = "Select an item"
		statValue.Text = ""
		statPerSecond.Text = ""
		emptyHint.Visible = true
		statViewportHolder.Visible = false
		sellBtn.Visible = false
		moveToCarryBtn.Visible = false
		placeBtn.Visible = false
		return
	end
	statViewportHolder.Visible = true

	local baseName, mutationId = Mutations.Unwrap(entry.name)
	local tintColor = Mutations.Color(mutationId)
	buildItemViewport(statViewportHolder, baseName, tintColor, {
		size = UDim2.new(1, -12, 1, -12),
		position = UDim2.fromOffset(6, 6),
		zoom = 1.35,
	})

	statName.Text = ItemNames.Display(entry.name)
	statName.RichText=false
	statValue.Text = string.format("Value:  %d coins", math.floor(entry.value))
	statPerSecond.Text = string.format("If placed:  %.1f / sec", entry.perSecond)
	emptyHint.Visible = false
	sellBtn.Visible = true
	moveToCarryBtn.Visible = true
	placeBtn.Visible = true
	UIStyle.Surface(placeBtn,#currentPlaced >= currentPlacedCapacity and Color3.fromRGB(89,122,144) or Color3.fromRGB(20,218,157),3)
placeBtn.TextColor3=Color3.new(1,1,1)
	for _,g in placeBtn:GetChildren() do if g:IsA("UIGradient") then g:Destroy() end end
end

do
	local back = mark(Instance.new("TextButton"))
	back.Name = "CloseDetails"
	back.Text = "X"
	back.Font = Enum.Font.FredokaOne
	back.TextSize = 20
	back.TextColor3 = INK
	back.BackgroundTransparency = 1
	back.Size = UDim2.fromOffset(36, 36)
	back.Position = UDim2.new(1, -40, 0, 2)
	back.ZIndex = 6
	back.Parent = statPanel
	back.Activated:Connect(function() showStatsFor(nil) end)
end

function redrawInventory(items, capacity)
	-- Selling or moving an earlier-indexed item shifts everything after it
	-- down by one (table.remove semantics), so a plain index match after
	-- the swap can land on a completely different item that happened to
	-- inherit the old selection's slot. Comparing the name too catches that.
	local previousSelectedName = selectedIndex and currentInventory[selectedIndex] and currentInventory[selectedIndex].name

	currentInventory = items
	currentInventoryCapacity = capacity or currentInventoryCapacity
	inventoryCount.Text = string.format("%d / %d", #items, currentInventoryCapacity)

	for _, child in ipairs(inventoryScroll:GetChildren()) do
		if child:IsA("GuiObject") then child:Destroy() end
	end

	if #items == 0 then
		local empty = label(inventoryScroll, "Nothing here yet — fuse something at your pad.",
			UDim2.new(1, 0, 0, 60), Color3.fromRGB(150, 142, 128), Enum.Font.FredokaOne, 16)
		empty.TextWrapped = true
		empty.TextXAlignment = Enum.TextXAlignment.Center
	end

	local stillSelected = false
	for i, entry in ipairs(items) do
		if searchBox.Text ~= "" and not string.find(string.lower(ItemNames.Display(entry.name)), string.lower(searchBox.Text), 1, true) then continue end
		local baseName, mutationId = Mutations.Unwrap(entry.name)
		local tintColor = Mutations.Color(mutationId)
		local rarityKey = FusionRecipes.GetRarity(baseName)
		local rarityColor = tintColor or ItemRarity.Color(entry.tier, entry.isSecret, rarityKey)
		-- How hard the pool of light burns, on the six-tier rarity ladder.
		-- Rarity first and tier only as a fallback: every grabbable is tier 1,
		-- so scaling by tier alone gave the Jet Engine the faintest glow in
		-- the whole bag, which is exactly backwards.
		local rank = rarityKey and FusionRecipes.RarityIndex[rarityKey]
			or math.min(6, entry.tier + 1)
		if entry.isSecret then rank = 6 end
		local isSelected = entry.index == selectedIndex and entry.name == previousSelectedName

		-- Deliberately no card and no border: items read as floating on the
		-- panel, with a soft contact shadow doing the job the frame used to.
		-- With no border left to highlight, selection is shown by tinting
		-- that shadow teal and growing it.
		local card = mark(Instance.new("TextButton"))
		card.Name="InventoryItem"..entry.index
		card.Size = inventoryLayout.CellSize
		card.LayoutOrder = i
		card.BackgroundTransparency = 1
		card.Text = ""
		card.AutoButtonColor = false
		card.BorderSizePixel = 0
		card.Parent = inventoryScroll

		local shadow = mark(Instance.new("ImageLabel"))
		shadow.Name = "Shadow"
		shadow.BackgroundTransparency = 1
		shadow.Image = SHADOW_SPRITE
		-- Style A reads rarity as LIGHT, not as a border. The tiles stay
		-- borderless the way they were asked to be, so the pool of light the
		-- item is standing in carries its rarity instead: warm neutral for a
		-- common, a saturated glow for a legendary. Mixed back toward the
		-- neutral tint so it still reads as a shadow on the panel and not a
		-- sticker under the wheels.
		shadow.ImageColor3 = isSelected and UIStyle.Palette.Teal
			or rarityColor:Lerp(SHADOW_TINT, 0.45)
		local glow = math.clamp(0.38 - (rank - 1) * 0.052, 0.12, 0.38)
		shadow.ImageTransparency = 1
		shadow.ScaleType = Enum.ScaleType.Stretch
		shadow.AnchorPoint = Vector2.new(0.5, 0.5)
		-- Low and flat, reading as a contact shadow on the floor under a
		-- floating item. Centred behind the item instead, the model simply
		-- drew over the top of it and hid it.
		-- The label is deliberately oversized: the sprite carries a wide
		-- transparent margin, so only the middle ~60% of it is actually
		-- visible, and sizing to the intended shadow made it vanish.
		shadow.Position = UDim2.new(0.5, 0, 1, -28)
		shadow.Size = isSelected and UDim2.new(1.25, 0, 0, 42)
			or UDim2.new(0.95 + (rank - 1) * 0.05, 0, 0, 30 + (rank - 1) * 2.5)
		-- Above the viewport, not behind it. A ViewportFrame occludes
		-- lower-ZIndex siblings instead of compositing with them, so a shadow
		-- underneath was simply invisible wherever the item overlapped it.
		-- Drawing it on top is fine: it sits low and soft, so it reads as
		-- contact shading under the wheels rather than dirt on the model.
		shadow.ZIndex = 3
		shadow.Parent = card

		buildItemViewport(card, baseName, tintColor, {
			size = UDim2.new(1, -6, 1, -72),
			position = UDim2.fromOffset(3, 0),
			zoom = 1.28,
			zIndex = 2,
		})

		-- Name and value sit straight on the panel now, so both carry a dark
		-- text outline for legibility rather than a coloured strip behind them.
		local nameLbl = mark(label(card, ItemNames.Display(entry.name), UDim2.new(1, -6, 0, 20), rarityColor, Enum.Font.FredokaOne, 13))
		nameLbl.Position = UDim2.new(0, 8, 1, -62)
		nameLbl.Size=UDim2.new(1,-16,0,30)
		nameLbl.TextSize=18 nameLbl.TextColor3=INK nameLbl.TextStrokeTransparency=1
  local rarityChip=Garage.Text(card,"Rarity",rarityKey or (entry.isSecret and "SECRET" or "FUSED"),UDim2.new(.18,0,1,-28),UDim2.new(.64,0,0,25),16)
  Garage.Plate(rarityChip,rarityColor:Lerp(Color3.new(1,1,1),.35))
		nameLbl.BackgroundColor3=Color3.fromRGB(255,245,212) nameLbl.BackgroundTransparency=0 rounded(nameLbl,10)
		nameLbl.TextXAlignment = Enum.TextXAlignment.Center
		nameLbl.TextTruncate = Enum.TextTruncate.AtEnd
		nameLbl.TextStrokeColor3 = INK
		nameLbl.TextStrokeTransparency = 1
		nameLbl.ZIndex = 4

		local shown = entry.value >= 1000 and string.format("%.1fk", entry.value / 1000) or tostring(math.floor(entry.value))
		local valueLbl = mark(label(card, shown, UDim2.fromOffset(58, 18), UIStyle.Palette.Gold, Enum.Font.FredokaOne, 13))
		valueLbl.Position = UDim2.new(1, -60, 0, 2)
		valueLbl.TextXAlignment = Enum.TextXAlignment.Right
		valueLbl.TextStrokeColor3 = INK
		valueLbl.TextStrokeTransparency = 0.1
		valueLbl.ZIndex = 4

		card.MouseButton1Click:Connect(function()
			showStatsFor(entry)
			redrawInventory(currentInventory, currentInventoryCapacity)
		end)

		if isSelected then stillSelected = true end
	end

	inventoryScroll.CanvasSize = UDim2.new(0, 0, 0, inventoryLayout.AbsoluteContentSize.Y + 12)

	if not stillSelected then
		showStatsFor(nil)
	end
end

function redrawPlaced(items, capacity)
	currentPlaced = items
	currentPlacedCapacity = capacity or currentPlacedCapacity
	placedLabel.Text = string.format("EARNING PADS  %d / %d", #items, currentPlacedCapacity)

	if selectedIndex then
		placeBtn.BackgroundColor3 = #currentPlaced >= currentPlacedCapacity and DIM or UIStyle.Palette.Mint
	end

	for _, child in ipairs(placedRow:GetChildren()) do
		if child:IsA("GuiObject") then child:Destroy() end
	end

	local compact = inventoryFrame:GetAttribute("Compact")
	local gap = compact and 6 or 12
	placedLayout.Padding = UDim.new(0, gap)
	local slotSize = math.min(compact and 76 or 104, math.max(24, math.floor((inventoryFrame.AbsoluteSize.X-48-gap*(currentPlacedCapacity-1))/currentPlacedCapacity)))

	for slot = 1, currentPlacedCapacity do
		local entry = items[slot]

		local card = mark(Instance.new("TextButton"))
		card.Size = UDim2.fromOffset(slotSize, slotSize)
		card.LayoutOrder = slot
		card.Text = ""
		card.AutoButtonColor = false
		card.BorderSizePixel = 0
		card.Parent = placedRow

		if entry then
			local baseName, mutationId = Mutations.Unwrap(entry.name)
			local tintColor = Mutations.Color(mutationId)
			local rarityColor = tintColor or ItemRarity.Color(entry.tier, entry.isSecret,
				FusionRecipes.GetRarity(baseName))
			-- Same borderless treatment as the grid tiles, so a placed item
			-- and a stored one read as the same kind of object.
			card.BackgroundTransparency = 1

			local shadow = mark(Instance.new("ImageLabel"))
			shadow.Name = "Shadow"
			shadow.BackgroundTransparency = 1
			shadow.Image = SHADOW_SPRITE
			shadow.ImageColor3 = SHADOW_TINT
			shadow.ImageTransparency = 1
			shadow.ScaleType = Enum.ScaleType.Stretch
			shadow.AnchorPoint = Vector2.new(0.5, 0.5)
			shadow.Position = UDim2.new(0.5, 0, 1, -24)
			shadow.Size = UDim2.new(0.9, 0, 0, 26)
			shadow.ZIndex = 3
			shadow.Parent = card

			buildItemViewport(card, baseName, tintColor, {
				size = UDim2.new(1, -6, 1, -20),
				position = UDim2.fromOffset(3, 0),
				zoom = 1.28,
				zIndex = 2,
			})

			-- Rate reads as outlined text in the rarity colour, rather than a
			-- gold pill plus a separate rarity dot, now there is no card to
			-- hold either of them.
			local rateText = mark(label(card, string.format("%.0f/s", entry.perSecond or 0),
				UDim2.new(1, -6, 0, 18), rarityColor, Enum.Font.FredokaOne, 13))
			rateText.Position = UDim2.new(0, 3, 1, -19)
			rateText.TextXAlignment = Enum.TextXAlignment.Center
			rateText.TextStrokeColor3 = INK
			rateText.TextStrokeTransparency = 0.1
			rateText.ZIndex = 4

			card.MouseButton1Click:Connect(function()
				unplacePetRemote:FireServer(slot)
			end)
		else
			-- Empty slots keep a faint outline on purpose: with no border and
			-- nothing inside, an empty slot would be entirely invisible and
			-- the "3 / 5" count would stop being readable at a glance.
			card.BackgroundColor3 = PAPER
			card.BackgroundTransparency = 0.45
			rounded(card, 16)
			outline(card, Color3.fromRGB(214, 204, 186), 3)

			local plus = mark(label(card, "+", UDim2.fromScale(1, 1), Color3.fromRGB(196, 184, 164), Enum.Font.LuckiestGuy, math.floor(slotSize * 0.42)))
			plus.TextXAlignment = Enum.TextXAlignment.Center
		end
	end
end

sellBtn.MouseButton1Click:Connect(function()
	if selectedIndex then sellInventoryRemote:FireServer(selectedIndex) end
end)
moveToCarryBtn.MouseButton1Click:Connect(function()
	if selectedIndex then moveToCarryRemote:FireServer(selectedIndex) end
end)
placeBtn.MouseButton1Click:Connect(function()
	-- No client-side capacity guard here on purpose: let the server reject
	-- it and toast "All 5 pads are full" so a stale-looking button (pads
	-- filled by some other means since this panel last redrew) still gives
	-- the player feedback instead of silently doing nothing.
	if selectedIndex then placePetRemote:FireServer(selectedIndex) end
end)

local function toggleInventory()
	inventoryFrame.Visible = not inventoryFrame.Visible
	inventoryBackdrop.Visible = inventoryFrame.Visible
	if inventoryFrame.Visible then relayout() end
end

searchBox:GetPropertyChangedSignal("Text"):Connect(function() redrawInventory(currentInventory, currentInventoryCapacity) end)
inventoryBtn.MouseButton1Click:Connect(toggleInventory)
inventoryClose.MouseButton1Click:Connect(toggleInventory)

relayout()
showStatsFor(nil)

Garage.Shell(inventoryFrame)
Garage.Header(inventoryTitle)
Garage.Inset(gridBoard) Garage.Inset(statPanel) Garage.Inset(placedRow)
Garage.Plate(statValue) Garage.Plate(statPerSecond)
Garage.Plate(statName)
statName.BackgroundColor3=Color3.fromRGB(255,243,209)
statName.TextColor3=INK statName.TextStrokeTransparency=1
statViewportHolder:FindFirstChildOfClass("UIStroke").Transparency=1
UIStyle.Surface(moveToCarryBtn,Color3.fromRGB(0,165,250),3)
UIStyle.Surface(placeBtn,Color3.fromRGB(20,218,157),3)
UIStyle.Surface(sellBtn,Color3.fromRGB(255,91,35),3)
for _,btn in {placeBtn,moveToCarryBtn,sellBtn} do UIStyle.Surface(btn,btn.BackgroundColor3,3) UIStyle.Outline(btn,20) for _,g in btn:GetChildren() do if g:IsA("UIGradient") then g:Destroy() end end end
for _,b in {placeBtn,moveToCarryBtn,sellBtn} do Garage.Button(b) end
inventoryFrame.Illustration:Destroy()
Garage.Art(inventoryFrame,"INVENTORY",UDim2.fromOffset(14,8),UDim2.fromOffset(78,78))
relayout()
end -- do (Inventory section)

------------------------------------------------------------------
-- Event banner — reads EventConfig directly (no remote needed, both
-- sides load the same module); purely cosmetic, the real gate on the
-- exclusive Frenzy mutation lives server-side in Mutations.Roll.
--
-- Wrapped together with Trading right below into one `do...end`, same
-- register-budget reason as the Inventory section above: redrawTrade and
-- myTradeItems are the only two things the dispatcher still needs, so
-- they're predeclared here and assigned without `local` inside.
------------------------------------------------------------------

local redrawTrade, myTradeItems
do

local eventBanner = Instance.new("TextLabel")
eventBanner.Size = UDim2.new(0, 460, 0, 28)
eventBanner.Position = UDim2.new(0.5, -230, 0, 54)
eventBanner.BackgroundColor3 = Color3.fromRGB(255, 60, 60)
eventBanner.Text = ""
eventBanner.TextColor3 = Color3.fromRGB(255, 255, 255)
eventBanner.TextStrokeTransparency = 0.4
eventBanner.Font = Enum.Font.LuckiestGuy
eventBanner.TextSize = 15
eventBanner.BorderSizePixel = 0
eventBanner.Visible = false
eventBanner.Parent = gui
rounded(eventBanner)

local eventBannerGradient = Instance.new("UIGradient")
eventBannerGradient.Color = ColorSequence.new(Color3.fromRGB(255, 60, 60), Color3.fromRGB(255, 150, 60))
eventBannerGradient.Parent = eventBanner

local function formatEventDuration(seconds)
	if seconds < 60 then return string.format("%ds", seconds) end
	local h = math.floor(seconds / 3600)
	local m = math.floor((seconds % 3600) / 60)
	if h > 0 then return string.format("%dh %dm", h, m) end
	return string.format("%dm", m)
end

task.spawn(function()
	while true do
		if EventConfig.IsActive() then
			eventBanner.Visible = true
			if EventConfig.EXPIRES_AT then
				local remaining = math.max(0, EventConfig.EXPIRES_AT - os.time())
				eventBanner.Text = string.format("🎉 %s — ends in %s", EventConfig.NAME, formatEventDuration(remaining))
			else
				eventBanner.Text = string.format("🎉 %s — live now!", EventConfig.NAME)
			end
		else
			eventBanner.Visible = false
		end
		task.wait(5)
	end
end)

------------------------------------------------------------------
-- Trading — walk up to another player and press E on them to open this
-- for both sides at once. Nothing happens to either player's items until
-- both click CONFIRM, so opening it (even unintentionally) is harmless.
------------------------------------------------------------------

myTradeItems = {}

local tradeFrame = Instance.new("Frame")
tradeFrame.Size = UDim2.new(0, 480, 0, 360)
tradeFrame.Position = UDim2.new(0.5, -240, 0.5, -180)
tradeFrame.BackgroundColor3 = DARK
tradeFrame.BackgroundTransparency = GLASS_PANEL
tradeFrame.BorderSizePixel = 0
tradeFrame.Visible = false
tradeFrame.Parent = gui
rounded(tradeFrame, 10)
UIStyle.Modal(tradeFrame)

local tradeTitle = label(tradeFrame, "TRADING", UDim2.new(1, -30, 0, 30), WHITE, Enum.Font.LuckiestGuy, 20)
tradeTitle.Position = UDim2.new(0, 20, 0, 14)

local tradeStatus = label(tradeFrame, "", UDim2.new(1, -40, 0, 18), DIM, Enum.Font.FredokaOne, 13)
tradeStatus.Position = UDim2.new(0, 20, 0, 46)

local function buildOfferBox(titleText, xPos)
	local box = Instance.new("Frame")
	box.Size = UDim2.new(0, 208, 0, 170)
	box.Position = UDim2.new(0, xPos, 0, 74)
	box.BackgroundColor3 = Color3.fromRGB(28, 28, 34)
	box.BorderSizePixel = 0
	box.Parent = tradeFrame
	rounded(box, 8)

	local titleLbl = label(box, titleText, UDim2.new(1, -20, 0, 20), DIM, Enum.Font.FredokaOne, 13)
	titleLbl.Position = UDim2.new(0, 10, 0, 8)

	local itemLbl = label(box, "Nothing selected", UDim2.new(1, -20, 0, 90), LIGHT, Enum.Font.FredokaOne, 15)
	itemLbl.Position = UDim2.new(0, 10, 0, 32)
	itemLbl.TextWrapped = true
	itemLbl.RichText = true

	local statusLbl = label(box, "", UDim2.new(1, -20, 0, 20), Color3.fromRGB(120, 220, 140), Enum.Font.FredokaOne, 13)
	statusLbl.Position = UDim2.new(0, 10, 1, -26)

	return box, itemLbl, statusLbl
end

local myBox, myItemLbl, myStatusLbl = buildOfferBox("YOUR OFFER", 20)
local theirBox, theirItemLbl, theirStatusLbl = buildOfferBox("THEIR OFFER", 252)

local chooseItemBtn = Instance.new("TextButton")
chooseItemBtn.Size = UDim2.new(0, 208, 0, 34)
chooseItemBtn.Position = UDim2.new(0, 20, 0, 252)
chooseItemBtn.BackgroundColor3 = WHITE
chooseItemBtn.Text = "CHOOSE ITEM"
chooseItemBtn.TextColor3 = DARK
chooseItemBtn.Font = Enum.Font.FredokaOne
chooseItemBtn.TextSize = 13
chooseItemBtn.BorderSizePixel = 0
chooseItemBtn.Parent = tradeFrame
rounded(chooseItemBtn)

local confirmTradeBtn = Instance.new("TextButton")
confirmTradeBtn.Size = UDim2.new(0, 208, 0, 40)
confirmTradeBtn.Position = UDim2.new(0, 20, 0, 300)
confirmTradeBtn.BackgroundColor3 = Color3.fromRGB(120, 220, 140)
confirmTradeBtn.Text = "CONFIRM"
confirmTradeBtn.TextColor3 = DARK
confirmTradeBtn.Font = Enum.Font.LuckiestGuy
confirmTradeBtn.TextSize = 16
confirmTradeBtn.BorderSizePixel = 0
confirmTradeBtn.Parent = tradeFrame
rounded(confirmTradeBtn)

local cancelTradeBtn = Instance.new("TextButton")
cancelTradeBtn.Size = UDim2.new(0, 208, 0, 34)
cancelTradeBtn.Position = UDim2.new(0, 252, 0, 300)
cancelTradeBtn.BackgroundColor3 = Color3.fromRGB(60, 60, 68)
cancelTradeBtn.Text = "CANCEL TRADE"
cancelTradeBtn.TextColor3 = LIGHT
cancelTradeBtn.Font = Enum.Font.FredokaOne
cancelTradeBtn.TextSize = 13
cancelTradeBtn.BorderSizePixel = 0
cancelTradeBtn.Parent = tradeFrame
rounded(cancelTradeBtn)

-- Item picker: a secondary overlay listing everything SelectTradeOffer
-- will accept — everything currently in myTradeItems, sent fresh by the
-- server on every trade update, never guessed client-side.
local tradePickerFrame = Instance.new("Frame")
tradePickerFrame.Size = UDim2.new(0, 380, 0, 400)
tradePickerFrame.Position = UDim2.new(0.5, -190, 0.5, -200)
tradePickerFrame.BackgroundColor3 = DARK
tradePickerFrame.BackgroundTransparency = GLASS_PANEL
tradePickerFrame.BorderSizePixel = 0
tradePickerFrame.Visible = false
tradePickerFrame.ZIndex = 5
tradePickerFrame.Parent = gui
rounded(tradePickerFrame, 10)

local tradePickerTitle = label(tradePickerFrame, "CHOOSE AN ITEM", UDim2.new(1, -30, 0, 30), WHITE, Enum.Font.LuckiestGuy, 18)
tradePickerTitle.Position = UDim2.new(0, 20, 0, 14)
tradePickerTitle.ZIndex = 5

local tradePickerClose = Instance.new("TextButton")
tradePickerClose.Size = UDim2.new(0, 30, 0, 30)
tradePickerClose.Position = UDim2.new(1, -44, 0, 14)
tradePickerClose.BackgroundTransparency = 1
tradePickerClose.Text = "X"
tradePickerClose.TextColor3 = DIM
tradePickerClose.Font = Enum.Font.FredokaOne
tradePickerClose.TextSize = 18
tradePickerClose.ZIndex = 5
tradePickerClose.Parent = tradePickerFrame

local tradePickerScroll = Instance.new("ScrollingFrame")
tradePickerScroll.Size = UDim2.new(1, -40, 1, -70)
tradePickerScroll.Position = UDim2.new(0, 20, 0, 54)
tradePickerScroll.BackgroundTransparency = 1
tradePickerScroll.BorderSizePixel = 0
tradePickerScroll.ScrollBarThickness = 5
tradePickerScroll.ZIndex = 5
tradePickerScroll.Parent = tradePickerFrame

local tradePickerLayout = Instance.new("UIGridLayout")
tradePickerLayout.CellSize=UDim2.fromOffset(99,145)
tradePickerLayout.CellPadding=UDim2.fromOffset(8,10)
tradePickerLayout.Parent = tradePickerScroll

local function redrawTradePicker()
	for _, child in ipairs(tradePickerScroll:GetChildren()) do
		if not child:IsA("UIGridLayout") then child:Destroy() end
	end

	if #myTradeItems == 0 then
		local empty = Instance.new("TextLabel")
		empty.Size = UDim2.new(1, 0, 0, 40)
		empty.BackgroundTransparency = 1
		empty.Text = "You have nothing to offer right now."
		empty.TextColor3 = DIM
		empty.Font = Enum.Font.FredokaOne
		empty.TextSize = 14
		empty.ZIndex = 5
		empty.Parent = tradePickerScroll
	end

	for i, ref in ipairs(myTradeItems) do
		local row = Instance.new("TextButton")
		row.Size = UDim2.new(1, -6, 0, 40)
		row.LayoutOrder = i
		row.BackgroundColor3 = Color3.fromRGB(28, 28, 34)
		row.Text = ""
		row.AutoButtonColor = false
		row.BorderSizePixel = 0
		row.ZIndex = 5
		row.Parent = tradePickerScroll
		rounded(row, 6)

		local tag = ItemRarity.Tag(ref.itemName, FusionRecipes.GetTier(ref.itemName), FusionRecipes.IsSecretResult(ref.itemName))
		local rowLabel = label(row, tag, UDim2.new(1, -20, 1, 0), LIGHT, Enum.Font.FredokaOne, 14)
		rowLabel.Position = UDim2.new(0, 10, 0, 0)
		rowLabel.RichText = false
  rowLabel.Text=ItemNames.Display(ref.itemName)
  rowLabel.Position=UDim2.new(0,3,1,-35) rowLabel.Size=UDim2.new(1,-6,0,32) rowLabel.TextSize=13
  Garage.Plate(rowLabel)
  local base=Mutations.Unwrap(ref.itemName)
  buildItemViewport(row,base,nil,{size=UDim2.new(1,-4,0,106),position=UDim2.fromOffset(2,2),zoom=1.75})
  Garage.Inset(row)
		rowLabel.ZIndex = 5

		row.MouseButton1Click:Connect(function()
			selectTradeOfferRemote:FireServer(ref)
			tradePickerFrame.Visible = false
		end)
	end

	tradePickerScroll.CanvasSize = UDim2.new(0, 0, 0, tradePickerLayout.AbsoluteContentSize.Y + 10)
end

chooseItemBtn.MouseButton1Click:Connect(function()
	redrawTradePicker()
	tradePickerFrame.Visible = true
end)
tradePickerClose.MouseButton1Click:Connect(function()
	tradePickerFrame.Visible = false
end)

confirmTradeBtn.MouseButton1Click:Connect(function()
	confirmTradeRemote:FireServer()
end)
cancelTradeBtn.MouseButton1Click:Connect(function()
	cancelTradeRemote:FireServer()
	tradeFrame.Visible = false
	tradePickerFrame.Visible = false
end)

function redrawTrade(trade)
	if not trade then
		tradeFrame.Visible = false
		tradePickerFrame.Visible = false
		return
	end

	tradeFrame.Visible = true
	tradeTitle.Text = "TRADING WITH " .. string.upper(trade.partnerName)

	local function fillOffer(offer, itemLbl, statusLbl, confirmed, whoseConfirmedText)
  for _,c in itemLbl.Parent:GetChildren() do if c:IsA("ViewportFrame") then c:Destroy() end end
  if offer then local base,tint=Mutations.Unwrap(offer.itemName) buildItemViewport(itemLbl.Parent,base,Mutations.Color(tint),{size=UDim2.new(1,-18,0,320),position=UDim2.fromOffset(9,65),zoom=1.7}) end
		if offer then
			itemLbl.Text = ItemRarity.Tag(offer.itemName, FusionRecipes.GetTier(offer.itemName), FusionRecipes.IsSecretResult(offer.itemName))
		else
			itemLbl.Text = "Nothing selected"
		end
		statusLbl.Text = confirmed and whoseConfirmedText or ""
	end

	fillOffer(trade.myOffer, myItemLbl, myStatusLbl, trade.myConfirmed, "✓ You confirmed")
	fillOffer(trade.partnerOffer, theirItemLbl, theirStatusLbl, trade.partnerConfirmed, "✓ They confirmed")

	if trade.myConfirmed and trade.partnerConfirmed then
		tradeStatus.Text = "Finalizing trade..."
	elseif trade.myConfirmed then
		tradeStatus.Text = "Waiting for " .. trade.partnerName .. " to confirm..."
	elseif trade.partnerConfirmed then
		tradeStatus.Text = trade.partnerName .. " has confirmed — your move."
	else
		tradeStatus.Text = "Pick an item, then confirm when you're both ready."
	end

	redrawTradePicker() tradePickerFrame.Visible=true
 confirmTradeBtn.Text = trade.myConfirmed and "WAITING..." or "CONFIRM"
	confirmTradeBtn.BackgroundColor3 = trade.myConfirmed and Color3.fromRGB(60, 60, 68) or Color3.fromRGB(120, 220, 140)
end

------------------------------------------------------------------
-- Trading tab — click a name instead of walking up to someone. This
-- only replaces how a trade gets STARTED; once one's underway it's the
-- exact same tradeFrame/redrawTrade above either way.
------------------------------------------------------------------

local tradeBtn = NavButton.Create(gui, "🤝", "TRADE", GREEN, NavButton.RailPosition("right", 4))

local tradeListFrame = Instance.new("Frame")
tradeListFrame.Size = UDim2.new(0, 460, 0, 520)
tradeListFrame.Position = UDim2.new(0.5, -230, 0.5, -260)
tradeListFrame.BackgroundColor3 = DARK
tradeListFrame.BackgroundTransparency = GLASS_PANEL
tradeListFrame.BorderSizePixel = 0
tradeListFrame.Visible = false
tradeListFrame.Parent = gui
rounded(tradeListFrame, 14)
UIStyle.Modal(tradeListFrame)

local tradeListTitle = label(tradeListFrame, "🤝 TRADE WITH", UDim2.new(1, -70, 0, 34), GREEN, Enum.Font.LuckiestGuy, 22)
tradeListTitle.Position = UDim2.new(0, 22, 0, 18)

local tradeListClose = Instance.new("TextButton")
tradeListClose.Size = UDim2.new(0, 34, 0, 34)
tradeListClose.Position = UDim2.new(1, -50, 0, 16)
tradeListClose.BackgroundTransparency = 1
tradeListClose.Text = "X"
tradeListClose.TextColor3 = DIM
tradeListClose.Font = Enum.Font.FredokaOne
tradeListClose.TextSize = 20
tradeListClose.Parent = tradeListFrame

local tradeListScroll = Instance.new("ScrollingFrame")
tradeListScroll.Size = UDim2.new(1, -44, 1, -80)
tradeListScroll.Position = UDim2.new(0, 22, 0, 64)
tradeListScroll.BackgroundTransparency = 1
tradeListScroll.BorderSizePixel = 0
tradeListScroll.ScrollBarThickness = 6
tradeListScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
tradeListScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
tradeListScroll.Parent = tradeListFrame

local tradeListLayout = Instance.new("UIListLayout")
tradeListLayout.Padding = UDim.new(0, 10)
tradeListLayout.Parent = tradeListScroll

local function redrawTradeList()
	for _, child in ipairs(tradeListScroll:GetChildren()) do
		if not child:IsA("UIListLayout") then child:Destroy() end
	end

	local others = {}
	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= player then table.insert(others, other) end
	end

	if #others == 0 then
		local empty = Instance.new("TextLabel")
		empty.Size = UDim2.new(1, 0, 0, 60)
		empty.BackgroundTransparency = 1
		empty.Text = "No one else is here yet — invite a friend!"
		empty.TextColor3 = DIM
		empty.Font = Enum.Font.FredokaOne
		empty.TextSize = 14
		empty.TextWrapped = true
		empty.Parent = tradeListScroll
	end

	for i, other in ipairs(others) do
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, 0, 0, 64)
		row.LayoutOrder = i
		row.BackgroundColor3 = GREEN:Lerp(Color3.fromRGB(20, 20, 26), 0.8)
		row.BorderSizePixel = 0
		row.Parent = tradeListScroll
		rounded(row, 12)

		local rowStroke = Instance.new("UIStroke")
		rowStroke.Color = GREEN
		rowStroke.Transparency = 0.55
		rowStroke.Thickness = 1.5
		rowStroke.Parent = row

		local nameLbl = label(row, other.Name, UDim2.new(1, -140, 1, 0), LIGHT, Enum.Font.FredokaOne, 18)
		nameLbl.Position = UDim2.new(0, 72, 0, 0)
  nameLbl.Size=UDim2.new(1,-188,1,0)
  local avatar=Garage.New("ImageLabel",row,"Avatar",{Position=UDim2.fromOffset(6,6),Size=UDim2.fromOffset(58,58),BackgroundTransparency=1})
  task.spawn(function() local ok,url=pcall(function() return Players:GetUserThumbnailAsync(other.UserId,Enum.ThumbnailType.HeadShot,Enum.ThumbnailSize.Size150x150) end) if ok and avatar.Parent then avatar.Image=url end end)
  Garage.Inset(row)
		nameLbl.TextYAlignment = Enum.TextYAlignment.Center

		local tradeRowBtn = Instance.new("TextButton")
		tradeRowBtn.Size = UDim2.new(0, 110, 0, 44)
		tradeRowBtn.Position = UDim2.new(1, -122, 0.5, -22)
		tradeRowBtn.BackgroundColor3 = GREEN
		tradeRowBtn.TextColor3 = DARK
		tradeRowBtn.Font = Enum.Font.LuckiestGuy
		tradeRowBtn.TextSize = 14
		tradeRowBtn.Text = "TRADE"
		tradeRowBtn.BorderSizePixel = 0
		tradeRowBtn.Parent = row
		rounded(tradeRowBtn, 10)

		Garage.Button(tradeRowBtn,Color3.fromRGB(0,167,249))
  tradeRowBtn.MouseButton1Click:Connect(function()
			startTradeWithRemote:FireServer(other.UserId)
			tradeListFrame.Visible = false
		end)
	end
end

local function toggleTradeList()
	tradeListFrame.Visible = not tradeListFrame.Visible
	if tradeListFrame.Visible then redrawTradeList() end
end

tradeBtn.MouseButton1Click:Connect(toggleTradeList)
tradeListClose.MouseButton1Click:Connect(toggleTradeList)

-- Deferred so the join/leave has actually finished (Players:GetPlayers()
-- reflects it) before the list re-reads it, rather than possibly redrawing
-- one event tick early.
Players.PlayerAdded:Connect(function()
	if tradeListFrame.Visible then task.defer(redrawTradeList) end
end)
Players.PlayerRemoving:Connect(function()
	if tradeListFrame.Visible then task.defer(redrawTradeList) end
end)

for _,panel in {tradeFrame,tradeListFrame} do Garage.Shell(panel) end
Garage.Inset(tradePickerFrame)
for _,heading in {tradeTitle,tradeListTitle,tradePickerTitle} do Garage.Header(heading) end

Garage.Canvas(tradeFrame,1200,820) Garage.Canvas(tradeListFrame,1200,820)
tradeFrame.Name="TradingPanel" tradeListFrame.Name="TradePlayersPanel" tradePickerFrame.Name="ChooseTradeItem"
tradeTitle.Position=UDim2.fromOffset(94,15) tradeTitle.Size=UDim2.fromOffset(630,64) tradeTitle.TextSize=40
tradeListTitle.Position=UDim2.fromOffset(94,15) tradeListTitle.Size=UDim2.fromOffset(500,64) tradeListTitle.Text="TRADING" tradeListTitle.TextSize=46
Garage.Art(tradeFrame,"TRADE",UDim2.fromOffset(14,8),UDim2.fromOffset(78,78))
Garage.Art(tradeListFrame,"TRADE",UDim2.fromOffset(14,8),UDim2.fromOffset(78,78))
myBox.Position=UDim2.fromOffset(24,115) myBox.Size=UDim2.fromOffset(378,477) Garage.Inset(myBox)
theirBox.Position=UDim2.fromOffset(425,115) theirBox.Size=UDim2.fromOffset(378,477) Garage.Inset(theirBox)
for _,l in {myItemLbl,theirItemLbl} do l.Position=UDim2.fromOffset(12,389) l.Size=UDim2.new(1,-24,0,43) l.TextSize=24 Garage.Plate(l) end
for _,l in {myStatusLbl,theirStatusLbl} do l.Position=UDim2.new(0,12,1,-38) l.Size=UDim2.new(1,-24,0,30) l.TextSize=20 end
chooseItemBtn.Position=UDim2.fromOffset(40,607) chooseItemBtn.Size=UDim2.fromOffset(345,58) chooseItemBtn.TextSize=27 Garage.Button(chooseItemBtn,Color3.fromRGB(0,175,248))
tradeStatus.Position=UDim2.fromOffset(35,678) tradeStatus.Size=UDim2.fromOffset(750,38) tradeStatus.TextSize=22 Garage.Plate(tradeStatus,Color3.fromRGB(153,223,248))
confirmTradeBtn.Position=UDim2.fromOffset(40,736) confirmTradeBtn.Size=UDim2.fromOffset(350,58) confirmTradeBtn.TextSize=27 Garage.Button(confirmTradeBtn,Color3.fromRGB(20,224,128))
cancelTradeBtn.Position=UDim2.fromOffset(425,736) cancelTradeBtn.Size=UDim2.fromOffset(350,58) cancelTradeBtn.TextSize=27 Garage.Button(cancelTradeBtn,Color3.fromRGB(255,86,36))
tradePickerFrame.Parent=tradeFrame tradePickerFrame.Position=UDim2.fromOffset(824,116) tradePickerFrame.Size=UDim2.fromOffset(352,674)
tradePickerTitle.Size=UDim2.new(1,-28,0,50) tradePickerTitle.Position=UDim2.fromOffset(14,12) tradePickerTitle.TextSize=26
tradePickerClose.Visible=false
tradePickerScroll.Position=UDim2.fromOffset(13,78) tradePickerScroll.Size=UDim2.new(1,-26,1,-92)
tradeListScroll.Position=UDim2.fromOffset(824,125) tradeListScroll.Size=UDim2.fromOffset(350,658)
local playerPane=Garage.New("Frame",tradeListFrame,"PlayerPane",{Position=UDim2.fromOffset(814,105),Size=UDim2.fromOffset(370,684),ZIndex=0}) Garage.Inset(playerPane)
local greeting=Garage.Text(tradeListFrame,"Greeting","TRADE VEHICLES\nBUILD A BIGGER GARAGE!",UDim2.fromOffset(50,135),UDim2.fromOffset(700,95),38,Color3.new(1,1,1))
Garage.Art(tradeListFrame,"TRADE",UDim2.fromOffset(275,260),UDim2.fromOffset(255,235))
Garage.Text(tradeListFrame,"HowTo","Choose an online player to begin.\nBoth players must confirm before items change hands.",UDim2.fromOffset(80,565),UDim2.fromOffset(640,130),26,Color3.new(1,1,1))
end -- do (Event banner + Trading section)

------------------------------------------------------------------
-- Toasts
------------------------------------------------------------------

local function showToast(message, big)
	local toast = Instance.new("TextLabel")
	toast.Size = UDim2.new(0, 470, 0, big and 86 or 44)
	toast.Position = UDim2.new(0.5, -235, 0.5, big and -140 or -110)
	toast.BackgroundColor3 = big and GOLD or DARK
	toast.BackgroundTransparency = 0.08
	toast.Text = ItemNames.Display(message)
	toast.TextColor3 = big and DARK or LIGHT
	toast.Font = big and Enum.Font.LuckiestGuy or Enum.Font.FredokaOne
	toast.TextSize = big and 20 or 15
	toast.TextWrapped = true
	toast.BorderSizePixel = 0
	toast.RichText = true
	toast.Parent = gui
	rounded(toast)

	task.delay(big and 2.8 or 1.8, function()
		local fade = TweenService:Create(toast, TweenInfo.new(0.4), {
			BackgroundTransparency = 1,
			TextTransparency = 1,
		})
		fade:Play()
		fade.Completed:Wait()
		toast:Destroy()
	end)
end

-- Server-wide announcements (golden scrap, big finds). Deliberately
-- different from a personal toast: top of screen, wider, longer.
local announceActive = nil

local function showAnnounce(message)
	if announceActive then
		announceActive:Destroy()
	end

	local banner = Instance.new("TextLabel")
	banner.Size = UDim2.new(0, 640, 0, 46)
	banner.Position = UDim2.new(0.5, -320, 0, -60)
	banner.BackgroundColor3 = Color3.fromRGB(255, 205, 60)
	banner.BackgroundTransparency = 0.05
	banner.Text = ItemNames.Display(message)
	banner.TextColor3 = DARK
	banner.Font = Enum.Font.LuckiestGuy
	banner.TextSize = 17
	banner.TextWrapped = true
	banner.BorderSizePixel = 0
	banner.RichText = true
	banner.Parent = gui
	rounded(banner)

	announceActive = banner

	TweenService:Create(banner, TweenInfo.new(0.35, Enum.EasingStyle.Back), {
		Position = UDim2.new(0.5, -320, 0, 18),
	}):Play()

	task.delay(4.5, function()
		if banner.Parent then
			local out = TweenService:Create(banner, TweenInfo.new(0.4), {
				Position = UDim2.new(0.5, -320, 0, -60),
			})
			out:Play()
			out.Completed:Wait()
			banner:Destroy()
		end
	end)
end

------------------------------------------------------------------
-- Draw whatever the server sends
------------------------------------------------------------------

remote.OnClientEvent:Connect(function(data)
	if data.announce then
		showAnnounce(data.announce)
		return
	end

	if data.toast then
		showToast(data.toast, data.big)
		return
	end

	if data.boosts then
		activeBoosts = data.boosts
		redrawBoosts()
	end

	if data.dailyRewards then
		redrawDaily(data.dailyRewards, data.dailyClaimed, data.dailyNext, data.dailyAvailable)
	end

	if data.shop then
		redrawShop(data.shop)
	end

	if data.rebirth then
		redrawRebirth(data.rebirth)
	end

	if data.companion ~= nil then
		equippedCompanion = data.companion or nil
		companionText.Text = ItemNames.Display(equippedCompanion)
			and string.format("Companion: %s (+%d%%)", equippedCompanion.name, equippedCompanion.bonusPercent)
			or "No companion equipped"
		redrawIndex()
	end

	if data.inventory then
		redrawInventory(data.inventory, data.inventoryCapacity)
	end

	if data.placed then
		redrawPlaced(data.placed, data.placedCapacity)
	end

	if data.trade ~= nil then
		if data.myTradeItems then myTradeItems = data.myTradeItems end
		redrawTrade(data.trade or nil)
	end

	if data.luckPercent then
		-- Shows your real total odds (upgrade + rebirth + any active boost),
		-- not the raw upgrade level — the user's ask 2026-09-14: "a luck
		-- tracker... showing your luck percentage in the game."
		luckText.Text = "LUCK " .. tostring(data.luckPercent) .. "%"
	end

	if data.index then
		-- One list off the server, split here: addons get their own Index
		-- tab, so they should not also sit in the Junkyard list.
		local junk, addons = {}, {}
		for _, entry in ipairs(data.index) do
			table.insert(entry.isAddon and addons or junk, entry)
		end
		-- Worst engine to best, so the tab reads as the ladder it is.
		-- GetIndex sorts by name within a tier, and every addon is tier 1,
		-- which would file the Jet Engine second between Inline 4 and V6.
		table.sort(addons, function(x, y)
			return (FusionRecipes.RarityIndex[x.rarity] or 0)
				< (FusionRecipes.RarityIndex[y.rarity] or 0)
		end)
		indexData.junkyard = junk
		indexData.addons = addons
		redrawIndex()
	end

	if data.brainrotIndex then
		indexData.brainrot = data.brainrotIndex
		redrawIndex()
	end
end)

------------------------------------------------------------------
-- Travel menu — a single button opens a big picker listing each
-- destination as a bold color-gradient card with a giant emoji.
------------------------------------------------------------------

local travelRemote = ReplicatedStorage:WaitForChild("TravelTo")

local WORLDS = {
	{
		key = "junkyard", name = "JUNKYARD", emoji = "🚗",
		blurb = "Your plot, the fusion pad, and the shared scrap yard.",
		gradientColors = { Color3.fromRGB(255, 214, 80), Color3.fromRGB(255, 130, 40) },
	},
	{
		key = "brainrot", name = "BRAINROT ISLAND", emoji = "🧠",
		blurb = "A separate island with its own creatures to fuse.",
		gradientColors = { Color3.fromRGB(255, 110, 210), Color3.fromRGB(170, 80, 255) },
	},
	{
		key = "haunted", name = "HAUNTED HOLLOW", emoji = "👻",
		blurb = "A cursed graveyard with its own ghosts to fuse.",
		gradientColors = { Color3.fromRGB(120, 80, 190), Color3.fromRGB(45, 45, 60) },
	},
}

-- Right rail, slot 1 (top).
local travelBtn = NavButton.Create(gui, "🚀", "TRAVEL", RED, NavButton.RailPosition("right", 1))

-- Big picker modal — nearly fullscreen, scale-sized so it stays "almost
-- the whole screen" on any resolution instead of a fixed pixel box.
local travelFrame = Instance.new("Frame")
travelFrame.Size = UDim2.new(0.88, 0, 0.88, 0)
travelFrame.Position = UDim2.new(0.06, 0, 0.06, 0)
travelFrame.BackgroundColor3 = DARK
travelFrame.BackgroundTransparency = GLASS_PANEL
travelFrame.BorderSizePixel = 0
travelFrame.Visible = false
travelFrame.Parent = gui
rounded(travelFrame, 18)
UIStyle.Modal(travelFrame)

local travelTitle = label(travelFrame, "WHERE TO?", UDim2.new(1, -40, 0, 50), GOLD, Enum.Font.LuckiestGuy, 40)
travelTitle.Position = UDim2.new(0, 32, 0, 22)

local travelSub = label(travelFrame, "Pick a destination.", UDim2.new(1, -50, 0, 24), DIM, Enum.Font.FredokaOne, 16)
travelSub.Position = UDim2.new(0, 32, 0, 74)

local travelClose = Instance.new("TextButton")
travelClose.Size = UDim2.new(0, 42, 0, 42)
travelClose.Position = UDim2.new(1, -60, 0, 20)
travelClose.BackgroundTransparency = 1
travelClose.Text = "X"
travelClose.TextColor3 = DIM
travelClose.Font = Enum.Font.FredokaOne
travelClose.TextSize = 26
travelClose.Parent = travelFrame

local travelScroll = Instance.new("ScrollingFrame")
travelScroll.Size = UDim2.new(1, -64, 1, -128)
travelScroll.Position = UDim2.new(0, 32, 0, 110)
travelScroll.BackgroundTransparency = 1
travelScroll.BorderSizePixel = 0
travelScroll.ScrollBarThickness = 8
travelScroll.Parent = travelFrame

local travelLayout = Instance.new("UIListLayout")
travelLayout.Padding = UDim.new(0, 22)
travelLayout.SortOrder = Enum.SortOrder.LayoutOrder
travelLayout.Parent = travelScroll

travelLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
	travelScroll.CanvasSize = UDim2.new(0, 0, 0, travelLayout.AbsoluteContentSize.Y + 10)
end)

local function toggleTravel()
	travelFrame.Visible = not travelFrame.Visible
end

travelBtn.MouseButton1Click:Connect(toggleTravel)
travelClose.MouseButton1Click:Connect(toggleTravel)

-- Bold color-gradient cards with a giant emoji badge — reliably bright
-- and fun on every screen, unlike a hand-lit 3D scene, which fought us
-- on camera angles for three rounds before we gave up on it here.
local function buildWorldRow(world)
 local index=world.key=="brainrot" and 1 or world.key=="haunted" and 2 or 0
 local color=({Color3.fromRGB(255,159,27),Color3.fromRGB(235,49,220),Color3.fromRGB(128,65,225)})[index+1]
 local row=Garage.New("TextButton",travelScroll,"Destination_"..world.key,{Size=UDim2.new(1,-12,0,210),Text="",LayoutOrder=index,BackgroundColor3=color,AutoButtonColor=false})
 Garage.Gloss(row,color,20)
 Garage.Scene(row,index,UDim2.fromOffset(8,8),UDim2.new(.44,-12,1,-16))
 local name=Garage.Text(row,"DestinationName",world.name,UDim2.new(.46,0,0,13),UDim2.new(.52,-12,0,54),38,Color3.new(1,1,1))
 name.TextStrokeColor3=Color3.fromRGB(10,24,56) name.TextStrokeTransparency=0
 local desc=Garage.Text(row,"Description",world.blurb,UDim2.new(.46,0,0,79),UDim2.new(.29,-8,0,111),20)
 Garage.Plate(desc)
 local go=Garage.New("TextButton",row,"Travel",{Position=UDim2.new(.77,0,0,91),Size=UDim2.new(.21,-12,0,87),Text="TRAVEL →",TextSize=30,BackgroundColor3=Color3.fromRGB(12,223,142),Font=Enum.Font.FredokaOne})
 Garage.Button(go)
 local function travel() travelRemote:FireServer(world.key) toggleTravel() end
 go.Activated:Connect(travel) row.Activated:Connect(travel)
end

for _, world in ipairs(WORLDS) do
	buildWorldRow(world)
end

-- Apply presentation after construction; future inventory/reward rows inherit it.
UIStyle.Attach(gui)
Garage.Shell(shopFrame) Garage.Header(shopTitle)
Garage.Shell(dailyFrame) Garage.Header(dailyTitle)
Garage.Shell(travelFrame) Garage.Header(travelTitle)

shopTitle.Position=UDim2.fromOffset(98,12) shopTitle.Size=UDim2.new(1,-200,0,60) shopTitle.TextSize=42
shopFrame.Illustration.Position=UDim2.fromOffset(14,5) shopFrame.Illustration.Size=UDim2.fromOffset(78,78)
shopClose.Position=UDim2.new(1,-76,0,12)
rebirthRow.Position=UDim2.fromOffset(20,94) Garage.Inset(rebirthRow)
shopScroll.Position=UDim2.fromOffset(20,196) shopScroll.Size=UDim2.new(1,-40,1,-212)

dailyTitle.Size=UDim2.new(1,-250,0,38)
travelTitle.Size=UDim2.new(1,-115,0,50)

-- Daily rewards reference canvas.
Garage.Canvas(dailyFrame,1200,820)
dailyTitle.Text="DAILY REWARDS" dailyTitle.Position=UDim2.fromOffset(90,16) dailyTitle.Size=UDim2.fromOffset(495,64) dailyTitle.TextSize=46
Garage.Art(dailyFrame,"REWARDS",UDim2.fromOffset(12,12),UDim2.fromOffset(78,78))
streakPill.Position=UDim2.fromOffset(615,18) streakPill.Size=UDim2.fromOffset(445,42) streakPill.BackgroundTransparency=1
streakLabel.Position=UDim2.fromOffset(0,0) streakLabel.Size=UDim2.fromScale(1,1) streakLabel.TextSize=29 streakLabel.TextColor3=GOLD streakLabel:SetAttribute("Designed",true)
dailySub.Position=UDim2.fromOffset(610,63) dailySub.Size=UDim2.fromOffset(460,34) dailySub.TextSize=16 dailySub.TextWrapped=true dailySub.TextColor3=Color3.new(1,1,1) dailySub:SetAttribute("Designed",true)
grid.Position=UDim2.fromOffset(32,120) grid.Size=UDim2.new(1,-64,0,540)
claimBtn.Position=UDim2.new(.5,-275,1,-115) claimBtn.Size=UDim2.fromOffset(550,84) claimBtn.TextSize=36
Garage.Button(claimBtn,Color3.fromRGB(255,163,19))

Garage.Canvas(shopFrame,1200,820)
shopLayout.CellSize=UDim2.fromOffset(548,250) shopLayout.FillDirectionMaxCells=2 shopLayout.CellPadding=UDim2.fromOffset(18,18)
shopScroll.Position=UDim2.fromOffset(28,104) shopScroll.Size=UDim2.new(1,-56,0,526)
shopFrame.Illustration:Destroy() Garage.Art(shopFrame,"UPGRADES",UDim2.fromOffset(14,8),UDim2.fromOffset(78,78))
shopTitle.Size=UDim2.fromOffset(480,64)
rebirthRow.Position=UDim2.fromOffset(24,648) rebirthRow.Size=UDim2.new(1,-48,0,145)
Garage.Gloss(rebirthRow,Color3.fromRGB(161,63,236),20)
Garage.Art(rebirthRow,"rebirth",UDim2.fromOffset(12,0),UDim2.fromOffset(155,142))
rebirthTitle.Position=UDim2.fromOffset(176,16) rebirthTitle.Size=UDim2.new(1,-390,0,32) rebirthTitle.TextSize=28 UIStyle.Outline(rebirthTitle,28)
rebirthNow.Position=UDim2.fromOffset(176,57) rebirthNow.Size=UDim2.new(1,-390,0,25) rebirthNow.TextSize=18
rebirthNext.Position=UDim2.fromOffset(176,86) rebirthNext.Size=UDim2.new(1,-390,0,44) rebirthNext.TextSize=17
for _,l in {rebirthNow,rebirthNext} do l:SetAttribute("Designed",true) l.TextColor3=Color3.new(1,1,1) end
rebirthBtn.Size=UDim2.fromOffset(186,66) rebirthBtn.Position=UDim2.new(1,-200,.5,-33) Garage.Button(rebirthBtn,Color3.fromRGB(179,54,243))

Garage.Canvas(travelFrame,1200,820)
travelTitle.Position=UDim2.fromOffset(94,14) travelTitle.Size=UDim2.fromOffset(470,64) travelTitle.TextSize=46
Garage.Art(travelFrame,"TRAVEL",UDim2.fromOffset(14,8),UDim2.fromOffset(78,78))
travelSub.Position=UDim2.fromOffset(610,27) travelSub.Size=UDim2.fromOffset(400,42) travelSub.TextSize=26 travelSub.TextColor3=Color3.new(1,1,1) travelSub:SetAttribute("Designed",true)
travelScroll.Position=UDim2.fromOffset(22,108) travelScroll.Size=UDim2.new(1,-44,1,-128)
