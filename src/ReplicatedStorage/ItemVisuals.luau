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
--
-- position.Y is the SURFACE the item should rest on (ground, pad, slot
-- top) — not the part's own center. Meshes vary a lot in height (a Jet
-- Engine and a THE LAWNLORD are not the same size), so a fixed center-Y
-- chosen for one item either floats or buries a taller/shorter one. Every
-- caller passes the resting height; this works out the actual center.
function ItemVisuals.Create(itemName, position, sizeScale)
	sizeScale = (sizeScale or 1) * ItemVisuals.GLOBAL_SCALE

	local template = itemModels:FindFirstChild(itemName)
	local part
	local finalSize

	if template then
		part = template:Clone()
		finalSize = template.Size * sizeScale
		part.Size = finalSize
	else
		finalSize = Vector3.new(4, 2, 6) * sizeScale
		part = Instance.new("Part")
		part.Name = itemName
		part.Size = finalSize
		part.Material = Enum.Material.Neon
		part.Color = Color3.fromRGB(0, 220, 255)
	end

	part.Anchored = true
	part.Position = Vector3.new(position.X, position.Y + finalSize.Y / 2, position.Z)
	return part
end

function ItemVisuals.HasModel(itemName)
	return itemModels:FindFirstChild(itemName) ~= nil
end

return ItemVisuals
