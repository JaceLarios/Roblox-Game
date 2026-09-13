--[[
	PlotManager (Script, ServerScriptService) — Junkyard Fusion v1

	Replaces the old single shared FusionPad.

	The loop, for up to 8 players:
	  1. Scrap spawns in the shared yard at the centre of the map.
	  2. Anyone can press E on scrap to carry it (2+ slots per player).
	  3. You carry it back to YOUR OWN plot and fuse it there.
	  4. The result goes straight into your Inventory, where it earns coins
	     every few seconds for as long as you keep it — sell it anytime from
	     the Inventory popup for an instant payout instead of waiting on the
	     passive income, or send it back to carry to fuse into something
	     bigger.

	Everything below is per-player. No shared slots, no shared discoveries.
--]]

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService        = game:GetService("RunService")

local FusionRecipes = require(ReplicatedStorage:WaitForChild("FusionRecipes"))
local BrainrotRecipes = require(ReplicatedStorage:WaitForChild("BrainrotRecipes"))
local ItemVisuals   = require(ReplicatedStorage:WaitForChild("ItemVisuals"))
local ItemRarity    = require(ReplicatedStorage:WaitForChild("ItemRarity"))
local Mutations     = require(ReplicatedStorage:WaitForChild("Mutations"))
local DataManager   = require(script.Parent:WaitForChild("DataManager"))
local Gamepasses = require(script.Parent:WaitForChild("GamepassService"))
local Rebirth = require(script.Parent:WaitForChild("RebirthService"))
local Companions = require(script.Parent:WaitForChild("CompanionService"))
local Leaderboard = require(script.Parent:WaitForChild("LeaderboardService"))
local Trade = require(script.Parent:WaitForChild("TradeService"))
local Brainrot = require(script.Parent:WaitForChild("BrainrotService"))
Gamepasses.Start()

-- We position each character ourselves (their assigned plot, or wherever
-- they travel to) via RespawnLocation, so the default auto-spawn — which
-- would otherwise drop them at the world origin for a frame before our
-- code can move them — is turned off in favor of an explicit LoadCharacter
-- once we know where they belong.
Players.CharacterAutoLoads = false

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

-- Companions: equip any discovered item (either island) to follow you and
-- earn a small permanent value bonus scaled by its tier (see
-- CompanionService.luau for the bonus table — this file only validates
-- equip requests and owns the follow visual). No new content needed —
-- reuses whatever's already been discovered.
local COMPANION_SCALE = 0.45

local function isBaseItemName(itemName, Recipes)
	for _, item in ipairs(Recipes.BaseItems) do
		if item.name == itemName then return true end
	end
	return false
end

local function recipesFor(island)
	return island == "brainrot" and BrainrotRecipes or FusionRecipes
end

-- A player can equip anything they've actually discovered, base item or
-- curated result, on either island — same "known" definition the Index
-- already uses, just checked here instead of read off it.
local function playerKnowsItem(s, player, itemName, island)
	local Recipes = recipesFor(island)
	if isBaseItemName(itemName, Recipes) then return true end
	if island == "junkyard" then
		return s.discovered[itemName] == true
	end
	for _, name in ipairs(Brainrot.Snapshot(player)) do
		if name == itemName then return true end
	end
	return false
end

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
	{ text = string.format("Complete the index: all %d builds", FusionRecipes.GetTotalDiscoveries()),
	  reward = 50000, check = function(s) return s.count >= FusionRecipes.GetTotalDiscoveries() end },
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

local rebirthRemote = ReplicatedStorage:FindFirstChild("RebirthPlayer")
if not rebirthRemote then
	rebirthRemote = Instance.new("RemoteEvent")
	rebirthRemote.Name = "RebirthPlayer"
	rebirthRemote.Parent = ReplicatedStorage
end

local equipCompanionRemote = ReplicatedStorage:FindFirstChild("EquipCompanion")
if not equipCompanionRemote then
	equipCompanionRemote = Instance.new("RemoteEvent")
	equipCompanionRemote.Name = "EquipCompanion"
	equipCompanionRemote.Parent = ReplicatedStorage
end

local selectTradeOfferRemote = ReplicatedStorage:FindFirstChild("SelectTradeOffer")
if not selectTradeOfferRemote then
	selectTradeOfferRemote = Instance.new("RemoteEvent")
	selectTradeOfferRemote.Name = "SelectTradeOffer"
	selectTradeOfferRemote.Parent = ReplicatedStorage
end

local confirmTradeRemote = ReplicatedStorage:FindFirstChild("ConfirmTrade")
if not confirmTradeRemote then
	confirmTradeRemote = Instance.new("RemoteEvent")
	confirmTradeRemote.Name = "ConfirmTrade"
	confirmTradeRemote.Parent = ReplicatedStorage
end

local cancelTradeRemote = ReplicatedStorage:FindFirstChild("CancelTrade")
if not cancelTradeRemote then
	cancelTradeRemote = Instance.new("RemoteEvent")
	cancelTradeRemote.Name = "CancelTrade"
	cancelTradeRemote.Parent = ReplicatedStorage
end

local sellInventoryRemote = ReplicatedStorage:FindFirstChild("SellInventoryItem")
if not sellInventoryRemote then
	sellInventoryRemote = Instance.new("RemoteEvent")
	sellInventoryRemote.Name = "SellInventoryItem"
	sellInventoryRemote.Parent = ReplicatedStorage
end

local moveToCarryRemote = ReplicatedStorage:FindFirstChild("MoveToCarry")
if not moveToCarryRemote then
	moveToCarryRemote = Instance.new("RemoteEvent")
	moveToCarryRemote.Name = "MoveToCarry"
	moveToCarryRemote.Parent = ReplicatedStorage
end

-- The side travel menu asks for a destination key; the server decides
-- where that actually is.
local travelRemote = ReplicatedStorage:FindFirstChild("TravelTo")
if not travelRemote then
	travelRemote = Instance.new("RemoteEvent")
	travelRemote.Name = "TravelTo"
	travelRemote.Parent = ReplicatedStorage
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

local plots = {}   -- [index] = { model, owner, centre, pad, padLabel, padPrompt, signLabel }
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

