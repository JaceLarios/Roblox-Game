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

local FusionRecipes = require(ReplicatedStorage:WaitForChild("FusionRecipes"))
local BrainrotRecipes = require(ReplicatedStorage:WaitForChild("BrainrotRecipes"))
local ItemRarity = require(ReplicatedStorage:WaitForChild("ItemRarity"))

local DARK   = Color3.fromRGB(18, 18, 22)
local GOLD   = Color3.fromRGB(255, 200, 80)
local LIGHT  = Color3.fromRGB(235, 235, 240)
local DIM    = Color3.fromRGB(120, 120, 132)

-- Glass look: panels let the world through, text stays fully opaque.
-- Readability comes from the stroke and the text contrast, not from
-- a solid fill.
local GLASS_PANEL = 0.35   -- big modals
local GLASS_HUD   = 0.28   -- always-on HUD cards

local gui = Instance.new("ScreenGui")
gui.Name = "JunkyardUI"
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
rounded(objCard)

local objStripe = Instance.new("Frame")
objStripe.Size = UDim2.new(0, 5, 1, -16)
objStripe.Position = UDim2.new(0, 8, 0, 8)
objStripe.BackgroundColor3 = GOLD
objStripe.BorderSizePixel = 0
objStripe.Parent = objCard
rounded(objStripe, 3)

local objHeader = label(objCard, "OBJECTIVE 1 / 9", UDim2.new(1, -30, 0, 20), GOLD, Enum.Font.FredokaOne, 12)
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
coinCard.Size = UDim2.new(0, 300, 0, 52)
coinCard.Position = UDim2.new(0, 20, 0, 122)
coinCard.BackgroundColor3 = DARK
coinCard.BackgroundTransparency = GLASS_HUD
coinCard.BorderSizePixel = 0
coinCard.Parent = gui
rounded(coinCard)

local coinIcon = Instance.new("Frame")
coinIcon.Size = UDim2.new(0, 22, 0, 22)
coinIcon.Position = UDim2.new(0, 14, 0, 15)
coinIcon.BackgroundColor3 = GOLD
coinIcon.BorderSizePixel = 0
coinIcon.Parent = coinCard
rounded(coinIcon, 11)

local coinText = label(coinCard, "0", UDim2.new(1, -50, 1, 0), GOLD, Enum.Font.LuckiestGuy, 24)
coinText.Position = UDim2.new(0, 46, 0, 0)

local luckText = label(coinCard, "LUCK 1", UDim2.new(0, 90, 0, 18), DIM, Enum.Font.FredokaOne, 12)
luckText.Position = UDim2.new(1, -96, 0, 17)
luckText.TextXAlignment = Enum.TextXAlignment.Right

local function commas(n)
	local formatted = tostring(n)
	while true do
		local replaced
		formatted, replaced = formatted:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
		if replaced == 0 then break end
	end
	return formatted
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
		coinText.TextSize = 30
		TweenService:Create(coinText, TweenInfo.new(0.25), { TextSize = 24 }):Play()
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

-- Always-present side tab. Sits on the left edge at mid-height so it
-- never collides with the objective stack up top.
local dailyBtn = Instance.new("TextButton")
dailyBtn.Size = UDim2.new(0, 82, 0, 82)
dailyBtn.Position = UDim2.new(0, 20, 0.5, -41)
dailyBtn.BackgroundColor3 = Color3.fromRGB(38, 38, 46)
dailyBtn.Text = ""
dailyBtn.AutoButtonColor = false
dailyBtn.BorderSizePixel = 0
dailyBtn.Parent = gui
rounded(dailyBtn, 14)

local dailyBtnGradient = Instance.new("UIGradient")
dailyBtnGradient.Color = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(56, 56, 68)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(30, 30, 38)),
})
dailyBtnGradient.Rotation = 90
dailyBtnGradient.Parent = dailyBtn

local dailyBtnStroke = Instance.new("UIStroke")
dailyBtnStroke.Color = Color3.fromRGB(90, 90, 108)
dailyBtnStroke.Thickness = 2
dailyBtnStroke.Transparency = 0.4
dailyBtnStroke.Parent = dailyBtn

