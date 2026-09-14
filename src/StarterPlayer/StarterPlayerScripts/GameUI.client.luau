--[[
	GameUI (LocalScript, StarterPlayerScripts) — Junkyard Fusion v1

	Four pieces:
	  • Objective card   (top left)     — the one thing to do next
	  • Discovery panel  (top right)    — what you've found
	  • Carry bar        (bottom)       — what's in your hands
	  • Item index       (press B)      — every item, masked until found

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
local removeFromCarryRemote = ReplicatedStorage:WaitForChild("RemoveFromCarry")
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
	l.Text = text
	l.TextColor3 = color or LIGHT
	l.Font = font or Enum.Font.FredokaOne
	l.TextSize = textSize or 14
	l.TextXAlignment = Enum.TextXAlignment.Left
	l.Parent = parent
	return l
end

------------------------------------------------------------------
-- Objective card (top left) — the structure that was missing
------------------------------------------------------------------

local objCard = Instance.new("Frame")
objCard.Size = UDim2.new(0, 300, 0, 92)
objCard.Position = UDim2.new(0, 20, 0, 20)
objCard.BackgroundColor3 = DARK
objCard.BackgroundTransparency = GLASS_HUD
objCard.BorderSizePixel = 0
objCard.Parent = gui
UIStyle.Navigation(objCard)
rounded(objCard)

local objStripe = Instance.new("Frame")
objStripe.Size = UDim2.new(0, 5, 1, -16)
objStripe.Position = UDim2.new(0, 8, 0, 8)
objStripe.BackgroundColor3 = BLUE
objStripe.BorderSizePixel = 0
objStripe.Parent = objCard
rounded(objStripe, 3)

local objHeader = label(objCard, "OBJECTIVE 1 / 9", UDim2.new(1, -30, 0, 20), BLUE, Enum.Font.FredokaOne, 12)
objHeader.Position = UDim2.new(0, 22, 0, 10)

local objText = label(objCard, "...", UDim2.new(1, -34, 0, 38), LIGHT, Enum.Font.FredokaOne, 17)
objText.Position = UDim2.new(0, 22, 0, 30)
objText.TextWrapped = true

local objReward = label(objCard, "", UDim2.new(1, -30, 0, 18), DIM, Enum.Font.FredokaOne, 13)
objReward.Position = UDim2.new(0, 22, 0, 68)

------------------------------------------------------------------
-- Coin counter (under the objective card)
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

local luckText = label(coinCard, "LUCK 1", UDim2.new(0, 90, 0, 18), DIM, Enum.Font.FredokaOne, 12)
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
	return ItemRarity.Tag(baseName, FusionRecipes.GetTier(baseName), FusionRecipes.IsSecretResult(baseName))
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
UIStyle.FixedFit(dailyFrame,600,470)

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
claimBtn.Size = UDim2.new(0, 280, 0, 52)
claimBtn.Position = UDim2.new(0.5, -140, 1, -70)
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
		Size = UDim2.new(0, 292, 0, 56),
		Position = UDim2.new(0.5, -146, 1, -72),
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
	dailyFrame.Size = UDim2.new(0, 560, 0, 440)
	dailyFrame.Position = UDim2.fromScale(0.5, 0.5)
	TweenService:Create(dailyFrame, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.new(0, 600, 0, 470),
		Position = UDim2.fromScale(0.5, 0.5),
	}):Play()
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
	for _, child in ipairs(grid:GetChildren()) do
		if not child:IsA("UIGridLayout") then child:Destroy() end
	end
	pulseCard = nil

	streakLabel.Text = string.format("🔥 %d DAY STREAK", claimed or 0)

	for day, reward in ipairs(rewards or {}) do
		local isClaimed = day <= (claimed or 0)
		local isNext    = available and day == nextDay
		local isBonus   = day == #rewards

		local card = Instance.new("Frame")
		card.LayoutOrder = day
		card.BorderSizePixel = 0
		card.ZIndex = 7
		card.BackgroundColor3 = Color3.fromRGB(32, 32, 40)
		card.Parent = grid
		rounded(card, 12)

		local cardGradient = Instance.new("UIGradient")
		cardGradient.Rotation = 90
		cardGradient.Parent = card

		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 2
		stroke.Transparency = 0.5
		stroke.Parent = card

		local accentColor

		if isNext then
			cardGradient.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 222, 120)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(236, 168, 40)),
			})
			stroke.Color = Color3.fromRGB(255, 250, 210)
			accentColor = Color3.fromRGB(40, 30, 10)
			pulseCard = card
		elseif isClaimed then
			cardGradient.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(90, 200, 130)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(40, 120, 70)),
			})
			stroke.Color = Color3.fromRGB(170, 255, 200)
			accentColor = Color3.fromRGB(225, 255, 235)
		elseif isBonus then
			cardGradient.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 120, 200)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(120, 70, 220)),
			})
			stroke.Color = Color3.fromRGB(255, 200, 255)
			accentColor = Color3.fromRGB(255, 230, 255)
		else
			cardGradient.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(40, 40, 50)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(26, 26, 34)),
			})
			stroke.Color = Color3.fromRGB(70, 70, 84)
			accentColor = Color3.fromRGB(120, 120, 140)
		end

		local textColor = isNext and Color3.fromRGB(34, 24, 8) or LIGHT

		-- Day number
		local dayLabel = label(card, "DAY " .. day, UDim2.new(1, 0, 0, 16), accentColor, Enum.Font.FredokaOne, 12)
		dayLabel.Position = UDim2.new(0, 0, 0, 12)
		dayLabel.TextXAlignment = Enum.TextXAlignment.Center
		dayLabel.ZIndex = 8

		-- Coin dot
		local coin = Instance.new("Frame")
		coin.Size = UDim2.new(0, 26, 0, 26)
		coin.Position = UDim2.new(0.5, -13, 0, 32)
		coin.BackgroundColor3 = isNext and Color3.fromRGB(60, 44, 12) or GOLD
		coin.BorderSizePixel = 0
		coin.ZIndex = 8
		coin.Parent = card
		rounded(coin, 13)

		local coinGradient = Instance.new("UIGradient")
		if reward.kind == "boost" then
			coinGradient.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(160, 220, 255)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(70, 150, 220)),
			})
		elseif reward.kind == "item" then
			coinGradient.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(220, 170, 255)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(150, 90, 220)),
			})
		else
			coinGradient.Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 232, 150)),
				ColorSequenceKeypoint.new(1, Color3.fromRGB(224, 160, 40)),
			})
		end
		coinGradient.Rotation = 90
		coinGradient.Parent = coin

		-- Amount
		local iconText = "💰"
		if reward.kind == "boost" then
			iconText = "⚡"
		elseif reward.kind == "item" then
			iconText = "📦"
		elseif reward.kind == "jackpot" then
			iconText = "👑"
		end

		local iconLabel = label(coin, iconText, UDim2.new(1, 0, 1, 0), Color3.fromRGB(255, 255, 255), Enum.Font.FredokaOne, 15)
		iconLabel.TextXAlignment = Enum.TextXAlignment.Center
		iconLabel.ZIndex = 9

		-- Reward name, then the qualifier underneath
		local amountLabel = label(card, reward.label, UDim2.new(1, -8, 0, 24), textColor, Enum.Font.LuckiestGuy, isBonus and 18 or 15)
		amountLabel.Position = UDim2.new(0, 4, 0, 62)
		amountLabel.TextXAlignment = Enum.TextXAlignment.Center
		amountLabel.TextScaled = true
		amountLabel.ZIndex = 8

		local subLabel = label(card, reward.sub or "", UDim2.new(1, -8, 0, 14),
			isNext and Color3.fromRGB(70, 52, 16) or DIM, Enum.Font.FredokaOne, 10)
		subLabel.Position = UDim2.new(0, 4, 0, 86)
		subLabel.TextXAlignment = Enum.TextXAlignment.Center
		subLabel.ZIndex = 8

		-- Status strip along the bottom
		local statusBar = Instance.new("Frame")
		statusBar.Size = UDim2.new(1, -20, 0, 22)
		statusBar.Position = UDim2.new(0, 10, 1, -30)
		statusBar.BackgroundColor3 = isNext and Color3.fromRGB(52, 38, 10) or Color3.fromRGB(18, 18, 24)
		statusBar.BackgroundTransparency = 0.25
		statusBar.BorderSizePixel = 0
		statusBar.ZIndex = 8
		statusBar.Parent = card
		rounded(statusBar, 6)

		local statusText = "🔒 LOCKED"
		if isClaimed then
			statusText = "✔ CLAIMED"
		elseif isNext then
			statusText = "▶ CLAIM NOW"
		elseif isBonus then
			statusText = "👑 JACKPOT"
		end

		local status = label(statusBar, statusText, UDim2.new(1, 0, 1, 0),
			isNext and Color3.fromRGB(255, 236, 170) or accentColor, Enum.Font.FredokaOne, 11)
		status.TextXAlignment = Enum.TextXAlignment.Center
		status.ZIndex = 9

		-- Staggered entrance
		card.Size = UDim2.new(0, 0, 0, 0)
		task.delay(day * 0.045, function()
			if card.Parent then
				TweenService:Create(card, TweenInfo.new(0.3, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
					Size = UDim2.new(0, 128, 0, 130),
				}):Play()
			end
		end)
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
-- Discovery panel (top right)
------------------------------------------------------------------

