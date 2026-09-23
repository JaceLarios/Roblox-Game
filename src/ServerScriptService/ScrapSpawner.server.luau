local ItemNames = require(game:GetService("ReplicatedStorage"):WaitForChild("ItemNames"))
--[[
	ScrapSpawner (Script, ServerScriptService) — Junkyard Fusion v1
	Drops a random Tier 1 item into the yard every few seconds, and runs the
	yard's timed events: Crane Drop, Scrap Rush and Mutation Frenzy.
	Server-only on purpose: the server decides what spawns, never the client.
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")

local FusionRecipes = require(ReplicatedStorage:WaitForChild("FusionRecipes"))
local ItemVisuals = require(ReplicatedStorage:WaitForChild("ItemVisuals"))
local ItemRarity = require(ReplicatedStorage:WaitForChild("ItemRarity"))
local Mutations = require(ReplicatedStorage:WaitForChild("Mutations"))
local EventConfig = require(ReplicatedStorage:WaitForChild("EventConfig"))
local YardFeatures = require(ServerStorage:WaitForChild("YardFeatures"))

-- Shared with PlotManager and the client UI.
local remote = ReplicatedStorage:FindFirstChild("GameUpdate")
if not remote then
	remote = Instance.new("RemoteEvent")
	remote.Name = "GameUpdate"
	remote.Parent = ReplicatedStorage
end

-- ---------- Tuning knobs. Change these, not the code below. ----------
local SPAWN_INTERVAL = 3      -- seconds between drops
local DESPAWN_AFTER  = 40     -- seconds before an ignored item disappears
-- Hard cap on items lying in the yard at once. At one drop every 3 s,
-- each lasting 40 s, the yard sits right at it: about 13 items, down from
-- about 22 when this was 45 and drops came every 2 s.
local MAX_ITEMS      = 14
local AREA_CENTER    = Vector3.new(0, 1.2, 0)  -- Y is the yard's ground surface, not an item's center
local Layout = require(game.ReplicatedStorage:WaitForChild("JunkyardLayout"))

-- Golden Scrap removed 2026-09-14 ("its litteary worthless now, get rid
-- of the gold scrap idea in general") — its old role as "the exciting
-- thing to chase" is replaced below by just announcing it when the
-- regular roll itself lands on a naturally rare base item.
-- Anything this rare or rarer gets the same "come get it" broadcast
-- Golden Scrap used to have: the Monster Truck, the V8 and the Jet Engine.
local ANNOUNCE_RARITY = "mythic"

-- Hard ceiling on how many addons can be lying in the yard at once.
-- FusionRecipes.AddonSpawnChance sets the long-run rate; this stops the
-- short-run clumping a rate cannot. Four engines inside twenty drops is
-- unremarkable dice, and it reads as the yard being full of engines.
-- Three rather than two now that addons are 12% of drops, most of them
-- Nitrous Tanks.
local MAX_ACTIVE_ADDONS = 3

-- Per-item limits on the map at once, on top of MAX_ITEMS. The rare end
-- is what made the yard feel flooded: two V8s and a Jet Engine lying
-- around together cheapens all three. A roll that lands on something
-- already at its limit becomes a vehicle instead.
local MAX_ON_MAP = {
	["Jet Engine"] = 1,
	["V8 Engine"] = 1,
	["V6 Engine"] = 1,
	["Monster Truck"] = 1,
	["Inline 4"] = 2,
	["Nitrous Tank"] = 2,
}

-- Yard events. One every four to six minutes, never the same one twice in
-- a row, each announced EVENT_WARNING seconds ahead so people can get
-- into position.
local EVENT_FIRST_AFTER = 120
local EVENT_GAP_MIN, EVENT_GAP_MAX = 240, 360
local EVENT_WARNING = 10

-- Scrap Rush: drops twice as fast for a minute, with its own lower cap so
-- a rush fills the yard without burying it.
local RUSH_SECONDS = 60
local RUSH_INTERVAL = 1.5
local RUSH_MAX_ITEMS = 22

-- Mutation Frenzy: a quarter of drops land already mutated, and every
-- fusion rolls mutations at double odds (EventConfig's own multiplier).
local FRENZY_SECONDS = 90
local FRENZY_DROP_CHANCE = 0.25
local FRENZY_DROP_WEIGHTS = { shiny = 60, toxic = 25, golden = 10, frenzy = 3, cosmic = 2 }

-- Crane Drop: the crate only ever holds something rare or better, picked
-- by rarity rather than by spawn rate so a crate stays worth racing for.
-- The Jet Engine is still the least likely thing in it (about 1 crate in 36).
local CRATE_MIN_RARITY = "rare"
local CRATE_DESPAWN_AFTER = 60
local CRANE_SWING_SECONDS = 6
local CRATE_FALL_SECONDS = 1.1

-- Light pillar over anything worth racing for, in its rarity colour.
local BEAM_HEIGHT = 70
-- ---------------------------------------------------------------------

-- All spawned scrap lives in one folder. Keeps Explorer readable
-- and makes counting items trivial.
local scrapFolder = workspace:FindFirstChild("Scrap")
if not scrapFolder then
	scrapFolder = Instance.new("Folder")
	scrapFolder.Name = "Scrap"
	scrapFolder.Parent = workspace
end

local rushUntil = 0
local frenzyUntil = 0

local function announce(message)
	remote:FireAllClients({ announce = message })
end

local function weightedPick(pool, weightOf)
	local total = 0
	for _, entry in ipairs(pool) do
		total += weightOf(entry)
	end
	local roll = math.random() * total
	for _, entry in ipairs(pool) do
		roll -= weightOf(entry)
		if roll <= 0 then
			return entry
		end
	end
	return pool[#pool]
end

------------------------------------------------------------------
-- Where things land
------------------------------------------------------------------

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude

-- The height of whatever someone could stand on at (x, z): the asphalt,
-- a junk pile's top step, a container roof. Returns nil for anywhere an
-- item should not go — a slope, the crane, or something too high to reach
-- (gate lintels overhang the corners of the drop square).
local function surfaceY(x, z)
	local ignore = { scrapFolder }
	for _, player in ipairs(Players:GetPlayers()) do
		if player.Character then
			table.insert(ignore, player.Character)
		end
	end
	local features = YardFeatures.Find()
	local crane = features and features:FindFirstChild("MagnetCrane")
	if crane then
		table.insert(ignore, crane)
	end
	rayParams.FilterDescendantsInstances = ignore

	local hit = workspace:Raycast(Vector3.new(x, 80, z), Vector3.new(0, -100, 0), rayParams)
	if not hit or hit.Normal.Y < 0.95 then
		return nil
	end
	if hit.Position.Y > YardFeatures.GROUND_Y + YardFeatures.MAX_STAND_HEIGHT then
		return nil
	end
	return hit.Position.Y
end

-- Uniform-area circular drops give all eight radial bases the same
-- distribution of return distances (the old square favored diagonal directions).
local function randomSpawnPosition()
	for _ = 1, 8 do
		local angle = math.random() * math.pi * 2
		local radius = math.sqrt(math.random()) * Layout.SpawnRadius
		local x = AREA_CENTER.X + math.cos(angle) * radius
		local z = AREA_CENTER.Z + math.sin(angle) * radius
		-- The crane's legs stand inside this radius.
		if x * x + z * z > 49 then
			local y = surfaceY(x, z)
			if y then
				return Vector3.new(x, y, z)
			end
		end
	end
	return AREA_CENTER + Vector3.new(30, 0, 0)
end

------------------------------------------------------------------
-- What things look like
------------------------------------------------------------------

-- Colour for anything's name: a mutation's own colour when it has one,
-- otherwise the base item's rarity colour.
local function itemColour(itemName)
	local baseName, mutationId = Mutations.Unwrap(itemName)
	return Mutations.Color(mutationId)
		or ItemRarity.Color(FusionRecipes.GetTier(baseName), false, FusionRecipes.GetRarity(baseName))
end

local function itemTag(itemName)
	local baseName, mutationId = Mutations.Unwrap(itemName)
	if mutationId then
		return Mutations.Tag(itemName, mutationId)
	end
	return ItemRarity.Tag(baseName, FusionRecipes.GetTier(baseName), false, FusionRecipes.GetRarity(baseName))
end

-- Floating name tag so you can tell items apart while testing.
local function addLabel(part, itemName)
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.new(0, 150, 0, 32)
	billboard.StudsOffset = Vector3.new(0, 2, 0)
	billboard.AlwaysOnTop = true
	-- Billboards hold a constant SCREEN size regardless of distance, so
	-- without a cutoff every drop across the whole yard stays fully
	-- legible at once and piles into an unreadable wall of text.
	billboard.MaxDistance = 45
	billboard.Parent = part

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = ItemNames.Display(itemName)
	label.TextColor3 = itemColour(itemName)
	label.TextStrokeTransparency = 0.4
	label.TextScaled = true
	label.Parent = billboard
end

-- A tall pillar of light, visible from anywhere in the yard. Parented to
-- the item, so it disappears the moment the item is grabbed or despawns.
local function addBeam(part, colour)
	local base = part.Position.Y - part.Size.Y / 2
	local beam = Instance.new("Part")
	beam.Name = "RareBeam"
	beam.Shape = Enum.PartType.Cylinder
	beam.Size = Vector3.new(BEAM_HEIGHT, 1.1, 1.1)
	beam.CFrame = CFrame.new(part.Position.X, base + BEAM_HEIGHT / 2, part.Position.Z) * CFrame.Angles(0, 0, math.rad(90))
	beam.Anchored = true
	beam.CanCollide = false
	beam.CanQuery = false
	beam.CanTouch = false
	beam.CastShadow = false
	beam.Material = Enum.Material.Neon
	beam.Color = colour
	beam.Transparency = 0.45
	beam.Parent = part

	local light = Instance.new("PointLight")
	light.Color = colour
	light.Range = 18
	light.Brightness = 2
	light.Parent = beam
end

-- The rarest base items — Golden Scrap's old "worth announcing" role, now
-- just surfacing when the regular roll itself lands on something already
-- rare instead of a separate spawn type. Addons need no special case: the
-- rarity bar lands on the V8 and the Jet Engine and skips the Nitrous
-- Tank, Inline 4 and V6, which is the right line. At a drop every
-- SPAWN_INTERVAL seconds, announcing every addon would fire several times
-- a minute and stop meaning anything.
-- The top mutations count too, whatever they landed on.
local ANNOUNCE_MUTATIONS = { golden = true, cosmic = true, frenzy = true }
local function isRareRoll(itemName)
	local baseName, mutationId = Mutations.Unwrap(itemName)
	if mutationId and ANNOUNCE_MUTATIONS[mutationId] then
		return true
	end
	local rarity = FusionRecipes.GetRarity(baseName)
	return rarity ~= nil
		and FusionRecipes.RarityIndex[rarity] >= FusionRecipes.RarityIndex[ANNOUNCE_RARITY]
end

local function activeAddonCount()
	local live = 0
	for _, item in ipairs(scrapFolder:GetChildren()) do
		if item:GetAttribute("IsAddon") then
			live += 1
		end
	end
	return live
end

-- How many of this item (mutated or not) are lying in the yard right now.
local function liveCount(baseName)
	local live = 0
	for _, item in ipairs(scrapFolder:GetChildren()) do
		local name = item:GetAttribute("ItemName")
		if name and Mutations.Unwrap(name) == baseName then
			live += 1
		end
	end
	return live
end

local function atLimit(itemName)
	local baseName = Mutations.Unwrap(itemName)
	if FusionRecipes.IsAddon(baseName) and activeAddonCount() >= MAX_ACTIVE_ADDONS then
		return true
	end
	local cap = MAX_ON_MAP[baseName]
	return cap ~= nil and liveCount(baseName) >= cap
end

-- Everything that puts an item on the yard floor goes through here, so a
-- crate drop and a regular drop behave identically once they land.
local function spawnItemAt(itemName, position, opts)
	opts = opts or {}
	local baseName, mutationId = Mutations.Unwrap(itemName)

	-- Detailed mesh when one exists in ItemModels, else the old block.
	local part = ItemVisuals.Create(baseName, position, 1)

	-- Stores the item's identity as data, not just a display name.
	-- The fusion pad will read this attribute later, so renaming
	-- the part in Explorer won't break anything.
	part:SetAttribute("ItemName", itemName)
	part:SetAttribute("Tier", 1)
	-- What activeAddonCount() counts. Set on the part rather than tracked
	-- in a table so the despawn timer and any other removal path keep the
	-- tally honest for free.
	part:SetAttribute("IsAddon", FusionRecipes.IsAddon(baseName))

	-- A textured mesh ignores Color, so a mutation is shown with a
	-- highlight in its colour instead of by repainting the model.
	local mutationColour = Mutations.Color(mutationId)
	if mutationColour then
		local glow = Instance.new("Highlight")
		glow.FillColor = mutationColour
		glow.OutlineColor = mutationColour
		glow.FillTransparency = 0.55
		glow.OutlineTransparency = 0
		glow.DepthMode = Enum.HighlightDepthMode.Occluded
		glow.Adornee = part:FindFirstChild("Visual") or part
		glow.Parent = part
	end

	addLabel(part, itemName)
	local rare = isRareRoll(itemName)
	if rare or opts.beam then
		addBeam(part, itemColour(itemName))
	end
	part.Parent = scrapFolder

	-- Worth announcing on its own merits — no separate "golden" spawn
	-- type needed to make a rare drop feel exciting. Keep this one (per
	-- the user's own call, "keep the one for when something rare spawns
	-- like a jet engine"); it's the sole surviving world-spawn announcement.
	if rare and not opts.silent then
		announce(string.format("%s just dropped in the yard — grab it before it's gone!", itemTag(itemName)))
		print("[ScrapSpawner] RARE spawn:", itemName)
	else
		print("[ScrapSpawner] Dropped:", itemName)
	end

	-- Clean itself up later. task.delay doesn't block this loop.
	task.delay(opts.despawnAfter or DESPAWN_AFTER, function()
		if part and part.Parent then
			part:Destroy()
		end
	end)
	return part
end

local function rollFrenzyMutation()
	local pool = {}
	for id in pairs(FRENZY_DROP_WEIGHTS) do
		table.insert(pool, id)
	end
	table.sort(pool)
	return weightedPick(pool, function(id) return FRENZY_DROP_WEIGHTS[id] end)
end

local function spawnScrap()
	local now = os.clock()
	local cap = now < rushUntil and RUSH_MAX_ITEMS or MAX_ITEMS
	-- Respect the cap. Better to skip a drop than lag the server.
	if #scrapFolder:GetChildren() >= cap then
		return
	end

	local itemName = FusionRecipes.RollSpawn()
	-- Already at its limit out there. Swap in a vehicle rather than skip
	-- the drop, so the yard stays as busy as it always was; the most common
	-- vehicle is the last resort, since nothing caps it.
	for _ = 1, 4 do
		if not atLimit(itemName) then break end
		itemName = FusionRecipes.RollBaseItem()
	end
	if atLimit(itemName) then
		itemName = FusionRecipes.Items[1].name
	end
	if now < frenzyUntil and math.random() < FRENZY_DROP_CHANCE then
		itemName = Mutations.Wrap(itemName, rollFrenzyMutation())
	end

	spawnItemAt(itemName, randomSpawnPosition())
end

------------------------------------------------------------------
-- Yard events
------------------------------------------------------------------

local function craneArm()
	local features = YardFeatures.Find()
	local crane = features and features:FindFirstChild("MagnetCrane")
	return crane and crane:FindFirstChild("Arm")
end

-- Turns the arm so the magnet hangs over `angle` (radians around the yard,
-- measured the same way as math.atan2(z, x)). The arm's jib points along
-- +X at yaw 0, and a yaw of -angle swings +X onto that bearing.
local function swingArm(arm, angle, seconds)
	local pivot = arm:GetPivot()
	local from = arm:GetAttribute("Yaw") or 0
	local to = -angle
	-- The short way round, never a full lap.
	local delta = (to - from + math.pi) % (math.pi * 2) - math.pi

	local driver = Instance.new("NumberValue")
	driver.Value = from
	local conn = driver.Changed:Connect(function(yaw)
		arm:PivotTo(CFrame.new(pivot.Position) * CFrame.Angles(0, yaw, 0))
	end)
	local tween = TweenService:Create(driver, TweenInfo.new(seconds, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut),
		{ Value = from + delta })
	tween:Play()
	tween.Completed:Wait()
	conn:Disconnect()
	driver:Destroy()
	arm:SetAttribute("Yaw", from + delta)
end

-- A pulsing ring and a light pillar on the landing spot, so everyone can
-- see where to stand before the crate comes down.
local function dropMarker(spot)
	local marker = Instance.new("Model")
	marker.Name = "CraneDropMarker"

	local ring = Instance.new("Part")
	ring.Name = "Ring"
	ring.Shape = Enum.PartType.Cylinder
	ring.Size = Vector3.new(0.2, 9, 9)
	ring.CFrame = CFrame.new(spot + Vector3.new(0, 0.12, 0)) * CFrame.Angles(0, 0, math.rad(90))
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.Material = Enum.Material.Neon
	ring.Color = Color3.fromRGB(255, 205, 40)
	ring.Transparency = 0.2
	ring.Parent = marker

	local pulse = TweenService:Create(ring, TweenInfo.new(0.5, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true),
		{ Transparency = 0.75 })
	pulse:Play()

	marker.Parent = workspace
	addBeam(ring, Color3.fromRGB(255, 205, 40))
	return marker
end

local function rollCrateItem()
	local floor = FusionRecipes.RarityIndex[CRATE_MIN_RARITY]
	local pool = {}
	for _, item in ipairs(FusionRecipes.BaseItems) do
		if FusionRecipes.RarityIndex[item.rarity] >= floor and not atLimit(item.name) then
			table.insert(pool, item)
		end
	end
	return weightedPick(pool, function(item) return FusionRecipes.RarityWeight[item.rarity] end).name
end

-- A wooden crate falling from the magnet onto the spot, then bursting.
local function dropCrate(origin, spot)
	local crate = Instance.new("Part")
	crate.Name = "CraneCrate"
	crate.Size = Vector3.new(4, 4, 4)
	crate.CFrame = CFrame.new(origin - Vector3.new(0, 2, 0))
	crate.Anchored = true
	crate.CanCollide = false
	crate.CanQuery = false
	crate.Material = Enum.Material.WoodPlanks
	crate.Color = Color3.fromRGB(150, 104, 58)
	crate.Parent = workspace

	local fall = TweenService:Create(crate, TweenInfo.new(CRATE_FALL_SECONDS, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
		{ CFrame = CFrame.new(spot + Vector3.new(0, 2, 0)) * CFrame.Angles(0, math.rad(35), 0) })
	fall:Play()
	fall.Completed:Wait()

	local burst = Instance.new("ParticleEmitter")
	burst.Color = ColorSequence.new(Color3.fromRGB(190, 150, 100))
	burst.Size = NumberSequence.new(1.2, 0)
	burst.Lifetime = NumberRange.new(0.4, 0.8)
	burst.Speed = NumberRange.new(10, 18)
	burst.SpreadAngle = Vector2.new(180, 180)
	burst.Rate = 0
	burst.Parent = crate
	burst:Emit(40)
	crate.Transparency = 1
	task.delay(1, function()
		crate:Destroy()
	end)
end

local runEvent = {}

-- The leaderboard board stands on the +X bearing just off the crane (see
-- PlotManager). Crane Drops pick any bearing except within this much of it.
local LEADERBOARD_CLEARANCE = math.rad(25)

function runEvent.CraneDrop()
	local angle = LEADERBOARD_CLEARANCE + math.random() * (math.pi * 2 - LEADERBOARD_CLEARANCE * 2)
	local reach = YardFeatures.CRANE_REACH
	local x, z = math.cos(angle) * reach, math.sin(angle) * reach
	local spot = Vector3.new(x, surfaceY(x, z) or YardFeatures.GROUND_Y, z)

	local marker = dropMarker(spot)
	announce(string.format("<font color=\"#FFCD28\">CRANE DROP</font> in %d seconds — get under the magnet!", EVENT_WARNING))

	local started = os.clock()
	local arm = craneArm()
	if arm then
		swingArm(arm, angle, CRANE_SWING_SECONDS)
	end
	task.wait(math.max(0, EVENT_WARNING - (os.clock() - started)))

	-- Fall from wherever the magnet actually ended up, so the crate always
	-- leaves the magnet even if the arm is a hair off the marker.
	local magnet = arm and arm:FindFirstChild("Magnet")
	local origin = magnet and (magnet.Position - Vector3.new(0, magnet.Size.X / 2, 0)) or (spot + Vector3.new(0, 20, 0))
	dropCrate(Vector3.new(spot.X, origin.Y, spot.Z), spot)
	marker:Destroy()

	local itemName = rollCrateItem()
	spawnItemAt(itemName, spot, { beam = true, silent = true, despawnAfter = CRATE_DESPAWN_AFTER })
	announce(string.format("<font color=\"#FFCD28\">CRANE DROP:</font> %s just landed by the crane!", itemTag(itemName)))
end

function runEvent.ScrapRush()
	announce(string.format("<font color=\"#5ADC78\">SCRAP RUSH</font> in %d seconds — double drops incoming!", EVENT_WARNING))
	task.wait(EVENT_WARNING)
	rushUntil = os.clock() + RUSH_SECONDS
	announce(string.format("<font color=\"#5ADC78\">SCRAP RUSH!</font> Scrap is dropping twice as fast for %d seconds!", RUSH_SECONDS))
	task.wait(RUSH_SECONDS)
	announce("The Scrap Rush is over.")
end

function runEvent.MutationFrenzy()
	announce(string.format("<font color=\"#BE6EFF\">MUTATION FRENZY</font> in %d seconds!", EVENT_WARNING))
	task.wait(EVENT_WARNING)
	frenzyUntil = os.clock() + FRENZY_SECONDS
	EventConfig.StartRuntime(FRENZY_SECONDS)
	announce(string.format("<font color=\"#BE6EFF\">MUTATION FRENZY!</font> Mutated scrap is dropping and fusions mutate twice as often — %d seconds!", FRENZY_SECONDS))
	task.wait(FRENZY_SECONDS)
	announce("The Mutation Frenzy is over.")
end

local EVENT_ORDER = { "CraneDrop", "ScrapRush", "MutationFrenzy" }
local eventRunning = false
local lastEvent = nil

local function startEvent(name)
	if eventRunning or not runEvent[name] then
		return false
	end
	eventRunning = true
	lastEvent = name
	print("[YardEvents] Starting", name)
	local ok, err = pcall(runEvent[name])
	if not ok then
		warn("[YardEvents] " .. name .. " failed: " .. tostring(err))
	end
	eventRunning = false
	return true
end

task.spawn(function()
	task.wait(EVENT_FIRST_AFTER)
	while true do
		local choices = {}
		for _, name in ipairs(EVENT_ORDER) do
			if name ~= lastEvent then
				table.insert(choices, name)
			end
		end
		startEvent(choices[math.random(1, #choices)])
		task.wait(math.random(EVENT_GAP_MIN, EVENT_GAP_MAX))
	end
end)

-- Developer hook: set workspace's "TriggerYardEvent" attribute to an event
-- name from a server script or the command bar to run it right now. Only
-- the server can set a workspace attribute, so players cannot reach this.
workspace:GetAttributeChangedSignal("TriggerYardEvent"):Connect(function()
	local name = workspace:GetAttribute("TriggerYardEvent")
	if type(name) == "string" and name ~= "" then
		workspace:SetAttribute("TriggerYardEvent", nil)
		task.spawn(startEvent, name)
	end
end)

print("[ScrapSpawner] Running. Dropping scrap every", SPAWN_INTERVAL, "seconds.")

while true do
	spawnScrap()
	task.wait(os.clock() < rushUntil and RUSH_INTERVAL or SPAWN_INTERVAL)
end
