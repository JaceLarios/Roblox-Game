--[[
	CarryPose (LocalScript, StarterPlayerScripts) — Junkyard Fusion

	Raises a carrier's arms so the loot over their head reads as being HELD
	rather than hovering there on its own. Runs for every character in the
	server, not just you, so a thief sprinting past looks like they are
	hauling something.

	Two things worth knowing about how this is built:

	1. It is entirely client-side and purely cosmetic. The server already
	   owns what is being carried and welds the item (see PlotManager's
	   attachCarried); this only changes how the body underneath it looks.
	   Nothing here can be trusted or cheated into mattering.

	2. The pose comes from a KeyframeSequence registered at runtime rather
	   than an uploaded animation asset. That matters because an uploaded
	   Animation has to be owned by the place owner to play at all, and
	   because the newer physics avatar rig ignores writes to a joint's
	   Transform outright — posing its arms by hand moves them exactly zero
	   studs. Going through the animator is the only thing that actually
	   works on every rig, and RegisterKeyframeSequence gets us there with
	   no asset to upload. The id it returns is local to this client, which
	   is fine: every client builds its own and plays it locally.
--]]

local Players = game:GetService("Players")
local KeyframeSequenceProvider = game:GetService("KeyframeSequenceProvider")

-- The part the server welds above a carrier's head. Its presence is the
-- entire signal this script runs on.
local CARRIED_ITEM_NAME = "CarriedItem"

-- Arms straight up, a couple of degrees off vertical so the hands meet
-- near the centre line instead of crossing.
local RIGHT_ARM_DEGREES = -170
local LEFT_ARM_DEGREES = 170

local BLEND_IN = 0.18
local BLEND_OUT = 0.12

-- Which limb each rig hangs off which parent. A KeyframeSequence poses by
-- part NAME, so R6 and R15 need separate sequences.
local RIG_CHAINS = {
	[Enum.HumanoidRigType.R15] = {
		spine = { "HumanoidRootPart", "LowerTorso", "UpperTorso" },
		right = "RightUpperArm",
		left = "LeftUpperArm",
	},
	[Enum.HumanoidRigType.R6] = {
		spine = { "HumanoidRootPart", "Torso" },
		right = "Right Arm",
		left = "Left Arm",
	},
}

-- Registered lazily and reused: building the sequence is cheap, but the
-- registration returns a stable id we would rather not churn.
local poseIdByRig = {}

local function poseIdFor(rigType)
	if poseIdByRig[rigType] then
		return poseIdByRig[rigType]
	end
	local chain = RIG_CHAINS[rigType]
	if not chain then
		return nil
	end

	local sequence = Instance.new("KeyframeSequence")
	sequence.Loop = true

	-- Two identical keyframes: a held pose, not a motion. One keyframe
	-- gives a zero-length track that some animators refuse to play.
	for _, time in ipairs({ 0, 1 }) do
		local keyframe = Instance.new("Keyframe")
		keyframe.Time = time

		-- Poses nest the same way the rig does, so the arm has to hang off
		-- the torso chain rather than sitting at the root.
		local root, parent
		for _, partName in ipairs(chain.spine) do
			local pose = Instance.new("Pose")
			pose.Name = partName
			pose.CFrame = CFrame.identity
			pose.Weight = 1
			if parent then
				pose.Parent = parent
			else
				root = pose
			end
			parent = pose
		end

		for angle, partName in pairs({ [RIGHT_ARM_DEGREES] = chain.right, [LEFT_ARM_DEGREES] = chain.left }) do
			local pose = Instance.new("Pose")
			pose.Name = partName
			pose.CFrame = CFrame.Angles(0, 0, math.rad(angle))
			pose.Weight = 1
			pose.Parent = parent
		end

		root.Parent = keyframe
		keyframe.Parent = sequence
	end

	local ok, id = pcall(function()
		return KeyframeSequenceProvider:RegisterKeyframeSequence(sequence)
	end)
	sequence:Destroy()
	if not ok or not id then
		return nil
	end

	poseIdByRig[rigType] = id
	return id
end

-- One entry per character we are currently posing.
local active = {}

local function stopPose(character)
	local entry = active[character]
	if not entry then
		return
	end
	active[character] = nil
	pcall(function()
		entry.track:Stop(BLEND_OUT)
		entry.track:Destroy()
	end)
end

local function startPose(character)
	if active[character] then
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	local animator = humanoid:FindFirstChildOfClass("Animator")
	if not animator then
		return
	end
	local id = poseIdFor(humanoid.RigType)
	if not id then
		return
	end

	local animation = Instance.new("Animation")
	animation.AnimationId = id

	local ok, track = pcall(function()
		return animator:LoadAnimation(animation)
	end)
	animation:Destroy()
	if not ok or not track then
		return
	end

	-- Action4 so it sits above every default movement animation. Without
	-- this the walk cycle's arm swing wins and the arms drop back down
	-- the moment the carrier starts running, which is all of the time.
	track.Priority = Enum.AnimationPriority.Action4
	track.Looped = true
	track:Play(BLEND_IN)

	active[character] = { track = track }
end

local function refresh(character)
	if character:FindFirstChild(CARRIED_ITEM_NAME) then
		startPose(character)
	else
		stopPose(character)
	end
end

local function watch(character)
	refresh(character)
	character.ChildAdded:Connect(function(child)
		if child.Name == CARRIED_ITEM_NAME then
			startPose(character)
		end
	end)
	character.ChildRemoved:Connect(function(child)
		if child.Name == CARRIED_ITEM_NAME then
			stopPose(character)
		end
	end)
	character.AncestryChanged:Connect(function(_, parent)
		if not parent then
			stopPose(character)
		end
	end)

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		-- Dying drops whatever you were carrying anyway; make sure the arms
		-- come down with it rather than sticking up through the ragdoll.
		humanoid.Died:Connect(function()
			stopPose(character)
		end)
	end
end

local function track(player)
	if player.Character then
		watch(player.Character)
	end
	player.CharacterAdded:Connect(watch)
	player.CharacterRemoving:Connect(stopPose)
end

for _, player in ipairs(Players:GetPlayers()) do
	track(player)
end
Players.PlayerAdded:Connect(track)