local panel = Instance.new("Frame")
panel.Size = UDim2.new(0, 240, 0, 300)
panel.Position = UDim2.new(1, -260, 0, 20)
panel.BackgroundColor3 = DARK
panel.BackgroundTransparency = GLASS_HUD
panel.BorderSizePixel = 0
panel.Parent = gui
UIStyle.Navigation(panel)
rounded(panel)

local header = label(panel, "DISCOVERIES  0 / 0", UDim2.new(1, -20, 0, 34), PURPLE, Enum.Font.FredokaOne, 15)
header.Position = UDim2.new(0, 12, 0, 8)

local secretLine = label(panel, "Secrets  0 / 3", UDim2.new(1, -20, 0, 16), DIM, Enum.Font.FredokaOne, 12)
secretLine.Position = UDim2.new(0, 12, 0, 34)

local list = Instance.new("ScrollingFrame")
list.Size = UDim2.new(1, -20, 1, -66)
list.Position = UDim2.new(0, 12, 0, 56)
list.BackgroundTransparency = 1
list.BorderSizePixel = 0
list.ScrollBarThickness = 4
list.CanvasSize = UDim2.new(0, 0, 0, 0)
list.Parent = panel

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 3)
layout.Parent = list

------------------------------------------------------------------
-- Carry bar (bottom centre)
------------------------------------------------------------------

local carryingFrame = Instance.new("Frame")
carryingFrame.Size = UDim2.new(0, 470, 0, 58)
carryingFrame.Position = UDim2.new(0.5, -235, 1, -92)
carryingFrame.BackgroundColor3 = DARK
carryingFrame.BackgroundTransparency = GLASS_HUD
carryingFrame.BorderSizePixel = 0
carryingFrame.Parent = gui
UIStyle.Navigation(carryingFrame)
rounded(carryingFrame)

local carryingStroke = Instance.new("UIStroke")
carryingStroke.Color = WHITE
carryingStroke.Transparency = 0.5
carryingStroke.Thickness = 1.5
carryingStroke.Parent = carryingFrame

local carryingLabel = label(carryingFrame, "CARRYING", UDim2.new(0, 150, 0, 18), LIGHT, Enum.Font.FredokaOne, 14)
carryingLabel.Position = UDim2.new(0, 14, 0, 6)
carryingLabel.TextXAlignment = Enum.TextXAlignment.Left

local carryingHint = label(carryingFrame, "tap a slot to take it off", UDim2.new(0, 200, 0, 18), DIM, Enum.Font.FredokaOne, 12)
carryingHint.Position = UDim2.new(1, -214, 0, 6)
carryingHint.TextXAlignment = Enum.TextXAlignment.Right

local carrySlotsHolder = Instance.new("Frame")
carrySlotsHolder.Size = UDim2.new(1, -28, 0, 26)
carrySlotsHolder.Position = UDim2.new(0, 14, 0, 26)
carrySlotsHolder.BackgroundTransparency = 1
carrySlotsHolder.Parent = carryingFrame

local carrySlotsLayout = Instance.new("UIListLayout")
carrySlotsLayout.FillDirection = Enum.FillDirection.Horizontal
carrySlotsLayout.Padding = UDim.new(0, 8)
carrySlotsLayout.VerticalAlignment = Enum.VerticalAlignment.Center
carrySlotsLayout.Parent = carrySlotsHolder

-- Clicking a filled slot sends it back to the Inventory — the client-side
-- half of "take something off the fuse pad" (the physical pad itself gets
-- taken off the same way, via its own ProximityPrompt, on the server).
local function redrawCarrySlots(slots, maxSlots)
	maxSlots = maxSlots or 2
	for _, child in ipairs(carrySlotsHolder:GetChildren()) do
		if not child:IsA("UIListLayout") then child:Destroy() end
	end

	for i = 1, maxSlots do
		local name = slots[i]

		local slotBtn = Instance.new("TextButton")
		slotBtn.Size = UDim2.new(0, 200, 1, 0)
		slotBtn.LayoutOrder = i
		slotBtn.BackgroundColor3 = name and Color3.fromRGB(42, 42, 50) or Color3.fromRGB(26, 26, 32)
		slotBtn.AutoButtonColor = name ~= nil
		slotBtn.Text = name and instanceTag(name) or "[ empty ]"
		slotBtn.TextColor3 = name and LIGHT or DIM
		slotBtn.RichText = true
		slotBtn.Font = Enum.Font.FredokaOne
		slotBtn.TextSize = 14
		slotBtn.TextTruncate = Enum.TextTruncate.AtEnd
		slotBtn.BorderSizePixel = 0
		slotBtn.Parent = carrySlotsHolder
		rounded(slotBtn, 6)

		if name then
			slotBtn.MouseButton1Click:Connect(function()
				removeFromCarryRemote:FireServer(i)
			end)
		end
	end
end

------------------------------------------------------------------
-- Item index (press B) — every item in the game, colored by rarity,
-- showing what you have and haven't found yet.
------------------------------------------------------------------

