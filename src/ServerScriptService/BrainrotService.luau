--[[
	BrainrotService (ModuleScript, ServerScriptService) — Junkyard Fusion v1

	Self-contained Brainrot Island: its own spawner, its own 2-slot carry
	state, its own shared fusion pad. Deliberately NOT wired into
	PlotManager's carry slots or per-player plots — keeps the two item
	lines from ever crossing, and keeps this a small, low-risk add-on to
	an already-complex live script.

	Fusing pays out immediately (no placement zones here yet — see
	HANDOFF.md for why). PlotManager owns the DataStore load/save
	lifecycle for the whole player, so this module never touches
	DataManager directly; it only exposes Init/Snapshot/Cleanup for
	PlotManager to call at the right moments.
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BrainrotRecipes = require(ReplicatedStorage:WaitForChild("BrainrotRecipes"))
local ItemVisuals = require(ReplicatedStorage:WaitForChild("ItemVisuals"))
local ItemRarity = require(ReplicatedStorage:WaitForChild("ItemRarity"))
local Mutations = require(ReplicatedStorage:WaitForChild("Mutations"))
local Gamepasses = require(script.Parent:WaitForChild("GamepassService"))
local Rebirth = require(script.Parent:WaitForChild("RebirthService"))

local remote = ReplicatedStorage:WaitForChild("GameUpdate")

-- ---------- Tuning ----------
local ISLAND_CENTER = Vector3.new(0, 0, 900)  -- far from the Foundry District ring
local AREA_SIZE = 60
local SPAWN_INTERVAL = 3
local DESPAWN_AFTER = 60
local MAX_ITEMS = 20
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
	coins.Value = coins.Value + amount
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

local old = workspace:FindFirstChild("BrainrotIsland")
if old then old:Destroy() end

local islandFolder = Instance.new("Folder")
islandFolder.Name = "BrainrotIsland"
islandFolder.Parent = workspace

part({
	Name = "Ground",
	Size = Vector3.new(AREA_SIZE + 40, 1, AREA_SIZE + 40),
	Position = ISLAND_CENTER,
	Material = Enum.Material.SmoothPlastic,
	Color = Color3.fromRGB(60, 220, 90),
	Parent = islandFolder,
})

-- Decoration ring: the ground used to be one flat rectangle. Everything
-- here sits between the creature-spawn field (|x|,|z| <= AREA_SIZE/2) and
-- the edge of the ground plate, so nothing blocks a live spawn or pickup.
do
	local DECOR_INNER = AREA_SIZE / 2 + 2
	local DECOR_OUTER = AREA_SIZE / 2 + 18
	local decorColors = {
		Color3.fromRGB(255, 90, 210), Color3.fromRGB(130, 255, 120),
		Color3.fromRGB(255, 220, 60), Color3.fromRGB(120, 200, 255),
	}
	local decorRng = Random.new(4242)

	for i = 0, 13 do
		local angle = i * (math.pi * 2 / 14) + decorRng:NextNumber(-0.08, 0.08)
		local dist = decorRng:NextNumber(DECOR_INNER, DECOR_OUTER)
		local pos = ISLAND_CENTER + Vector3.new(math.cos(angle) * dist, 0, math.sin(angle) * dist)
		local col = decorColors[(i % #decorColors) + 1]

		if i % 3 == 0 then
			-- A stylized alien stalk with a glowing pod on top.
			local height = decorRng:NextNumber(6, 11)
			part({
				Name = "IslandStalk", Size = Vector3.new(1.4, height, 1.4),
				Position = pos + Vector3.new(0, height / 2, 0),
				Material = Enum.Material.Neon, Color = col, Parent = islandFolder,
			})
			local pod = part({
				Name = "IslandStalkPod", Size = Vector3.new(3, 3, 3),
				Position = pos + Vector3.new(0, height, 0),
				Material = Enum.Material.Neon, Color = col, Parent = islandFolder,
			})
			pod.Shape = Enum.PartType.Ball
		else
			-- A cluster of glowing pods, like oversized berries.
			for k = 0, 1 do
				local size = decorRng:NextNumber(2, 3.4)
				local bush = part({
					Name = "IslandBush", Size = Vector3.new(size, size, size),
					Position = pos + Vector3.new(k * 2 - 1, size / 2, k * 1.4 - 0.7),
					Material = Enum.Material.Neon, Color = col, Parent = islandFolder,
				})
				bush.Shape = Enum.PartType.Ball
			end
		end
	end

	-- Ambient lighting so the island doesn't go flat and dark at dusk.
	for _, offset in { Vector3.new(20, 6, 20), Vector3.new(-20, 6, -20) } do
		local lamp = part({
			Name = "IslandLamp", Size = Vector3.new(1.6, 1.6, 1.6),
			Position = ISLAND_CENTER + offset,
			Material = Enum.Material.Neon, Color = Color3.fromRGB(255, 120, 220),
			Parent = islandFolder,
		})
		local pointLight = Instance.new("PointLight")
		pointLight.Color = Color3.fromRGB(255, 150, 230)
		pointLight.Range = 30
		pointLight.Brightness = 2
		pointLight.Parent = lamp
	end
end

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

local function attachTeleport(gatePart, destination)
	local prompt = Instance.new("ProximityPrompt")
	prompt.ActionText = "Travel"
	prompt.ObjectText = gatePart.Name
	prompt.HoldDuration = 0.3
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = gatePart

	prompt.Triggered:Connect(function(player)
		local character = player.Character
		if character then
			character:PivotTo(CFrame.new(destination))
		end
	end)
end

-- Where the travel menu (and the physical gate) actually drop you.
local ARRIVAL_POSITION = ISLAND_CENTER + Vector3.new(0, 5, -AREA_SIZE / 2 + 12)

attachTeleport(mainGate, ARRIVAL_POSITION)
attachTeleport(islandGate, Vector3.new(0, 5, 305))

function Brainrot.GetArrivalPosition()
	return ARRIVAL_POSITION
end

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
	prompt.HoldDuration = 0
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
		itemPart:Destroy()
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

	-- Fusion here pays out immediately rather than placing an instance, so
	-- (unlike the Junkyard side) a mutation never needs to be threaded
	-- through persisted state — it's just a bigger payout and a fancier
	-- toast for this one moment. No Luck upgrade exists on this island, so
	-- this rolls at the flat baseline rate rather than reading a level
	-- that doesn't exist here.
	local mutationId = Mutations.Roll(1, s.mutationPity)
	s.mutationPity = mutationId and 0 or (s.mutationPity or 0) + 1

	local resultTag = mutationId
		and Mutations.Tag(Mutations.Wrap(result, mutationId), mutationId)
		or ItemRarity.Tag(result, info.tier, info.isSecret)

	if not info.isFallback and not s.discovered[result] then
		s.discovered[result] = true
		toast(player, string.format(info.isSecret and "SECRET RECIPE\n%s" or "NEW DISCOVERY\n%s", resultTag), true)
	end

	local mult = Mutations.ValueMultiplier(mutationId) * Rebirth.Multiplier(player)
	local payout = addCoins(player, math.floor(info.value * mult))
	toast(player, string.format("%s sold for %d coins.", resultTag, payout))

	if mutationId then
		toast(player, string.format("MUTATION!\n%s", resultTag), true)
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
