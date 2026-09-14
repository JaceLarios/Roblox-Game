--[[
	FusionCelebration (LocalScript, StarterPlayerScripts) — Junkyard Fusion
	Big, screen-covering-but-not-total celebration animation + SFX shown
	whenever this player fuses two items. Deliberately its own standalone
	script listening to its own dedicated RemoteEvent (FusionCelebration,
	fired from PlotManager.server.luau's attemptFusion) rather than living
	inside GameUI/ShopUI or piggybacking on the small toast system — those
	two files are mid-rewrite by a separate tool, so this stays fully
	independent to avoid any collision with that work.
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local remote = ReplicatedStorage:WaitForChild("FusionCelebration")

-- Signature palette — kept as a local copy deliberately (see project
-- memory: these aren't shared via a module, every UI script defines its
-- own copy of the same values).
local WHITE = Color3.fromRGB(255, 255, 255)
local GOLD = Color3.fromRGB(255, 200, 80)
local CARD_BG = Color3.fromRGB(24, 22, 32)
local PILL_BG = Color3.fromRGB(0, 0, 0)

local SPARKLE_EMOJI = "✨" -- old, universally-supported (see the 🪙 rendering-gap lesson)

------------------------------------------------------------------
-- Static UI build (built once, hidden; each celebration just fills it in
-- and plays the show/hide tweens — avoids rebuilding instances per fuse).
------------------------------------------------------------------

local gui = Instance.new("ScreenGui")
gui.Name = "FusionCelebrationGui"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 100
gui.Parent = playerGui

local backdrop = Instance.new("Frame")
backdrop.Name = "Backdrop"
backdrop.Size = UDim2.fromScale(1, 1)
backdrop.BackgroundColor3 = Color3.new(0, 0, 0)
backdrop.BackgroundTransparency = 1
backdrop.BorderSizePixel = 0
backdrop.Visible = false
backdrop.ZIndex = 1
backdrop.Parent = gui

-- Card is sized to most of the screen but never edge-to-edge, so the HUD
-- around it (currency, nav rail) stays visible while this is up.
local card = Instance.new("Frame")
card.Name = "Card"
card.AnchorPoint = Vector2.new(0.5, 0.5)
card.Position = UDim2.fromScale(0.5, 0.48)
card.Size = UDim2.fromScale(0, 0)
card.BackgroundColor3 = CARD_BG
card.BorderSizePixel = 0
card.ZIndex = 2
card.Parent = backdrop

local cardCorner = Instance.new("UICorner")
cardCorner.CornerRadius = UDim.new(0, 32)
cardCorner.Parent = card

local cardStroke = Instance.new("UIStroke")
cardStroke.Thickness = 6
cardStroke.Color = WHITE
cardStroke.Parent = card

local strokeGradient = Instance.new("UIGradient")
strokeGradient.Color = ColorSequence.new(WHITE, WHITE)
strokeGradient.Parent = cardStroke

local cardPadding = Instance.new("UIPadding")
cardPadding.PaddingTop = UDim.new(0, 28)
cardPadding.PaddingBottom = UDim.new(0, 28)
cardPadding.PaddingLeft = UDim.new(0, 40)
cardPadding.PaddingRight = UDim.new(0, 40)
cardPadding.Parent = card

local layout = Instance.new("UIListLayout")
layout.FillDirection = Enum.FillDirection.Vertical
layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
layout.VerticalAlignment = Enum.VerticalAlignment.Center
layout.SortOrder = Enum.SortOrder.LayoutOrder
layout.Padding = UDim.new(0, 10)
layout.Parent = card

local function label(order, size, font, color, transparency)
	local lbl = Instance.new("TextLabel")
	lbl.BackgroundTransparency = 1
	lbl.Size = UDim2.new(1, 0, 0, size)
	lbl.Font = font
	lbl.TextColor3 = color
	lbl.TextTransparency = transparency or 0
	lbl.TextScaled = true
	lbl.RichText = true
	lbl.LayoutOrder = order
	lbl.ZIndex = 3
	lbl.Parent = card
	return lbl
end

local headerLabel = label(1, 34, Enum.Font.FredokaOne, GOLD)
local ingredientsLabel = label(2, 26, Enum.Font.FredokaOne, WHITE)
ingredientsLabel.TextTransparency = 0.15

local resultLabel = label(3, 78, Enum.Font.LuckiestGuy, WHITE)
resultLabel.Size = UDim2.new(1, 0, 0, 90)

local pill = Instance.new("Frame")
pill.BackgroundColor3 = PILL_BG
pill.BackgroundTransparency = 0.25
pill.Size = UDim2.new(0, 0, 0, 44)
pill.AutomaticSize = Enum.AutomaticSize.X
pill.LayoutOrder = 4
pill.ZIndex = 3
pill.Parent = card

local pillCorner = Instance.new("UICorner")
pillCorner.CornerRadius = UDim.new(1, 0)
pillCorner.Parent = pill

local pillPadding = Instance.new("UIPadding")
pillPadding.PaddingLeft = UDim.new(0, 28)
pillPadding.PaddingRight = UDim.new(0, 28)
pillPadding.Parent = pill

local rarityLabel = Instance.new("TextLabel")
rarityLabel.BackgroundTransparency = 1
rarityLabel.Size = UDim2.new(0, 0, 1, 0)
rarityLabel.AutomaticSize = Enum.AutomaticSize.X
rarityLabel.Font = Enum.Font.FredokaOne
rarityLabel.TextColor3 = WHITE
rarityLabel.TextScaled = true
rarityLabel.Size = UDim2.new(0, 200, 1, 0)
rarityLabel.Parent = pill

local rateLabel = label(5, 30, Enum.Font.FredokaOne, GOLD)

------------------------------------------------------------------
-- Floating sparkle decorations — same "drift forever, independently"
-- technique used for the Shop's gamepass banners, just written fresh here
-- since that code lives in a file this script deliberately doesn't touch.
------------------------------------------------------------------

local sparkles = {}
for i = 1, 10 do
	local spark = Instance.new("TextLabel")
	spark.BackgroundTransparency = 1
	spark.Text = SPARKLE_EMOJI
	spark.Font = Enum.Font.SourceSans
	spark.TextColor3 = WHITE
	spark.TextScaled = true
	spark.AnchorPoint = Vector2.new(0.5, 0.5)
	spark.Size = UDim2.fromOffset(24 + math.random(0, 20), 24 + math.random(0, 20))
	spark.Position = UDim2.fromScale(math.random(0, 100) / 100, math.random(0, 100) / 100)
	spark.Rotation = math.random(0, 360)
	spark.ZIndex = 2
	spark.Parent = backdrop
	table.insert(sparkles, spark)

	local tween = TweenService:Create(spark,
		TweenInfo.new(1.4 + math.random() * 1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Position = spark.Position + UDim2.fromScale(0, 0.04), Rotation = spark.Rotation + 25 })
	tween:Play()
end

------------------------------------------------------------------
-- Sound — non-positional (parented to SoundService, not a world part) so
-- it's always clearly audible regardless of camera angle, using the same
-- confirmed-valid rbxasset ids the server already plays at the pad.
------------------------------------------------------------------

local function playUiSound(id, pitch, volume, delaySeconds)
	task.delay(delaySeconds or 0, function()
		local sound = Instance.new("Sound")
		sound.SoundId = id
		sound.PlaybackSpeed = pitch
		sound.Volume = volume
		sound.Parent = SoundService
		sound:Play()
		sound.Ended:Connect(function() sound:Destroy() end)
		task.delay(5, function() if sound.Parent then sound:Destroy() end end)
	end)
end

------------------------------------------------------------------
-- Show / hide, queued so back-to-back fusions never overlap two half
-- animated cards.
------------------------------------------------------------------

local queue = {}
local playing = false

local SHOW_TIME = 0.45
local HOLD_TIME = 2.6
local HIDE_TIME = 0.3

local function playOne(data)
	headerLabel.Text = data.headerText or "FUSION COMPLETE"
	ingredientsLabel.Text = string.format("%s  +  %s", data.aTag or "", data.bTag or "")
	resultLabel.Text = data.resultTag or ""
	rarityLabel.Text = data.rarityName or ""
	rateLabel.Text = data.rateLine or ""

	local color = data.color or GOLD
	cardStroke.Color = color
	strokeGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, WHITE),
		ColorSequenceKeypoint.new(0.5, color),
		ColorSequenceKeypoint.new(1, WHITE),
	})
	pill.BackgroundColor3 = color
	pill.BackgroundTransparency = 0.1
	rarityLabel.TextColor3 = WHITE

	backdrop.Visible = true
	backdrop.BackgroundTransparency = 1
	card.Size = UDim2.fromScale(0, 0)

	TweenService:Create(backdrop, TweenInfo.new(SHOW_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ BackgroundTransparency = 0.55 }):Play()
	TweenService:Create(card, TweenInfo.new(SHOW_TIME, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Size = UDim2.fromScale(0.66, 0.56) }):Play()

	-- A slow rotating gradient on the border for a shimmering "magic" feel
	-- while the card is up.
	local rotateTween = TweenService:Create(strokeGradient,
		TweenInfo.new(2.2, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1, false),
		{ Rotation = 360 })
	rotateTween:Play()

	playUiSound("rbxasset://sounds/electronicpingshort.wav", 0.9, 0.55, 0)
	playUiSound("rbxasset://sounds/bass.wav", 1.0, 0.8, 0.05)

	task.wait(SHOW_TIME + HOLD_TIME)

	rotateTween:Cancel()
	TweenService:Create(backdrop, TweenInfo.new(HIDE_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ BackgroundTransparency = 1 }):Play()
	local shrink = TweenService:Create(card, TweenInfo.new(HIDE_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ Size = UDim2.fromScale(0, 0) })
	shrink:Play()
	shrink.Completed:Wait()
	backdrop.Visible = false
end

local function processQueue()
	if playing then return end
	playing = true
	while #queue > 0 do
		local data = table.remove(queue, 1)
		playOne(data)
	end
	playing = false
end

remote.OnClientEvent:Connect(function(data)
	if type(data) ~= "table" then return end
	-- Cap the queue so a spam-fusing session can't pile up a long backlog
	-- of cards to play through after the player's stopped fusing.
	if #queue >= 3 then table.remove(queue, 1) end
	table.insert(queue, data)
	task.spawn(processQueue)
end)
