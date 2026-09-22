--[[
	YardFeatures (ModuleScript, ServerStorage) — Junkyard Fusion

	Gives the scrap yard some shape: a magnet crane in the middle, and a
	ring of climbable junk piles and container stacks between the gate
	lanes. Before this the yard was a flat parking lot with a few oil
	drums, so every chase was a straight line and there was nothing to
	climb, hide behind or fight over.

	Its own module rather than more of MapRevamp so it can be rebuilt on its
	own: bump VERSION and the next server start tears the old set down and
	builds the new one. It is blockout geometry with real materials — laid
	out for play first, so any piece can be swapped for a finished model
	later without moving anything.

	The positions below were picked against three rules:
	- nothing within 13 studs of the eight gate lanes, so every road still
	  opens onto clear asphalt;
	- clear of the 20 oil drums already in the yard;
	- nothing between the crane's legs and radius 25, which is the ring the
	  Crane Drop event lands in (ScrapSpawner finds the crane by name).
--]]

local YardFeatures = {}

YardFeatures.VERSION = 1
YardFeatures.FOLDER_NAME = "YardFeatures"
-- How far out from the tower the magnet hangs. Crane Drop crates land
-- directly under it, so this is also the radius of the drop ring.
YardFeatures.CRANE_REACH = 20
-- Top of the YardAsphalt slab everything stands on.
YardFeatures.GROUND_Y = 1.2
-- Tallest walkable top anything here has. ScrapSpawner refuses to drop
-- items onto anything higher, which keeps them off gate lintels and the
-- crane while still letting them land on piles and container roofs.
YardFeatures.MAX_STAND_HEIGHT = 14.5

local G = YardFeatures.GROUND_Y
local REACH = YardFeatures.CRANE_REACH

local V = Vector3.new
local CF = CFrame.new
local RGB = Color3.fromRGB

local CRANE_YELLOW = RGB(242, 190, 40)
local CRANE_DARK = RGB(46, 46, 54)
local CAR_COLOURS = {
	RGB(156, 78, 52),   -- rust red
	RGB(58, 118, 128),  -- faded teal
	RGB(176, 142, 62),  -- ochre
	RGB(84, 96, 136),   -- dull blue
	RGB(120, 128, 78),  -- olive
	RGB(128, 122, 118), -- primer grey
	RGB(192, 104, 48),  -- orange
}
local CONTAINER_COLOURS = {
	RGB(186, 72, 50),
	RGB(46, 110, 142),
	RGB(208, 150, 44),
	RGB(70, 132, 88),
}

-- Eight spots, one per wedge between gate lanes, alternating pile and
-- container stack so no two neighbours are the same kind of thing.
local SPOTS = {
	{ kind = "pile",      x = 51.3,  z = 13.3 },
	{ kind = "container", x = 20.9,  z = 50.4 },
	{ kind = "pile",      x = -13.0, z = 31.4 },
	{ kind = "container", x = -53.7, z = 13.9 },
	{ kind = "pile",      x = -47.8, z = -28.2 },
	{ kind = "container", x = -13.2, z = -31.9 },
	{ kind = "pile",      x = 13.0,  z = -31.4 },
	{ kind = "container", x = 31.4,  z = -13.0 },
}

local RUBBER = Enum.Material.SmoothPlastic
pcall(function() RUBBER = Enum.Material.Rubber end)

local function block(parent, name, size, cframe, colour, material, props)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cframe
	p.Color = colour
	p.Material = material or Enum.Material.Metal
	p.Anchored = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if props then
		for key, value in pairs(props) do
			p[key] = value
		end
	end
	p.Parent = parent
	return p
end

-- A bar running from a to b.
local function strut(parent, name, a, b, thickness, colour, props)
	local length = (b - a).Magnitude
	return block(parent, name, V(thickness, thickness, length),
		CFrame.lookAt((a + b) / 2, b), colour, Enum.Material.Metal, props)
end

