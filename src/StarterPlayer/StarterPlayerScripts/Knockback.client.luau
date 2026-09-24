--[[
	Knockback (LocalScript, StarterPlayerScripts) — Junkyard Fusion

	Sends you flying when someone hits you with the bat. The server decides
	the hit and the direction (swingBat in PlotManager) and flops you over;
	your own client owns your character's physics, so the launch is applied
	here, where it takes effect straight away.
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local knockback = ReplicatedStorage:WaitForChild("Knockback")

knockback.OnClientEvent:Connect(function(velocity)
	if typeof(velocity) ~= "Vector3" then return end
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not (root and humanoid) or humanoid.Health <= 0 or humanoid.SeatPart then return end
	-- Off the ground first, or the floor's friction eats the push.
	humanoid:ChangeState(Enum.HumanoidStateType.Physics)
	root.AssemblyLinearVelocity = velocity
	-- A tumble as you go.
	root.AssemblyAngularVelocity = Vector3.new(math.random(-8, 8), math.random(-4, 4), math.random(-8, 8))
	task.delay(1.2, function()
		if humanoid.Parent and humanoid.Health > 0 then
			humanoid:ChangeState(Enum.HumanoidStateType.GettingUp)
		end
	end)
end)
