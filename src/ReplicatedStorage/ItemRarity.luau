local ItemNames = require(game:GetService("ReplicatedStorage"):WaitForChild("ItemNames"))
local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
--[[
	ItemRarity (ModuleScript, ReplicatedStorage) — Junkyard Fusion v1
	One shared tier -> color mapping, so an item's name reads the same
	rarity color everywhere it's shown (world labels, carry previews,
	toasts, the index) regardless of which item line it came from.

	Two rarities are more than a colour. Godly is a rainbow: names in
	rich text (Tag) get a colour a letter, and labels, plate rims and the
	Index tab get a rainbow gradient (Rainbow, Paint, Plate) that flows
	along on players' screens. Color() gives its aqua wherever one colour
	has to do (a glow, a podium). Secret is near-black, with a light
	outline on its letters so it still reads on a dark background.
--]]

local ItemRarity = {}

local TIER_COLORS = {
	[1] = Color3.fromRGB(165, 168, 175),  -- common scrap: muted gray
	[2] = Color3.fromRGB(90, 220, 120),   -- green
	[3] = Color3.fromRGB(90, 170, 255),   -- blue
	[4] = Color3.fromRGB(210, 110, 255),  -- purple
}
-- Same tiers as TIER_COLORS, same order the Index's rarity tabs already
-- use — kept here too now that server-side text (the fusion result
-- announcement) needs to say a rarity out loud, not just imply it by color.
local TIER_NAMES = {
	[1] = "COMMON",
	[2] = "UNCOMMON",
	[3] = "RARE",
	[4] = "EPIC",
}
local MAX_TIER = 4

local SECRET_COLOR = Color3.fromRGB(34, 34, 40)     -- near-black, as RARITY_COLORS.secret
-- Round a Secret name's dark letters, so they read on dark glass too.
local SECRET_OUTLINE = Color3.fromRGB(205, 205, 215)

-- Grabbable base items carry their own six-step rarity ladder, separate
-- from the fusion tier ladder above. They have to: every base item is
-- fusion tier 1, so colouring the yard by tier alone rendered all eight of
-- them the same grey. A rarity key, where one is supplied, overrides the
-- tier colour.
local RARITY_COLORS = {
	common    = Color3.fromRGB(206, 211, 219),  -- light gray
	uncommon  = Color3.fromRGB(90, 220, 120),   -- green
	rare      = Color3.fromRGB(90, 170, 255),   -- blue
	epic      = Color3.fromRGB(190, 110, 255),  -- purple
	mythic    = Color3.fromRGB(255, 70, 70),    -- red
	legendary = Color3.fromRGB(255, 221, 51),   -- yellow
	godly     = Color3.fromRGB(110, 255, 240),  -- aqua; shown as a rainbow where it can be (see the top)
	secret    = SECRET_COLOR,                   -- near-black: the Secret cars
}
local RARITY_NAMES = {
	common = "COMMON", uncommon = "UNCOMMON", rare = "RARE",
	epic = "EPIC", mythic = "MYTHIC", legendary = "LEGENDARY", godly = "GODLY", secret = "SECRET",
}
-- Best first, so anything that needs to sort or compare rarities has a
-- single source of truth for the order rather than re-deriving it.
ItemRarity.Order = { "secret", "godly", "legendary", "mythic", "epic", "rare", "uncommon", "common" }

function ItemRarity.RarityColor(key)
	return RARITY_COLORS[key]
end

function ItemRarity.RarityName(key)
	return RARITY_NAMES[key]
end

function ItemRarity.Color(tier, isSecret, rarityKey)
	if rarityKey and RARITY_COLORS[rarityKey] then
		return RARITY_COLORS[rarityKey]
	end
	if isSecret then
		return SECRET_COLOR
	end
	return TIER_COLORS[math.clamp(tier or 1, 1, MAX_TIER)]
end

function ItemRarity.Name(tier, isSecret, rarityKey)
	if rarityKey and RARITY_NAMES[rarityKey] then
		return RARITY_NAMES[rarityKey]
	end
	if isSecret then
		return "SECRET"
	end
	return TIER_NAMES[math.clamp(tier or 1, 1, MAX_TIER)]
end

-- Rich-text color codes don't take a Color3 directly — this saves every
-- call site from repeating :ToHex() and the "#" prefix.
function ItemRarity.Hex(tier, isSecret, rarityKey)
	return "#" .. ItemRarity.Color(tier, isSecret, rarityKey):ToHex()
end

