--[[
	ItemVisuals (ModuleScript, ReplicatedStorage) — Junkyard Fusion v1
	Builds the physical part for an item: a detailed mesh clone if one
	exists in ItemModels, otherwise the old placeholder block. This lets
	models get added item-by-item without any spawn code changes.
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local itemModels = ReplicatedStorage:WaitForChild("ItemModels")

local ItemVisuals = {}

-- Flat multiplier on top of every sizeScale below — the "make items bigger"
-- pass lives here instead of touching every ItemVisuals.Create call site.
ItemVisuals.GLOBAL_SCALE = 1.4

-- sizeScale multiplies the template's own size (or the fallback box size)
-- so the same model reads correctly small (pad slot), normal (yard drop)
-- or large (pedestal) without distorting its proportions.
function ItemVisuals.Create(itemName, position, sizeScale)
	sizeScale = (sizeScale or 1) * ItemVisuals.GLOBAL_SCALE

	local template = itemModels:FindFirstChild(itemName)
	if template then
		local part = template:Clone()
		part.Size = template.Size * sizeScale
		part.Position = position
		part.Anchored = true
		return part
	end

	local part = Instance.new("Part")
	part.Name = itemName
	part.Size = Vector3.new(4, 2, 6) * sizeScale
	part.Position = position
	part.Anchored = true
	part.Material = Enum.Material.Neon
	part.Color = Color3.fromRGB(0, 220, 255)
	return part
end

function ItemVisuals.HasModel(itemName)
	return itemModels:FindFirstChild(itemName) ~= nil
end

return ItemVisuals
