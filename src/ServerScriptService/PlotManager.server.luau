--[[
	PlotManager (Script, ServerScriptService) — Junkyard Fusion v1

	Replaces the old single shared FusionPad.

	The loop, for up to 8 players:
	  1. Scrap spawns in the shared yard at the centre of the map.
	  2. Anyone can press E on scrap to carry it (2 slots per player).
	  3. You carry it back to YOUR OWN plot and fuse it there.
	  4. The result auto-places into a zone (Garage/Workshop/Trophy Case)
	     matching its tier, where it earns coins every few seconds for as
	     long as it stays there — sell it anytime for an instant payout
	     instead of waiting on the passive income.

	Everything below is per-player. No shared slots, no shared discoveries.
--]]

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FusionRecipes = require(ReplicatedStorage:WaitForChild("FusionRecipes"))
local ItemVisuals   = require(ReplicatedStorage:WaitForChild("ItemVisuals"))
local DataManager   = require(script.Parent:WaitForChild("DataManager"))
local Gamepasses = require(script.Parent:WaitForChild("GamepassService"))
Gamepasses.Start()

-- ---------- Tuning ----------
local PLOT_COUNT  = 8
local RING_RADIUS = 190    -- how far each plot sits from the centre yard
local PLOT_SIZE   = 70

-- Luck: applied when you GRAB, not when scrap spawns. The yard is shared,
-- so a per-player spawn table is impossible — but a per-player reroll at
-- pickup gives the same feeling and keeps the middle fair.
local LUCK_PER_LEVEL = 0.06   -- +6% upgrade chance per luck level above 1
local LUCK_MAX_CHANCE = 0.40  -- never more than a 40% chance

-- Upgrades. All four are PERSONAL — none of them touch the shared yard,
-- so buying them can't make the middle unfair for everyone else.
-- `start` is the level a new player begins at.
local UPGRADES = {
	{
		key = "luck", name = "Lucky Wrench", start = 1, max = 10,
		baseCost = 500, mult = 1.9,
		describe = function(lv)
			return string.format("%d%% chance to upgrade scrap on pickup",
				math.floor(math.min(LUCK_MAX_CHANCE, (lv - 1) * LUCK_PER_LEVEL) * 100))
		end,
	},
	{
		key = "carry", name = "Bigger Truck", start = 1, max = 5,
		baseCost = 800, mult = 2.4,
		describe = function(lv) return string.format("Carry %d items per trip", lv + 1) end,
	},
	{
		key = "magnet", name = "Scrap Magnet", start = 0, max = 6,
		baseCost = 1200, mult = 2.2,
		describe = function(lv)
			if lv == 0 then return "Not installed" end
			return string.format("Auto-grabs scrap within %d studs", 10 + lv * 10)
		end,
	},
	{
		key = "value", name = "Haggler", start = 1, max = 8,
		baseCost = 1000, mult = 2.0,
		describe = function(lv) return string.format("+%d%% sell price", (lv - 1) * 15) end,
	},
}

local function upgradeDef(key)
	for _, def in ipairs(UPGRADES) do
		if def.key == key then return def end
	end
	return nil
end

-- Cost to buy the NEXT level. Returns nil when maxed.
local function upgradeCost(def, currentLevel)
	if currentLevel >= def.max then return nil end
	return math.floor(def.baseCost * def.mult ^ (currentLevel - def.start))
end
-- ----------------------------

-- Ordered objectives. Each unlocks only after the previous is done, so
-- there is always exactly one thing the player is working toward.
local GOALS = {
	{ text = "Fuse anything at your pad",         reward = 100,   check = function(s) return s.count >= 1 end },
	{ text = "Discover 3 different builds",       reward = 250,   check = function(s) return s.count >= 3 end },
	{ text = "Sell a build for coins",            reward = 250,   check = function(s) return s.sales >= 1 end },
	{ text = "Discover 6 different builds",       reward = 600,   check = function(s) return s.count >= 6 end },
	{ text = "Build a Tier 3 machine",            reward = 1500,  check = function(s) return s.bestTier >= 3 end },
	{ text = "Discover 12 different builds",      reward = 3000,  check = function(s) return s.count >= 12 end },
	{ text = "Build a Tier 4 monster",            reward = 8000,  check = function(s) return s.bestTier >= 4 end },
	{ text = "Uncover a secret recipe",           reward = 15000, check = function(s) return s.secrets >= 1 end },
	{ text = "Complete the index: all 22 builds", reward = 50000, check = function(s) return s.count >= 22 end },
}

-- Client talks to this for UI updates.
local remote = ReplicatedStorage:FindFirstChild("GameUpdate")
if not remote then
	remote = Instance.new("RemoteEvent")
	remote.Name = "GameUpdate"
	remote.Parent = ReplicatedStorage
end

-- Client asks to buy; the SERVER decides the price and whether it's
-- affordable. The client sends a key and nothing else.
local buyRemote = ReplicatedStorage:FindFirstChild("BuyUpgrade")
if not buyRemote then
	buyRemote = Instance.new("RemoteEvent")
	buyRemote.Name = "BuyUpgrade"
	buyRemote.Parent = ReplicatedStorage
end

