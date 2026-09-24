--[[
	RaceTrack (ModuleScript, ServerStorage) — Junkyard Fusion

	The Race Wars area: a lobby, then one long straight track split into
	themed levels (RaceConfig.Levels), each ending in a gate. Built far
	from the Junkyard, where the Junkyard's distance fog hides it.

	This module owns the geometry and the maths for where things are on
	it. RaceService owns the races run on it.

	Positions on the track are a distance and a sideways offset: distance 0
	is the start line and grows toward the finish, and the offset is
	studs to the right of the centre line (seen driving forward). The
	lobby is at negative distances, behind the start line.

	Built at server start into its own Workspace folder, idempotent by
	VERSION like the yard conveyor.
--]]

local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RaceConfig = require(ReplicatedStorage:WaitForChild("RaceConfig"))

local Track = {}

-- Start line centre, on the floor. Well past the Junkyard's fog.
Track.ORIGIN = Vector3.new(-2600, 0, 0)
-- Drivable width between the walls.
Track.WIDTH = 72
Track.Length = #RaceConfig.Levels * RaceConfig.LEVEL_LENGTH

local WALL_HEIGHT = 46
local WALL_THICKNESS = 6
local LOBBY_DEPTH = 150
local LOBBY_WIDTH = 150
-- The run-out past the last gate, where a winning car rolls to a stop.
local FINISH_DEPTH = 160

local FOLDER_NAME = "RaceWars"
-- Bump when the geometry changes, so a stale build is replaced.
local VERSION = 2

-- White and light grey squares, tinted per level (assets/race-wars).
local CHECKER = "rbxassetid://126970654411709"

-- Collision groups: race cars pass through each other and through the
-- lobby's start-line gate, which keeps everyone on foot off the track.
Track.CAR_GROUP = "RaceCar"
local GATE_GROUP = "RaceGate"

-- Facing down the track: forward is world -Z, right is world +X.
local FRAME = CFrame.new(Track.ORIGIN)

function Track.PointAt(distance, offset, height)
	return FRAME * Vector3.new(offset or 0, height or 0, -distance)
end

-- A position's distance along the track and its offset from the centre.
function Track.DistanceOf(position)
	local p = FRAME:PointToObjectSpace(position)
	return -p.Z, p.X
end

-- The way the track runs, as a rotation.
Track.Heading = FRAME.Rotation

function Track.InLobby(position)
	local distance, offset = Track.DistanceOf(position)
	return distance <= 2 and distance >= -LOBBY_DEPTH
		and math.abs(offset) <= LOBBY_WIDTH / 2
		and position.Y > Track.ORIGIN.Y - 10 and position.Y < Track.ORIGIN.Y + 40
end

-- Where someone arriving in the lobby stands.
function Track.LobbySpawn()
	return CFrame.lookAt(Track.PointAt(-110, 0, 4), Track.PointAt(0, 0, 4))
end

