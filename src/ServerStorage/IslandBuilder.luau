--[[
	IslandBuilder (ModuleScript, ServerStorage) — Junkyard Fusion

	Shared world-building scaffold so every non-Junkyard island (Brainrot
	Island, and whatever comes after it) gets the same underlying
	structure — a ground plate, a boundary ring of bollards+lamps marking
	the play area's edge, scattered decorative clusters, and a couple of
	bigger hand-placed landmarks — with only the THEME (colors, what a
	"cluster" or "landmark" actually looks like) changing per island.
	Mirrors the shape of MapRevamp.luau's Map.DressYard (bollard ring +
	lamp posts + scattered clutter around a defined play radius), just
	generalized to take a theme instead of being Junkyard-specific.

	This module only builds GEOMETRY. Mechanics — fusion pads, spawners,
	gates, ProximityPrompts, what's actually collectible — stay in each
	island's own script (BrainrotService.luau, etc.), which calls
	IslandBuilder.Build once and then attaches its own mechanics using
	the returned folder/center/radius as anchors. Don't add mechanics
	here; an island with different rules (a shared pad vs. per-player
	plots, say) should never have to fight this module's assumptions.
--]]

local IslandBuilder = {}

local function part(props)
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = props.CanCollide == true
	p.CanTouch = false
	for key, value in pairs(props) do
		p[key] = value
	end
	return p
end

local function light(p, color, brightness, range)
	local pointLight = Instance.new("PointLight")
	pointLight.Color = color
	pointLight.Brightness = brightness
	pointLight.Range = range
	pointLight.Shadows = false
	pointLight.Parent = p
end

--[[
	theme = {
		name = string,               -- folder name; also what a rebuild looks for to destroy the old copy
		center = Vector3,
		groundRadius = number,       -- half-width of the actual walkable/spawnable play area
		groundColor = Color3,
		groundMaterial = Enum.Material?,
		ringColors = {Color3, ...},  -- cycled around the bollard ring and the scattered clusters
		lampColor = Color3?,
		clusterCount = number?,
		buildCluster = function(cf: CFrame, color: Color3, parent: Instance, rng: Random)?,
		landmarks = { {position = Vector3 (offset from center), build = function(cf: CFrame, parent: Instance)}, ... }?,
		seed = number?,               -- Random seed for the cluster scatter; keep it fixed so a rebuild is deterministic
	}

	Returns {folder, center, groundRadius, ringRadius, outerRadius} — the
	caller's anchors for its own pad/gate/spawn-field placement.
]]
function IslandBuilder.Build(theme)
	local folder = Instance.new("Folder")
	folder.Name = theme.name
	folder.Parent = workspace

	local center = theme.center
	local groundRadius = theme.groundRadius
	local ringRadius = groundRadius + 12
	local outerRadius = groundRadius + 28

	part({
		Name = "Ground",
		Size = Vector3.new(outerRadius * 2, 1, outerRadius * 2),
		Position = center,
		Material = theme.groundMaterial or Enum.Material.SmoothPlastic,
		Color = theme.groundColor,
		Parent = folder,
	})

	-- Boundary ring: bollards mark exactly where the walkable play area
	-- ends; lamps a bit further out light the edge without crowding it.
	local ringColors = theme.ringColors or { theme.groundColor }
	for i = 0, 15 do
		local a = i * math.pi / 8
		local pos = center + Vector3.new(math.cos(a) * ringRadius, 0, math.sin(a) * ringRadius)
		local col = ringColors[(i % #ringColors) + 1]
		part({
			Name = "IslandBollard", Size = Vector3.new(1.6, 3.2, 1.6),
			Position = pos + Vector3.new(0, 1.6, 0), Material = Enum.Material.Neon,
			Color = col, Parent = folder,
		})
	end
	for i = 0, 7 do
		local a = (i + 0.5) * math.pi / 4
		local pos = center + Vector3.new(math.cos(a) * outerRadius, 0, math.sin(a) * outerRadius)
		part({
			Name = "IslandLampPost", Size = Vector3.new(0.9, 16, 0.9),
			Position = pos + Vector3.new(0, 8, 0), Material = Enum.Material.Metal,
			Color = Color3.fromRGB(40, 44, 48), Parent = folder,
		})
		local head = part({
			Name = "IslandLampHead", Size = Vector3.new(2, 1, 2),
			Position = pos + Vector3.new(0, 16.2, 0), Material = Enum.Material.Neon,
			Color = theme.lampColor or Color3.new(1, 1, 1), Parent = folder,
		})
		light(head, theme.lampColor or Color3.new(1, 1, 1), 0.5, 45)
	end

	-- Scattered decorative clusters between the play area and the ring —
	-- the island's actual "scenery," fully theme-defined.
	if theme.buildCluster then
		local rng = Random.new(theme.seed or 1)
		local count = theme.clusterCount or 10
		for i = 0, count - 1 do
			local a = i * (math.pi * 2 / count) + rng:NextNumber(-0.08, 0.08)
			local dist = rng:NextNumber(groundRadius + 2, ringRadius - 4)
			local pos = center + Vector3.new(math.cos(a) * dist, 0, math.sin(a) * dist)
			local col = ringColors[(i % #ringColors) + 1]
			theme.buildCluster(CFrame.new(pos), col, folder, rng)
		end
	end

	-- Landmarks: a handful of bigger, hand-placed structures at exact
	-- positions — what makes an island feel like a built place rather
	-- than a decorated field.
	for _, landmark in ipairs(theme.landmarks or {}) do
		landmark.build(CFrame.new(center + landmark.position), folder)
	end

	return {
		folder = folder,
		center = center,
		groundRadius = groundRadius,
		ringRadius = ringRadius,
		outerRadius = outerRadius,
	}
end

-- A straight walkway between two points, wide and flat — the same
-- stretched-part-via-lookAt shape MapRevamp.luau's own `beam` helper
-- uses for roads and structural members. Kept generic (not tied to any
-- one island's palette) so every island's own script can lay its own
-- paths between its pad, sign and landmarks after building them.
function IslandBuilder.Path(a, b, width, color, parent)
	local mid = (a + b) / 2
	return part({
		Name = "IslandPath",
		Size = Vector3.new(width, 0.2, (a - b).Magnitude),
		CFrame = CFrame.lookAt(mid, b),
		Material = Enum.Material.Concrete,
		Color = color,
		Parent = parent,
	})
end

return IslandBuilder