local claimRemote = ReplicatedStorage:FindFirstChild("ClaimDaily")
if not claimRemote then
	claimRemote = Instance.new("RemoteEvent")
	claimRemote.Name = "ClaimDaily"
	claimRemote.Parent = ReplicatedStorage
end

-- Retention rewards.
-- Deliberately mixed: coins are the boring baseline, and the days that
-- aren't coins are the ones people remember. Day 7 stacks all three.
local DAILY_REWARDS = {
	{ kind = "coins", amount = 500,  label = "500 Coins",        sub = "starter" },
	{ kind = "boost", stat = "luck",  mult = 3, minutes = 10, label = "3x LUCK",  sub = "10 minutes" },
	{ kind = "coins", amount = 1500, label = "1,500 Coins",      sub = "" },
	{ kind = "item",  label = "RARE CRATE",   sub = "guaranteed rare" },
	{ kind = "boost", stat = "value", mult = 2, minutes = 15, label = "2x SELL",   sub = "15 minutes" },
	{ kind = "coins", amount = 3000, label = "3,000 Coins",      sub = "" },
	{ kind = "jackpot", amount = 7500, label = "JACKPOT",        sub = "coins + luck + jet engine" },
}
local DAILY_MAX_STREAK = #DAILY_REWARDS

-- Escalating within a session: the longer you stay, the better it gets.
local PLAYTIME_REWARDS = { 300, 500, 800, 1200, 1500 }
local PLAYTIME_INTERVAL = 5   -- minutes between payouts

-- Days since epoch. Simple, and immune to timezone drift because it's
-- computed from UTC on the server, never from the client's clock.
local function currentDay()
	return math.floor(os.time() / 86400)
end

-- Works out where the player sits in the 7-day cycle.
-- Returns: available, the day they'd claim next, how many are already claimed.
local function dailyInfo(s)
	local today = currentDay()
	local available = today > s.lastDailyDay

	if not available then
		return false, nil, s.dailyStreak
	end

	local nextDay
	if today == s.lastDailyDay + 1 and s.dailyStreak < DAILY_MAX_STREAK then
		nextDay = s.dailyStreak + 1   -- streak continues
	else
		nextDay = 1                   -- missed a day, or finished the cycle
	end

	return true, nextDay, nextDay - 1
end

local plots = {}   -- [index] = { model, owner, padPrompt, zones, sign }
local state = {}   -- [player] = { slots, discovered, count, plotIndex }

-- Boosts are timed multipliers stored as an expiry timestamp, so they
-- keep ticking across a rejoin instead of resetting on every session.
-- Defined up here because grabItem and the sell prompt both call it,
-- and in Lua a local declared further down is simply not in scope above.
local function boostMult(s, stat)
	local b = s.boosts and s.boosts[stat]
	if b and b.expires > os.time() then
		return b.mult
	end
	return 1
end

-- Shared by manual sells and passive income — the Haggler upgrade and any
-- timed sell boost apply to everything a player's builds earn, not just
-- the moment you press Sell.
local function valueMultiplier(s)
	return (1 + (s.upgrades.value - 1) * 0.15) * boostMult(s, "value")
end

------------------------------------------------------------------
-- Small builders
------------------------------------------------------------------

local function makeLabel(parent, text, offsetY, size, color)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.new(0, size or 280, 0, 60)
	gui.StudsOffset = Vector3.new(0, offsetY or 4, 0)
	gui.AlwaysOnTop = true
	gui.Parent = parent

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = color or Color3.fromRGB(255, 255, 255)
	label.TextStrokeTransparency = 0.3
	label.TextScaled = true
	label.Font = Enum.Font.GothamBold
	label.Parent = gui

	return label
end

local function makePart(props)
	local part = Instance.new("Part")
	part.Anchored = true
	for key, value in pairs(props) do
		part[key] = value
	end
	return part
end

------------------------------------------------------------------
-- Sound
-- Using built-in rbxasset:// paths so nothing depends on a
-- marketplace upload. Swap the ids for your own later.
------------------------------------------------------------------

local SOUNDS = {
	pickup  = { id = "rbxasset://sounds/clickfast.wav",           pitch = 1.4,  volume = 0.4 },
	fuse    = { id = "rbxasset://sounds/electronicpingshort.wav", pitch = 0.85, volume = 0.7 },
	big     = { id = "rbxasset://sounds/bass.wav",                pitch = 1.0,  volume = 0.9 },
	fail    = { id = "rbxasset://sounds/switch.wav",              pitch = 0.6,  volume = 0.5 },
	sell    = { id = "rbxasset://sounds/electronicpingshort.wav", pitch = 1.5,  volume = 0.5 },
}

local function playSound(parent, key)
	local cfg = SOUNDS[key]
	if not (cfg and parent) then return end

	local sound = Instance.new("Sound")
	sound.SoundId = cfg.id
	sound.PlaybackSpeed = cfg.pitch
	sound.Volume = cfg.volume
	sound.Parent = parent
	sound:Play()

	-- Clean itself up so sounds don't pile up in the data model.
	sound.Ended:Connect(function() sound:Destroy() end)
	task.delay(5, function() if sound.Parent then sound:Destroy() end end)
end

