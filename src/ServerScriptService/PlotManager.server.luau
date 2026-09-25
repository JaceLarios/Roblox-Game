local ItemNames = require(game:GetService("ReplicatedStorage"):WaitForChild("ItemNames"))
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
local ServerStorage     = game:GetService("ServerStorage")
local RunService        = game:GetService("RunService")
local PhysicsService    = game:GetService("PhysicsService")
local TweenService      = game:GetService("TweenService")
local HttpService       = game:GetService("HttpService")

local FusionEffects = require(ServerStorage:WaitForChild("FusionEffects"))
local PickupEffects = require(ServerStorage:WaitForChild("PickupEffects"))
local ScrapLabel    = require(ServerStorage:WaitForChild("ScrapLabel"))
local CoilAura      = require(ServerStorage:WaitForChild("CoilAura"))
local FusionRecipes = require(ReplicatedStorage:WaitForChild("FusionRecipes"))
local ItemVisuals   = require(ReplicatedStorage:WaitForChild("ItemVisuals"))
local ItemRarity    = require(ReplicatedStorage:WaitForChild("ItemRarity"))
local Mutations     = require(ReplicatedStorage:WaitForChild("Mutations"))
local PromoCodes    = require(ReplicatedStorage:WaitForChild("PromoCodes"))
local RaceConfig    = require(ReplicatedStorage:WaitForChild("RaceConfig"))
local RaceCrates    = require(ReplicatedStorage:WaitForChild("RaceCrates"))
local DataManager   = require(script.Parent:WaitForChild("DataManager"))
local Gamepasses = require(script.Parent:WaitForChild("GamepassService"))
local Rebirth = require(script.Parent:WaitForChild("RebirthService"))
local Leaderboard = require(script.Parent:WaitForChild("LeaderboardService"))
local PlaytimeLeaderboard = require(script.Parent:WaitForChild("PlaytimeLeaderboardService"))
local Trade = require(script.Parent:WaitForChild("TradeService"))
local RaceWars = require(script.Parent:WaitForChild("RaceService"))

-- The big screen-covering celebration popup on fuse. Its own dedicated
-- remote (not a new field on the small `GameUpdate` toast) and its own
-- standalone client script, specifically so this doesn't touch or depend
-- on GameUI/ShopUI while Codex is mid-rewrite on those — see HANDOFF.md.
local fusionCelebrationRemote = ReplicatedStorage:FindFirstChild("FusionCelebration")
if not fusionCelebrationRemote then
	fusionCelebrationRemote = Instance.new("RemoteEvent")
	fusionCelebrationRemote.Name = "FusionCelebration"
	fusionCelebrationRemote.Parent = ReplicatedStorage
end

Gamepasses.Start()

-- We position each character ourselves (their assigned plot, or wherever
-- they travel to) via RespawnLocation, so the default auto-spawn — which
-- would otherwise drop them at the world origin for a frame before our
-- code can move them — is turned off in favor of an explicit LoadCharacter
-- once we know where they belong.
Players.CharacterAutoLoads = false

-- ---------- Tuning ----------
local Layout = require(game.ReplicatedStorage:WaitForChild("JunkyardLayout"))
local BaseGate = require(game.ServerStorage:WaitForChild("BaseGate"))
local PLOT_COUNT  = Layout.PlotCount
local RING_RADIUS = Layout.PlotRadius
local PLOT_SIZE   = Layout.PlotSize

-- Eight earning pads: four down each workshop side. Saved slot order is unchanged.
local PET_PAD_COUNT = Layout.PetPadCount
local PET_PAD_SIZE = 7

-- Luck: applied when you GRAB, not when scrap spawns. The yard is shared,
-- so a per-player spawn table is impossible — but a per-player reroll at
-- pickup gives the same feeling and keeps the middle fair.
local LUCK_PER_LEVEL = 0.06   -- +6% upgrade chance per luck level above 1
local LUCK_MAX_CHANCE = 0.40  -- never more than a 40% chance

-- Upgrades. All four are PERSONAL — none of them touch the shared yard,
-- so buying them can't make the middle unfair for everyone else.
-- `start` is the level a new player begins at.
-- s.slots is a fuse STAGING area now, not a carry capacity: physical
-- carrying is one item held overhead, delivered to inventory at your base.
-- Fixed at 2, which is exactly what one fusion consumes.
local FUSE_STAGING_SLOTS = 2

-- Grabbing is a deliberate commitment now, not an instant tap: you stand
-- still for this long, in the open, before the item is yours.
local GRAB_HOLD_SECONDS = 0.5

-- Physical carrying. Exactly ONE item at a time, visibly held in the hand,
-- until you get it back to your own plot. Deliberately separate from
-- s.slots (the fuse staging area): grabbing no longer puts anything into
-- staging, it puts a real object in your hand that other players can see
-- coming and knock loose.
local CARRY_SCALE = 0.72
local CARRY_TRANSPARENCY = 0.35
-- Held ABOVE the head, not in the hand. Anchored to HumanoidRootPart
-- rather than Head on purpose: welding to the head makes the item swing
-- around with the camera every time the player looks about.
-- Gap between the carrier's raised palms and the bottom of what they are
-- holding. The height itself is measured off the character rather than
-- fixed, so it still lands right on avatars that are scaled up or down —
-- see attachCarried. CarryPose (client) is what puts the arms up there.
local CARRY_HAND_GAP = 0.15

-- Road lasers are permanent: the approach to every base is an obby you
-- jump, not a hazard somebody switches on. Invisible barriers run down
-- both sides of each road so the lasers cannot simply be walked around.
local LASER_COUNT = 4
-- Studs between neighbouring bars. Carrying loot you run at 22 studs/sec
-- or more, so an ordinary jump covers about 12 studs: at 14 apart one jump
-- clears one bar and lands with just enough room to line up the next (a
-- fourth bar, added to make the way in harder, left no room for 16). At
-- the old spacing (under 6) a jump either came down on the next bar or
-- had to clear two at once.
local LASER_SPACING = 14
local BARRIER_HEIGHT = 16
local BARRIER_HALF_WIDTH = Layout.RouteHalfWidth

-- Bat and speed coil. Everyone spawns with both, and gives up both the
-- moment they pick something up.
local BAT_COOLDOWN = 1.2
local BAT_RANGE = 12
-- Dot product against the swinger's look vector, so the bat only connects
-- with someone actually in front of them rather than anyone standing
-- within range in any direction. ~0.5 is a 120-degree cone.
local BAT_ARC_DOT = 0.5
local FLOP_SECONDS = 2.5
-- How hard a bat hit sends someone flying: studs per second away from the
-- swinger, and upward.
local BAT_KNOCK_SPEED = 85
local BAT_KNOCK_LIFT = 70
local COIL_SPEED_BONUS = 0.15
-- The Bat Strength and Speed Coil upgrades: each level past the first hits
-- 12% harder, and adds 5% to the coil's speed boost.
local BAT_POWER_PER_LEVEL = 0.12
local COIL_BONUS_PER_LEVEL = 0.05
-- MapRevamp paints this plot's guide rails at +/-11.5 from the road
-- centreline, so a 24-wide bar spans the corridor with a little overhang.
local LASER_WIDTH = 24
-- Stepping onto your own plot at all counts as getting home.
local DELIVER_RADIUS = PLOT_SIZE / 2

-- Base raids. Anything sitting on a pet pad can be stolen by another
-- player who gets to it; anything in Inventory cannot. The hold is longer
-- than a yard grab so the owner has a moment to react, and the owner can
-- shut their pads for a minute with the Lock Base button.
local STEAL_HOLD_SECONDS = 2.5
local STEAL_RANGE = 12
local LOCK_SECONDS = 60
local LOCK_COOLDOWN_SECONDS = 60
local RAID_ALARM_COOLDOWN = 6
-- Owner-only walls around every base. Everyone else can only get in or out
-- along that base's own laser road; the owner walks straight through
-- (collision groups, below), so the grass and the island gates behind each
-- base stay reachable for them.
local BASE_WALL_HEIGHT = 16
local BASE_WALL_VISIBLE_HEIGHT = 5
-- Offset from the plot centre: clear of the pads, and outside the road
-- mouth of every one of the eight plots.
local LOCK_BUTTON_OFFSET = Vector3.new(16, 0, -24)

local function isLocked(plot)
	return plot.lockedUntil ~= nil and os.clock() < plot.lockedUntil
end

-- Inventory space: 50 to start, 5 more for each of the first four Storage
-- Space upgrades, then 10 more for every one after that.
local INVENTORY_BASE = 50
local function storageSlots(level)
	local slots = INVENTORY_BASE
	for lv = 2, level do
		slots += lv <= 5 and 5 or 10
	end
	return slots
end

-- How hard a bat hit launches someone at a Bat Strength level (1 at
-- level 1), and the coil's speed boost at a Speed Coil level.
local function batPower(level)
	return 1 + (math.max(level or 1, 1) - 1) * BAT_POWER_PER_LEVEL
end
local function coilBonus(level)
	return COIL_SPEED_BONUS + (math.max(level or 1, 1) - 1) * COIL_BONUS_PER_LEVEL
end

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
		key = "value", name = "Haggler", start = 1, max = 8,
		baseCost = 1000, mult = 2.0,
		describe = function(lv) return string.format("+%d%% sell price", (lv - 1) * 15) end,
	},
	{
		key = "speed", name = "Speed Boots", start = 1, max = 8,
		baseCost = 700, mult = 1.85,
		describe = function(lv) return string.format("+%d%% move speed", (lv - 1) * 8) end,
	},
	{
		key = "storage", name = "Storage Space", start = 1, max = 10,
		baseCost = 2500, mult = 1.8,
		describe = function(lv) return string.format("%d inventory spaces", storageSlots(lv)) end,
	},
	{
		key = "bat", name = "Bat Strength", start = 1, max = 10,
		baseCost = 1500, mult = 1.7,
		describe = function(lv) return string.format("Hits launch people %d%% as far", math.floor(batPower(lv) * 100 + 0.5)) end,
	},
	{
		key = "coil", name = "Speed Coil", start = 1, max = 10,
		baseCost = 1200, mult = 1.75,
		describe = function(lv) return string.format("+%d%% speed with the coil out", math.floor(coilBonus(lv) * 100 + 0.5)) end,
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

-- Whether this player has discovered a build at least this rare. Read
-- off the discoveries themselves, so it needs nothing extra saved.
local function hasDiscoveredRarity(s, rarity)
	local floor = FusionRecipes.RarityIndex[rarity]
	for name in pairs(s.discovered) do
		local found = FusionRecipes.GetRarity(name)
		if found and FusionRecipes.RarityIndex[found] >= floor then
			return true
		end
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
	{ text = "Fuse an Epic build (V6 Engine)",    reward = 1500,  check = function(s) return hasDiscoveredRarity(s, "epic") end },
	{ text = "Discover 12 different builds",      reward = 3000,  check = function(s) return s.count >= 12 end },
	{ text = "Fuse a Mythic build (V8 Engine)",   reward = 8000,  check = function(s) return hasDiscoveredRarity(s, "mythic") end },
	{ text = "Fuse a Legendary build (Jet Engine)", reward = 15000, check = function(s) return hasDiscoveredRarity(s, "legendary") end },
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

-- The Shop's Addons tab. Addons no longer spawn in the yard, so this is
-- the only way to get one: bought for coins, straight into Inventory. Same
-- rule as upgrades — the client names an addon, the server sets the price.
local buyAddonRemote = ReplicatedStorage:FindFirstChild("BuyAddon")
if not buyAddonRemote then
	buyAddonRemote = Instance.new("RemoteEvent")
	buyAddonRemote.Name = "BuyAddon"
	buyAddonRemote.Parent = ReplicatedStorage
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

-- The Trading tab's player list: click a name instead of walking up to
-- them. Sends the target's UserId (not the Player instance, and not
-- their name — a UserId is unambiguous even if two players share a
-- display name) and resolves it server-side.
local startTradeRemote = ReplicatedStorage:FindFirstChild("StartTradeWith")
if not startTradeRemote then
	startTradeRemote = Instance.new("RemoteEvent")
	startTradeRemote.Name = "StartTradeWith"
	startTradeRemote.Parent = ReplicatedStorage
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