-- A short stack of tyres, lying flat.
local function tyres(parent, pos, count)
	for i = 1, count do
		block(parent, "Tyre", V(1.3, 3.6, 3.6),
			CF(pos + V(0, G + 0.65 + (i - 1) * 1.3 - pos.Y, 0)) * CFrame.Angles(0, 0, math.rad(90)),
			RGB(34, 34, 38), RUBBER, { Shape = Enum.PartType.Cylinder })
	end
end

------------------------------------------------------------------
-- Junk pile: three crushed-car blocks stacked like steps, each 3 studs
-- up from the last, so it is a climb with a lookout on top.
------------------------------------------------------------------

local function junkPile(parent, pos, rng)
	local model = Instance.new("Model")
	model.Name = "JunkPile"
	model.Parent = parent

	local yaw = rng:NextNumber(0, math.pi * 2)
	local frame = CF(pos.X, 0, pos.Z) * CFrame.Angles(0, yaw, 0)
	local tiers = {
		{ size = V(12, 3, 9), x = 0, z = 0 },
		{ size = V(9, 3, 7), x = -1.4, z = 0.9 },
		{ size = V(6.5, 3, 5), x = -2.6, z = 1.5 },
	}
	for i, tier in ipairs(tiers) do
		local y = G + (i - 1) * 3 + 1.5
		local wobble = CFrame.Angles(0, math.rad(rng:NextNumber(-10, 10)), 0)
		local cf = frame * CF(tier.x, y, tier.z) * wobble
		local car = block(model, "CrushedCar", tier.size, cf,
			CAR_COLOURS[rng:NextInteger(1, #CAR_COLOURS)], Enum.Material.CorrodedMetal)
		-- A squashed windscreen band across each block, so they read as
		-- cars that went through the crusher rather than plain crates.
		block(model, "Windscreen", V(tier.size.X * 0.55, 0.5, tier.size.Z + 0.1),
			car.CFrame * CF(tier.size.X * 0.12, 0.35, 0), RGB(120, 170, 190), Enum.Material.Glass,
			{ Transparency = 0.25, CanCollide = false, CanQuery = false })
	end

	-- A tyre stack at the foot: one easy hop before the first block.
	tyres(model, (frame * CF(7.5, 0, -4)).Position, 2)
	return model
end

------------------------------------------------------------------
-- Container stack: a shipping container lying side-on to the crane as a
-- wall of cover, a ramp up onto its roof, and a smaller container up there
-- to duck behind.
------------------------------------------------------------------

local function containerStack(parent, pos, rng)
	local model = Instance.new("Model")
	model.Name = "ContainerStack"
	model.Parent = parent

	-- Long side facing the crane: the container's X axis runs along the
	-- tangent of the ring, so it blocks sight lines across the yard.
	local angle = math.atan2(pos.Z, pos.X)
	local yaw = -(angle + math.pi / 2)
	local frame = CF(pos.X, 0, pos.Z) * CFrame.Angles(0, yaw, 0)

	local colourA = CONTAINER_COLOURS[rng:NextInteger(1, #CONTAINER_COLOURS)]
	local colourB = CONTAINER_COLOURS[rng:NextInteger(1, #CONTAINER_COLOURS)]

	local LENGTH, HEIGHT, DEPTH = 16, 7, 7
	local body = block(model, "Container", V(LENGTH, HEIGHT, DEPTH), frame * CF(0, G + HEIGHT / 2, 0),
		colourA, Enum.Material.CorrodedMetal)
	-- Corrugation ribs down both long faces.
	for x = -LENGTH / 2 + 1, LENGTH / 2 - 1, 1.4 do
		for _, side in ipairs({ -1, 1 }) do
			block(model, "Rib", V(0.35, HEIGHT - 0.6, 0.25),
				body.CFrame * CF(x, 0, side * (DEPTH / 2 + 0.1)), colourA:Lerp(RGB(0, 0, 0), 0.18),
				Enum.Material.Metal, { CanCollide = false, CanQuery = false })
		end
	end
	-- Door end: two panels and a pair of lock bars.
	for _, z in ipairs({ -1.7, 1.7 }) do
		block(model, "Door", V(0.2, HEIGHT - 0.8, 3.2), body.CFrame * CF(-LENGTH / 2 - 0.1, 0, z),
			colourA:Lerp(RGB(0, 0, 0), 0.1), Enum.Material.Metal, { CanCollide = false, CanQuery = false })
		block(model, "LockBar", V(0.3, HEIGHT - 1.4, 0.3), body.CFrame * CF(-LENGTH / 2 - 0.3, 0, z * 0.5),
			RGB(70, 70, 76), Enum.Material.Metal, { CanCollide = false, CanQuery = false })
	end

	-- Ramp off the far end, rising toward the container so it leads up
	-- onto the roof. A WedgePart is tallest at its +Z face; turning it so
	-- +Z points back along -X puts that tall face against the container.
	local RAMP_LENGTH = 11
	local ramp = Instance.new("WedgePart")
	ramp.Name = "Ramp"
	ramp.Size = V(5, HEIGHT, RAMP_LENGTH)
	ramp.CFrame = frame * CF(LENGTH / 2 + RAMP_LENGTH / 2, G + HEIGHT / 2, 0) * CFrame.Angles(0, -math.pi / 2, 0)
	ramp.Color = RGB(118, 92, 62)
	ramp.Material = Enum.Material.WoodPlanks
	ramp.Anchored = true
	ramp.Parent = model

	-- Smaller container on the roof, turned across, near the door end so
	-- the roof by the ramp stays open to stand on.
	block(model, "Container", V(6.5, 6, 9), frame * CF(-3.5, G + HEIGHT + 3, 0),
		colourB, Enum.Material.CorrodedMetal)

	tyres(model, (frame * CF(-LENGTH / 2 - 2.5, 0, -DEPTH / 2 - 2)).Position, 3)
	return model
end

------------------------------------------------------------------
-- Magnet crane: a four-legged lattice tower with a rotating arm. The
-- middle of the tower is open on purpose — the place's default spawn
-- pad sits right under it.
------------------------------------------------------------------

local function magnetCrane(parent)
	local model = Instance.new("Model")
	model.Name = "MagnetCrane"
	model.Parent = parent

	local HALF = 3.5
	local TOWER = 30
	local TOP = G + TOWER

	for _, sx in ipairs({ -HALF, HALF }) do
		for _, sz in ipairs({ -HALF, HALF }) do
			block(model, "Leg", V(1, TOWER, 1), CF(sx, G + TOWER / 2, sz), CRANE_YELLOW)
			block(model, "Foot", V(2.4, 0.6, 2.4), CF(sx, G + 0.3, sz), CRANE_DARK, Enum.Material.DiamondPlate)
		end
	end
	-- Lattice: a ring every 5 studs and a diagonal brace between each pair
	-- of rings on every face, alternating direction up the tower.
	local corners = { V(-HALF, 0, -HALF), V(HALF, 0, -HALF), V(HALF, 0, HALF), V(-HALF, 0, HALF) }
	local flip = false
	for y = G + 5, TOP - 2, 5 do
		for i = 1, 4 do
			local a, b = corners[i], corners[i % 4 + 1]
			strut(model, "Ring", a + V(0, y, 0), b + V(0, y, 0), 0.45, CRANE_YELLOW)
			if y + 5 <= TOP - 2 then
				local lowA, highB = flip and b or a, flip and a or b
				strut(model, "Brace", lowA + V(0, y, 0), highB + V(0, y + 5, 0), 0.35, CRANE_YELLOW)
			end
		end
		flip = not flip
	end
	block(model, "Turntable", V(9, 1.2, 9), CF(0, TOP + 0.6, 0), CRANE_DARK)

	-- Everything that swings lives in its own model so the arm can be
	-- turned with one PivotTo. The pivot sits on the tower's axis.
	local arm = Instance.new("Model")
	arm.Name = "Arm"
	arm.Parent = model
	local pivot = block(arm, "Pivot", V(1, 1, 1), CF(0, TOP + 1.7, 0), CRANE_DARK, Enum.Material.Metal,
		{ Transparency = 1 })
	arm.PrimaryPart = pivot

	block(arm, "Cab", V(5, 4, 5), CF(-1, TOP + 3.2, 0), CRANE_YELLOW)
	block(arm, "CabWindow", V(0.2, 2, 3.6), CF(1.55, TOP + 3.6, 0), RGB(140, 200, 230), Enum.Material.Glass,
		{ Transparency = 0.25 })
	block(arm, "Jib", V(REACH + 4, 1.4, 1.6), CF(REACH / 2, TOP + 5.6, 0), CRANE_YELLOW)
	block(arm, "CounterJib", V(9, 1.4, 1.6), CF(-6.5, TOP + 5.6, 0), CRANE_YELLOW)
	block(arm, "Counterweight", V(3.5, 3.5, 3.5), CF(-9.5, TOP + 3.9, 0), RGB(96, 96, 104), Enum.Material.Concrete)
	block(arm, "Mast", V(1.2, 6, 1.2), CF(0, TOP + 9.3, 0), CRANE_YELLOW)
	strut(arm, "TieLine", V(0, TOP + 12, 0), V(REACH, TOP + 6.3, 0), 0.22, CRANE_DARK)
	strut(arm, "TieLine", V(0, TOP + 12, 0), V(-10, TOP + 6.3, 0), 0.22, CRANE_DARK)

	block(arm, "Trolley", V(2.4, 1, 2.4), CF(REACH, TOP + 4.6, 0), CRANE_DARK)
	local CABLE = 14
	block(arm, "Cable", V(0.25, CABLE, 0.25), CF(REACH, TOP + 4.1 - CABLE / 2, 0), CRANE_DARK)
	local magnetY = TOP + 4.1 - CABLE - 0.8
	local magnet = block(arm, "Magnet", V(1.6, 5.5, 5.5), CF(REACH, magnetY, 0) * CFrame.Angles(0, 0, math.rad(90)),
		CRANE_DARK, Enum.Material.Metal, { Shape = Enum.PartType.Cylinder })
	block(arm, "MagnetRim", V(0.5, 6.1, 6.1), CF(REACH, magnetY + 0.95, 0) * CFrame.Angles(0, 0, math.rad(90)),
		CRANE_YELLOW, Enum.Material.Metal, { Shape = Enum.PartType.Cylinder })
	-- ScrapSpawner reads this to know where a crate starts its fall.
	magnet:SetAttribute("DropOrigin", true)

	-- The arm swings over people's heads: it must never collide with them
	-- or catch a raycast meant for the ground.
	for _, p in ipairs(arm:GetDescendants()) do
		if p:IsA("BasePart") then
			p.CanCollide = false
			p.CanQuery = false
			p.CanTouch = false
		end
	end
	arm:SetAttribute("Yaw", 0)
	return model
end

------------------------------------------------------------------

function YardFeatures.Find()
	return workspace:FindFirstChild(YardFeatures.FOLDER_NAME)
end

function YardFeatures.Build()
	local existing = YardFeatures.Find()
	if existing and existing:GetAttribute("Version") == YardFeatures.VERSION then
		return existing
	end
	if existing then
		existing:Destroy()
	end

	local folder = Instance.new("Folder")
	folder.Name = YardFeatures.FOLDER_NAME
	folder:SetAttribute("Version", YardFeatures.VERSION)

	magnetCrane(folder)
	-- Fixed seed: the yard looks the same every server, every restart.
	local rng = Random.new(20260921)
	for _, spot in ipairs(SPOTS) do
		local pos = V(spot.x, G, spot.z)
		if spot.kind == "pile" then
			junkPile(folder, pos, rng)
		else
			containerStack(folder, pos, rng)
		end
	end

	folder.Parent = workspace
	print("[Map] Yard features built.")
	return folder
end

return YardFeatures
