--[[
	YardConveyor (ModuleScript, ServerStorage) — Junkyard Fusion

	The belt everything in the yard arrives on. A ring of conveyor circles
	the middle of the yard — round the crane and the two leaderboards —
	and a black box straddles it at one point. Scrap comes out of the box's
	front, rides one full lap, and goes back in at the box's rear, where it
	is gone; a fresh car keeps coming out of the front. Nothing sits still
	waiting to be picked up: if you want it, you catch it.

	This module owns the geometry and the path. ScrapSpawner owns what
	rides it (what spawns, how often, moving it along).

	The path is measured in studs along the belt's centre line: distance 0
	is the box's front face, and Conveyor.Length is its rear face, one lap
	later. Items travel counter-clockwise seen from above.

	Built at server start, into its own Workspace folder, and only ever
	touches that folder.
--]]

local Conveyor = {}

-- Centre line of the belt, measured from the yard's centre. The yard is
-- clear from about 38 to 78 studs out: inside that are the crane and the
-- leaderboards, outside it the salvage stations and the road mouths.
Conveyor.RADIUS = 58
Conveyor.WIDTH = 10
-- Studs per second along the belt. Slower than walking (22), so anyone can
-- catch up with what they want; a lap takes about 43 seconds.
Conveyor.SPEED = 8

local GROUND_Y = 1.2
local BELT_THICKNESS = 0.5
-- Top of the belt: what riders sit on.
Conveyor.SURFACE_Y = GROUND_Y + BELT_THICKNESS

-- The black box sits between two base roads (every base's road is on a
-- multiple of 45 degrees), so nobody running home has to go round it.
local BOX_BEARING = math.rad(-67.5)
local BOX_LENGTH = 16   -- along the belt
local BOX_WIDTH = 16    -- across the belt
local BOX_HEIGHT = 12

local SEGMENTS = 72
local FOLDER_NAME = "YardConveyor"
-- Bump when the geometry changes, so a stale build is replaced.
local VERSION = 1

local BELT_COLOUR = Color3.fromRGB(40, 42, 48)
local TRIM_YELLOW = Color3.fromRGB(255, 196, 40)
local TRIM_DARK = Color3.fromRGB(30, 32, 36)
local BOX_COLOUR = Color3.fromRGB(16, 16, 19)
local FLAP_COLOUR = Color3.fromRGB(26, 26, 30)

-- Chevrons on the belt's top face, pointing the way it runs. The client
-- scrolls them (ConveyorBelt.client) so the belt reads as moving.
local BELT_TEXTURE = "rbxassetid://93791096336970"
Conveyor.TEXTURE_TILE = 5

local boxHalfAngle = (BOX_LENGTH / 2) / Conveyor.RADIUS
local frontAngle = BOX_BEARING + boxHalfAngle
Conveyor.Length = (2 * math.pi - 2 * boxHalfAngle) * Conveyor.RADIUS

local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end

local function onRing(angle, radius, y)
	return Vector3.new(math.cos(angle) * radius, y, math.sin(angle) * radius)
end

-- Direction of travel at a bearing: counter-clockwise, the way the angle
-- grows.
local function tangentAt(angle)
	return Vector3.new(-math.sin(angle), 0, math.cos(angle))
end

-- Where a point this far along the belt is: the spot on the belt's top
-- surface on its centre line, and the direction of travel there. Works
-- past either end too, which is inside the box.
function Conveyor.PointAt(distance)
	local angle = frontAngle + distance / Conveyor.RADIUS
	return onRing(angle, Conveyor.RADIUS, Conveyor.SURFACE_Y), tangentAt(angle)
end

-- How far along the belt a position is (0 at the box's front, measured
-- the way the belt runs). Anything between Length and a full lap is
-- inside the box.
function Conveyor.DistanceOf(position)
	local angle = math.atan2(position.Z, position.X)
	return ((angle - frontAngle) % (2 * math.pi)) * Conveyor.RADIUS
end

-- True for a spot over the belt itself, not beside it.
function Conveyor.IsOnBelt(position)
	return math.abs(flat(position).Magnitude - Conveyor.RADIUS) <= Conveyor.WIDTH / 2
end