local dailyIcon = label(dailyBtn, "🎁", UDim2.new(1, 0, 0, 32), Color3.fromRGB(255, 255, 255), Enum.Font.FredokaOne, 28)
dailyIcon.Position = UDim2.new(0, 0, 0, 10)
dailyIcon.TextXAlignment = Enum.TextXAlignment.Center

local dailyCaption = label(dailyBtn, "REWARDS", UDim2.new(1, 0, 0, 16), Color3.fromRGB(150, 150, 170), Enum.Font.FredokaOne, 13)
dailyCaption.Position = UDim2.new(0, 0, 0, 44)
dailyCaption.TextXAlignment = Enum.TextXAlignment.Center

local dailyStatus = label(dailyBtn, "", UDim2.new(1, -6, 0, 14), Color3.fromRGB(120, 120, 140), Enum.Font.FredokaOne, 10)
dailyStatus.Position = UDim2.new(0, 3, 0, 60)
dailyStatus.TextXAlignment = Enum.TextXAlignment.Center
dailyStatus.TextScaled = true

-- Red dot, only when there's something to collect.
local dailyBadge = Instance.new("Frame")
dailyBadge.Size = UDim2.new(0, 20, 0, 20)
dailyBadge.Position = UDim2.new(1, -9, 0, -9)
dailyBadge.BackgroundColor3 = Color3.fromRGB(235, 70, 70)
dailyBadge.BorderSizePixel = 0
dailyBadge.Visible = false
dailyBadge.ZIndex = 3
dailyBadge.Parent = dailyBtn
rounded(dailyBadge, 10)

local badgeMark = label(dailyBadge, "!", UDim2.new(1, 0, 1, 0), Color3.fromRGB(255, 255, 255), Enum.Font.LuckiestGuy, 13)
badgeMark.TextXAlignment = Enum.TextXAlignment.Center
badgeMark.ZIndex = 4

dailyBtn.MouseEnter:Connect(function()
	TweenService:Create(dailyBtn, TweenInfo.new(0.12), { Size = UDim2.new(0, 88, 0, 88) }):Play()
end)

dailyBtn.MouseLeave:Connect(function()
	TweenService:Create(dailyBtn, TweenInfo.new(0.12), { Size = UDim2.new(0, 82, 0, 82) }):Play()
end)

-- Dimmed backdrop
local dimmer = Instance.new("TextButton")
dimmer.Size = UDim2.new(1, 0, 1, 0)
dimmer.BackgroundColor3 = Color3.fromRGB(0, 0, 0)
dimmer.BackgroundTransparency = 0.35
dimmer.Text = ""
dimmer.AutoButtonColor = false
dimmer.BorderSizePixel = 0
dimmer.Visible = false
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
streakPill.Position = UDim2.new(1, -170, 0, 30)
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
dailyClose.Size = UDim2.new(0, 32, 0, 32)
dailyClose.Position = UDim2.new(1, -46, 0, 74)
dailyClose.BackgroundTransparency = 1
dailyClose.Text = "✕"
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
	dailyFrame.Position = UDim2.new(0.5, -280, 0.5, -220)
	TweenService:Create(dailyFrame, TweenInfo.new(0.28, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Size = UDim2.new(0, 600, 0, 470),
		Position = UDim2.new(0.5, -300, 0.5, -235),
	}):Play()
end

dailyClose.MouseButton1Click:Connect(closeDaily)
dimmer.MouseButton1Click:Connect(closeDaily)
dailyBtn.MouseButton1Click:Connect(openDaily)

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
rounded(panel)

local header = label(panel, "DISCOVERIES  0 / 0", UDim2.new(1, -20, 0, 34), GOLD, Enum.Font.FredokaOne, 15)
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

local carrying = Instance.new("TextLabel")
carrying.Size = UDim2.new(0, 470, 0, 40)
carrying.Position = UDim2.new(0.5, -235, 1, -74)
carrying.BackgroundColor3 = DARK
carrying.BackgroundTransparency = GLASS_HUD
carrying.Text = "CARRYING:  [ empty ]   +   [ empty ]"
carrying.TextColor3 = LIGHT
carrying.Font = Enum.Font.FredokaOne
carrying.TextSize = 15
carrying.BorderSizePixel = 0
carrying.RichText = true
carrying.Parent = gui
rounded(carrying)

