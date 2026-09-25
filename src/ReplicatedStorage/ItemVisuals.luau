-- Detailed vehicles keep a BasePart handle for the existing pickup/plot code.
-- Authored Models live in ItemModels; legacy single-part items still work.
local RS = game:GetService("ReplicatedStorage")
local templates = RS:WaitForChild("ItemModels")
local FusionRecipes = require(RS:WaitForChild("FusionRecipes"))
local ItemVisuals = { GLOBAL_SCALE = 1.4 }
local wheelRigs = {}

-- An item's own model, or, until it has one, the model standing in for it
-- (FusionRecipes.StandIn: the nearest addon or build that has a model).
local function templateFor(name)
	local own = templates:FindFirstChild(name)
	if own then return own end
	local standIn = FusionRecipes.StandIn(name)
	return standIn and templates:FindFirstChild(standIn)
end

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
	local template = templateFor(name)
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
	local template = templateFor(name)
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
		local rig = {}
		wheelRigs[root] = rig
		root.Destroying:Once(function() wheelRigs[root] = nil end)
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
			local pivot, radius = p:GetAttribute("WheelPivot"), p:GetAttribute("WheelRadius")
			if typeof(pivot) == "Vector3" and type(radius) == "number" and radius > 0 then
				local localPivot = template:GetPivot():PointToObjectSpace(pivot)
				local worldPivot = visual:GetPivot():PointToWorldSpace(localPivot * scale)
				table.insert(rig, { joint = joint, pivot = root.CFrame:PointToObjectSpace(worldPivot),
					radius = radius * scale, rest = joint.C0, angle = 0 })
			end
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

-- Distance-driven visual rolling. Positive distance is travel along the car's +Z.
-- This keeps the conveyor deterministic; no unanchored physics or motor can shove an item off it.
function ItemVisuals.RollWheels(object, distance)
	if distance ~= distance or math.abs(distance) == math.huge then return end
	local rig = wheelRigs[object]
	if not rig then return end
	for _, wheel in rig do
		if wheel.joint.Parent then
			wheel.angle = (wheel.angle + distance / wheel.radius) % (math.pi * 2)
			wheel.joint.C0 = CFrame.new(wheel.pivot) * CFrame.Angles(wheel.angle, 0, 0)
				* CFrame.new(-wheel.pivot) * wheel.rest
		end
	end
end

-- Uniform resize used by the short pickup flourish. Weld offsets and the
-- bounds handle shrink together, so no detached wheels or leftover grilles.
function ItemVisuals.Resize(object, size)
	if object:GetAttribute("ItemAssembly") then
		local factor = size.X / object.Size.X
		for _, wheel in wheelRigs[object] or {} do
			wheel.pivot *= factor
			wheel.radius *= factor
			wheel.rest = CFrame.new(wheel.rest.Position * factor) * wheel.rest.Rotation
		end
		-- Keep the reactor's attached effects aligned during pickup resizing.
		for _, effect in object:GetDescendants() do
			if effect:IsA("Attachment") then
				effect.Position *= factor
			elseif effect:IsA("ParticleEmitter") then
				local points = {}
				for _, key in effect.Size.Keypoints do
					table.insert(points, NumberSequenceKeypoint.new(key.Time, key.Value * factor, key.Envelope * factor))
				end
				effect.Size = NumberSequence.new(points)
				effect.Speed = NumberRange.new(effect.Speed.Min * factor, effect.Speed.Max * factor)
				effect.Acceleration *= factor
			elseif effect:IsA("PointLight") then
				effect.Range *= factor
			end
		end
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
