local Players = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("GamepassConfig"))
local Service = {}
local owned = {}
local started = false
local changed = Instance.new("BindableEvent")
Service.Changed = changed.Event

local function configured(key)
	local item = Config[key]
	return item and type(item.id) == "number" and item.id > 0 and item.id % 1 == 0
end

local function grant(player, key)
	local flags = owned[player]
	if not flags or flags[key] then return end
	flags[key] = true
	player:SetAttribute("Pass_" .. key, true)
	changed:Fire(player)
end

local function check(player, key)
	if not configured(key) then
		player:SetAttribute("PassStatus_" .. key, "Unavailable")
		return
	end
	for attempt = 1, 3 do
		local ok, hasPass = pcall(function()
			return MarketplaceService:UserOwnsGamePassAsync(player.UserId, Config[key].id)
		end)
		if not owned[player] or player.Parent ~= Players then return end
		if ok then
			if hasPass then grant(player, key) end
			player:SetAttribute("PassStatus_" .. key, "Ready")
			return
		end
		warn("[Gamepasses] Ownership check failed for " .. key .. " (attempt " .. attempt .. ")")
		if attempt < 3 then task.wait(attempt * 2) end
	end
	player:SetAttribute("PassStatus_" .. key, "Retry")
end

function Service.Init(player)
	if owned[player] then return end
	owned[player] = {}
	for key in pairs(Config) do
		player:SetAttribute("Pass_" .. key, false)
		player:SetAttribute("PassStatus_" .. key, "Checking")
	end
	for key in pairs(Config) do
		task.spawn(check, player, key)
	end
end

function Service.Has(player, key)
	return owned[player] ~= nil and owned[player][key] == true
end

-- StarterPack's coin bonus is deliberately modest (+15%) and stacks with
-- DoubleCoins (+100%) rather than competing with it - it's a bundled
-- starter perk, not a replacement for the dedicated economy gamepass.
function Service.Coins(player, amount)
	local mult = Service.Has(player, "DoubleCoins") and 2 or 1
	if Service.Has(player, "StarterPack") then mult = mult * 1.15 end
	return math.floor(amount * mult)
end

function Service.Capacity(_player, carryLevel)
	return carryLevel + 1
end

-- Extra inventory spaces the +50 Inventory Space pass adds on top of the
-- Storage Space upgrade.
function Service.ExtraStorage(player)
	return Service.Has(player, "ExtraStorage") and 50 or 0
end

-- StarterPack's other half of "money/speed boost" - a flat permanent
-- multiplier PlotManager.server.luau's updateWalkSpeed applies on top of
-- the existing Speed-upgrade multiplier, same pattern as Coins() above.
function Service.SpeedMultiplier(player)
	return Service.Has(player, "StarterPack") and 1.1 or 1
end

function Service.Start()
	if started then return end
	started = true
	MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(player, passId, purchased)
		if not purchased or not owned[player] or player.Parent ~= Players then return end
		for key, item in pairs(Config) do
			if configured(key) and item.id == passId then
				-- This event is handled on the server, never from a client RemoteEvent.
				grant(player, key)
				player:SetAttribute("PassStatus_" .. key, "Ready")
			end
		end
	end)
	Players.PlayerRemoving:Connect(function(player) owned[player] = nil end)
	-- Retry transient failures and recognize purchases made outside the game.
	task.spawn(function()
		while true do
			task.wait(60)
			for player, flags in pairs(owned) do
				for key in pairs(Config) do
					if not flags[key] and configured(key) then task.spawn(check, player, key) end
				end
			end
		end
	end)
end

return Service