------------------------------------------------------------------
-- Item index (press B) — every item in the game, colored by rarity,
-- showing what you have and haven't found yet.
------------------------------------------------------------------

local bookBtn = Instance.new("TextButton")
bookBtn.Size = UDim2.new(0, 150, 0, 34)
bookBtn.Position = UDim2.new(1, -170, 1, -74)
bookBtn.BackgroundColor3 = GOLD
bookBtn.Text = "📖  INDEX"
bookBtn.TextColor3 = DARK
bookBtn.Font = Enum.Font.LuckiestGuy
bookBtn.TextSize = 15
bookBtn.BorderSizePixel = 0
bookBtn.Parent = gui
rounded(bookBtn, 12)

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

local bookLayout = Instance.new("UIListLayout")
bookLayout.Padding = UDim.new(0, 10)
bookLayout.Parent = bookScroll

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

local function redrawIndex()
	for _, child in ipairs(bookScroll:GetChildren()) do
		if not child:IsA("UIListLayout") then child:Destroy() end
	end

	local onJunkyard = activeTab == "junkyard"
	tabJunkyard.BackgroundColor3 = onJunkyard and GOLD or Color3.fromRGB(50, 50, 58)
	tabJunkyard.TextColor3 = onJunkyard and DARK or LIGHT
	tabBrainrot.BackgroundColor3 = onJunkyard and Color3.fromRGB(50, 50, 58) or GOLD
	tabBrainrot.TextColor3 = onJunkyard and LIGHT or DARK

	local buckets = {}
	for _, key in ipairs(SECTION_ORDER) do buckets[key] = {} end
	for _, entry in ipairs(indexData[activeTab]) do
		local key = entry.isSecret and "secret" or entry.tier
		if buckets[key] then table.insert(buckets[key], entry) end
	end

	for _, key in ipairs(SECTION_ORDER) do
		local info = SECTION_INFO[key]
		local isActive = key == activeRarity
		rarityTabs[key].BackgroundColor3 = isActive and info.color or Color3.fromRGB(40, 40, 46)
		rarityTabs[key].TextColor3 = isActive and Color3.fromRGB(20, 20, 26) or LIGHT
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

	for i, entry in ipairs(bucket) do
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, -6, 0, 40)
		row.LayoutOrder = i
		row.BackgroundColor3 = info.color:Lerp(Color3.fromRGB(18, 18, 24), entry.known and 0.68 or 0.82)
		row.BorderSizePixel = 0
		row.Parent = bookScroll
		rounded(row, 9)

		-- Just the final name — collected or not. No ingredients, no
		-- arrows: this is a collection list, not a recipe book.
		local text = entry.known and ItemRarity.Tag(entry.name, entry.tier, entry.isSecret) or "???"

		local l = label(row, text, UDim2.new(1, -28, 1, 0), entry.known and LIGHT or DIM, Enum.Font.FredokaOne, 18)
		l.Position = UDim2.new(0, 16, 0, 0)
		l.TextXAlignment = Enum.TextXAlignment.Center
		l.RichText = true
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

local shopBtn = Instance.new("TextButton")
shopBtn.Size = UDim2.new(0, 150, 0, 34)
shopBtn.Position = UDim2.new(1, -170, 1, -114)
shopBtn.BackgroundColor3 = Color3.fromRGB(90, 200, 255)
shopBtn.Text = "UPGRADES  [U]"
shopBtn.TextColor3 = DARK
shopBtn.Font = Enum.Font.FredokaOne
shopBtn.TextSize = 13
shopBtn.BorderSizePixel = 0
shopBtn.Parent = gui
rounded(shopBtn)

local shopFrame = Instance.new("Frame")
shopFrame.Size = UDim2.new(0, 520, 0, 420)
shopFrame.Position = UDim2.new(0.5, -260, 0.5, -210)
shopFrame.BackgroundColor3 = DARK
shopFrame.BackgroundTransparency = GLASS_PANEL
shopFrame.BorderSizePixel = 0
shopFrame.Visible = false
shopFrame.Parent = gui
rounded(shopFrame, 10)

