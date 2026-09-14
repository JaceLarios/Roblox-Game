--[[
	FusionCelebrationView (ModuleScript, StarterPlayerScripts) — Junkyard Fusion

	ALL visual design for the fusion celebration lives here: layout,
	colors, fonts, card shape, decorations, motion/easing, hold duration,
	sound choices and timing feel. This is the Codex-owned half — redesign
	this file as freely as you want, including completely replacing how
	View.Play builds and animates things, as long as the one contract
	below still holds.

	The controller, FusionCelebration.client.luau (a sibling script, not
	this one), only ever calls one thing:

		View.Play(data)

	It must SHOW the celebration and only RETURN once it's fully done
	(shown, held, and hidden again) — the controller uses that to know
	when it's safe to play the next queued fusion. Everything about how
	long that takes, what it looks like, and how it moves is entirely up
	to this module.

	`data` (sent by PlotManager.server.luau's attemptFusion over the
	FusionCelebration RemoteEvent) is a plain table:
		headerText   - string, e.g. "NEW DISCOVERY", "FUSION COMPLETE"
		aTag, bTag   - strings, the two ingredient names (RichText, already
		               rarity-colored via ItemRarity.Tag)
		resultTag    - string, the fused result's name (RichText, colored)
		rarityName   - string, e.g. "RARE", "SECRET"
		color        - Color3, the result's rarity/mutation color
		rateLine     - string, e.g. "RARE — +2.3 coins/sec if placed"

	Everything below this point is a working placeholder (ported from an
	earlier single-file version), not a final design — it exists so the
	feature is testable end-to-end before a real visual pass.
--]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local SoundService = game:GetService("SoundService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local WHITE = Color3.fromRGB(255, 255, 255)
local GOLD = Color3.fromRGB(255, 200, 80)
local CARD_BG = Color3.fromRGB(24, 22, 32)
local PILL_BG = Color3.fromRGB(0, 0, 0)
local SPARKLE_EMOJI = "✨"

local SHOW_TIME = 0.45
local HOLD_TIME = 2.6
local HIDE_TIME = 0.3

local View = {}

local ui -- built lazily on first Play call, reused after that

local function label(parent, order, size, font, color)
	local lbl = Instance.new("TextLabel")
	lbl.BackgroundTransparency = 1
	lbl.Size = UDim2.new(1, 0, 0, size)
	lbl.Font = font
	lbl.TextColor3 = color
	lbl.TextScaled = true
	lbl.RichText = true
	lbl.LayoutOrder = order
	lbl.ZIndex = 3
	lbl.Parent = parent
	return lbl
end

local function build()
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

	local headerLabel = label(card, 1, 34, Enum.Font.FredokaOne, GOLD)
	local ingredientsLabel = label(card, 2, 26, Enum.Font.FredokaOne, WHITE)
	ingredientsLabel.TextTransparency = 0.15

	local resultLabel = label(card, 3, 78, Enum.Font.LuckiestGuy, WHITE)
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
	rarityLabel.Font = Enum.Font.FredokaOne
	rarityLabel.TextColor3 = WHITE
	rarityLabel.TextScaled = true
	rarityLabel.Size = UDim2.new(0, 200, 1, 0)
	rarityLabel.Parent = pill

	local rateLabel = label(card, 5, 30, Enum.Font.FredokaOne, GOLD)

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

		local tween = TweenService:Create(spark,
			TweenInfo.new(1.4 + math.random() * 1.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
			{ Position = spark.Position + UDim2.fromScale(0, 0.04), Rotation = spark.Rotation + 25 })
		tween:Play()
	end

	return {
		backdrop = backdrop,
		card = card,
		cardStroke = cardStroke,
		strokeGradient = strokeGradient,
		headerLabel = headerLabel,
		ingredientsLabel = ingredientsLabel,
		resultLabel = resultLabel,
		rarityLabel = rarityLabel,
		ratePill = pill,
		rateLabel = rateLabel,
	}
end

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

function View.Play(data)
	ui = ui or build()

	ui.headerLabel.Text = data.headerText or "FUSION COMPLETE"
	ui.ingredientsLabel.Text = string.format("%s  +  %s", data.aTag or "", data.bTag or "")
	ui.resultLabel.Text = data.resultTag or ""
	ui.rarityLabel.Text = data.rarityName or ""
	ui.rateLabel.Text = data.rateLine or ""

	local color = data.color or GOLD
	ui.cardStroke.Color = color
	ui.strokeGradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, WHITE),
		ColorSequenceKeypoint.new(0.5, color),
		ColorSequenceKeypoint.new(1, WHITE),
	})
	ui.ratePill.BackgroundColor3 = color
	ui.ratePill.BackgroundTransparency = 0.1

	ui.backdrop.Visible = true
	ui.backdrop.BackgroundTransparency = 1
	ui.card.Size = UDim2.fromScale(0, 0)

	TweenService:Create(ui.backdrop, TweenInfo.new(SHOW_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
		{ BackgroundTransparency = 0.55 }):Play()
	TweenService:Create(ui.card, TweenInfo.new(SHOW_TIME, Enum.EasingStyle.Back, Enum.EasingDirection.Out),
		{ Size = UDim2.fromScale(0.66, 0.56) }):Play()

	local rotateTween = TweenService:Create(ui.strokeGradient,
		TweenInfo.new(2.2, Enum.EasingStyle.Linear, Enum.EasingDirection.InOut, -1, false),
		{ Rotation = 360 })
	rotateTween:Play()

	playUiSound("rbxasset://sounds/electronicpingshort.wav", 0.9, 0.55, 0)
	playUiSound("rbxasset://sounds/bass.wav", 1.0, 0.8, 0.05)

	task.wait(SHOW_TIME + HOLD_TIME)

	rotateTween:Cancel()
	TweenService:Create(ui.backdrop, TweenInfo.new(HIDE_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ BackgroundTransparency = 1 }):Play()
	local shrink = TweenService:Create(ui.card, TweenInfo.new(HIDE_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ Size = UDim2.fromScale(0, 0) })
	shrink:Play()
	shrink.Completed:Wait()
	ui.backdrop.Visible = false
end

return View