local placePetRemote = ReplicatedStorage:FindFirstChild("PlacePet")
if not placePetRemote then
	placePetRemote = Instance.new("RemoteEvent")
	placePetRemote.Name = "PlacePet"
	placePetRemote.Parent = ReplicatedStorage
end

local unplacePetRemote = ReplicatedStorage:FindFirstChild("UnplacePet")
if not unplacePetRemote then
	unplacePetRemote = Instance.new("RemoteEvent")
	unplacePetRemote.Name = "UnplacePet"
	unplacePetRemote.Parent = ReplicatedStorage
end

-- Takes a carried item (already grabbed, sitting on the pad waiting to be
-- fused) back off before you commit to fusing it, straight to Inventory.
local removeFromCarryRemote = ReplicatedStorage:FindFirstChild("RemoveFromCarry")
if not removeFromCarryRemote then
	removeFromCarryRemote = Instance.new("RemoteEvent")
	removeFromCarryRemote.Name = "RemoveFromCarry"
	removeFromCarryRemote.Parent = ReplicatedStorage
end

-- The Drop button on the item you are carrying overhead (CarryHud builds
-- it on your own client). Lets go of the item wherever you are.
local dropCarriedRemote = ReplicatedStorage:FindFirstChild("DropCarried")
if not dropCarriedRemote then
	dropCarriedRemote = Instance.new("RemoteEvent")
	dropCarriedRemote.Name = "DropCarried"
	dropCarriedRemote.Parent = ReplicatedStorage
end

-- The side travel menu asks for a destination key; the server decides
-- where that actually is.
local travelRemote = ReplicatedStorage:FindFirstChild("TravelTo")
if not travelRemote then
	travelRemote = Instance.new("RemoteEvent")
	travelRemote.Name = "TravelTo"
	travelRemote.Parent = ReplicatedStorage
end

-- Shop UI: promo codes and coin-purchasable pets.
local redeemCodeRemote = ReplicatedStorage:FindFirstChild("RedeemCode")
if not redeemCodeRemote then
	redeemCodeRemote = Instance.new("RemoteEvent")
	redeemCodeRemote.Name = "RedeemCode"
	redeemCodeRemote.Parent = ReplicatedStorage
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
	{ kind = "jackpot", amount = 7500, label = "JACKPOT",        sub = "coins + luck + Jet Engine" },
}
local DAILY_MAX_STREAK = #DAILY_REWARDS

-- Four fixed check-in points per session, each paid out exactly once —
-- not a repeating-forever timer. "minutes" is time played THIS session
-- (s.playMinutes resets to 0 on join); lifetime playtime for the
-- "Most Dedicated" leaderboard is tracked separately, in
-- PlaytimeLeaderboardService, and never resets.
local PLAYTIME_MILESTONES = {
	{ minutes = 5, reward = 300 },
	{ minutes = 15, reward = 500 },
	{ minutes = 30, reward = 800 },
	{ minutes = 60, reward = 1500 },
}

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
-- timed sell boost and a player's permanent Rebirth multiplier apply to
-- everything a player's builds earn, not just the moment you press Sell.
local function valueMultiplier(player, s)
	return (1 + (s.upgrades.value - 1) * 0.15) * boostMult(s, "value") * Rebirth.Multiplier(player)
end

-- Best available colored tag for an item name that might carry a mutation
-- prefix (see Mutations.luau) — mutation color takes over from rarity
-- color when present, since it's the more exciting signal in that moment.
local function instanceTag(name)
	local baseName, mutationId = Mutations.Unwrap(name)
	if mutationId then
		return Mutations.Tag(name, mutationId)
	end
	return ItemRarity.Tag(baseName, FusionRecipes.GetTier(baseName), FusionRecipes.IsSecretResult(baseName),
		FusionRecipes.GetRarity(baseName))
end

-- Tier/secret/value for any item name PlotManager could be holding —
-- always a Junkyard name, but may carry a mutation prefix. Defined early
-- since pushUI needs it for inventory stats, well before Trading (which
-- also uses it) is defined.
local function itemTierInfo(itemName)
	local baseName, mutationId = Mutations.Unwrap(itemName)
	return {
		tier = FusionRecipes.GetTier(baseName),
		rarity = FusionRecipes.GetRarity(baseName),
		isSecret = FusionRecipes.IsSecretResult(baseName),
		value = FusionRecipes.GetValue(baseName) * Mutations.ValueMultiplier(mutationId),
	}
end

-- Cars as transportation: every pet actually placed and earning (not just
-- sitting in Inventory) makes you faster, on top of the Speed Boots
-- upgrade below. Placement is capped at PET_PAD_COUNT, so this is now a
-- flat per-pad bonus instead of the old per-inventory-item one.
local BASE_WALK_SPEED = 22
local PLACED_SPEED_PER_ITEM = 2
local PLACED_SPEED_CAP = 10 -- Preserve movement balance with eight earning pads.
local SPEED_UPGRADE_PER_LEVEL = 0.08 -- +8% per level above 1

