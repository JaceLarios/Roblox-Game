--[[
	RaceWorkshop (LocalScript, StarterPlayerScripts) — Junkyard Fusion

	Sets the Race Workshop's mechanic (ServerStorage.RaceWorkshop) working,
	on this screen: bent over the car on the lift, ratcheting with the
	wrench in his right hand, the other hand on the car; every so often he
	straightens up for a breather and looks round, then gets back to it.
	Done by turning his joints each frame (their Transform, as CarryPose
	does), so it needs no uploaded animation and costs the server nothing.
	He is only animated while someone could see him.
--]]

local RunService = game:GetService("RunService")

local workshop = workspace:WaitForChild("RaceWorkshop", 120)
local mechanic = workshop and workshop:WaitForChild("Mechanic", 60)
if not mechanic then return end

-- His joints: AnimationConstraints (how Roblox builds rigs now) or Motor6Ds,
-- either takes a Transform.
local function joint(partName, jointName)
	local p = mechanic:WaitForChild(partName, 10)
	local j = p and p:FindFirstChild(jointName)
	return j and (j:IsA("Motor6D") or j:IsA("AnimationConstraint")) and j or nil
end
local waist = joint("UpperTorso", "Waist")
local neck = joint("Head", "Neck")
local rightShoulder = joint("RightUpperArm", "RightShoulder")
local rightElbow = joint("RightLowerArm", "RightElbow")
local leftShoulder = joint("LeftUpperArm", "LeftShoulder")
local leftElbow = joint("LeftLowerArm", "LeftElbow")
local root = mechanic:FindFirstChild("HumanoidRootPart")

-- Seconds bent over working, then seconds straightened up, then again.
local WORK, REST, EASE = 7, 2.5, 0.6
local SEEN_FROM = 250 -- studs: further than this nobody can tell

local function smooth(x)
	x = math.clamp(x, 0, 1)
	return x * x * (3 - 2 * x)
end

local function set(motor, cf)
	if motor then motor.Transform = cf end
end

RunService.Stepped:Connect(function()
	if not mechanic.Parent then return end
	local camera = workspace.CurrentCamera
	if not (camera and root) or (camera.CFrame.Position - root.Position).Magnitude > SEEN_FROM then return end
	local t = os.clock()
	local phase = t % (WORK + REST)
	-- How bent over he is: 1 while working, easing up at the end of it
	-- and back down at the end of the breather.
	local work
	if phase < WORK then
		work = 1 - smooth((phase - (WORK - EASE)) / EASE)
	else
		work = smooth((phase - WORK - (REST - EASE)) / EASE)
	end
	local rest = 1 - work
	local ratchet = math.sin(t * 8)

	set(waist, CFrame.Angles(-0.5 * work, 0, 0))
	set(neck, CFrame.Angles(-0.35 * work + 0.08 * rest, 0.55 * rest * math.sin(t * 0.9), 0))
	set(rightShoulder, CFrame.Angles((0.95 + 0.25 * ratchet) * work, 0, 0.1 * work))
	set(rightElbow, CFrame.Angles((0.75 + 0.3 * ratchet) * work, 0, 0))
	set(leftShoulder, CFrame.Angles(0.85 * work, 0, -0.2 * work))
	set(leftElbow, CFrame.Angles(0.45 * work, 0, 0))
end)
