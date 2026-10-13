--[[
	RacePodium (ModuleScript, ServerStorage) — Junkyard Fusion

	A live podium in the Race Wars lobby for the three players who have got
	furthest down the track (user, 2026-10-13): statues of their real
	avatars, first place in the middle on the tallest block and the
	biggest, second and third either side, lower and smaller. It is the
	"furthest race" ranking (RaceLeaderboardService, global, with everyone
	in this server folded in live) and refreshes every REFRESH_SECONDS
	(three minutes, as asked), with a countdown on its sign. A place nobody
	holds yet shows a grey, see-through stand-in.

	Statues are the avatar built from its user id on the server (seen by
	everyone), scaled to its place's height, posed by turning its shoulder
	joints (first place with both arms up, the others waving), anchored at
	the root. They are rebuilt only when someone new takes a place.

	PlotManager calls Start(RaceLeaderboardService) once. Where it stands is
	RaceTrack's (Track.PodiumFrame).
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Track = require(ServerStorage:WaitForChild("RaceTrack"))
local RaceConfig = require(ReplicatedStorage:WaitForChild("RaceConfig"))

local Podium = {}

local REFRESH_SECONDS = 180

local DARK = Color3.fromRGB(34, 36, 42)
local WHITE = Color3.fromRGB(245, 245, 240)
local RED = Color3.fromRGB(214, 44, 44)

-- Seen from the front: second on the left of first, third on the right.
-- The podium's own +X is its viewers' left (its front is -Z).
local PLACES = {
	{ label = "1ST", x = 0,   block = 8,   statue = 13,   color = Color3.fromRGB(240, 190, 60),  trim = Color3.fromRGB(255, 222, 110) },
	{ label = "2ND", x = 10,  block = 5.5, statue = 10.5, color = Color3.fromRGB(184, 192, 204), trim = Color3.fromRGB(226, 232, 240) },
	{ label = "3RD", x = -10, block = 4,   statue = 9.5,  color = Color3.fromRGB(196, 120, 64),  trim = Color3.fromRGB(232, 160, 104) },
}
local BLOCK_WIDTH, BLOCK_DEPTH = 9, 8

local root = nil      -- the podium model
local slots = {}      -- [place] = { plate labels, statue, userId, loading }
local countdown = nil -- the sign's "updates in" label

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

local function label(gui, name, text, y, height, color, font)
	local l = Instance.new("TextLabel")
	l.Name = name
	l.Position = UDim2.fromScale(0.04, y)
	l.Size = UDim2.fromScale(0.92, height)
	l.BackgroundTransparency = 1
	l.Text = text
	l.TextScaled = true
	l.Font = font or Enum.Font.FredokaOne
	l.TextColor3 = color
	l.Parent = gui
	local outline = Instance.new("UIStroke")
	outline.Color = Color3.fromRGB(16, 16, 20)
	outline.Thickness = 3
	outline.Parent = l
	return l
end

local function face(p, canvas)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Front
	gui.CanvasSize = canvas
	gui.LightInfluence = 0
	gui.Parent = p
	return gui
end

function Podium.Build()
	local old = workspace:FindFirstChild("RacePodium")
	if old then old:Destroy() end
	root = Instance.new("Model")
	root.Name = "RacePodium"
	root.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	table.clear(slots)

	local base = Track.PodiumFrame()
	local function at(x, y, z) return base * CFrame.new(x, y, z) end

	-- A low stage under all three, and the three blocks.
	part(root, "Stage", Vector3.new(32, 0.8, 12), at(0, 0.4, 0), DARK, Enum.Material.DiamondPlate)
	for place, spec in ipairs(PLACES) do
		local top = 0.8 + spec.block
		part(root, "Block" .. place, Vector3.new(BLOCK_WIDTH, spec.block, BLOCK_DEPTH), at(spec.x, 0.8 + spec.block / 2, 0), spec.color, Enum.Material.Metal)
		part(root, "BlockTrim" .. place, Vector3.new(BLOCK_WIDTH + 0.3, 0.5, BLOCK_DEPTH + 0.3), at(spec.x, top - 0.25, 0), spec.trim, Enum.Material.Neon)
		-- The plate on its front: the place, the name, how far they got.
		local plateHeight = math.min(3.4, spec.block - 0.6)
		local plate = part(root, "Plate" .. place, Vector3.new(BLOCK_WIDTH - 1, plateHeight, 0.3), at(spec.x, 0.8 + spec.block / 2, -BLOCK_DEPTH / 2 - 0.15), DARK)
		plate.CanCollide = false
		local gui = face(plate, Vector2.new(400, math.floor(400 * plateHeight / (BLOCK_WIDTH - 1))))
		slots[place] = {
			spec = spec,
			top = at(spec.x, top, 0),
			place = label(gui, "Place", spec.label, 0.04, 0.34, spec.trim, Enum.Font.LuckiestGuy),
			name = label(gui, "Name", "—", 0.38, 0.32, WHITE),
			best = label(gui, "Best", "Race to get here!", 0.71, 0.25, Color3.fromRGB(255, 204, 60)),
			userId = nil,
			generation = 0,
		}
	end

	-- The sign behind: what this is, and when it next updates.
	-- High enough to clear first place's statue, arms up.
	for _, x in ipairs({ -14.5, 14.5 }) do
		part(root, "SignPost", Vector3.new(0.8, 31, 0.8), at(x, 15.5, 5.4), DARK, Enum.Material.Metal)
	end
	local board = part(root, "SignBoard", Vector3.new(30, 5, 0.6), at(0, 28.5, 5.4), DARK)
	part(root, "SignRim", Vector3.new(30.8, 5.8, 0.3), at(0, 28.5, 5.75), RED)
	local signGui = face(board, Vector2.new(900, 150))
	label(signGui, "Title", "TOP RACERS", 0.02, 0.62, WHITE, Enum.Font.LuckiestGuy)
	countdown = label(signGui, "Updates", "Furthest down the track · live", 0.64, 0.32, Color3.fromRGB(255, 204, 60))

	-- A spotlight on the winner.
	local light = Instance.new("SpotLight")
	light.Angle = 50
	light.Brightness = 3
	light.Range = 30
	light.Color = Color3.fromRGB(255, 236, 190)
	-- In front of the podium, high up, shining back down onto first place.
	light.Face = Enum.NormalId.Back
	local spot = part(root, "Spot", Vector3.new(1, 1, 1), at(0, 27, -12) * CFrame.Angles(math.rad(50), 0, 0), DARK)
	spot.Transparency = 1
	spot.CanCollide = false
	light.Parent = spot

	root.Parent = workspace
	return root
end

local function isJoint(d)
	return d:IsA("Motor6D") or d:IsA("AnimationConstraint")
end

-- Turns a statue's arms up: both for first place, a wave for the others.
-- Avatars are built with AnimationConstraint joints now (Motor6D before);
-- either takes a Transform.
local function pose(rig, place)
	local function turn(jointName, angle)
		local joint = rig:FindFirstChild(jointName, true)
		if joint and isJoint(joint) then
			joint.Transform = CFrame.Angles(0, 0, angle)
		end
	end
	if place == 1 then
		turn("RightShoulder", math.rad(150))
		turn("LeftShoulder", math.rad(-150))
	else
		turn("RightShoulder", math.rad(place == 2 and 140 or 120))
	end
end

-- The bottom and top of a rig's body (its own parts, not hats or hair).
local function bodySpan(rig)
	local low, high = math.huge, -math.huge
	for _, p in ipairs(rig:GetChildren()) do
		if p:IsA("BasePart") and p.Name ~= "HumanoidRootPart" then
			low = math.min(low, p.Position.Y - p.Size.Y / 2)
			high = math.max(high, p.Position.Y + p.Size.Y / 2)
		end
	end
	return low, high
end

-- A statue on a block: `userId`'s avatar, or the grey stand-in for 0. It
-- is put together out of sight under the stage (in the world, so its hats
-- and hair attach), posed, and then frozen: every part anchored and the
-- joints taken out, so it holds the pose on every screen. Only then is it
-- scaled to its place's height (by its body), which for a frozen model is
-- exact; scaling it while jointed left it to the physics to catch up.
local function buildStatue(slot, place, userId)
	local ok, rig = pcall(function()
		if userId > 0 then
			return Players:CreateHumanoidModelFromUserId(userId)
		end
		return Players:CreateHumanoidModelFromDescription(Instance.new("HumanoidDescription"), Enum.HumanoidRigType.R15)
	end)
	if not ok or not rig then return nil end
	local humanoid = rig:FindFirstChildOfClass("Humanoid")
	local rootPart = rig:FindFirstChild("HumanoidRootPart")
	if not (humanoid and rootPart) then rig:Destroy() return nil end
	rig.Name = "Statue"
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	for _, d in ipairs(rig:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = false
			d.CanCollide = false
			d.CanTouch = false
			d.CanQuery = false
			if userId == 0 then
				d.Color = Color3.fromRGB(150, 150, 156)
				d.Material = Enum.Material.SmoothPlastic
				d.Transparency = d == rootPart and 1 or 0.45
				if d:IsA("MeshPart") then d.TextureID = "" end
			end
		elseif userId == 0 and (d:IsA("Decal") or d:IsA("Clothing")) then
			d:Destroy()
		end
	end
	rootPart.Anchored = true
	rig:PivotTo(slot.top - Vector3.new(0, 80, 0))
	rig.Parent = root
	task.wait(0.2)
	-- Its height standing, before the arms go up.
	local low, high = bodySpan(rig)
	local height = math.max(high - low, 1)
	-- Nothing animates a statue, and an Animator would undo the pose.
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if animator then animator:Destroy() end
	pose(rig, place)
	task.wait(0.25)
	-- Frozen, scaled, then stood on its block, facing the lobby.
	for _, d in ipairs(rig:GetDescendants()) do
		if d:IsA("BasePart") then d.Anchored = true end
	end
	for _, d in ipairs(rig:GetDescendants()) do
		if isJoint(d) then d:Destroy() end
	end
	rig:ScaleTo(rig:GetScale() * slot.spec.statue / height)
	low = bodySpan(rig)
	local pivot = rig:GetPivot()
	rig:PivotTo(slot.top.Rotation + Vector3.new(slot.top.Position.X, pivot.Position.Y + slot.top.Position.Y - low, slot.top.Position.Z))
	return rig
end

-- Shows the top three: `top` is the ranking, best first ({ userId, name,
-- best } each). A statue is only rebuilt when its place changes hands.
function Podium.Show(top)
	if not root then return end
	for place, slot in ipairs(slots) do
		local entry = top[place]
		local userId = entry and entry.userId or 0
		slot.name.Text = entry and entry.name or "—"
		slot.best.Text = entry and RaceConfig.DescribeDistance(entry.best) or "Race to get here!"
		if slot.userId ~= userId then
			slot.userId = userId
			slot.generation += 1
			local generation = slot.generation
			task.spawn(function()
				local statue = buildStatue(slot, place, userId)
				-- A slow load overtaken by a newer one is dropped.
				if not statue or slot.generation ~= generation or not root.Parent then
					if statue then statue:Destroy() end
					return
				end
				if slot.statue then slot.statue:Destroy() end
				slot.statue = statue
			end)
		end
	end
end

function Podium.Start(board)
	Podium.Build()
	task.spawn(function()
		task.wait(5)
		while true do
			pcall(board.RefreshIfStale)
			local ok, top = pcall(board.GetTopCached)
			if ok and type(top) == "table" then
				Podium.Show(top)
			end
			local nextAt = os.clock() + REFRESH_SECONDS
			while os.clock() < nextAt do
				local left = math.max(0, math.ceil(nextAt - os.clock()))
				if countdown then
					countdown.Text = string.format("Furthest down the track · updates in %d:%02d", left // 60, left % 60)
				end
				task.wait(1)
			end
		end
	end)
end

return Podium