local bookBtn = NavButton.Create(gui, "📖", "INDEX", PURPLE, NavButton.RailPosition("left", 3))

-- Big picker modal — nearly fullscreen like the travel menu, same scale
-- trick so it stays "almost the whole screen" on any resolution.
local bookFrame = Instance.new("Frame")
bookFrame.Size = UDim2.new(0.88, 0, 0.88, 0)
bookFrame.Position = UDim2.new(0.06, 0, 0.06, 0)
bookFrame.BackgroundColor3 = DARK
bookFrame.BackgroundTransparency = GLASS_PANEL
bookFrame.BorderSizePixel = 0
bookFrame.Visible = false
bookFrame.Parent = gui
rounded(bookFrame, 18)
UIStyle.Modal(bookFrame)

local bookTitle = label(bookFrame, "ITEM INDEX", UDim2.new(0, 360, 0, 50), GOLD, Enum.Font.LuckiestGuy, 40)
bookTitle.Position = UDim2.new(0, 32, 0, 22)

local bookClose = Instance.new("TextButton")
bookClose.Size = UDim2.new(0, 42, 0, 42)
bookClose.Position = UDim2.new(1, -60, 0, 20)
bookClose.BackgroundTransparency = 1
bookClose.Text = "X"
bookClose.TextColor3 = DIM
bookClose.Font = Enum.Font.FredokaOne
bookClose.TextSize = 26
bookClose.Parent = bookFrame

-- Two big pill tabs, one per item line — each keeps its own list so
-- switching tabs never needs a round trip to the server.
local tabJunkyard = Instance.new("TextButton")
tabJunkyard.Size = UDim2.new(0, 190, 0, 40)
tabJunkyard.Position = UDim2.new(1, -420, 0, 28)
tabJunkyard.Text = "🚗 JUNKYARD"
tabJunkyard.Font = Enum.Font.LuckiestGuy
tabJunkyard.TextSize = 16
tabJunkyard.BorderSizePixel = 0
tabJunkyard.Parent = bookFrame
rounded(tabJunkyard, 20)

local tabBrainrot = Instance.new("TextButton")
tabBrainrot.Size = UDim2.new(0, 190, 0, 40)
tabBrainrot.Position = UDim2.new(1, -220, 0, 28)
tabBrainrot.Text = "🧠 BRAINROT"
tabBrainrot.Font = Enum.Font.LuckiestGuy
tabBrainrot.TextSize = 16
tabBrainrot.BorderSizePixel = 0
tabBrainrot.Parent = bookFrame
rounded(tabBrainrot, 20)

-- One pill per rarity, in display order — secrets pulled out of their
-- numeric tier into their own gold page, since "which tier" is less
-- interesting than "it's a secret" once you're paging by color.
local SECTION_ORDER = { 1, 2, 3, 4, "secret" }
local SECTION_INFO = {
	[1]      = { name = "COMMON",   color = ItemRarity.Color(1, false) },
	[2]      = { name = "UNCOMMON", color = ItemRarity.Color(2, false) },
	[3]      = { name = "RARE",     color = ItemRarity.Color(3, false) },
	[4]      = { name = "EPIC",     color = ItemRarity.Color(4, false) },
	secret   = { name = "SECRET",   color = ItemRarity.Color(1, true) },
}

local rarityRow = Instance.new("Frame")
rarityRow.Size = UDim2.new(1, -64, 0, 40)
rarityRow.Position = UDim2.new(0, 32, 0, 74)
rarityRow.BackgroundTransparency = 1
rarityRow.Parent = bookFrame

local rarityLayout = Instance.new("UIListLayout")
rarityLayout.FillDirection = Enum.FillDirection.Horizontal
rarityLayout.Padding = UDim.new(0, 8)
rarityLayout.Parent = rarityRow

local rarityTabs = {}
for _, key in ipairs(SECTION_ORDER) do
	local info = SECTION_INFO[key]
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(0.19, 0, 1, 0)
	btn.Text = info.name
	btn.Font = Enum.Font.LuckiestGuy
	btn.TextSize = 15
	btn.BorderSizePixel = 0
	btn.Parent = rarityRow
	rounded(btn, 10)
	rarityTabs[key] = btn
end

local pageHeader = Instance.new("Frame")
pageHeader.Size = UDim2.new(1, -64, 0, 44)
pageHeader.Position = UDim2.new(0, 32, 0, 122)
pageHeader.BorderSizePixel = 0
pageHeader.Parent = bookFrame
rounded(pageHeader, 12)

local pageHeaderGradient = Instance.new("UIGradient")
pageHeaderGradient.Rotation = 20
pageHeaderGradient.Parent = pageHeader

local pageHeaderText = label(pageHeader, "", UDim2.new(1, -140, 1, 0), Color3.fromRGB(255, 255, 255), Enum.Font.LuckiestGuy, 22)
pageHeaderText.Position = UDim2.new(0, 18, 0, 0)
pageHeaderText.TextStrokeTransparency = 0.5

local pageHeaderCount = label(pageHeader, "", UDim2.new(0, 110, 1, 0), Color3.fromRGB(255, 255, 255), Enum.Font.LuckiestGuy, 20)
pageHeaderCount.Position = UDim2.new(1, -128, 0, 0)
pageHeaderCount.TextXAlignment = Enum.TextXAlignment.Right
pageHeaderCount.TextStrokeTransparency = 0.5

local bookScroll = Instance.new("ScrollingFrame")
bookScroll.Size = UDim2.new(1, -64, 1, -222)
bookScroll.Position = UDim2.new(0, 32, 0, 178)
bookScroll.BackgroundTransparency = 1
bookScroll.BorderSizePixel = 0
bookScroll.ScrollBarThickness = 8
bookScroll.Parent = bookFrame

local bookLayout = Instance.new("UIGridLayout")
bookLayout.CellSize = UDim2.new(0, 170, 0, 200)
bookLayout.CellPadding = UDim2.new(0, 14, 0, 14)
bookLayout.Parent = bookScroll

-- A small live 3D render of the actual mesh, framed generically by its
-- own bounding size so a Rusted Sedan and a THE LAWNLORD both center
-- nicely without per-item camera tuning.
-- tintColor is optional — used for a mutated inventory item's icon; the
-- Index never passes it, since discovered-recipe icons are never mutated.
local function buildItemViewport(parent, itemName, tintColor)
	local viewport = Instance.new("ViewportFrame")
	viewport.Size = UDim2.new(1, -16, 1, -46)
	viewport.Position = UDim2.new(0, 8, 0, 8)
	viewport.BorderSizePixel = 0
	viewport.BackgroundColor3 = Color3.new(1,1,1)
	viewport.BackgroundTransparency = 1
	viewport.Ambient = Color3.fromRGB(195,195,205)
	viewport.LightColor = Color3.new(1,1,1)
	viewport.Parent = parent

	local cam = Instance.new("Camera")
	cam.FieldOfView = 35
	viewport.CurrentCamera = cam
	cam.Parent = viewport

	local template = itemModels:FindFirstChild(itemName)
	if template then
		local clone = template:Clone()
		clone.Anchored = true
		clone.CFrame = CFrame.new(0, 0, 0)
		if tintColor then clone.Color = tintColor end
		clone.Parent = viewport

		local size = clone.Size
		local reach = math.max(size.X, size.Y, size.Z) * 1.5 + 0.2
		cam.CFrame = CFrame.new(Vector3.new(reach * 0.6, reach * 0.5, reach * 0.85), Vector3.new(0, 0, 0))
	end
