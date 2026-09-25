--[[
	BatSwing (LocalScript, StarterPlayerScripts) — Junkyard Fusion

	The bat's swing: a flat cross swing, the bat held out straight from the
	fist and swept from the right side across to the left, the body turning
	into it. Played in code, by overriding the arm's joints for a moment on
	top of whatever animation is running, so no animation asset is needed.

	Your own swing plays the moment you click (the server's swingBat decides
	who it hits); everyone else's arrives on the BatSwing remote. R15 only:
	on an R6 rig nothing is overridden.
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local swingRemote = ReplicatedStorage:WaitForChild("BatSwing")

-- Must match BAT_COOLDOWN in PlotManager, so a swing only plays when the
-- server will take it.
local COOLDOWN = 1.2
local SWING_SECONDS = 0.45

-- Where the arm points, in degrees, as the swing goes: turned round to
-- the right and back for the wind-up, then swept across to the left.
local WIND_YAW, FINISH_YAW = -115, 80
local ARM_PITCH = 82
-- How far the wrist turns the bat down from standing up out of the fist:
-- enough to hold it out level, as an extension of the arm.
local WRIST_TURN = -55

local swinging = {} -- [character] = { joints, started }

local function jointsOf(character)
	local upperArm = character:FindFirstChild("RightUpperArm")
	local lowerArm = character:FindFirstChild("RightLowerArm")
	local hand = character:FindFirstChild("RightHand")
	local upperTorso = character:FindFirstChild("UpperTorso")
	local joints = {
		shoulder = upperArm and upperArm:FindFirstChild("RightShoulder"),
		elbow = lowerArm and lowerArm:FindFirstChild("RightElbow"),
		wrist = hand and hand:FindFirstChild("RightWrist"),
		waist = upperTorso and upperTorso:FindFirstChild("Waist"),
	}
	if joints.shoulder and joints.elbow and joints.wrist then
		return joints
	end
	return nil
end

local function play(character)
	if not character then return end
	local joints = jointsOf(character)
	if not joints then return end
	swinging[character] = { joints = joints, started = os.clock() }
end

local function easeOut(x)
	return 1 - (1 - x) * (1 - x)
end

-- The arm's pose at `u` (0 to 1 through the swing), and how much of it to
-- show over the animation underneath (fading in and out at the ends).
local function pose(u)
	local yaw
	if u < 0.3 then
		yaw = WIND_YAW * easeOut(u / 0.3)
	elseif u < 0.62 then
		yaw = WIND_YAW + (FINISH_YAW - WIND_YAW) * easeOut((u - 0.3) / 0.32)
	else
		yaw = FINISH_YAW
	end
	local weight = 1
	if u < 0.12 then
		weight = u / 0.12
	elseif u > 0.75 then
		weight = (1 - u) / 0.25
	end
	return math.rad(yaw), weight
end

-- After the Animator has set the joints for this frame, so the swing sits
-- on top of it.
RunService.Stepped:Connect(function()
	local now = os.clock()
	for character, swing in pairs(swinging) do
		local u = (now - swing.started) / SWING_SECONDS
		local joints = swing.joints
		if u >= 1 or not character.Parent or not joints.shoulder.Parent then
			swinging[character] = nil
		else
			local yaw, weight = pose(u)
			local arm = CFrame.Angles(0, yaw, 0) * CFrame.Angles(math.rad(ARM_PITCH), 0, 0)
			joints.shoulder.Transform = joints.shoulder.Transform:Lerp(arm, weight)
			-- A straight arm, and the wrist turned so the bat is held out
			-- level instead of standing up out of the fist.
			joints.elbow.Transform = joints.elbow.Transform:Lerp(CFrame.new(), weight)
			joints.wrist.Transform = joints.wrist.Transform:Lerp(CFrame.Angles(math.rad(WRIST_TURN), 0, 0), weight)
			if joints.waist then
				joints.waist.Transform = joints.waist.Transform:Lerp(CFrame.Angles(0, yaw * 0.3, 0), weight)
			end
		end
	end
end)

swingRemote.OnClientEvent:Connect(function(character)
	if typeof(character) == "Instance" and character ~= player.Character then
		play(character)
	end
end)

-- Your own bat: plays straight away rather than waiting on the server.
local readyAt = 0
local hooked = setmetatable({}, { __mode = "k" })
local function hook(tool)
	if not tool:IsA("Tool") or tool.Name ~= "Bat" or hooked[tool] then return end
	hooked[tool] = true
	tool.Activated:Connect(function()
		local now = os.clock()
		if now < readyAt then return end
		readyAt = now + COOLDOWN
		play(player.Character)
	end)
end

local function watch(container)
	for _, child in ipairs(container:GetChildren()) do hook(child) end
	container.ChildAdded:Connect(hook)
end

player.CharacterAdded:Connect(watch)
if player.Character then watch(player.Character) end
watch(player:WaitForChild("Backpack"))
player.ChildAdded:Connect(function(child)
	if child:IsA("Backpack") then watch(child) end
end)
