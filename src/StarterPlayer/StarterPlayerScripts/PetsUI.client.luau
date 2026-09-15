--[[
	PetsUI (LocalScript, StarterPlayerScripts) — Junkyard Fusion v1

	Lets a player equip one owned AreaPets egg pet to follow them (see
	PlotManager.server.luau's AreaPetsService wiring and
	updateEquippedPetVisual). Deliberately a brand-new, fully
	self-contained script — its own nav button (left rail, slot 4, the
	first free one) and its own modal — rather than another section
	bolted onto GameUI.client.luau, so this never touches (or conflicts
	with) whatever Codex is mid-pass on in that file. Same reasoning
	ShopUI.client.luau already uses for its own nav button.

	Pet catalog data (name, area, tier, multipliers) comes straight from
	AreaPets.luau, required directly — same as FusionRecipes/
	BrainrotRecipes already are elsewhere — rather than resent over the
	wire. Only which keys are OWNED and which one is EQUIPPED come from
	the server, via the existing GameUpdate payload's ownedAreaPets/
	equippedAreaPet fields.
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local gui = player:WaitForChild("PlayerGui"):WaitForChild("JunkyardUI")

local NavButton = require(ReplicatedStorage:WaitForChild("NavButton"))
local UIStyle = require(ReplicatedStorage:WaitForChild("UIStyle"))
local AreaPets = require(ReplicatedStorage:WaitForChild("AreaPets"))

local updateRemote = ReplicatedStorage:WaitForChild("GameUpdate")
local equipRemote = ReplicatedStorage:WaitForChild("EquipAreaPet")

local Palette = UIStyle.Palette

local AREA_TABS = {
	{ key = "junkyard", label = "JUNKYARD" },
	{ key = "brainrot", label = "BRAINROT" },
	{ key = "haunted", label = "HAUNTED" },
}

local ownedAreaPets = {}
local equippedPetKey = nil
local selectedArea = "junkyard"

------------------------------------------------------------------
-- Frame
------------------------------------------------------------------

local petsBtn = NavButton.Create(gui, "🐾", "PETS", Palette.Mint, NavButton.RailPosition("left", 4))

-- A custom icon, not the shared illustrated atlas — "PETS" would
-- otherwise land on the same cell as REWARDS/CODE (see UIStyle.luau's
-- `cells` table), and the user was explicit 2026-09-14 this needs to be
-- its own distinct icon, "a cartoon photo of an egg... following the
-- trend" of the rest of the UI. There's no tool available here to paint
-- a new sprite into that existing illustrated atlas, so this builds a
-- clean cartoon egg — cream shell, dark outline, a few playful speckles
-- in the game's own accent colors — entirely out of GUI primitives
-- instead. Swap this whole block for real illustrated art whenever
-- Codex has one, same as any other placeholder this session.
local defaultArt = petsBtn:FindFirstChild("Illustration")
if defaultArt then
	defaultArt.Visible = false
end

local eggShape = Instance.new("Frame")
eggShape.Name = "EggIcon"
eggShape.Size = UDim2.fromOffset(58, 76)
eggShape.AnchorPoint = Vector2.new(0.5, 0.5)
eggShape.Position = UDim2.new(0.5, 0, 0.5, -18)
eggShape.BackgroundColor3 = Color3.fromRGB(255, 250, 235)
eggShape.BorderSizePixel = 0
eggShape.ZIndex = 3
eggShape.Parent = petsBtn

local eggCorner = Instance.new("UICorner")
eggCorner.CornerRadius = UDim.new(0.5, 0)
eggCorner.Parent = eggShape

local eggStroke = Instance.new("UIStroke")
eggStroke.Color = Palette.Ink
eggStroke.Thickness = 3
eggStroke.Parent = eggShape

local speckles = {
	{ color = Palette.Copper, x = 0.32, y = 0.32, size = 11 },
	{ color = Palette.Teal, x = 0.66, y = 0.46, size = 9 },
	{ color = Palette.Gold, x = 0.48, y = 0.68, size = 13 },
}
for _, spot in ipairs(speckles) do
	local speckle = Instance.new("Frame")
	speckle.Size = UDim2.fromOffset(spot.size, spot.size)
	speckle.AnchorPoint = Vector2.new(0.5, 0.5)
	speckle.Position = UDim2.new(spot.x, 0, spot.y, 0)
	speckle.BackgroundColor3 = spot.color
	speckle.BorderSizePixel = 0
	speckle.ZIndex = 4
	speckle.Parent = eggShape

	local speckleCorner = Instance.new("UICorner")
	speckleCorner.CornerRadius = UDim.new(0.5, 0)
	speckleCorner.Parent = speckle
end

-- Style.Fit alone leaves no dimming backdrop behind the panel — the same
-- gap the Item Index and Inventory both had before being fixed. Adding
-- one here from the start rather than repeating that discovery a 4th time.
local petsBackdrop = Instance.new("Frame")
petsBackdrop.Name = "PetsBackdrop"
petsBackdrop.Size = UDim2.fromScale(1, 1)
petsBackdrop.BackgroundColor3 = Color3.new(0, 0, 0)
petsBackdrop.BackgroundTransparency = 0.35
petsBackdrop.BorderSizePixel = 0
petsBackdrop.Visible = false
petsBackdrop.ZIndex = 9
petsBackdrop:SetAttribute("Designed", true)
petsBackdrop.Parent = gui

local petsFrame = Instance.new("Frame")
petsFrame.Name = "PetsFrame"
petsFrame.Visible = false
petsFrame.BackgroundColor3 = Palette.Cream
petsFrame.Parent = gui
UIStyle.Fit(petsFrame, 920, 640)
UIStyle.Surface(petsFrame, Palette.Cream, 4)

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
	return lbl
end

local title = label(petsFrame, "PETS", UDim2.new(0, 300, 0, 50), UDim2.new(0, 30, 0, 20), Palette.Ink, Enum.Font.LuckiestGuy, 36)
title.TextXAlignment = Enum.TextXAlignment.Left

local subtitle = label(petsFrame, "Equip one owned pet to have it follow you.", UDim2.new(0, 500, 0, 24), UDim2.new(0, 32, 0, 68), Palette.Ink, Enum.Font.FredokaOne, 16)
subtitle.TextXAlignment = Enum.TextXAlignment.Left
subtitle.TextTransparency = 0.25

local closeBtn = Instance.new("TextButton")
closeBtn.Parent = petsFrame
UIStyle.Close(closeBtn)

------------------------------------------------------------------
-- Area tabs
------------------------------------------------------------------

local tabRow = Instance.new("Frame")
tabRow.BackgroundTransparency = 1
tabRow.Size = UDim2.new(1, -64, 0, 44)
tabRow.Position = UDim2.new(0, 32, 0, 100)
tabRow.Parent = petsFrame

local tabLayout = Instance.new("UIListLayout")
tabLayout.FillDirection = Enum.FillDirection.Horizontal
tabLayout.Padding = UDim.new(0, 10)
tabLayout.Parent = tabRow

local tabButtons = {}

------------------------------------------------------------------
-- Scrollable pet list
------------------------------------------------------------------

local scroll = Instance.new("ScrollingFrame")
scroll.Size = UDim2.new(1, -64, 1, -220)
scroll.Position = UDim2.new(0, 32, 0, 156)
scroll.BackgroundTransparency = 1
scroll.BorderSizePixel = 0
scroll.ScrollBarThickness = 8
scroll.CanvasSize = UDim2.new(0, 0, 0, 0)
scroll.Parent = petsFrame

local scrollLayout = Instance.new("UIListLayout")
scrollLayout.Padding = UDim.new(0, 18)
scrollLayout.Parent = scroll
scrollLayout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
	scroll.CanvasSize = UDim2.new(0, 0, 0, scrollLayout.AbsoluteContentSize.Y + 16)
end)

local TIER_ACCENTS = { okay = Palette.Steel, good = Palette.Teal, great = Palette.Gold }

-- Only ever called for a pet the player actually owns — this tab shows
-- your collection, not a browsable catalog. The user's own correction
-- 2026-09-14: "its not an index it should only show the pets i have
-- bought from the eggs or from the store it shouldnt show anything else."
local function buildPetCard(parent, pet, accent)
	local isEquipped = equippedPetKey == pet.key

	local card = Instance.new("TextButton")
	card.Size = UDim2.new(0, 164, 0, 150)
	card.AutoButtonColor = false
	card.Text = ""
	card.BackgroundColor3 = Palette.Cream
	card.Parent = parent
	UIStyle.Surface(card, card.BackgroundColor3, isEquipped and 5 or 2)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 14)
	corner.Parent = card
	if isEquipped then
		local stroke = card:FindFirstChildOfClass("UIStroke")
		stroke.Color = accent
	end

	local badge = Instance.new("Frame")
	badge.Size = UDim2.new(1, -16, 0, 6)
	badge.Position = UDim2.new(0, 8, 0, 8)
	badge.BackgroundColor3 = accent
	badge.BorderSizePixel = 0
	badge.Parent = card
	local badgeCorner = Instance.new("UICorner")
	badgeCorner.CornerRadius = UDim.new(1, 0)
	badgeCorner.Parent = badge

	if pet.secret then
		local secretTag = label(card, "★ SECRET", UDim2.new(1, -16, 0, 16), UDim2.new(0, 8, 0, 18), Palette.Gold, Enum.Font.FredokaOne, 12)
		secretTag.TextXAlignment = Enum.TextXAlignment.Left
	end

	local nameLbl = label(card, pet.name, UDim2.new(1, -16, 0, 52), UDim2.new(0, 8, 0, pet.secret and 36 or 22), Palette.Ink, Enum.Font.FredokaOne, 15)
	nameLbl.TextWrapped = true
	nameLbl.TextXAlignment = Enum.TextXAlignment.Left
	nameLbl.TextYAlignment = Enum.TextYAlignment.Top

	local statText = string.format("+%d%% coins\n+%d%% speed",
		math.floor((pet.coinMult - 1) * 100 + 0.5), math.floor((pet.speedMult - 1) * 100 + 0.5))
	local statLbl = label(card, statText, UDim2.new(1, -16, 0, 40), UDim2.new(0, 8, 1, -76), Palette.Teal, Enum.Font.FredokaOne, 13)
	statLbl.TextXAlignment = Enum.TextXAlignment.Left

	local stateLbl = Instance.new("TextLabel")
	stateLbl.Size = UDim2.new(1, -16, 0, 28)
	stateLbl.Position = UDim2.new(0, 8, 1, -32)
	stateLbl.BackgroundColor3 = isEquipped and accent or Palette.Ink
	stateLbl.BorderSizePixel = 0
	stateLbl.Text = isEquipped and "EQUIPPED" or "TAP TO EQUIP"
	stateLbl.TextColor3 = Palette.Cream
	stateLbl.Font = Enum.Font.FredokaOne
	stateLbl.TextSize = 13
	stateLbl.Parent = card
	local stateCorner = Instance.new("UICorner")
	stateCorner.CornerRadius = UDim.new(0, 8)
	stateCorner.Parent = stateLbl

	card.MouseButton1Click:Connect(function()
		equipRemote:FireServer(pet.key)
	end)

	return card