local shopTitle = label(shopFrame, "UPGRADES", UDim2.new(1, -30, 0, 30), Color3.fromRGB(90, 200, 255), Enum.Font.LuckiestGuy, 20)
shopTitle.Position = UDim2.new(0, 20, 0, 14)

local shopClose = Instance.new("TextButton")
shopClose.Size = UDim2.new(0, 30, 0, 30)
shopClose.Position = UDim2.new(1, -44, 0, 14)
shopClose.BackgroundTransparency = 1
shopClose.Text = "X"
shopClose.TextColor3 = DIM
shopClose.Font = Enum.Font.FredokaOne
shopClose.TextSize = 18
shopClose.Parent = shopFrame

local shopScroll = Instance.new("ScrollingFrame")
shopScroll.Size = UDim2.new(1, -40, 1, -70)
shopScroll.Position = UDim2.new(0, 20, 0, 54)
shopScroll.BackgroundTransparency = 1
shopScroll.BorderSizePixel = 0
shopScroll.ScrollBarThickness = 5
shopScroll.Parent = shopFrame

local shopLayout = Instance.new("UIListLayout")
shopLayout.Padding = UDim.new(0, 8)
shopLayout.Parent = shopScroll

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

local function redrawShop(shop)
	for _, child in ipairs(shopScroll:GetChildren()) do
		if not child:IsA("UIListLayout") then child:Destroy() end
	end

	for i, entry in ipairs(shop or {}) do
		local row = Instance.new("Frame")
		row.Size = UDim2.new(1, -6, 0, 78)
		row.LayoutOrder = i
		row.BackgroundColor3 = Color3.fromRGB(28, 28, 34)
		row.BackgroundTransparency = 0.2
		row.BorderSizePixel = 0
		row.Parent = shopScroll
		rounded(row, 6)

		local name = label(row, string.format("%s  —  Lv %d / %d", entry.name, entry.level, entry.max),
			UDim2.new(1, -160, 0, 22), LIGHT, Enum.Font.FredokaOne, 15)
		name.Position = UDim2.new(0, 14, 0, 10)

		local now = label(row, "Now: " .. entry.effect, UDim2.new(1, -160, 0, 18), DIM, Enum.Font.FredokaOne, 12)
		now.Position = UDim2.new(0, 14, 0, 32)

		if entry.nextEffect then
			local nxt = label(row, "Next: " .. entry.nextEffect, UDim2.new(1, -160, 0, 18),
				Color3.fromRGB(150, 220, 160), Enum.Font.FredokaOne, 12)
			nxt.Position = UDim2.new(0, 14, 0, 50)
		end

		local buy = Instance.new("TextButton")
		buy.Size = UDim2.new(0, 128, 0, 40)
		buy.Position = UDim2.new(1, -142, 0, 19)
		buy.BorderSizePixel = 0
		buy.Font = Enum.Font.FredokaOne
		buy.TextSize = 14
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

	shopScroll.CanvasSize = UDim2.new(0, 0, 0, shopLayout.AbsoluteContentSize.Y + 10)
end

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
		local parts = {}
		local maxSlots = data.maxSlots or 2
		for i = 1, maxSlots do
			local name = data.slots[i]
			if name then
				table.insert(parts, "[ " .. ItemRarity.Tag(name, FusionRecipes.GetTier(name), FusionRecipes.IsSecretResult(name)) .. " ]")
			else
				table.insert(parts, "[ empty ]")
			end
		end
		carrying.Text = "CARRYING:  " .. table.concat(parts, "  ")
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

-- Compact trigger button (right side, vertically centered).
local travelBtn = Instance.new("TextButton")
travelBtn.Size = UDim2.new(0, 150, 0, 46)
travelBtn.Position = UDim2.new(1, -170, 0.5, -23)
travelBtn.BackgroundColor3 = Color3.fromRGB(60, 230, 170)
travelBtn.Text = "🚀  TRAVEL"
travelBtn.TextColor3 = DARK
travelBtn.Font = Enum.Font.LuckiestGuy
travelBtn.TextSize = 18
travelBtn.BorderSizePixel = 0
travelBtn.Parent = gui
rounded(travelBtn, 12)

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