local function part(parent, props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CastShadow = false
	for key, value in pairs(props) do
		p[key] = value
	end
	p.Parent = parent
	return p
end

local function buildBelt(folder)
	local belt = Instance.new("Folder")
	belt.Name = "Belt"
	belt.Parent = folder

	local step = 2 * math.pi / SEGMENTS
	-- Long enough to meet at the OUTER edge, where the gaps would show; the
	-- overlap on the inner edge is the same colour and invisible.
	local length = step * (Conveyor.RADIUS + Conveyor.WIDTH / 2) + 0.1
	for i = 0, SEGMENTS - 1 do
		local angle = (i + 0.5) * step
		local centre = onRing(angle, Conveyor.RADIUS, GROUND_Y + BELT_THICKNESS / 2)
		local frame = CFrame.lookAt(centre, centre + tangentAt(angle))

		-- Solid, so players can stand on it to catch what is riding past.
		local segment = part(belt, {
			Name = "BeltSegment",
			Size = Vector3.new(Conveyor.WIDTH, BELT_THICKNESS, length),
			CFrame = frame,
			Color = BELT_COLOUR,
			Material = Enum.Material.SmoothPlastic,
		})
		local chevrons = Instance.new("Texture")
		chevrons.Name = "BeltChevrons"
		chevrons.Texture = BELT_TEXTURE
		chevrons.Face = Enum.NormalId.Top
		chevrons.StudsPerTileU = Conveyor.WIDTH
		chevrons.StudsPerTileV = Conveyor.TEXTURE_TILE
		chevrons.Color3 = Color3.fromRGB(95, 100, 112)
		chevrons.Transparency = 0.35
		chevrons.Parent = segment

		-- Low safety edges, striped by alternating segments. Not solid, so
		-- they never trip anyone stepping on or off the belt.
		local colour = (i % 2 == 0) and TRIM_YELLOW or TRIM_DARK
		for _, side in ipairs({ -1, 1 }) do
			part(belt, {
				Name = "BeltEdge",
				Size = Vector3.new(0.5, BELT_THICKNESS + 0.3, length),
				CFrame = frame * CFrame.new(side * (Conveyor.WIDTH / 2 + 0.25), 0.15, 0),
				Color = colour,
				Material = Enum.Material.SmoothPlastic,
				CanCollide = false,
				CanQuery = false,
				CanTouch = false,
			})
		end
	end
end

local function buildBox(folder)
	local box = Instance.new("Model")
	box.Name = "BlackBox"
	box.Parent = folder

	local centre = onRing(BOX_BEARING, Conveyor.RADIUS, GROUND_Y + BOX_HEIGHT / 2)
	-- Looking the way the belt runs, so its front face (local -Z) is where
	-- scrap comes OUT and its rear face (local +Z) is where it goes IN.
	local frame = CFrame.lookAt(centre, centre + tangentAt(BOX_BEARING))

	local body = part(box, {
		Name = "Body",
		Size = Vector3.new(BOX_WIDTH, BOX_HEIGHT, BOX_LENGTH),
		CFrame = frame,
		Color = BOX_COLOUR,
		Material = Enum.Material.SmoothPlastic,
		Reflectance = 0.05,
	})
	box.PrimaryPart = body

	-- For each mouth: a curtain of rubber strips over the belt opening and
	-- a light bar above it, green where scrap comes out, red where it goes
	-- in. The strips are not solid; riders pass straight through them.
	local mouthHeight = 7
	local strips = 7
	for _, mouth in ipairs({ { z = -1, colour = Color3.fromRGB(70, 230, 110), name = "Exit" },
		{ z = 1, colour = Color3.fromRGB(255, 60, 60), name = "Entry" } }) do
		local faceZ = mouth.z * (BOX_LENGTH / 2 + 0.15)
		for s = 1, strips do
			local x = -Conveyor.WIDTH / 2 + (s - 0.5) * (Conveyor.WIDTH / strips)
			part(box, {
				Name = mouth.name .. "Flap",
				Size = Vector3.new(Conveyor.WIDTH / strips - 0.12, mouthHeight, 0.12),
				CFrame = frame * CFrame.new(x, -BOX_HEIGHT / 2 + BELT_THICKNESS + mouthHeight / 2, faceZ),
				Color = FLAP_COLOUR,
				Material = Enum.Material.SmoothPlastic,
				Transparency = 0.1,
				CanCollide = false,
				CanQuery = false,
				CanTouch = false,
			})
		end
		part(box, {
			Name = mouth.name .. "Light",
			Size = Vector3.new(Conveyor.WIDTH + 1, 0.6, 0.3),
			CFrame = frame * CFrame.new(0, -BOX_HEIGHT / 2 + BELT_THICKNESS + mouthHeight + 0.8, mouth.z * (BOX_LENGTH / 2 + 0.2)),
			Color = mouth.colour,
			Material = Enum.Material.Neon,
			CanCollide = false,
			CanQuery = false,
			CanTouch = false,
		})
	end
end

-- Builds the conveyor once. Safe to call again: an up-to-date build is
-- left alone, and an older one is replaced.
function Conveyor.Build()
	local existing = workspace:FindFirstChild(FOLDER_NAME)
	if existing then
		if existing:GetAttribute("Version") == VERSION then
			return existing
		end
		existing:Destroy()
	end

	local folder = Instance.new("Folder")
	folder.Name = FOLDER_NAME
	folder:SetAttribute("Version", VERSION)
	folder:SetAttribute("Speed", Conveyor.SPEED)
	folder:SetAttribute("TextureTile", Conveyor.TEXTURE_TILE)
	buildBelt(folder)
	buildBox(folder)
	folder.Parent = workspace
	return folder
end

return Conveyor
