--[[
	AdminService (Script, ServerScriptService) — Junkyard Fusion

	Carries out what the admin panel (AdminPanel.client) asks for, and only
	for admins (AdminConfig). Each action pulls a lever another script
	already watches, so nothing else depends on this one:
	  legendary   drop the secret Legendary now and restart its 20 minutes
	              (ScrapSpawner watches workspace's LegendaryDropAt)
	  race        start the next race now, for whoever is lined up
	              (RaceService watches workspace's RaceNextAt)
	  CraneDrop, ScrapRush, MutationFrenzy
	              run that yard event now (ScrapSpawner's TriggerYardEvent)
	Showing the whole Index needs nothing from the server: it is only on
	the admin's own screen.
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AdminConfig = require(ReplicatedStorage:WaitForChild("AdminConfig"))

local remote = ReplicatedStorage:FindFirstChild("AdminAction")
if not remote then
	remote = Instance.new("RemoteEvent")
	remote.Name = "AdminAction"
	remote.Parent = ReplicatedStorage
end

local YARD_EVENTS = { CraneDrop = true, ScrapRush = true, MutationFrenzy = true }

remote.OnServerEvent:Connect(function(player, action)
	if not AdminConfig.IsAdmin(player) or type(action) ~= "string" then
		return
	end
	local now = workspace:GetServerTimeNow()
	local done
	if action == "legendary" then
		workspace:SetAttribute("LegendaryDropAt", now)
		done = "Secret Legendary dropping now."
	elseif action == "race" then
		workspace:SetAttribute("RaceNextAt", now + 1)
		done = "Next race starting now (for anyone in line)."
	elseif YARD_EVENTS[action] then
		workspace:SetAttribute("TriggerYardEvent", action)
		done = action .. " starting now."
	else
		return
	end
	print(string.format("[Admin] %s: %s", player.Name, action))
	remote:FireClient(player, done)
end)
