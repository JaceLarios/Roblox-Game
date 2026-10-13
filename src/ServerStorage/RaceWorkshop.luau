--[[
	RaceWorkshop (ModuleScript, ServerStorage) — Junkyard Fusion

	Where you pick the car you race (user, 2026-10-13: "go up to and switch
	what car you'd want to drive in the race. Make it look like a small
	workshop that the person is working in"). It replaced the plain garage
	kiosk that stood in the lobby. A little open-front garage: concrete
	floor, red walls, a tool wall, a workbench, tyres and an oil drum, a car
	up on a two-post lift, and the race mechanic working on it.

	The mechanic is his own character, not anyone's avatar (the user's own
	avatar runs the Bolt Shop): an R15 figure in navy overalls, a white
	shirt and a red cap, wrench in hand. RaceWorkshop.client sets him
	working (bent over the car, ratcheting) on each player's screen. His
	"Choose Race Car" prompt is named ChooseCar: RaceWarsUI opens the car
	picker from any prompt of that name.

	Built by MapBootstrap, from scratch every time. Where it stands is
	RaceTrack's (Track.WorkshopFrame).
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Track = require(ServerStorage:WaitForChild("RaceTrack"))

local Workshop = {}

local RED = Color3.fromRGB(214, 44, 44)
local WHITE = Color3.fromRGB(245, 245, 240)
local DARK = Color3.fromRGB(46, 48, 54)
local CONCRETE = Color3.fromRGB(128, 128, 124)
local YELLOW = Color3.fromRGB(255, 204, 60)
local STEEL = Color3.fromRGB(176, 186, 196)
local NAVY = Color3.fromRGB(40, 58, 96)
local SKIN = Color3.fromRGB(204, 142, 105)

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

local function cylinder(parent, name, length, diameter, cf, color, material)
	-- Roblox cylinders run along X: `cf` is turned so that X is the axis.
	local p = part(parent, name, Vector3.new(length, diameter, diameter), cf, color, material)
	p.Shape = Enum.PartType.Cylinder
	return p
end

local function signText(board, text, color, stroke, font)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = Vector2.new(560, 120)
	gui.LightInfluence = 0
	gui.Parent = board
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = font or Enum.Font.LuckiestGuy
	label.TextScaled = true
	label.TextColor3 = color
	label.Text = text
	label.Parent = gui
	local outline = Instance.new("UIStroke")
	outline.Color = stroke
	outline.Thickness = 4
	outline.Parent = label
end

------------------------------------------------------------------
-- The mechanic
------------------------------------------------------------------

-- Something he wears or holds: welded to one of his body parts at `offset`
-- from it, weightless and never in anyone's way.
local function wear(rig, limbName, name, size, offset, color, material, shape)
	local limb = rig:FindFirstChild(limbName)
	if not limb then return end
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	if shape then p.Shape = shape end
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Massless = true
	p.CFrame = limb.CFrame * offset
	p.Parent = rig
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = limb
	weld.Part1 = p
	weld.Parent = p
	return p
end

-- An R15 figure standing at `spot` (his feet), facing its LookVector.
local function buildMechanic(parent, spot)
	local description = Instance.new("HumanoidDescription")
	description.HeadColor = SKIN
	description.LeftArmColor = SKIN
	description.RightArmColor = SKIN
	description.TorsoColor = NAVY
	description.LeftLegColor = NAVY
	description.RightLegColor = NAVY
	local ok, rig = pcall(Players.CreateHumanoidModelFromDescription, Players, description, Enum.HumanoidRigType.R15)
	if not ok or not rig then
		warn("[RaceWorkshop] No mechanic: " .. tostring(rig))
		return nil
	end
	rig.Name = "Mechanic"
	local humanoid = rig:FindFirstChildOfClass("Humanoid")
	local root = rig:FindFirstChild("HumanoidRootPart")
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	-- No Animate script: his client (RaceWorkshop.client) moves his joints.
	for _, d in ipairs(rig:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = false
			d.CanCollide = false
			d.CanTouch = false
			d.CanQuery = false
		end
	end
	root.Anchored = true
	rig:PivotTo(spot * CFrame.new(0, humanoid.HipHeight + root.Size.Y / 2, 0))
	rig.Parent = parent

	-- The outfit: a white shirt under the overalls' bib and straps, rolled
	-- sleeves, a red cap, a rag in his pocket, a wrench in his hand.
	local chest = rig:FindFirstChild("UpperTorso")
	if chest then
		local s = chest.Size
		wear(rig, "UpperTorso", "Shirt", Vector3.new(s.X + 0.04, s.Y * 0.42, s.Z + 0.04), CFrame.new(0, s.Y * 0.29, 0), WHITE)
		wear(rig, "UpperTorso", "OverallBib", Vector3.new(s.X * 0.62, s.Y * 0.62, 0.08), CFrame.new(0, -s.Y * 0.16, -s.Z / 2 - 0.03), NAVY)
		wear(rig, "UpperTorso", "BibPocket", Vector3.new(s.X * 0.26, s.Y * 0.2, 0.06), CFrame.new(0, -s.Y * 0.1, -s.Z / 2 - 0.08), Color3.fromRGB(30, 44, 74))
		for _, x in ipairs({ -1, 1 }) do
			wear(rig, "UpperTorso", "Strap", Vector3.new(0.16, s.Y * 0.5, 0.06), CFrame.new(x * s.X * 0.25, s.Y * 0.24, -s.Z / 2 - 0.04), NAVY)
			wear(rig, "UpperTorso", "BackStrap", Vector3.new(0.16, s.Y * 0.62, 0.06), CFrame.new(x * s.X * 0.25, s.Y * 0.1, s.Z / 2 + 0.04), NAVY)
		end
	end
	for _, side in ipairs({ "Left", "Right" }) do
		local arm = rig:FindFirstChild(side .. "UpperArm")
		if arm then
			local s = arm.Size
			wear(rig, side .. "UpperArm", "Sleeve", Vector3.new(s.X + 0.06, s.Y * 0.62, s.Z + 0.06), CFrame.new(0, s.Y * 0.2, 0), WHITE)
		end
	end
	local head = rig:FindFirstChild("Head")
	if head then
		local s = head.Size
		local cap = wear(rig, "Head", "Cap", Vector3.new(s.X * 1.04, s.Y * 0.36, s.Z * 1.04), CFrame.new(0, s.Y * 0.36, 0), RED)
		wear(rig, "Head", "CapBrim", Vector3.new(s.X * 0.96, 0.08, s.Z * 0.5), CFrame.new(0, s.Y * 0.2, -s.Z * 0.66), RED)
		wear(rig, "Head", "CapButton", Vector3.new(0.18, 0.1, 0.18), CFrame.new(0, s.Y * 0.56, 0), WHITE)
		if cap then cap.Shape = Enum.PartType.Block end
	end
	local hips = rig:FindFirstChild("LowerTorso")
	if hips then
		local s = hips.Size
		wear(rig, "LowerTorso", "Rag", Vector3.new(0.34, 0.7, 0.06), CFrame.new(s.X * 0.28, -s.Y * 0.4, s.Z / 2 + 0.05), RED)
	end
	local hand = rig:FindFirstChild("RightHand")
	if hand then
		wear(rig, "RightHand", "WrenchShaft", Vector3.new(0.14, 1.3, 0.14), CFrame.new(0, -0.55, -0.1), STEEL, Enum.Material.Metal)
		wear(rig, "RightHand", "WrenchHead", Vector3.new(0.5, 0.18, 0.2), CFrame.new(0, -1.2, -0.1), STEEL, Enum.Material.Metal)
	end
	return rig
end

------------------------------------------------------------------
-- The workshop
------------------------------------------------------------------

function Workshop.Build()
	local old = workspace:FindFirstChild("RaceWorkshop")
	if old then old:Destroy() end
	local model = Instance.new("Model")
	model.Name = "RaceWorkshop"
	-- On everyone's screen all the time, so the client finds the mechanic.
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent

	-- The opening is the front (-Z), toward the middle of the lobby.
	local base = Track.WorkshopFrame()
	local function at(x, y, z) return base * CFrame.new(x, y, z) end

	-- Floor, walls and roof.
	part(model, "Floor", Vector3.new(24, 0.5, 18), at(0, 0.25, 0), CONCRETE, Enum.Material.Concrete)
	part(model, "BackWall", Vector3.new(24, 14, 0.8), at(0, 7, 8.6), DARK, Enum.Material.Metal)
	for _, x in ipairs({ -11.6, 11.6 }) do
		part(model, "SideWall", Vector3.new(0.8, 14, 18), at(x, 7, 0), RED)
		part(model, "SideStripe", Vector3.new(0.9, 0.8, 18.1), at(x, 9.5, 0), WHITE)
	end
	part(model, "Roof", Vector3.new(25.6, 1, 19), at(0, 14.4, 0), DARK, Enum.Material.Metal)
	-- The roller door, rolled up over the opening.
	cylinder(model, "RollerDoor", 22.6, 1.8, at(0, 13, -8.3), Color3.fromRGB(150, 154, 160), Enum.Material.Metal)
	-- Hazard stripes on the floor at the door.
	for i = 0, 10 do
		local stripe = part(model, "Hazard", Vector3.new(1, 0.06, 1.4), at(-10 + i * 2, 0.52, -8.2) * CFrame.Angles(0, math.rad(35), 0), YELLOW)
		stripe.CanCollide = false
	end
	-- A warm work light under the roof.
	local lamp = part(model, "WorkLamp", Vector3.new(6, 0.3, 1), at(0, 13.7, 1), Color3.fromRGB(255, 240, 200), Enum.Material.Neon)
	lamp.CanCollide = false
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 236, 200)
	light.Brightness = 1.6
	light.Range = 26
	light.Parent = lamp

	-- The sign over the opening, and what it is for.
	local board = part(model, "SignBoard", Vector3.new(18, 3.4, 0.5), at(0, 15.8, -9.5), DARK)
	signText(board, "WORKSHOP", WHITE, RED)
	part(model, "SignRim", Vector3.new(18.6, 4, 0.3), at(0, 15.8, -9.2), RED)
	local sub = part(model, "SubSign", Vector3.new(12, 1.3, 0.3), at(0, 13.4, -9.9), RED)
	sub.CanCollide = false
	signText(sub, "Pick your race car", WHITE, DARK, Enum.Font.FredokaOne)

	-- The tool wall: a pegboard with tools hanging on it.
	part(model, "Pegboard", Vector3.new(14, 6, 0.3), at(0, 8, 8.05), Color3.fromRGB(196, 164, 118), Enum.Material.WoodPlanks)
	for i = 0, 6 do
		local x = -5.4 + i * 1.8
		local long = i % 2 == 0
		part(model, "HungTool", Vector3.new(0.22, long and 3 or 2.2, 0.15), at(x, 8.2, 7.82), i % 3 == 0 and RED or STEEL, Enum.Material.Metal)
		part(model, "HungToolHead", Vector3.new(long and 0.8 or 0.6, 0.35, 0.16), at(x, long and 9.7 or 9.3, 7.82), STEEL, Enum.Material.Metal)
	end

	-- The workbench along the left wall, with a vise and a toolbox.
	part(model, "Workbench", Vector3.new(3, 0.4, 8), at(-9.6, 3.2, 3), Color3.fromRGB(120, 84, 52), Enum.Material.WoodPlanks)
	for _, z in ipairs({ -0.7, 6.7 }) do
		part(model, "BenchLeg", Vector3.new(2.6, 3, 0.4), at(-9.6, 1.5, z), DARK, Enum.Material.Metal)
	end
	part(model, "Vise", Vector3.new(1, 0.9, 1.2), at(-9.4, 3.85, 0.6), STEEL, Enum.Material.Metal)
	part(model, "Toolbox", Vector3.new(2.4, 1.2, 1.4), at(-9.6, 4, 5), RED, Enum.Material.Metal)
	-- A tall tool chest on the right, and a stack of tyres and an oil drum.
	part(model, "ToolChest", Vector3.new(3, 5, 2), at(9.6, 2.5, 6.6), RED, Enum.Material.Metal)
	for i = 0, 3 do
		part(model, "Drawer", Vector3.new(2.6, 0.08, 0.06), at(9.6, 1.2 + i * 1.1, 5.58), STEEL, Enum.Material.Metal)
	end
	for i = 0, 2 do
		cylinder(model, "Tyre", 1, 2.8, at(9.4, 1 + i * 1.02, -5.4) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(26, 26, 30))
	end
	cylinder(model, "OilDrum", 3.4, 2.4, at(-9.8, 2.2, -5.8) * CFrame.Angles(0, 0, math.pi / 2), Color3.fromRGB(40, 110, 200), Enum.Material.Metal)

	-- A two-post lift with a car up on it, nose to the door.
	for _, x in ipairs({ -4.6, 4.6 }) do
		part(model, "LiftPost", Vector3.new(0.9, 9, 0.9), at(x, 4.75, 1.4), YELLOW, Enum.Material.Metal)
		part(model, "LiftArm", Vector3.new(3, 0.35, 0.5), at(x * 0.72, 1.45, -1.4), DARK, Enum.Material.Metal)
		part(model, "LiftArm", Vector3.new(3, 0.35, 0.5), at(x * 0.72, 1.45, 4.2), DARK, Enum.Material.Metal)
	end
	local ItemVisuals = require(ReplicatedStorage:WaitForChild("ItemVisuals"))
	local ok, car = pcall(ItemVisuals.CloneForViewport, "Muscle Car")
	if ok and car then
		local _, size = car:GetBoundingBox()
		car:ScaleTo(car:GetScale() * (10.5 / math.max(size.X, size.Z)))
		local _, scaled = car:GetBoundingBox()
		-- Item models face +Z; this one faces the door (-Z).
		-- Raised a little, at working height for the mechanic.
		car:PivotTo(at(0, 1.65 + scaled.Y / 2, 1.4) * CFrame.Angles(0, math.pi, 0))
		car.Name = "CarOnLift"
		car.Parent = model
	end

	-- The mechanic, at the front corner of the car, bent over the engine.
	local mechanic = buildMechanic(model, at(-3.9, 0.5, -2.6) * CFrame.Angles(0, math.rad(-80), 0))
	local promptHost = mechanic and mechanic:FindFirstChild("HumanoidRootPart")
	if not promptHost then
		promptHost = part(model, "PromptPost", Vector3.new(1, 4, 1), at(-3.9, 2.5, -2.6), DARK)
	end

	-- His name over him.
	local tag = Instance.new("BillboardGui")
	tag.Name = "MechanicTag"
	tag.Size = UDim2.fromOffset(240, 56)
	tag.StudsOffset = Vector3.new(0, 4.6, 0)
	tag.AlwaysOnTop = true
	tag.MaxDistance = 70
	tag.Parent = promptHost
	local text = Instance.new("TextLabel")
	text.Size = UDim2.fromScale(1, 1)
	text.BackgroundTransparency = 1
	text.Text = "RACE MECHANIC"
	text.TextColor3 = WHITE
	text.TextStrokeTransparency = 0.2
	text.TextScaled = true
	text.Font = Enum.Font.FredokaOne
	text.Parent = tag

	-- RaceWarsUI opens the car picker from any prompt with this name.
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ChooseCar"
	prompt.ActionText = "Choose Race Car"
	prompt.ObjectText = "Race Mechanic"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = promptHost

	model.Parent = workspace
	return model
end

return Workshop