end

local function toggleBook()
	bookFrame.Visible = not bookFrame.Visible
end

bookBtn.MouseButton1Click:Connect(toggleBook)
bookClose.MouseButton1Click:Connect(toggleBook)

UserInputService.InputBegan:Connect(function(input, processed)
	if processed then return end
	if input.KeyCode == Enum.KeyCode.B then
		toggleBook()
	end
end)

local indexData = { junkyard = {}, brainrot = {} }
local activeTab = "junkyard"
local activeRarity = 1
local equippedCompanion = nil -- { name, island, bonusPercent } or nil

local function redrawIndex()
	for _, child in ipairs(bookScroll:GetChildren()) do
		if not child:IsA("UIGridLayout") then child:Destroy() end
	end

	local onJunkyard = activeTab == "junkyard"
	tabJunkyard.BackgroundColor3 = onJunkyard and GOLD or Color3.fromRGB(50, 50, 58)
	tabJunkyard.TextColor3 = onJunkyard and DARK or LIGHT
	tabBrainrot.BackgroundColor3 = onJunkyard and Color3.fromRGB(50, 50, 58) or GOLD
	tabBrainrot.TextColor3 = onJunkyard and LIGHT or DARK
	UIStyle.Surface(tabJunkyard)
	UIStyle.Surface(tabBrainrot)
	tabJunkyard:FindFirstChildOfClass("UIStroke").Thickness = onJunkyard and 4 or 1
	tabBrainrot:FindFirstChildOfClass("UIStroke").Thickness = onJunkyard and 1 or 4

	local buckets = {}
	for _, key in ipairs(SECTION_ORDER) do buckets[key] = {} end
	for _, entry in ipairs(indexData[activeTab]) do
		local key = entry.isSecret and "secret" or entry.tier
		if buckets[key] then table.insert(buckets[key], entry) end
	end

	for _, key in ipairs(SECTION_ORDER) do
		local info = SECTION_INFO[key]
		local isActive = key == activeRarity
		-- Inactive tabs stay tinted with their own color instead of flat
		-- gray, so the whole row previews the rarity palette even before
		-- you click anything.
		rarityTabs[key].BackgroundColor3 = isActive and info.color or info.color:Lerp(Color3.fromRGB(30, 30, 36), 0.75)
		rarityTabs[key].TextColor3 = isActive and Color3.fromRGB(20, 20, 26) or info.color:Lerp(Color3.fromRGB(255, 255, 255), 0.25)
		UIStyle.Surface(rarityTabs[key])
		rarityTabs[key]:FindFirstChildOfClass("UIStroke").Thickness = isActive and 4 or 1
	end

	local bucket = buckets[activeRarity]
	local info = SECTION_INFO[activeRarity]
	local knownCount = 0
	for _, e in ipairs(bucket) do
		if e.known then knownCount = knownCount + 1 end
	end

	pageHeader.BackgroundColor3 = info.color
	pageHeaderGradient.Color = ColorSequence.new(info.color, info.color:Lerp(Color3.new(1, 1, 1), 0.35))
	pageHeaderText.Text = info.name
	pageHeaderCount.Text = string.format("%d / %d", knownCount, #bucket)

	-- Pet-Sim style cards: a live photo of the actual item on top, its
	-- name below, tinted by rarity. Undiscovered entries show a "?"
	-- silhouette instead of rendering anything — collected or not, no
	-- ingredients, no arrows: this is a collection list, not a recipe book.
	-- Known cards double as the companion picker — click one to equip it.
	for i, entry in ipairs(bucket) do
		local isEquipped = equippedCompanion
			and equippedCompanion.name == entry.name
			and equippedCompanion.island == activeTab

		local card = Instance.new(entry.known and "TextButton" or "Frame")
		card.Size = bookLayout.CellSize
		card.LayoutOrder = i
		card.BackgroundColor3 = entry.known
			and info.color:Lerp(Color3.fromRGB(18, 18, 24), 0.35)
			or Color3.fromRGB(32, 32, 38)
		card.BorderSizePixel = 0
		card.Parent = bookScroll
		rounded(card, 14)

		if entry.known then
			card.Text = ""
			card.AutoButtonColor = false
			card.MouseButton1Click:Connect(function()
				equipCompanionRemote:FireServer(entry.name, activeTab)
			end)

			-- A soft top-to-bottom sheen instead of a flat fill, so cards
			-- read as glossy collectibles rather than plain colored boxes.
			local sheen = Instance.new("UIGradient")
			sheen.Color = ColorSequence.new(info.color:Lerp(Color3.fromRGB(255, 255, 255), 0.3), card.BackgroundColor3)
			sheen.Rotation = 90
			sheen.Parent = card
		end

		local stroke = Instance.new("UIStroke")
		stroke.Color = isEquipped and Color3.fromRGB(255, 255, 255) or entry.known and info.color or Color3.fromRGB(60, 60, 68)
		stroke.Thickness = isEquipped and 3.5 or entry.known and 2.5 or 1.5
		stroke.Parent = card

		-- Secrets get a slow breathing glow on top of everything else —
		-- the rarest page in the book should feel like it, not just be
		-- colored gold like any other rarity.
		if entry.known and activeRarity == "secret" and not isEquipped then
			TweenService:Create(stroke, TweenInfo.new(0.9, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), {
				Thickness = 4.5,
			}):Play()
		end

		if isEquipped then
			local badge = Instance.new("TextLabel")
			badge.Size = UDim2.new(1, -12, 0, 20)
			badge.Position = UDim2.new(0, 6, 0, 6)
			badge.BackgroundTransparency = 1
			badge.Text = "★ COMPANION"
			badge.TextColor3 = Color3.fromRGB(255, 255, 255)
			badge.TextStrokeTransparency = 0.3
			badge.Font = Enum.Font.FredokaOne
			badge.TextScaled = true
			badge.ZIndex = 2
			badge.Parent = card
		end

		if entry.known then
			buildItemViewport(card, entry.name)
		else
			local lock = Instance.new("TextLabel")
			lock.Size = UDim2.new(1, -16, 1, -46)
			lock.Position = UDim2.new(0, 8, 0, 8)
			lock.BackgroundTransparency = 1
			lock.Text = "?"
			-- A faint hint of the page's own color instead of flat gray —
			-- still clearly "locked", but the whole page doesn't go dead
			-- monochrome just because nothing on it is discovered yet.
			lock.TextColor3 = info.color:Lerp(Color3.fromRGB(45, 45, 52), 0.75)
			lock.Font = Enum.Font.LuckiestGuy
			lock.TextScaled = true
			lock.Parent = card
		end

		local nameLabel = Instance.new("TextLabel")
		nameLabel.Size = UDim2.new(1, -16, 0, 32)
		nameLabel.Position = UDim2.new(0, 8, 1, -38)
		nameLabel.BackgroundTransparency = 1
		nameLabel.Text = entry.known and entry.name or "???"
		nameLabel.TextColor3 = entry.known and Color3.fromRGB(255, 255, 255) or DIM
		nameLabel.TextStrokeTransparency = entry.known and 0.4 or 1
		nameLabel.Font = Enum.Font.FredokaOne
		nameLabel.TextScaled = true
		nameLabel.TextWrapped = true
		nameLabel.Parent = card
	end

	bookScroll.CanvasSize = UDim2.new(0, 0, 0, bookLayout.AbsoluteContentSize.Y + 10)
end

for _, key in ipairs(SECTION_ORDER) do
	rarityTabs[key].MouseButton1Click:Connect(function()
		activeRarity = key
		redrawIndex()
	end)
end

tabJunkyard.MouseButton1Click:Connect(function()
	activeTab = "junkyard"
	redrawIndex()
end)
tabBrainrot.MouseButton1Click:Connect(function()
	activeTab = "brainrot"
	redrawIndex()
end)

redrawIndex()

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
UIStyle.Fit(shopFrame, 1100, 760)
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

local shopLayout = Instance.new("UIListLayout")
shopLayout.Padding = UDim.new(0, 8)
shopLayout.Parent = shopScroll
UIStyle.ScrollPadding(shopScroll)

shopScroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
shopFrame:GetAttributeChangedSignal("Compact"):Connect(function() UIStyle.UpgradeLayout(shopFrame, shopScroll) end)

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
	magnet = PURPLE,
	value = RED,
	speed = WHITE,
}