-- The starting grid: four places across the track just past the line.
-- Cars never collide with each other, so a busy grid just shares places.
local GRID = { -24, -8, 8, 24 }
function Track.GridFrame(place)
	local offset = GRID[(place - 1) % #GRID + 1]
	return CFrame.new(Track.PointAt(10, offset, 0)) * Track.Heading
end

------------------------------------------------------------------
-- Looks
------------------------------------------------------------------

local function rgb(r, g, b) return Color3.fromRGB(r, g, b) end

-- floor, wall and trim colours per level theme, and what its obstacles
-- are built as.
local THEMES = {
	grass   = { floor = rgb(88, 206, 66),   wall = rgb(229, 132, 96),  trim = rgb(88, 184, 70),   trimNeon = false, obstacle = "bush" },
	desert  = { floor = rgb(238, 205, 132), wall = rgb(214, 160, 96),  trim = rgb(248, 226, 170), trimNeon = false, obstacle = "cactus" },
	snow    = { floor = rgb(232, 242, 250), wall = rgb(140, 184, 226), trim = rgb(255, 255, 255), trimNeon = false, obstacle = "ice" },
	volcano = { floor = rgb(84, 70, 68),    wall = rgb(116, 52, 42),   trim = rgb(255, 112, 36),  trimNeon = true,  obstacle = "lava" },
	neon    = { floor = rgb(40, 32, 66),    wall = rgb(66, 36, 120),   trim = rgb(0, 255, 222),   trimNeon = true,  obstacle = "neon" },
}

local function part(parent, props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Material = Enum.Material.SmoothPlastic
	for key, value in pairs(props) do
		p[key] = value
	end
	p.Parent = parent
	return p
end

local function checker(p, face, colour, tile)
	local t = Instance.new("Texture")
	t.Name = "Checker"
	t.Texture = CHECKER
	t.Face = face
	t.Color3 = colour
	t.StudsPerTileU = tile
	t.StudsPerTileV = tile
	t.Parent = p
	return t
end

-- A box on the track floor at a distance/offset, `size` as (across, up,
-- along).
local function box(parent, distance, offset, size, props)
	props.Size = size
	props.CFrame = CFrame.new(Track.PointAt(distance, offset, size.Y / 2)) * Track.Heading
	return part(parent, props)
end

-- Text on the face drivers see coming up the track (the +Z face).
local function sign(p, text, colour, stroke)
	local gui = Instance.new("SurfaceGui")
	gui.Face = Enum.NormalId.Back
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	-- Low enough that TextScaled's 100-pixel cap still fills the board.
	gui.PixelsPerStud = 8
	gui.LightInfluence = 0
	gui.Parent = p
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = colour
	label.Parent = gui
	local outline = Instance.new("UIStroke")
	outline.Color = stroke
	outline.Thickness = 6
	outline.Parent = label
	return label
end

------------------------------------------------------------------
-- Obstacles, one builder per theme. Each takes the level folder, a
-- distance, an offset, a footprint width and a Random, and builds
-- something solid about that wide.
------------------------------------------------------------------

local OBSTACLES = {}

-- Blocky hedges, like the reference's: a wide base with smaller blocks
-- stacked off-centre on top.
function OBSTACLES.bush(folder, distance, offset, width, rng)
	local depth = rng:NextNumber(7, 11)
	local green = rgb(64, 170, 52)
	box(folder, distance, offset, Vector3.new(width, 6, depth),
		{ Name = "Hedge", Color = green, Material = Enum.Material.Grass })
	local topWidth = width * rng:NextNumber(0.45, 0.65)
	local shift = (width - topWidth) / 2 * (rng:NextNumber() < 0.5 and -1 or 1)
	local top = box(folder, distance + rng:NextNumber(-1, 1), offset + shift,
		Vector3.new(topWidth, 5, depth * 0.8), { Name = "Hedge", Color = green:Lerp(rgb(120, 210, 80), 0.25), Material = Enum.Material.Grass })
	top.CFrame += Vector3.new(0, 6, 0)
end

-- A sandstone slab with a cactus standing on it.
function OBSTACLES.cactus(folder, distance, offset, width, rng)
	local stone = rgb(222, 178, 110)
	box(folder, distance, offset, Vector3.new(width, 4, rng:NextNumber(7, 10)),
		{ Name = "Sandstone", Color = stone, Material = Enum.Material.Sandstone })
	local green = rgb(72, 150, 70)
	local stemX = offset + rng:NextNumber(-width / 4, width / 4)
	local stem = box(folder, distance, stemX, Vector3.new(3, 14, 3), { Name = "Cactus", Color = green, Material = Enum.Material.Grass })
	stem.CFrame += Vector3.new(0, 4, 0)
	for _, side in ipairs({ -1, 1 }) do
		local arm = box(folder, distance, stemX + side * 3, Vector3.new(3, 6, 2.5), { Name = "Cactus", Color = green, Material = Enum.Material.Grass })
		arm.CFrame += Vector3.new(0, 8 + side, 0)
	end
end

-- A block of ice with a snow cap.
function OBSTACLES.ice(folder, distance, offset, width, rng)
	local depth = rng:NextNumber(7, 10)
	local height = rng:NextNumber(7, 10)
	box(folder, distance, offset, Vector3.new(width, height, depth),
		{ Name = "IceBlock", Color = rgb(170, 220, 250), Material = Enum.Material.Ice, Transparency = 0.15 })
	local cap = box(folder, distance, offset, Vector3.new(width + 0.6, 1.4, depth + 0.6),
		{ Name = "SnowCap", Color = rgb(250, 252, 255), Material = Enum.Material.Snow })
	cap.CFrame += Vector3.new(0, height, 0)
end

-- A basalt boulder with a glowing seam of lava across it.
function OBSTACLES.lava(folder, distance, offset, width, rng)
	local depth = rng:NextNumber(7, 11)
	local height = rng:NextNumber(6, 9)
	local rock = box(folder, distance, offset, Vector3.new(width, height, depth),
		{ Name = "Basalt", Color = rgb(52, 46, 48), Material = Enum.Material.Basalt })
	rock.CFrame *= CFrame.Angles(0, rng:NextNumber(-0.25, 0.25), 0)
	local seam = box(folder, distance, offset, Vector3.new(width + 0.2, 0.8, depth + 0.2),
		{ Name = "LavaSeam", Color = rgb(255, 110, 30), Material = Enum.Material.Neon, CanCollide = false })
	seam.CFrame = rock.CFrame * CFrame.new(0, height * 0.1, 0)
end

-- A dark barrier with glowing edges.
function OBSTACLES.neon(folder, distance, offset, width, rng)
	local height = rng:NextNumber(5, 7)
	local glow = rng:NextNumber() < 0.5 and rgb(0, 255, 222) or rgb(255, 60, 200)
	box(folder, distance, offset, Vector3.new(width, height, 4),
		{ Name = "Barrier", Color = rgb(28, 22, 44), Material = Enum.Material.SmoothPlastic })
	local edge = box(folder, distance, offset, Vector3.new(width + 0.3, 0.8, 4.3),
		{ Name = "BarrierGlow", Color = glow, Material = Enum.Material.Neon, CanCollide = false })
	edge.CFrame += Vector3.new(0, height - 0.4, 0)
end

------------------------------------------------------------------
-- Building
------------------------------------------------------------------

local function ensureCollisionGroups()
	for _, name in ipairs({ Track.CAR_GROUP, GATE_GROUP }) do
		if not PhysicsService:IsCollisionGroupRegistered(name) then
			PhysicsService:RegisterCollisionGroup(name)
		end
	end
	PhysicsService:CollisionGroupSetCollidable(Track.CAR_GROUP, Track.CAR_GROUP, false)
	PhysicsService:CollisionGroupSetCollidable(Track.CAR_GROUP, GATE_GROUP, false)
end

-- A gate across the track: a pillar against each wall and a banner over
-- the top, with a chequered line on the floor.
local function buildGate(folder, distance, text, colour)
	local half = Track.WIDTH / 2
	for _, side in ipairs({ -1, 1 }) do
		box(folder, distance, side * (half - 2), Vector3.new(4, 34, 4),
			{ Name = "GatePillar", Color = rgb(40, 40, 46) })
	end
	local banner = box(folder, distance, 0, Vector3.new(Track.WIDTH, 8, 2),
		{ Name = "GateBanner", Color = rgb(30, 30, 36) })
	banner.CFrame += Vector3.new(0, 26, 0)
	sign(banner, text, colour, rgb(10, 10, 14))

	local squares = 12
	local size = Track.WIDTH / squares
	for row = 0, 1 do
		for i = 0, squares - 1 do
			local white = (i + row) % 2 == 0
			local square = box(folder, distance + (row - 0.5) * size, -half + (i + 0.5) * size,
				Vector3.new(size, 0.1, size), { Name = "FinishLine", Color = white and rgb(245, 245, 245) or rgb(24, 24, 28),
					CanCollide = false, CanQuery = false })
			square.CFrame += Vector3.new(0, 0.05, 0)
		end
	end
end

local function buildLevel(root, index, level)
	local theme = THEMES[level.theme] or THEMES.grass
	local folder = Instance.new("Folder")
	folder.Name = string.format("Level%d_%s", index, (level.name:gsub("%s", "")))
	folder.Parent = root

	local length = RaceConfig.LEVEL_LENGTH
	local start = (index - 1) * length
	local middle = start + length / 2
	local half = Track.WIDTH / 2

	local floor = part(folder, {
		Name = "Floor",
		Size = Vector3.new(Track.WIDTH + WALL_THICKNESS * 2, 4, length),
		CFrame = CFrame.new(Track.PointAt(middle, 0, -2)) * Track.Heading,
		Color = theme.floor,
	})
	checker(floor, Enum.NormalId.Top, theme.floor, 24)

	for _, side in ipairs({ -1, 1 }) do
		local wall = part(folder, {
			Name = "Wall",
			Size = Vector3.new(WALL_THICKNESS, WALL_HEIGHT, length),
			CFrame = CFrame.new(Track.PointAt(middle, side * (half + WALL_THICKNESS / 2), WALL_HEIGHT / 2)) * Track.Heading,
			Color = theme.wall,
		})
		-- Only the face toward the track: +X for the left wall, -X for the right.
		checker(wall, side < 0 and Enum.NormalId.Right or Enum.NormalId.Left, theme.wall, 24)
		part(folder, {
			Name = "WallTrim",
			Size = Vector3.new(WALL_THICKNESS + 1, 3, length),
			CFrame = CFrame.new(Track.PointAt(middle, side * (half + WALL_THICKNESS / 2), WALL_HEIGHT + 1.5)) * Track.Heading,
			Color = theme.trim,
			Material = theme.trimNeon and Enum.Material.Neon or Enum.Material.Grass,
		})
	end

	-- Obstacles in rows, more of them each level, and from level two some
	-- rows have two. Every row leaves a gap at least GAP studs wide, so
	-- there is always a way through.
	local build = OBSTACLES[theme.obstacle] or OBSTACLES.bush
	local rng = Random.new(index * 7919)
	local rows = 10 + index * 3
	-- Level 1 gives you a clear run off the grid to get up to speed.
	local first, last = start + (index == 1 and 160 or 80), start + length - 60
	local spacing = (last - first) / rows
	local GAP = 22
	for row = 1, rows do
		local distance = first + (row - 0.5) * spacing + rng:NextNumber(-spacing, spacing) * 0.25
		local gapCentre = rng:NextNumber(-half + GAP / 2 + 4, half - GAP / 2 - 4)
		local sides = {
			{ from = -half + 2, to = gapCentre - GAP / 2 },
			{ from = gapCentre + GAP / 2, to = half - 2 },
		}
		local count = (index > 1 and rng:NextNumber() < 0.55) and 2 or 1
		for n = 1, count do
			local width = rng:NextNumber(10, 16)
			local space = sides[(row + n) % 2 + 1]
			if space.to - space.from < width then
				space = sides[(row + n + 1) % 2 + 1]
			end
			if space.to - space.from >= width then
				local offset = rng:NextNumber(space.from + width / 2, space.to - width / 2)
				build(folder, distance, offset, width, rng)
			end
		end
	end

	local nextLevel = RaceConfig.Levels[index + 1]
	local gateText = nextLevel and string.format("LEVEL %d · %s", index + 1, string.upper(nextLevel.name)) or "FINISH!"
	buildGate(folder, start + length, gateText, theme.trim)
end

local function buildLobby(root)
	local folder = Instance.new("Folder")
	folder.Name = "Lobby"
	folder.Parent = root

	local floor = part(folder, {
		Name = "LobbyFloor",
		Size = Vector3.new(LOBBY_WIDTH, 4, LOBBY_DEPTH),
		CFrame = CFrame.new(Track.PointAt(-LOBBY_DEPTH / 2, 0, -2)) * Track.Heading,
		Color = rgb(58, 60, 66),
	})
	checker(floor, Enum.NormalId.Top, rgb(66, 68, 76), 20)

	-- Low walls on three sides, and across the front either side of the
	-- track mouth.
	local wallColour = rgb(214, 44, 44)
	local function wall(distance, offset, width, depth)
		part(folder, {
			Name = "LobbyWall",
			Size = Vector3.new(width, 22, depth),
			CFrame = CFrame.new(Track.PointAt(distance, offset, 11)) * Track.Heading,
			Color = wallColour,
		})
	end
	wall(-LOBBY_DEPTH / 2, -LOBBY_WIDTH / 2 - 2, 4, LOBBY_DEPTH)
	wall(-LOBBY_DEPTH / 2, LOBBY_WIDTH / 2 + 2, 4, LOBBY_DEPTH)
	wall(-LOBBY_DEPTH - 2, 0, LOBBY_WIDTH + 8, 4)
	local mouth = Track.WIDTH / 2 + WALL_THICKNESS
	local sideWidth = LOBBY_WIDTH / 2 - mouth
	for _, side in ipairs({ -1, 1 }) do
		wall(-2, side * (mouth + sideWidth / 2), sideWidth, 4)
	end

	-- The start-line gate: solid to anyone on foot, open to race cars.
	local gate = part(folder, {
		Name = "StartGate",
		Size = Vector3.new(Track.WIDTH + WALL_THICKNESS * 2, 40, 2),
		CFrame = CFrame.new(Track.PointAt(-1, 0, 20)) * Track.Heading,
		Transparency = 1,
		CollisionGroup = GATE_GROUP,
	})
	gate.CanQuery = false

	-- The big sign over the track mouth.
	local signBoard = part(folder, {
		Name = "RaceWarsSign",
		Size = Vector3.new(Track.WIDTH + 20, 16, 3),
		CFrame = CFrame.new(Track.PointAt(-4, 0, 40)) * Track.Heading,
		Color = rgb(24, 24, 28),
	})
	sign(signBoard, "RACE WARS", rgb(255, 255, 255), rgb(214, 44, 44))

	-- The garage kiosk, where you pick a car and start a race.
	local kiosk = part(folder, {
		Name = "RaceGarage",
		Size = Vector3.new(14, 10, 8),
		CFrame = CFrame.new(Track.PointAt(-60, -36, 5)) * Track.Heading * CFrame.Angles(0, math.rad(-35), 0),
		Color = rgb(40, 40, 46),
	})
	local awning = part(folder, {
		Name = "GarageAwning",
		Size = Vector3.new(16, 1, 10),
		CFrame = kiosk.CFrame * CFrame.new(0, 5.5, 1),
		Color = rgb(214, 44, 44),
	})
	awning.CanCollide = false
	local kioskSign = part(folder, {
		Name = "GarageSign",
		Size = Vector3.new(14, 3, 0.4),
		CFrame = kiosk.CFrame * CFrame.new(0, 7.8, 3.9),
		Color = rgb(24, 24, 28),
	})
	kioskSign.CanCollide = false
	sign(kioskSign, "GARAGE", rgb(255, 255, 255), rgb(24, 24, 28))
	local pick = Instance.new("ProximityPrompt")
	pick.Name = "ChooseCar"
	pick.ActionText = "Choose Car"
	pick.ObjectText = "Race Garage"
	pick.HoldDuration = 0
	pick.MaxActivationDistance = 14
	pick.RequiresLineOfSight = false
	pick.Parent = kiosk

	-- The way home.
	local exit = part(folder, {
		Name = "RaceExit",
		Size = Vector3.new(12, 14, 2),
		CFrame = CFrame.new(Track.PointAt(-LOBBY_DEPTH + 4, 0, 7)) * Track.Heading,
		Color = rgb(88, 206, 66),
		Material = Enum.Material.Neon,
		Transparency = 0.35,
	})
	exit.CanCollide = false
	local home = Instance.new("ProximityPrompt")
	home.Name = "GoHome"
	home.ActionText = "Back to Junkyard"
	home.ObjectText = "Exit"
	home.HoldDuration = 0
	home.MaxActivationDistance = 12
	home.RequiresLineOfSight = false
	home.Parent = exit
end

local function buildFinish(root)
	local folder = Instance.new("Folder")
	folder.Name = "Finish"
	folder.Parent = root
	local middle = Track.Length + FINISH_DEPTH / 2
	local floor = part(folder, {
		Name = "FinishFloor",
		Size = Vector3.new(Track.WIDTH + WALL_THICKNESS * 2, 4, FINISH_DEPTH),
		CFrame = CFrame.new(Track.PointAt(middle, 0, -2)) * Track.Heading,
		Color = rgb(255, 204, 60),
	})
	checker(floor, Enum.NormalId.Top, rgb(255, 204, 60), 24)
	for _, side in ipairs({ -1, 1 }) do
		part(folder, {
			Name = "Wall",
			Size = Vector3.new(WALL_THICKNESS, WALL_HEIGHT, FINISH_DEPTH),
			CFrame = CFrame.new(Track.PointAt(middle, side * (Track.WIDTH / 2 + WALL_THICKNESS / 2), WALL_HEIGHT / 2)) * Track.Heading,
			Color = rgb(40, 40, 46),
		})
	end
	part(folder, {
		Name = "EndWall",
		Size = Vector3.new(Track.WIDTH + WALL_THICKNESS * 2, WALL_HEIGHT, WALL_THICKNESS),
		CFrame = CFrame.new(Track.PointAt(Track.Length + FINISH_DEPTH + WALL_THICKNESS / 2, 0, WALL_HEIGHT / 2)) * Track.Heading,
		Color = rgb(40, 40, 46),
	})
end

-- Builds the area once. Safe to call again: an up-to-date build is left
-- alone, and an older one is replaced.
function Track.Build()
	ensureCollisionGroups()
	local existing = workspace:FindFirstChild(FOLDER_NAME)
	if existing then
		if existing:GetAttribute("Version") == VERSION then
			return existing
		end
		existing:Destroy()
	end

	local root = Instance.new("Model")
	root.Name = FOLDER_NAME
	root:SetAttribute("Version", VERSION)
	-- Where the area is, for clients (RaceDrive opens up the fog there).
	root:SetAttribute("Origin", Track.ORIGIN)
	root:SetAttribute("Length", Track.Length + FINISH_DEPTH)
	root:SetAttribute("LobbyDepth", LOBBY_DEPTH)
	root:SetAttribute("Width", LOBBY_WIDTH)
	-- The whole area stays loaded if streaming is ever turned on: a car at
	-- 100 studs a second outruns streaming.
	root.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	buildLobby(root)
	for index, level in ipairs(RaceConfig.Levels) do
		buildLevel(root, index, level)
	end
	buildFinish(root)
	root.Parent = workspace
	return root
end

-- The lobby's two prompts, for RaceService to connect.
function Track.Prompts()
	local root = workspace:FindFirstChild(FOLDER_NAME)
	local lobby = root and root:FindFirstChild("Lobby")
	return lobby and lobby.RaceGarage.ChooseCar, lobby and lobby.RaceExit.GoHome
end

return Track
