--[[
	FusionCelebration (LocalScript, StarterPlayerScripts) — Junkyard Fusion

	This script owns ONLY the mechanics of when the fusion celebration
	plays: listening for the server's FusionCelebration RemoteEvent and
	making sure back-to-back fusions queue instead of overlapping. It has
	no opinion on what the celebration looks like, how long it lasts, or
	how it moves — all of that lives in FusionCelebrationView (a sibling
	ModuleScript), which this script only ever calls through one function,
	View.Play(data). That split is deliberate: this file should basically
	never need to change for a visual/animation redesign, and the view
	file should basically never need to change for a data/trigger change.
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local remote = ReplicatedStorage:WaitForChild("FusionCelebration")
local View = require(script.Parent:WaitForChild("FusionCelebrationView"))

local queue = {}
local playing = false

local function processQueue()
	if playing then return end
	playing = true
	while #queue > 0 do
		local data = table.remove(queue, 1)
		View.Play(data)
	end
	playing = false
end

remote.OnClientEvent:Connect(function(data)
	if type(data) ~= "table" then return end
	-- Cap the queue so a spam-fusing session can't pile up a long backlog
	-- of celebrations to play through after the player's stopped fusing.
	if #queue >= 3 then table.remove(queue, 1) end
	table.insert(queue, data)
	task.spawn(processQueue)
end)