-- Wraps a name in its rarity color as a RichText span. The label/TextLabel
-- showing it must have RichText = true, or the tags render as plain text.
-- A Godly name is a colour a letter round the rainbow (rich text can't
-- move, so this one stays still); a Secret one is near-black with a light
-- outline.
function ItemRarity.Tag(name, tier, isSecret, rarityKey)
	name = ItemNames.Display(name)
	local key = isSecret and "secret" or rarityKey
	if key == "godly" then
		local letters, count, i = {}, math.max(utf8.len(name) or #name, 1), 0
		for _, code in utf8.codes(name) do
			table.insert(letters, string.format('<font color="#%s">%s</font>',
				Color3.fromHSV(i / count * 0.85, 0.7, 1):ToHex(), utf8.char(code)))
			i += 1
		end
		return table.concat(letters)
	elseif key == "secret" then
		return string.format('<stroke color="#%s" thickness="1.5"><font color="#%s">%s</font></stroke>',
			SECRET_OUTLINE:ToHex(), SECRET_COLOR:ToHex(), name)
	end
	return string.format('<font color="%s">%s</font>', ItemRarity.Hex(tier, isSecret, rarityKey), name)
end

-- One colour for plain text that goes with a rarity but isn't the name (a
-- pad's earning line under it): the rarity's colour, but white-ish for
-- Godly and light grey for Secret, which can't be read near-black.
function ItemRarity.TextColor(tier, isSecret, rarityKey)
	local key = isSecret and "secret" or rarityKey
	if key == "godly" then return Color3.fromRGB(235, 255, 252) end
	if key == "secret" then return SECRET_OUTLINE end
	return ItemRarity.Color(tier, isSecret, rarityKey)
end

------------------------------------------------------------------
-- Godly's rainbow
------------------------------------------------------------------

local RAINBOW = "GodlyRainbow"   -- the gradients' name, and their CollectionService tag

local function rainbowColors(shift)
	local keys = {}
	for i = 0, 6 do
		keys[i + 1] = ColorSequenceKeypoint.new(i / 6, Color3.fromHSV((i / 6 + shift) % 1, 0.7, 1))
	end
	return ColorSequence.new(keys)
end

-- Puts the rainbow on a GuiObject or a UIStroke (once) and returns it. A
-- gradient multiplies, so whatever it is on should be white: the caller
-- sets that. Made on the server too (labels over cars); it flows on
-- players' screens either way, by its tag.
function ItemRarity.Rainbow(target)
	local gradient = target:FindFirstChild(RAINBOW)
	if not gradient then
		gradient = Instance.new("UIGradient")
		gradient.Name = RAINBOW
		gradient.Color = rainbowColors(0)
		CollectionService:AddTag(gradient, RAINBOW)
		gradient.Parent = target
	end
	return gradient
end

if RunService:IsClient() then
	task.spawn(function()
		while true do
			local colors = rainbowColors(os.clock() * 0.25 % 1)
			for _, gradient in ipairs(CollectionService:GetTagged(RAINBOW)) do
				gradient.Color = colors
			end
			task.wait(1 / 20)
		end
	end)
end

-- Colours a label that shows an item's name (a name tag over a car): its
-- rarity colour, the rainbow for Godly, and for Secret near-black letters
-- with a light outline (its UIStroke, or its plain text stroke). A label
-- reused for another item is put back the way it was.
function ItemRarity.Paint(label, tier, isSecret, rarityKey)
	local key = isSecret and "secret" or rarityKey
	local rainbow = label:FindFirstChild(RAINBOW)
	if key == "godly" then
		label.TextColor3 = Color3.new(1, 1, 1)
		ItemRarity.Rainbow(label)
	else
		if rainbow then rainbow:Destroy() end
		label.TextColor3 = ItemRarity.Color(tier, isSecret, rarityKey)
	end
	local outline = label:FindFirstChildOfClass("UIStroke")
	local holder, property = outline or label, outline and "Color" or "TextStrokeColor3"
	if holder:GetAttribute("RarityOutline") == nil then
		holder:SetAttribute("RarityOutline", holder[property])
	end
	holder[property] = key == "secret" and SECRET_OUTLINE or holder:GetAttribute("RarityOutline")
end

-- Dresses a name plate (GarageTheme.Plate) for its rarity: a flowing
-- rainbow rim for Godly, a dark plate with light letters for Secret.
-- Anything else keeps the plate as it is.
function ItemRarity.Plate(plate, rarityKey)
	local rim = plate:FindFirstChildOfClass("UIStroke")
	if rarityKey == "godly" and rim then
		rim.Color = Color3.new(1, 1, 1)
		rim.Thickness = math.max(rim.Thickness, 3)
		ItemRarity.Rainbow(rim)
	elseif rarityKey == "secret" then
		plate.BackgroundColor3 = Color3.fromRGB(44, 44, 52)
		plate.TextColor3 = Color3.fromRGB(236, 236, 242)
		if rim then rim.Color = Color3.fromRGB(120, 120, 134) end
	end
end

return ItemRarity
