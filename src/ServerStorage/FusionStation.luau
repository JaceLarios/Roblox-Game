--[[
	FusionStation (ModuleScript, ServerStorage) — Junkyard Fusion

	The look of each base's Fusion Pad (user, 2026-10-13: "a rework on the
	fusion pad"). It was a plain glowing orange slab; now it is a fusion
	machine. The pad itself (PlotManager's FusionPad part, which everything
	else finds by name: its prompts, where the two items sit, the shimmer,
	the tutorial) is unchanged in size and place and becomes a steel deck;
	round it this builds:
	  - a raised dark rim and a glowing orange border on the deck,
	  - two cyan-outlined bays where the car and the addon sit (PlotManager
	    puts them 4.6 studs either side of the middle, along world X),
	  - an arch over the middle: two pylons with glowing coils and a beam,
	    a "FUSION PAD" sign on each side of it,
	  - the fusion core hanging from the beam between the two bays, in a
	    glass shell, lit, with energy lines running from the pylons to it.

	Only looks: nothing here is clicked or counted. PlotManager calls
	Build(pad) when it builds a base. The pad's parts line up with world
	X and Z, as the item bays do.
--]]

local Station = {}

local ORANGE = Color3.fromRGB(255, 120, 20)
local CYAN = Color3.fromRGB(110, 236, 255)
local STEEL = Color3.fromRGB(150, 160, 172)
local DARK = Color3.fromRGB(40, 44, 52)
local DECK = Color3.fromRGB(70, 76, 88)
local WHITE = Color3.fromRGB(245, 245, 240)

local function part(parent, name, size, cf, color, material, collide)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanCollide = collide == true
	p.CanTouch = false
	p.CanQuery = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- A vertical disc or ring: Roblox cylinders run along X, so turned upright.
local function disc(parent, name, height, diameter, cf, color, material)
	local p = part(parent, name, Vector3.new(height, diameter, diameter), cf * CFrame.Angles(0, 0, math.pi / 2), color, material)
	p.Shape = Enum.PartType.Cylinder
	return p
end

local function signText(board, face, text)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.CanvasSize = Vector2.new(500, 100)
	gui.LightInfluence = 0
	gui.Parent = board
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.LuckiestGuy
	label.TextScaled = true
	label.TextColor3 = WHITE
	label.Text = text
	label.Parent = gui
	local outline = Instance.new("UIStroke")
	outline.Color = Color3.fromRGB(150, 60, 0)
	outline.Thickness = 4
	outline.Parent = label
end

-- An outline of thin glowing strips round a rectangle on the deck.
local function outline(parent, name, centre, sizeX, sizeZ, width, color)
	local y = 0.04
	for _, side in ipairs({ -1, 1 }) do
		part(parent, name, Vector3.new(sizeX, 0.08, width), centre * CFrame.new(0, y, side * (sizeZ - width) / 2), color, Enum.Material.Neon)
		part(parent, name, Vector3.new(width, 0.08, sizeZ), centre * CFrame.new(side * (sizeX - width) / 2, y, 0), color, Enum.Material.Neon)
	end
end