local function redrawShop(shop)
	for _, child in ipairs(shopScroll:GetChildren()) do
		if not child:IsA("UIListLayout") and not child:IsA("UIPadding") then child:Destroy() end
	end

	for i, entry in ipairs(shop or {}) do
		local accent = UPGRADE_COLORS[entry.key] or LIGHT

		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, -10, 0, 156)
		row.Name = entry.key
		row.LayoutOrder = i
		row.BackgroundColor3 = accent:Lerp(Color3.new(1,1,1),.72)
		row.BorderSizePixel = 0
		row.Parent = shopScroll
		rounded(row, 6)

		local rowStroke = Instance.new("UIStroke")
		rowStroke.Color = accent
		rowStroke.Transparency = 0
		rowStroke.Color=Color3.fromRGB(35,35,43)
		rowStroke.Thickness = 1.5
		rowStroke.Parent = row
		UIStyle.Art(row, entry.key, UDim2.fromOffset(10,8), UDim2.fromOffset(140,140))

		local name = label(row, string.format("%s  —  Lv %d / %d", entry.name, entry.level, entry.max),
			UDim2.new(1, -360, 0, 32), accent, Enum.Font.FredokaOne, 24)
		name.Name = "UpgradeName"
		name.Position = UDim2.new(0, 166, 0, 20)

		local now = label(row, "Now: " .. entry.effect, UDim2.new(1, -360, 0, 28), DIM, Enum.Font.FredokaOne, 18)
		now.Name = "UpgradeNow"
		now.Position = UDim2.new(0, 166, 0, 62)

		if entry.nextEffect then
			local nxt = label(row, "Next: " .. entry.nextEffect, UDim2.new(1, -360, 0, 28),
				Color3.fromRGB(150, 220, 160), Enum.Font.FredokaOne, 18)
			nxt.Name = "UpgradeNext"
			nxt.Position = UDim2.new(0, 166, 0, 98)
		end

		local buy = Instance.new("TextButton")
		buy.Size = UDim2.new(0, 170, 0, 60)
		buy.Position = UDim2.new(1, -184, .5, -30)
		buy.BorderSizePixel = 0
		buy.Font = Enum.Font.FredokaOne
		buy.TextSize = 18
		buy.Name = "UpgradeBuy"
		buy.Parent = row
		rounded(buy, 6)

		if entry.cost then
			buy.BackgroundColor3 = GOLD
			buy.TextColor3 = DARK
			buy.Text = string.format("%s coins", entry.cost)
			buy.MouseButton1Click:Connect(function()
				buyRemote:FireServer(entry.key)
			end)
		else
			buy.BackgroundColor3 = Color3.fromRGB(50, 50, 58)
			buy.TextColor3 = DIM
			buy.Text = "MAXED"
		end
	end

	UIStyle.UpgradeLayout(shopFrame, shopScroll)
	shopScroll.CanvasSize = UDim2.new(0, 0, 0, shopLayout.AbsoluteContentSize.Y + 16)
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
	rebirthNow.Text = string.format("Current multiplier: x%.2f coins", info.multiplier)

	if info.maxed then
		rebirthNext.Text = "You've hit the ceiling — nothing left to cash in for."
		rebirthBtn.Text = "MAXED"
		rebirthBtn.BackgroundColor3 = Color3.fromRGB(50, 50, 58)
		rebirthBtn.TextColor3 = DIM
		rebirthBtn.Active = false
	else
		rebirthNext.Text = string.format(
			"Next: x%.2f — %d coins (clears inventory/upgrades only)",
			info.nextMultiplier, info.nextCost)
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
local currentPlacedCapacity = 5

local inventoryBtn = NavButton.Create(gui, "📦", "INVENTORY", BLUE, NavButton.RailPosition("left", 2))

local inventoryFrame = Instance.new("Frame")
inventoryFrame.Name = "InventoryPanel"
inventoryFrame.Size = UDim2.new(0, 1100, 0, 800)
inventoryFrame.Position = UDim2.new(0.5, -430, 0.5, -320)
inventoryFrame.BackgroundColor3 = DARK
inventoryFrame.BackgroundTransparency = GLASS_PANEL
inventoryFrame.BorderSizePixel = 0
inventoryFrame.Visible = false
inventoryFrame.Parent = gui
rounded(inventoryFrame, 18)
UIStyle.Fit(inventoryFrame, 1200, 800)
UIStyle.Surface(inventoryFrame,UIStyle.Palette.Cream,5)
UIStyle.Art(inventoryFrame,"INVENTORY",UDim2.fromOffset(-16,-80),UDim2.fromOffset(112,112))

local inventoryTitle = label(inventoryFrame, "INVENTORY", UDim2.new(0, 280, 0, 40), BLUE, Enum.Font.LuckiestGuy, 30)
inventoryTitle.Position = UDim2.fromOffset(92,-64)
inventoryTitle.Size = UDim2.fromOffset(480,88)
inventoryTitle.Text = "Inventory!"
UIStyle.Outline(inventoryTitle,60)

local inventoryCount = label(inventoryFrame, "0 / 15", UDim2.new(0, 110, 0, 34), DIM, Enum.Font.FredokaOne, 16)
inventoryCount.Position = UDim2.new(.5,-55,0,18)
inventoryCount.TextSize = 22

local inventoryClose = Instance.new("TextButton")
inventoryClose.Size = UDim2.new(0, 64, 0, 54)
inventoryClose.Position = UDim2.new(1, -76, 0, 8)
inventoryClose.BackgroundTransparency = 1
inventoryClose.Text = "X"
inventoryClose.TextColor3 = DIM
inventoryClose.Font = Enum.Font.FredokaOne
inventoryClose.TextSize = 20
inventoryClose.Parent = inventoryFrame
UIStyle.Close(inventoryClose)

