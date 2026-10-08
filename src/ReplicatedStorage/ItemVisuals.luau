-- Detailed vehicles keep a BasePart handle for the existing pickup/plot code.
-- Authored Models live in ItemModels; legacy single-part items still work.
local RS = game:GetService("ReplicatedStorage")
local templates = RS:WaitForChild("ItemModels")
local FusionRecipes = require(RS:WaitForChild("FusionRecipes"))
local Mutations = require(RS:WaitForChild("Mutations"))
local EventAddons = require(RS:WaitForChild("EventAddons"))
local ItemVisuals = { GLOBAL_SCALE = 1.4 }
local wheelRigs = {}

-- An item's own model, or, until it has one, the model standing in for it
-- (FusionRecipes.StandIn: the nearest addon or build that has a model).
-- The second value is true when the model is borrowed.
local function templateFor(name)
	local own = templates:FindFirstChild(name)
	if own then return own, false end
	local standIn = FusionRecipes.StandIn(name)
	return standIn and templates:FindFirstChild(standIn), true
end

local function parts(object)
	local list = {}
	if object:IsA("BasePart") then table.insert(list, object) end
	for _, p in object:GetDescendants() do
		if p:IsA("BasePart") then table.insert(list, p) end
	end
	return list
end

-- A Phantom addon or build whose own model is not made yet borrows one
-- (FusionRecipes.StandIn) and is drawn see-through and ghostly, so it does
-- not pass for the build it borrowed from: pale mint, no textures, and in
-- the world Roblox's shimmering ForceField material. A ViewportFrame (the
-- Index, Inventory, shops) barely draws ForceField, so `flat` gives it a
-- plain see-through mint instead.
local GHOST = Color3.fromRGB(190, 255, 228)
function ItemVisuals.Ghostly(object, flat)
	for _, p in parts(object) do
		p.Color = GHOST
		if flat then
			p.Material = Enum.Material.SmoothPlastic
			p.Transparency = math.max(p.Transparency, 0.3)
		else
			p.Material = Enum.Material.ForceField
		end
		if p:IsA("MeshPart") then p.TextureID = "" end
	end
	for _, d in object:GetDescendants() do
		if d:IsA("SurfaceAppearance") or d:IsA("Decal") or d:IsA("Texture") then d:Destroy() end
	end
end

-- Whether this name is drawn ghostly (see Ghostly).
function ItemVisuals.IsGhostStandIn(name)
	return FusionRecipes.IsPhantom(name) and templates:FindFirstChild(name) == nil
end

-- A ghost car (EventAddons): where its Phantom addon's model sits on any
-- car, from the car's bounding box (its front is +Z). `at` is "top" (on
-- the roof, `z` along the car as a fraction of its length, + forward),
-- "front" or "rear" (low, off that end), or "frontAxle" / "rearAxle"
-- (round that axle, turning with its wheels). `width`, `length` and
-- `height` cap the addon at those fractions of the car's; `turn` spins it
-- round first.
local MOUNTS = {
	["Will-o'-Wisp Lanterns"] = { at = "top", z = .22, width = .85, length = .45 },
	["Phantom Exhaust"] = { at = "rear", width = .5, length = .45, turn = math.pi },
	["Crystal Ball Ornament"] = { at = "top", z = 0, width = .45, length = .45 },
	["Graveyard Grille"] = { at = "front", width = .95, length = .35 },
	["Ecto Tank"] = { at = "top", z = -.22, width = .4, length = .35 },
	["Banshee Horn"] = { at = "top", z = .12, width = .5, length = .55 },
	["Poltergeist Spoiler"] = { at = "top", z = -.35, width = .95, length = .3 },
	["Coffin Carrier"] = { at = "top", z = 0, width = .75, length = .7 },
	["Witch's Cauldron"] = { at = "top", z = -.18, width = .45, length = .4 },
	["Specter Sails"] = { at = "top", z = 0, width = .85, length = .5, height = 1.2 },
	["Wraith Wheels"] = { at = "rearAxle", width = 1.1 },
	["Soul Turbo"] = { at = "top", z = -.28, width = .5, length = .4 },
	["Hearse Canopy"] = { at = "top", z = 0, width = .9, length = .75 },
	["Reaper Scythes"] = { at = "frontAxle", width = 1.15 },
	["Ghost Chauffeur"] = { at = "top", z = 0, width = .45, length = .45 },
}

