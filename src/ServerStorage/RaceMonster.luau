--[[
	RaceMonster (ModuleScript, ServerStorage) — Junkyard Fusion

	What the Race Wars monster looks like and how it moves. RaceService
	decides where it is; this module only draws it there.

	The model is a placeholder built from parts. To use a real one, put a
	Model named "RaceMonsterModel" in ServerStorage: it is used instead,
	scaled so its height is HEIGHT, with its pivot on the floor at its
	middle and its front facing the pivot's LookVector.
--]]

local ServerStorage = game:GetService("ServerStorage")

local Monster = {}

-- Big enough to loom over the whole width of the track.
local HEIGHT = 38

local function rgb(r, g, b) return Color3.fromRGB(r, g, b) end

local function add(model, name, size, cframe, colour, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cframe
	p.Color = colour
	p.Material = material or Enum.Material.Metal
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.CastShadow = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = model
	return p
end

-- A hulking scrap beast: a hunched body, a wide jaw full of teeth, two
-- glowing eyes and clawed arms. Faces -Z (its LookVector).
local function placeholder()
	local model = Instance.new("Model")
	model.Name = "RaceMonster"
	local dark, rust = rgb(46, 44, 50), rgb(122, 64, 40)
	local root = add(model, "Root", Vector3.new(2, 2, 2), CFrame.new(0, 0, 0), dark)
	root.Transparency = 1
	model.PrimaryPart = root

	add(model, "Body", Vector3.new(20, 16, 14), CFrame.new(0, 13, 2) * CFrame.Angles(math.rad(-12), 0, 0), dark)
	add(model, "BackPlate", Vector3.new(16, 10, 6), CFrame.new(0, 19, 7) * CFrame.Angles(math.rad(-25), 0, 0), rust, Enum.Material.CorrodedMetal)
	for i = -1, 1 do
		add(model, "Spike", Vector3.new(2, 7, 2), CFrame.new(i * 5, 25, 7) * CFrame.Angles(math.rad(-30), 0, math.rad(i * 15)), rust, Enum.Material.CorrodedMetal)
	end
	add(model, "Head", Vector3.new(16, 9, 10), CFrame.new(0, 21, -6), dark)
	add(model, "Jaw", Vector3.new(15, 4, 10), CFrame.new(0, 14.5, -8) * CFrame.Angles(math.rad(12), 0, 0), dark)
	for i = 0, 5 do
		local x = -6 + i * 2.4
		add(model, "Tooth", Vector3.new(1.2, 2.4, 1.2), CFrame.new(x, 16.4, -12.6), rgb(240, 236, 220), Enum.Material.SmoothPlastic)
		add(model, "Tooth", Vector3.new(1.2, 2.2, 1.2), CFrame.new(x + 1.2, 18.4, -11.6) * CFrame.Angles(math.pi, 0, 0), rgb(240, 236, 220), Enum.Material.SmoothPlastic)
	end
	for _, side in ipairs({ -1, 1 }) do
		add(model, "Eye", Vector3.new(3, 2, 1), CFrame.new(side * 4.5, 23, -11.2), rgb(255, 40, 30), Enum.Material.Neon)
		add(model, "Arm", Vector3.new(5, 14, 5), CFrame.new(side * 12, 12, -4) * CFrame.Angles(math.rad(35), 0, math.rad(side * 10)), dark)
		for c = -1, 1 do
			add(model, "Claw", Vector3.new(1, 5, 1), CFrame.new(side * 12 + c * 1.6, 3.5, -10) * CFrame.Angles(math.rad(60), 0, 0), rgb(220, 214, 200), Enum.Material.SmoothPlastic)
		end
		add(model, "Leg", Vector3.new(6, 8, 7), CFrame.new(side * 6, 4, 4), dark)
	end
	local glow = Instance.new("PointLight")
	glow.Color = rgb(255, 60, 40)
	glow.Range = 24
	glow.Brightness = 3
	glow.Parent = model.Head
	return model
end

function Monster.Create()
	local template = ServerStorage:FindFirstChild("RaceMonsterModel")
	local model
	if template and template:IsA("Model") then
		model = template:Clone()
		local _, size = model:GetBoundingBox()
		if size.Y > 0 then
			model:ScaleTo(model:GetScale() * HEIGHT / size.Y)
		end
		for _, p in ipairs(model:GetDescendants()) do
			if p:IsA("BasePart") then
				p.Anchored = true
				p.CanCollide = false
				p.CanTouch = false
				p.CanQuery = false
			end
		end
	else
		model = placeholder()
		-- The placeholder is built 30 studs tall.
		model:ScaleTo(HEIGHT / 30)
	end
	model.Name = "RaceMonster"
	return model
end

-- Draws the monster standing at `frame` (on the floor, facing the way it
-- runs). `t` is the time, for its lumbering bob.
function Monster.Place(model, frame, t)
	local bob = math.abs(math.sin(t * 7)) * 1.6
	local sway = math.sin(t * 3.5) * math.rad(4)
	model:PivotTo(frame * CFrame.new(0, bob, 0) * CFrame.Angles(0, 0, sway))
end

return Monster
