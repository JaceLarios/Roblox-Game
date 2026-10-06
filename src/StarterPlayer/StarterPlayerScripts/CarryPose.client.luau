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

	2. The arms are held up by writing each shoulder joint's Transform
	   every frame, just after the animator has written its own (Stepped),
	   so the pose wins over the walk cycle. Both kinds of joint have a
	   Transform: the Motor6D of older rigs and the AnimationConstraint of
	   the newer physics avatar rig. Until 2026-10-05 this played a pose
	   made with KeyframeSequenceProvider:RegisterKeyframeSequence, which
	   works in Studio but not in the published game, where the arms
	   stayed down (the user saw it there).
--]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

-- The part the server welds above a carrier's head. Its presence is the
-- entire signal this script runs on.
local CARRIED_ITEM_NAME = "CarriedItem"

-- Arms straight up, a few degrees off vertical so the hands meet near the
-- centre line instead of crossing.
local RIGHT_ARM_DEGREES = -170
local LEFT_ARM_DEGREES = 170

-- Seconds to raise the arms, and to let them back down.
local BLEND_IN = 0.18
local BLEND_OUT = 0.12

-- Where each rig keeps its shoulder joints: the part holding the joint
-- and the joint's name.
local SHOULDERS = {
	[Enum.HumanoidRigType.R15] = {
		{ part = "RightUpperArm", joint = "RightShoulder", angle = RIGHT_ARM_DEGREES },
		{ part = "LeftUpperArm", joint = "LeftShoulder", angle = LEFT_ARM_DEGREES },
	},
	[Enum.HumanoidRigType.R6] = {
		{ part = "Torso", joint = "Right Shoulder", angle = RIGHT_ARM_DEGREES },
		{ part = "Torso", joint = "Left Shoulder", angle = LEFT_ARM_DEGREES },
	},
}

-- One entry per character being posed: its joints and their raised pose,
-- how far up the arms are (0 to 1), and whether they are going up or down.
local active = {}

local function jointsFor(character)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local layout = humanoid and SHOULDERS[humanoid.RigType]
	if not layout then
		return nil
	end
	local joints = {}
	for _, shoulder in ipairs(layout) do
		local holder = character:FindFirstChild(shoulder.part)
		local joint = holder and holder:FindFirstChild(shoulder.joint)
		if joint and (joint:IsA("Motor6D") or joint:IsA("AnimationConstraint")) then
			table.insert(joints, { joint = joint, pose = CFrame.Angles(0, 0, math.rad(shoulder.angle)) })
		end
	end
	return #joints > 0 and joints or nil
end

local function startPose(character)
	local entry = active[character]
	if entry then
		entry.raising = true
		return
	end
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return
	end
	local joints = jointsFor(character)
	if not joints then
		return
	end
	active[character] = { joints = joints, amount = 0, raising = true }
end

local function stopPose(character)
	local entry = active[character]
	if entry then
		entry.raising = false
	end
end

-- After the animator, before physics: blend each carrier's shoulders from
-- what the animation says toward arms-up, by how far up they are.
RunService.Stepped:Connect(function(_, dt)
	for character, entry in pairs(active) do
		local step = dt / (entry.raising and BLEND_IN or BLEND_OUT)
		entry.amount = math.clamp(entry.amount + (entry.raising and step or -step), 0, 1)
		if entry.amount <= 0 and not entry.raising or not character.Parent then
			active[character] = nil
		else
			-- Eased, so the arms swing up rather than tick up.
			local alpha = entry.amount * entry.amount * (3 - 2 * entry.amount)
			for _, j in ipairs(entry.joints) do
				if j.joint.Parent then
					j.joint.Transform = j.joint.Transform:Lerp(j.pose, alpha)
				end
			end
		end
	end
end)

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
			active[character] = nil
		end
	end)

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		-- Dying drops whatever you were carrying anyway; make sure the arms
		-- come down with it rather than sticking up through the ragdoll.
		humanoid.Died:Connect(function()
			active[character] = nil
		end)
	end
end

local function track(player)
	if player.Character then
		watch(player.Character)
	end
	player.CharacterAdded:Connect(watch)
	player.CharacterRemoving:Connect(function(character)
		active[character] = nil
	end)
end

for _, player in ipairs(Players:GetPlayers()) do
	track(player)
end
Players.PlayerAdded:Connect(track)