-- The car's axle at one end (+1 front, -1 back): its middle, a wheel's id
-- and radius, from the wheel parts' WheelPivot; nil for a car without.
local function axle(model, side)
	local best = {}
	for _, p in parts(model) do
		local pivot, radius = p:GetAttribute("WheelPivot"), p:GetAttribute("WheelRadius")
		if typeof(pivot) == "Vector3" and type(radius) == "number" then
			local z = math.round(pivot.Z * 100) * side
			if not best.z or z > best.z then best = { z = z, pivots = {}, radius = radius, id = p:GetAttribute("WheelId") } end
			if z == best.z then table.insert(best.pivots, pivot); best.radius = math.max(best.radius, radius) end
		end
	end
	if not best.z then return nil end
	local sum = Vector3.zero
	for _, pivot in best.pivots do sum += pivot end
	return sum / #best.pivots, best.id, best.radius
end

-- How high a roof addon rests over a car: the highest point of the car
-- under its footprint (`spots`, x/z pairs), found by casting down onto a
-- copy in a hidden WorldModel (rays only work on one in the game), so it
-- sits on the bonnet or the roof, not on top of the car's tallest part.
-- Cached per car and event addon. Nil when nothing is under it.
local probe
local restHeights = {}
local function restHeight(model, key, spots, from)
	if restHeights[key] ~= nil then return restHeights[key] or nil end
	if not probe then
		probe = Instance.new("WorldModel")
		probe.Name = "GhostMountProbe"
		probe.Parent = game:GetService("RunService"):IsServer() and game:GetService("ServerStorage") or RS
	end
	local copy = model:Clone()
	for _, p in parts(copy) do p.CanQuery = true end
	copy.Parent = probe
	local best
	for _, spot in spots do
		local hit = probe:Raycast(Vector3.new(spot.X, from, spot.Y), Vector3.new(0, -(from * 2 + 100), 0))
		if hit then best = math.max(best or -math.huge, hit.Position.Y) end
	end
	copy:Destroy()
	restHeights[key] = best or false
	return best
end

-- Dresses a car as a ghost: drawn ghostly (see Ghostly), with its event
-- addon's own model mounted on it (MOUNTS), not ghostly. `model` holds the
-- car, in its template's place, before any scaling; `key` names the car.
local function ghostOverlay(model, eventId, flat, key)
	ItemVisuals.Ghostly(model, flat)
	local addonName = EventAddons.Addon(eventId)
	local template = addonName and templates:FindFirstChild(addonName)
	local mount = MOUNTS[addonName]
	if not (template and template:IsA("Model") and mount) then return end
	local cf, size = model:GetBoundingBox()
	local addon = template:Clone()
	addon.Name = "EventAddon"
	if mount.turn then addon:PivotTo(addon:GetPivot() * CFrame.Angles(0, mount.turn, 0)) end
	local _, own = addon:GetBoundingBox()
	local scale = size.X * mount.width / own.X
	if mount.length then scale = math.min(scale, size.Z * mount.length / own.Z) end
	if mount.height then scale = math.min(scale, size.Y * mount.height / own.Y) end
	addon:ScaleTo(addon:GetScale() * scale)
	local acf, asize = addon:GetBoundingBox()
	local c, half = cf.Position, size / 2
	local spot, wheel
	if mount.at == "top" then
		local z = c.Z + size.Z * mount.z
		local spots = {}
		for _, dx in { -.4, 0, .4 } do
			for _, dz in { -.4, 0, .4 } do table.insert(spots, Vector2.new(c.X + asize.X * dx, z + asize.Z * dz)) end
		end
		local rest = restHeight(model, tostring(key) .. "|" .. eventId, spots, c.Y + half.Y + 5) or c.Y + half.Y
		spot = Vector3.new(c.X, rest + asize.Y / 2 - size.Y * .02, z)
	elseif mount.at == "front" then
		spot = Vector3.new(c.X, c.Y - half.Y + asize.Y / 2, c.Z + half.Z + asize.Z * .4)
	elseif mount.at == "rear" then
		spot = Vector3.new(c.X, c.Y - half.Y + size.Y * .15 + asize.Y / 2, c.Z - half.Z)
	else
		local side = mount.at == "frontAxle" and 1 or -1
		local middle, id, radius = axle(model, side)
		spot = middle and Vector3.new(c.X, middle.Y, middle.Z) or Vector3.new(c.X, c.Y - half.Y + size.Y * .25, c.Z + side * size.Z * .33)
		if middle then wheel = { id = id, pivot = spot, radius = radius } end
	end
	addon:PivotTo(CFrame.new(spot - acf.Position) * addon:GetPivot())
	if wheel then
		for _, p in parts(addon) do
			p:SetAttribute("WheelId", wheel.id); p:SetAttribute("WheelPivot", wheel.pivot); p:SetAttribute("WheelRadius", wheel.radius)
		end
	end
	addon.Parent = model
end

