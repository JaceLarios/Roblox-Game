--[[
	PhantomGarage (ModuleScript, ServerStorage) — Junkyard Fusion

	The stall in the Race Wars lobby where the Phantom addons are sold for
	bolts (FusionRecipes.PhantomAddons; the bolts are won racing). A crooked
	dark-violet hut with mint trim, a "PHANTOM GARAGE" sign, green-flame
	lanterns and a floating ghost behind the counter. Its "Phantom Shop"
	prompt is on the Counter; PhantomShop.client opens the shop from it, and
	PlotManager's BuyPhantom checks the buyer is standing near the Counter.
	The Counter's Remove Phantom prompt takes the Phantom off a held ghost
	car (PlotManager; see EventAddons).

	Built by MapBootstrap, from scratch every time. Stands left of the
	line-up box, near the start gate, turned to face players arriving at
	the lobby spawn.
--]]

local ServerStorage = game:GetService("ServerStorage")
local Track = require(ServerStorage:WaitForChild("RaceTrack"))

local Garage = {}

local VIOLET = Color3.fromRGB(58, 34, 96)
local DEEP = Color3.fromRGB(30, 18, 52)
local MINT = Color3.fromRGB(150, 255, 210)
local BONE = Color3.fromRGB(242, 234, 211)

local function part(parent, name, size, cf, color, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function signText(board, face, text, size, color)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.CanvasSize = Vector2.new(560, 120)
	gui.LightInfluence = 0
	gui.Parent = board
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = Enum.Font.Creepster
	label.TextScaled = true
	label.TextColor3 = color
	label.Text = text
	label.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Color = DEEP
	stroke.Thickness = 3
	stroke.Parent = label
	return gui
end

-- A lantern on a post with a green spirit flame.
local function lantern(parent, cf)
	part(parent, "LanternPost", Vector3.new(0.5, 7, 0.5), cf * CFrame.new(0, 3.5, 0), DEEP, Enum.Material.Metal)
	local cage = part(parent, "LanternCage", Vector3.new(1.4, 1.8, 1.4), cf * CFrame.new(0, 7.6, 0), DEEP, Enum.Material.Metal)
	cage.Transparency = 0.2
	local flame = part(parent, "LanternFlame", Vector3.new(0.7, 1.1, 0.7), cf * CFrame.new(0, 7.6, 0), MINT, Enum.Material.Neon)
	flame.Shape = Enum.PartType.Ball
	flame.CanCollide = false
	local light = Instance.new("PointLight")
	light.Color = MINT
	light.Brightness = 1.4
	light.Range = 14
	light.Parent = flame
end

function Garage.Build()
	local old = workspace:FindFirstChild("PhantomGarage")
	if old then old:Destroy() end
	local model = Instance.new("Model")
	model.Name = "PhantomGarage"
	-- On everyone's screen all the time, so the client can find its prompt.
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent

	local spot = Track.PointAt(-34, -84, 0)
	local spawn = Track.PointAt(-110, 0, 0)
	local base = CFrame.lookAt(spot, Vector3.new(spawn.X, spot.Y, spawn.Z))

	-- The hut: a floor, three walls and a crooked roof, open at the front.
	part(model, "Floor", Vector3.new(18, 0.6, 12), base * CFrame.new(0, 0.3, 0), DEEP, Enum.Material.WoodPlanks)
	part(model, "BackWall", Vector3.new(18, 12, 0.8), base * CFrame.new(0, 6, 5.6), VIOLET, Enum.Material.WoodPlanks)
	for _, x in ipairs({ -8.6, 8.6 }) do
		part(model, "SideWall", Vector3.new(0.8, 12, 12), base * CFrame.new(x, 6, 0), VIOLET, Enum.Material.WoodPlanks)
	end
	part(model, "Roof", Vector3.new(21, 1, 15), base * CFrame.new(0, 12.6, 0) * CFrame.Angles(math.rad(-8), 0, math.rad(4)), DEEP, Enum.Material.Slate)
	-- Mint trim round the opening.
	part(model, "TrimTop", Vector3.new(18.4, 0.4, 0.4), base * CFrame.new(0, 11.2, -5.8), MINT, Enum.Material.Neon)
	for _, x in ipairs({ -9, 9 }) do
		part(model, "TrimSide", Vector3.new(0.4, 11, 0.4), base * CFrame.new(x, 5.8, -5.8), MINT, Enum.Material.Neon)
	end

	-- The counter, with the prompt.
	local counter = part(model, "Counter", Vector3.new(12, 3.4, 2.4), base * CFrame.new(0, 2.3, -3.4), VIOLET, Enum.Material.Wood)
	part(model, "CounterTop", Vector3.new(12.6, 0.3, 3), base * CFrame.new(0, 4.1, -3.4), BONE, Enum.Material.Marble)

	-- The shopkeeper: a ghost floating behind the counter, see-through.
	local ghost = Instance.new("Model")
	ghost.Name = "Shopkeeper"
	ghost.Parent = model
	local body = part(ghost, "Sheet", Vector3.new(3.4, 4.4, 3), base * CFrame.new(0, 6.4, 1.2), Color3.fromRGB(235, 255, 246), Enum.Material.ForceField)
	body.Shape = Enum.PartType.Cylinder
	body.CFrame = base * CFrame.new(0, 6.2, 1.2) * CFrame.Angles(0, 0, math.pi / 2)
	body.Size = Vector3.new(4.2, 3.6, 3.6)
	local head = part(ghost, "Head", Vector3.new(3.6, 3.6, 3.6), base * CFrame.new(0, 8.6, 1.2), Color3.fromRGB(240, 255, 248), Enum.Material.ForceField)
	head.Shape = Enum.PartType.Ball
	for _, x in ipairs({ -0.65, 0.65 }) do
		local eye = part(ghost, "Eye", Vector3.new(0.5, 0.75, 0.2), base * CFrame.new(x, 8.9, -0.55), DEEP)
		eye.CanCollide = false
	end
	local mouth = part(ghost, "Mouth", Vector3.new(0.6, 0.6, 0.2), base * CFrame.new(0, 8, -0.6), DEEP)
	mouth.Shape = Enum.PartType.Ball
	-- A little top hat.
	part(ghost, "HatBrim", Vector3.new(0.2, 3, 3), base * CFrame.new(0, 10.3, 1.2) * CFrame.Angles(0, 0, math.pi / 2), DEEP).Shape = Enum.PartType.Cylinder
	part(ghost, "HatTop", Vector3.new(1.8, 2, 2), base * CFrame.new(0, 11.2, 1.2) * CFrame.Angles(0, 0, math.pi / 2), DEEP).Shape = Enum.PartType.Cylinder
	for _, p in ipairs(ghost:GetDescendants()) do
		if p:IsA("BasePart") then p.CanCollide = false end
	end
	local mist = Instance.new("ParticleEmitter")
	mist.Texture = "rbxasset://textures/particles/smoke_main.dds"
	mist.Color = ColorSequence.new(Color3.fromRGB(225, 255, 240), MINT)
	mist.Rate = 5
	mist.Lifetime = NumberRange.new(2, 3)
	mist.Speed = NumberRange.new(0.3, 0.8)
	mist.SpreadAngle = Vector2.new(40, 40)
	mist.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.5), NumberSequenceKeypoint.new(1, 3.5) })
	mist.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1) })
	mist.Parent = body

	-- The sign over the opening, readable from the front.
	local board = part(model, "SignBoard", Vector3.new(16, 3, 0.5), base * CFrame.new(0, 14.4, -6.2), DEEP)
	signText(board, Enum.NormalId.Front, "PHANTOM GARAGE", 0, MINT)
	-- In front of the roof's edge, under the big sign.
	local sub = part(model, "SubSign", Vector3.new(10, 1.2, 0.3), base * CFrame.new(0, 13.2, -8), VIOLET)
	sub.CanCollide = false
	signText(sub, Enum.NormalId.Front, "Ghost addons for bolts", 0, BONE)

	lantern(model, base * CFrame.new(-11, 0, -6))
	lantern(model, base * CFrame.new(11, 0, -6))

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "OpenPhantomShop"
	prompt.ActionText = "Phantom Shop"
	prompt.ObjectText = "Spend your bolts"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = counter

	-- Taking a Phantom off the ghost car you hold (PlotManager): its own key
	-- and a hold, since the Phantom is lost, and shown under the shop's.
	local remove = Instance.new("ProximityPrompt")
	remove.Name = "RemovePhantomPrompt"
	remove.ActionText = "Remove Phantom"
	remove.ObjectText = "From the car you hold (it's lost)"
	remove.KeyboardKeyCode = Enum.KeyCode.R
	remove.GamepadKeyCode = Enum.KeyCode.ButtonY
	remove.HoldDuration = 1.5
	remove.MaxActivationDistance = 14
	remove.RequiresLineOfSight = false
	remove.UIOffset = Vector2.new(0, 90)
	remove.Parent = counter

	model.Parent = workspace
	return model
end

return Garage