-- Shared by manual sells and passive income — the Haggler upgrade, any
-- timed sell boost, a player's permanent Rebirth multiplier, and their
-- equipped companion (if any) apply to everything a player's builds earn,
-- not just the moment you press Sell.
local function valueMultiplier(player, s)
	return (1 + (s.upgrades.value - 1) * 0.15) * boostMult(s, "value") * Rebirth.Multiplier(player) * Companions.Bonus(player)
end

-- Best available colored tag for an item name that might carry a mutation
-- prefix (see Mutations.luau) — mutation color takes over from rarity
-- color when present, since it's the more exciting signal in that moment.
local function instanceTag(name)
	local baseName, mutationId = Mutations.Unwrap(name)
	if mutationId then
		return Mutations.Tag(name, mutationId)
	end
	return ItemRarity.Tag(baseName, FusionRecipes.GetTier(baseName), FusionRecipes.IsSecretResult(baseName))
end

-- Same idea as instanceTag, but for a name that's known to belong to a
-- specific island rather than possibly carrying a mutation prefix — used
-- for companion names, which are chosen by base recipe identity.
local function islandTag(itemName, island)
	local Recipes = recipesFor(island)
	return ItemRarity.Tag(itemName, Recipes.GetTier(itemName), Recipes.IsSecretResult(itemName))
end

-- Tier/secret/value for any item name PlotManager could be holding —
-- always a Junkyard name, but may carry a mutation prefix. Defined early
-- since pushUI needs it for inventory stats, well before Trading (which
-- also uses it) is defined.
local function itemTierInfo(itemName)
	local baseName, mutationId = Mutations.Unwrap(itemName)
	return {
		tier = FusionRecipes.GetTier(baseName),
		isSecret = FusionRecipes.IsSecretResult(baseName),
		value = FusionRecipes.GetValue(baseName) * Mutations.ValueMultiplier(mutationId),
	}
end

-- Cars as transportation: every fused vehicle in your inventory (not sold)
-- makes you faster, on top of everything else. Used to be keyed off
-- physical Garage placement; inventory only ever holds fusion results
-- (never raw scrap), so a plain count does the same job with no zones.
local BASE_WALK_SPEED = 16
local INVENTORY_SPEED_PER_ITEM = 1
local INVENTORY_SPEED_CAP = 10