-- A strip across the top showing the five pads at your plot — the only
-- things actually earning you money. Click an occupied one to take it
-- off (same as walking up to its physical pad and pressing the prompt).
local placedLabel = label(inventoryFrame, "🐾 YOUR PETS — EARNING (0 / 5)", UDim2.new(0, 400, 0, 22), GREEN, Enum.Font.LuckiestGuy, 16)
placedLabel.Position = UDim2.new(.5,-250,0,52)
placedLabel.Size = UDim2.fromOffset(500,30)
placedLabel.TextSize=23
placedLabel.TextXAlignment=Enum.TextXAlignment.Center

local placedRow = Instance.new("Frame")
placedRow.Size = UDim2.new(.72, 0, 0, 150)
placedRow:SetAttribute("Floating",true)
placedRow.Position = UDim2.new(.14, 0, 0, 94)
placedRow.BackgroundColor3 = Color3.fromRGB(20, 26, 22)
placedRow.BorderSizePixel = 0
placedRow.Parent = inventoryFrame
rounded(placedRow, 12)

local placedLayout = Instance.new("UIListLayout")
placedLayout.FillDirection = Enum.FillDirection.Horizontal
placedLayout.Padding = UDim.new(0, 10)
placedLayout.VerticalAlignment = Enum.VerticalAlignment.Center
placedLayout.Parent = placedRow
placedRow.ClipsDescendants = true

local placedPadding = Instance.new("UIPadding")
placedPadding.PaddingLeft = UDim.new(0, 10)
placedPadding.PaddingTop = UDim.new(0, 10)
placedPadding.Parent = placedRow

-- Left pane: everything you're holding.
local inventoryScroll = Instance.new("ScrollingFrame")
inventoryScroll.Name = "Items"
inventoryScroll.Size = UDim2.new(1, -48, 1, -280)
inventoryScroll.Position = UDim2.new(0, 24, 0, 260)
inventoryScroll.BackgroundTransparency = 1
inventoryScroll.BorderSizePixel = 0
inventoryScroll.ScrollBarThickness = 6
inventoryScroll.Parent = inventoryFrame

local inventoryLayout = Instance.new("UIGridLayout")
inventoryLayout.CellSize = UDim2.new(0, 224, 0, 250)
UIStyle.ScrollPadding(inventoryScroll)
inventoryLayout.CellPadding = UDim2.new(0, 10, 0, 10)
inventoryLayout.Parent = inventoryScroll
do
	local function reflow()
		local compact = inventoryFrame:GetAttribute("Compact")
		inventoryScroll.Size = UDim2.new(1,inventoryFrame:GetAttribute("DetailsOpen") and (compact and -292 or -386) or -48,1,-280)
		inventoryLayout.CellSize = compact and UDim2.fromOffset(158,190) or UDim2.fromOffset(184,206)
	end
	inventoryFrame:GetAttributeChangedSignal("Compact"):Connect(reflow)
	inventoryFrame:GetAttributeChangedSignal("DetailsOpen"):Connect(reflow)
	reflow()
end

-- Right pane: stats for whichever item is currently selected.
local statPanel = Instance.new("Frame")
statPanel.Name = "ItemDetails"
statPanel.Size = UDim2.new(0, 320, 1, -236)
statPanel.Position = UDim2.new(1, -344, 0, 222)
statPanel.BackgroundColor3 = Color3.fromRGB(26, 26, 32)
statPanel.BorderSizePixel = 0
statPanel.Parent = inventoryFrame
rounded(statPanel, 12)
UIStyle.ScrollDetails(statPanel, 350)
statPanel.Parent.Visible=false
do
	local wrapper = statPanel.Parent
	local function reflow()
		local compact = inventoryFrame:GetAttribute("Compact")
		wrapper.Size = UDim2.new(0,compact and 240 or 320,1,-280)
		wrapper.Position = UDim2.new(1,compact and -264 or -344,0,260)
	end
	inventoryFrame:GetAttributeChangedSignal("Compact"):Connect(reflow)
	reflow()
end

local statViewportHolder = Instance.new("Frame")
statViewportHolder.Size = UDim2.new(1, -28, 0, 116)
statViewportHolder.Position = UDim2.new(0, 14, 0, 14)
statViewportHolder.BackgroundColor3 = Color3.fromRGB(36, 36, 44)
statViewportHolder:SetAttribute("Floating",true)
statViewportHolder.BorderSizePixel = 0
statViewportHolder.Parent = statPanel
rounded(statViewportHolder, 10)

local statName = label(statPanel, "Select an item", UDim2.new(1, -28, 0, 50), LIGHT, Enum.Font.FredokaOne, 19)
statName.Position = UDim2.new(0, 14, 0, 130)
statName.Size=UDim2.new(1,-28,0,38)
statName.TextWrapped = true
statName.RichText = true

local statValue = label(statPanel, "", UDim2.new(1, -28, 0, 20), GOLD, Enum.Font.FredokaOne, 15)
statValue.Position = UDim2.new(0, 14, 0, 172)

local statPerSecond = label(statPanel, "", UDim2.new(1, -28, 0, 20), Color3.fromRGB(120, 220, 140), Enum.Font.FredokaOne, 15)
statPerSecond.Position = UDim2.new(0, 14, 0, 198)

local placeBtn = Instance.new("TextButton")
placeBtn.Size = UDim2.new(1, -28, 0, 36)
placeBtn.Position = UDim2.new(0, 14, 1, -122)
placeBtn.BackgroundColor3 = GREEN
placeBtn.Text = "PLACE ON PAD"
placeBtn.TextColor3 = DARK
placeBtn.Font = Enum.Font.LuckiestGuy
placeBtn.TextSize = 16
placeBtn.BorderSizePixel = 0
placeBtn.Visible = false
placeBtn.Parent = statPanel
rounded(placeBtn)

local moveToCarryBtn = Instance.new("TextButton")
moveToCarryBtn.Size = UDim2.new(1, -28, 0, 36)
moveToCarryBtn.Position = UDim2.new(0, 14, 1, -80)
moveToCarryBtn.BackgroundColor3 = PURPLE
moveToCarryBtn.Text = "CARRY TO FUSE"
moveToCarryBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
moveToCarryBtn.Font = Enum.Font.FredokaOne
moveToCarryBtn.TextSize = 14
moveToCarryBtn.BorderSizePixel = 0
moveToCarryBtn.Visible = false
moveToCarryBtn.Parent = statPanel
rounded(moveToCarryBtn)

local sellBtn = Instance.new("TextButton")
sellBtn.Size = UDim2.new(1, -28, 0, 36)
sellBtn.Position = UDim2.new(0, 14, 1, -38)
sellBtn.BackgroundColor3 = RED
sellBtn.Text = "SELL"
sellBtn.TextColor3 = Color3.fromRGB(255, 255, 255)
sellBtn.Font = Enum.Font.LuckiestGuy
sellBtn.TextSize = 16
sellBtn.BorderSizePixel = 0
sellBtn.Visible = false
sellBtn.Parent = statPanel
rounded(sellBtn)

