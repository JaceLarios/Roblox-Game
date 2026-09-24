--[[
	FusionPadPrompts (LocalScript, StarterPlayerScripts) — Junkyard Fusion

	Your fusion pad has one Fuse prompt and a Remove prompt on each item
	sitting on it, and all of them are on E. Roblox only shows one prompt
	per key at a time, and its pick is not simply the nearest one — left to
	itself it kept showing Fuse while you stood right beside an item, so
	Remove could never be pressed.

	So this decides, on your own screen only: whichever you are standing
	closest to (on the ground, ignoring height) gets the E prompt — an item
	on the pad, or the pad itself — and the others are switched off. Walk
	up to an item and it offers Remove; step back to the pad and it offers
	Fuse again.

	Only your own pad, and only locally. The server never changes these
	prompts' Enabled, and it still checks ownership on every trigger.
--]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local plotsFolder = workspace:WaitForChild("Plots")

-- How often the pick is re-made. Ten times a second is plenty for walking.
local CHECK_EVERY = 0.1

local function flat(v)
	return Vector3.new(v.X, 0, v.Z)
end

local function myPlot()
	for _, plot in ipairs(plotsFolder:GetChildren()) do
		if plot:GetAttribute("OwnerUserId") == player.UserId then
			return plot
		end
	end
	return nil
end

local elapsed = 0
RunService.Heartbeat:Connect(function(dt)
	elapsed += dt
	if elapsed < CHECK_EVERY then return end
	elapsed = 0

	local plot = myPlot()
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not (plot and root) then return end
	local pad = plot:FindFirstChild("FusionPad", true)
	local fuse = pad and pad:FindFirstChild("ProximityPrompt")
	if not fuse then return end

	local here = flat(root.Position)
	local padDistance = (here - flat(pad.Position)).Magnitude

	local removes = {}
	local nearest, nearestDistance = nil, math.huge
	for _, descendant in ipairs(plot:GetDescendants()) do
		if descendant:IsA("ProximityPrompt") and descendant.Name == "RemovePrompt" and descendant.Parent:IsA("BasePart") then
			table.insert(removes, descendant)
			local distance = (here - flat(descendant.Parent.Position)).Magnitude
			if distance < nearestDistance then
				nearest, nearestDistance = descendant, distance
			end
		end
	end

	local offerRemove = nearest ~= nil
		and nearestDistance <= nearest.MaxActivationDistance
		and nearestDistance < padDistance

	for _, remove in ipairs(removes) do
		local want = offerRemove and remove == nearest
		if remove.Enabled ~= want then remove.Enabled = want end
	end
	if fuse.Enabled == offerRemove then
		fuse.Enabled = not offerRemove
	end
end)
