local ItemNames = require(game:GetService("ReplicatedStorage"):WaitForChild("ItemNames"))
--[[
	ScrapSpawner (Script, ServerScriptService) — Junkyard Fusion v1
	Sends a random car out of the black box onto the yard's conveyor every
	few seconds and moves everything riding it round the loop (YardConveyor
	owns the belt itself). Also runs the yard's timed events: Crane Drop,
	Scrap Rush and Mutation Frenzy.
	Server-only on purpose: the server decides what spawns, never the client.
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local TweenService = game:GetService("TweenService")
local RunService = game:GetService("RunService")

local FusionRecipes = require(ReplicatedStorage:WaitForChild("FusionRecipes"))
local ItemVisuals = require(ReplicatedStorage:WaitForChild("ItemVisuals"))
local ItemRarity = require(ReplicatedStorage:WaitForChild("ItemRarity"))
local Mutations = require(ReplicatedStorage:WaitForChild("Mutations"))
local EventConfig = require(ReplicatedStorage:WaitForChild("EventConfig"))
local YardFeatures = require(ServerStorage:WaitForChild("YardFeatures"))
local ScrapLabel = require(ServerStorage:WaitForChild("ScrapLabel"))
local Conveyor = require(ServerStorage:WaitForChild("YardConveyor"))

-- Shared with PlotManager and the client UI.
local remote = ReplicatedStorage:FindFirstChild("GameUpdate")
if not remote then
	remote = Instance.new("RemoteEvent")
	remote.Name = "GameUpdate"
	remote.Parent = ReplicatedStorage
end

-- ---------- Tuning knobs. Change these, not the code below. ----------
local SPAWN_INTERVAL = 5      -- seconds between cars coming out of the box (was 3: too many at once)
local DESPAWN_AFTER  = 40     -- seconds before an ignored crane prize disappears
-- Most cars on the belt at once. One leaves the box every 5 s and a lap
-- takes about 43 s, so the belt normally carries about 9; this only
-- catches a hiccup, it is not what normally limits the count.
local MAX_ITEMS      = 12

-- The secret Legendary: every LEGENDARY_EVERY seconds a random Legendary
-- build (any car with a Jet Engine, Rocket Booster or Fusion Core) rolls
-- out of the box, for whoever gets to it first. Its time is workspace's
-- "LegendaryDropAt" (server time), which the timer in every base counts
-- down to; setting it to now drops one straight away (the admin panel).
local LEGENDARY_EVERY = 20 * 60

-- Golden Scrap removed 2026-09-14 ("its litteary worthless now, get rid
-- of the gold scrap idea in general") — its old role as "the exciting
-- thing to chase" is replaced below by just announcing it when the
-- regular roll itself lands on a naturally rare base item.
-- Anything this rare or rarer gets the same "come get it" broadcast
-- Golden Scrap used to have: the Monster Truck, now that addons are bought
-- in the Shop rather than found on the belt.
local ANNOUNCE_RARITY = "mythic"

-- Per-item limits on the map at once, on top of MAX_ITEMS. Two Monster
-- Trucks out together cheapens both. A roll that lands on something
-- already at its limit becomes a more common car instead. (Addons are
-- bought in the Shop now, so none of them ride the belt.)
local MAX_ON_MAP = {
	["Monster Truck"] = 1,
}

-- Yard events. One every four to six minutes, never the same one twice in
-- a row, each announced EVENT_WARNING seconds ahead so people can get
-- into position.
local EVENT_FIRST_AFTER = 120
local EVENT_GAP_MIN, EVENT_GAP_MAX = 240, 360
local EVENT_WARNING = 10

-- Scrap Rush: cars come out of the box twice as fast for a minute, with
-- its own cap so a rush fills the belt without burying it.
local RUSH_SECONDS = 60
local RUSH_INTERVAL = 1.5
local RUSH_MAX_ITEMS = 30

-- Mutation Frenzy: a quarter of drops land already mutated, and every
-- fusion rolls mutations at double odds (EventConfig's own multiplier).
local FRENZY_SECONDS = 90
local FRENZY_DROP_CHANCE = 0.25
local FRENZY_DROP_WEIGHTS = { shiny = 60, toxic = 25, golden = 10, frenzy = 3, cosmic = 2 }

-- Crane Drop: the crate only ever holds a rare-or-better car (Cop Cruiser,
-- Box Truck or Monster Truck), picked by rarity rather than by spawn rate
-- so a crate stays worth racing for. Addons are Shop-only now.
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

------------------------------------------------------------------
-- The conveyor
------------------------------------------------------------------

Conveyor.Build()

-- Everything riding the belt: [item] = how far along it is, how high its
-- middle sits above the belt, and half its length, for knowing when it
-- is fully inside the box. The Heartbeat below moves them all.
local riders = {}

local function ride(part, distance)
	riders[part] = {
		distance = distance,
		lift = part.Size.Y / 2,
		half = math.max(part.Size.X, part.Size.Z) / 2,
	}
end

local function riderCount()
	local count = 0
	for _ in pairs(riders) do
		count += 1
	end
	return count
end

RunService.Heartbeat:Connect(function(dt)
	local moving, frames = {}, {}
	local step = Conveyor.SPEED * dt
	for part, rider in pairs(riders) do
		if not part.Parent or part:GetAttribute("Collected") then
			-- Grabbed (PlotManager marks it and flies it to the player), or
			-- gone some other way: no longer ours to move.
			riders[part] = nil
		else
			rider.distance += step
			if rider.distance > Conveyor.Length + rider.half then
				-- All the way into the box's rear: that is the end of its lap.
				riders[part] = nil
				part:Destroy()
			else
				local point, travel = Conveyor.PointAt(rider.distance)
				local centre = point + Vector3.new(0, rider.lift, 0)
				table.insert(moving, part)
				-- The car models are built nose-first along +Z (grille,
				-- headlights and front wheels on that end), the opposite of
				-- LookVector, so +Z is what points down the belt.
				table.insert(frames, CFrame.lookAt(centre, centre - travel))
				-- Its wheels turn on players' screens (ConveyorBelt).
			end
		end
	end
	if #moving > 0 then
		workspace:BulkMoveTo(moving, frames, Enum.BulkMoveMode.FireCFrameChanged)
	end
end)

-- Anything a player drops onto the belt rides it too, rather than sitting
-- still on a moving belt. Waits out the drop's fall first (PlotManager
-- eases it down), then picks it up from where it landed.
scrapFolder.ChildAdded:Connect(function(item)
	if not item:GetAttribute("DroppedBy") then return end
	task.delay(1, function()
		if not item.Parent or riders[item] or not item:IsA("BasePart") then return end
		if not Conveyor.IsOnBelt(item.Position) then return end
		local distance = Conveyor.DistanceOf(item.Position)
		if distance <= Conveyor.Length then
			ride(item, distance)
		end
	end)
end)

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
-- The look lives in ScrapLabel, shared with anything a player drops, so
-- every loose item in the world wears the same bubbly name tag.
local function addLabel(part, itemName)
	ScrapLabel.Attach(part, itemName)
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

-- The rarest cars — Golden Scrap's old "worth announcing" role, now just
-- surfacing when the regular roll itself lands on something already rare
-- instead of a separate spawn type. Of the cars, only the Monster Truck
-- clears the bar.
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
	local cap = MAX_ON_MAP[baseName]
	return cap ~= nil and liveCount(baseName) >= cap
end

-- Everything that puts an item into the yard goes through here — a car
-- onto the belt, or a crane prize onto the floor — so they all look and
-- behave the same.
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
		announce(string.format("%s is riding the conveyor — grab it before the black box does!", itemTag(itemName)))
		print("[ScrapSpawner] RARE spawn:", itemName)
	else
		print("[ScrapSpawner] Dropped:", itemName)
	end

	-- Clean itself up later. task.delay doesn't block this loop. A car on
	-- the belt needs no timer: the black box takes it at the end of its lap.
	if not opts.onBelt then
		task.delay(opts.despawnAfter or DESPAWN_AFTER, function()
			if part and part.Parent then
				part:Destroy()
			end
		end)
	end
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
	-- Respect the cap. Better to skip a car than lag the server. Only the
	-- belt counts: a crane prize or something a player dropped should not
	-- stop cars coming out of the box.
	if riderCount() >= cap then
		return
	end

	local itemName = FusionRecipes.RollSpawn()
	-- Already at its limit out there. Swap in a more common car rather than
	-- skip it, so the belt stays as busy as it always was; the most common
	-- car is the last resort, since nothing caps it.
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

	-- Made just inside the box's front, so it rolls out through the flaps
	-- rather than popping into view on the belt.
	local part = spawnItemAt(itemName, (Conveyor.PointAt(0)), { onBelt = true })
	ride(part, -math.max(part.Size.X, part.Size.Z) / 2)
end

-- Every Legendary build in the recipe book.
local legendaryBuilds = {}
for _, entry in ipairs(FusionRecipes.GetAllResults()) do
	local name = type(entry) == "table" and entry.name or entry
	if FusionRecipes.GetRarity(name) == "legendary" then
		table.insert(legendaryBuilds, name)
	end
end

-- The secret Legendary rolls out of the box, whatever the belt's cap.
local function spawnSecretLegendary()
	local itemName = legendaryBuilds[math.random(1, #legendaryBuilds)]
	local part = spawnItemAt(itemName, (Conveyor.PointAt(0)), { onBelt = true, beam = true, silent = true })
	ride(part, -math.max(part.Size.X, part.Size.Z) / 2)
	workspace:SetAttribute("LegendaryDroppedAt", workspace:GetServerTimeNow())
	announce(string.format("<font color=\"#FFCD28\">SECRET LEGENDARY!</font> %s just rolled out of the black box — first to grab it keeps it!",
		itemTag(itemName)))
	print("[ScrapSpawner] Secret Legendary:", itemName)
end

workspace:SetAttribute("LegendaryDropAt", workspace:GetServerTimeNow() + LEGENDARY_EVERY)
task.spawn(function()
	while true do
		task.wait(0.5)
		local now = workspace:GetServerTimeNow()
		local dropAt = workspace:GetAttribute("LegendaryDropAt") or now
		if now >= dropAt then
			-- The next one is a full LEGENDARY_EVERY from now, so an early
			-- drop (the admin panel) restarts the 20 minutes.
			workspace:SetAttribute("LegendaryDropAt", now + LEGENDARY_EVERY)
			local ok, err = pcall(spawnSecretLegendary)
			if not ok then
				warn("[ScrapSpawner] Secret Legendary failed: " .. tostring(err))
			end
		end
	end
end)

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
	for _, item in ipairs(FusionRecipes.Items) do
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
	announce(string.format("<font color=\"#5ADC78\">SCRAP RUSH!</font> The conveyor is running twice as many cars for %d seconds!", RUSH_SECONDS))
	task.wait(RUSH_SECONDS)
	announce("The Scrap Rush is over.")
end

function runEvent.MutationFrenzy()
	announce(string.format("<font color=\"#BE6EFF\">MUTATION FRENZY</font> in %d seconds!", EVENT_WARNING))
	task.wait(EVENT_WARNING)
	frenzyUntil = os.clock() + FRENZY_SECONDS
	EventConfig.StartRuntime(FRENZY_SECONDS)
	announce(string.format("<font color=\"#BE6EFF\">MUTATION FRENZY!</font> Mutated cars are riding the conveyor and fusions mutate twice as often — %d seconds!", FRENZY_SECONDS))
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

print("[ScrapSpawner] Running. A car leaves the black box every", SPAWN_INTERVAL, "seconds.")

while true do
	spawnScrap()
	task.wait(os.clock() < rushUntil and RUSH_INTERVAL or SPAWN_INTERVAL)
end