local selectedIndex = nil
local searchBox = Instance.new("TextBox")
searchBox.Name="Search" searchBox.Text="" searchBox.PlaceholderText="Search items..."
searchBox.ClearTextOnFocus=false searchBox.Font=Enum.Font.FredokaOne searchBox.TextSize=24
searchBox.Position=UDim2.new(1,-332,0,-28) searchBox.Size=UDim2.fromOffset(260,50)
searchBox.Parent=inventoryFrame rounded(searchBox,22) UIStyle.Surface(searchBox,Color3.new(1,1,1),3)
do
	local function reflowHeader()
		local compact=inventoryFrame:GetAttribute("Compact")
		inventoryTitle.TextSize=compact and 44 or 60
		inventoryTitle.Size=UDim2.fromOffset(compact and 370 or 480,88)
		searchBox.Position=compact and UDim2.fromOffset(22,16) or UDim2.new(1,-332,0,-28)
		searchBox.Size=compact and UDim2.new(1,-160,0,46) or UDim2.fromOffset(260,50)
		inventoryCount.Position=compact and UDim2.new(1,-124,0,22) or UDim2.new(.5,-55,0,18)
		placedLabel.Position=UDim2.new(.5,-250,0,compact and 78 or 52)
		placedRow.Position=UDim2.new(.14,0,0,compact and 114 or 94)
	end
	inventoryFrame:GetAttributeChangedSignal("Compact"):Connect(reflowHeader)
	reflowHeader()
end


local function showStatsFor(entry)
	selectedIndex = entry and entry.index
	statPanel.Parent.Visible = entry ~= nil
	inventoryFrame:SetAttribute("DetailsOpen",entry~=nil)
	for _, c in ipairs(statViewportHolder:GetChildren()) do c:Destroy() end

	if not entry then
		statName.Text = "Select an item"
		statValue.Text = ""
		statPerSecond.Text = ""
		sellBtn.Visible = false
		moveToCarryBtn.Visible = false
		placeBtn.Visible = false
		return
	end

	local baseName, mutationId = Mutations.Unwrap(entry.name)
	local tintColor = Mutations.Color(mutationId)
	buildItemViewport(statViewportHolder, baseName, tintColor)

	statName.Text = instanceTag(entry.name)
	statValue.Text = string.format("Value: %d coins", math.floor(entry.value))
	statPerSecond.Text = string.format("If placed: %.1f coins/sec", entry.perSecond)
	sellBtn.Visible = true
	moveToCarryBtn.Visible = true
	placeBtn.Visible = true
	placeBtn.BackgroundColor3 = #currentPlaced >= currentPlacedCapacity and DIM or GREEN
end

do
	local back=Instance.new("TextButton")
	back.Name="CloseDetails" back.Text="X" back.Font=Enum.Font.FredokaOne back.TextSize=18
	back.BackgroundTransparency=1 back.Size=UDim2.fromOffset(34,34)
	back.Position=UDim2.new(1,-38,0,2) back.ZIndex=4 back.Parent=statPanel
	back.Activated:Connect(function() showStatsFor(nil) end)
end

