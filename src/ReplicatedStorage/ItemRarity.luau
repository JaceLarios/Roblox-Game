--[[
	ItemRarity (ModuleScript, ReplicatedStorage) — Junkyard Fusion v1
	One shared tier -> color mapping, so an item's name reads the same
	rarity color everywhere it's shown (world labels, carry previews,
	toasts, the index) regardless of which item line it came from.
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

local SECRET_COLOR = Color3.fromRGB(255, 205, 40)   -- gold

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
}
local RARITY_NAMES = {
	common = "COMMON", uncommon = "UNCOMMON", rare = "RARE",
	epic = "EPIC", mythic = "MYTHIC", legendary = "LEGENDARY",
}
-- Best first, so anything that needs to sort or compare rarities has a
-- single source of truth for the order rather than re-deriving it.
ItemRarity.Order = { "legendary", "mythic", "epic", "rare", "uncommon", "common" }

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
function ItemRarity.Tag(name, tier, isSecret, rarityKey)
	return string.format('<font color="%s">%s</font>', ItemRarity.Hex(tier, isSecret, rarityKey), name)
end

return ItemRarity