local function playerRoot(player)
	local char = player.Character
	return char and char:FindFirstChild("HumanoidRootPart")
end

------------------------------------------------------------------
-- Placement zones
-- Fused results auto-place here instead of an immediate one-time sale.
-- Which zone accepts a result depends on its tier, so higher zones are
-- both a status symbol and a reason to keep grinding for rarer fuses.
------------------------------------------------------------------

-- Roughly how long passive income takes to match a manual sell of the
-- same item — after that it's pure profit for as long as it stays placed.
local PLACEMENT_PAYBACK_SECONDS = 90
local INCOME_TICK_SECONDS = 3

local ZONES = {
	{
		key = "garage", label = "GARAGE — Tier 2", capacity = 4,
		offset = Vector3.new(-22, 0, 20),
		color = Color3.fromRGB(0, 200, 255),
		accepts = function(info) return info.tier == 2 and not info.isSecret end,
	},
	{
		key = "workshop", label = "WORKSHOP — Tier 3", capacity = 3,
		offset = Vector3.new(0, 0, 20),
		color = Color3.fromRGB(200, 80, 255),
		accepts = function(info) return info.tier == 3 and not info.isSecret end,
	},
	{
		key = "trophy", label = "TROPHY CASE — Tier 4+ / Secrets", capacity = 2,
		offset = Vector3.new(22, 0, 20),
		color = Color3.fromRGB(255, 210, 0),
		accepts = function(info) return info.tier >= 4 or info.isSecret end,
	},
}

local function zoneForInfo(info)
	for _, zoneDef in ipairs(ZONES) do
		if zoneDef.accepts(info) then return zoneDef end
	end
	return nil
end

------------------------------------------------------------------
-- Build the eight plots in a ring around the yard
------------------------------------------------------------------

local plotFolder = workspace:FindFirstChild("Plots")
if plotFolder then plotFolder:Destroy() end
plotFolder = Instance.new("Folder")
plotFolder.Name = "Plots"
plotFolder.Parent = workspace

for i = 1, PLOT_COUNT do
	local angle = (i - 1) / PLOT_COUNT * math.pi * 2
	local centre = Vector3.new(math.cos(angle) * RING_RADIUS, 0, math.sin(angle) * RING_RADIUS)

	local model = Instance.new("Model")
	model.Name = "Plot" .. i
	model.Parent = plotFolder

	local ground = makePart({
		Name = "Ground",
		Size = Vector3.new(PLOT_SIZE, 1, PLOT_SIZE),
		Position = centre,
		Material = Enum.Material.SmoothPlastic,
		Color = Color3.fromRGB(235, 240, 245),
		Parent = model,
	})

	-- Sign shows who owns the plot.
	local signPost = makePart({
		Name = "Sign",
		Size = Vector3.new(2, 10, 2),
		Position = centre + Vector3.new(0, 5, -PLOT_SIZE / 2 + 3),
		Material = Enum.Material.SmoothPlastic,
		Color = Color3.fromRGB(255, 214, 0),
		Parent = model,
	})
	local signLabel = makeLabel(signPost, "UNCLAIMED PLOT", 6, 320, Color3.fromRGB(255, 200, 80))

	-- The fusion pad: only its owner can use it.
	local pad = makePart({
		Name = "FusionPad",
		Size = Vector3.new(16, 1, 16),
		Position = centre + Vector3.new(0, 1, 0),
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(255, 110, 0),
		Parent = model,
	})
	local padLabel = makeLabel(pad, "FUSION PAD", 7, 340)

	local padPrompt = Instance.new("ProximityPrompt")
	padPrompt.ActionText = "Fuse"
	padPrompt.ObjectText = "Fusion Pad"
	padPrompt.HoldDuration = 0
	padPrompt.MaxActivationDistance = 16
	padPrompt.RequiresLineOfSight = false
	padPrompt.Parent = pad

	-- Placement zones: each fused result auto-places into the zone that
	-- accepts its tier, where it earns coins every few seconds.
	local zones = {}
	for _, zoneDef in ipairs(ZONES) do
		local zoneCentre = centre + zoneDef.offset

		local signPost2 = makePart({
			Name = zoneDef.key .. "Sign",
			Size = Vector3.new(1, 6, 1),
			Position = zoneCentre + Vector3.new(0, 3, -4),
			Material = Enum.Material.Neon,
			Color = zoneDef.color,
			Parent = model,
		})
		makeLabel(signPost2, zoneDef.label, 4, 280, Color3.fromRGB(255, 255, 255))

		local slots = {}
		for slotIndex = 1, zoneDef.capacity do
			local localX = (slotIndex - (zoneDef.capacity + 1) / 2) * 5
			local base = makePart({
				Name = zoneDef.key .. "Slot" .. slotIndex,
				Size = Vector3.new(4, 1, 4),
				Position = zoneCentre + Vector3.new(localX, 1, 0),
				Material = Enum.Material.SmoothPlastic,
				Color = zoneDef.color:Lerp(Color3.new(1, 1, 1), 0.6),
				Parent = model,
			})
			local slotLabel = makeLabel(base, "empty", 2.2, 220, zoneDef.color)

			local sellPrompt = Instance.new("ProximityPrompt")
			sellPrompt.ActionText = "Sell"
			sellPrompt.ObjectText = "Placed item"
			sellPrompt.HoldDuration = 0.4
			sellPrompt.MaxActivationDistance = 12
			sellPrompt.RequiresLineOfSight = false
			sellPrompt.Enabled = false
			sellPrompt.Parent = base

			slots[slotIndex] = {
				base = base,
				label = slotLabel,
				sellPrompt = sellPrompt,
				itemPart = nil,
				itemName = nil,
				value = nil,
			}
		end

		zones[zoneDef.key] = { def = zoneDef, slots = slots }
	end

	plots[i] = {
		model = model,
		owner = nil,
		centre = centre,
		pad = pad,
		padLabel = padLabel,
		padPrompt = padPrompt,
		zones = zones,
		signLabel = signLabel,
	}