-- redrawPlaced (below) and redrawInventory each need to re-run the
-- other whenever a selection or count changes — both are already
-- predeclared above (see the `do` block comment), so neither needs its
-- own separate forward-declare here.
function redrawInventory(items, capacity)
	-- Selling or moving an earlier-indexed item shifts everything after it
	-- down by one (table.remove semantics), so a plain index match after
	-- the swap can land on a completely different item that happened to
	-- inherit the old selection's slot. Comparing the name too catches that;
	-- an index match with a different name means our selection is gone.
	local previousSelectedName = selectedIndex and currentInventory[selectedIndex] and currentInventory[selectedIndex].name

	currentInventory = items
	currentInventoryCapacity = capacity or currentInventoryCapacity
	inventoryCount.Text = string.format("%d / %d", #items, currentInventoryCapacity)

	for _, child in ipairs(inventoryScroll:GetChildren()) do
		if not child:IsA("UIGridLayout") and not child:IsA("UIPadding") then child:Destroy() end
	end

	if #items == 0 then
		local empty = Instance.new("TextLabel")
		empty.Size = UDim2.new(1, 0, 0, 60)
		empty.BackgroundTransparency = 1
		empty.Text = "Nothing here yet — fuse something at your pad."
		empty.TextColor3 = DIM
		empty.Font = Enum.Font.FredokaOne
		empty.TextSize = 14
		empty.TextWrapped = true
		empty.Parent = inventoryScroll
	end

	local stillSelected = false
	for i, entry in ipairs(items) do
		if searchBox.Text ~= "" and not string.find(string.lower(entry.name),string.lower(searchBox.Text),1,true) then continue end
		local baseName, mutationId = Mutations.Unwrap(entry.name)
		local tintColor = Mutations.Color(mutationId)
		local rarityColor = tintColor or ItemRarity.Color(entry.tier, entry.isSecret)
		local isSelected = entry.index == selectedIndex and entry.name == previousSelectedName

		local card = Instance.new("TextButton")
		card.Size = inventoryLayout.CellSize
		card.LayoutOrder = i
		card.BackgroundColor3 = rarityColor:Lerp(Color3.fromRGB(18, 18, 24), 0.35)
		card.Text = ""
		card.AutoButtonColor = false
		card.BorderSizePixel = 0
		card.Parent = inventoryScroll
		rounded(card, 12)

		card:SetAttribute("Selected", isSelected)
		card:SetAttribute("Floating",true)
		card.BackgroundTransparency=1
		local stroke = Instance.new("UIStroke")
		stroke.Color = isSelected and Color3.fromRGB(255, 255, 255) or rarityColor
		stroke.Color=Color3.fromRGB(32,192,240)
		stroke.Thickness = isSelected and 3 or 0
		stroke.Transparency=isSelected and 0 or 1
		stroke.Parent = card

		buildItemViewport(card, baseName, tintColor)

		local nameLbl = Instance.new("TextLabel")
		nameLbl.Size = UDim2.new(1, -10, 0, 30)
		nameLbl.Position = UDim2.new(0, 5, 1, -34)
		nameLbl.BackgroundTransparency = 1
		nameLbl.Text = entry.name
		nameLbl.TextColor3 = Color3.fromRGB(255, 255, 255)
		nameLbl.TextStrokeTransparency = 0.4
		nameLbl.Font = Enum.Font.FredokaOne
		nameLbl.TextScaled = false
		nameLbl.TextSize=20
		nameLbl.TextWrapped = true
		nameLbl.Parent = card

		card.MouseButton1Click:Connect(function()
			showStatsFor(entry)
			redrawInventory(currentInventory, currentInventoryCapacity)
		end)

		if isSelected then stillSelected = true end
	end

	inventoryScroll.CanvasSize = UDim2.new(0, 0, 0, inventoryLayout.AbsoluteContentSize.Y + 10)

	if not stillSelected then
		showStatsFor(nil)
	end
end

function redrawPlaced(items, capacity)
	currentPlaced = items
	currentPlacedCapacity = capacity or currentPlacedCapacity
	placedLabel.Text = string.format("🐾 YOUR PETS — EARNING (%d / %d)", #items, currentPlacedCapacity)

	if selectedIndex then
		placeBtn.BackgroundColor3 = #currentPlaced >= currentPlacedCapacity and DIM or GREEN
	end

	for _, child in ipairs(placedRow:GetChildren()) do
		if not child:IsA("UIListLayout") and not child:IsA("UIPadding") then child:Destroy() end
	end

	for slot = 1, currentPlacedCapacity do
		local entry = items[slot]

		local card = Instance.new("TextButton")
		card.Size = UDim2.new(0.2, -12, 0, 142)
		card.LayoutOrder = slot
		card.Text = ""
		card.AutoButtonColor = false
		card.BorderSizePixel = 0
		card.Parent = placedRow

		if entry then
			card:SetAttribute("Floating",true)
			local baseName, mutationId = Mutations.Unwrap(entry.name)
			local tintColor = Mutations.Color(mutationId)
			local rarityColor = tintColor or ItemRarity.Color(entry.tier, entry.isSecret)
			card.BackgroundColor3 = rarityColor:Lerp(Color3.fromRGB(18, 18, 24), 0.3)
			rounded(card, 16)

			local stroke = Instance.new("UIStroke")
			stroke.Color = rarityColor
			stroke.Thickness = 3
			stroke.Parent = card

			buildItemViewport(card, baseName, tintColor)

			card.MouseButton1Click:Connect(function()
				unplacePetRemote:FireServer(slot)
			end)
		else
			card.BackgroundColor3 = UIStyle.Palette.Mint
			rounded(card, 16)

			local stroke = Instance.new("UIStroke")
			stroke.Color = Color3.fromRGB(70, 90, 78)
			stroke.Thickness = 2.5
			stroke.Parent = card

			local plus = label(card, "+", UDim2.new(1, 0, 1, 0), Color3.fromRGB(85, 110, 95), Enum.Font.LuckiestGuy, 36)
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
	-- it and toast "All 5 pads are full" so a stale-looking green button
	-- (pads filled by some other means since this panel last redrew) still
	-- gives the player feedback instead of silently doing nothing.
	if selectedIndex then placePetRemote:FireServer(selectedIndex) end
end)

local function toggleInventory()
	inventoryFrame.Visible = not inventoryFrame.Visible
end

searchBox:GetPropertyChangedSignal("Text"):Connect(function() redrawInventory(currentInventory,currentInventoryCapacity) end)
inventoryBtn.MouseButton1Click:Connect(toggleInventory)
inventoryClose.MouseButton1Click:Connect(toggleInventory)

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

local tradePickerLayout = Instance.new("UIListLayout")
tradePickerLayout.Padding = UDim.new(0, 6)
tradePickerLayout.Parent = tradePickerScroll

local function redrawTradePicker()
	for _, child in ipairs(tradePickerScroll:GetChildren()) do
		if not child:IsA("UIListLayout") then child:Destroy() end
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
		rowLabel.RichText = true
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
		nameLbl.Position = UDim2.new(0, 16, 0, 0)
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
	toast.Text = message
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
	banner.Text = message
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

local function redrawList(names)
	for _, child in ipairs(list:GetChildren()) do
		if child:IsA("TextLabel") then child:Destroy() end
	end

	for i, name in ipairs(names or {}) do
		local itemColor = ItemRarity.Color(FusionRecipes.GetTier(name), FusionRecipes.IsSecretResult(name))
		local entry = label(list, "• " .. name, UDim2.new(1, 0, 0, 20), itemColor, Enum.Font.FredokaOne, 13)
		entry.LayoutOrder = i
	end

	list.CanvasSize = UDim2.new(0, 0, 0, layout.AbsoluteContentSize.Y + 8)
end

remote.OnClientEvent:Connect(function(data)
	if data.announce then
		showAnnounce(data.announce)
		return
	end

	if data.toast then
		showToast(data.toast, data.big)
		return
	end

	if data.slots then
		redrawCarrySlots(data.slots, data.maxSlots)
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
		companionText.Text = equippedCompanion
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

	if data.goalText then
		objHeader.Text = string.format("OBJECTIVE %d / %d", data.goalNumber or 1, data.goalTotal or 9)
		objText.Text = data.goalText
		objReward.Text = (data.goalReward or 0) > 0
			and string.format("Reward: %d coins", data.goalReward)
			or ""
	end

	if data.luck then
		luckText.Text = "LUCK " .. tostring(data.luck)
	end

	if data.discoveredCount then
		header.Text = string.format("DISCOVERIES  %d / %d", data.discoveredCount, data.total or 0)
		secretLine.Text = string.format("Secrets  %d / %d", data.secretsFound or 0, data.secretTotal or 3)
		redrawList(data.list)
	end

	if data.index then
		indexData.junkyard = data.index
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
	local row = Instance.new("TextButton")
	row.Size = UDim2.new(1, -6, 0, 220)
	row.BackgroundColor3 = world.gradientColors[1]
	row.AutoButtonColor = false
	row.Text = ""
	row.BorderSizePixel = 0
	row.ClipsDescendants = true
	row.Parent = travelScroll
	rounded(row, 20)

	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new(world.gradientColors[1], world.gradientColors[2])
	gradient.Rotation = 20
	gradient.Parent = row

	-- Giant emoji badge, oversized and cropped by the card so it reads as
	-- a bold graphic rather than a tiny icon.
	local emojiBadge = Instance.new("TextLabel")
	emojiBadge.Size = UDim2.new(0, 260, 0, 260)
	emojiBadge.Position = UDim2.new(0, -40, 0.5, -130)
	emojiBadge.BackgroundTransparency = 1
	emojiBadge.Text = world.emoji
	emojiBadge.Font = Enum.Font.LuckiestGuy
	emojiBadge.TextSize = 150
	emojiBadge.TextTransparency = 0.06
	emojiBadge.TextStrokeTransparency = 0.75
	emojiBadge.Rotation = -8
	emojiBadge.Parent = row

	local nameLabel = label(row, world.name, UDim2.new(1, -280, 0, 44), Color3.fromRGB(255, 255, 255), Enum.Font.LuckiestGuy, 34)
	nameLabel.Position = UDim2.new(0, 200, 0, 34)
	nameLabel.TextStrokeTransparency = 0.55

	local blurbLabel = label(row, world.blurb, UDim2.new(1, -300, 0, 40), Color3.fromRGB(255, 255, 255), Enum.Font.FredokaOne, 16)
	blurbLabel.Position = UDim2.new(0, 200, 0, 82)
	blurbLabel.TextWrapped = true
	blurbLabel.TextTransparency = 0.05
	blurbLabel.TextStrokeTransparency = 0.65

	local goPill = Instance.new("Frame")
	goPill.Size = UDim2.new(0, 200, 0, 42)
	goPill.Position = UDim2.new(0, 200, 1, -62)
	goPill.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	goPill.BorderSizePixel = 0
	goPill.Parent = row
	rounded(goPill, 21)

	local goLabel = label(goPill, "TAP TO TRAVEL  →", UDim2.new(1, 0, 1, 0), world.gradientColors[2], Enum.Font.LuckiestGuy, 15)
	goLabel.TextXAlignment = Enum.TextXAlignment.Center

	row.MouseButton1Click:Connect(function()
		travelRemote:FireServer(world.key)
		toggleTravel()
	end)
end

for _, world in ipairs(WORLDS) do
	buildWorldRow(world)
end

-- Apply presentation after construction; future inventory/reward rows inherit it.
UIStyle.Attach(gui)