local function updateWalkSpeed(player)
	local s = state[player]
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not (s and humanoid) then return end

	local placedBonus = math.min(#s.placed * PLACED_SPEED_PER_ITEM, PLACED_SPEED_CAP)
	local speedMult = (1 + (s.upgrades.speed - 1) * SPEED_UPGRADE_PER_LEVEL) * Gamepasses.SpeedMultiplier(player)
	-- The coil is a held tool, so its bonus applies only while it is
	-- actually equipped, and never while carrying: the coil is one of the
	-- two things you give up to haul loot.
	if s.coilEquipped and not s.carrying then
		speedMult = speedMult * (1 + coilBonus(s.upgrades.coil))
	end
	humanoid.WalkSpeed = (BASE_WALK_SPEED + placedBonus) * speedMult
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

-- How many items a player's Inventory holds: their Storage Space upgrade
-- (see storageSlots) plus the +50 Inventory Space pass. Still a real
-- limit: sell, place or fuse to make room.
local function inventoryCapacity(s, player)
	return storageSlots(s and s.upgrades and s.upgrades.storage or 1) + Gamepasses.ExtraStorage(player)
end

------------------------------------------------------------------
-- Build the eight plots in a ring around the yard
------------------------------------------------------------------

local plotFolder = workspace:FindFirstChild("Plots")
if plotFolder then plotFolder:Destroy() end
plotFolder = Instance.new("Folder")
plotFolder.Name = "Plots"
plotFolder.Parent = workspace

-- One wall group and one owner group per plot. A plot's walls stop every
-- character except those in its own owner group, which is how "only the
-- owner walks through" works with no per-player scripting on the walls.
local function wallGroup(i) return "PlotWall" .. i end
local function ownerGroup(i) return "PlotOwner" .. i end
for i = 1, PLOT_COUNT do
	for _, name in ipairs({ wallGroup(i), ownerGroup(i) }) do
		if not PhysicsService:IsCollisionGroupRegistered(name) then
			PhysicsService:RegisterCollisionGroup(name)
		end
	end
	PhysicsService:CollisionGroupSetCollidable(wallGroup(i), ownerGroup(i), false)
end

for i = 1, PLOT_COUNT do
	local angle = (i - 1) / PLOT_COUNT * math.pi * 2
	local centre = Vector3.new(math.cos(angle) * RING_RADIUS, 0, math.sin(angle) * RING_RADIUS)

	local plotFrame = CFrame.lookAt(centre, Vector3.zero)
	local model = Instance.new("Model")
	model.Name = "Plot" .. i
	model.Parent = plotFolder

	local ground = makePart({
		Name = "Ground",
		Size = Vector3.new(PLOT_SIZE, 1, PLOT_SIZE),
		CFrame = plotFrame,
		Material = Enum.Material.SmoothPlastic,
		Color = Color3.fromRGB(235, 240, 245),
		Parent = model,
	})


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

	-- Eight pads along the workshop sides — the only place a pet
	-- actually earns money. Everything else in Inventory is just stored;
	-- only what's physically placed here counts toward passive income.
	-- Built here (fixed platforms + prompts), wired up for real down in
	-- "Wire up each plot's prompts" once the handler exists, same as the
	-- fusion pad itself.
	local petPads = {}
	for slot = 1, PET_PAD_COUNT do
		local xOffset = slot <= 4 and -28 or 28
		local zOffset = -24 + ((slot - 1) % 4) * 16
		local padCentre = plotFrame:PointToWorldSpace(Vector3.new(xOffset, 0, zOffset))

		local petPadPart = makePart({
			Name = "PetPad" .. slot,
			Size = Vector3.new(PET_PAD_SIZE, 1, PET_PAD_SIZE),
			Position = padCentre + Vector3.new(0, 0.5, 0),
			Material = Enum.Material.SmoothPlastic,
			Color = Color3.fromRGB(210, 210, 220),
			Parent = model,
		})
		local petPadLabel = makeLabel(petPadPart, "EMPTY PAD", 3, 150, Color3.fromRGB(150, 150, 165), 45)

		local takeOffPrompt = Instance.new("ProximityPrompt")
		takeOffPrompt.ActionText = "Take Off"
		takeOffPrompt.ObjectText = "Pet Pad"
		takeOffPrompt.HoldDuration = 0.3
		takeOffPrompt.MaxActivationDistance = 10
		takeOffPrompt.RequiresLineOfSight = false
		takeOffPrompt.Enabled = false -- only enabled once something is actually placed
		takeOffPrompt.Name = "TakeOffPrompt"
		takeOffPrompt.Parent = petPadPart

		-- The visitor's half of the same pad. Both prompts exist for
		-- everyone; BaseRaid.client hides whichever one is not yours, and
		-- the server checks ownership either way.
		local stealPrompt = Instance.new("ProximityPrompt")
		stealPrompt.Name = "StealPrompt"
		stealPrompt.ActionText = "Steal"
		stealPrompt.ObjectText = "Pet Pad"
		stealPrompt.HoldDuration = STEAL_HOLD_SECONDS
		stealPrompt.MaxActivationDistance = 10
		stealPrompt.RequiresLineOfSight = false
		stealPrompt.Enabled = false
		stealPrompt.Parent = petPadPart

		petPads[slot] = { part = petPadPart, label = petPadLabel, prompt = takeOffPrompt, stealPrompt = stealPrompt, itemPart = nil }
	end

	-- No physical display zones anymore — a fused result goes straight
	-- into the player's inventory (see Inventory below), sold or sent
	-- back to the pad from the Inventory popup instead of walking to a
	-- physical slot. The pad is now the only place a new item (grabbed
	-- scrap or a fusion result) actually enters a player's hands.
	-- Road lasers spanning this plot's own approach corridor, plus the
	-- button that arms them. Built here with the rest of the plot; the
	-- prompt and touch handlers are wired further down, once dropCarried
	-- exists for them to call.
	local radial = Vector3.new(math.cos(angle), 0, math.sin(angle))
	local side = Vector3.new(-math.sin(angle), 0, math.cos(angle))
	-- Same expression MapRevamp uses for where this route stops, so the
	-- lasers land on the painted road rather than past the end of it.
	local roadEnd = RING_RADIUS - PLOT_SIZE / 2
	local lasers = {}
	local entranceGate = BaseGate.Create(model, radial * roadEnd + Vector3.new(0, 0.5, 0),
		side, wallGroup(i), BARRIER_HALF_WIDTH * 2 + 1, 20)
	BaseGate.Update(entranceGate, false, 0, 0, false)
	-- Centred on the stretch between where the shoulder walls begin and the
	-- door, so there is as much run-up before the first bar as landing room
	-- after the last.
	local laserMid = (Layout.BarrierStart + roadEnd) / 2
	for k = 1, LASER_COUNT do
		local r = laserMid + (k - (LASER_COUNT + 1) / 2) * LASER_SPACING
		local laser = makePart({
			Name = "RoadLaser",
			Size = Vector3.new(LASER_WIDTH, 0.5, 1.2),
			Position = radial * r + Vector3.new(0, 1.7, 0),
			Material = Enum.Material.Neon,
			Color = Color3.fromRGB(255, 45, 45),
			Parent = model,
		})
		-- X along the road's side axis so the bar spans the corridor.
		laser.CFrame = CFrame.fromMatrix(laser.Position, side, Vector3.new(0, 1, 0))
		laser.CanCollide = false
		table.insert(lasers, laser)
	end

	-- Invisible walls down both shoulders, so the only way past a bar is
	-- over it. They start just past the yard and stop at the plot edge, so
	-- the yard itself and the plot stay completely open to walk around.
	-- Each shoulder runs until it actually meets the plot's edge. On the four
	-- straight roads that is exactly where the road stops; on the four
	-- diagonal ones the road stops at the plot's corner while the shoulders
	-- are still short of it, which used to leave a gap either side that
	-- stepped straight off the road onto the grass.
	local barrierStart = Layout.BarrierStart
	for _, offset in ipairs({ -BARRIER_HALF_WIDTH, BARRIER_HALF_WIDTH }) do
		local barrierEnd = roadEnd
		local barrierMid = radial * ((barrierStart + barrierEnd) / 2)
		local wall = makePart({
			Name = "RoadBarrier",
			Size = Vector3.new(1, BARRIER_HEIGHT, barrierEnd - barrierStart),
			Position = barrierMid + side * offset + Vector3.new(0, BARRIER_HEIGHT / 2, 0),
			Parent = model,
		})
		-- lookAt puts the part's Z (its length) along the road.
		wall.CFrame = CFrame.lookAt(wall.Position, wall.Position + radial)
		wall.Transparency = 1
		wall.CanCollide = true
		wall.CanQuery = false
	end

	-- Workshop walls and roof are solid for everyone; only the laser entrance
	-- uses owner-specific collision filtering.

	-- Lock Base: owner-only, shuts every pad for LOCK_SECONDS.
	local lockSpot = plotFrame:PointToWorldSpace(Vector3.new(0, 0, 35))
	makePart({
		Name = "LockPedestal",
		Size = Vector3.new(2.6, 2.6, 2.6),
		Position = lockSpot + Vector3.new(0, 1.8, 0),
		Material = Enum.Material.Metal,
		Color = Color3.fromRGB(46, 46, 54),
		Parent = model,
	})
	local lockButton = makePart({
		Name = "LockButton",
		Shape = Enum.PartType.Cylinder,
		Size = Vector3.new(0.6, 2.2, 2.2),
		CFrame = CFrame.new(lockSpot + Vector3.new(0, 3.4, 0)) * CFrame.Angles(0, 0, math.rad(90)),
		Material = Enum.Material.Neon,
		Color = Color3.fromRGB(70, 220, 110),
		Parent = model,
	})
	local lockLabel = makeLabel(lockButton, "LOCK BASE", 3, 200, Color3.fromRGB(120, 255, 150), 60)
	local lockPrompt = Instance.new("ProximityPrompt")
	lockPrompt.Name = "LockPrompt"
	lockPrompt.ActionText = "Lock Base"
	lockPrompt.ObjectText = string.format("%d seconds", LOCK_SECONDS)
	lockPrompt.HoldDuration = 0.4
	lockPrompt.MaxActivationDistance = 10
	lockPrompt.RequiresLineOfSight = false
	lockPrompt.Parent = lockButton

	-- A shield over each pad bank protects the eight slots while locked.
	local shields = {}
	for _, x in ipairs({-28, 28}) do
		table.insert(shields, makePart({
			Name = "LockShield", Size = Vector3.new(11, 12, 60),
			CFrame = plotFrame * CFrame.new(x, 6.5, 0),
			Material = Enum.Material.Neon, Color = Color3.fromRGB(90, 170, 255),
			Transparency = 1, CanCollide = false, CanQuery = false, CanTouch = false,
			CastShadow = false, CollisionGroup = wallGroup(i), Parent = model,
		}))
	end

	plots[i] = {
		model = model,
		lasers = lasers,
		lockButton = lockButton,
		lockLabel = lockLabel,
		lockPrompt = lockPrompt,
		shields = shields,
		frame = plotFrame,
		gate = entranceGate,
		lockedUntil = 0,
		lockCooldownUntil = 0,
		owner = nil,
		centre = centre,
		pad = pad,
		padLabel = padLabel,
		padPrompt = padPrompt,
		petPads = petPads,
	}
end

------------------------------------------------------------------
-- Two central boards backed by the existing all-time ranking services.
require(game.ServerStorage:WaitForChild("CentralLeaderboards")).Start(Leaderboard, PlaytimeLeaderboard)

------------------------------------------------------------------
-- Per-player helpers
------------------------------------------------------------------

local function capacity(player, s)
	-- The Bigger Truck upgrade was retired when carrying became one physical
	-- item overhead, and the +2 Carry Slots pass became +50 Inventory Space.
	return Gamepasses.Capacity(player, FUSE_STAGING_SLOTS - 1)
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
			-- What it WOULD earn once placed — not placed yet, so this is
			-- potential, not current. The client is responsible for
			-- wording that distinction; the number itself is what a
			-- player needs to decide which pet is worth placing.
			perSecond = info.value / PLACEMENT_PAYBACK_SECONDS,
		})
	end

	local placedInfo = {}
	for i, itemName in ipairs(s.placed) do
		local info = itemTierInfo(itemName)
		table.insert(placedInfo, {
			index = i,
			name = itemName,
			tier = info.tier,
			isSecret = info.isSecret,
			value = info.value,
			perSecond = info.value / PLACEMENT_PAYBACK_SECONDS,
		})
	end

	-- Race Wars crates, without what is inside: that is a surprise until
	-- the crate is opened. Seconds left rather than a timestamp, so the
	-- client counts down without trusting its own clock.
	local crateInfo = {}
	local now = os.time()
	for _, crate in ipairs(s.crates) do
		local level = RaceConfig.Levels[crate.level]
		table.insert(crateInfo, {
			id = crate.id,
			level = crate.level,
			levelName = level and level.name or "Race Wars",
			remaining = math.max(0, crate.readyAt - now),
		})
	end

	-- Real total odds, matching grabItem's own formula exactly (upgrade
	-- level, any active boost, AND the rebirth luck multiplier) — the
	-- bottom-left HUD tracker shows this, not just the raw upgrade level.
	local luckPercent = math.floor(math.min(LUCK_MAX_CHANCE,
		(s.upgrades.luck * boostMult(s, "luck") - 1) * LUCK_PER_LEVEL * Rebirth.LuckMultiplier(player)) * 100 + 0.5)

	remote:FireClient(player, {
		slots = s.slots,
		maxSlots = capacity(player, s),
		discoveredCount = s.count,
		total = FusionRecipes.GetTotalDiscoveries(),
		list = s.discoveredList,
		index = FusionRecipes.GetIndex(s.discovered),
		secretsFound = secretsFound,
		secretTotal = secretTotal,
		goalText = goal and goal.text or "All objectives complete",
		goalReward = goal and Gamepasses.Coins(player, goal.reward) or 0,
		goalNumber = math.min(s.goalIndex, #GOALS),
		goalTotal = #GOALS,
		luck = s.upgrades.luck,
		luckPercent = luckPercent,
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
			luckMultiplier = Rebirth.LuckMultiplier(player),
			nextCost = Rebirth.NextCost(player),
			nextMultiplier = Rebirth.NextMultiplier(player),
			nextLuckMultiplier = Rebirth.NextLuckMultiplier(player),
			maxed = Rebirth.IsMaxed(player),
		},
		inventory = inventoryInfo,
		inventoryCapacity = inventoryCapacity(s, player),
		crates = crateInfo,
		crateCapacity = RaceCrates.CAPACITY,
		carrying = s.carrying and s.carrying.name or nil,
		-- Where "home" is, so the client can point its RUN arrows at it
		-- without having to work out which plot belongs to this player.
		baseCentre = plots[s.plotIndex] and plots[s.plotIndex].centre or nil,
		-- Only set while carrying something stolen off another base, so the
		-- arrows can lead back out along that base's road first.
		carryFrom = s.carrying and s.carrying.fromPlot and plots[s.carrying.fromPlot]
			and plots[s.carrying.fromPlot].centre or nil,
		placed = placedInfo,
		placedCapacity = PET_PAD_COUNT,
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

-- Items ordered rarest first, for luck upgrades. Vehicles only on
-- purpose: a lucky pickup should hand you a better CAR, not silently
-- turn one into an engine.
local function rarerThan(itemName)
	local current
	for _, item in ipairs(FusionRecipes.Items) do
		if item.name == itemName then current = item end
	end
	if not current then return nil end

	local candidates = {}
	for _, item in ipairs(FusionRecipes.Items) do
		if item.weight < current.weight then
			table.insert(candidates, item.name)
		end
	end

	if #candidates == 0 then return nil end
	return candidates[math.random(1, #candidates)]
end

-- Picks a rare car for the daily reward: a Cop Cruiser, Box Truck or
-- Monster Truck.
local function rollRareItem()
	local pool = {}
	for _, item in ipairs(FusionRecipes.Items) do
		if FusionRecipes.RarityIndex[item.rarity] >= FusionRecipes.RarityIndex.rare then
			table.insert(pool, item.name)
		end
	end
	return pool[math.random(1, #pool)]
end

-- How close you have to stand to an item on the fusion pad for its Remove
-- button to show. Short on purpose: the pad's own Fuse prompt is also on
-- E, and the nearest E prompt is the one that shows, so this only wins
-- when you are standing at that item rather than at the pad.
local PAD_REMOVE_RANGE = 7
-- Takes an item off the fusion pad and back into Inventory. Assigned next
-- to the RemoveFromCarry remote further down; the pad's Remove buttons
-- call it too.
local returnSlotToInventory

local function refreshPad(player)
	local s = state[player]
	if not s then return end
	local plot = plots[s.plotIndex]
	if not plot then return end

	local function tag(itemName)
		if not itemName then return "empty" end
		return instanceTag(itemName)
	end

	-- The empty half says what it is waiting for, since the pad only ever
	-- takes one item and one addon.
	local waiting = "empty"
	if s.slots[1] and not s.slots[2] then
		waiting = FusionRecipes.IsAddon((Mutations.Unwrap(s.slots[1]))) and "needs a car" or "needs an addon"
	end
	plot.padLabel.Text = string.format(
		"FUSION PAD\n[ %s ]  +  [ %s ]",
		tag(s.slots[1]),
		s.slots[2] and tag(s.slots[2]) or waiting
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
			if mutationColor then ItemVisuals.Tint(slotPart, mutationColor) end
			local itemColor = mutationColor or ItemRarity.Color(FusionRecipes.GetTier(baseName), FusionRecipes.IsSecretResult(baseName),
				FusionRecipes.GetRarity(baseName))
			makeLabel(slotPart, itemName, 1.8, 140, itemColor, 45)

			-- Take it back off the pad: click or tap the button, or press E.
			-- BaseRaid hides it from everyone but the owner, and the owner
			-- check below is the real guard.
			local removePrompt = Instance.new("ProximityPrompt")
			removePrompt.Name = "RemovePrompt"
			removePrompt.ActionText = "Remove"
			removePrompt.ObjectText = ItemNames.Display(itemName)
			removePrompt.KeyboardKeyCode = Enum.KeyCode.E
			removePrompt.HoldDuration = 0
			removePrompt.MaxActivationDistance = PAD_REMOVE_RANGE
			removePrompt.RequiresLineOfSight = false
			removePrompt.Parent = slotPart
			local slotIndex = i
			removePrompt.Triggered:Connect(function(who)
				if who == player then
					returnSlotToInventory(player, slotIndex)
				end
			end)
			plot.slotParts[i] = slotPart
		end
	end
end

-- The five physical pads behind each plot's pad are the only place a pet
-- earns money — placing/unplacing (see the Inventory section and the
-- prompt wiring below) both funnel through here to keep a pad's platform,
-- prompt, and label in sync with whatever's actually in that slot.
local function redrawPetPad(plot, slot, itemName)
	local pad = plot.petPads[slot]
	if pad.itemPart then
		pad.itemPart:Destroy()
		pad.itemPart = nil
	end

	if not itemName then
		pad.label.Text = "EMPTY PAD"
		pad.label.TextColor3 = Color3.fromRGB(150, 150, 165)
		pad.prompt.Enabled = false
		pad.stealPrompt.Enabled = false
		return
	end

	local baseName, mutationId = Mutations.Unwrap(itemName)
	local padSurfaceY = pad.part.Position.Y + pad.part.Size.Y / 2
	local part = ItemVisuals.Create(baseName, Vector3.new(pad.part.Position.X, padSurfaceY, pad.part.Position.Z), 0.75)
	local mutationColor = Mutations.Color(mutationId)
	if mutationColor then ItemVisuals.Tint(part, mutationColor) end
	part.Parent = plot.model
	pad.itemPart = part

	local info = itemTierInfo(itemName)
	local itemColor = mutationColor or ItemRarity.Color(info.tier, info.isSecret, info.rarity)
	FusionEffects.AttachPlacedGlow(part, itemColor)
	pad.label.Text = string.format("%s\n+%.1f coins/sec", instanceTag(itemName), info.value / PLACEMENT_PAYBACK_SECONDS)
	pad.label.TextColor3 = itemColor
	pad.prompt.Enabled = true
	pad.stealPrompt.ObjectText = itemName
	pad.stealPrompt.Enabled = not isLocked(plot)
end

local function refreshPlacedPets(player)
	local s = state[player]
	if not s then return end
	local plot = plots[s.plotIndex]
	if not plot then return end

	for slot = 1, PET_PAD_COUNT do
		redrawPetPad(plot, slot, s.placed[slot])
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

local yardRay = RaycastParams.new()
yardRay.FilterType = Enum.RaycastFilterType.Exclude

-- Somewhere in the middle of the yard to put an item down: on the asphalt
-- or on top of a pile, never inside one. Falls back to bare ground.
local function yardDropPosition()
	for _ = 1, 8 do
		local x, z = math.random(-40, 40), math.random(-40, 40)
		if x * x + z * z > 49 then
			local ignore = { getScrapFolder() }
			local features = workspace:FindFirstChild("YardFeatures")
			local crane = features and features:FindFirstChild("MagnetCrane")
			if crane then table.insert(ignore, crane) end
			for _, p in ipairs(Players:GetPlayers()) do
				if p.Character then table.insert(ignore, p.Character) end
			end
			yardRay.FilterDescendantsInstances = ignore
			local hit = workspace:Raycast(Vector3.new(x, 60, z), Vector3.new(0, -80, 0), yardRay)
			if hit and hit.Normal.Y > 0.95 and hit.Position.Y < 16 then
				return Vector3.new(x, hit.Position.Y, z)
			end
		end
	end
	return Vector3.new(math.random(10, 40), 1.2, math.random(10, 40))
end

-- Anything dropped stays loose this long, counting down over its name,
-- and then it is gone for good.
local DROPPED_ITEM_SECONDS = 30
local function expireLater(part)
	ScrapLabel.Countdown(part, DROPPED_ITEM_SECONDS)
	task.delay(DROPPED_ITEM_SECONDS, function()
		if part.Parent and not part:GetAttribute("Collected") then
			part:Destroy()
		end
	end)
end

local function dropItemNearYard(itemName)
	local position = yardDropPosition()
	local baseName, mutationId = Mutations.Unwrap(itemName)
	local part = ItemVisuals.Create(baseName, position, 1)
	local mutationColor = Mutations.Color(mutationId)
	if mutationColor then ItemVisuals.Tint(part, mutationColor) end
	part:SetAttribute("ItemName", itemName)
	ScrapLabel.Attach(part, itemName)
	expireLater(part)
	part.Parent = getScrapFolder()
end

-- Where a dropped item comes to rest: the first solid thing straight below
-- where it was let go. Players, loose scrap and anything you cannot stand
-- on (laser bars, decoration) are skipped, so it lands on the floor rather
-- than hanging in mid-air.
local dropRay = RaycastParams.new()
dropRay.FilterType = Enum.RaycastFilterType.Exclude
dropRay.RespectCanCollide = true

local function floorBelow(position)
	local ignore = { getScrapFolder() }
	for _, p in ipairs(Players:GetPlayers()) do
		if p.Character then table.insert(ignore, p.Character) end
	end
	dropRay.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(position + Vector3.new(0, 1, 0), Vector3.new(0, -200, 0), dropRay)
	return hit and hit.Position.Y or 1.2
end

-- Puts an item back into the world as an ordinary grabbable, falling from
-- where it was let go to the floor below it, and wearing the same label
-- as everything else loose in the yard, with DROPPED_ITEM_SECONDS to go.
-- Parenting into the scrap folder is all a Grab prompt needs: its
-- ChildAdded hook adds one.
local function layDownItem(itemName, fromPosition, dropper)
	local floorY = floorBelow(fromPosition)
	local baseName, mutationId = Mutations.Unwrap(itemName)
	local part = ItemVisuals.Create(baseName, Vector3.new(fromPosition.X, floorY, fromPosition.Z), 1)
	local mutationColor = Mutations.Color(mutationId)
	if mutationColor then ItemVisuals.Tint(part, mutationColor) end
	part:SetAttribute("ItemName", itemName)
	if dropper then
		part:SetAttribute("DroppedBy", dropper.UserId)
	end
	ScrapLabel.Attach(part, itemName)
	expireLater(part)

	-- Start it where it was and let it fall, eased like gravity, for as
	-- long as a real fall from that height would take.
	local rest = part.CFrame
	local lift = fromPosition.Y - rest.Position.Y
	part.Parent = getScrapFolder()
	if lift > 0.3 then
		part.CFrame = rest + Vector3.new(0, lift, 0)
		local seconds = math.clamp(math.sqrt(2 * lift / workspace.Gravity), 0.12, 0.7)
		TweenService:Create(part, TweenInfo.new(seconds, Enum.EasingStyle.Quad, Enum.EasingDirection.In),
			{ CFrame = rest }):Play()
	end
	return part
end

------------------------------------------------------------------
-- Fusion
------------------------------------------------------------------

-- Selling and sending an item back to carry both live down in the
-- Inventory section below, next to the remotes that trigger them —
-- there's no more physical placement step for a fusion result to go
-- through here.

-- Junkyard fusing is one item plus one addon and nothing else: no item
-- with item, no addon with addon, and a fused build only takes an addon
-- better than the one it has. Returns why a pair is not allowed, or nil
-- when it is.
local function fusionPairProblem(a, b)
	return FusionRecipes.PairProblem((Mutations.Unwrap(a)), (Mutations.Unwrap(b)))
end

local function attemptFusion(player)
	local s = state[player]
	if not s then return end

	local plot = plots[s.plotIndex]
	if not plot then return end

	local a, b = s.slots[1], s.slots[2]
	if not (a and b) then
		toast(player, "You need an item and an addon to fuse.")
		return
	end

	-- An item sent back from Inventory can still carry its mutation prefix
	-- — recipe lookups need the bare name, or a "[Shiny] Trail Blazer"
	-- would never be found in the book. The ingredient's own mutation is
	-- dealt with separately, below the result's roll.
	local baseA = Mutations.Unwrap(a)
	local baseB = Mutations.Unwrap(b)

	-- Nothing is consumed unless the pair actually makes something.
	local result, info = FusionRecipes.Fuse(baseA, baseB)
	if not result then
		toast(player, info)
		playSound(plot.pad, "fail")
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

	-- Mutation rolls independently of rarity — an Uncommon Rusty Splice
	-- and a Legendary Scrapyard God are equally eligible. Discovery/goal
	-- bookkeeping below always uses the bare `result` name; only the
	-- placed/displayed instance carries the mutation.
	local mutationId = Mutations.Roll(s.upgrades.luck, s.mutationPity)
	s.mutationPity = mutationId and 0 or (s.mutationPity or 0) + 1
	-- A mutated ingredient carries its mutation through: fuse a Golden car
	-- and the result stays Golden unless its own roll beat that. This used
	-- to be dropped on purpose, but with the Mutation Frenzy putting
	-- mutated scrap on the yard floor, dropping it made those finds
	-- worthless the moment they were fused.
	for _, ingredient in ipairs({ a, b }) do
		local _, inherited = Mutations.Unwrap(ingredient)
		if inherited and Mutations.ValueMultiplier(inherited) > Mutations.ValueMultiplier(mutationId) then
			mutationId = inherited
		end
	end
	local instanceName = Mutations.Wrap(result, mutationId)
	local instanceValue = math.floor(info.value * Mutations.ValueMultiplier(mutationId))
	local mutationColor = Mutations.Color(mutationId)

	local resultTag = instanceTag(instanceName)
	local aTag = instanceTag(a)
	local bTag = instanceTag(b)

	-- The "how much money it'll make you" half of the fusion pop-up — a
	-- rate, not the flat sell value, since a fused item only ever earns
	-- once actually placed on a pad (see PLACEMENT_PAYBACK_SECONDS above).
	local rarityName = ItemRarity.Name(info.tier, false, info.rarity)
	local rateLine = string.format("%s — +%.1f coins/sec if placed",
		rarityName, instanceValue / PLACEMENT_PAYBACK_SECONDS)
	local isNewDiscovery = not s.discovered[result]

	if isNewDiscovery then
		s.discovered[result] = true
		s.count = s.count + 1
		table.insert(s.discoveredList, result)
		if info.tier > s.bestTier then s.bestTier = info.tier end
		toast(player, string.format("NEW DISCOVERY\n%s\n%s", resultTag, rateLine), true)
		print(string.format("[Fusion] %s discovered %s (%d/%d)",
			player.Name, result, s.count, FusionRecipes.GetTotalDiscoveries()))
	elseif info.upgradedFrom then
		local fromTag = FusionRecipes.IsAddon(baseA) and bTag or aTag
		toast(player, string.format("%s upgraded to %s\n%s", fromTag, resultTag, rateLine), true)
	else
		toast(player, string.format("%s + %s = %s\n%s", aTag, bTag, resultTag, rateLine), true)
	end

	if mutationId then
		toast(player, string.format("MUTATION!\n%s", resultTag), true)
	end

	-- The big, mostly-screen-covering celebration popup — additive to the
	-- small toasts above, not a replacement for them.
	do
		local badges = {}
		if isNewDiscovery then table.insert(badges, "NEW DISCOVERY") end
		if info.upgradedFrom then table.insert(badges, "UPGRADE") end
		if mutationId then table.insert(badges, "MUTATION") end
		local headerText = #badges > 0 and table.concat(badges, "   •   ") or "FUSION COMPLETE"

		fusionCelebrationRemote:FireClient(player, {
			area = "junkyard",
			headerText = headerText,
			aTag = aTag,
			bTag = bTag,
			resultTag = resultTag,
			rarityName = rarityName,
			color = mutationColor or ItemRarity.Color(info.tier, false, info.rarity),
			rateLine = rateLine,
		})
	end

	FusionEffects.FusionShimmer(plot.pad)

	-- Straight into inventory — the pad is the only place a new item
	-- enters a player's hands now. Fusing always nets -1 slot overall
	-- (2 ingredients consumed, 1 result produced), so this can only ever
	-- fail to fit if the inventory was already completely full before
	-- this fusion even started; auto-sell instead of losing it.
	if #s.inventory < inventoryCapacity(s, player) then
		table.insert(s.inventory, instanceName)
	else
		local mult = valueMultiplier(player, s)
		local payout = addCoins(player, math.floor(instanceValue * mult)) or 0
		toast(player, string.format("Inventory's full — %s auto-sold for %d coins instead.", resultTag, payout))
	end
	updateWalkSpeed(player)

	local big = FusionRecipes.RarityIndex[info.rarity] >= FusionRecipes.RarityIndex.mythic
	playSound(plot.pad, (mutationId or big) and "big" or "fuse")
	checkGoals(player)
	pushUI(player)
end

------------------------------------------------------------------
-- Grabbing scrap (used by both the E prompt and the Auto-Collect gamepass)
------------------------------------------------------------------

-- Welds a visible, semi-transparent copy of the item above the player's
-- head and tags it with its name, so it reads as loot being hauled and is
-- obvious from a distance to anyone hunting them. Massless + CanCollide
-- off so carrying never shoves the character around or snags on geometry.
local function attachCarried(player, itemName)
	local char = player.Character
	if not char then return nil end
	local anchor = char:FindFirstChild("HumanoidRootPart")
	if not anchor then return nil end

	local baseName = Mutations.Unwrap(itemName)
	local held = ItemVisuals.Create(baseName, anchor.Position, CARRY_SCALE)
	held.Name = "CarriedItem"
	held.Anchored = false
	held.CanCollide = false
	held.Massless = true
	ItemVisuals.SetTransparency(held, CARRY_TRANSPARENCY)

	-- Sit it ON the raised hands instead of at a fixed height, which is
	-- what made it look like it was floating there on its own. The top of
	-- the head is within a couple of tenths of where CarryPose puts the
	-- palms, and unlike the hands it can be measured right now — the pose
	-- is client-side and has not blended in yet at this point. Reading it
	-- off the character also means it tracks avatar scaling for free.
	local head = char:FindFirstChild("Head")
	local handHeight = 2.15
	if head then
		handHeight = (head.Position.Y - anchor.Position.Y) + head.Size.Y * 0.5 + CARRY_HAND_GAP
	end
	held.CFrame = anchor.CFrame * CFrame.new(0, handHeight + held.Size.Y * 0.5, 0)
	held.Parent = char

	makeLabel(held, instanceTag(itemName), 2.4, 260, Color3.fromRGB(255, 255, 255), 120)

	-- WeldConstraint snapshots the current relative transform, so the part
	-- has to be positioned and parented BEFORE the weld is made.
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = anchor
	weld.Part1 = held
	weld.Parent = held

	return held
end

local function clearCarriedVisual(s)
	if s.carrying and s.carrying.model then
		s.carrying.model:Destroy()
	end
end

-- Puts the carried item back into the world as an ordinary grabbable, so
-- whoever gets there first can take it. Parenting into the scrap folder is
-- all that is needed: its ChildAdded hook attaches the Grab prompt.
-- A stolen item whose thief got stopped goes back to its owner: onto a
-- free pad if there is one, else into their Inventory. False when the
-- owner has left or has nowhere to put it, and the caller drops it instead.
local function returnStolen(victim, itemName, thief)
	local vs = state[victim]
	if not vs or not victim.Parent then return false end
	if #vs.placed < PET_PAD_COUNT then
		table.insert(vs.placed, itemName)
		refreshPlacedPets(victim)
	elseif #vs.inventory < inventoryCapacity(vs, victim) then
		table.insert(vs.inventory, itemName)
	else
		return false
	end
	updateWalkSpeed(victim)
	toast(victim, string.format("%s got stopped — your %s is back home!", thief.Name, instanceTag(itemName)), true)
	pushUI(victim)
	return true
end

local function dropCarried(player, reason)
	local s = state[player]
	if not s or not s.carrying then return false end

	local itemName = s.carrying.name
	local victim = s.carrying.stolenFrom
	local root = playerRoot(player)
	-- Let go from where the item actually was, over the player's head, so
	-- it visibly falls rather than appearing on the floor.
	local held = s.carrying.model
	local origin = (held and held.Parent and held.Position)
		or (root and root.Position)
		or Vector3.new(0, 6, 0)

	clearCarriedVisual(s)
	s.carrying = nil

	-- Stopped mid-raid: it goes home to whoever it was taken from, not onto
	-- the floor for a third player to scoop up.
	if victim and returnStolen(victim, itemName, player) then
		toast(player, (reason and (reason .. " ") or "") .. "It went back to its owner.")
		pushUI(player)
		return true
	end

	layDownItem(itemName, origin, player)

	if reason then
		toast(player, reason)
	end
	pushUI(player)
	return true
end

dropCarriedRemote.OnServerEvent:Connect(function(player)
	local s = state[player]
	if not (s and s.carrying) then return end
	dropCarried(player)
end)

local function deliverCarried(player)
	local s = state[player]
	if not s or not s.carrying then return false end

	if #s.inventory >= inventoryCapacity(s, player) then
		-- Deliberately does NOT drop it: you keep hold of it and get told
		-- why, rather than having it silently fall on your own doorstep.
		toast(player, "Inventory full — sell or fuse something first.")
		return false
	end

	local itemName = s.carrying.name
	local victim = s.carrying.stolenFrom
	clearCarriedVisual(s)
	s.carrying = nil

	table.insert(s.inventory, itemName)
	playSound(playerRoot(player), "big")
	toast(player, string.format("Delivered %s to your base.", instanceTag(itemName)), true)
	if victim and victim.Parent then
		toast(victim, string.format("%s got away with your %s!", player.Name, instanceTag(itemName)), true)
		broadcast(string.format("%s got away with %s from %s's base!", player.Name, instanceTag(itemName), victim.Name))
	end
	pushUI(player)
	return true
end

-- Everything that happens the moment someone starts hauling something,
-- whether it came off the yard floor or off another player's pad. `extra`
-- is merged into the carry record (a stolen item notes who it belongs to).
local function beginCarry(player, itemName, extra)
	local s = state[player]
	if not s then return false end
	local held = attachCarried(player, itemName)
	if not held then return false end
	s.carrying = { name = itemName, model = held }
	if extra then
		for key, value in pairs(extra) do
			s.carrying[key] = value
		end
	end

	-- Picking something up costs you the bat and the coil. CarryHud hides
	-- the hotbar client-side; this is the half that actually enforces it.
	local carrierHumanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if carrierHumanoid then carrierHumanoid:UnequipTools() end
	s.coilEquipped = false
	updateWalkSpeed(player)

	playSound(playerRoot(player), "pickup")
	return true
end

local function grabItem(player, part)
	local s = state[player]
	if not s then return false end
	if not part or not part.Parent then return false end
	-- Already on its way to someone: it stays in the yard for the length
	-- of the pickup flight, where Auto-Collect could otherwise take it too.
	if part:GetAttribute("Collected") then return false end
	-- One item at a time, and it goes into your hand rather than into
	-- staging. Staging is only fed from the Inventory panel now.
	if s.carrying then return false end

	local grabbed = part:GetAttribute("ItemName") or part.Name

	-- Silent — no popup on a lucky upgrade anymore (see the "remove pickup
	-- popups" note by grabItem's own header comment above); the upgrade
	-- itself still happens, you just notice by looking at what you're
	-- carrying rather than a toast interrupting you.
	local chance = math.min(LUCK_MAX_CHANCE, (s.upgrades.luck * boostMult(s, "luck") - 1) * LUCK_PER_LEVEL * Rebirth.LuckMultiplier(player))
	if math.random() < chance then
		local upgraded = rarerThan(grabbed)
		if upgraded then
			grabbed = upgraded
		end
	end

	if not beginCarry(player, grabbed) then return false end

	-- Taken: the conveyor lets go of it (ScrapSpawner), so the pickup
	-- flight is not dragged back onto the belt.
	part:SetAttribute("Collected", true)
	local root = playerRoot(player)
	PickupEffects.Play(part, root and root.Position or part.Position)

	-- Server-wide callout: carrying something is public information, so
	-- everyone gets a chance to go and take it off you.
	broadcast(string.format("%s is carrying %s — run them down before they get home!",
		player.Name, instanceTag(grabbed)))

	-- No refreshPad here any more: grabbing feeds the hand, not the fuse
	-- staging slots the pad renders, so there is nothing on it to redraw.
	pushUI(player)
	return true
end

local function attachPickup(part)
	if not part:IsA("BasePart") then return end
	if part:FindFirstChildOfClass("ProximityPrompt") then return end

	local itemName = part:GetAttribute("ItemName") or part.Name

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Grab"
	prompt.ObjectText = ItemNames.Display(itemName)
	prompt.HoldDuration = GRAB_HOLD_SECONDS
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = part

	prompt.Triggered:Connect(function(player)
		if not grabItem(player, part) then
			toast(player, "You can only carry one item — get that one home first.")
		end
	end)
end

local scrapFolder = getScrapFolder()
for _, child in ipairs(scrapFolder:GetChildren()) do
	attachPickup(child)
end
scrapFolder.ChildAdded:Connect(attachPickup)

------------------------------------------------------------------
-- Bat and speed coil. Everyone gets both on spawn. They are the two
-- things you give up the moment you pick something up, so every entry
-- point checks s.carrying: the client hiding the hotbar is presentation,
-- these guards are the rule.
------------------------------------------------------------------

local batReadyAt = {}

-- The victim's own client moves their character, so the launch itself is
-- applied there (Knockback.client); the server decides who gets hit and
-- which way.
local knockbackRemote = ReplicatedStorage:FindFirstChild("Knockback")
if not knockbackRemote then
	knockbackRemote = Instance.new("RemoteEvent")
	knockbackRemote.Name = "Knockback"
	knockbackRemote.Parent = ReplicatedStorage
end

-- Tells everyone else to play a swing on this character (BatSwing.client
-- animates it; the swinger's own client already has).
local batSwingRemote = ReplicatedStorage:FindFirstChild("BatSwing")
if not batSwingRemote then
	batSwingRemote = Instance.new("RemoteEvent")
	batSwingRemote.Name = "BatSwing"
	batSwingRemote.Parent = ReplicatedStorage
end

local function flopPlayer(target, seconds)
	local char = target.Character
	local humanoid = char and char:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then return end
	-- PlatformStand rather than breaking joints: it reads as a flop, it
	-- reverses cleanly, and it cannot leave somebody permanently wrecked
	-- the way a real ragdoll can when the reset is missed.
	humanoid.PlatformStand = true
	task.delay(seconds, function()
		if humanoid.Parent and humanoid.Health > 0 then
			humanoid.PlatformStand = false
		end
	end)
end

local function swingBat(player)
	local s = state[player]
	if not s then return end
	if s.carrying then
		toast(player, "You cannot swing while carrying something.")
		return
	end

	local now = os.clock()
	if now < (batReadyAt[player] or 0) then return end
	batReadyAt[player] = now + BAT_COOLDOWN

	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= player then
			batSwingRemote:FireClient(other, player.Character)
		end
	end

	local root = playerRoot(player)
	if not root then return end
	local forward = root.CFrame.LookVector

	for _, other in ipairs(Players:GetPlayers()) do
		if other ~= player then
			local otherRoot = playerRoot(other)
			if otherRoot then
				local offset = otherRoot.Position - root.Position
				local distance = offset.Magnitude
				if distance > 0.1 and distance <= BAT_RANGE and forward:Dot(offset.Unit) >= BAT_ARC_DOT then
					-- dropCarried returns false when they had nothing, which
					-- is the difference between a steal and just a knockdown.
					local knockedLoose = dropCarried(other, "You got whacked — you dropped it!")
					flopPlayer(other, FLOP_SECONDS)
					local away = Vector3.new(offset.X, 0, offset.Z)
					away = away.Magnitude > 0.1 and away.Unit or Vector3.new(forward.X, 0, forward.Z).Unit
					local power = batPower(s.upgrades.bat)
					knockbackRemote:FireClient(other, (away * BAT_KNOCK_SPEED + Vector3.new(0, BAT_KNOCK_LIFT, 0)) * power)
					playSound(otherRoot, "big")
					toast(player, knockedLoose
						and string.format("You knocked it out of %s!", other.Name)
						or string.format("You flattened %s.", other.Name))
				end
			end
		end
	end
end

local function unequipIfCarrying(player)
	local s = state[player]
	if not (s and s.carrying) then return false end
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then humanoid:UnequipTools() end
	return true
end

local function giveTools(player)
	local backpack = player:FindFirstChildOfClass("Backpack")
	if not backpack then return end

	-- Backpack contents survive nothing across a respawn, but clear any
	-- stragglers so a player can never end up with two bats.
	for _, existing in ipairs(backpack:GetChildren()) do
		if existing.Name == "Bat" or existing.Name == "Speed Coil" then
			existing:Destroy()
		end
	end

	local bat = Instance.new("Tool")
	bat.Name = "Bat"
	bat.CanBeDropped = false
	bat.ToolTip = "Whack someone to send them flying and knock loose whatever they are carrying"
	-- A real bat model (ServerStorage.BatModel, a MeshPart standing upright,
	-- barrel up) when there is one, else a plain wooden stick.
	local model = ServerStorage:FindFirstChild("BatModel")
	local batHandle
	if model then
		batHandle = model:Clone()
		batHandle.Anchored = false
	else
		batHandle = Instance.new("Part")
		batHandle.Size = Vector3.new(0.7, 4.4, 0.7)
		batHandle.Color = Color3.fromRGB(156, 108, 62)
		batHandle.Material = Enum.Material.Wood
	end
	batHandle.Name = "Handle"
	batHandle.CanCollide = false
	batHandle.Massless = true
	batHandle.Parent = bat
	-- Held near the knob, barrel up.
	bat.Grip = CFrame.new(0, -batHandle.Size.Y * 0.32, 0)
	bat.Activated:Connect(function() swingBat(player) end)
	bat.Equipped:Connect(function() unequipIfCarrying(player) end)
	bat.Parent = backpack

	local coil = Instance.new("Tool")
	coil.Name = "Speed Coil"
	coil.CanBeDropped = false
	local owner = state[player]
	coil.ToolTip = string.format("+%d%% move speed while held",
		math.floor(coilBonus(owner and owner.upgrades.coil) * 100 + 0.5))
	local coilHandle = Instance.new("Part")
	coilHandle.Name = "Handle"
	coilHandle.Size = Vector3.new(1.3, 1.3, 2.4)
	coilHandle.Parent = coil
	-- The real Roblox Speed Coil, not a stand-in cylinder. Mesh, texture,
	-- handle size and scale all lifted off the classic coil model so it
	-- reads as the coil players already recognise.
	local coilMesh = Instance.new("SpecialMesh")
	coilMesh.MeshType = Enum.MeshType.FileMesh
	coilMesh.MeshId = "rbxassetid://16606212"
	coilMesh.TextureId = "rbxassetid://99170547"
	coilMesh.Scale = Vector3.new(0.7, 0.7, 0.7)
	coilMesh.Parent = coilHandle
	coil.Equipped:Connect(function()
		if unequipIfCarrying(player) then return end
		local s = state[player]
		if s then s.coilEquipped = true end
		updateWalkSpeed(player)
		CoilAura.Attach(player.Character)
	end)
	coil.Unequipped:Connect(function()
		local s = state[player]
		if s then s.coilEquipped = false end
		updateWalkSpeed(player)
		CoilAura.Detach(player.Character)
	end)
	coil.Parent = backpack
end

------------------------------------------------------------------
-- Road lasers: always live. Touching one drops whatever you were
-- carrying and kills you, so the run home is a short obby you jump
-- rather than a straight sprint.
------------------------------------------------------------------

for _, plot in ipairs(plots) do
	for _, laser in ipairs(plot.lasers) do
		laser.Touched:Connect(function(hit)
			local char = hit.Parent
			local humanoid = char and char:FindFirstChildOfClass("Humanoid")
			if not humanoid or humanoid.Health <= 0 then return end
			local player = Players:GetPlayerFromCharacter(char)
			if not player then return end
			-- Drop first, then kill: dropCarried reads the character's
			-- position to decide where the item lands, and a dead
			-- character's root has already started falling over.
			dropCarried(player, "You hit a laser — you dropped it!")
			humanoid.Health = 0
		end)
	end
end

-- Getting home is checked by distance rather than a Touched connection on
-- the plot ground: Touched fires constantly for a character standing still
-- and would need its own debounce, while this only looks at the handful of
-- players actually carrying something.
task.spawn(function()
	while true do
		task.wait(0.25)
		for player, s in pairs(state) do
			if s.carrying then
				local plot = plots[s.plotIndex]
				local root = playerRoot(player)
				if plot and root and (root.Position - plot.centre).Magnitude <= DELIVER_RADIUS then
					deliverCarried(player)
				end
			end
		end
	end
end)

------------------------------------------------------------------
-- Base raids: stealing off pet pads, and the Lock Base button
------------------------------------------------------------------

local lastAlarm = {}   -- [plotIndex] = os.clock() of the owner's last "someone is in your base" warning

-- Shield, button colour, label and every steal prompt, from the lock timers.
local function refreshLock(plot)
	local now = os.clock()
	local locked = now < plot.lockedUntil
	for _, shield in ipairs(plot.shields) do
		shield.Transparency = locked and 0.90 or 1
		shield.CanCollide = locked
	end
	plot.model:SetAttribute("Locked", locked)
	BaseGate.Update(plot.gate, locked, plot.lockedUntil - now, plot.lockCooldownUntil - now, plot.owner and plot.owner.Name)
	if locked then
		plot.lockLabel.Text = string.format("LOCKED  %ds", math.ceil(plot.lockedUntil - now))
		plot.lockLabel.TextColor3 = Color3.fromRGB(120, 200, 255)
		plot.lockButton.Color = Color3.fromRGB(80, 170, 255)
	elseif now < plot.lockCooldownUntil then
		plot.lockLabel.Text = string.format("RECHARGING  %ds", math.ceil(plot.lockCooldownUntil - now))
		plot.lockLabel.TextColor3 = Color3.fromRGB(255, 190, 90)
		plot.lockButton.Color = Color3.fromRGB(255, 150, 40)
	else
		plot.lockLabel.Text = "LOCK BASE"
		plot.lockLabel.TextColor3 = Color3.fromRGB(120, 255, 150)
		plot.lockButton.Color = Color3.fromRGB(70, 220, 110)
	end
	local owner = plot.owner and state[plot.owner]
	for slot, pad in ipairs(plot.petPads) do
		pad.stealPrompt.Enabled = (not locked) and owner ~= nil and owner.placed[slot] ~= nil
	end
end

local function stealFromPad(thief, plotIndex, slot)
	local plot = plots[plotIndex]
	local victim = plot and plot.owner
	local ts = state[thief]
	if not (plot and victim and ts) or victim == thief then return end
	if isLocked(plot) then
		toast(thief, "That base is locked — wait for the shield to drop.")
		return
	end
	if ts.carrying then
		toast(thief, "You can only carry one item — get that one home first.")
		return
	end

	local vs = state[victim]
	local itemName = vs and vs.placed[slot]
	if not itemName then return end

	local char = thief.Character
	local humanoid = char and char:FindFirstChildOfClass("Humanoid")
	local root = playerRoot(thief)
	if not (humanoid and root) or humanoid.Health <= 0 then return end
	-- Getting flopped by the owner's bat mid-hold spoils the steal.
	if humanoid.PlatformStand then return end
	if (root.Position - plot.petPads[slot].part.Position).Magnitude > STEAL_RANGE then return end

	table.remove(vs.placed, slot)
	refreshPlacedPets(victim)
	updateWalkSpeed(victim)
	pushUI(victim)

	if not beginCarry(thief, itemName, { stolenFrom = victim, fromPlot = plotIndex }) then
		-- Could not attach it to the thief at all: put it straight back.
		table.insert(vs.placed, slot, itemName)
		refreshPlacedPets(victim)
		updateWalkSpeed(victim)
		pushUI(victim)
		return
	end

	playSound(plot.pad, "big")
	toast(victim, string.format("%s STOLE your %s — stop them before they get home!", thief.Name, instanceTag(itemName)), true)
	broadcast(string.format("%s stole %s from %s's base — stop them before they get home!",
		thief.Name, instanceTag(itemName), victim.Name))
	pushUI(thief)
end

for plotIndex, plot in ipairs(plots) do
	for slot, pad in ipairs(plot.petPads) do
		-- The owner hears about it the moment someone starts the hold, not
		-- only once the steal has already worked.
		pad.stealPrompt.PromptButtonHoldBegan:Connect(function(thief)
			local victim = plot.owner
			if not victim or victim == thief then return end
			local now = os.clock()
			if now - (lastAlarm[plotIndex] or 0) < RAID_ALARM_COOLDOWN then return end
			lastAlarm[plotIndex] = now
			toast(victim, string.format("%s is stealing from your base!", thief.Name), true)
			playSound(plot.pad, "fail")
		end)
		pad.stealPrompt.Triggered:Connect(function(thief)
			stealFromPad(thief, plotIndex, slot)
		end)
	end

	plot.lockPrompt.Triggered:Connect(function(player)
		local now = os.clock()
		local ok, message = BaseGate.TryActivate(plot, player, now, LOCK_SECONDS, LOCK_COOLDOWN_SECONDS)
		if not ok then toast(player, message) return end
		refreshLock(plot)
		playSound(plot.pad, "fuse")
		toast(player, string.format("Base locked for %d seconds — visitors blocked, owner access stays open.", LOCK_SECONDS), true)
	end)
end

-- Counts the lock labels down and drops each shield as it expires. Only
-- touches plots with a lock or cooldown still running (plus one tick past
-- the end, to flip the label back to LOCK BASE).
task.spawn(function()
	while true do
		task.wait(1)
		local now = os.clock()
		for _, plot in ipairs(plots) do
			if plot.lockCooldownUntil > now - 1 then
				refreshLock(plot)
			end
		end
	end
end)

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

	if key == "speed" or key == "coil" then
		updateWalkSpeed(player) -- feel it immediately, not on the next fuse/place
	end
	if key == "coil" then
		local coil = player.Character and player.Character:FindFirstChild("Speed Coil")
			or player:FindFirstChildOfClass("Backpack") and player:FindFirstChildOfClass("Backpack"):FindFirstChild("Speed Coil")
		if coil then
			coil.ToolTip = string.format("+%d%% move speed while held", math.floor(coilBonus(s.upgrades.coil) * 100 + 0.5))
		end
	end

	playSound(playerRoot(player), "big")
	toast(player, string.format("%s → Level %d\n%s", def.name, s.upgrades[key], def.describe(s.upgrades[key])), true)
	pushUI(player)
end)

-- Every answer also goes straight back to the buyer's Addons tab
-- (ShopAddons shows it on the button), because a toast is drawn underneath
-- the open Shop and would never be seen.
buyAddonRemote.OnServerEvent:Connect(function(player, addonName)
	local s = state[player]
	if not s or type(addonName) ~= "string" then return end
	local price = FusionRecipes.AddonPrice(addonName)
	if not price then return end

	if #s.inventory >= inventoryCapacity(s, player) then
		toast(player, "Inventory full — sell or fuse something first.")
		buyAddonRemote:FireClient(player, addonName, "full")
		return
	end

	local stats = player:FindFirstChild("leaderstats")
	local coins = stats and stats:FindFirstChild("Coins")
	if not coins then return end
	if coins.Value < price then
		toast(player, string.format("Not enough coins. Need %d.", price))
		buyAddonRemote:FireClient(player, addonName, "coins")
		return
	end

	coins.Value = coins.Value - price
	table.insert(s.inventory, addonName)
	playSound(playerRoot(player), "big")
	toast(player, string.format("Bought %s — it's in your Inventory.", instanceTag(addonName)), true)
	buyAddonRemote:FireClient(player, addonName, "bought")
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
	s.upgrades = { luck = 1, carry = 1, value = 1, speed = 1, storage = 1, bat = 1, coil = 1 }
	s.inventory = {}
	s.placed = {}
	updateWalkSpeed(player)
	refreshPlacedPets(player)
	Rebirth.Increment(player)

	local level = Rebirth.Get(player)
	local mult = Rebirth.Multiplier(player)
	playSound(playerRoot(player), "big")
	toast(player, string.format("REBIRTH %d\nPermanent x%.2f coin multiplier", level, mult), true)
	broadcast(string.format("%s reached Rebirth %d!", player.Name, level))
	pushUI(player)
end)

------------------------------------------------------------------
-- Race Wars, and the travel menu's teleports. RaceService runs the
-- races; this is the part that touches player data: which cars you own,
-- and the crate each cleared level wins.
------------------------------------------------------------------

local function sendHome(player)
	local s = state[player]
	local plot = s and plots[s.plotIndex]
	local character = player.Character
	if plot and character then
		RaceWars.Leave(player)
		character:PivotTo(plot.frame * CFrame.new(0, 5, -20))
	end
end

-- Luck for a crate roll: 1 plus the same chance the luck upgrade gives a
-- grab (see grabItem), so everything that raises your luck helps here.
local function crateLuck(player, s)
	return 1 + math.min(LUCK_MAX_CHANCE,
		(s.upgrades.luck * boostMult(s, "luck") - 1) * LUCK_PER_LEVEL * Rebirth.LuckMultiplier(player))
end

-- A crate for clearing `level`, rolled now and timed by what it holds.
-- Returns whether one was given (not when the crate shelf is full).
local function awardCrate(player, level)
	local s = state[player]
	if not s then return false end
	if #s.crates >= RaceCrates.CAPACITY then
		toast(player, "Your crate shelf is full — open some crates to win more.")
		return false
	end
	local item, rarity = RaceCrates.Roll(level, crateLuck(player, s))
	table.insert(s.crates, {
		id = HttpService:GenerateGUID(false),
		level = level,
		item = item,
		readyAt = os.time() + (RaceCrates.OpenSeconds[rarity] or 60),
	})
	playSound(playerRoot(player), "big")
	pushUI(player)
	return true
end

local function ownsItem(s, itemName)
	for _, name in ipairs(s.inventory) do
		if name == itemName then return true end
	end
	for _, name in ipairs(s.placed) do
		if name == itemName then return true end
	end
	return false
end

RaceWars.Configure({
	cars = function(player)
		local s = state[player]
		local names = {}
		if s then
			for _, name in ipairs(s.inventory) do table.insert(names, name) end
			for _, name in ipairs(s.placed) do table.insert(names, name) end
		end
		return names
	end,
	owns = function(player, itemName)
		local s = state[player]
		return s ~= nil and ownsItem(s, itemName)
	end,
	canRace = function(player)
		local s = state[player]
		if not s then return false, "Still loading — try again in a moment." end
		if s.carrying then return false, "Take what you're carrying home first." end
		return true
	end,
	levelCleared = awardCrate,
	toast = toast,
	broadcast = broadcast,
	sendHome = sendHome,
})

local openCrateRemote = ReplicatedStorage:FindFirstChild("OpenCrate")
if not openCrateRemote then
	openCrateRemote = Instance.new("RemoteEvent")
	openCrateRemote.Name = "OpenCrate"
	openCrateRemote.Parent = ReplicatedStorage
end

-- Opens a crate whose timer has run out, straight into Inventory. The
-- answer goes back to the Crates tab too (RaceCrates.client shows it on
-- the crate), since a toast can be hidden behind the open Inventory.
openCrateRemote.OnServerEvent:Connect(function(player, crateId)
	local s = state[player]
	if not s or type(crateId) ~= "string" then return end
	local index
	for i, crate in ipairs(s.crates) do
		if crate.id == crateId then index = i break end
	end
	if not index then return end
	local crate = s.crates[index]

	if os.time() < crate.readyAt then
		openCrateRemote:FireClient(player, crateId, false, "wait")
		return
	end
	if #s.inventory >= inventoryCapacity(s, player) then
		toast(player, "Inventory full — sell or fuse something first.")
		openCrateRemote:FireClient(player, crateId, false, "full")
		return
	end

	table.remove(s.crates, index)
	table.insert(s.inventory, crate.item)
	playSound(playerRoot(player), "big")
	toast(player, string.format("CRATE OPENED\n%s", instanceTag(crate.item)), true)
	openCrateRemote:FireClient(player, crateId, true, crate.item)
	pushUI(player)
end)

travelRemote.OnServerEvent:Connect(function(player, destination)
	if destination == "junkyard" then
		sendHome(player)
	elseif destination == "racewars" then
		RaceWars.SendToLobby(player)
	end
end)

------------------------------------------------------------------
-- Trading — 1-for-1, same server, proximity-triggered.
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
		local freeSlots = inventoryCapacity(s, player) - #s.inventory
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
	end
end

local function giveTradedItem(player, itemName, source)
	local s = state[player]
	if source == "carry" then
		table.insert(s.slots, itemName)
		refreshPad(player)
	elseif source == "inventory" then
		table.insert(s.inventory, itemName)
	end
end

local function pushTradeUpdate(player)
	local snapshot = Trade.Snapshot(player)
	remote:FireClient(player, {
		-- false, not nil: a RemoteEvent drops nil-valued keys, and the client
		-- needs "no trade" to be told apart from "field absent" to know when
		-- to clear a stale trade window.
		trade = snapshot or false,
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

-- A trade starts with a request from the TRADE menu. The other player
-- gets a popup (TradeRequestUI) and nothing opens for either of them until
-- they accept it; a request nobody answers runs out after
-- TRADE_REQUEST_SECONDS.
local TRADE_REQUEST_SECONDS = 15

local tradeRequestRemote = ReplicatedStorage:FindFirstChild("TradeRequest")
if not tradeRequestRemote then
	tradeRequestRemote = Instance.new("RemoteEvent")
	tradeRequestRemote.Name = "TradeRequest"
	tradeRequestRemote.Parent = ReplicatedStorage
end

-- [target] = { from = player, id = n }: the request waiting on target.
local tradeRequests = {}
local nextRequestId = 0

local function startTradeWith(initiator, target)
	if initiator == target then return end
	local id = Trade.Start(initiator, target)
	if not id then
		toast(initiator, "Can't start a trade right now — one of you is already trading.")
		return
	end
	pushTradeUpdate(initiator)
	pushTradeUpdate(target)
end

local function requestTrade(initiator, target)
	if initiator == target then return end
	if Trade.Get(initiator) or Trade.Get(target) then
		toast(initiator, "One of you is already in a trade.")
		return
	end
	local waiting = tradeRequests[target]
	if waiting and waiting.from ~= initiator and waiting.from.Parent then
		toast(initiator, target.Name .. " is answering another trade request — try again in a moment.")
		return
	end
	nextRequestId += 1
	local id = nextRequestId
	tradeRequests[target] = { from = initiator, id = id }
	tradeRequestRemote:FireClient(target, {
		kind = "request",
		fromName = initiator.Name,
		fromUserId = initiator.UserId,
		seconds = TRADE_REQUEST_SECONDS,
	})
	toast(initiator, "Trade request sent to " .. target.Name .. ".")
	task.delay(TRADE_REQUEST_SECONDS, function()
		local still = tradeRequests[target]
		if still and still.id == id then
			tradeRequests[target] = nil
			tradeRequestRemote:FireClient(target, { kind = "expired" })
			if initiator.Parent then
				toast(initiator, target.Name .. " didn't answer your trade request.")
			end
		end
	end)
end

startTradeRemote.OnServerEvent:Connect(function(player, targetUserId)
	if type(targetUserId) ~= "number" then return end
	local target = Players:GetPlayerByUserId(targetUserId)
	if not target then
		toast(player, "That player isn't here anymore.")
		return
	end
	requestTrade(player, target)
end)

-- The answer to a request: accept opens the trade for both, decline tells
-- the one who asked.
tradeRequestRemote.OnServerEvent:Connect(function(player, accepted)
	local waiting = tradeRequests[player]
	if not waiting then return end
	tradeRequests[player] = nil
	local initiator = waiting.from
	if not initiator.Parent then
		toast(player, "They left before you answered.")
		return
	end
	if accepted == true then
		startTradeWith(initiator, player)
	else
		toast(initiator, player.Name .. " declined your trade request.")
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

	-- Turn away a pairing that could never fuse instead of letting it sit
	-- on the pad and fail later. Only the first pair is checked here:
	-- anything past it queues, and attemptFusion checks again on its turn.
	if #s.slots == 1 then
		local problem = fusionPairProblem(s.slots[1], itemName)
		if problem then
			toast(player, problem)
			return
		end
	end

	if not canReceiveTradedItem(player, itemName, "carry") then
		toast(player, "Hands full — fuse or sell something first.")
		return
	end

	removeTradedItem(player, { source = "inventory", index = index, itemName = itemName })
	giveTradedItem(player, itemName, "carry")

	toast(player, string.format("%s is ready to fuse — head to your pad.", instanceTag(itemName)))
	pushUI(player)
end)

-- Lets a fresh grab sitting on the pad (not fused yet) go back to
-- Inventory instead of being stuck there until you commit to a fuse.
returnSlotToInventory = function(player, index)
	local s = state[player]
	if not s then return end
	local itemName = type(index) == "number" and s.slots[index]
	if not itemName then return end

	if #s.inventory >= inventoryCapacity(s, player) then
		toast(player, "Inventory's full — sell or place something first.")
		return
	end

	table.remove(s.slots, index)
	table.insert(s.inventory, itemName)
	refreshPad(player)

	toast(player, string.format("%s is back in your Inventory.", instanceTag(itemName)))
	pushUI(player)
end

removeFromCarryRemote.OnServerEvent:Connect(returnSlotToInventory)

------------------------------------------------------------------
-- Placing and unplacing pets — a pet only earns money while it's
-- physically on one of a player's pads. Placing happens from the
-- Inventory popup (you're choosing which of your pets goes to work);
-- unplacing happens either the same way or by walking up to an occupied
-- pad and taking it off directly, same "physical prompt for the pad
-- itself" pattern as the fusion pad.
------------------------------------------------------------------

placePetRemote.OnServerEvent:Connect(function(player, index)
	local s = state[player]
	if not s then return end
	local itemName = type(index) == "number" and s.inventory[index]
	if not itemName then return end

	if #s.placed >= PET_PAD_COUNT then
		toast(player, string.format("All %d pads are full — take one off first.", PET_PAD_COUNT))
		return
	end

	table.remove(s.inventory, index)
	table.insert(s.placed, itemName)
	updateWalkSpeed(player)
	refreshPlacedPets(player)

	toast(player, string.format("%s is on the job — earning coins now.", instanceTag(itemName)))
	pushUI(player)
end)

local function unplacePet(player, slot)
	local s = state[player]
	if not s then return end
	local itemName = type(slot) == "number" and s.placed[slot]
	if not itemName then return end

	if #s.inventory >= inventoryCapacity(s, player) then
		toast(player, "Inventory's full — sell something first.")
		return
	end

	table.remove(s.placed, slot)
	table.insert(s.inventory, itemName)
	updateWalkSpeed(player)
	refreshPlacedPets(player)

	toast(player, string.format("%s is back in your Inventory.", instanceTag(itemName)))
	pushUI(player)
end

unplacePetRemote.OnServerEvent:Connect(function(player, slot)
	unplacePet(player, slot)
end)

-- Walking up to an occupied pad and taking it off directly — same
-- "physical prompt right on the thing" pattern as the fusion pad, wired
-- separately from that loop since it needs unplacePet, defined above it.
for _, plot in ipairs(plots) do
	for slot, pad in ipairs(plot.petPads) do
		pad.prompt.Triggered:Connect(function(player)
			if plot.owner ~= player then
				toast(player, "That's not your plot.")
				return
			end
			unplacePet(player, slot)
		end)
	end
end

------------------------------------------------------------------
-- Shop: promo codes and coin-purchasable pets
------------------------------------------------------------------

redeemCodeRemote.OnServerEvent:Connect(function(player, rawCode)
	local s = state[player]
	if not s then return end
	if type(rawCode) ~= "string" then return end

	local code = rawCode:gsub("^%s+", ""):gsub("%s+$", ""):upper()
	if code == "" then return end

	if s.redeemedCodes[code] then
		toast(player, "You've already redeemed that code.")
		return
	end

	local reward = PromoCodes[code]
	if not reward then
		toast(player, "That code isn't valid.")
		return
	end

	s.redeemedCodes[code] = true

	if reward.coins then
		local awarded = addCoins(player, reward.coins) or 0
		toast(player, string.format("CODE REDEEMED\n+%d coins", awarded), true)
	end

	pushUI(player)
end)

------------------------------------------------------------------
-- Passive income from placed pets ONLY — sitting in Inventory doesn't
-- earn a thing anymore; a pet has to actually be on one of a player's
-- pads (see "Placing and unplacing pets" below) to make money.
------------------------------------------------------------------

task.spawn(function()
	while true do
		task.wait(INCOME_TICK_SECONDS)

		for _, player in ipairs(Players:GetPlayers()) do
			local s = state[player]
			if s then
				local mult = valueMultiplier(player, s)
				local perSecond = 0

				for _, itemName in ipairs(s.placed) do
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
		-- The best addon, straight into your hands. The claim handler's own
		-- Day-7 toast says what you got, so no toast here.
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
		toast(player, string.format("DAY 7 JACKPOT\n%d coins + 3x Luck\n%s", displayReward.amount, instanceTag("Jet Engine")), true)
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
				PlaytimeLeaderboard.Record(player, 1)

				for _, milestone in ipairs(PLAYTIME_MILESTONES) do
					if s.playMinutes >= milestone.minutes and not s.playtimeMilestonesClaimed[milestone.minutes] then
						s.playtimeMilestonesClaimed[milestone.minutes] = true
						local awarded = addCoins(player, milestone.reward) or 0
						toast(player, string.format("%d MINUTES PLAYED\n+%d coins", milestone.minutes, awarded), true)
						pushUI(player)
					end
				end
			end
		end
	end
end)

------------------------------------------------------------------
-- Joining and leaving
------------------------------------------------------------------

-- CharacterAutoLoads is off (see the top of this file), so Roblox never
-- auto-respawns a dead player on its own — this is the only thing that
-- does, on every character's Humanoid.Died. Sends them back to their own
-- plot (RespawnLocation), never wherever they died, same as any normal
-- Roblox respawn.
local RESPAWN_DELAY = 3

local function assignPlot(player)
	for i, plot in ipairs(plots) do
		if plot.owner == nil then
			plot.owner = player

			-- BaseRaid.client reads this to tell your pads from everyone else's.
			plot.model:SetAttribute("OwnerUserId", player.UserId)
			plot.lockedUntil = 0
			plot.lockCooldownUntil = 0
			refreshLock(plot)
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
	Rebirth.Init(player, data.rebirths)
	Leaderboard.Init(player, data.lifetimeCoins)
	PlaytimeLeaderboard.Init(player, data.totalPlaytimeMinutes)

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

	local upgrades = data.upgrades or { luck = 1, carry = 1, value = 1, speed = 1 }
	upgrades.speed = upgrades.speed or 1 -- fills in for a save from before Speed Boots existed
	upgrades.storage = upgrades.storage or 1 -- and before Storage Space existed
	upgrades.bat = upgrades.bat or 1 -- and before Bat Strength and Speed Coil
	upgrades.coil = upgrades.coil or 1

	state[player] = {
		slots = {},
		inventory = data.inventory or {},
		placed = data.placedPets or {},
		discovered = discovered,
		discoveredList = data.discoveredList,
		count = #data.discoveredList,
		sales = data.sales,
		bestTier = data.bestTier,
		secrets = data.secrets,
		goalIndex = data.goalIndex,
		upgrades = upgrades,
		maxSlots = FUSE_STAGING_SLOTS,
		lastDailyDay = data.lastDailyDay or 0,
		dailyStreak = data.dailyStreak or 0,
		boosts = data.boosts or {},
		playMinutes = 0,
		playtimeMilestonesClaimed = {},
		redeemedCodes = data.redeemedCodes or {},
		crates = data.crates or {},
		plotIndex = index,
		mutationPity = 0,
	}

	-- Pets, Brainrot Island and Haunted Hollow were removed on 2026-09-23.
	-- An older save can still hold one of their items (or a pet from before
	-- pets stopped being items) in its inventory or on a pad; none of them
	-- is a Junkyard item any more, so they go. Anything the recipe book
	-- knows the rarity of is a Junkyard item and stays, and so does
	-- anything a Race Wars crate can hold.
	do
		local s = state[player]
		for _, field in ipairs({ "inventory", "placed" }) do
			for i = #s[field], 1, -1 do
				local baseName = Mutations.Unwrap(s[field][i])
				if not FusionRecipes.GetRarity(baseName) and not RaceCrates.IsLoot(baseName) then
					table.remove(s[field], i)
				end
			end
		end
	end

	refreshPad(player)
	updateWalkSpeed(player)
	refreshPlacedPets(player)

	-- A dedicated, invisible spawn point right on their plot, so the
	-- character appears there from frame one instead of flashing at the
	-- world origin first and getting teleported a moment later.
	if not plot.spawnPoint then
		local spawnPoint = Instance.new("SpawnLocation")
		spawnPoint.Name = "PlotSpawn"
		spawnPoint.Size = Vector3.new(6, 1, 6)
		spawnPoint.Position = plot.frame:PointToWorldSpace(Vector3.new(0, 3, -20))
		spawnPoint.Anchored = true
		spawnPoint.CanCollide = false
		spawnPoint.Transparency = 1
		spawnPoint.Neutral = true
		spawnPoint.Parent = plot.model
		plot.spawnPoint = spawnPoint
	end
	player.RespawnLocation = plot.spawnPoint

	player.CharacterAdded:Connect(function(character)
		-- The owner's own base walls let them through (collision groups set
		-- up by the plot builder). Every part as it arrives, tools included,
		-- since an equipped tool's handle collides too.
		local group = ownerGroup(index)
		local function joinGroup(part)
			if part:IsA("BasePart") then part.CollisionGroup = group end
		end
		for _, descendant in ipairs(character:GetDescendants()) do joinGroup(descendant) end
		character.DescendantAdded:Connect(joinGroup)

		local humanoid = character:WaitForChild("Humanoid")
		giveTools(player)
		updateWalkSpeed(player)
		task.wait(1)
		pushUI(player)

		humanoid.Died:Connect(function()
			-- Dying loses the run: whatever you were carrying lands where you
			-- fell, for anyone else to pick up.
			dropCarried(player)
			task.wait(RESPAWN_DELAY)
			if player.Parent then
				player:LoadCharacter()
			end
		end)
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
		placedPets = s.placed,
		upgrades = s.upgrades,
		lastDailyDay = s.lastDailyDay,
		dailyStreak = s.dailyStreak,
		boosts = s.boosts,
		rebirths = Rebirth.Snapshot(player),
		lifetimeCoins = Leaderboard.Snapshot(player),
		totalPlaytimeMinutes = PlaytimeLeaderboard.Snapshot(player),
		redeemedCodes = s.redeemedCodes,
		crates = s.crates,
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
			PlaytimeLeaderboard.PushToStore(player)
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
	-- Leaving mid-raid does not let a thief keep it: it goes back home.
	local leaving = state[player]
	if leaving and leaving.carrying and leaving.carrying.stolenFrom then
		dropCarried(player)
	end

	local data = snapshot(player)
	if data then
		DataManager.Save(player, data)
	end
	Leaderboard.PushToStore(player)
	PlaytimeLeaderboard.PushToStore(player)

	local tradePartner = Trade.Partner(player)
	Trade.Cleanup(player)
	if tradePartner then
		toast(tradePartner, player.Name .. " left — trade cancelled.")
		pushTradeUpdate(tradePartner)
	end
	tradeRequests[player] = nil

	local s = state[player]
	if s then
		local plot = plots[s.plotIndex]
		if plot then
			plot.owner = nil
			plot.model:SetAttribute("OwnerUserId", nil)
			plot.lockedUntil = 0
			plot.lockCooldownUntil = 0
			refreshLock(plot)

			plot.padLabel.Text = "FUSION PAD"
			for slot = 1, PET_PAD_COUNT do
				redrawPetPad(plot, slot, nil)
			end
		end
	end
	state[player] = nil
	Rebirth.Cleanup(player)
	Leaderboard.Cleanup(player)
	PlaytimeLeaderboard.Cleanup(player)
	DataManager.Forget(player)
end)

print(string.format("[PlotManager] %d plots ready. %d combos to discover.",
	PLOT_COUNT, FusionRecipes.GetTotalDiscoveries()))