local function updateWalkSpeed(player)
	local s = state[player]
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not (s and humanoid) then return end

	local bonus = math.min(#s.inventory * INVENTORY_SPEED_PER_ITEM, INVENTORY_SPEED_CAP)
	humanoid.WalkSpeed = BASE_WALK_SPEED + bonus
end

------------------------------------------------------------------
-- Small builders
------------------------------------------------------------------

local function makeLabel(parent, text, offsetY, size, color, maxDistance)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.new(0, size or 280, 0, 60)
	gui.StudsOffset = Vector3.new(0, offsetY or 4, 0)
	gui.AlwaysOnTop = true
	-- Billboards hold a constant SCREEN size regardless of distance, so
	-- without a cutoff every plot's labels stay fully legible from
	-- clear across the map and pile into an unreadable wall of text.
	gui.MaxDistance = maxDistance or 45
	gui.Parent = parent

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = color or Color3.fromRGB(255, 255, 255)
	label.TextStrokeTransparency = 0.3
	label.TextScaled = true
	label.Font = Enum.Font.FredokaOne
	-- Lets a caller color individual item names within a shared label (the
	-- pad's "[a] + [b]" preview) via <font color="..."> tags. Plain text
	-- without tags renders identically either way.
	label.RichText = true
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
-- Inventory — where a fusion result actually goes. No more physical
-- display zones: the pad is the only place a new item enters a player's
-- hands (grabbed scrap into carry, or a fusion result into here), and
-- selling / sending something back to carry to re-fuse both happen from
-- the Inventory popup instead of walking to a physical slot.
------------------------------------------------------------------

-- Roughly how long passive income takes to match a manual sell of the
-- same item — after that it's pure profit for as long as it's held.
local PLACEMENT_PAYBACK_SECONDS = 90
local INCOME_TICK_SECONDS = 3

-- A flat cap rather than three tier-gated zone capacities (4+3+2=9 before)
-- — a little more generous since nothing about it is tier-specific
-- anymore, but still a real limit: sell or send things back to carry to
-- make room, same "make a choice" pressure the old zones created.
local INVENTORY_CAPACITY = 15

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
	local signLabel = makeLabel(signPost, "UNCLAIMED PLOT", 6, 260, Color3.fromRGB(255, 200, 80), 90)

	-- The fusion pad: only its owner can use it.
	local pad = makePart({
		Name = "FusionPad",
		Size = Vector3.new(16, 1, 16),
		Position = centre + Vector3.new(0, 1, 0),
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(255, 110, 0),
		Parent = model,
	})
	local padLabel = makeLabel(pad, "FUSION PAD", 7, 260, nil, 55)

	local padPrompt = Instance.new("ProximityPrompt")
	padPrompt.ActionText = "Fuse"
	padPrompt.ObjectText = "Fusion Pad"
	padPrompt.HoldDuration = 0
	padPrompt.MaxActivationDistance = 16
	padPrompt.RequiresLineOfSight = false
	padPrompt.Parent = pad

	-- No physical display zones anymore — a fused result goes straight
	-- into the player's inventory (see Inventory below), sold or sent
	-- back to the pad from the Inventory popup instead of walking to a
	-- physical slot. The pad is now the only place a new item (grabbed
	-- scrap or a fusion result) actually enters a player's hands.
	plots[i] = {
		model = model,
		owner = nil,
		centre = centre,
		pad = pad,
		padLabel = padLabel,
		padPrompt = padPrompt,
		signLabel = signLabel,
	}
end

------------------------------------------------------------------
-- Public leaderboard monument — a physical sign in the middle of the
-- yard everyone can walk up and read, instead of a private top-of-screen
-- popup. A SurfaceGui on a fixed-orientation board, not a BillboardGui —
-- it never rotates to track the camera, so it reads like an actual sign
-- you have to walk up and face rather than a UI element that happens to
-- float in the world. That also solves "visible from anywhere" for free:
-- normal perspective already makes a small sign illegible from far away,
-- with no artificial MaxDistance cutoff needed. Scrollable for the full
-- Top 100 rather than a fixed 10.
------------------------------------------------------------------

local function commas(n)
	local formatted = tostring(n)
	while true do
		local replaced
		formatted, replaced = formatted:gsub("^(-?%d+)(%d%d%d)", "%1,%2")
		if replaced == 0 then break end
	end
	return formatted
end

local RANK_COLORS = {
	[1] = Color3.fromRGB(255, 215, 60),
	[2] = Color3.fromRGB(210, 215, 220),
	[3] = Color3.fromRGB(210, 140, 80),
}

do
	local base = Vector3.new(0, 1.2, 0)

	-- A wide pedestal, not a thin pole — this is a kiosk you walk up and
	-- stand in front of, so it needs real footing, and the board sits low
	-- enough (bottom ~7 studs up) to read and scroll without tipping the
	-- camera back like you would for a tall billboard.
	makePart({
		Name = "LeaderboardBase",
		Size = Vector3.new(6, 6, 6),
		Position = base + Vector3.new(0, 3, 0),
		Material = Enum.Material.SmoothPlastic,
		Color = Color3.fromRGB(40, 40, 48),
		Parent = workspace,
	})

	-- A slightly larger gold backing peeking out from behind the dark
	-- board — a real physical frame, not a screen-space UIStroke, since
	-- this whole redesign is about the sign being an actual object.
	makePart({
		Name = "LeaderboardFrame",
		Size = Vector3.new(10.7, 13.7, 0.6),
		-- +Z, i.e. BEHIND the board relative to its Front (-Z) face — this
		-- keeps the board's own front surface (where the SurfaceGui lives)
		-- as the closest thing to a viewer standing in front of it, so the
		-- frame only ever shows in the margin around the board, never
		-- occluding the leaderboard text itself.
		Position = base + Vector3.new(0, 13.7, 0.3),
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(255, 205, 40),
		Parent = workspace,
	})

	-- The sign itself — a real, visible, fixed-orientation board (unlike
	-- the old invisible anchor part the BillboardGui used to hang off of).
	-- Only readable from its front face, same as an actual sign.
	local board = makePart({
		Name = "LeaderboardBoard",
		Size = Vector3.new(10, 13, 1),
		Position = base + Vector3.new(0, 13.7, 0),
		Material = Enum.Material.SmoothPlastic,
		Color = Color3.fromRGB(18, 18, 24),
		Parent = workspace,
	})

	local boardGui = Instance.new("SurfaceGui")
	boardGui.Face = Enum.NormalId.Front
	boardGui.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	boardGui.CanvasSize = Vector2.new(640, 860)
	boardGui.Parent = board

	local boardTitle = Instance.new("TextLabel")
	boardTitle.Size = UDim2.new(1, -40, 0, 64)
	boardTitle.Position = UDim2.new(0, 20, 0, 20)
	boardTitle.BackgroundTransparency = 1
	boardTitle.Text = "🏆 TOP FUSIONEERS"
	boardTitle.TextColor3 = Color3.fromRGB(255, 205, 40)
	boardTitle.TextStrokeTransparency = 0.4
	boardTitle.Font = Enum.Font.LuckiestGuy
	boardTitle.TextScaled = true
	boardTitle.Parent = boardGui

	local boardSub = Instance.new("TextLabel")
	boardSub.Size = UDim2.new(1, -40, 0, 26)
	boardSub.Position = UDim2.new(0, 20, 0, 86)
	boardSub.BackgroundTransparency = 1
	boardSub.Text = "Ranked by lifetime coins earned  —  scroll for more"
	boardSub.TextColor3 = Color3.fromRGB(180, 180, 190)
	boardSub.Font = Enum.Font.FredokaOne
	boardSub.TextScaled = true
	boardSub.Parent = boardGui

	-- The part the player actually scrolls — a ScrollingFrame on a
	-- SurfaceGui responds to mouse wheel / touch drag the same way it
	-- would on a screen-space GUI, as long as the player is looking at it.
	local boardScroll = Instance.new("ScrollingFrame")
	boardScroll.Size = UDim2.new(1, -40, 1, -140)
	boardScroll.Position = UDim2.new(0, 20, 0, 128)
	boardScroll.BackgroundTransparency = 1
	boardScroll.BorderSizePixel = 0
	boardScroll.ScrollBarThickness = 10
	boardScroll.ScrollBarImageColor3 = Color3.fromRGB(255, 205, 40)
	boardScroll.CanvasSize = UDim2.new(0, 0, 0, 0)
	boardScroll.Parent = boardGui

	local boardLayout = Instance.new("UIListLayout")
	boardLayout.Padding = UDim.new(0, 4)
	boardLayout.Parent = boardScroll

	local function redrawBoard(top)
		for _, child in ipairs(boardScroll:GetChildren()) do
			if not child:IsA("UIListLayout") then child:Destroy() end
		end

		if #top == 0 then
			local empty = Instance.new("TextLabel")
			empty.Size = UDim2.new(1, 0, 0, 40)
			empty.BackgroundTransparency = 1
			empty.Text = "No rankings yet — be the first to earn your way on."
			empty.TextColor3 = Color3.fromRGB(150, 150, 165)
			empty.Font = Enum.Font.FredokaOne
			empty.TextSize = 20
			empty.TextWrapped = true
			empty.Parent = boardScroll
		end

		for i, entry in ipairs(top) do
			local row = Instance.new("TextLabel")
			row.Size = UDim2.new(1, 0, 0, 34)
			row.LayoutOrder = i
			row.BackgroundTransparency = 1
			row.Text = string.format("#%d  %s — %s coins", i, entry.name, commas(entry.coins))
			row.TextColor3 = RANK_COLORS[i] or Color3.fromRGB(220, 220, 230)
			row.Font = Enum.Font.FredokaOne
			row.TextSize = 22
			row.TextXAlignment = Enum.TextXAlignment.Left
			row.Parent = boardScroll
		end

		boardScroll.CanvasSize = UDim2.new(0, 0, 0, boardLayout.AbsoluteContentSize.Y + 10)
	end

	task.spawn(function()
		while true do
			Leaderboard.RefreshIfStale()
			redrawBoard(Leaderboard.GetTopCached())
			task.wait(15)
		end
	end)
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

	local secretsFound, secretTotal = FusionRecipes.GetSecretProgress(s.discovered)
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

	local brainrotDiscovered = {}
	for _, name in ipairs(Brainrot.Snapshot(player)) do
		brainrotDiscovered[name] = true
	end

	-- Full stats per item, computed here rather than on the client, since
	-- value/tier/mutation logic already lives entirely server-side.
	local inventoryInfo = {}
	for i, itemName in ipairs(s.inventory) do
		local info = itemTierInfo(itemName)
		table.insert(inventoryInfo, {
			index = i,
			name = itemName,
			tier = info.tier,
			isSecret = info.isSecret,
			value = info.value,
			perSecond = info.value / PLACEMENT_PAYBACK_SECONDS,
		})
	end

	-- `false`, never nil: RemoteEvent args drop nil-valued table keys, and
	-- the client needs to tell "no companion" apart from "field absent"
	-- (e.g. on a toast-only message) to know when to clear a stale display.
	local equippedCompanion = Companions.Get(player)
	local companionInfo = equippedCompanion and {
		name = equippedCompanion.name,
		island = equippedCompanion.island,
		bonusPercent = math.floor((Companions.Bonus(player) - 1) * 100 + 0.5),
	} or false

	remote:FireClient(player, {
		slots = s.slots,
		maxSlots = capacity(player, s),
		discoveredCount = s.count,
		total = FusionRecipes.GetTotalDiscoveries(),
		list = s.discoveredList,
		index = FusionRecipes.GetIndex(s.discovered),
		brainrotIndex = BrainrotRecipes.GetIndex(brainrotDiscovered),
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
		rebirth = {
			level = Rebirth.Get(player),
			maxLevel = Rebirth.MaxLevel,
			multiplier = Rebirth.Multiplier(player),
			nextCost = Rebirth.NextCost(player),
			nextMultiplier = Rebirth.NextMultiplier(player),
			maxed = Rebirth.IsMaxed(player),
		},
		companion = companionInfo,
		inventory = inventoryInfo,
		inventoryCapacity = INVENTORY_CAPACITY,
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

	local function tag(itemName)
		if not itemName then return "empty" end
		return instanceTag(itemName)
	end

	plot.padLabel.Text = string.format(
		"FUSION PAD\n[ %s ]  +  [ %s ]",
		tag(s.slots[1]),
		tag(s.slots[2])
	)

	-- Physical items sitting in the two slots on the pad. A carried item
	-- can carry a mutation prefix (sent back from Inventory to re-fuse),
	-- so this unwraps for the mesh/tier lookup and tints the mesh itself,
	-- same as everywhere else a possibly-mutated name gets rendered.
	plot.slotParts = plot.slotParts or {}
	for i = 1, 2 do
		if plot.slotParts[i] then
			plot.slotParts[i]:Destroy()
			plot.slotParts[i] = nil
		end

		local itemName = s.slots[i]
		if itemName then
			local baseName, mutationId = Mutations.Unwrap(itemName)
			local offset = (i == 1) and -4.6 or 4.6
			local padSurfaceY = plot.pad.Position.Y + plot.pad.Size.Y / 2
			local slotPart = ItemVisuals.Create(baseName, Vector3.new(plot.pad.Position.X + offset, padSurfaceY, plot.pad.Position.Z), 0.85)
			slotPart.Name = "Slot" .. i
			slotPart.Parent = plot.model
			local mutationColor = Mutations.Color(mutationId)
			if mutationColor then slotPart.Color = mutationColor end
			local itemColor = mutationColor or ItemRarity.Color(FusionRecipes.GetTier(baseName), FusionRecipes.IsSecretResult(baseName))
			makeLabel(slotPart, itemName, 1.8, 140, itemColor, 45)
			plot.slotParts[i] = slotPart
		end
	end
end

-- A small physical display behind each plot's pad, mirroring inventory
-- 1:1 — purely decorative, no selling/picking-up here, since that's what
-- the Inventory popup is for. This exists so a player (and anyone walking
-- by) can actually SEE what's earning them money instead of it only ever
-- being a number in a list. Rebuilt from scratch on every call rather
-- than diffed, same as the Inventory popup's own grid — simplest thing
-- that's correct, and inventory tops out at 15 items so it's cheap.
local DISPLAY_COLS = 5
local DISPLAY_SPACING = 6
local DISPLAY_START_Z = 14 -- clears the 16-stud pad before the grid begins

local function clearInventoryDisplay(plot)
	if not plot.displayParts then return end
	for _, part in ipairs(plot.displayParts) do
		part:Destroy()
	end
	plot.displayParts = nil
end

local function refreshInventoryDisplay(player)
	local s = state[player]
	if not s then return end
	local plot = plots[s.plotIndex]
	if not plot then return end

	clearInventoryDisplay(plot)
	plot.displayParts = {}

	for i, itemName in ipairs(s.inventory) do
		local baseName, mutationId = Mutations.Unwrap(itemName)
		local col = (i - 1) % DISPLAY_COLS
		local row = math.floor((i - 1) / DISPLAY_COLS)
		local offset = Vector3.new(
			(col - (DISPLAY_COLS - 1) / 2) * DISPLAY_SPACING,
			0,
			DISPLAY_START_Z + row * DISPLAY_SPACING
		)
		local part = ItemVisuals.Create(baseName, plot.centre + offset + Vector3.new(0, 1, 0), 0.6)
		local mutationColor = Mutations.Color(mutationId)
		if mutationColor then part.Color = mutationColor end
		part.Parent = plot.model

		local info = itemTierInfo(itemName)
		local itemColor = mutationColor or ItemRarity.Color(info.tier, info.isSecret)
		makeLabel(part, string.format("%s\n+%.1f/sec", instanceTag(itemName), info.value / PLACEMENT_PAYBACK_SECONDS), 1.6, 130, itemColor, 40)

		table.insert(plot.displayParts, part)
	end
end

local function addCoins(player, amount)
	local stats = player:FindFirstChild("leaderstats")
	if not stats then return end
	local coins = stats:FindFirstChild("Coins")
	if coins then
		amount = Gamepasses.Coins(player, amount)
		coins.Value = coins.Value + amount
		Leaderboard.Record(player, amount)
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
	local position = Vector3.new(math.random(-40, 40), 1.2, math.random(-40, 40))
	local baseName, mutationId = Mutations.Unwrap(itemName)
	local part = ItemVisuals.Create(baseName, position, 1)
	local mutationColor = Mutations.Color(mutationId)
	if mutationColor then part.Color = mutationColor end
	part:SetAttribute("ItemName", itemName)
	local itemColor = mutationColor or ItemRarity.Color(FusionRecipes.GetTier(baseName), FusionRecipes.IsSecretResult(baseName))
	makeLabel(part, itemName, 2, 150, itemColor, 45)
	part.Parent = getScrapFolder()
end

------------------------------------------------------------------
-- Fusion
------------------------------------------------------------------

-- Selling and sending an item back to carry both live down in the
-- Inventory section below, next to the remotes that trigger them —
-- there's no more physical placement step for a fusion result to go
-- through here.

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

	-- An item sent back from Inventory can still carry its mutation prefix
	-- — recipe lookups need the bare name, or a "[Shiny] Trail Blazer"
	-- would never match the curated recipe for "Trail Blazer" and would
	-- silently fall back to a worse, wrong-tier hybrid. The ingredient's
	-- own mutation isn't carried forward either way — the result gets its
	-- own independent roll below, same as always.
	local baseA = Mutations.Unwrap(a)
	local baseB = Mutations.Unwrap(b)

	s.slots[1], s.slots[2] = nil, nil
	-- Shift any extra carried items down into the empty slots.
	local remaining = {}
	for i = 3, capacity(player, s) do
		if s.slots[i] then table.insert(remaining, s.slots[i]) end
	end
	s.slots = remaining
	refreshPad(player)

	local result, info = FusionRecipes.Fuse(baseA, baseB)

	if not result then
		-- Only reachable on malformed input (see FusionRecipes.Fuse) —
		-- every real item name pair now produces a result.
		dropItemNearYard(a)
		dropItemNearYard(b)
		pushUI(player)
		return
	end

	-- Mutation rolls independently of tier/secret status — a common Rusted
	-- Sedan and a secret Scrapyard God are equally eligible. Discovery/goal
	-- bookkeeping below always uses the bare `result` name; only the
	-- placed/displayed instance carries the mutation.
	local mutationId = Mutations.Roll(s.upgrades.luck, s.mutationPity)
	s.mutationPity = mutationId and 0 or (s.mutationPity or 0) + 1
	local instanceName = Mutations.Wrap(result, mutationId)
	local instanceValue = math.floor(info.value * Mutations.ValueMultiplier(mutationId))

	local resultTag = instanceTag(instanceName)
	local aTag = instanceTag(a)
	local bTag = instanceTag(b)

	if info.isFallback then
		-- A generic hybrid, not a curated recipe — still worth having and
		-- placing, but doesn't count toward discoveries/goals.
		toast(player, string.format("%s + %s = %s", aTag, bTag, resultTag))
	elseif not s.discovered[result] then
		s.discovered[result] = true
		s.count = s.count + 1
		table.insert(s.discoveredList, result)
		if info.tier > s.bestTier then s.bestTier = info.tier end
		if info.isSecret then s.secrets = s.secrets + 1 end
		toast(player, string.format("NEW DISCOVERY\n%s", resultTag), true)
		print(string.format("[Fusion] %s discovered %s (%d/%d)",
			player.Name, result, s.count, FusionRecipes.GetTotalDiscoveries()))
	else
		toast(player, string.format("%s + %s = %s", aTag, bTag, resultTag))
	end

	if info.isSecret then
		toast(player, string.format("SECRET RECIPE\n%s", resultTag), true)
	end

	if mutationId then
		toast(player, string.format("MUTATION!\n%s", resultTag), true)
	end

	-- Straight into inventory — the pad is the only place a new item
	-- enters a player's hands now. Fusing always nets -1 slot overall
	-- (2 ingredients consumed, 1 result produced), so this can only ever
	-- fail to fit if the inventory was already completely full before
	-- this fusion even started; auto-sell instead of losing it.
	if #s.inventory < INVENTORY_CAPACITY then
		table.insert(s.inventory, instanceName)
	else
		local mult = valueMultiplier(player, s)
		local payout = addCoins(player, math.floor(instanceValue * mult)) or 0
		toast(player, string.format("Inventory's full — %s auto-sold for %d coins instead.", resultTag, payout))
	end
	updateWalkSpeed(player)
	refreshInventoryDisplay(player)

	playSound(plot.pad, (mutationId or info.isSecret or info.tier >= 4) and "big" or "fuse")
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
		local grabbedTag = ItemRarity.Tag(grabbed, FusionRecipes.GetTier(grabbed), false)
		broadcast(string.format("%s claimed the GOLDEN SCRAP — %s!", player.Name, grabbedTag))
	else
		local chance = math.min(LUCK_MAX_CHANCE, (s.upgrades.luck * boostMult(s, "luck") - 1) * LUCK_PER_LEVEL)
		if math.random() < chance then
			local upgraded = rarerThan(grabbed)
			if upgraded then
				local fromTag = ItemRarity.Tag(grabbed, FusionRecipes.GetTier(grabbed), false)
				local toTag = ItemRarity.Tag(upgraded, FusionRecipes.GetTier(upgraded), false)
				toast(player, string.format("LUCKY FIND\n%s → %s", fromTag, toTag), true)
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
-- Rebirth — a permanent coin multiplier, paid for with a full reset of
-- coins, upgrades, and everything currently in inventory. Discoveries,
-- the Index, gamepasses, daily streak and boosts are untouched: those
-- are earned records, not part of the grind this resets.
------------------------------------------------------------------

rebirthRemote.OnServerEvent:Connect(function(player)
	local s = state[player]
	if not s then return end

	local cost = Rebirth.NextCost(player)
	if not cost then
		toast(player, "Already at max Rebirth.")
		return
	end

	local stats = player:FindFirstChild("leaderstats")
	local coins = stats and stats:FindFirstChild("Coins")
	if not coins then return end

	if coins.Value < cost then
		toast(player, string.format("Not enough coins to rebirth. Need %d.", cost))
		return
	end

	coins.Value = 0
	s.upgrades = { luck = 1, carry = 1, magnet = 0, value = 1 }
	s.inventory = {}
	updateWalkSpeed(player)
	refreshInventoryDisplay(player)
	Rebirth.Increment(player)

	local level = Rebirth.Get(player)
	local mult = Rebirth.Multiplier(player)
	playSound(playerRoot(player), "big")
	toast(player, string.format("REBIRTH %d\nPermanent x%.2f coin multiplier", level, mult), true)
	broadcast(string.format("%s reached Rebirth %d!", player.Name, level))
	pushUI(player)
end)

------------------------------------------------------------------
-- Travel menu — the side panel's teleport buttons
------------------------------------------------------------------

travelRemote.OnServerEvent:Connect(function(player, destination)
	local character = player.Character
	if not character then return end

	if destination == "junkyard" then
		local s = state[player]
		local plot = s and plots[s.plotIndex]
		if plot then
			character:PivotTo(CFrame.new(plot.centre + Vector3.new(0, 5, -20)))
		end
	elseif destination == "brainrot" then
		character:PivotTo(CFrame.new(Brainrot.GetArrivalPosition()))
	end
end)

------------------------------------------------------------------
-- Companions — equip any discovered item to follow you and boost value
------------------------------------------------------------------

local companionParts = {} -- [player] = part

local function updateCompanionVisual(player)
	local old = companionParts[player]
	if old then
		old:Destroy()
		companionParts[player] = nil
	end

	local companion = Companions.Get(player)
	if not companion then return end

	local Recipes = recipesFor(companion.island)
	local part = ItemVisuals.Create(companion.name, Vector3.new(0, 5, 0), COMPANION_SCALE)
	part.Anchored = true
	part.CanCollide = false
	part.Parent = workspace

	local light = Instance.new("PointLight")
	light.Color = ItemRarity.Color(Recipes.GetTier(companion.name), Recipes.IsSecretResult(companion.name))
	light.Range = 10
	light.Brightness = 1.5
	light.Parent = part

	companionParts[player] = part
end

-- Runs every frame (unlike the other background loops below, which only
-- need to tick every second or two) because a companion that visibly
-- stutters while following is worse than not having one at all.
RunService.Heartbeat:Connect(function()
	local t = os.clock()
	for player, part in pairs(companionParts) do
		local root = part.Parent and playerRoot(player)
		if root then
			local bob = math.sin(t * 2 + player.UserId) * 0.6
			local orbit = root.CFrame:VectorToWorldSpace(Vector3.new(-4, 3 + bob, -3))
			part.CFrame = CFrame.new(root.Position + orbit) * CFrame.Angles(0, t * 1.5, 0)
		elseif not root then
			part:Destroy()
			companionParts[player] = nil
		end
	end
end)

equipCompanionRemote.OnServerEvent:Connect(function(player, itemName, island)
	local s = state[player]
	if not s then return end
	if type(itemName) ~= "string" or (island ~= "junkyard" and island ~= "brainrot") then return end

	if not playerKnowsItem(s, player, itemName, island) then
		toast(player, "You haven't discovered that yet.")
		return
	end

	-- Clicking the currently-equipped item again unequips it.
	local current = Companions.Get(player)
	if current and current.name == itemName and current.island == island then
		Companions.Set(player, nil)
		toast(player, "Companion unequipped.")
	else
		Companions.Set(player, { name = itemName, island = island })
		toast(player, string.format("%s is now your companion.", islandTag(itemName, island)))
	end

	updateCompanionVisual(player)
	pushUI(player)
end)

------------------------------------------------------------------
-- Trading — 1-for-1, same server, proximity-triggered. Junkyard items
-- only: Brainrot creatures never sit in a carry slot or a placement zone
-- (that island pays out immediately), so there's nothing there to trade.
------------------------------------------------------------------

-- True only if `player` really currently holds exactly this item where the
-- ref claims — re-run at both offer time and execute time, since a client
-- claim is never trusted and state can change between the two.
local function resolveItemRef(player, ref)
	local s = state[player]
	if not s then return false end
	if type(ref) ~= "table" or type(ref.index) ~= "number" or type(ref.itemName) ~= "string" then
		return false
	end

	if ref.source == "carry" then
		return s.slots[ref.index] == ref.itemName
	elseif ref.source == "inventory" then
		return s.inventory[ref.index] == ref.itemName
	end
	return false
end

-- Every item `player` currently holds, carry and inventory, in the same
-- itemRef shape resolveItemRef expects — sent to the client so it can
-- offer a real list of things to trade, not a guess.
local function getMyTradeItems(player)
	local s = state[player]
	if not s then return {} end
	local items = {}

	for i, name in ipairs(s.slots) do
		table.insert(items, { source = "carry", index = i, itemName = name })
	end
	for i, name in ipairs(s.inventory) do
		table.insert(items, { source = "inventory", index = i, itemName = name })
	end

	return items
end

-- `outgoingRef` is the item this same player is about to give away in the
-- same trade — counted as an already-free slot if it shares a source with
-- the incoming item, since removeTradedItem/giveTradedItem always run for
-- both sides before either side's item lands. Without this, a player
-- whose carry or inventory was already full could never trade an item
-- there for another of the same kind, even a plain 1-for-1 swap that nets
-- to no change in how many slots they're using.
local function canReceiveTradedItem(player, itemName, source, outgoingRef)
	local s = state[player]
	if not s then return false end

	if source == "carry" then
		local freeSlots = capacity(player, s) - #s.slots
		if outgoingRef and outgoingRef.source == "carry" then
			freeSlots = freeSlots + 1
		end
		return freeSlots > 0
	elseif source == "inventory" then
		local freeSlots = INVENTORY_CAPACITY - #s.inventory
		if outgoingRef and outgoingRef.source == "inventory" then
			freeSlots = freeSlots + 1
		end
		return freeSlots > 0
	end
	return false
end

local function removeTradedItem(player, ref)
	local s = state[player]
	if ref.source == "carry" then
		table.remove(s.slots, ref.index)
		refreshPad(player)
	elseif ref.source == "inventory" then
		table.remove(s.inventory, ref.index)
		updateWalkSpeed(player)
		refreshInventoryDisplay(player)
	end
end

local function giveTradedItem(player, itemName, source)
	local s = state[player]
	if source == "carry" then
		table.insert(s.slots, itemName)
		refreshPad(player)
	elseif source == "inventory" then
		table.insert(s.inventory, itemName)
		updateWalkSpeed(player)
		refreshInventoryDisplay(player)
	end
end

local function pushTradeUpdate(player)
	local snapshot = Trade.Snapshot(player)
	remote:FireClient(player, {
		trade = snapshot or false, -- false, not nil: see the same note on `companion` above
		myTradeItems = snapshot and getMyTradeItems(player) or nil,
	})
end

local function endTrade(player, reason)
	local partner = Trade.Partner(player)
	Trade.End(player)
	if reason then
		toast(player, reason)
		if partner then toast(partner, reason) end
	end
	pushTradeUpdate(player)
	if partner then pushTradeUpdate(partner) end
end

-- Re-checks everything before moving anything. No yield happens between
-- the checks and the swap below, so nothing else can run in between and
-- invalidate what was just verified — that's what keeps this atomic on a
-- single-threaded script without needing an explicit lock.
local function executeTrade(playerA, playerB)
	local trade = Trade.Get(playerA)
	if not trade then return end

	local offerA, offerB = trade.offers[playerA], trade.offers[playerB]
	if not (offerA and offerB) then
		endTrade(playerA)
		return
	end

	if not resolveItemRef(playerA, offerA) or not resolveItemRef(playerB, offerB) then
		endTrade(playerA, "Trade cancelled — an offered item is no longer available.")
		return
	end
	if not canReceiveTradedItem(playerB, offerA.itemName, offerA.source, offerB)
		or not canReceiveTradedItem(playerA, offerB.itemName, offerB.source, offerA) then
		endTrade(playerA, "Trade cancelled — one side has no room for the incoming item.")
		return
	end

	removeTradedItem(playerA, offerA)
	removeTradedItem(playerB, offerB)
	giveTradedItem(playerA, offerB.itemName, offerB.source)
	giveTradedItem(playerB, offerA.itemName, offerA.source)

	toast(playerA, string.format("Trade complete! You received %s.", instanceTag(offerB.itemName)), true)
	toast(playerB, string.format("Trade complete! You received %s.", instanceTag(offerA.itemName)), true)

	Trade.End(playerA)
	pushTradeUpdate(playerA)
	pushTradeUpdate(playerB)
	pushUI(playerA)
	pushUI(playerB)
end

-- Trade prompts only show to players OTHER than their owner. A
-- ProximityPrompt parented to your own HumanoidRootPart is always at
-- distance 0 from you — left always "Enabled", it permanently wins
-- proximity over every other prompt in range (grab, fuse) and blocks
-- them, which is exactly the "can't pick anything up" bug this fixes.
-- Only enabled while some other player is actually within range.
local TRADE_PROMPT_RANGE = 10
local tradePrompts = {} -- [player] = { prompt = ProximityPrompt, root = BasePart }

local function attachTradePrompt(player, character)
	local root = character:WaitForChild("HumanoidRootPart")
	local existing = root:FindFirstChild("TradePrompt")
	if existing then existing:Destroy() end

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "TradePrompt"
	prompt.ActionText = "Trade"
	prompt.ObjectText = player.Name
	prompt.HoldDuration = 0.3
	prompt.MaxActivationDistance = TRADE_PROMPT_RANGE
	prompt.RequiresLineOfSight = false
	prompt.Enabled = false
	prompt.Parent = root

	tradePrompts[player] = { prompt = prompt, root = root }

	prompt.Triggered:Connect(function(triggeringPlayer)
		if triggeringPlayer == player then return end
		local id = Trade.Start(triggeringPlayer, player)
		if not id then
			toast(triggeringPlayer, "Can't start a trade right now — one of you is already trading.")
			return
		end
		toast(triggeringPlayer, "Trade started with " .. player.Name .. ".")
		toast(player, triggeringPlayer.Name .. " wants to trade with you!")
		pushTradeUpdate(triggeringPlayer)
		pushTradeUpdate(player)
	end)
end

task.spawn(function()
	while true do
		task.wait(0.5)
		for owner, info in pairs(tradePrompts) do
			if info.root.Parent then
				local nearbyOther = false
				for _, other in ipairs(Players:GetPlayers()) do
					if other ~= owner then
						local otherRoot = playerRoot(other)
						if otherRoot and (otherRoot.Position - info.root.Position).Magnitude <= TRADE_PROMPT_RANGE then
							nearbyOther = true
							break
						end
					end
				end
				info.prompt.Enabled = nearbyOther
			end
		end
	end
end)

selectTradeOfferRemote.OnServerEvent:Connect(function(player, ref)
	if not Trade.Get(player) then return end
	if not resolveItemRef(player, ref) then
		toast(player, "You don't have that item.")
		return
	end
	Trade.SetOffer(player, ref)
	pushTradeUpdate(player)
	local partner = Trade.Partner(player)
	if partner then pushTradeUpdate(partner) end
end)

confirmTradeRemote.OnServerEvent:Connect(function(player)
	if not Trade.Get(player) then return end
	if not Trade.Confirm(player) then
		toast(player, "Select an item to offer first.")
		return
	end
	local partner = Trade.Partner(player)
	pushTradeUpdate(player)
	if partner then pushTradeUpdate(partner) end

	if partner and Trade.BothConfirmed(player) then
		executeTrade(player, partner)
	end
end)

cancelTradeRemote.OnServerEvent:Connect(function(player)
	if not Trade.Get(player) then return end
	endTrade(player)
end)

------------------------------------------------------------------
-- Inventory — selling and sending an item back to carry (to re-fuse it
-- into something bigger) both happen from the Inventory popup now,
-- instead of walking to a physical slot. Reuses the same remove/give
-- helpers Trading already validated, with "inventory" as just another
-- itemRef source alongside "carry".
------------------------------------------------------------------

sellInventoryRemote.OnServerEvent:Connect(function(player, index)
	local s = state[player]
	if not s then return end
	local itemName = type(index) == "number" and s.inventory[index]
	if not itemName then return end

	local mult = valueMultiplier(player, s)
	local payout = addCoins(player, math.floor(itemTierInfo(itemName).value * mult)) or 0
	removeTradedItem(player, { source = "inventory", index = index, itemName = itemName })

	playSound(playerRoot(player), "sell")
	toast(player, string.format("Sold %s for %d coins.", instanceTag(itemName), payout))

	s.sales = s.sales + 1
	checkGoals(player)
	pushUI(player)
end)

moveToCarryRemote.OnServerEvent:Connect(function(player, index)
	local s = state[player]
	if not s then return end
	local itemName = type(index) == "number" and s.inventory[index]
	if not itemName then return end

	if not canReceiveTradedItem(player, itemName, "carry") then
		toast(player, "Hands full — fuse or sell something first.")
		return
	end

	removeTradedItem(player, { source = "inventory", index = index, itemName = itemName })
	giveTradedItem(player, itemName, "carry")

	toast(player, string.format("%s is ready to fuse — head to your pad.", instanceTag(itemName)))
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
-- Passive income from inventory — every fusion result you're holding
-- (never raw scrap, since inventory only ever receives fusion results)
-- keeps paying out for as long as you keep it instead of selling it.
------------------------------------------------------------------

task.spawn(function()
	while true do
		task.wait(INCOME_TICK_SECONDS)

		for _, player in ipairs(Players:GetPlayers()) do
			local s = state[player]
			if s then
				local mult = valueMultiplier(player, s)
				local perSecond = 0

				for _, itemName in ipairs(s.inventory) do
					perSecond = perSecond + (itemTierInfo(itemName).value / PLACEMENT_PAYBACK_SECONDS) * mult
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
	Brainrot.Init(player, data.brainrotDiscovered)
	Rebirth.Init(player, data.rebirths)
	Companions.Init(player, data.companion)
	Leaderboard.Init(player, data.lifetimeCoins)

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

	local plot = plots[index]

	-- Rebuild the discovered lookup from the saved list.
	local discovered = {}
	for _, name in ipairs(data.discoveredList) do
		discovered[name] = true
	end

	local upgrades = data.upgrades or { luck = 1, carry = 1, magnet = 0, value = 1 }

	state[player] = {
		slots = {},
		inventory = data.inventory or {},
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
		mutationPity = 0,
	}

	refreshPad(player)
	updateWalkSpeed(player)
	refreshInventoryDisplay(player)

	-- A dedicated, invisible spawn point right on their plot, so the
	-- character appears there from frame one instead of flashing at the
	-- world origin first and getting teleported a moment later.
	if not plot.spawnPoint then
		local spawnPoint = Instance.new("SpawnLocation")
		spawnPoint.Name = "PlotSpawn"
		spawnPoint.Size = Vector3.new(6, 1, 6)
		spawnPoint.Position = plot.centre + Vector3.new(0, 3, -20)
		spawnPoint.Anchored = true
		spawnPoint.CanCollide = false
		spawnPoint.Transparency = 1
		spawnPoint.Neutral = true
		spawnPoint.Parent = plot.model
		plot.spawnPoint = spawnPoint
	end
	player.RespawnLocation = plot.spawnPoint

	player.CharacterAdded:Connect(function(character)
		character:WaitForChild("Humanoid")
		updateWalkSpeed(player)
		updateCompanionVisual(player)
		attachTradePrompt(player, character)
		task.wait(1)
		pushUI(player)
		toast(player, "Plot " .. index .. " is yours. Scrap spawns in the centre.")
	end)

	-- CharacterAutoLoads is off, so this is what actually spawns them —
	-- right at plot.spawnPoint, since RespawnLocation is already set.
	player:LoadCharacter()
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
-- Turns live state back into the plain table DataManager stores.
local function snapshot(player)
	local s = state[player]
	if not s then return nil end

	local stats = player:FindFirstChild("leaderstats")
	local coins = stats and stats:FindFirstChild("Coins")

	return {
		coins = coins and coins.Value or 0,
		discoveredList = s.discoveredList,
		goalIndex = s.goalIndex,
		bestTier = s.bestTier,
		secrets = s.secrets,
		sales = s.sales,
		inventory = s.inventory,
		brainrotDiscovered = Brainrot.Snapshot(player),
		upgrades = s.upgrades,
		lastDailyDay = s.lastDailyDay,
		dailyStreak = s.dailyStreak,
		boosts = s.boosts,
		rebirths = Rebirth.Snapshot(player),
		companion = Companions.Snapshot(player),
		lifetimeCoins = Leaderboard.Snapshot(player),
	}
end

-- Autosave. Without this, a server crash loses everything since join.
-- Also the only place the leaderboard's OrderedDataStore gets written —
-- piggybacking on this cadence instead of a separate loop means a lifetime
-- coin gain never costs a network call on its own.
task.spawn(function()
	while true do
		task.wait(120)
		for _, player in ipairs(Players:GetPlayers()) do
			local data = snapshot(player)
			if data then
				DataManager.Save(player, data)
			end
			Leaderboard.PushToStore(player)
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
	Leaderboard.PushToStore(player)

	local tradePartner = Trade.Partner(player)
	Trade.Cleanup(player)
	if tradePartner then
		toast(tradePartner, player.Name .. " left — trade cancelled.")
		pushTradeUpdate(tradePartner)
	end
	tradePrompts[player] = nil

	local s = state[player]
	if s then
		local plot = plots[s.plotIndex]
		if plot then
			plot.owner = nil
			plot.signLabel.Text = "UNCLAIMED PLOT"
			plot.padLabel.Text = "FUSION PAD"
			clearInventoryDisplay(plot)
		end
	end
	state[player] = nil
	Brainrot.Cleanup(player)
	Rebirth.Cleanup(player)
	Companions.Cleanup(player)
	Leaderboard.Cleanup(player)
	DataManager.Forget(player)

	local companionPart = companionParts[player]
	if companionPart then
		companionPart:Destroy()
		companionParts[player] = nil
	end
end)

print(string.format("[PlotManager] %d plots ready. %d combos to discover.",
	PLOT_COUNT, FusionRecipes.GetTotalDiscoveries()))
