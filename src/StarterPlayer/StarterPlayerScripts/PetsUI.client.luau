--[[
	PetsUI (LocalScript, StarterPlayerScripts) — Junkyard Fusion v1

	Lets a player equip one owned AreaPets egg pet to follow them (see
	PlotManager.server.luau's AreaPetsService wiring and
	updateEquippedPetVisual). Deliberately a brand-new, fully
	self-contained script — its own nav button (left rail, slot 4) and its
	own modal — rather than another section bolted onto
	GameUI.client.luau, so this never touches (or conflicts with)
	whatever Codex is mid-pass on in that file. Same reasoning
	ShopUI.client.luau already uses for its own nav button.

	Pet catalog data (name, area, tier, multipliers) comes straight from
	AreaPets.luau, required directly — same as FusionRecipes/
	BrainrotRecipes already are elsewhere — rather than resent over the
	wire. Only which keys are OWNED and which one is EQUIPPED come from
	the server, via the existing GameUpdate payload's ownedAreaPets/
	equippedAreaPet fields.

	This tab shows ONLY pets the player actually owns — never a browsable
	catalog of everything. That was an explicit correction, not a
	preference: "its not an index it should onl whow the pets i have
	bought from the eggs or from the store it shouldnt show anything else."
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local gui = player:WaitForChild("PlayerGui"):WaitForChild("JunkyardUI")

local NavButton = require(ReplicatedStorage:WaitForChild("NavButton"))
local UIStyle = require(ReplicatedStorage:WaitForChild("UIStyle"))
local AreaPets = require(ReplicatedStorage:WaitForChild("AreaPets"))

local updateRemote = ReplicatedStorage:WaitForChild("GameUpdate")
local equipRemote = ReplicatedStorage:WaitForChild("EquipAreaPet")

local Palette = UIStyle.Palette

local AREA_TABS = {
	{ key = "junkyard", label = "JUNKYARD", accent = Palette.Copper },
	{ key = "brainrot", label = "BRAINROT", accent = Palette.Mint },
	{ key = "haunted", label = "HAUNTED", accent = Palette.Steel },
	-- The paid pets (SecretPets.luau) belong to no one area, so they get
	-- their own tab. AreaPets folds them into its catalog as the "secret"
	-- area, which is all the rest of this file needs to list them.
	{ key = "secret", label = "SECRET", accent = Palette.Gold },
}

local TIER_ACCENTS = { okay = Palette.Steel, good = Palette.Teal, great = Palette.Gold }

local ownedAreaPets = {}
local equippedPetKey = nil
local selectedArea = "junkyard"

-- Style.Attach repaints any TextLabel/Frame it doesn't consider "Designed",
-- which would flatten every accent colour below back to the default theme.
-- Everything this file colours on purpose gets marked so the shim skips it.
local function designed(object)
	object:SetAttribute("Designed", true)
	return object
end

local function corner(object, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = object
	return c
end

local function stroke(object, color, thickness)
	local s = Instance.new("UIStroke")
	s.Color = color
	s.Thickness = thickness
	s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Parent = object
	return s
end

local function label(parent, text, size, position, color, font, textSize)
	local lbl = Instance.new("TextLabel")
	lbl.BackgroundTransparency = 1
	lbl.Size = size
	lbl.Position = position
	lbl.Text = text
	lbl.TextColor3 = color or Palette.Ink
	lbl.Font = font or Enum.Font.FredokaOne
	lbl.TextSize = textSize or 20
	lbl.TextScaled = false
	lbl.Parent = parent
	return designed(lbl)
end

------------------------------------------------------------------
-- Nav button
------------------------------------------------------------------

local petsBtn = NavButton.Create(gui, "🐾", "PETS", Palette.Mint, NavButton.RailPosition("left", 4))

-- The Pets egg, drawn to match the shared illustrated atlas rather than taken
-- from it: every one of that atlas's nine cells is already spoken for, and
-- "PETS" would otherwise land on the same cell as REWARDS/CODE (see
-- UIStyle.luau's `cells` table). Repointing NavButton's own Illustration label
-- instead of overlaying a second element keeps this icon at the exact size,
-- position and ScaleType as every other button on the rail. Clearing
-- ImageRectSize is what stops it still being cropped to an atlas cell.
local PETS_ICON = "rbxassetid://98114882060104"
local art = petsBtn:FindFirstChild("Illustration")
if art then
	art.Image = PETS_ICON
	art.ImageRectOffset = Vector2.zero
	art.ImageRectSize = Vector2.zero
end

-- A press bounce, so the rail reacts to the click the way the panel does.
local btnScale = Instance.new("UIScale")
btnScale.Parent = petsBtn

------------------------------------------------------------------
-- Panel shell
------------------------------------------------------------------

local petsBackdrop = designed(Instance.new("Frame"))
petsBackdrop.Name = "PetsBackdrop"
petsBackdrop.Size = UDim2.fromScale(1, 1)
petsBackdrop.BackgroundColor3 = Color3.new(0, 0, 0)
petsBackdrop.BackgroundTransparency = 1
petsBackdrop.BorderSizePixel = 0
petsBackdrop.Visible = false
petsBackdrop.ZIndex = 9
petsBackdrop.Parent = gui

local petsFrame = Instance.new("Frame")
petsFrame.Name = "PetsFrame"
petsFrame.Visible = false
petsFrame.BackgroundColor3 = Palette.Cream
-- Deliberately NOT clipping: UIStyle.Close parks the X button above the
-- panel's own top edge, and clipping here lops half of it off.
petsFrame.Parent = gui
UIStyle.Fit(petsFrame, 980, 660)
UIStyle.Surface(petsFrame, Palette.Cream, 4)
corner(petsFrame, 22)

local fitScale = petsFrame:FindFirstChildOfClass("UIScale")
local RESTING_Y = petsFrame.Position.Y.Scale

-- Coloured header band. A second square-cornered strip covers the band's own
-- lower corners so it meets the panel body flush instead of showing a notch.
local headerBand = designed(Instance.new("Frame"))
headerBand.Name = "Header"
headerBand.Size = UDim2.new(1, 0, 0, 108)
headerBand.BackgroundColor3 = Palette.Copper
headerBand.BorderSizePixel = 0
headerBand.ZIndex = 2
headerBand.Parent = petsFrame
corner(headerBand, 22)

local headerFoot = designed(Instance.new("Frame"))
headerFoot.Size = UDim2.new(1, 0, 0, 26)
headerFoot.Position = UDim2.new(0, 0, 1, -26)
headerFoot.BackgroundColor3 = Palette.Copper
headerFoot.BorderSizePixel = 0
headerFoot.ZIndex = 2
headerFoot.Parent = headerBand

local headerRule = designed(Instance.new("Frame"))
headerRule.Size = UDim2.new(1, 0, 0, 4)
headerRule.Position = UDim2.new(0, 0, 1, -4)
headerRule.BackgroundColor3 = Palette.Ink
headerRule.BorderSizePixel = 0
headerRule.ZIndex = 3
headerRule.Parent = headerBand

local titleLabel = label(headerBand, "PETS", UDim2.new(0, 400, 0, 52), UDim2.new(0, 34, 0, 16),
	Palette.Cream, Enum.Font.LuckiestGuy, 44)
titleLabel.TextXAlignment = Enum.TextXAlignment.Left
titleLabel.ZIndex = 4
UIStyle.Outline(titleLabel, 44)

local counterLabel = label(headerBand, "", UDim2.new(0, 400, 0, 24), UDim2.new(0, 36, 0, 68),
	Palette.Cream, Enum.Font.FredokaOne, 17)
counterLabel.TextXAlignment = Enum.TextXAlignment.Left
counterLabel.ZIndex = 4

local closeBtn = Instance.new("TextButton")
closeBtn.Parent = petsFrame
UIStyle.Close(closeBtn)

------------------------------------------------------------------
-- Area tabs
------------------------------------------------------------------

local tabRow = designed(Instance.new("Frame"))
tabRow.BackgroundTransparency = 1
tabRow.Size = UDim2.new(1, -68, 0, 54)
tabRow.Position = UDim2.new(0, 34, 0, 128)
tabRow.ZIndex = 3
tabRow.Parent = petsFrame

local tabLayout = Instance.new("UIListLayout")
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.Padding = UDim.new(0, 12)
-- Explicit, because UIListLayout otherwise sorts by Name and the tabs carry
-- per-area names — which silently reordered them alphabetically.
tabLayout.SortOrder = Enum.SortOrder.LayoutOrder
tabLayout.Parent = tabRow

local tabButtons = {}

------------------------------------------------------------------
-- Scrollable owned-pet list
------------------------------------------------------------------

local scroll = designed(Instance.new("ScrollingFrame"))
scroll.Size = UDim2.new(1, -68, 1, -220)
scroll.Position = UDim2.new(0, 34, 0, 198)
scroll.BackgroundTransparency = 1
scroll.BorderSizePixel = 0
scroll.ScrollBarThickness = 8
scroll.ScrollBarImageColor3 = Palette.Steel
scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
scroll.ZIndex = 3
scroll.Parent = petsFrame

local scrollLayout = Instance.new("UIListLayout")
scrollLayout.Padding = UDim.new(0, 22)
-- Sections carry LayoutOrder = egg.tier so they read Okay -> Good -> Great.
scrollLayout.SortOrder = Enum.SortOrder.LayoutOrder
scrollLayout.Parent = scroll
scrollLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
	scroll.CanvasSize = UDim2.new(0, 0, 0, scrollLayout.AbsoluteContentSize.Y + 18)
end)

local function statChip(parent, text, fill, order)
	local chip = designed(Instance.new("Frame"))
	chip.Size = UDim2.new(0, 92, 0, 26)
	chip.BackgroundColor3 = fill
	chip.BorderSizePixel = 0
	chip.LayoutOrder = order
	chip.ZIndex = 5
	chip.Parent = parent
	corner(chip, 999)
	stroke(chip, Palette.Ink, 2)

	local txt = label(chip, text, UDim2.fromScale(1, 1), UDim2.fromScale(0, 0),
		Palette.Ink, Enum.Font.FredokaOne, 13)
	txt.ZIndex = 6
	return chip
end

local function buildPetCard(parent, pet, accent)
	local isEquipped = equippedPetKey == pet.key

	local card = designed(Instance.new("TextButton"))
	card.Size = UDim2.new(0, 208, 0, 208)
	card.AutoButtonColor = false
	card.Text = ""
	card.BackgroundColor3 = Palette.Cream
	card.BorderSizePixel = 0
	card.ClipsDescendants = true
	card.ZIndex = 4
	card.Parent = parent
	corner(card, 16)
	stroke(card, isEquipped and Palette.Mint or Palette.Ink, isEquipped and 5 or 3)

	-- Tier strip: the card's loudest signal of which egg this came out of.
	local strip = designed(Instance.new("Frame"))
	strip.Size = UDim2.new(1, 0, 0, 46)
	strip.BackgroundColor3 = accent
	strip.BorderSizePixel = 0
	strip.ZIndex = 5
	strip.Parent = card

	local stripText = label(strip, pet.secret and "★ SECRET" or "PET",
		UDim2.new(1, -20, 1, 0), UDim2.new(0, 12, 0, 0),
		Palette.Ink, Enum.Font.FredokaOne, 16)
	stripText.TextXAlignment = Enum.TextXAlignment.Left
	stripText.ZIndex = 6

	local nameLbl = label(card, pet.name, UDim2.new(1, -24, 0, 50), UDim2.new(0, 12, 0, 56),
		Palette.Ink, Enum.Font.FredokaOne, 16)
	nameLbl.TextWrapped = true
	nameLbl.TextXAlignment = Enum.TextXAlignment.Left
	nameLbl.TextYAlignment = Enum.TextYAlignment.Top
	nameLbl.ZIndex = 5

	local chipRow = designed(Instance.new("Frame"))
	chipRow.BackgroundTransparency = 1
	chipRow.Size = UDim2.new(1, -24, 0, 26)
	chipRow.Position = UDim2.new(0, 12, 0, 114)
	chipRow.ZIndex = 5
	chipRow.Parent = card

	local chipLayout = Instance.new("UIListLayout")
	chipLayout.FillDirection = Enum.FillDirection.Horizontal
	chipLayout.Padding = UDim.new(0, 8)
	chipLayout.SortOrder = Enum.SortOrder.LayoutOrder
	chipLayout.Parent = chipRow

	statChip(chipRow, string.format("+%d%% COINS", math.floor((pet.coinMult - 1) * 100 + 0.5)), Palette.Gold, 1)
	statChip(chipRow, string.format("+%d%% SPEED", math.floor((pet.speedMult - 1) * 100 + 0.5)), Palette.Mint, 2)

	local action = designed(Instance.new("TextButton"))
	action.Size = UDim2.new(1, -24, 0, 40)
	action.Position = UDim2.new(0, 12, 1, -52)
	action.AutoButtonColor = false
	action.BackgroundColor3 = isEquipped and Palette.Mint or Palette.Ink
	action.BorderSizePixel = 0
	action.Text = isEquipped and "EQUIPPED" or "EQUIP"
	action.TextColor3 = isEquipped and Palette.Ink or Palette.Cream
	action.Font = Enum.Font.FredokaOne
	action.TextSize = 17
	action.ZIndex = 5
	action.Parent = card
	corner(action, 10)
	stroke(action, Palette.Ink, 2)

	local function equip()
		equipRemote:FireServer(pet.key)
	end
	card.MouseButton1Click:Connect(equip)
	action.MouseButton1Click:Connect(equip)

	return card
end

local function buildEmptyState()
	local empty = designed(Instance.new("Frame"))
	empty.BackgroundColor3 = Color3.fromRGB(244, 238, 226)
	empty.BorderSizePixel = 0
	empty.Size = UDim2.new(1, -12, 0, 190)
	empty.LayoutOrder = 99
	empty.ZIndex = 4
	empty.Parent = scroll
	corner(empty, 16)
	stroke(empty, Palette.Steel, 3)

	local mark = designed(Instance.new("ImageLabel"))
	mark.Size = UDim2.fromOffset(74, 74)
	mark.AnchorPoint = Vector2.new(0.5, 0)
	mark.Position = UDim2.new(0.5, 0, 0, 22)
	mark.BackgroundTransparency = 1
	mark.Image = PETS_ICON
	mark.ImageTransparency = 0.25
	mark.ScaleType = Enum.ScaleType.Fit
	mark.ZIndex = 5
	mark.Parent = empty

	local msg = label(empty, "No pets from this area yet", UDim2.new(1, -40, 0, 26),
		UDim2.new(0, 20, 0, 106), Palette.Ink, Enum.Font.FredokaOne, 20)
	msg.TextXAlignment = Enum.TextXAlignment.Center
	msg.ZIndex = 5

	local hint = label(empty, "Crack an egg at one of the incubators to start your collection.",
		UDim2.new(1, -40, 0, 24), UDim2.new(0, 20, 0, 136), Palette.Ink, Enum.Font.FredokaOne, 15)
	hint.TextXAlignment = Enum.TextXAlignment.Center
	hint.TextTransparency = 0.35
	hint.ZIndex = 5
end

local function redrawPets()
	for _, child in ipairs(scroll:GetChildren()) do
		if child:IsA("GuiObject") then child:Destroy() end
	end

	local area = AreaPets.Areas[selectedArea]
	if not area then return end

	local anyOwned = false

	for _, egg in ipairs(area.eggs) do
		local ownedPets = {}
		for _, pet in ipairs(egg.pets) do
			if ownedAreaPets[pet.key] then
				table.insert(ownedPets, pet)
			end
		end
		if #ownedPets > 0 then
			anyOwned = true
			local accent = TIER_ACCENTS[egg.key] or Palette.Steel

			local section = designed(Instance.new("Frame"))
			section.BackgroundTransparency = 1
			section.Size = UDim2.new(1, 0, 0, 268)
			section.LayoutOrder = egg.tier
			section.ZIndex = 3
			section.Parent = scroll

			local sectionBar = designed(Instance.new("Frame"))
			sectionBar.Size = UDim2.new(1, -12, 0, 38)
			sectionBar.BackgroundColor3 = accent
			sectionBar.BorderSizePixel = 0
			sectionBar.ZIndex = 4
			sectionBar.Parent = section
			corner(sectionBar, 10)
			stroke(sectionBar, Palette.Ink, 2)

			local sectionTitle = label(sectionBar, string.upper(egg.name), UDim2.new(1, -110, 1, 0),
				UDim2.new(0, 14, 0, 0), Palette.Ink, Enum.Font.FredokaOne, 19)
			sectionTitle.TextXAlignment = Enum.TextXAlignment.Left
			sectionTitle.ZIndex = 5

			local sectionCount = label(sectionBar, string.format("%d / %d", #ownedPets, #egg.pets),
				UDim2.new(0, 90, 1, 0), UDim2.new(1, -102, 0, 0), Palette.Ink, Enum.Font.FredokaOne, 17)
			sectionCount.TextXAlignment = Enum.TextXAlignment.Right
			sectionCount.ZIndex = 5

			local row = designed(Instance.new("Frame"))
			row.BackgroundTransparency = 1
			row.Size = UDim2.new(1, 0, 0, 214)
			row.Position = UDim2.new(0, 0, 0, 50)
			row.ZIndex = 3
			row.Parent = section

			local rowLayout = Instance.new("UIListLayout")
			rowLayout.FillDirection = Enum.FillDirection.Horizontal
			rowLayout.Padding = UDim.new(0, 14)
			rowLayout.Parent = row

			for _, pet in ipairs(ownedPets) do
				buildPetCard(row, pet, accent)
			end
		end
	end

	if not anyOwned then
		buildEmptyState()
	end
end

local function refreshCounter()
	local owned, total = 0, 0
	for _, areaKey in ipairs(AreaPets.AreaKeys) do
		for _, egg in ipairs(AreaPets.Areas[areaKey].eggs) do
			for _, pet in ipairs(egg.pets) do
				total += 1
				if ownedAreaPets[pet.key] then owned += 1 end
			end
		end
	end
	counterLabel.Text = string.format("%d of %d collected", owned, total)
end

------------------------------------------------------------------
-- Tabs
------------------------------------------------------------------

local function paintTab(btn, tab, active)
	btn.BackgroundColor3 = active and tab.accent or Palette.Cream
	btn.TextColor3 = Palette.Ink
	local s = btn:FindFirstChildOfClass("UIStroke")
	if s then s.Thickness = active and 4 or 2 end
end

for index, tab in ipairs(AREA_TABS) do
	local btn = designed(Instance.new("TextButton"))
	btn.Name = "Tab_" .. tab.key
	btn.LayoutOrder = index
	btn.Size = UDim2.new(0, 168, 1, 0)
	btn.Text = tab.label
	btn.Font = Enum.Font.FredokaOne
	btn.TextSize = 19
	btn.AutoButtonColor = false
	btn.BorderSizePixel = 0
	btn.ZIndex = 4
	btn.Parent = tabRow
	corner(btn, 999)
	stroke(btn, Palette.Ink, 2)
	paintTab(btn, tab, tab.key == selectedArea)

	btn.MouseButton1Click:Connect(function()
		selectedArea = tab.key
		for _, other in ipairs(AREA_TABS) do
			paintTab(tabButtons[other.key], other, other.key == selectedArea)
		end
		headerBand.BackgroundColor3 = tab.accent
		headerFoot.BackgroundColor3 = tab.accent
		redrawPets()
	end)

	tabButtons[tab.key] = btn
end

------------------------------------------------------------------
-- Open / close, with the pop the panel was missing
------------------------------------------------------------------

local POP_IN = TweenInfo.new(0.26, Enum.EasingStyle.Back, Enum.EasingDirection.Out)
local POP_OUT = TweenInfo.new(0.14, Enum.EasingStyle.Quad, Enum.EasingDirection.In)
local FADE = TweenInfo.new(0.18, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)

local activeTweens = {}
local function play(object, info, goal)
	local existing = activeTweens[object]
	if existing then existing:Cancel() end
	local t = TweenService:Create(object, info, goal)
	activeTweens[object] = t
	t:Play()
	return t
end

local isOpen = false

local function openPanel()
	isOpen = true
	redrawPets()
	refreshCounter()

	-- fitScale is owned by Style.Fit and only recomputed on a viewport change,
	-- so its value while closed is the correct resting scale to animate back to.
	local rest = fitScale.Scale
	fitScale.Scale = rest * 0.86
	petsFrame.Position = UDim2.fromScale(0.5, RESTING_Y + 0.05)
	petsFrame.Visible = true
	petsBackdrop.Visible = true
	petsBackdrop.BackgroundTransparency = 1

	play(petsBackdrop, FADE, { BackgroundTransparency = 0.35 })
	play(fitScale, POP_IN, { Scale = rest })
	play(petsFrame, POP_IN, { Position = UDim2.fromScale(0.5, RESTING_Y) })
end

local function closePanel()
	isOpen = false
	local rest = fitScale.Scale
	play(petsBackdrop, POP_OUT, { BackgroundTransparency = 1 })
	play(petsFrame, POP_OUT, { Position = UDim2.fromScale(0.5, RESTING_Y + 0.04) })
	local shrink = play(fitScale, POP_OUT, { Scale = rest * 0.9 })

	shrink.Completed:Connect(function()
		if isOpen then return end
		petsFrame.Visible = false
		petsBackdrop.Visible = false
		-- Restore resting values so the next open reads them correctly.
		fitScale.Scale = rest
		petsFrame.Position = UDim2.fromScale(0.5, RESTING_Y)
	end)
end

local function togglePets()
	-- A quick squash on the rail button so the click registers physically.
	btnScale.Scale = 0.88
	play(btnScale, TweenInfo.new(0.22, Enum.EasingStyle.Back, Enum.EasingDirection.Out), { Scale = 1 })

	if isOpen then closePanel() else openPanel() end
end

petsBtn.MouseButton1Click:Connect(togglePets)
closeBtn.MouseButton1Click:Connect(function()
	if isOpen then closePanel() end
end)

-- Style.Modal hides other panels by flipping Visible directly, which bypasses
-- closePanel() and would otherwise leave isOpen stuck true.
petsFrame:GetPropertyChangedSignal("Visible"):Connect(function()
	if not petsFrame.Visible and isOpen then
		isOpen = false
		petsBackdrop.Visible = false
	end
end)

------------------------------------------------------------------
-- Server data
------------------------------------------------------------------

updateRemote.OnClientEvent:Connect(function(data)
	local changed = false
	if data.ownedAreaPets ~= nil then
		ownedAreaPets = data.ownedAreaPets
		changed = true
	end
	if data.equippedAreaPet ~= nil then
		equippedPetKey = data.equippedAreaPet and data.equippedAreaPet.key or nil
		changed = true
	end
	if changed then
		refreshCounter()
		if petsFrame.Visible then redrawPets() end
	end
end)

refreshCounter()
