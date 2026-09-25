--[[
	RaceDrive (LocalScript, StarterPlayerScripts) — Junkyard Fusion

	Drives your Race Wars car. RaceService builds the car and seats you in
	it; this reads the seat's throttle and steer (the default controls
	fill those in on every device) and turns them into speed and heading
	on the car's drive constraints. Driving runs here, on your own client,
	so the car answers the controls instantly; the server checks how far
	it could really have got (see RaceService).

	Also lifts the Junkyard's distance fog while you are in the Race Wars
	area, so you can see down the track, and puts it back when you leave,
	and turns the wheels of every car in the race as it goes.
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Lighting = game:GetService("Lighting")

local ItemVisuals = require(ReplicatedStorage:WaitForChild("ItemVisuals"))

local player = Players.LocalPlayer

-- Handling. Speeds are studs per second.
local BRAKE = 90          -- slowing down with S while moving forward
local COAST = 22          -- slowing down with no throttle
local REVERSE_SPEED = 18
-- Steering only bites once you are moving; at this speed it is full lock.
local FULL_GRIP_SPEED = 25
-- If the car is going this much slower than it is being told to (it hit
-- something), its speed drops to what it is really doing.
local CRASH_SLACK = 12

------------------------------------------------------------------
-- Driving
------------------------------------------------------------------

local driving = nil

local function stopDriving()
	if driving then
		driving:Disconnect()
		driving = nil
	end
end

local attempt = nil -- the latest drive() call; an older one still waiting gives way to it

local function drive(humanoid, seat)
	stopDriving()
	local mine = {}
	attempt = mine
	local car = seat.Parent
	-- Wait for the car's drive parts for as long as you are still in the
	-- seat. Giving up after a few seconds (as this used to) left a car
	-- whose parts reached this screen late (the place streams) sitting
	-- still for the whole race.
	local chassis, velocity, heading
	while attempt == mine and humanoid.SeatPart == seat and seat.Parent do
		chassis = car and car:FindFirstChild("Chassis")
		velocity = chassis and chassis:FindFirstChild("DriveVelocity")
		heading = chassis and chassis:FindFirstChild("DriveHeading")
		if velocity and heading then break end
		task.wait(0.1)
	end
	if attempt ~= mine or humanoid.SeatPart ~= seat or not (velocity and heading) then return end

	local speed = 0
	local _, yaw = chassis.CFrame:ToOrientation()

	driving = RunService.Heartbeat:Connect(function(dt)
		if humanoid.SeatPart ~= seat or not seat.Parent then
			stopDriving()
			return
		end
		if not seat:GetAttribute("Go") then
			speed = 0
			velocity.PlaneVelocity = Vector2.zero
			return
		end

		local top = seat:GetAttribute("TopSpeed") or 50
		local accel = seat:GetAttribute("Accel") or 40
		local turnRate = seat:GetAttribute("TurnRate") or 1.8
		local throttle, steer = seat.ThrottleFloat, seat.SteerFloat

		-- Hitting something costs you your speed.
		local actual = chassis.AssemblyLinearVelocity:Dot(chassis.CFrame.LookVector)
		if speed > 0 and actual < speed - CRASH_SLACK then
			speed = math.max(actual, 0)
		elseif speed < 0 and actual > speed + CRASH_SLACK then
			speed = math.min(actual, 0)
		end

		if throttle > 0 then
			speed = math.min(top, speed + accel * throttle * dt)
		elseif throttle < 0 then
			if speed > 0 then
				speed = math.max(0, speed - BRAKE * dt)
			else
				speed = math.max(-REVERSE_SPEED, speed - accel * 0.5 * dt)
			end
		elseif speed > 0 then
			speed = math.max(0, speed - COAST * dt)
		else
			speed = math.min(0, speed + COAST * dt)
		end

		local grip = math.clamp(math.abs(speed) / FULL_GRIP_SPEED, 0, 1)
		yaw -= steer * turnRate * grip * dt * (speed < 0 and -1 or 1)
		local facing = CFrame.Angles(0, yaw, 0)
		heading.CFrame = facing
		local direction = facing.LookVector * speed
		velocity.PlaneVelocity = Vector2.new(direction.X, direction.Z)
	end)
end

local function watchCharacter(character)
	local humanoid = character:WaitForChild("Humanoid")
	humanoid:GetPropertyChangedSignal("SeatPart"):Connect(function()
		local seat = humanoid.SeatPart
		if seat and seat:GetAttribute("RaceSeat") then
			drive(humanoid, seat)
		else
			stopDriving()
		end
	end)
end

if player.Character then task.spawn(watchCharacter, player.Character) end
player.CharacterAdded:Connect(watchCharacter)

------------------------------------------------------------------
-- Fog
------------------------------------------------------------------

local RACE_FOG_START, RACE_FOG_END = 700, 3200
local RACE_ATMOSPHERE_DENSITY = 0.08

local area = workspace:WaitForChild("RaceWars")
local origin = area:GetAttribute("Origin")
local length = area:GetAttribute("Length")
local lobbyDepth = area:GetAttribute("LobbyDepth")
local halfWidth = area:GetAttribute("Width") / 2 + 20

local saved = nil

local function inArea(position)
	-- The track runs from the origin toward -Z; the lobby is behind it.
	local distance = origin.Z - position.Z
	return distance > -lobbyDepth - 30 and distance < length + 30
		and math.abs(position.X - origin.X) < halfWidth
end

RunService.Heartbeat:Connect(function()
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local inside = root ~= nil and inArea(root.Position)
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if inside and not saved then
		saved = {
			fogStart = Lighting.FogStart,
			fogEnd = Lighting.FogEnd,
			density = atmosphere and atmosphere.Density,
		}
		Lighting.FogStart = RACE_FOG_START
		Lighting.FogEnd = RACE_FOG_END
		if atmosphere then atmosphere.Density = RACE_ATMOSPHERE_DENSITY end
	elseif not inside and saved then
		Lighting.FogStart = saved.fogStart
		Lighting.FogEnd = saved.fogEnd
		if atmosphere and saved.density then atmosphere.Density = saved.density end
		saved = nil
	end
end)

------------------------------------------------------------------
-- Wheels
------------------------------------------------------------------

-- Every race car's wheels turn with its speed, yours and everyone else's,
-- on this screen only: turned on the server, every wheel would be sent to
-- every player each frame. A car is its item model (the body, nose along
-- its +Z) welded onto an invisible Chassis (see RaceService.buildCar).
-- Only models with separate wheels (Codex's rebuilds) have any to turn.
local live = workspace:WaitForChild("RaceWarsLive")

-- The most a wheel turns in a frame, in radians. At race speed a wheel
-- would turn more than a spoke's width a frame and look still or even
-- backwards; held to this it reads as a fast forward spin.
local MAX_WHEEL_TURN = 0.35

RunService.RenderStepped:Connect(function(dt)
	for _, car in ipairs(live:GetChildren()) do
		local chassis = car:IsA("Model") and car:FindFirstChild("Chassis")
		if chassis then
			for _, body in ipairs(car:GetChildren()) do
				if body:IsA("BasePart") and body:GetAttribute("ItemAssembly") then
					local speed = chassis.AssemblyLinearVelocity:Dot(body.CFrame.ZVector)
					ItemVisuals.RollWheels(body, speed * dt, MAX_WHEEL_TURN)
				end
			end
		end
	end
end)
