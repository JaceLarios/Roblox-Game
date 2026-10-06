--[[
	AdminService (Script, ServerScriptService) — Junkyard Fusion

	Carries out what the admin panel (AdminPanel.client) asks for, and only
	for admins (AdminConfig). Each action pulls a lever another script
	already watches, so nothing else depends on this one:
	  legendary   drop the secret Legendary now and restart its 20 minutes
	              (ScrapSpawner watches workspace's LegendaryDropAt)
	  race        cut the line-up countdown short: the race starts now, for
	              whoever is lined up (RaceService's RaceNextAt)
	  CraneDrop, ScrapRush, MutationFrenzy
	              run that yard event now (ScrapSpawner's TriggerYardEvent)
	  SecretCar   a Secret car rolls out of the black box now (the same way)
	  bolts       +100 bolts, to try the Phantom Garage without racing
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

local YARD_EVENTS = { CraneDrop = true, ScrapRush = true, MutationFrenzy = true, SecretCar = true }

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
		done = "Race starting now, if anyone is in the yellow box."
	elseif YARD_EVENTS[action] then
		workspace:SetAttribute("TriggerYardEvent", action)
		done = action .. " starting now."
	elseif action == "bolts" then
		local stats = player:FindFirstChild("leaderstats")
		local bolts = stats and stats:FindFirstChild("Bolts")
		if not bolts then return end
		bolts.Value += 100
		done = "+100 bolts."
	else
		return
	end
	print(string.format("[Admin] %s: %s", player.Name, action))
	remote:FireClient(player, done)
end)
