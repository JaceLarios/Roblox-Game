--[[
	BaseRaid (LocalScript, StarterPlayerScripts) — Junkyard Fusion

	Every pet pad carries two prompts: Take Off, for its owner, and Steal,
	for everybody else. The server cannot show a ProximityPrompt to one
	player and not another, so both exist for everyone and this hides the
	one that is not yours — Steal on your own pads, Take Off on anyone
	else's — so each pad only ever offers you the thing you can do.

	It only ever switches a prompt OFF, and only locally. Turning one ON is
	always the server's call (it enables a pad's prompts when something is
	placed on it), and the server still checks ownership on every trigger,
	so nothing here decides who is allowed to do what.
--]]

local Players = game:GetService("Players")

local player = Players.LocalPlayer
local plotsFolder = workspace:WaitForChild("Plots")

local ROLE = {
	StealPrompt = "visitor",
	TakeOffPrompt = "owner",
	-- Taking an item back off the fusion pad (PlotManager's refreshPad).
	RemovePrompt = "owner",
}

local function forbidden(prompt)
	local role = ROLE[prompt.Name]
	if not role then return false end
	local plot = prompt:FindFirstAncestorOfClass("Model")
	local mine = plot ~= nil and plot:GetAttribute("OwnerUserId") == player.UserId
	if role == "owner" then
		return not mine
	end
	return mine
end

local function apply(prompt)
	if prompt.Enabled and forbidden(prompt) then
		prompt.Enabled = false
	end
end

local watched = {}

local function watch(prompt)
	if watched[prompt] or not ROLE[prompt.Name] then return end
	watched[prompt] = true
	apply(prompt)
	-- The server re-enables a pad's prompts whenever that pad changes, and
	-- that replicated value overwrites ours, so hide it again each time.
	prompt:GetPropertyChangedSignal("Enabled"):Connect(function()
		apply(prompt)
	end)
	prompt.AncestryChanged:Connect(function(_, parent)
		if not parent then watched[prompt] = nil end
	end)
end

local function watchPlot(plot)
	if not plot:IsA("Model") then return end
	for _, descendant in ipairs(plot:GetDescendants()) do
		if descendant:IsA("ProximityPrompt") then watch(descendant) end
	end
	plot.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("ProximityPrompt") then watch(descendant) end
	end)
	-- Whose plot it is decides which prompt is hidden, so re-check all of
	-- this plot's prompts when that changes.
	plot:GetAttributeChangedSignal("OwnerUserId"):Connect(function()
		for _, descendant in ipairs(plot:GetDescendants()) do
			if descendant:IsA("ProximityPrompt") then apply(descendant) end
		end
	end)
end

for _, plot in ipairs(plotsFolder:GetChildren()) do
	watchPlot(plot)
end
plotsFolder.ChildAdded:Connect(watchPlot)