end

------------------------------------------------------------------
-- Per-player helpers
------------------------------------------------------------------

local function capacity(player, s)
	return Gamepasses.Capacity(player, s.upgrades.carry)
end

local function rewardInfo(player, reward)
	local copy = table.clone(reward)
	if copy.amount then
		copy.amount = Gamepasses.Coins(player, copy.amount)
		if copy.kind == "coins" then copy.label = string.format("%d Coins", copy.amount) end
	end
	return copy
end

local function pushUI(player)
	local s = state[player]
	if not s then return end

	local book, secretsFound, secretTotal = FusionRecipes.GetRecipeBook(s.discovered)
	local goal = GOALS[s.goalIndex]

	local shop = {}
	for _, def in ipairs(UPGRADES) do
		local level = s.upgrades[def.key]
		table.insert(shop, {
			key = def.key,
			name = def.name,
			level = level,
			max = def.max,
			effect = def.describe(level),
			nextEffect = level < def.max and def.describe(level + 1) or nil,
			cost = upgradeCost(def, level),
		})
	end

	local dailyAvailable, dailyNext, dailyClaimed = dailyInfo(s)

	-- Only send boosts that are still live, with seconds remaining so the
	-- client can count down without trusting its own clock for the maths.
	local activeBoosts = {}
	for stat, b in pairs(s.boosts or {}) do
		local remaining = b.expires - os.time()
		if remaining > 0 then
			table.insert(activeBoosts, { stat = stat, mult = b.mult, remaining = remaining })
		end
	end

	local dailyRewards = {}
	for _, reward in ipairs(DAILY_REWARDS) do table.insert(dailyRewards, rewardInfo(player, reward)) end

	remote:FireClient(player, {
		slots = s.slots,
		maxSlots = capacity(player, s),
		discoveredCount = s.count,
		total = FusionRecipes.GetTotalDiscoveries(),
		list = s.discoveredList,
		book = book,
		secretsFound = secretsFound,
		secretTotal = secretTotal,
		goalText = goal and goal.text or "All objectives complete",
		goalReward = goal and Gamepasses.Coins(player, goal.reward) or 0,
		goalNumber = math.min(s.goalIndex, #GOALS),
		goalTotal = #GOALS,
		luck = s.upgrades.luck,
		shop = shop,
		dailyAvailable = dailyAvailable,
		dailyNext = dailyNext,
		dailyClaimed = dailyClaimed,
		dailyRewards = dailyRewards,
		boosts = activeBoosts,
	})
end

Gamepasses.Changed:Connect(function(player)
	if state[player] then pushUI(player) end
end)

local function toast(player, message, isBig)
	remote:FireClient(player, { toast = message, big = isBig or false })
end

-- Goes to everyone. Used for golden scrap and big finds — the whole point
-- is that other players see it and react.
local function broadcast(message)
	remote:FireAllClients({ announce = message })
end

-- Items ordered rarest first, for luck upgrades.
local function rarerThan(itemName)
	local current
	for _, item in ipairs(FusionRecipes.BaseItems) do
		if item.name == itemName then current = item end
	end
	if not current then return nil end

	local candidates = {}
	for _, item in ipairs(FusionRecipes.BaseItems) do
		if item.weight < current.weight then
			table.insert(candidates, item.name)
		end
	end

	if #candidates == 0 then return nil end
	return candidates[math.random(1, #candidates)]
end

-- Picks a rare item for golden scrap: anything uncommon or better.
local function rollRareItem()
	local pool = {}
	for _, item in ipairs(FusionRecipes.BaseItems) do
		if item.weight <= 30 then
			table.insert(pool, item.name)
		end
	end
	return pool[math.random(1, #pool)]
end

local function refreshPad(player)
	local s = state[player]
	if not s then return end
	local plot = plots[s.plotIndex]
	if not plot then return end

	plot.padLabel.Text = string.format(
		"FUSION PAD\n[ %s ]  +  [ %s ]",
		s.slots[1] or "empty",
		s.slots[2] or "empty"
	)

	-- Physical items sitting in the two slots on the pad.
	plot.slotParts = plot.slotParts or {}
	for i = 1, 2 do
		if plot.slotParts[i] then
			plot.slotParts[i]:Destroy()
			plot.slotParts[i] = nil
		end

		local itemName = s.slots[i]
		if itemName then
			local offset = (i == 1) and -4.6 or 4.6
			local slotPart = ItemVisuals.Create(itemName, plot.pad.Position + Vector3.new(offset, 2.4, 0), 0.85)
			slotPart.Name = "Slot" .. i
			slotPart.Parent = plot.model
			makeLabel(slotPart, itemName, 1.8, 190, Color3.fromRGB(255, 235, 190))
			plot.slotParts[i] = slotPart
		end
	end
end

local function addCoins(player, amount)
	local stats = player:FindFirstChild("leaderstats")
	if not stats then return end
	local coins = stats:FindFirstChild("Coins")
	if coins then
		amount = Gamepasses.Coins(player, amount)
		coins.Value = coins.Value + amount
		return amount
	end
end

-- Walks the goal list in order, awarding every objective now satisfied.
local function checkGoals(player)
	local s = state[player]
	if not s then return end

	while s.goalIndex <= #GOALS do
		local goal = GOALS[s.goalIndex]
		if not goal.check(s) then break end

		local awarded = addCoins(player, goal.reward) or 0
		toast(player, string.format("OBJECTIVE COMPLETE\n%s\n+%d coins", goal.text, awarded), true)
		s.goalIndex = s.goalIndex + 1
	end
end

local function getScrapFolder()
	local folder = workspace:FindFirstChild("Scrap")
	if not folder then
		folder = Instance.new("Folder")
		folder.Name = "Scrap"
		folder.Parent = workspace
	end
	return folder
end

local function dropItemNearYard(itemName)
	local position = Vector3.new(math.random(-40, 40), 3, math.random(-40, 40))
	local part = ItemVisuals.Create(itemName, position, 1)
	part:SetAttribute("ItemName", itemName)
	makeLabel(part, itemName, 2, 200)
	part.Parent = getScrapFolder()
end

------------------------------------------------------------------
-- Fusion
------------------------------------------------------------------

-- Builds the physical item sitting in a zone slot and marks the slot
-- filled. Shared by a fresh fuse-and-place and restoring a save on join.
local function renderInSlot(plot, slot, itemName, value, isSecret)
	local position = slot.base.Position + Vector3.new(0, 2.5, 0)
	local part
	if ItemVisuals.HasModel(itemName) then
		part = ItemVisuals.Create(itemName, position, 1)
	else
		-- No detailed model for this result yet — keep a neon placeholder,
		-- with a distinct color for secret discoveries.
		part = makePart({
			Name = itemName,
			Size = Vector3.new(3.5, 2, 3.5),
			Position = position,
			Material = Enum.Material.Neon,
			Color = isSecret and Color3.fromRGB(255, 90, 200) or Color3.fromRGB(90, 200, 255),
		})
	end
	part.Parent = plot.model
	part:SetAttribute("ItemName", itemName)

	slot.itemPart = part
	slot.itemName = itemName
	slot.value = value
	slot.label.Text = string.format("%s\n+%.1f coins/sec", itemName, value / PLACEMENT_PAYBACK_SECONDS)
	slot.sellPrompt.Enabled = true
end

-- Finds the first empty slot in the zone matching this result's tier and
-- places it there. Returns false (zone full) if nothing was available.
local function placeFusedItem(plot, resultName, info)
	local zoneDef = zoneForInfo(info)
	if not zoneDef then
		warn("[PlotManager] No zone accepts tier " .. tostring(info.tier) .. " results")
		return false
	end

	local zone = plot.zones[zoneDef.key]
	for _, slot in ipairs(zone.slots) do
		if not slot.itemName then
			renderInSlot(plot, slot, resultName, info.value, info.isSecret)
			return true
		end
	end

	return false
end

-- Cashes out one placed item for an instant payout instead of letting it
-- keep earning passively.
local function sellSlot(plot, zoneKey, slotIndex, player)
	if plot.owner ~= player then
		toast(player, "That's not your plot.")
		return
	end

	local slot = plot.zones[zoneKey].slots[slotIndex]
	if not slot.itemName then return end

	local s = state[player]
	local mult = s and valueMultiplier(s) or 1
	local payout = addCoins(player, math.floor(slot.value * mult)) or 0

	playSound(slot.base, "sell")
	toast(player, string.format("Sold %s for %d coins.", slot.itemName, payout))

	slot.itemPart:Destroy()
	slot.itemPart = nil
	slot.itemName = nil
	slot.value = nil
	slot.label.Text = "empty"
	slot.sellPrompt.Enabled = false

	if s then
		s.sales = s.sales + 1
		checkGoals(player)
		pushUI(player)
	end
end

local function attemptFusion(player)
	local s = state[player]
	if not s then return end

	local plot = plots[s.plotIndex]
	if not plot then return end

	local a, b = s.slots[1], s.slots[2]
	if not (a and b) then
		toast(player, "You need two items to fuse.")
		return
	end

	s.slots[1], s.slots[2] = nil, nil
	-- Shift any extra carried items down into the empty slots.
	local remaining = {}
	for i = 3, capacity(player, s) do
		if s.slots[i] then table.insert(remaining, s.slots[i]) end
	end
	s.slots = remaining
	refreshPad(player)

	local result, info = FusionRecipes.Fuse(a, b)

	if not result then
		-- Dead ends cost nothing. Both items go back to the yard.
		dropItemNearYard(a)
		dropItemNearYard(b)
		playSound(plot.pad, "fail")
		toast(player, string.format("%s + %s = nothing. Items returned.", a, b))
		pushUI(player)
		return
	end

	if not s.discovered[result] then
		s.discovered[result] = true
		s.count = s.count + 1
		table.insert(s.discoveredList, result)
		if info.tier > s.bestTier then s.bestTier = info.tier end
		if info.isSecret then s.secrets = s.secrets + 1 end
		toast(player, string.format("NEW DISCOVERY\n%s", result), true)
		print(string.format("[Fusion] %s discovered %s (%d/%d)",
			player.Name, result, s.count, FusionRecipes.GetTotalDiscoveries()))
	else
		toast(player, string.format("%s + %s = %s", a, b, result))
	end

	if info.isSecret then
		toast(player, string.format("SECRET RECIPE\n%s", result), true)
	end

	local placed = placeFusedItem(plot, result, info)
	if not placed then
		dropItemNearYard(result)
		toast(player, string.format("Your zone for %s is full — sell something there first. It was returned to the yard.", result))
	end

	playSound(plot.pad, (info.isSecret or info.tier >= 4) and "big" or "fuse")
	checkGoals(player)
	pushUI(player)
end

------------------------------------------------------------------
-- Grabbing scrap (used by both the E prompt and the magnet)
------------------------------------------------------------------

local function grabItem(player, part)
	local s = state[player]
	if not s then return false end
	if not part or not part.Parent then return false end
	if #s.slots >= capacity(player, s) then return false end

	local grabbed = part:GetAttribute("ItemName") or part.Name
	local isGolden = part:GetAttribute("Golden")

	if isGolden then
		grabbed = rollRareItem()
		broadcast(string.format("%s claimed the GOLDEN SCRAP — %s!", player.Name, grabbed))
	else
		local chance = math.min(LUCK_MAX_CHANCE, (s.upgrades.luck * boostMult(s, "luck") - 1) * LUCK_PER_LEVEL)
		if math.random() < chance then
			local upgraded = rarerThan(grabbed)
			if upgraded then
				toast(player, string.format("LUCKY FIND\n%s → %s", grabbed, upgraded), true)
				grabbed = upgraded
			end
		end
	end

	table.insert(s.slots, grabbed)
	playSound(playerRoot(player), isGolden and "big" or "pickup")
	part:Destroy()
	refreshPad(player)
	pushUI(player)
	return true
end

local function attachPickup(part)
	if not part:IsA("BasePart") then return end
	if part:FindFirstChildOfClass("ProximityPrompt") then return end

	local itemName = part:GetAttribute("ItemName") or part.Name

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Grab"
	prompt.ObjectText = itemName
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = part

	prompt.Triggered:Connect(function(player)
		if not grabItem(player, part) then
			toast(player, "Hands full — fuse at your plot first.")
		end
	end)
end

local scrapFolder = getScrapFolder()
for _, child in ipairs(scrapFolder:GetChildren()) do
	attachPickup(child)
end
scrapFolder.ChildAdded:Connect(attachPickup)

------------------------------------------------------------------
-- Wire up each plot's prompts (owner-only)
------------------------------------------------------------------

for i, plot in ipairs(plots) do
	plot.padPrompt.Triggered:Connect(function(player)
		if plot.owner ~= player then
			toast(player, "That's not your plot.")
			return
		end
		attemptFusion(player)
	end)

	for _, zoneDef in ipairs(ZONES) do
		for slotIndex, slot in ipairs(plot.zones[zoneDef.key].slots) do
			slot.sellPrompt.Triggered:Connect(function(player)
				sellSlot(plot, zoneDef.key, slotIndex, player)
			end)
		end
	end
end

------------------------------------------------------------------
-- Buying upgrades
------------------------------------------------------------------

buyRemote.OnServerEvent:Connect(function(player, key)
	-- Never trust the client. It sends a key; we decide everything else.
	if type(key) ~= "string" then return end

	local s = state[player]
	if not s then return end

	local def = upgradeDef(key)
	if not def then return end

	local level = s.upgrades[key]
	local cost = upgradeCost(def, level)
	if not cost then
		toast(player, def.name .. " is already maxed.")
		return
	end

	local stats = player:FindFirstChild("leaderstats")
	local coins = stats and stats:FindFirstChild("Coins")
	if not coins then return end

	if coins.Value < cost then
		toast(player, string.format("Not enough coins. Need %d.", cost))
		return
	end

	coins.Value = coins.Value - cost
	s.upgrades[key] = level + 1

	if key == "carry" then
		-- Capacity is derived from earned upgrades plus pass ownership.
	end

	playSound(playerRoot(player), "big")
	toast(player, string.format("%s → Level %d\n%s", def.name, s.upgrades[key], def.describe(s.upgrades[key])), true)
	pushUI(player)
end)

------------------------------------------------------------------
-- Scrap magnet
------------------------------------------------------------------

task.spawn(function()
	while true do
		task.wait(1.5)

		for _, player in ipairs(Players:GetPlayers()) do
			local s = state[player]
			if s and Gamepasses.Radius(player, s.upgrades.magnet) > 0 and #s.slots < capacity(player, s) then
				local root = playerRoot(player)
				if root then
					local radius = Gamepasses.Radius(player, s.upgrades.magnet)
					local nearest, nearestDist = nil, radius

					for _, part in ipairs(getScrapFolder():GetChildren()) do
						if part:IsA("BasePart") then
							local dist = (part.Position - root.Position).Magnitude
							if dist < nearestDist then
								nearest, nearestDist = part, dist
							end
						end
					end

					if nearest then
						grabItem(player, nearest)
					end
				end
			end
		end
	end
end)

------------------------------------------------------------------
-- Passive income from placed items
------------------------------------------------------------------

task.spawn(function()
	while true do
		task.wait(INCOME_TICK_SECONDS)

		for _, player in ipairs(Players:GetPlayers()) do
			local s = state[player]
			local plot = s and plots[s.plotIndex]
			if s and plot then
				local mult = valueMultiplier(s)
				local perSecond = 0

				for _, zoneDef in ipairs(ZONES) do
					for _, slot in ipairs(plot.zones[zoneDef.key].slots) do
						if slot.value then
							perSecond = perSecond + (slot.value / PLACEMENT_PAYBACK_SECONDS) * mult
						end
					end
				end

				if perSecond > 0 then
					addCoins(player, math.floor(perSecond * INCOME_TICK_SECONDS))
				end
			end
		end
	end
end)

local function giveBoost(player, stat, mult, minutes)
	local s = state[player]
	if not s then return end
	s.boosts[stat] = { mult = mult, expires = os.time() + minutes * 60 }
end

local function giveItem(player, itemName)
	local s = state[player]
	if not s then return end

	if #s.slots < capacity(player, s) then
		table.insert(s.slots, itemName)
		refreshPad(player)
	else
		-- Hands full: drop it in the yard rather than silently voiding it.
		dropItemNearYard(itemName)
		toast(player, itemName .. " dropped in the yard — your hands were full.")
	end
end

local function grantReward(player, reward)
	local s = state[player]
	if not s then return end

	if reward.kind == "coins" then
		addCoins(player, reward.amount)

	elseif reward.kind == "boost" then
		giveBoost(player, reward.stat, reward.mult, reward.minutes)

	elseif reward.kind == "item" then
		giveItem(player, rollRareItem())

	elseif reward.kind == "jackpot" then
		addCoins(player, reward.amount)
		giveBoost(player, "luck", 3, 20)
		giveItem(player, "Jet Engine")
	end
end

------------------------------------------------------------------
-- Retention: daily streak + playtime rewards
------------------------------------------------------------------

claimRemote.OnServerEvent:Connect(function(player)
	local s = state[player]
	if not s then return end

	local available, nextDay = dailyInfo(s)
	if not available then
		toast(player, "Already claimed today. Come back tomorrow.")
		return
	end

	s.dailyStreak = nextDay
	s.lastDailyDay = currentDay()

	local reward = DAILY_REWARDS[nextDay]
	grantReward(player, reward)
	local displayReward = rewardInfo(player, reward)
	playSound(playerRoot(player), "big")

	if nextDay == DAILY_MAX_STREAK then
		broadcast(string.format("%s completed a 7-day streak and hit the JACKPOT!", player.Name))
		toast(player, string.format("DAY 7 JACKPOT\n%d coins + 3x Luck + Jet Engine", displayReward.amount), true)
	else
		toast(player, string.format("DAY %d CLAIMED\n%s", nextDay, displayReward.label), true)
	end

	pushUI(player)
end)

task.spawn(function()
	while true do
		task.wait(60)

		for _, player in ipairs(Players:GetPlayers()) do
			local s = state[player]
			if s then
				s.playMinutes = (s.playMinutes or 0) + 1

				if s.playMinutes % PLAYTIME_INTERVAL == 0 then
					local step = math.floor(s.playMinutes / PLAYTIME_INTERVAL)
					local reward = PLAYTIME_REWARDS[math.min(step, #PLAYTIME_REWARDS)]

					local awarded = addCoins(player, reward) or 0
					toast(player, string.format("%d MINUTES PLAYED\n+%d coins", s.playMinutes, awarded), true)
					pushUI(player)
				end
			end
		end
	end
end)

------------------------------------------------------------------
-- Joining and leaving
------------------------------------------------------------------

local function assignPlot(player)
	for i, plot in ipairs(plots) do
		if plot.owner == nil then
			plot.owner = player
			plot.signLabel.Text = player.Name .. "'S YARD"
			return i
		end
	end
	return nil
end

local function onPlayerAdded(player)
	Gamepasses.Init(player)
	-- Load BEFORE anything else, so a slow DataStore can't be beaten
	-- by the player picking something up.
	local data = DataManager.Load(player)

	local stats = Instance.new("Folder")
	stats.Name = "leaderstats"
	stats.Parent = player

	local coins = Instance.new("IntValue")
	coins.Name = "Coins"
	coins.Value = data.coins
	coins.Parent = stats

	local index = assignPlot(player)
	if not index then
		-- Should never happen at 8 max players, but never leave this unhandled.
		warn("[PlotManager] No free plot for " .. player.Name)
		return
	end

	-- Rebuild the discovered lookup from the saved list.
	local discovered = {}
	for _, name in ipairs(data.discoveredList) do
		discovered[name] = true
	end

	local upgrades = data.upgrades or { luck = 1, carry = 1, magnet = 0, value = 1 }

	state[player] = {
		slots = {},
		discovered = discovered,
		discoveredList = data.discoveredList,
		count = #data.discoveredList,
		sales = data.sales,
		bestTier = data.bestTier,
		secrets = data.secrets,
		goalIndex = data.goalIndex,
		upgrades = upgrades,
		maxSlots = upgrades.carry + 1,
		lastDailyDay = data.lastDailyDay or 0,
		dailyStreak = data.dailyStreak or 0,
		boosts = data.boosts or {},
		playMinutes = 0,
		plotIndex = index,
	}

	refreshPad(player)

	-- Restore whatever was placed in this plot's zones last session.
	local plot = plots[index]
	for _, saved in ipairs(data.placed or {}) do
		local zone = plot.zones[saved.zone]
		local slot = zone and zone.slots[saved.slot]
		if slot and not slot.itemName and saved.itemName and saved.value then
			renderInSlot(plot, slot, saved.itemName, saved.value, false)
		end
	end

	-- Drop them on their own plot when they spawn.
	player.CharacterAdded:Connect(function(character)
		task.wait(0.2)
		local plot = plots[index]
		if plot and character.PrimaryPart then
			character:PivotTo(CFrame.new(plot.centre + Vector3.new(0, 5, -20)))
		end
		task.wait(1)
		pushUI(player)
		toast(player, "Plot " .. index .. " is yours. Scrap spawns in the centre.")
	end)

	-- If the character already exists (Studio joins fast), draw the UI now.
	if player.Character then
		task.delay(1, function() pushUI(player) end)
	end
end

Players.PlayerAdded:Connect(onPlayerAdded)

-- In Studio the local player can join before this script finishes running,
-- so PlayerAdded never fires for them. Catch anyone already here.
for _, existing in ipairs(Players:GetPlayers()) do
	if not state[existing] then
		task.spawn(onPlayerAdded, existing)
	end
end

------------------------------------------------------------------
-- Saving
------------------------------------------------------------------

-- Every currently-filled slot across a plot's zones, in save-file form.
local function snapshotPlaced(plot)
	local placed = {}
	for _, zoneDef in ipairs(ZONES) do
		for slotIndex, slot in ipairs(plot.zones[zoneDef.key].slots) do
			if slot.itemName then
				table.insert(placed, {
					zone = zoneDef.key,
					slot = slotIndex,
					itemName = slot.itemName,
					value = slot.value,
				})
			end
		end
	end
	return placed
end

-- Turns live state back into the plain table DataManager stores.
local function snapshot(player)
	local s = state[player]
	if not s then return nil end

	local stats = player:FindFirstChild("leaderstats")
	local coins = stats and stats:FindFirstChild("Coins")
	local plot = plots[s.plotIndex]

	return {
		coins = coins and coins.Value or 0,
		discoveredList = s.discoveredList,
		goalIndex = s.goalIndex,
		bestTier = s.bestTier,
		secrets = s.secrets,
		sales = s.sales,
		placed = plot and snapshotPlaced(plot) or {},
		upgrades = s.upgrades,
		lastDailyDay = s.lastDailyDay,
		dailyStreak = s.dailyStreak,
		boosts = s.boosts,
	}
end

-- Autosave. Without this, a server crash loses everything since join.
task.spawn(function()
	while true do
		task.wait(120)
		for _, player in ipairs(Players:GetPlayers()) do
			local data = snapshot(player)
			if data then
				DataManager.Save(player, data)
			end
		end
	end
end)

-- Runs when the server shuts down. Roblox gives about 30 seconds.
game:BindToClose(function()
	if DataManager.IsStudio() then return end

	for _, player in ipairs(Players:GetPlayers()) do
		local data = snapshot(player)
		if data then
			task.spawn(function()
				DataManager.Save(player, data)
			end)
		end
	end

	task.wait(5)
end)

Players.PlayerRemoving:Connect(function(player)
	local data = snapshot(player)
	if data then
		DataManager.Save(player, data)
	end

	local s = state[player]
	if s then
		local plot = plots[s.plotIndex]
		if plot then
			plot.owner = nil
			plot.signLabel.Text = "UNCLAIMED PLOT"
			plot.padLabel.Text = "FUSION PAD"
			for _, zoneDef in ipairs(ZONES) do
				for _, slot in ipairs(plot.zones[zoneDef.key].slots) do
					if slot.itemPart then
						slot.itemPart:Destroy()
						slot.itemPart = nil
					end
					slot.itemName = nil
					slot.value = nil
					slot.label.Text = "empty"
					slot.sellPrompt.Enabled = false
				end
			end
		end
	end
	state[player] = nil
	DataManager.Forget(player)
end)

print(string.format("[PlotManager] %d plots ready. %d combos to discover.",
	PLOT_COUNT, FusionRecipes.GetTotalDiscoveries()))
