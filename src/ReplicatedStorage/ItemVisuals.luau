-- Detailed vehicles keep a BasePart handle for the existing pickup/plot code.
-- Authored Models live in ItemModels; legacy single-part items still work.
local RS = game:GetService("ReplicatedStorage")
local templates = RS:WaitForChild("ItemModels")
local ItemVisuals = { GLOBAL_SCALE = 1.4 }

local function parts(object)
	local list = {}
	if object:IsA("BasePart") then table.insert(list, object) end
	for _, p in object:GetDescendants() do
		if p:IsA("BasePart") then table.insert(list, p) end
	end
	return list
end

function ItemVisuals.Tint(object, color)
	if not color then return end
	for _, p in parts(object) do p.Color = color end
end

function ItemVisuals.SetTransparency(object, alpha)
	local assembly = object:GetAttribute("ItemAssembly") == true
	for _, p in parts(object) do
		if not (assembly and p == object) then
			local original = p:GetAttribute("VisualTransparency") or 0
			p.Transparency = original + (1 - original) * alpha
		end
	end
end

-- Viewports use an anchored Model, avoiding physics-dependent joint motion.
function ItemVisuals.CloneForViewport(name, tint)
	local template = templates:FindFirstChild(name)
	if not template then return nil end
	local model = Instance.new("Model")
	model.Name = name
	local clone = template:Clone()
	clone.Parent = model
	for _, p in parts(model) do
		p.Anchored = true
		p.CanCollide = false
		p.CanTouch = false
		p.CanQuery = false
	end
	local cf, size = model:GetBoundingBox()
	model:PivotTo(CFrame.new(-cf.Position) * model:GetPivot())
	ItemVisuals.Tint(model, tint)
	return model, size
end

function ItemVisuals.Create(name, position, sizeScale)
	local scale = (sizeScale or 1) * ItemVisuals.GLOBAL_SCALE
	local template = templates:FindFirstChild(name)
	if template and template:IsA("Model") then
		local visual = template:Clone()
		visual.Name = "Visual"
		visual:ScaleTo(visual:GetScale() * scale)
		local cf, size = visual:GetBoundingBox()
		local root = Instance.new("Part")
		root.Name = name
		root.Size = size
		root.Transparency = 1
		root.Anchored = true
		root.CanCollide = false
		root.CanTouch = false
		root.CanQuery = true
		root:SetAttribute("ItemAssembly", true)
		root:SetAttribute("VisualRevision", template:GetAttribute("VisualRevision"))
		root.CFrame = CFrame.new(position.X, position.Y + size.Y / 2, position.Z)
		visual:PivotTo(root.CFrame * CFrame.new(-cf.Position) * visual:GetPivot())
		visual.Parent = root
		for _, p in parts(visual) do
			p:SetAttribute("VisualTransparency", p.Transparency)
			p.Anchored = false
			p.CanCollide = false
			p.CanTouch = false
			p.CanQuery = false
			p.Massless = true
			local joint = Instance.new("Weld")
			joint.Name = "VisualJoint"
			joint.Part0 = root
			joint.Part1 = p
			joint.C0 = root.CFrame:ToObjectSpace(p.CFrame)
			joint.Parent = root
		end
		return root
	end
	local part
	if template and template:IsA("BasePart") then
		part = template:Clone()
		part.Size *= scale
	else
		part = Instance.new("Part")
		part.Name = name
		part.Size = Vector3.new(4, 2, 6) * scale
		part.Material = Enum.Material.Neon
		part.Color = Color3.fromRGB(0, 220, 255)
	end
	part.Anchored = true
	part.Position = Vector3.new(position.X, position.Y + part.Size.Y / 2, position.Z)
	return part
end

-- Uniform resize used by the short pickup flourish. Weld offsets and the
-- bounds handle shrink together, so no detached wheels or leftover grilles.
function ItemVisuals.Resize(object, size)
	if object:GetAttribute("ItemAssembly") then
		local factor = size.X / object.Size.X
		for _, joint in object:GetChildren() do
			if joint:IsA("Weld") and joint.Name == "VisualJoint" and joint.Part1 then
				joint.Part1.Size *= factor
				joint.C0 = CFrame.new(joint.C0.Position * factor) * joint.C0.Rotation
			end
		end
	end
	object.Size = size
end

function ItemVisuals.HasModel(name)
	return templates:FindFirstChild(name) ~= nil
end
return ItemVisuals