function Station.Build(pad)
	local old = pad.Parent:FindFirstChild("FusionStation")
	if old then old:Destroy() end
	local model = Instance.new("Model")
	model.Name = "FusionStation"

	-- The deck: the pad itself, in steel.
	pad.Material = Enum.Material.DiamondPlate
	pad.Color = DECK
	local half = pad.Size.X / 2
	local top = CFrame.new(pad.Position + Vector3.new(0, pad.Size.Y / 2, 0))
	local function at(x, y, z) return top * CFrame.new(x, y, z) end

	-- A raised rim round the deck, from the floor (the deck stands
	-- pad.Size.Y above it), and its glowing border.
	local floorY = -pad.Size.Y
	for _, side in ipairs({ -1, 1 }) do
		part(model, "Rim", Vector3.new(pad.Size.X + 2, pad.Size.Y + 0.2, 1), at(0, floorY / 2 + 0.1, side * (half + 0.5)), DARK, Enum.Material.Metal, true)
		part(model, "Rim", Vector3.new(1, pad.Size.Y + 0.2, pad.Size.Z), at(side * (half + 0.5), floorY / 2 + 0.1, 0), DARK, Enum.Material.Metal, true)
	end
	outline(model, "DeckGlow", top, pad.Size.X - 1, pad.Size.Z - 1, 0.3, ORANGE)

	-- The two bays, where the car and the addon sit (4.6 either side, X).
	for _, x in ipairs({ -4.6, 4.6 }) do
		outline(model, "Bay", at(x, 0, 0), 6.2, 13.4, 0.2, CYAN)
	end
	-- Lines of light from each bay to the middle.
	for _, z in ipairs({ -3, 0, 3 }) do
		part(model, "Channel", Vector3.new(2.2, 0.08, 0.18), at(0, 0.04, z), ORANGE, Enum.Material.Neon)
	end

	-- The arch: a pylon off each end of the deck (Z) and a beam over it.
	local archHeight = 13.5
	for _, side in ipairs({ -1, 1 }) do
		local z = side * (half + 2.2)
		part(model, "PylonBase", Vector3.new(3, 1, 3), at(0, floorY + 0.5, z), DARK, Enum.Material.Metal, true)
		part(model, "Pylon", Vector3.new(1.4, archHeight, 1.4), at(0, archHeight / 2, z), Color3.fromRGB(84, 90, 104), Enum.Material.Metal, true)
		for i, y in ipairs({ 3, 5.5, 8, 10.5 }) do
			disc(model, "Coil", 0.35, i % 2 == 0 and 2.1 or 2.4, at(0, y, z), ORANGE, Enum.Material.Neon)
		end
		part(model, "PylonCap", Vector3.new(2, 0.6, 2), at(0, archHeight + 0.3, z), DARK, Enum.Material.Metal)
		-- Energy running down the pylon and across the floor to the deck.
		part(model, "Feed", Vector3.new(0.2, archHeight - 1, 0.2), at(0.8, archHeight / 2, z), CYAN, Enum.Material.Neon)
		part(model, "Feed", Vector3.new(0.2, 0.08, 1.6), at(0.8, floorY + 0.04, z - side * 1.2), CYAN, Enum.Material.Neon)
	end
	local beamLength = pad.Size.Z + 6.4
	part(model, "Beam", Vector3.new(1.6, 1.4, beamLength), at(0, archHeight + 0.7, 0), STEEL, Enum.Material.Metal)
	part(model, "BeamGlow", Vector3.new(0.5, 0.1, beamLength - 2), at(0, archHeight - 0.05, 0), ORANGE, Enum.Material.Neon)
	-- The sign on each face of the beam.
	for _, side in ipairs({ -1, 1 }) do
		local board = part(model, "Sign", Vector3.new(0.3, 2.2, 11), at(side * 0.95, archHeight + 0.7, 0), DARK)
		signText(board, side > 0 and Enum.NormalId.Right or Enum.NormalId.Left, "FUSION PAD")
	end

	-- The core, hanging between the bays above the item labels.
	local coreY = 10.6
	part(model, "CoreRod", Vector3.new(0.4, archHeight - coreY - 1, 0.4), at(0, (archHeight + coreY + 1) / 2, 0), STEEL, Enum.Material.Metal)
	local core = part(model, "Core", Vector3.new(2.2, 2.2, 2.2), at(0, coreY, 0), ORANGE, Enum.Material.Neon)
	core.Shape = Enum.PartType.Ball
	local shell = part(model, "CoreShell", Vector3.new(3.4, 3.4, 3.4), at(0, coreY, 0), CYAN, Enum.Material.Glass)
	shell.Shape = Enum.PartType.Ball
	shell.Transparency = 0.6
	-- Two steel bands round the shell, crossing.
	for _, angle in ipairs({ 0, 90 }) do
		part(model, "CoreBand", Vector3.new(0.3, 3.7, 0.3), at(0, coreY, 0) * CFrame.Angles(0, math.rad(angle), 0) * CFrame.new(1.75, 0, 0), STEEL, Enum.Material.Metal)
		part(model, "CoreBand", Vector3.new(0.3, 3.7, 0.3), at(0, coreY, 0) * CFrame.Angles(0, math.rad(angle), 0) * CFrame.new(-1.75, 0, 0), STEEL, Enum.Material.Metal)
	end
	local light = Instance.new("PointLight")
	light.Color = ORANGE
	light.Brightness = 2
	light.Range = 18
	light.Parent = core
	local sparks = Instance.new("ParticleEmitter")
	sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparks.Color = ColorSequence.new(ORANGE, CYAN)
	sparks.LightEmission = 1
	sparks.Rate = 6
	sparks.Lifetime = NumberRange.new(0.6, 1.2)
	sparks.Speed = NumberRange.new(1, 3)
	sparks.SpreadAngle = Vector2.new(180, 180)
	sparks.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0) })
	sparks.Parent = core

	model.Parent = pad.Parent
	return model
end

return Station
