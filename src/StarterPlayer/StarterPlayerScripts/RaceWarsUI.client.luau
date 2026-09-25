--[[
	RaceWarsUI (LocalScript, StarterPlayerScripts) — Junkyard Fusion

	The controller for Race Wars on screen: the lobby panel (time to the
	next race, how many are lined up, whether you are, and your car), the
	Race Garage where you pick which car you race in, and the race HUD.
	RaceWarsView owns every bit of the look.

	Races run on a schedule (RaceService): stand in the line-up box when
	the timer runs out and you race. Picking a car only chooses it for
	next time; without a pick you race your fastest.

	Your cars come from the GameUpdate payload the Inventory already uses
	(inventory and placed), so nothing new is sent for the picker. The
	schedule and the line-up are attributes (on Workspace for everyone,
	on your player for you); race moments come on the RaceEvent remote and
	the running numbers as attributes on your player.
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ProximityPromptService = game:GetService("ProximityPromptService")

local RaceConfig = require(ReplicatedStorage:WaitForChild("RaceConfig"))
local View = require(script.Parent:WaitForChild("RaceWarsView"))

local player = Players.LocalPlayer
local gameUpdate = ReplicatedStorage:WaitForChild("GameUpdate")
local pickRemote = ReplicatedStorage:WaitForChild("RacePick")
local eventRemote = ReplicatedStorage:WaitForChild("RaceEvent")

local owned = { inventory = {}, placed = {} }
local racing = false
local topSpeed = 0

-- The engine the gauge cluster shows. Cars have no real gears, so the revs
-- come from the speed: six gears spread evenly up to the car's top speed,
-- each running from about 3,400 to 7,000 rpm before the next one takes
-- over, revving off the line at a standstill and bouncing off the limiter
-- flat out.
local GEARS = 6
local function engine(speed, top, throttle)
	local fraction = math.clamp(speed / math.max(top, 1), 0, 1)
	local gear = math.clamp(math.floor(fraction * GEARS * 0.999) + 1, 1, GEARS)
	local within = math.clamp(fraction * GEARS - (gear - 1), 0, 1)
	local rpm = gear == 1 and (900 + within * 6100) or (3400 + within * 3600)
	if throttle > 0 and fraction < 0.04 then
		rpm = math.max(rpm, 2800)
	end
	if throttle > 0 and fraction > 0.985 then
		rpm = 7000 + math.sin(os.clock() * 45) * 200
	end
	return rpm, gear
end
local trackLength = #RaceConfig.Levels * RaceConfig.LEVEL_LENGTH

gameUpdate.OnClientEvent:Connect(function(data)
	if type(data) ~= "table" then return end
	if data.inventory then owned.inventory = data.inventory end
	if data.placed then owned.placed = data.placed end
end)

-- Every drivable car you own, fastest first. One card per name: two of
-- the same car race the same.
local function carList()
	local cars, seen = {}, {}
	local function add(entry, onPad)
		local name = entry.name
		if seen[name] then
			if onPad then seen[name].onPad = true end
			return
		end
		local stats = RaceConfig.CarStats(name)
		if not stats then return end
		local reach = RaceConfig.ReachableLevel(stats.topSpeed)
		local car = {
			name = name,
			topSpeed = stats.topSpeed,
			reach = reach,
			reachName = reach > 0 and RaceConfig.Levels[reach].name or "",
			onPad = onPad,
		}
		seen[name] = car
		table.insert(cars, car)
	end
	for _, entry in ipairs(owned.placed) do add(entry, true) end
	for _, entry in ipairs(owned.inventory) do add(entry, false) end
	table.sort(cars, function(a, b) return a.topSpeed > b.topSpeed end)
	return cars
end

-- The car you will race next: your pick while you still own it, else
-- your fastest (what the server falls back to as well).
local function nextCar()
	local cars = carList()
	local picked = player:GetAttribute("RacePicked")
	for _, car in ipairs(cars) do
		if car.name == picked then return car end
	end
	return cars[1]
end

local function openPicker()
	if racing then return end
	local chosen = nextCar()
	View.ShowPicker(carList(), chosen and chosen.name, function(itemName)
		View.HidePicker()
		pickRemote:FireServer(itemName)
	end)
end

ProximityPromptService.PromptTriggered:Connect(function(prompt)
	if prompt.Name == "ChooseCar" then
		openPicker()
	end
end)
View.OnChooseCar(openPicker)

local function ordinal(n)
	local last2 = n % 100
	local suffix = "TH"
	if last2 < 11 or last2 > 13 then
		suffix = ({ "ST", "ND", "RD" })[n % 10] or "TH"
	end
	return tostring(n) .. suffix
end

-- "2ND OF 5 · " for a race with others in it; nothing when you raced
-- alone.
local function placeText(event)
	if (event.of or 1) <= 1 then return "" end
	return string.format("%s OF %d · ", ordinal(event.place or 1), event.of)
end

local function cratesText(count)
	count = count or 0
	if count == 0 then return "no crates" end
	return string.format("%d crate%s won", count, count == 1 and "" or "s")
end

eventRemote.OnClientEvent:Connect(function(event)
	if type(event) ~= "table" then return end
	local kind = event.kind
	if kind == "arrived" then
		racing = false
		View.HideHud()
		-- Face the start, whichever way the camera happened to be looking.
		-- A beat later, so the move to the lobby has reached this client.
		local facing = typeof(event.facing) == "Vector3" and event.facing or nil
		task.delay(0.2, function()
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart")
			local camera = workspace.CurrentCamera
			if not (root and camera and facing) then return end
			camera.CFrame = CFrame.lookAt(root.Position - facing * 14 + Vector3.new(0, 6, 0), root.Position + facing * 20)
		end)
	elseif kind == "countdown" then
		racing = true
		topSpeed = event.topSpeed or 0
		View.HidePicker()
		View.ShowHud(#RaceConfig.Levels)
		View.Countdown(event.seconds or 3)
	elseif kind == "caught" then
		racing = false
		View.HideHud()
		View.Banner("CAUGHT!", placeText(event) .. (event.cleared > 0
			and string.format("cleared %d level%s · %s", event.cleared, event.cleared == 1 and "" or "s", cratesText(event.crates))
			or "it got you on Level 1 — try a faster car"), View.Colours.red)
	elseif kind == "finished" then
		racing = false
		View.HideHud()
		local won = (event.of or 1) > 1 and event.place == 1
		View.Banner(won and "YOU WON!" or "YOU ESCAPED!", placeText(event) .. "every level cleared · " .. cratesText(event.crates),
			View.Colours.gold)
	elseif kind == "bailed" then
		racing = false
		View.HideHud()
		View.Banner("BAILED OUT", placeText(event) .. cratesText(event.crates), View.Colours.white)
	elseif kind == "ended" then
		racing = false
		View.HideHud()
	end
end)

-- The lobby panel, whenever you are in the lobby and not racing.
local function updateLobby()
	if racing or not player:GetAttribute("RaceLobby") then
		View.HideLobby()
		return
	end
	local car = nextCar()
	View.UpdateLobby({
		secondsLeft = (workspace:GetAttribute("RaceNextAt") or 0) - workspace:GetServerTimeNow(),
		running = workspace:GetAttribute("RaceRunning") == true,
		inLine = workspace:GetAttribute("RaceQueueCount") or 0,
		queued = player:GetAttribute("RaceQueued") == true,
		carName = car and car.name,
		carSpeed = car and car.topSpeed,
	})
end

-- The running numbers, every frame while racing.
RunService.RenderStepped:Connect(function()
	updateLobby()
	if not racing then return end
	local levelIndex = player:GetAttribute("RaceLevel") or 1
	local distance = player:GetAttribute("RaceDistance") or 0
	local gap = player:GetAttribute("RaceGap") or RaceConfig.MAX_GAP
	local monsterSpeed = player:GetAttribute("RaceMonsterSpeed") or 0
	local level = RaceConfig.Levels[levelIndex] or RaceConfig.Levels[1]
	local racers = player:GetAttribute("RaceRacers") or 1

	local speed = 0
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local seat = humanoid and humanoid.SeatPart
	local chassis = seat and seat.Parent and seat.Parent:FindFirstChild("Chassis")
	if chassis then
		speed = chassis.AssemblyLinearVelocity:Dot(chassis.CFrame.LookVector)
	end
	local throttle = seat and seat:IsA("VehicleSeat") and seat.Throttle or 0
	local rpm, gear = engine(math.max(speed, 0), topSpeed, throttle)

	View.UpdateHud({
		level = levelIndex,
		levelName = level.name,
		place = racers > 1 and ordinal(player:GetAttribute("RacePlace") or 1) .. " / " .. racers or nil,
		progress = distance / trackLength,
		monsterProgress = (distance - gap) / trackLength,
		gap = gap,
		monsterSpeed = monsterSpeed,
		speed = speed,
		topSpeed = topSpeed,
		rpm = rpm,
		gear = gear,
	})
end)