-- What to draw for any item name (with or without its mutation and event
-- addon): the model to clone, the bare name, its event addon, whether to
-- dress it with ghostOverlay, and whether the model is borrowed. A named
-- Spectral build (an Index entry) is its car with that Phantom; a Phantom
-- on a base car whose named build has a model of its own (the samples)
-- shows that model as it is.
local function pick(name)
	local base, _, eventId = Mutations.Unwrap(name)
	local overlay = eventId ~= nil
	if not eventId then
		local car, id = EventAddons.FromIndexName(base)
		if car then
			eventId = id
			if templates:FindFirstChild(base) then return templates[base], base, eventId, false, false end
			base, overlay = car, true
		end
	end
	if eventId and FusionRecipes.CarOf(base) == base then
		local named = templates:FindFirstChild(EventAddons.IndexName(base, eventId) or "")
		if named then return named, base, eventId, false, false end
	end
	local template, borrowed = templateFor(base)
	return template, base, eventId, overlay, borrowed
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
-- Any item name: a mutation is left to `tint`, an event addon is drawn.
function ItemVisuals.CloneForViewport(name, tint)
	local template, base, eventId, overlay, borrowed = pick(name)
	if not template then return nil end
	local model = Instance.new("Model")
	model.Name = (Mutations.Unwrap(name))
	local clone = template:Clone()
	clone.Parent = model
	if overlay then
		ghostOverlay(model, eventId, true, template.Name)
	elseif borrowed and FusionRecipes.IsPhantom(base) then
		ItemVisuals.Ghostly(model, true)
	end
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

-- Any item name, like CloneForViewport. The root is named after the bare
-- item; a ghost car's carries its event addon (EventAddon), for
-- VehicleAddonEffects.
function ItemVisuals.Create(name, position, sizeScale)
	local scale = (sizeScale or 1) * ItemVisuals.GLOBAL_SCALE
	local template, base, eventId, overlay, borrowed = pick(name)
	name = (Mutations.Unwrap(name))
	if template and template:IsA("Model") then
		local visual = template:Clone()
		visual.Name = "Visual"
		if overlay then
			ghostOverlay(visual, eventId, false, template.Name)
		elseif borrowed and FusionRecipes.IsPhantom(base) then
			ItemVisuals.Ghostly(visual)
		end
		-- Sent to players whole, never a few parts at a time (the place
		-- streams): the wheel rig (RollWheels) and the Atom Rider's hover
		-- copy (HoverVisuals) take the model as it is when it arrives.
		visual.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
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
		root:SetAttribute("EventAddon", eventId)
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
				-- The same axle, sized for this copy, for players' screens
				-- to roll the wheel from (see RollWheels).
				p:SetAttribute("RollPivot", root.CFrame:PointToObjectSpace(worldPivot))
				p:SetAttribute("RollRadius", radius * scale)
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

-- A copy made on the server, as a player's screen sees it: its wheels
-- from the RollPivot/RollRadius that Create left on them. Built again if
-- more of the car arrives after it was first looked at.
local function rigFromAttributes(object)
	if not object:GetAttribute("ItemAssembly") then return nil end
	local rig = {}
	for _, joint in object:GetChildren() do
		if joint:IsA("Weld") and joint.Name == "VisualJoint" and joint.Part1 then
			local pivot, radius = joint.Part1:GetAttribute("RollPivot"), joint.Part1:GetAttribute("RollRadius")
			if typeof(pivot) == "Vector3" and type(radius) == "number" and radius > 0 then
				table.insert(rig, { joint = joint, pivot = pivot, radius = radius, rest = joint.C0, angle = 0 })
			end
		end
	end
	wheelRigs[object] = rig
	local added, gone
	added = object.ChildAdded:Connect(function()
		added:Disconnect()
		gone:Disconnect()
		wheelRigs[object] = nil
	end)
	gone = object.AncestryChanged:Connect(function()
		if not object:IsDescendantOf(game) then
			added:Disconnect()
			gone:Disconnect()
			wheelRigs[object] = nil
		end
	end)
	return rig
end

-- Distance-driven visual rolling. Positive distance is travel along the car's +Z.
-- This keeps the conveyor deterministic; no unanchored physics or motor can shove an item off it.
-- Called on players' screens (ConveyorBelt, RaceDrive), never the server: a wheel
-- turned there is sent to every player, every frame.
-- maxTurn, if given, is the most a wheel turns in one call (radians): past
-- about a spoke a frame a fast wheel looks still or spinning backwards.
function ItemVisuals.RollWheels(object, distance, maxTurn)
	if distance ~= distance or math.abs(distance) == math.huge then return end
	local rig = wheelRigs[object] or rigFromAttributes(object)
	if not rig then return end
	for _, wheel in rig do
		if wheel.joint.Parent then
			local turn = distance / wheel.radius
			if maxTurn then
				turn = math.clamp(turn, -maxTurn, maxTurn)
			end
			wheel.angle = (wheel.angle + turn) % (math.pi * 2)
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
