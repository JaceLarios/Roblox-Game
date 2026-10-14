--[[
	RaceDrive (LocalScript, StarterPlayerScripts) — Junkyard Fusion

	Drives your Race Wars car. RaceService builds the car and seats you in
	it; this reads what you ask for (see readInput: the seat, the keys, a
	gamepad, your character's move direction) and turns it into speed and
	heading on the car's drive constraints. The car is in gear from GO and
	drives itself ahead: you steer, and hold back to brake. Driving runs
	here, on your own client, so the car answers instantly; the server
	checks how far it could really have got (see RaceService).

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
local drivingSeat = nil

-- Jumping out of a race car ends your run, and a stray Space bar did it
-- by accident, so there is no jumping while you drive.
local jumpOff = nil -- the humanoid jumping is switched off on
local function allowJump(humanoid, allowed)
	if allowed then
		if jumpOff and jumpOff.Parent then
			jumpOff:SetStateEnabled(Enum.HumanoidStateType.Jumping, true)
		end
		jumpOff = nil
	elseif jumpOff ~= humanoid then
		humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, false)
		jumpOff = humanoid
	end
end

local function stopDriving()
	if driving then
		driving:Disconnect()
		driving = nil
	end
	drivingSeat = nil
	allowJump(nil, true)
end

-- Whether you are in this race seat. Your character usually notices the
-- seat itself (SeatPart), but on a busy server it can miss it (a bat hit
-- had it tumbling, say) while the server has you sat and welded in: the
-- seat's Occupant, which comes from the server, still says so, and the car
-- must drive either way ("the car won't move", 2026-10-13).
local function seated(humanoid, seat)
	return seat.Parent ~= nil and (humanoid.SeatPart == seat or seat.Occupant == humanoid)
end

-- What the driver is asking for, read here from every source there is,
-- since none of them can be counted on alone. A VehicleSeat's ThrottleFloat
-- and SteerFloat are filled in by Roblox's own controls, but only some
-- players get the controls that do it: the place has no PlayerModule, and
-- the built-in controls some clients run left the seat at zero, so the car
-- never moved ("I can't even move when the race starts", 2026-10-13). So
-- also the keys themselves (WASD and arrows), a gamepad's left stick and
-- triggers, and the character's MoveDirection, which every control scheme
-- sets, the touch thumbstick included.
local UserInputService = game:GetService("UserInputService")
local DEADZONE = 0.2
local function keyAxis(positive, negative)
	local value = 0
	for _, key in ipairs(positive) do
		if UserInputService:IsKeyDown(key) then value += 1 break end
	end
	for _, key in ipairs(negative) do
		if UserInputService:IsKeyDown(key) then value -= 1 break end
	end
	return value
end
local AHEAD, BACK = { Enum.KeyCode.W, Enum.KeyCode.Up }, { Enum.KeyCode.S, Enum.KeyCode.Down }
local RIGHT, LEFT = { Enum.KeyCode.D, Enum.KeyCode.Right }, { Enum.KeyCode.A, Enum.KeyCode.Left }

-- The car is in gear from GO (user: "we need to start the race in gear"):
-- it drives itself ahead flat out, and all the driver has to do is steer.
-- Holding back (S, Down, the left trigger, the stick pulled back) brakes,
-- then reverses.
local function readInput(seat, humanoid, chassis)
	local throttle, steer = seat.ThrottleFloat, seat.SteerFloat
	if steer == 0 then steer = keyAxis(RIGHT, LEFT) end
	if throttle == 0 then throttle = keyAxis(AHEAD, BACK) end
	if UserInputService.GamepadEnabled then
		for _, state in ipairs(UserInputService:GetGamepadState(Enum.UserInputType.Gamepad1)) do
			if state.KeyCode == Enum.KeyCode.Thumbstick1 then
				if steer == 0 and math.abs(state.Position.X) > DEADZONE then steer = state.Position.X end
				if throttle == 0 and math.abs(state.Position.Y) > DEADZONE then throttle = state.Position.Y end
			elseif state.KeyCode == Enum.KeyCode.ButtonL2 and state.Position.Z > 0.3 and throttle == 0 then
				throttle = -1
			end
		end
	end
	-- Any controls at all: the way the character is asked to move, turned
	-- into the car's own frame (it is camera-relative, and the camera rides
	-- behind the car).
	if throttle == 0 and steer == 0 then
		local move = humanoid.MoveDirection
		if move.Magnitude > DEADZONE then
			local inCar = chassis.CFrame:VectorToObjectSpace(move)
			throttle = math.clamp(-inCar.Z, -1, 1)
			steer = math.clamp(inCar.X, -1, 1)
		end
	end
	-- In gear: never slower than full ahead unless holding back.
	if throttle > -0.3 then throttle = 1 end
	return throttle, math.clamp(steer, -1, 1)
end

local attempt = nil -- the latest drive() call; an older one still waiting gives way to it

local function drive(humanoid, seat)
	if drivingSeat == seat then return end
	stopDriving()
	local mine = {}
	attempt = mine
	drivingSeat = seat
	local car = seat.Parent
	-- Wait for the car's drive parts for as long as you are still in the
	-- seat. Giving up after a few seconds (as this used to) left a car
	-- whose parts reached this screen late (the place streams) sitting
	-- still for the whole race.
	local chassis, velocity, heading
	while attempt == mine and seated(humanoid, seat) do
		chassis = car and car:FindFirstChild("Chassis")
		velocity = chassis and chassis:FindFirstChild("DriveVelocity")
		heading = chassis and chassis:FindFirstChild("DriveHeading")
		if velocity and heading then break end
		task.wait(0.1)
	end
	if attempt ~= mine or not seated(humanoid, seat) or not (velocity and heading) then
		if attempt == mine then drivingSeat = nil end
		return
	end
	allowJump(humanoid, false)

	local speed = 0
	local _, yaw = chassis.CFrame:ToOrientation()

	driving = RunService.Heartbeat:Connect(function(dt)
		if not seated(humanoid, seat) then
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
		local throttle, steer = readInput(seat, humanoid, chassis)

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
			task.spawn(drive, humanoid, seat)
		end
	end)
end

if player.Character then task.spawn(watchCharacter, player.Character) end
player.CharacterAdded:Connect(watchCharacter)

-- And your car found by its driver tag, a few times a second, in case your
-- character never registered the seat at all (see seated above).
task.spawn(function()
	local live = workspace:WaitForChild("RaceWarsLive")
	while true do
		task.wait(0.25)
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if humanoid and not drivingSeat then
			for _, car in ipairs(live:GetChildren()) do
				local seat = car:FindFirstChild("RaceSeat")
				if seat and seat:GetAttribute("DriverId") == player.UserId and seated(humanoid, seat) then
					task.spawn(drive, humanoid, seat)
					break
				end
			end
		end
	end
end)

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
