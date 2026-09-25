--[[
	RaceService (ModuleScript, ServerScriptService) — Junkyard Fusion

	Runs Race Wars races. They run on a schedule, one every
	RaceConfig.RACE_INTERVAL seconds: everyone standing in the line-up box
	in front of the start when the timer runs out races together. Each
	racer gets a drivable copy of the car they picked in the Race Garage
	(RaceWarsUI; their fastest car if they never picked), set on the
	starting grid from the middle out, and drives it themselves (RaceDrive,
	on their own client). Cars pass through each other.

	One monster chases the whole pack at the speed of whichever level it
	is on (RaceConfig), always after the racer at the back: it sprints to
	catch up when that racer gets far ahead, and catches them first. Every
	level a racer clears wins them a crate; their run ends when the monster
	catches them, they reach the finish, or they leave the car. Places go
	to finishers in the order they finish, then to everyone caught, last
	caught highest.

	Racing never uses the car up — the item stays wherever it is, in
	Inventory or on a pad. What you drive is a copy.

	PlotManager owns player data, so it hands this module what it needs
	through Race.Configure (the same "inject after require" shape used for
	other services): which cars a player owns, whether they can race right
	now, and what to do when a level is cleared.

	The client drives its own car (so steering feels instant), which means
	the server never trusts where the client says the car is: a racer's
	progress only counts up as fast as that car could really have driven.
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local RunService = game:GetService("RunService")

local RaceConfig = require(ReplicatedStorage:WaitForChild("RaceConfig"))
local ItemVisuals = require(ReplicatedStorage:WaitForChild("ItemVisuals"))
local Mutations = require(ReplicatedStorage:WaitForChild("Mutations"))
local ItemNames = require(ReplicatedStorage:WaitForChild("ItemNames"))
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

-- Client -> server: the car to race in next time.
local pickRemote = remoteEvent("RacePick")
-- Server -> client: what is happening in your race, as { kind = ... }:
-- "arrived", "countdown", "go", "caught", "finished", "bailed", "ended".
local eventRemote = remoteEvent("RaceEvent")

-- Set by PlotManager (see the header).
local hooks = {
	cars = function() return {} end,
	owns = function() return false end,
	canRace = function() return true end,
	unlocked = function() return true end,
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

local queued = {}     -- [player] = os.clock() they stepped into the line-up
local picks = {}      -- [player] = the car they picked in the Race Garage
local racers = {}     -- [player] = racer, while their run is going
local current = nil   -- the race being run (see startRace), or nil
local monsters = {}   -- [race] = true while its monster is on screen

-- When the next race starts, in workspace:GetServerTimeNow() time, which
-- the clients share, so their countdowns match the board's. The attribute
-- is the schedule itself: set it from the server (a test, an admin) and
-- the next race moves with it.
workspace:SetAttribute("RaceNextAt", workspace:GetServerTimeNow() + RaceConfig.RACE_INTERVAL)

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
	-- Sent to players whole (the place streams): the driver's RaceDrive
	-- needs the seat, the Chassis and its drive constraints all at once.
	car.ModelStreamingMode = Enum.ModelStreamingMode.Atomic

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

-- The fastest car a player owns, for anyone who never picked one.
local function fastestCar(player)
	local best, bestSpeed = nil, -1
	for _, itemName in ipairs(hooks.cars(player)) do
		local stats = RaceConfig.CarStats(itemName)
		if stats and stats.topSpeed > bestSpeed then
			best, bestSpeed = itemName, stats.topSpeed
		end
	end
	return best
end

-- The car a player races in: the one they picked while they still own
-- it, else their fastest.
local function carFor(player)
	local picked = picks[player]
	if picked and hooks.owns(player, picked) then
		return picked
	end
	return fastestCar(player)
end

-- Everything a racing character touches joins the race cars' collision
-- group, so racers pass through each other and the lobby gate.
local function setRacingGroup(racer, racing)
	local character = racer.player.Character
	if racing then
		racer.savedGroups = {}
		if character then
			for _, p in ipairs(character:GetDescendants()) do
				if p:IsA("BasePart") then
					racer.savedGroups[p] = p.CollisionGroup
					p.CollisionGroup = Track.CAR_GROUP
				end
			end
		end
	else
		for p, group in pairs(racer.savedGroups or {}) do
			if p.Parent then p.CollisionGroup = group end
		end
		racer.savedGroups = nil
	end
end

local HUD_ATTRIBUTES = { "RaceLevel", "RaceDistance", "RaceGap", "RaceMonsterSpeed", "RacePlace", "RaceRacers" }
local function clearHud(player)
	for _, name in ipairs(HUD_ATTRIBUTES) do
		player:SetAttribute(name, nil)
	end
end

-- The race is over once nobody is still running: the monster stays a
-- moment on whoever it caught last, then goes.
local function checkOver(race)
	if race.state == "over" or race.finished + race.out < race.count then return end
	race.state = "over"
	if current == race then current = nil end
	task.delay(2.5, function()
		race.monster:Destroy()
	end)
end

-- Ends one racer's run. `outcome` is what they are told: "caught",
-- "finished", "bailed", or "left" (travelled away or quit — nothing to
-- show, no trip back to the lobby).
local function endRun(racer, outcome)
	if racer.state == "out" then return end
	local player, race = racer.player, racer.race
	racer.state = "out"
	if racers[player] == racer then
		racers[player] = nil
	end
	if outcome == "finished" then
		race.finished += 1
		racer.place = race.finished
	else
		racer.place = race.count - race.out
		race.out += 1
	end
	clearHud(player)
	if racer.seat.Parent then
		racer.seat:SetAttribute("Go", false)
	end
	if outcome ~= "left" then
		fire(player, { kind = outcome, cleared = racer.cleared, crates = racer.crates, place = racer.place, of = race.count })
	else
		fire(player, { kind = "ended" })
	end
	if outcome == "finished" then
		local car = ItemNames.Display(racer.itemName)
		if race.count > 1 and racer.place == 1 then
			hooks.broadcast(string.format("%s won the Race Wars race in a %s!", player.Name, car))
		else
			hooks.broadcast(string.format("%s escaped the Race Wars monster in a %s!", player.Name, car))
		end
	end

	local function tidy()
		setRacingGroup(racer, false)
		if racer.humanoid.Parent and racer.humanoid.SeatPart == racer.seat then
			racer.humanoid.Sit = false
		end
		racer.car:Destroy()
	end
	if outcome == "left" then
		tidy()
	else
		-- A moment to see what happened (the monster on you, or the
		-- finish) before being sent back to the lobby.
		task.delay(outcome == "finished" and 3 or 2, function()
			tidy()
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if player.Parent and humanoid and humanoid.Health > 0 and not racers[player] then
				task.wait(0.1)
				character:PivotTo(Track.LobbySpawn())
				fire(player, { kind = "arrived", facing = Track.Heading.LookVector })
			end
		end)
	end
	checkOver(race)
end

-- Puts one racer in their car on the grid, ready for the countdown.
local function seatRacer(race, player, itemName, place)
	local character = player.Character
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local stats = RaceConfig.CarStats(itemName)
	local frame = Track.GridFrame(place)
	local car, chassis, seat = buildCar(player, itemName, stats, frame)
	local distance, offset = Track.DistanceOf(chassis.Position)

	local racer = {
		race = race,
		player = player,
		itemName = itemName,
		stats = stats,
		car = car,
		chassis = chassis,
		seat = seat,
		humanoid = humanoid,
		state = "countdown",
		level = 1,
		cleared = 0,
		crates = 0,
		distance = distance,
		offset = offset,
		checkedAt = os.clock(),
		lastGood = chassis.CFrame,
		hudAt = 0,
	}
	racers[player] = racer
	table.insert(race.racers, racer)

	humanoid.Sit = false
	character:PivotTo(seat.CFrame * CFrame.new(0, 3, 0))
	seat:Sit(humanoid)
	setRacingGroup(racer, true)
	player:SetAttribute("RaceLevel", 1)
	player:SetAttribute("RaceRacers", race.count)
	player:SetAttribute("RacePlace", place)
	player:SetAttribute("RaceGap", math.floor(distance - race.monsterDistance))
	player:SetAttribute("RaceMonsterSpeed", math.floor(race.monsterSpeed))
	fire(player, { kind = "countdown", seconds = COUNTDOWN, item = itemName, topSpeed = stats.topSpeed, racers = race.count })
end

-- Starts a race with everyone in the line-up, in the order they lined up:
-- the first on the grid's centre spot, the rest out either side of them.
local function startRace()
	local lineup = {}
	for player, since in pairs(queued) do
		table.insert(lineup, { player = player, since = since })
	end
	table.sort(lineup, function(a, b) return a.since < b.since end)

	local entries = {}
	for _, entry in ipairs(lineup) do
		local player = entry.player
		local ok, reason = hooks.canRace(player)
		local itemName = ok and carFor(player) or nil
		if not ok then
			hooks.toast(player, reason)
		elseif not itemName then
			hooks.toast(player, "You need a car to race — grab one off the conveyor in the Junkyard.")
		else
			table.insert(entries, { player = player, itemName = itemName })
		end
	end
	table.clear(queued)
	if #entries == 0 then return end

	local race = {
		racers = {},
		count = #entries,
		finished = 0,
		out = 0,
		state = "countdown",
		monster = Monster.Create(),
		monsterDistance = Track.MONSTER_START,
		monsterOffset = 0,
		monsterSpeed = RaceConfig.MonsterSpeed(1),
	}
	race.monster.Parent = liveFolder
	monsters[race] = true
	current = race
	for place, entry in ipairs(entries) do
		seatRacer(race, entry.player, entry.itemName, place)
	end

	task.delay(COUNTDOWN, function()
		if race.state ~= "countdown" then return end
		race.state = "racing"
		race.goAt = os.clock()
		for _, racer in ipairs(race.racers) do
			if racer.state == "countdown" then
				if racer.seat.Occupant ~= racer.humanoid then
					endRun(racer, "bailed")
				else
					racer.chassis.Anchored = false
					-- Each car on its own: a car that cannot be handed to its
					-- driver must not stop everyone after it getting "Go".
					local ok, err = pcall(racer.chassis.SetNetworkOwner, racer.chassis, racer.player)
					if not ok then
						warn("[RaceService] Could not give " .. racer.player.Name .. " their car: " .. tostring(err))
					end
					racer.seat:SetAttribute("Go", true)
					racer.state = "racing"
					racer.checkedAt = os.clock()
					fire(racer.player, { kind = "go" })
				end
			end
		end
	end)
end

-- One racer's progress: checked, then counted toward levels and the
-- finish. Returns false once their run is over.
local function stepRacer(racer, now)
	local chassis, humanoid = racer.chassis, racer.humanoid
	if not chassis.Parent or not humanoid.Parent or humanoid.Health <= 0 or racer.seat.Occupant ~= humanoid then
		endRun(racer, "bailed")
		return false
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
		chassis.CFrame = racer.lastGood
	else
		local elapsed = now - racer.checkedAt
		racer.distance = math.min(distance, racer.distance + racer.stats.topSpeed * elapsed * 1.3 + 6)
		racer.offset = offset
		racer.checkedAt = now
		racer.lastGood = chassis.CFrame
	end

	-- Every level cleared wins a crate, quietly: the race carries on.
	while racer.level <= #RaceConfig.Levels and racer.distance >= racer.level * RaceConfig.LEVEL_LENGTH do
		if hooks.levelCleared(racer.player, racer.level) == true then
			racer.crates += 1
		end
		racer.cleared = racer.level
		racer.level += 1
		racer.player:SetAttribute("RaceLevel", math.min(racer.level, #RaceConfig.Levels))
	end
	if racer.level > #RaceConfig.Levels then
		endRun(racer, "finished")
		return false
	end
	return true
end

local function stepRace(race, dt, now)
	local running = {}
	for _, racer in ipairs(race.racers) do
		if racer.state == "racing" and stepRacer(racer, now) then
			table.insert(running, racer)
		end
	end
	if #running == 0 then return end

	-- The monster goes after whoever is at the back, at its own level's
	-- speed, sprinting when they have got too far ahead of it.
	table.sort(running, function(a, b) return a.distance > b.distance end)
	local last = running[#running]
	local monsterLevel = math.clamp(math.floor(math.max(race.monsterDistance, 0) / RaceConfig.LEVEL_LENGTH) + 1,
		1, #RaceConfig.Levels)
	race.monsterSpeed = RaceConfig.MonsterSpeed(monsterLevel)
	if now - race.goAt >= RaceConfig.MONSTER_DELAY then
		local sprint = last.distance - race.monsterDistance > RaceConfig.MAX_GAP and RaceConfig.MONSTER_SPRINT or 1
		race.monsterDistance += race.monsterSpeed * sprint * dt
		race.monsterOffset += (last.offset - race.monsterOffset) * math.min(1, dt * 1.5)

		-- Back to front, so it takes the last car first.
		for i = #running, 1, -1 do
			local racer = running[i]
			if racer.distance - race.monsterDistance > RaceConfig.CATCH_DISTANCE then break end
			endRun(racer, "caught")
			table.remove(running, i)
		end
	end

	for rank, racer in ipairs(running) do
		if now - racer.hudAt > 0.1 then
			racer.hudAt = now
			local player = racer.player
			player:SetAttribute("RaceDistance", math.floor(racer.distance))
			player:SetAttribute("RaceGap", math.floor(racer.distance - race.monsterDistance))
			player:SetAttribute("RaceMonsterSpeed", math.floor(race.monsterSpeed))
			player:SetAttribute("RacePlace", race.finished + rank)
		end
	end
end

RunService.Heartbeat:Connect(function(dt)
	local race = current
	if race and race.state == "racing" then
		stepRace(race, dt, os.clock())
	end

	-- Drawn every frame while on screen, finished races included (the
	-- monster stays on whoever it caught last until the tidy-up).
	local t = os.clock()
	for shown in pairs(monsters) do
		if not shown.monster.Parent then
			monsters[shown] = nil
		else
			local half = Track.WIDTH / 2 - 12
			local offset = math.clamp(shown.monsterOffset, -half, half)
			Monster.Place(shown.monster, CFrame.new(Track.PointAt(shown.monsterDistance, offset, 0)) * Track.Heading, t)
		end
	end
end)

------------------------------------------------------------------
-- The line-up and the schedule
------------------------------------------------------------------

local function setAttribute(instance, name, value)
	if instance:GetAttribute(name) ~= value then
		instance:SetAttribute(name, value)
	end
end

-- Who is standing in the line-up, and who is in the lobby at all (for
-- the lobby's on-screen panel). Returns how many are lined up.
local lockedTold = {} -- [player] = true once told races are locked, until they leave the box
local function refreshQueue()
	local count = 0
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		local root = character and character:FindFirstChild("HumanoidRootPart")
		local here = humanoid ~= nil and root ~= nil and humanoid.Health > 0 and not racers[player]
		local inBox = here and not humanoid.SeatPart and Track.InQueue(root.Position)
		-- Races are locked until a player's first Rebirth: standing in the
		-- box does not line them up, and they are told why, once a visit.
		local inLine = inBox and hooks.unlocked(player)
		if inBox and not inLine then
			if not lockedTold[player] then
				lockedTold[player] = true
				local _, reason = hooks.canRace(player)
				hooks.toast(player, reason or "Races are locked for you right now.")
			end
		elseif not inBox then
			lockedTold[player] = nil
		end
		if inLine then
			queued[player] = queued[player] or os.clock()
			count += 1
		else
			queued[player] = nil
		end
		setAttribute(player, "RaceQueued", inLine == true)
		setAttribute(player, "RaceLobby", (here and Track.InLobby(root.Position)) == true)
	end
	setAttribute(workspace, "RaceQueueCount", count)
	return count
end

local function clock(seconds)
	seconds = math.max(0, math.ceil(seconds))
	return string.format("%d:%02d", seconds // 60, seconds % 60)
end

local function updateBoard(left, count)
	local inLine = count == 1 and "1 RACER IN LINE" or string.format("%d RACERS IN LINE", count)
	if current then
		Track.SetBoard("RACE ON!", string.format("NEXT RACE %s · %s", clock(left), inLine))
	else
		Track.SetBoard("NEXT RACE " .. clock(left), count > 0 and inLine or "STAND IN THE YELLOW BOX TO JOIN")
	end
end

task.spawn(function()
	while true do
		local count = refreshQueue()
		local now = workspace:GetServerTimeNow()
		local nextRaceAt = workspace:GetAttribute("RaceNextAt") or now
		if now >= nextRaceAt then
			if current then
				-- The last race is somehow still going: start this one as
				-- soon as it is over.
				nextRaceAt = now + 5
			else
				nextRaceAt = now + RaceConfig.RACE_INTERVAL
				if count > 0 then
					startRace()
				end
			end
			workspace:SetAttribute("RaceNextAt", nextRaceAt)
		end
		setAttribute(workspace, "RaceRunning", current ~= nil)
		updateBoard(nextRaceAt - now, count)
		task.wait(0.25)
	end
end)

pickRemote.OnServerEvent:Connect(function(player, itemName)
	if type(itemName) ~= "string" then return end
	if not RaceConfig.CarStats(itemName) then
		hooks.toast(player, "That can't be raced — pick a car.")
		return
	end
	if not hooks.owns(player, itemName) then
		hooks.toast(player, "You don't own that car any more.")
		return
	end
	picks[player] = itemName
	player:SetAttribute("RacePicked", itemName)
end)

local _, goHome = Track.Prompts()
if goHome then
	goHome.Triggered:Connect(function(player)
		hooks.sendHome(player)
	end)
end

-- Into the lobby, ending any run first.
function Race.SendToLobby(player)
	local racer = racers[player]
	if racer then endRun(racer, "left") end
	local character = player.Character
	if character then
		character:PivotTo(Track.LobbySpawn())
		fire(player, { kind = "arrived", facing = Track.Heading.LookVector })
	end
end

-- Ends any run this player is in without sending them anywhere.
function Race.Leave(player)
	local racer = racers[player]
	if racer then endRun(racer, "left") end
end

function Race.IsRacing(player)
	return racers[player] ~= nil
end

Players.PlayerRemoving:Connect(function(player)
	Race.Leave(player)
	queued[player] = nil
	picks[player] = nil
	lockedTold[player] = nil
end)

return Race
