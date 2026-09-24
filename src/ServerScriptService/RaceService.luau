--[[
	RaceService (ModuleScript, ServerScriptService) — Junkyard Fusion

	Runs Race Wars races. A player in the lobby picks one of their cars
	(RaceWarsUI), the server builds a drivable copy of it on the starting
	grid and seats them in it, counts down, and lets them go. They drive it
	themselves (RaceDrive, on their own client); a monster chases them at
	the speed of whichever level they are on (RaceConfig). Every level
	cleared wins a crate; the run ends when the monster catches them, they
	reach the finish, or they leave the car.

	Racing never uses the car up — the item stays wherever it is, in
	Inventory or on a pad. What you drive is a copy.

	PlotManager owns player data, so it hands this module what it needs
	through Race.Configure (the same "inject after require" shape used for
	other services): whether a player owns a car and can race right now,
	and what to do when a level is cleared.

	The client drives its own car (so steering feels instant), which means
	the server never trusts where the client says the car is: a race's
	progress only counts up as fast as that car could really have driven.
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")

local RaceConfig = require(ReplicatedStorage:WaitForChild("RaceConfig"))
local ItemVisuals = require(ReplicatedStorage:WaitForChild("ItemVisuals"))
local Mutations = require(ReplicatedStorage:WaitForChild("Mutations"))
local Track = require(ServerStorage:WaitForChild("RaceTrack"))
local Monster = require(ServerStorage:WaitForChild("RaceMonster"))

local Race = {}

local function remoteEvent(name)
	local r = ReplicatedStorage:FindFirstChild(name)
	if not r then
		r = Instance.new("RemoteEvent")
		r.Name = name
		r.Parent = ReplicatedStorage
	end
	return r
end

-- Client -> server: start a race in this car.
local startRemote = remoteEvent("RaceStart")
-- Server -> client: what is happening in your race, as { kind = ... }:
-- "arrived", "countdown", "go", "cleared", "caught", "finished", "bailed",
-- "ended".
local eventRemote = remoteEvent("RaceEvent")

-- Set by PlotManager (see the header).
local hooks = {
	owns = function() return false end,
	canRace = function() return true end,
	levelCleared = function() return false end,
	toast = function() end,
	broadcast = function() end,
	sendHome = function() end,
}
function Race.Configure(given)
	for key, fn in pairs(given) do
		hooks[key] = fn
	end
end

Track.Build()

local liveFolder = workspace:FindFirstChild("RaceWarsLive")
if not liveFolder then
	liveFolder = Instance.new("Folder")
	liveFolder.Name = "RaceWarsLive"
	liveFolder.Parent = workspace
end

local races = {}      -- [player] = race (see startRace)
local lastStart = {}  -- [player] = os.clock() of their last start

local COUNTDOWN = 3
-- Race cars have no friction: the drive constraint alone decides how fast
-- they go, and friction only made them judder against it.
local SLICK = PhysicalProperties.new(0.7, 0, 0.3, 100, 1)

local function fire(player, payload)
	if player.Parent then
		eventRemote:FireClient(player, payload)
	end
end

------------------------------------------------------------------
-- The car
------------------------------------------------------------------

-- A drivable copy of an item: an invisible box as the physics body (its
-- LookVector is the car's front), the item's own model welded on it, and
-- a seat. The item models are built nose-first along +Z, so the model is
-- turned round to face the body's front.
local function buildCar(player, itemName, stats, frame)
	local baseName, mutationId = Mutations.Unwrap(itemName)
	local probe = ItemVisuals.Create(baseName, Vector3.zero, 1)
	local probeSize = probe.Size
	probe:Destroy()
	local body = ItemVisuals.Create(baseName, Vector3.zero, RaceConfig.CAR_LENGTH / math.max(probeSize.Z, probeSize.X, 1))
	local size = body.Size

	local car = Instance.new("Model")
	car.Name = player.Name .. "'s car"

	local chassisHeight = math.clamp(size.Y * 0.55, 2.5, 6)
	local chassis = Instance.new("Part")
	chassis.Name = "Chassis"
	chassis.Size = Vector3.new(math.max(size.X, 5), chassisHeight, math.max(size.Z, 9))
	chassis.CFrame = frame * CFrame.new(0, chassisHeight / 2 + 0.3, 0)
	chassis.Transparency = 1
	chassis.Anchored = true
	chassis.CanCollide = true
	chassis.CustomPhysicalProperties = SLICK
	chassis.CollisionGroup = Track.CAR_GROUP
	chassis.Parent = car
	car.PrimaryPart = chassis

	body.Anchored = false
	body.CanCollide = false
	body.Massless = true
	body.CFrame = chassis.CFrame * CFrame.new(0, size.Y / 2 - chassisHeight / 2, 0) * CFrame.Angles(0, math.pi, 0)
	body.Parent = car
	local bodyWeld = Instance.new("WeldConstraint")
	bodyWeld.Part0 = chassis
	bodyWeld.Part1 = body
	bodyWeld.Parent = chassis
	for _, p in ipairs(body:GetDescendants()) do
		if p:IsA("BasePart") then
			p.CollisionGroup = Track.CAR_GROUP
		end
	end

	local colour = Mutations.Color(mutationId)
	if colour then
		local glow = Instance.new("Highlight")
		glow.FillColor = colour
		glow.OutlineColor = colour
		glow.FillTransparency = 0.6
		glow.Adornee = body:FindFirstChild("Visual") or body
		glow.Parent = car
	end

	-- A VehicleSeat, so the default controls feed its Throttle and Steer
	-- on every device (keys, gamepad, touch thumbstick) for RaceDrive to
	-- read. It drives nothing itself.
	local seat = Instance.new("VehicleSeat")
	seat.Name = "RaceSeat"
	seat.Size = Vector3.new(2.4, 0.6, 2.4)
	seat.Transparency = 1
	seat.CanCollide = false
	seat.Massless = true
	seat.MaxSpeed = 0
	seat.Torque = 0
	seat.TurnSpeed = 0
	seat.HeadsUpDisplay = false
	seat.CFrame = chassis.CFrame * CFrame.new(0, -chassisHeight / 2 + size.Y * 0.45, size.Z * 0.06)
	seat.CollisionGroup = Track.CAR_GROUP
	seat:SetAttribute("RaceSeat", true)
	seat:SetAttribute("TopSpeed", stats.topSpeed)
	seat:SetAttribute("Accel", stats.accel)
	seat:SetAttribute("TurnRate", stats.turnRate)
	seat:SetAttribute("Go", false)
	seat.Parent = car
	local seatWeld = Instance.new("WeldConstraint")
	seatWeld.Part0 = chassis
	seatWeld.Part1 = seat
	seatWeld.Parent = chassis

	-- What RaceDrive steers with: velocity along the ground (gravity left
	-- alone) and a yaw-only orientation that keeps the car flat.
	local attachment = Instance.new("Attachment")
	attachment.Name = "Drive"
	attachment.Parent = chassis
	local drive = Instance.new("LinearVelocity")
	drive.Name = "DriveVelocity"
	drive.Attachment0 = attachment
	drive.RelativeTo = Enum.ActuatorRelativeTo.World
	drive.VelocityConstraintMode = Enum.VelocityConstraintMode.Plane
	drive.PrimaryTangentAxis = Vector3.xAxis
	drive.SecondaryTangentAxis = Vector3.zAxis
	drive.PlaneVelocity = Vector2.zero
	drive.MaxForce = 400000
	drive.Parent = chassis
	local align = Instance.new("AlignOrientation")
	align.Name = "DriveHeading"
	align.Attachment0 = attachment
	align.Mode = Enum.OrientationAlignmentMode.OneAttachment
	align.CFrame = frame.Rotation
	align.MaxTorque = math.huge
	align.Responsiveness = 40
	align.Parent = chassis

	car.Parent = liveFolder
	return car, chassis, seat
end

------------------------------------------------------------------
-- Races
------------------------------------------------------------------

-- Everything a racing character touches joins the race cars' collision
-- group, so racers pass through each other and the lobby gate.
local function setRacingGroup(race, racing)
	local character = race.player.Character
	if racing then
		race.savedGroups = {}
		if character then
			for _, p in ipairs(character:GetDescendants()) do
				if p:IsA("BasePart") then
					race.savedGroups[p] = p.CollisionGroup
					p.CollisionGroup = Track.CAR_GROUP
				end
			end
		end
	else
		for p, group in pairs(race.savedGroups or {}) do
			if p.Parent then p.CollisionGroup = group end
		end
		race.savedGroups = nil
	end
end

local function clearHud(player)
	player:SetAttribute("RaceLevel", nil)
	player:SetAttribute("RaceDistance", nil)
	player:SetAttribute("RaceGap", nil)
	player:SetAttribute("RaceMonsterSpeed", nil)
end

-- Ends a race. `outcome` is what the player is told: "caught",
-- "finished", "bailed", or "left" (travelled away or quit — nothing to
-- show, no trip back to the lobby).
local function endRace(race, outcome)
	if race.state == "ended" then return end
	local player = race.player
	race.state = "ended"
	if races[player] == race then
		races[player] = nil
	end
	clearHud(player)
	if race.seat.Parent then
		race.seat:SetAttribute("Go", false)
	end
	if outcome ~= "left" then
		fire(player, { kind = outcome, cleared = race.cleared, level = race.level })
	else
		fire(player, { kind = "ended" })
	end
	if outcome == "finished" then
		hooks.broadcast(string.format("%s escaped the Race Wars monster in a %s!", player.Name, race.itemName))
	end

	local function tidy()
		setRacingGroup(race, false)
		if race.humanoid.Parent and race.humanoid.SeatPart == race.seat then
			race.humanoid.Sit = false
		end
		race.car:Destroy()
		race.monster:Destroy()
	end
	if outcome == "left" then
		tidy()
		return
	end
	-- A moment to see what happened (the monster on you, or the finish)
	-- before being sent back to the lobby.
	task.delay(outcome == "finished" and 3 or 2, function()
		tidy()
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if player.Parent and humanoid and humanoid.Health > 0 then
			task.wait(0.1)
			character:PivotTo(Track.LobbySpawn())
			fire(player, { kind = "arrived" })
		end
	end)
end

local function startRace(player, itemName, stats)
	local character = player.Character
	local humanoid = character:FindFirstChildOfClass("Humanoid")

	local place = 1
	for _ in pairs(races) do place += 1 end
	local frame = Track.GridFrame(place)
	local car, chassis, seat = buildCar(player, itemName, stats, frame)

	local monster = Monster.Create()
	monster.Parent = liveFolder

	local race = {
		player = player,
		itemName = itemName,
		stats = stats,
		car = car,
		chassis = chassis,
		seat = seat,
		humanoid = humanoid,
		monster = monster,
		state = "countdown",
		level = 1,
		cleared = 0,
		distance = Track.DistanceOf(chassis.Position),
		offset = select(2, Track.DistanceOf(chassis.Position)),
		checkedAt = os.clock(),
		lastGood = chassis.CFrame,
		-- Waiting in the lobby mouth behind the grid, in view of everyone.
		monsterDistance = -30,
		monsterOffset = 0,
		hudAt = 0,
	}
	races[player] = race

	humanoid.Sit = false
	character:PivotTo(seat.CFrame * CFrame.new(0, 3, 0))
	seat:Sit(humanoid)
	setRacingGroup(race, true)
	player:SetAttribute("RaceLevel", 1)
	player:SetAttribute("RaceMonsterSpeed", math.floor(RaceConfig.MonsterSpeed(1)))
	fire(player, { kind = "countdown", seconds = COUNTDOWN, item = itemName, topSpeed = stats.topSpeed })

	task.delay(COUNTDOWN, function()
		if race.state ~= "countdown" then return end
		if seat.Occupant ~= humanoid then
			endRace(race, "bailed")
			return
		end
		chassis.Anchored = false
		chassis:SetNetworkOwner(player)
		seat:SetAttribute("Go", true)
		race.state = "racing"
		race.goAt = os.clock()
		race.checkedAt = os.clock()
		fire(player, { kind = "go" })
	end)
end

local function stepRace(race, dt, now)
	local chassis, humanoid = race.chassis, race.humanoid
	if not chassis.Parent or not humanoid.Parent or humanoid.Health <= 0 or race.seat.Occupant ~= humanoid then
		endRace(race, "bailed")
		return
	end

	-- Progress only counts as fast as this car could really have gone
	-- since the last check, whatever its client claims.
	local position = chassis.Position
	local distance, offset = Track.DistanceOf(position)
	-- A car's middle sits a few studs up; ten is already clear of every
	-- obstacle's reach, so anything higher is a car being flown.
	local offTrack = position.Y < Track.ORIGIN.Y - 20 or position.Y > Track.ORIGIN.Y + 10
		or math.abs(offset) > Track.WIDTH / 2 + 4
	if offTrack then
		-- Fallen off, flying over the obstacles or through a wall: none of
		-- that counts, and it goes back where it last was on the track.
		chassis.AssemblyLinearVelocity = Vector3.zero
		chassis.CFrame = race.lastGood
	else
		local elapsed = now - race.checkedAt
		race.distance = math.min(distance, race.distance + race.stats.topSpeed * elapsed * 1.3 + 6)
		race.offset = offset
		race.checkedAt = now
		race.lastGood = chassis.CFrame
	end

	while race.level <= #RaceConfig.Levels and race.distance >= race.level * RaceConfig.LEVEL_LENGTH do
		local won = hooks.levelCleared(race.player, race.level)
		race.cleared = race.level
		race.level += 1
		-- Every level cleared, the monster gets a lot faster.
		local faster = race.level <= #RaceConfig.Levels and RaceConfig.MonsterSpeed(race.level) or nil
		fire(race.player, { kind = "cleared", level = race.cleared, crate = won == true, monsterSpeed = faster })
		race.player:SetAttribute("RaceLevel", math.min(race.level, #RaceConfig.Levels))
		race.player:SetAttribute("RaceMonsterSpeed", faster and math.floor(faster) or nil)
	end
	if race.level > #RaceConfig.Levels then
		endRace(race, "finished")
		return
	end

	if now - race.goAt >= RaceConfig.MONSTER_DELAY then
		local speed = RaceConfig.MonsterSpeed(race.level)
		race.monsterDistance = math.max(race.monsterDistance + speed * dt, race.distance - RaceConfig.MAX_GAP)
	end
	race.monsterOffset += (race.offset - race.monsterOffset) * math.min(1, dt * 1.5)

	if race.distance - race.monsterDistance <= RaceConfig.CATCH_DISTANCE then
		race.monsterDistance = race.distance - 2
		endRace(race, "caught")
		return
	end

	if now - race.hudAt > 0.1 then
		race.hudAt = now
		race.player:SetAttribute("RaceDistance", math.floor(race.distance))
		race.player:SetAttribute("RaceGap", math.floor(race.distance - race.monsterDistance))
	end
end

RunService.Heartbeat:Connect(function(dt)
	local now = os.clock()
	for _, race in pairs(races) do
		if race.state == "racing" then
			stepRace(race, dt, now)
		end
	end
end)

-- Drawn every frame for every race still on screen, ended ones included
-- (a caught car's monster stays on it until the tidy-up).
local drawn = {}
RunService.Heartbeat:Connect(function()
	local t = os.clock()
	for _, race in pairs(races) do
		drawn[race] = true
	end
	for race in pairs(drawn) do
		if not race.monster.Parent then
			drawn[race] = nil
		else
			local half = Track.WIDTH / 2 - 12
			local offset = math.clamp(race.monsterOffset, -half, half)
			Monster.Place(race.monster, CFrame.new(Track.PointAt(race.monsterDistance, offset, 0)) * Track.Heading, t)
		end
	end
end)

startRemote.OnServerEvent:Connect(function(player, itemName)
	if type(itemName) ~= "string" or races[player] then return end
	if lastStart[player] and os.clock() - lastStart[player] < 3 then return end

	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (humanoid and root and humanoid.Health > 0) then return end
	if not Track.InLobby(root.Position) then
		hooks.toast(player, "Start a race from the Race Wars garage.")
		return
	end

	local stats = RaceConfig.CarStats(itemName)
	if not stats then
		hooks.toast(player, "That can't be raced — pick a car.")
		return
	end
	if not hooks.owns(player, itemName) then
		hooks.toast(player, "You don't own that car any more.")
		return
	end
	local ok, reason = hooks.canRace(player)
	if not ok then
		hooks.toast(player, reason)
		return
	end

	lastStart[player] = os.clock()
	startRace(player, itemName, stats)
end)

local _, goHome = Track.Prompts()
if goHome then
	goHome.Triggered:Connect(function(player)
		hooks.sendHome(player)
	end)
end

-- Into the lobby, ending any race first.
function Race.SendToLobby(player)
	local race = races[player]
	if race then endRace(race, "left") end
	local character = player.Character
	if character then
		character:PivotTo(Track.LobbySpawn())
		fire(player, { kind = "arrived" })
	end
end

-- Ends any race this player is in without sending them anywhere.
function Race.Leave(player)
	local race = races[player]
	if race then endRace(race, "left") end
end

function Race.IsRacing(player)
	return races[player] ~= nil
end

Players.PlayerRemoving:Connect(function(player)
	Race.Leave(player)
	lastStart[player] = nil
end)

return Race
