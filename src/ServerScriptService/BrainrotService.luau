--[[
	BrainrotService (ModuleScript, ServerScriptService) — Junkyard Fusion v1

	Self-contained Brainrot Island: its own spawner, its own 2-slot carry
	state, its own shared fusion pad. Deliberately NOT wired into
	PlotManager's carry slots or per-player plots — keeps the two item
	lines from ever crossing, and keeps this a small, low-risk add-on to
	an already-complex live script.

	One deliberate exception, added 2026-09-14: entering the island costs
	coins (see ConfigureUnlock below), and the "have they paid" flag has
	to live in PlotManager's own per-player state, since that's what
	actually gets saved/loaded. PlotManager injects the check function
	after requiring this module — see ConfigureUnlock's own comment.

	Fusing pays out immediately (no placement zones here yet — see
	HANDOFF.md for why). PlotManager owns the DataStore load/save
	lifecycle for the whole player, so this module never touches
	DataManager directly; it only exposes Init/Snapshot/Cleanup for
	PlotManager to call at the right moments.
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local InsertService = game:GetService("InsertService")

local IslandBuilder = require(ServerStorage:WaitForChild("IslandBuilder"))
local PickupEffects = require(ServerStorage:WaitForChild("PickupEffects"))
local BrainrotRecipes = require(ReplicatedStorage:WaitForChild("BrainrotRecipes"))
local ItemVisuals = require(ReplicatedStorage:WaitForChild("ItemVisuals"))
local ItemRarity = require(ReplicatedStorage:WaitForChild("ItemRarity"))
local Mutations = require(ReplicatedStorage:WaitForChild("Mutations"))
local Gamepasses = require(script.Parent:WaitForChild("GamepassService"))
local Rebirth = require(script.Parent:WaitForChild("RebirthService"))
local Companions = require(script.Parent:WaitForChild("CompanionService"))
local Leaderboard = require(script.Parent:WaitForChild("LeaderboardService"))
local AreaPetsService = require(script.Parent:WaitForChild("AreaPetsService"))

local remote = ReplicatedStorage:WaitForChild("GameUpdate")
-- PlotManager creates this before requiring this module (see its own
-- comment there), specifically so this WaitForChild is safe to call here
-- at module load time instead of deadlocking on a remote that doesn't
-- exist yet.
local fusionCelebrationRemote = ReplicatedStorage:WaitForChild("FusionCelebration")

-- ---------- Tuning ----------
local ISLAND_CENTER = Vector3.new(0, 0, 900)  -- far from the Foundry District ring
-- Bumped 60->100 on 2026-09-14 ("build the brainrot island out... just
-- like the junkyard island so people can walk around"), then 100->150
-- the same day ("id like the map to be bigger for each of the new
-- areas") — this is the half-width of the actual creature-spawn field;
-- IslandBuilder derives the boundary ring and outer ground plate from
-- it, so the whole island grows along with it, not just the spawn area.
local AREA_SIZE = 150
local SPAWN_INTERVAL = 3
local DESPAWN_AFTER = 60
local MAX_ITEMS = 48  -- scaled up with AREA_SIZE (32 at 100) so density feels about the same, not sparser
local CARRY_CAPACITY = 2
-- ----------------------------

local Brainrot = {}

local state = {} -- [player] = { slots = {a, b}, discovered = {[name]=true} }

local function toast(player, message, isBig)
	remote:FireClient(player, { toast = message, big = isBig or false })
end

local function broadcast(message)
	remote:FireAllClients({ announce = message })
end

local function addCoins(player, amount)
	local stats = player:FindFirstChild("leaderstats")
	local coins = stats and stats:FindFirstChild("Coins")
	if not coins then return 0 end
	amount = Gamepasses.Coins(player, amount)
	amount = AreaPetsService.Coins(player, amount)
	coins.Value = coins.Value + amount
	Leaderboard.Record(player, amount)
	return amount
end

local function part(props)
	local p = Instance.new("Part")
	p.Anchored = true
	for key, value in pairs(props) do p[key] = value end
	return p
end

local function label(parent, text, offsetY, size, color, maxDistance)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.new(0, size or 280, 0, 60)
	gui.StudsOffset = Vector3.new(0, offsetY or 4, 0)
	gui.AlwaysOnTop = true
	-- Billboards hold a constant SCREEN size regardless of distance, so
	-- without a cutoff every label on the island stays fully legible
	-- from clear across it and piles into an unreadable wall of text.
	gui.MaxDistance = maxDistance or 45
	gui.Parent = parent

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, 0, 1, 0)
	lbl.BackgroundTransparency = 1
	lbl.Text = text
	lbl.TextColor3 = color or Color3.fromRGB(255, 255, 255)
	lbl.TextStrokeTransparency = 0.3
	lbl.TextScaled = true
	lbl.Font = Enum.Font.FredokaOne
	lbl.RichText = true
	lbl.Parent = gui
	return lbl
end

------------------------------------------------------------------
-- Build the island
------------------------------------------------------------------

-- Same alien-stalk/glowing-pod-cluster look this island already had,
-- promoted to IslandBuilder's theme.buildCluster shape (unchanged
-- visuals/colors), plus two new bigger landmarks. "Built out, walkable,
-- like the Junkyard" needed more than a bigger empty field — a place to
-- actually walk toward, not just more of the same scattered clutter.
local BRAINROT_COLORS = {
	Color3.fromRGB(255, 90, 210), Color3.fromRGB(130, 255, 120),
	Color3.fromRGB(255, 220, 60), Color3.fromRGB(120, 200, 255),
}

local function buildCluster(cf, color, parent, rng)
	if rng:NextNumber() < 0.35 then
		-- A stylized alien stalk with a glowing pod on top.
		local height = rng:NextNumber(6, 11)
		part({
			Name = "IslandStalk", Size = Vector3.new(1.4, height, 1.4),
			CFrame = cf * CFrame.new(0, height / 2, 0),
			Material = Enum.Material.Neon, Color = color, Parent = parent,
		})
		local pod = part({
			Name = "IslandStalkPod", Size = Vector3.new(3, 3, 3),
			CFrame = cf * CFrame.new(0, height, 0),
			Material = Enum.Material.Neon, Color = color, Parent = parent,
		})
		pod.Shape = Enum.PartType.Ball
	else
		-- A cluster of glowing pods, like oversized berries.
		for k = 0, 1 do
			local size = rng:NextNumber(2, 3.4)
			local bush = part({
				Name = "IslandBush", Size = Vector3.new(size, size, size),
				CFrame = cf * CFrame.new(k * 2 - 1, size / 2, k * 1.4 - 0.7),
				Material = Enum.Material.Neon, Color = color, Parent = parent,
			})
			bush.Shape = Enum.PartType.Ball
		end
	end
end

-- Landmark 1: a tall spiraling spire, visible from across the island —
-- something to walk toward besides the pad itself.
local function buildSpire(cf, parent)
	local height = 45
	for i = 0, 8 do
		local t = i / 8
		local segCf = cf * CFrame.new(math.sin(t * math.pi * 3) * 3, t * height, math.cos(t * math.pi * 3) * 3)
		local seg = part({
			Name = "SpireSegment", Size = Vector3.new(3.2 - t * 1.6, 3, 3.2 - t * 1.6),
			CFrame = segCf, Material = Enum.Material.Neon,
			Color = Color3.fromRGB(255, 90, 210):Lerp(Color3.fromRGB(120, 200, 255), t), Parent = parent,
		})
		seg.Shape = Enum.PartType.Ball
	end
	local orb = part({
		Name = "SpireOrb", Size = Vector3.new(6, 6, 6),
		CFrame = cf * CFrame.new(0, height + 4, 0),
		Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 255, 255), Parent = parent,
	})
	orb.Shape = Enum.PartType.Ball
	local spireLight = Instance.new("PointLight")
	spireLight.Color = Color3.fromRGB(255, 200, 255)
	spireLight.Brightness = 3
	spireLight.Range = 50
	spireLight.Shadows = false
	spireLight.Parent = orb
end

-- Landmark 2: an oversized mushroom grove — a whimsical, surreal touch
-- matching the brainrot-meme creature roster (Bombardino Squalini and
-- friends), not a generic alien-planet cliché.
local function buildMushroomGrove(cf, parent)
	local capColors = { Color3.fromRGB(255, 120, 180), Color3.fromRGB(150, 255, 180), Color3.fromRGB(255, 220, 120) }
	for i = 0, 2 do
		local offsetCf = cf * CFrame.new(math.cos(i * 2.1) * 6, 0, math.sin(i * 2.1) * 6)
		local h = 8 + i * 2
		part({
			Name = "MushroomStem", Size = Vector3.new(2, h, 2),
			CFrame = offsetCf * CFrame.new(0, h / 2, 0),
			Material = Enum.Material.SmoothPlastic, Color = Color3.fromRGB(245, 240, 225), Parent = parent,
		})
		local cap = part({
			Name = "MushroomCap", Size = Vector3.new(9, 4, 9),
			CFrame = offsetCf * CFrame.new(0, h + 1, 0),
			Material = Enum.Material.Neon, Color = capColors[i + 1], Parent = parent,
		})
		cap.Shape = Enum.PartType.Ball
	end
end

local SPIRE_OFFSET = Vector3.new(-AREA_SIZE / 2 + 15, 0, 0)
local MUSHROOM_OFFSET = Vector3.new(AREA_SIZE / 2 - 20, 0, -AREA_SIZE / 2 + 20)

local old = workspace:FindFirstChild("BrainrotIsland")
if old then old:Destroy() end

local built = IslandBuilder.Build({
	name = "BrainrotIsland",
	center = ISLAND_CENTER,
	groundRadius = AREA_SIZE / 2,
	groundColor = Color3.fromRGB(60, 220, 90),
	ringColors = BRAINROT_COLORS,
	lampColor = Color3.fromRGB(255, 150, 230),
	clusterCount = 22,
	buildCluster = buildCluster,
	seed = 4242,
	landmarks = {
		{ position = SPIRE_OFFSET, build = buildSpire },
		{ position = MUSHROOM_OFFSET, build = buildMushroomGrove },
	},
})
local islandFolder = built.folder

local islandSign = part({
	Name = "IslandSign",
	Size = Vector3.new(2, 14, 2),
	Position = ISLAND_CENTER + Vector3.new(0, 8, -AREA_SIZE / 2 - 8),
	Material = Enum.Material.Neon,
	Color = Color3.fromRGB(255, 0, 170),
	Parent = islandFolder,
})
label(islandSign, "BRAINROT ISLAND", 9, 340, Color3.fromRGB(255, 255, 255), 90)

-- Shared fusion pad — first come, first served, unlike the personal pads
-- back at the Junkyard plots.
local pad = part({
	Name = "BrainrotPad",
	Size = Vector3.new(16, 1, 16),
	Position = ISLAND_CENTER + Vector3.new(0, 1, AREA_SIZE / 2 - 5),
	Material = Enum.Material.Neon,
	Color = Color3.fromRGB(255, 0, 170),
	Parent = islandFolder,
})
local padLabel = label(pad, "FUSION PAD", 6, 260, nil, 55)

local padPrompt = Instance.new("ProximityPrompt")
padPrompt.ActionText = "Fuse"
padPrompt.ObjectText = "Brainrot Pad"
padPrompt.HoldDuration = 0
padPrompt.MaxActivationDistance = 16
padPrompt.RequiresLineOfSight = false
padPrompt.Parent = pad

-- Teleporters: one at the edge of the main map, one on the island.
local mainGate = part({
	Name = "ToBrainrotIsland",
	Size = Vector3.new(8, 1, 8),
	Position = Vector3.new(0, 1, 320),
	Material = Enum.Material.Neon,
	Color = Color3.fromRGB(255, 0, 170),
	Parent = workspace,
})
label(mainGate, "To Brainrot Island", 4, 220, Color3.fromRGB(255, 255, 255), 70)

local islandGate = part({
	Name = "ToMainland",
	Size = Vector3.new(8, 1, 8),
	Position = ISLAND_CENTER + Vector3.new(0, 1, -AREA_SIZE / 2 + 5),
	Material = Enum.Material.Neon,
	Color = Color3.fromRGB(0, 200, 255),
	Parent = islandFolder,
})
label(islandGate, "To the Junkyard", 4, 220, Color3.fromRGB(255, 255, 255), 70)

local function attachTeleport(gatePart, destination, requireUnlock)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Travel"
	prompt.ObjectText = gatePart.Name
	prompt.HoldDuration = 0.3
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = gatePart

	prompt.Triggered:Connect(function(player)
		if requireUnlock and not (Brainrot.UnlockGate and Brainrot.UnlockGate(player)) then
			return
		end
		local character = player.Character
		if character then
			character:PivotTo(CFrame.new(destination))
		end
	end)

	return prompt
end

-- Where the travel menu (and the physical gate) actually drop you.
local ARRIVAL_POSITION = ISLAND_CENTER + Vector3.new(0, 5, -AREA_SIZE / 2 + 12)

-- Only the trip INTO the island can cost anything — coming back to the
-- mainland (islandGate) is always free. PlotManager.server.luau (which
-- owns coins/state/save data, none of which belongs in this
-- self-contained module) calls Brainrot.ConfigureUnlock once it has
-- everything that needs; safe to reference Brainrot.UnlockGate here
-- before that injection happens, since a real player can't trigger this
-- prompt until the whole server script has finished loading.
local mainGatePrompt = attachTeleport(mainGate, ARRIVAL_POSITION, true)
attachTeleport(islandGate, Vector3.new(0, 5, 305))

function Brainrot.ConfigureUnlock(checkFn, cost)
	Brainrot.UnlockGate = checkFn
	mainGatePrompt.ObjectText = string.format("Brainrot Island (%d coins to unlock)", cost)
end

function Brainrot.GetArrivalPosition()
	return ARRIVAL_POSITION
end

-- Paths connecting the pad to the sign and the two landmarks — the
-- difference between "a decorated field" and "a place with somewhere to
-- walk." IslandBuilder.Path is the same stretched-part-via-lookAt shape
-- MapRevamp.luau's own road/beam helper uses.
do
	local PATH_COLOR = Color3.fromRGB(235, 225, 245)
	-- IslandBuilder's Ground is 1 stud thick, centered on built.center.Y —
	-- +0.5 is its top surface, so paths lie flush on the grass instead of
	-- poking through it (see IslandBuilder.Path's own comment for why).
	local PATH_Y = built.center.Y + 0.5
	IslandBuilder.Path(pad.Position, islandSign.Position, 7, PATH_COLOR, islandFolder, PATH_Y)
	IslandBuilder.Path(pad.Position, ISLAND_CENTER + SPIRE_OFFSET, 6, PATH_COLOR, islandFolder, PATH_Y)
	IslandBuilder.Path(pad.Position, ISLAND_CENTER + MUSHROOM_OFFSET, 6, PATH_COLOR, islandFolder, PATH_Y)
	IslandBuilder.Path(pad.Position, ISLAND_CENTER, 6, PATH_COLOR, islandFolder, PATH_Y)
end

------------------------------------------------------------------
-- AreaPets egg cluster — the 3 Robux eggs for this island (see
-- AreaPets.luau), placed dead-center per the user's ask 2026-09-14:
-- "id like to have the Egg placemnt in the middle of the island so its
-- easy for eveyone to see." Visual only for now, same honest gap as the
-- eggs' own shop UI — no real product ids exist yet, so there's nothing
-- to wire a purchase ProximityPrompt to. Adding one is a small, obvious
-- follow-up once that exists (see PickupEffects/AreaPetsService for the
-- established "server owns the mechanic, prompt triggers it" shape).
------------------------------------------------------------------

-- Real modelled incubator machines, replacing the hand-built
-- cylinder-and-ball placeholders these started as. One machine per egg tier,
-- deliberately escalating from a cheap toy dispenser to an alien organism so
-- the tier jump reads from across the island without anyone parsing the label.
-- Reskinning a tier is a one-line change: swap its asset id below.
local INCUBATOR_HEIGHT = 9.2
local EGG_TIERS = {
	{ label = "OKAY EGG",  color = Color3.fromRGB(140, 160, 200), asset = 117072885390456 }, -- gumball dispenser
	{ label = "GOOD EGG",  color = Color3.fromRGB(90, 200, 190),  asset = 104592900443146 }, -- arcade capsule machine
	{ label = "GREAT EGG", color = Color3.fromRGB(235, 190, 90),  asset = 126746703704748 }, -- alien bio-pod
}

local function buildIncubator(pos, tier, parent)
	local ok, container = pcall(function()
		return InsertService:LoadAsset(tier.asset)
	end)
	if not ok or not container then
		warn(string.format("[Brainrot] incubator asset %d did not load: %s", tier.asset, tostring(container)))
		return
	end

	local model = container:FindFirstChildWhichIsA("Model")
	if not model then
		container:Destroy()
		warn(string.format("[Brainrot] incubator asset %d contained no Model", tier.asset))
		return
	end
	model.Name = "Incubator_" .. string.gsub(tier.label, " ", "_")
	model.Parent = parent
	container:Destroy()

	for _, d in ipairs(model:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = true
		end
	end

	-- Normalize height so all three read as one matched set regardless of
	-- whatever bounding box each individual mesh happened to come back with.
	local extents = model:GetExtentsSize()
	if extents.Y > 0 then
		model:ScaleTo(model:GetScale() * (INCUBATOR_HEIGHT / extents.Y))
	end

	model:PivotTo(CFrame.new(pos.X, model:GetPivot().Position.Y, pos.Z))
	local bbCF, bbSize = model:GetBoundingBox()
	-- +0.5 is the island ground's actual top surface (see IslandBuilder.Path).
	model:PivotTo(model:GetPivot() + Vector3.new(0, (pos.Y + 0.5) - (bbCF.Position.Y - bbSize.Y / 2), 0))

	local anchor = model.PrimaryPart or model:FindFirstChildWhichIsA("BasePart", true)
	if anchor then
		label(anchor, tier.label, bbSize.Y * 0.62, 200, tier.color, 70)
	end
end

-- Spawned rather than inline: LoadAsset yields on a web request, and three of
-- them would otherwise stall PlotManager's own require of this module at
-- server start. The machines are decorative, so arriving a beat late is fine.
task.spawn(function()
	for i, tier in ipairs(EGG_TIERS) do
		local angle = (i - 1) * (math.pi * 2 / 3)
		buildIncubator(ISLAND_CENTER + Vector3.new(math.cos(angle) * 11, 0, math.sin(angle) * 11), tier, islandFolder)
	end
end)

------------------------------------------------------------------
-- Spawning
------------------------------------------------------------------

local collectionFolder = Instance.new("Folder")
collectionFolder.Name = "BrainrotScrap"
collectionFolder.Parent = islandFolder

-- Keeps a clear ring around the pad so its Fuse prompt never has to
-- compete with a creature's Grab prompt for focus.
local PAD_EXCLUSION_RADIUS = 18

local function randomSpawnPosition()
	local half = AREA_SIZE / 2
	for _ = 1, 10 do
		local x = ISLAND_CENTER.X + math.random(-half, half)
		local z = ISLAND_CENTER.Z + math.random(-half, half)
		if (Vector3.new(x, 0, z) - Vector3.new(pad.Position.X, 0, pad.Position.Z)).Magnitude >= PAD_EXCLUSION_RADIUS then
			return Vector3.new(x, ISLAND_CENTER.Y + 0.5, z)
		end
	end
	return Vector3.new(ISLAND_CENTER.X - half, ISLAND_CENTER.Y + 0.5, ISLAND_CENTER.Z - half)
end

local function attachPickup(itemPart)
	if not itemPart:IsA("BasePart") then return end
	if itemPart:FindFirstChildOfClass("ProximityPrompt") then return end

	local itemName = itemPart:GetAttribute("ItemName") or itemPart.Name

	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Grab"
	prompt.ObjectText = itemName
	-- Matches the yard's GRAB_HOLD_SECONDS in PlotManager: grabbing is a
	-- deliberate 1.5s commitment everywhere, not just in the Junkyard.
	prompt.HoldDuration = 1.5
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = itemPart

	prompt.Triggered:Connect(function(player)
		local s = state[player]
		if not s then return end
		if not itemPart.Parent then return end
		if #s.slots >= CARRY_CAPACITY then
			toast(player, "Hands full — fuse at the Brainrot Pad first.")
			return
		end

		table.insert(s.slots, itemName)
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		PickupEffects.Play(itemPart, root and root.Position or itemPart.Position)
		Brainrot.RefreshPad(player)
	end)
end

collectionFolder.ChildAdded:Connect(attachPickup)

local function dropNearIsland(itemName)
	local itemPart = ItemVisuals.Create(itemName, randomSpawnPosition(), 1)
	itemPart:SetAttribute("ItemName", itemName)
	local itemColor = ItemRarity.Color(BrainrotRecipes.GetTier(itemName), BrainrotRecipes.IsSecretResult(itemName))
	label(itemPart, itemName, 2, 150, itemColor, 45)
	itemPart.Parent = collectionFolder
end

local function spawnCreature()
	if #collectionFolder:GetChildren() >= MAX_ITEMS then return end

	local itemName = BrainrotRecipes.RollBaseItem()
	local itemPart = ItemVisuals.Create(itemName, randomSpawnPosition(), 1)
	itemPart:SetAttribute("ItemName", itemName)
	label(itemPart, itemName, 2, 150, ItemRarity.Color(1, false), 45)
	itemPart.Parent = collectionFolder

	task.delay(DESPAWN_AFTER, function()
		if itemPart.Parent then itemPart:Destroy() end
	end)
end

task.spawn(function()
	while true do
		task.wait(SPAWN_INTERVAL)
		spawnCreature()
	end
end)

------------------------------------------------------------------
-- Fusion — pays out immediately instead of placing for passive income.
------------------------------------------------------------------

local function tag(itemName)
	if not itemName then return "empty" end
	return ItemRarity.Tag(itemName, BrainrotRecipes.GetTier(itemName), BrainrotRecipes.IsSecretResult(itemName))
end

function Brainrot.RefreshPad(player)
	local s = state[player]
	if not s then return end
	padLabel.Text = string.format("FUSION PAD\n[ %s ]  +  [ %s ]", tag(s.slots[1]), tag(s.slots[2]))
end

local function attemptFusion(player)
	local s = state[player]
	if not s then return end

	local a, b = s.slots[1], s.slots[2]
	if not (a and b) then
		toast(player, "You need two brainrot creatures to fuse.")
		return
	end

	s.slots = {}
	Brainrot.RefreshPad(player)

	local result, info = BrainrotRecipes.Fuse(a, b)

	if not result then
		-- Only reachable on malformed input (see BrainrotRecipes.Fuse) —
		-- every real item name pair now produces a result.
		dropNearIsland(a)
		dropNearIsland(b)
		return
	end

	-- Captured once, up front, before s.discovered[result] gets mutated
	-- below — otherwise the "was this new" check and the celebration
	-- badges built later would both read the post-mutation value and
	-- never see a discovery as new. Junkyard's attemptFusion has the same
	-- hazard and solves it the same way.
	local isNewDiscovery = not info.isFallback and not s.discovered[result]

	-- Fusion here pays out immediately rather than placing an instance, so
	-- (unlike the Junkyard side) a mutation never needs to be threaded
	-- through persisted state — it's just a bigger payout and a fancier
	-- toast for this one moment. No Luck upgrade exists on this island, so
	-- this rolls at the flat baseline rate rather than reading a level
	-- that doesn't exist here.
	local mutationId = Mutations.Roll(1, s.mutationPity)
	s.mutationPity = mutationId and 0 or (s.mutationPity or 0) + 1
	local mutationColor = Mutations.Color(mutationId)

	local resultTag = mutationId
		and Mutations.Tag(Mutations.Wrap(result, mutationId), mutationId)
		or ItemRarity.Tag(result, info.tier, info.isSecret)

	if isNewDiscovery then
		s.discovered[result] = true
		toast(player, string.format(info.isSecret and "SECRET RECIPE\n%s" or "NEW DISCOVERY\n%s", resultTag), true)
	end

	local mult = Mutations.ValueMultiplier(mutationId) * Rebirth.Multiplier(player) * Companions.Bonus(player)
	local payout = addCoins(player, math.floor(info.value * mult))
	toast(player, string.format("%s sold for %d coins.", resultTag, payout))

	if mutationId then
		toast(player, string.format("MUTATION!\n%s", resultTag), true)
	end

	-- The same big screen-covering popup the Junkyard's fuse pad shows —
	-- Brainrot Island never fired this before now, so this was silent
	-- except for the small toasts above. Tagged area="brainrot" so
	-- FusionCelebrationView can eventually give this island its own look
	-- (see that module's Variants table) without touching this trigger.
	do
		local badges = {}
		if isNewDiscovery then table.insert(badges, "NEW DISCOVERY") end
		if info.isSecret then table.insert(badges, "SECRET RECIPE") end
		if mutationId then table.insert(badges, "MUTATION") end
		local headerText = #badges > 0 and table.concat(badges, "   •   ") or "FUSION COMPLETE"

		fusionCelebrationRemote:FireClient(player, {
			area = "brainrot",
			headerText = headerText,
			aTag = tag(a),
			bTag = tag(b),
			resultTag = resultTag,
			rarityName = ItemRarity.Name(info.tier, info.isSecret),
			color = mutationColor or ItemRarity.Color(info.tier, info.isSecret),
			-- Not a coins/sec rate like Junkyard's — this island pays out
			-- immediately, so the honest equivalent is the flat payout.
			rateLine = string.format("Sold instantly for %d coins", payout),
		})
	end

	-- Server-wide callout stays reserved for real discoveries — a generic
	-- hybrid shouldn't announce itself with the same fanfare. A mutation
	-- earns the callout even on an already-discovered result.
	if not info.isFallback and (info.tier >= 3 or info.isSecret or mutationId) then
		broadcast(string.format("%s fused %s on Brainrot Island!", player.Name, resultTag))
	end
end

padPrompt.Triggered:Connect(attemptFusion)

------------------------------------------------------------------
-- Persistence hooks — called by PlotManager, which owns the save file.
------------------------------------------------------------------

function Brainrot.Init(player, discoveredList)
	local discovered = {}
	for _, name in ipairs(discoveredList or {}) do
		discovered[name] = true
	end
	state[player] = { slots = {}, discovered = discovered, mutationPity = 0 }
end

function Brainrot.Snapshot(player)
	local s = state[player]
	if not s then return {} end

	local list = {}
	for name in pairs(s.discovered) do
		table.insert(list, name)
	end
	return list
end

function Brainrot.Cleanup(player)
	state[player] = nil
end

print(string.format("[Brainrot] Island ready. %d combos to discover.", BrainrotRecipes.GetTotalDiscoveries()))

return Brainrot