end

local function redrawPets()
	for _, child in ipairs(scroll:GetChildren()) do
		if child:IsA("Frame") then child:Destroy() end
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

			local section = Instance.new("Frame")
			section.BackgroundTransparency = 1
			section.Size = UDim2.new(1, 0, 0, 210)
			section.LayoutOrder = egg.tier
			section.Parent = scroll

			local sectionTitle = label(section, egg.name:upper(), UDim2.new(1, 0, 0, 26), UDim2.new(0, 0, 0, 0), TIER_ACCENTS[egg.key] or Palette.Ink, Enum.Font.FredokaOne, 20)
			sectionTitle.TextXAlignment = Enum.TextXAlignment.Left

			local row = Instance.new("Frame")
			row.BackgroundTransparency = 1
			row.Size = UDim2.new(1, 0, 0, 158)
			row.Position = UDim2.new(0, 0, 0, 34)
			row.Parent = section

			local rowLayout = Instance.new("UIListLayout")
			rowLayout.FillDirection = Enum.FillDirection.Horizontal
			rowLayout.Padding = UDim.new(0, 12)
			rowLayout.Parent = row

			for _, pet in ipairs(ownedPets) do
				buildPetCard(row, pet, TIER_ACCENTS[egg.key] or Palette.Ink)
			end
		end
	end

	if not anyOwned then
		local empty = Instance.new("Frame")
		empty.BackgroundTransparency = 1
		empty.Size = UDim2.new(1, 0, 0, 160)
		empty.LayoutOrder = 99
		empty.Parent = scroll

		local msg = label(empty, "No pets from this area yet — buy an egg in the shop to get started!",
			UDim2.new(1, 0, 0, 60), UDim2.new(0, 0, 0, 40), Palette.Ink, Enum.Font.FredokaOne, 18)
		msg.TextXAlignment = Enum.TextXAlignment.Center
		msg.TextWrapped = true
		msg.TextTransparency = 0.3
	end
