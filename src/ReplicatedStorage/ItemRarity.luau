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
local GOLDEN_SCRAP_COLOR = Color3.fromRGB(255, 225, 90)

function ItemRarity.Color(tier, isSecret)
	if isSecret then
		return SECRET_COLOR
	end
	return TIER_COLORS[math.clamp(tier or 1, 1, MAX_TIER)]
end

function ItemRarity.Name(tier, isSecret)
	if isSecret then
		return "SECRET"
	end
	return TIER_NAMES[math.clamp(tier or 1, 1, MAX_TIER)]
end

-- Rich-text color codes don't take a Color3 directly — this saves every
-- call site from repeating :ToHex() and the "#" prefix.
function ItemRarity.Hex(tier, isSecret)
	return "#" .. ItemRarity.Color(tier, isSecret):ToHex()
end

-- Wraps a name in its rarity color as a RichText span. The label/TextLabel
-- showing it must have RichText = true, or the tags render as plain text.
function ItemRarity.Tag(name, tier, isSecret)
	return string.format('<font color="%s">%s</font>', ItemRarity.Hex(tier, isSecret), name)
end

function ItemRarity.GoldenScrapColor()
	return GOLDEN_SCRAP_COLOR
end

return ItemRarity
