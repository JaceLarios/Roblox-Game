--[[
	HauntedService (ModuleScript, ServerScriptService) — Junkyard Fusion v1

	Self-contained Haunted Hollow: its own spawner, its own 2-slot carry
	state, its own shared fusion pad. Same self-contained shape as
	BrainrotService.luau, deliberately NOT wired into PlotManager's carry
	slots or per-player plots — keeps this item line from ever crossing
	with the other two, and keeps this a small, low-risk add-on.

	Entering the island costs coins (see ConfigureUnlock below), and the
	"have they paid" flag has to live in PlotManager's own per-player
	state, since that's what actually gets saved/loaded. PlotManager
	injects the check function after requiring this module — see
	ConfigureUnlock's own comment. Same pattern as Brainrot Island's gate.

	Fusing pays out immediately, same as Brainrot — no placement zones on
	this island either. PlotManager owns the DataStore load/save
	lifecycle for the whole player, so this module never touches
	DataManager directly; it only exposes Init/Snapshot/Cleanup for
	PlotManager to call at the right moments.

	Deliberately does NOT fire the FusionCelebration remote — Codex is
	actively animating that file's Variants table as of 2026-09-14 (see
	HANDOFF.md), and this island's fuse pad shipping toasts-only today is
	a lot safer than guessing at a "haunted" variant key that file doesn't
	know about yet. Wiring this pad into that celebration (tag
	area="haunted") once that pass lands is a small, obvious follow-up —
	see the note right above attemptFusion below.
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local IslandBuilder = require(ServerStorage:WaitForChild("IslandBuilder"))
local HauntedRecipes = require(ReplicatedStorage:WaitForChild("HauntedRecipes"))
local ItemVisuals = require(ReplicatedStorage:WaitForChild("ItemVisuals"))
local ItemRarity = require(ReplicatedStorage:WaitForChild("ItemRarity"))
local Mutations = require(ReplicatedStorage:WaitForChild("Mutations"))
local Gamepasses = require(script.Parent:WaitForChild("GamepassService"))
local Rebirth = require(script.Parent:WaitForChild("RebirthService"))
local Companions = require(script.Parent:WaitForChild("CompanionService"))
local Leaderboard = require(script.Parent:WaitForChild("LeaderboardService"))

local remote = ReplicatedStorage:WaitForChild("GameUpdate")

-- ---------- Tuning ----------
-- 1,000 studs out on +X — Brainrot Island sits 900 studs out on +Z, so
-- this keeps well clear of it on a different axis entirely, and clear of
-- the Foundry District's own ambient decoration (checked live: nothing
-- closer than ~57 studs to this island's mainland gate).
local ISLAND_CENTER = Vector3.new(1000, 0, 900)
-- Launches at the same built-out scale Brainrot Island grew to the same
-- day, rather than starting small and needing its own later expansion
-- pass — "same basic layout" per the standing directive.
local AREA_SIZE = 100
local SPAWN_INTERVAL = 3
local DESPAWN_AFTER = 60
local MAX_ITEMS = 32
local CARRY_CAPACITY = 2
-- ----------------------------

local Haunted = {}

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
	-- without a cutoff every label on the island stays fully legible from
	-- clear across it and piles into an unreadable wall of text.
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

-- A graveyard-mist palette: ghostly purple, ecto green, bone white, and a
-- blood-red accent — cycled around the boundary ring and used as each
-- scattered cluster's wisp-light color (see buildCluster below).
local HAUNTED_COLORS = {
	Color3.fromRGB(150, 90, 220), Color3.fromRGB(120, 230, 140),
	Color3.fromRGB(230, 225, 210), Color3.fromRGB(200, 60, 60),
}

local function buildCluster(cf, color, parent, rng)
	if rng:NextNumber() < 0.4 then
		-- A leaning tombstone (always stone-colored — a real graveyard
		-- doesn't have rainbow headstones) with a wisp light hovering
		-- beside it in the cluster's cycled theme color, so the scatter
		-- still reads as varied at a glance.
		local tilt = rng:NextNumber(-0.15, 0.15)
		local slab = part({
			Name = "Tombstone", Size = Vector3.new(2.4, 3.6, 0.8),
			CFrame = cf * CFrame.new(0, 1.8, 0) * CFrame.Angles(0, 0, tilt),
			Material = Enum.Material.Slate, Color = Color3.fromRGB(120, 118, 112), Parent = parent,
		})
		local cap = part({
			Name = "TombstoneCap", Size = Vector3.new(2.4, 2.4, 0.8),
			CFrame = slab.CFrame * CFrame.new(0, 1.2, 0),
			Material = Enum.Material.Slate, Color = slab.Color, Parent = parent,
		})
		cap.Shape = Enum.PartType.Cylinder
		cap.Orientation = Vector3.new(0, 0, 90)

		local wisp = part({
			Name = "WispLight", Size = Vector3.new(1.2, 1.2, 1.2),
			CFrame = cf * CFrame.new(2, rng:NextNumber(3, 5), 1),
			Material = Enum.Material.Neon, Color = color, Parent = parent,
		})
		wisp.Shape = Enum.PartType.Ball
		local wispLight = Instance.new("PointLight")
		wispLight.Color = color
		wispLight.Brightness = 1.5
		wispLight.Range = 16
		wispLight.Shadows = false
		wispLight.Parent = wisp
	else
		-- A small drift of 2-3 will-o-wisp lights at staggered heights —
		-- no tombstone, just ghost lights over open grass.
		for k = 0, rng:NextInteger(1, 2) do
			local wisp = part({
				Name = "WispLight", Size = Vector3.new(1, 1, 1),
				CFrame = cf * CFrame.new(k * 2 - 1, rng:NextNumber(2.5, 5.5), k * 1.3 - 0.6),
				Material = Enum.Material.Neon, Color = color, Parent = parent,
			})
			wisp.Shape = Enum.PartType.Ball
			local wispLight = Instance.new("PointLight")
			wispLight.Color = color
			wispLight.Brightness = 1.2
			wispLight.Range = 14
			wispLight.Shadows = false
			wispLight.Parent = wisp
		end
	end
end

-- Landmark 1: a small crooked stone mausoleum — something to walk toward
-- besides the pad itself, and the island's most recognizable silhouette.
local function buildCrypt(cf, parent)
	local base = part({
		Name = "CryptBase", Size = Vector3.new(14, 10, 12),
		CFrame = cf * CFrame.new(0, 5, 0) * CFrame.Angles(0, 0.05, 0),
		Material = Enum.Material.Slate, Color = Color3.fromRGB(95, 92, 88), Parent = parent,
	})
	local roof = part({
		Name = "CryptRoof", Size = Vector3.new(16, 1, 14),
		CFrame = base.CFrame * CFrame.new(0, 6, 0) * CFrame.Angles(0, 0, math.rad(20)),
		Material = Enum.Material.Slate, Color = Color3.fromRGB(70, 68, 65), Parent = parent,
	})
	local door = part({
		Name = "CryptDoor", Size = Vector3.new(4, 6, 0.4),
		CFrame = base.CFrame * CFrame.new(0, -2, -6.1),
		Material = Enum.Material.Neon, Color = Color3.fromRGB(150, 90, 220), Parent = parent,
	})
	local doorLight = Instance.new("PointLight")
	doorLight.Color = Color3.fromRGB(170, 120, 240)
	doorLight.Brightness = 2.5
	doorLight.Range = 30
	doorLight.Shadows = false
	doorLight.Parent = door

	for _, side in ipairs({ -1, 1 }) do
		part({
			Name = "CryptPillar", Size = Vector3.new(1.6, 9, 1.6),
			CFrame = base.CFrame * CFrame.new(side * 5, -0.5, -6),
			Material = Enum.Material.Slate, Color = Color3.fromRGB(105, 102, 98), Parent = parent,
		})
	end
end

-- Landmark 2: a gnarled dead tree with a few hanging wisp-lights instead
-- of leaves — spooky-charming rather than gory, matching the rest of the
-- game's whimsical tone (same call the mushroom grove made for Brainrot).
local function buildDeadTree(cf, parent)
	local trunk = part({
		Name = "DeadTrunk", Size = Vector3.new(3.5, 22, 3.5),
		CFrame = cf * CFrame.new(0, 11, 0) * CFrame.Angles(0, 0, math.rad(6)),
		Material = Enum.Material.Wood, Color = Color3.fromRGB(55, 48, 45), Parent = parent,
	})

	local branchColors = { Color3.fromRGB(120, 230, 140), Color3.fromRGB(150, 90, 220), Color3.fromRGB(230, 140, 60) }
	for i = 0, 3 do
		local a = i * (math.pi / 2) + 0.4
		local branch = part({
			Name = "DeadBranch", Size = Vector3.new(1.2, 8, 1.2),
			CFrame = trunk.CFrame * CFrame.new(0, 7, 0)
				* CFrame.Angles(0, a, math.rad(55))
				* CFrame.new(0, 4, 0),
			Material = Enum.Material.Wood, Color = trunk.Color, Parent = parent,
		})

		local wisp = part({
			Name = "WispLight", Size = Vector3.new(1.4, 1.4, 1.4),
			Position = branch.Position + Vector3.new(0, 4.2, 0),
			Material = Enum.Material.Neon, Color = branchColors[i % #branchColors + 1], Parent = parent,
		})
		wisp.Shape = Enum.PartType.Ball
		local wispLight = Instance.new("PointLight")
		wispLight.Color = wisp.Color
		wispLight.Brightness = 2
		wispLight.Range = 20
		wispLight.Shadows = false
		wispLight.Parent = wisp
	end
end

local CRYPT_OFFSET = Vector3.new(-AREA_SIZE / 2 + 15, 0, 0)
local TREE_OFFSET = Vector3.new(AREA_SIZE / 2 - 20, 0, -AREA_SIZE / 2 + 20)

local old = workspace:FindFirstChild("HauntedIsland")
if old then old:Destroy() end

local built = IslandBuilder.Build({
	name = "HauntedIsland",
	center = ISLAND_CENTER,
	groundRadius = AREA_SIZE / 2,
	groundColor = Color3.fromRGB(48, 42, 56),
	ringColors = HAUNTED_COLORS,
	lampColor = Color3.fromRGB(120, 230, 140),
	clusterCount = 22,
	buildCluster = buildCluster,
	seed = 1313,
	landmarks = {
		{ position = CRYPT_OFFSET, build = buildCrypt },
		{ position = TREE_OFFSET, build = buildDeadTree },
	},
})
local islandFolder = built.folder

local islandSign = part({
	Name = "IslandSign",
	Size = Vector3.new(2, 14, 2),
	Position = ISLAND_CENTER + Vector3.new(0, 8, -AREA_SIZE / 2 - 8),
	Material = Enum.Material.Neon,
	Color = Color3.fromRGB(150, 90, 220),
	Parent = islandFolder,
})
label(islandSign, "HAUNTED HOLLOW", 9, 340, Color3.fromRGB(255, 255, 255), 90)

-- Shared fusion pad — first come, first served, unlike the personal pads
-- back at the Junkyard plots.
local pad = part({
	Name = "HauntedPad",
	Size = Vector3.new(16, 1, 16),
	Position = ISLAND_CENTER + Vector3.new(0, 1, AREA_SIZE / 2 - 5),
	Material = Enum.Material.Neon,
	Color = Color3.fromRGB(120, 230, 140),
	Parent = islandFolder,
})
local padLabel = label(pad, "FUSION PAD", 6, 260, nil, 55)

local padPrompt = Instance.new("ProximityPrompt")
padPrompt.ActionText = "Fuse"
padPrompt.ObjectText = "Haunted Pad"
padPrompt.HoldDuration = 0
padPrompt.MaxActivationDistance = 16
padPrompt.RequiresLineOfSight = false
padPrompt.Parent = pad

-- Teleporters: one at the edge of the main map, one on the island.
local mainGate = part({
	Name = "ToHauntedIsland",
	Size = Vector3.new(8, 1, 8),
	Position = Vector3.new(320, 1, 0),
	Material = Enum.Material.Neon,
	Color = Color3.fromRGB(150, 90, 220),
	Parent = workspace,
})
label(mainGate, "To Haunted Hollow", 4, 220, Color3.fromRGB(255, 255, 255), 70)

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
		if requireUnlock and not (Haunted.UnlockGate and Haunted.UnlockGate(player)) then
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
-- self-contained module) calls Haunted.ConfigureUnlock once it has
-- everything it needs; safe to reference Haunted.UnlockGate here before
-- that injection happens, since a real player can't trigger this prompt
-- until the whole server script has finished loading. Same pattern as
-- Brainrot Island's gate.
local mainGatePrompt = attachTeleport(mainGate, ARRIVAL_POSITION, true)
attachTeleport(islandGate, Vector3.new(1000, 5, 905))

function Haunted.ConfigureUnlock(checkFn, cost)
	Haunted.UnlockGate = checkFn
	mainGatePrompt.ObjectText = string.format("Haunted Hollow (%d coins to unlock)", cost)
end

function Haunted.GetArrivalPosition()
	return ARRIVAL_POSITION
end

-- Paths connecting the pad to the sign and the two landmarks — the
-- difference between "a decorated field" and "a place with somewhere to
-- walk." Same IslandBuilder.Path helper Brainrot Island's own paths use.
do
	local PATH_COLOR = Color3.fromRGB(90, 80, 100)
	IslandBuilder.Path(pad.Position, islandSign.Position, 7, PATH_COLOR, islandFolder)
	IslandBuilder.Path(pad.Position, ISLAND_CENTER + CRYPT_OFFSET, 6, PATH_COLOR, islandFolder)
	IslandBuilder.Path(pad.Position, ISLAND_CENTER + TREE_OFFSET, 6, PATH_COLOR, islandFolder)
end

------------------------------------------------------------------
-- Spawning
------------------------------------------------------------------

local collectionFolder = Instance.new("Folder")
collectionFolder.Name = "HauntedScrap"
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
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = itemPart

	prompt.Triggered:Connect(function(player)
		local s = state[player]
		if not s then return end
		if not itemPart.Parent then return end
		if #s.slots >= CARRY_CAPACITY then
			toast(player, "Hands full — fuse at the Haunted Pad first.")
			return
		end

		table.insert(s.slots, itemName)
		itemPart:Destroy()
		Haunted.RefreshPad(player)
	end)
end

collectionFolder.ChildAdded:Connect(attachPickup)

local function dropNearIsland(itemName)
	local itemPart = ItemVisuals.Create(itemName, randomSpawnPosition(), 1)
	itemPart:SetAttribute("ItemName", itemName)
	local itemColor = ItemRarity.Color(HauntedRecipes.GetTier(itemName), HauntedRecipes.IsSecretResult(itemName))
	label(itemPart, itemName, 2, 150, itemColor, 45)
	itemPart.Parent = collectionFolder
end

local function spawnCreature()
	if #collectionFolder:GetChildren() >= MAX_ITEMS then return end

	local itemName = HauntedRecipes.RollBaseItem()
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
	return ItemRarity.Tag(itemName, HauntedRecipes.GetTier(itemName), HauntedRecipes.IsSecretResult(itemName))
end

function Haunted.RefreshPad(player)
	local s = state[player]
	if not s then return end
	padLabel.Text = string.format("FUSION PAD\n[ %s ]  +  [ %s ]", tag(s.slots[1]), tag(s.slots[2]))
end

local function attemptFusion(player)
	local s = state[player]
	if not s then return end

	local a, b = s.slots[1], s.slots[2]
	if not (a and b) then
		toast(player, "You need two graveyard finds to fuse.")
		return
	end

	s.slots = {}
	Haunted.RefreshPad(player)

	local result, info = HauntedRecipes.Fuse(a, b)

	if not result then
		-- Only reachable on malformed input (see HauntedRecipes.Fuse) —
		-- every real item name pair now produces a result.
		dropNearIsland(a)
		dropNearIsland(b)
		return
	end

	-- Captured once, up front, before s.discovered[result] gets mutated
	-- below — otherwise the "was this new" check would read the
	-- post-mutation value and never see a discovery as new. Same hazard
	-- Junkyard/Brainrot's attemptFusion both have and solve the same way.
	local isNewDiscovery = not info.isFallback and not s.discovered[result]

	-- No Luck upgrade exists on this island, so this rolls at the flat
	-- baseline rate rather than reading a level that doesn't exist here —
	-- same reasoning as Brainrot's own attemptFusion.
	local mutationId = Mutations.Roll(1, s.mutationPity)
	s.mutationPity = mutationId and 0 or (s.mutationPity or 0) + 1

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

	-- No FusionCelebration popup on this island yet — deliberately, see
	-- this file's header. Once Codex's Variants table has a "haunted"
	-- entry, wiring this in is the same few lines Brainrot's own
	-- attemptFusion already has: fire fusionCelebrationRemote with
	-- area="haunted" and the same aTag/bTag/resultTag/rarityName/color
	-- payload shape, right here.

	-- Server-wide callout stays reserved for real discoveries — a generic
	-- hybrid shouldn't announce itself with the same fanfare. A mutation
	-- earns the callout even on an already-discovered result.
	if not info.isFallback and (info.tier >= 3 or info.isSecret or mutationId) then
		broadcast(string.format("%s fused %s in Haunted Hollow!", player.Name, resultTag))
	end
end

padPrompt.Triggered:Connect(attemptFusion)

------------------------------------------------------------------
-- Persistence hooks — called by PlotManager, which owns the save file.
------------------------------------------------------------------

function Haunted.Init(player, discoveredList)
	local discovered = {}
	for _, name in ipairs(discoveredList or {}) do
		discovered[name] = true
	end
	state[player] = { slots = {}, discovered = discovered, mutationPity = 0 }
end

function Haunted.Snapshot(player)
	local s = state[player]
	if not s then return {} end

	local list = {}
	for name in pairs(s.discovered) do
		table.insert(list, name)
	end
	return list
end

function Haunted.Cleanup(player)
	state[player] = nil
end

print(string.format("[Haunted] Island ready. %d combos to discover.", HauntedRecipes.GetTotalDiscoveries()))

return Haunted