end

for _, tab in ipairs(AREA_TABS) do
	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(0, 160, 1, 0)
	btn.Text = tab.label
	btn.Font = Enum.Font.FredokaOne
	btn.TextSize = 18
	btn.AutoButtonColor = false
	btn.Parent = tabRow
	UIStyle.Surface(btn, tab.key == selectedArea and Palette.Teal or Palette.Cream, 2)
	btn.TextColor3 = tab.key == selectedArea and Palette.Cream or Palette.Ink
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 10)
	corner.Parent = btn

	btn.MouseButton1Click:Connect(function()
		selectedArea = tab.key
		for key, otherBtn in pairs(tabButtons) do
			local active = key == selectedArea
			otherBtn.BackgroundColor3 = active and Palette.Teal or Palette.Cream
			otherBtn.TextColor3 = active and Palette.Cream or Palette.Ink
		end
		redrawPets()
	end)

	tabButtons[tab.key] = btn
end

------------------------------------------------------------------
-- Toggle + data
------------------------------------------------------------------

local function togglePets()
	local visible = not petsFrame.Visible
	petsFrame.Visible = visible
	petsBackdrop.Visible = visible
	if visible then redrawPets() end
end

petsBtn.MouseButton1Click:Connect(togglePets)
closeBtn.MouseButton1Click:Connect(togglePets)

updateRemote.OnClientEvent:Connect(function(data)
	if data.ownedAreaPets ~= nil then
		ownedAreaPets = data.ownedAreaPets
	end
	if data.equippedAreaPet ~= nil then
		equippedPetKey = data.equippedAreaPet and data.equippedAreaPet.key or nil
	end
	if petsFrame.Visible then redrawPets() end
end)
