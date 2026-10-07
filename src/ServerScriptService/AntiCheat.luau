--[[
	AntiCheat (ModuleScript, ServerScriptService) — Junkyard Fusion

	Server-side checks against the everyday Roblox exploits (user,
	2026-10-07). Everything that matters is already decided on the server
	(coins, bolts, items, fusing, prices), so a cheater's client can only
	cheat with its own character and by flooding remotes. This watches
	both:

	  speed / teleport  a character moving further than its walk speed
	                    (the server's, which a cheater cannot change) allows
	  fly               a character hanging high in the air without falling
	  noclip            a character passing through a solid wall (a base's,
	                    a building's, the island's edge)
	  remote spam       more than SPAM_PER_SECOND remote calls in a second

	Movement cheats are put back where they last stood legitimately
	(rubber-banding), and STRIKES_TO_KICK of them inside a minute is a kick.
	Remote spam is a kick straight away. Seated players (race cars) are
	left alone, and anything the server itself does to a character (sending
	it home or to the race lobby, putting it in a car) calls Allow first so
	it is not mistaken for a cheat.

	Off in Studio, where test scripts move characters about, unless
	workspace's AntiCheatTest attribute is true.

	Start() once (PlotManager does). Allow(player, seconds) from any server
	script that moves a character itself.
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local AntiCheat = {}

local CHECK_EVERY = 0.25
-- A step may cover walk speed times this, plus SPEED_SLACK studs a second
-- (lag, slopes, being knocked about, riding something) and STEP_SLACK.
local SPEED_FACTOR = 1.4
local SPEED_SLACK = 12
local STEP_SLACK = 5
-- Higher than this over the ground, and not falling, for FLY_SECONDS.
local FLY_HEIGHT = 14
local FLY_SECONDS = 2.5
local STRIKE_WINDOW = 60
local STRIKES_TO_KICK = 8
local SPAM_PER_SECOND = 60

local graceUntil = {} -- [player] = clock time the checks resume
local tracked = {}    -- [player] = { last, lastGood, airTime, strikes }
local started = false

-- The server is about to move this player's character (or just did):
-- leave it alone for `seconds`.
function AntiCheat.Allow(player, seconds)
	graceUntil[player] = math.max(graceUntil[player] or 0, os.clock() + (seconds or 2))
	local entry = tracked[player]
	if entry then entry.last = nil end
end

local function active()
	return not RunService:IsStudio() or workspace:GetAttribute("AntiCheatTest") == true
end

local function kick(player, why)
	warn(string.format("[AntiCheat] Kicked %s: %s", player.Name, why))
	player:Kick("Removed by the anti-cheat: " .. why .. ". If this was a mistake, just rejoin.")
end

local function strike(player, entry, root, why)
	-- Back to where it last stood legitimately.
	if entry.lastGood then
		root.AssemblyLinearVelocity = Vector3.zero
		root.CFrame = CFrame.new(entry.lastGood) * root.CFrame.Rotation
	end
	entry.last = entry.lastGood
	entry.airTime = 0
	local now = os.clock()
	table.insert(entry.strikes, now)
	while entry.strikes[1] and now - entry.strikes[1] > STRIKE_WINDOW do
		table.remove(entry.strikes, 1)
	end
	warn(string.format("[AntiCheat] %s: %s (%d in the last minute)", player.Name, why, #entry.strikes))
	if #entry.strikes >= STRIKES_TO_KICK then
		kick(player, "unusual movement (" .. why .. ")")
	end
end

-- Noclip: the straight line a character moved along this step goes
-- through something solid that nobody can walk through. Only tall, fixed
-- things count, and only well below their top, so stepping up onto a
-- crate or jumping a low wall is never taken for it. Loose scrap, race
-- cars, characters and the player's own base's owner-only parts are not
-- solid to them.
local solidRay = RaycastParams.new()
solidRay.FilterType = Enum.RaycastFilterType.Exclude
solidRay.RespectCanCollide = true
local function throughWall(player, from, to)
	local ignore = {}
	for _, name in ipairs({ "Scrap", "RaceWarsLive" }) do
		local folder = workspace:FindFirstChild(name)
		if folder then table.insert(ignore, folder) end
	end
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then table.insert(ignore, p.Character) end
	end
	local plots = workspace:FindFirstChild("Plots")
	if plots then
		for _, plot in ipairs(plots:GetChildren()) do
			if plot:GetAttribute("OwnerUserId") == player.UserId then
				for _, d in ipairs(plot:GetDescendants()) do
					if d:IsA("BasePart") and string.sub(d.CollisionGroup, 1, 8) == "PlotWall" then
						table.insert(ignore, d)
					end
				end
			end
		end
	end
	solidRay.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(from, to - from, solidRay)
	if not hit then return nil end
	local part = hit.Instance
	if not part.Anchored or part.Size.Y < 8 then return nil end
	local top = part.Position.Y + part.Size.Y / 2
	if hit.Position.Y > top - 3 then return nil end
	return part
end

local groundRay = RaycastParams.new()
groundRay.FilterType = Enum.RaycastFilterType.Exclude
groundRay.RespectCanCollide = true

local function check(player, dt)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (humanoid and root) or humanoid.Health <= 0 then return end
	local entry = tracked[player]
	if not entry then
		entry = { strikes = {}, airTime = 0 }
		tracked[player] = entry
	end
	local position = root.Position
	if humanoid.SeatPart or os.clock() < (graceUntil[player] or 0) or not entry.last then
		entry.last, entry.lastGood, entry.airTime = position, position, 0
		return
	end

	-- Speed and teleports: how far it went across the ground this step.
	local step = Vector3.new(position.X - entry.last.X, 0, position.Z - entry.last.Z).Magnitude
	local allowed = (humanoid.WalkSpeed * SPEED_FACTOR + SPEED_SLACK) * dt + STEP_SLACK
	if step > allowed then
		strike(player, entry, root, string.format("moved %d studs in %.2fs", step, dt))
		return
	end

	-- Noclip: the line it moved along goes through a solid wall.
	if (position - entry.last).Magnitude > 0.5 then
		local wall = throughWall(player, entry.last, position)
		if wall then
			strike(player, entry, root, "went through " .. wall.Name)
			return
		end
	end

	-- Flying: high over the ground and not coming down.
	local ignore = {}
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then table.insert(ignore, p.Character) end
	end
	groundRay.FilterDescendantsInstances = ignore
	local below = workspace:Raycast(position, Vector3.new(0, -(FLY_HEIGHT + 40), 0), groundRay)
	local height = below and (position.Y - below.Position.Y) or math.huge
	if height > FLY_HEIGHT and root.AssemblyLinearVelocity.Y > -6 then
		entry.airTime += dt
		if entry.airTime > FLY_SECONDS then
			strike(player, entry, root, "flying")
			return
		end
	else
		entry.airTime = 0
	end

	entry.last = position
	-- Only somewhere it stood on something counts as a place to put it back.
	if height <= 6 then entry.lastGood = position end
end

-- Remote spam: every RemoteEvent in ReplicatedStorage, now and later.
local calls = {} -- [player] = { second, count }
local function watchRemote(remote)
	if not remote:IsA("RemoteEvent") then return end
	remote.OnServerEvent:Connect(function(player)
		if not active() then return end
		local now = math.floor(os.clock())
		local c = calls[player]
		if not c or c.second ~= now then
			c = { second = now, count = 0 }
			calls[player] = c
		end
		c.count += 1
		if c.count == SPAM_PER_SECOND + 1 then
			kick(player, "too many requests")
		end
	end)
end

function AntiCheat.Start()
	if started then return end
	started = true
	for _, d in ipairs(ReplicatedStorage:GetDescendants()) do watchRemote(d) end
	ReplicatedStorage.DescendantAdded:Connect(watchRemote)

	Players.PlayerAdded:Connect(function(player)
		player.CharacterAdded:Connect(function()
			-- A fresh character spawns somewhere new.
			AntiCheat.Allow(player, 3)
		end)
	end)
	for _, player in ipairs(Players:GetPlayers()) do
		player.CharacterAdded:Connect(function() AntiCheat.Allow(player, 3) end)
	end
	Players.PlayerRemoving:Connect(function(player)
		tracked[player] = nil
		graceUntil[player] = nil
		calls[player] = nil
	end)

	task.spawn(function()
		local last = os.clock()
		while true do
			task.wait(CHECK_EVERY)
			local now = os.clock()
			local dt = now - last
			last = now
			if active() then
				for _, player in ipairs(Players:GetPlayers()) do
					local ok, err = pcall(check, player, dt)
					if not ok then warn("[AntiCheat] " .. tostring(err)) end
				end
			end
		end
	end)
end

return AntiCheat
