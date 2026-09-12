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
local Gamepasses = require(script.Parent:WaitForChild("GamepassService"))

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

local function label(parent, text, offsetY, size, color)
	local gui = Instance.new("BillboardGui")
	gui.Size = UDim2.new(0, size or 280, 0, 60)
	gui.StudsOffset = Vector3.new(0, offsetY or 4, 0)
	gui.AlwaysOnTop = true
	gui.Parent = parent

	local lbl = Instance.new("TextLabel")
	lbl.Size = UDim2.new(1, 0, 1, 0)
	lbl.BackgroundTransparency = 1
	lbl.Text = text
	lbl.TextColor3 = color or Color3.fromRGB(255, 255, 255)
	lbl.TextStrokeTransparency = 0.3
	lbl.TextScaled = true
	lbl.Font = Enum.Font.GothamBold
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

local islandSign = part({
	Name = "IslandSign",
	Size = Vector3.new(2, 14, 2),
	Position = ISLAND_CENTER + Vector3.new(0, 8, -AREA_SIZE / 2 - 8),
	Material = Enum.Material.Neon,
	Color = Color3.fromRGB(255, 0, 170),
	Parent = islandFolder,
})
label(islandSign, "BRAINROT ISLAND", 9, 420, Color3.fromRGB(255, 255, 255))

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
local padLabel = label(pad, "FUSION PAD", 6, 320)

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
label(mainGate, "To Brainrot Island", 4, 260, Color3.fromRGB(255, 255, 255))

local islandGate = part({
	Name = "ToMainland",
	Size = Vector3.new(8, 1, 8),
	Position = ISLAND_CENTER + Vector3.new(0, 1, -AREA_SIZE / 2 + 5),
	Material = Enum.Material.Neon,
	Color = Color3.fromRGB(0, 200, 255),
	Parent = islandFolder,
})
label(islandGate, "To the Junkyard", 4, 260, Color3.fromRGB(255, 255, 255))

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

attachTeleport(mainGate, ISLAND_CENTER + Vector3.new(0, 5, -AREA_SIZE / 2 + 12))
attachTeleport(islandGate, Vector3.new(0, 5, 305))

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
			return Vector3.new(x, ISLAND_CENTER.Y + 3, z)
		end
	end
	return Vector3.new(ISLAND_CENTER.X - half, ISLAND_CENTER.Y + 3, ISLAND_CENTER.Z - half)
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
	label(itemPart, itemName, 2, 200, Color3.fromRGB(255, 220, 255))
	itemPart.Parent = collectionFolder
end

local function spawnCreature()
	if #collectionFolder:GetChildren() >= MAX_ITEMS then return end

	local itemName = BrainrotRecipes.RollBaseItem()
	local itemPart = ItemVisuals.Create(itemName, randomSpawnPosition(), 1)
	itemPart:SetAttribute("ItemName", itemName)
	label(itemPart, itemName, 2, 200, Color3.fromRGB(255, 220, 255))
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

function Brainrot.RefreshPad(player)
	local s = state[player]
	if not s then return end
	padLabel.Text = string.format("FUSION PAD\n[ %s ]  +  [ %s ]", s.slots[1] or "empty", s.slots[2] or "empty")
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
		dropNearIsland(a)
		dropNearIsland(b)
		toast(player, string.format("%s + %s = nothing. Returned to the island.", a, b))
		return
	end

	if not s.discovered[result] then
		s.discovered[result] = true
		toast(player, string.format(info.isSecret and "SECRET RECIPE\n%s" or "NEW DISCOVERY\n%s", result), true)
	end

	local payout = addCoins(player, info.value)
	toast(player, string.format("%s sold for %d coins.", result, payout))

	if info.tier >= 3 or info.isSecret then
		broadcast(string.format("%s fused %s on Brainrot Island!", player.Name, result))
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
	state[player] = { slots = {}, discovered = discovered }
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
