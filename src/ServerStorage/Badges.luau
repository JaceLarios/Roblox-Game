--[[
	Badges (ModuleScript, ServerStorage) — Junkyard Fusion

	Roblox badges for the game's milestones (the user, 2026-10-09). Each
	badge is made on the Creator Hub (the game's Badges page), and its id
	pasted into LIST below; one left at 0 is simply never awarded, so the
	game runs the same before they exist. Names and descriptions here are
	what to type in when making them (docs/BADGES.md has the list and the
	icons, assets/badges).

	Award(player, key) gives one badge at the moment it happens; Check()
	gives every badge a player already qualifies for, and is cheap enough
	to call on every UI push. Each badge is checked against
	Roblox once per player per server, so nothing is asked twice.
--]]

local BadgeService = game:GetService("BadgeService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local FusionRecipes = require(ReplicatedStorage:WaitForChild("FusionRecipes"))

local Badges = {}

Badges.LIST = {
	welcome      = { id = 2018639245002603, name = "Welcome to the Junkyard", description = "Join Junkyard Fusion." },
	firstFusion  = { id = 3372506036321754, name = "First Fusion", description = "Fuse a car with an addon at your Fusion Pad." },
	firstGhost   = { id = 1195291716831241, name = "Ghost Rider", description = "Put a Phantom on a car and make it a ghost." },
	secretCar    = { id = 0, name = "Secret Find", description = "Get one of the Secret cars." },
	firstRebirth = { id = 1698272688187589, name = "Born Again", description = "Rebirth for the first time." },
	maxRebirth   = { id = 0, name = "Ceiling Breaker", description = "Reach the highest Rebirth." },
	raceFinish   = { id = 3321738086322531, name = "Outran the Monster", description = "Finish a Race Wars race." },
	collector    = { id = 0, name = "Collector", description = "Discover 25 builds in the Index." },
	masterBuilder = { id = 0, name = "Master Builder", description = "Discover every fusion build in the Index." },
	ghostCollector = { id = 0, name = "Ghost Collector", description = "Fill the whole Spectral tab: every Phantom on every car." },
}

-- How many of each the collection badges need.
local COLLECTOR_BUILDS = 25

local done = {} -- [player] = { [key] = true } once asked or given this server

function Badges.Award(player, key)
	local badge = Badges.LIST[key]
	if not (badge and badge.id ~= 0 and player and player.Parent) then return end
	done[player] = done[player] or {}
	if done[player][key] then return end
	done[player][key] = true
	task.spawn(function()
		local ok, has = pcall(BadgeService.UserHasBadgeAsync, BadgeService, player.UserId, badge.id)
		if ok and has then return end
		local awarded, err = pcall(BadgeService.AwardBadge, BadgeService, player.UserId, badge.id)
		if not awarded then
			-- Let a later call try again (a throttled or offline badge service).
			if done[player] then done[player][key] = nil end
			warn("[Badges] Could not award " .. key .. " to " .. player.Name .. ": " .. tostring(err))
		end
	end)
end

-- Every badge that comes from where a player stands rather than one
-- moment: joining, Secret cars found, builds discovered (every fusion
-- build), Spectral entries (a Phantom on each car) and Rebirths. Cheap
-- (each badge is only ever asked about once), so PlotManager calls it on
-- every UI push.
function Badges.Check(player, discovered, secretCars, rebirths, maxRebirths)
	Badges.Award(player, "welcome")
	if secretCars and next(secretCars) then Badges.Award(player, "secretCar") end
	local builds, spectral = 0, 0
	for name in pairs(discovered or {}) do
		if FusionRecipes.IsPhantom(name) then spectral += 1 else builds += 1 end
	end
	local spectralTotal = #FusionRecipes.PhantomAddons * #FusionRecipes.Items
	local buildTotal = FusionRecipes.GetTotalDiscoveries() - spectralTotal
	if builds >= COLLECTOR_BUILDS then Badges.Award(player, "collector") end
	if builds >= buildTotal then Badges.Award(player, "masterBuilder") end
	if spectral >= spectralTotal then Badges.Award(player, "ghostCollector") end
	if (rebirths or 0) >= 1 then Badges.Award(player, "firstRebirth") end
	if maxRebirths and (rebirths or 0) >= maxRebirths then Badges.Award(player, "maxRebirth") end
end

Players.PlayerRemoving:Connect(function(player) done[player] = nil end)

return Badges
