--[[
	ScrapSpawner (Script, ServerScriptService) — Junkyard Fusion v1
	Drops a random Tier 1 item into the yard every few seconds.
	Server-only on purpose: the server decides what spawns, never the client.
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local FusionRecipes = require(ReplicatedStorage:WaitForChild("FusionRecipes"))
local ItemVisuals = require(ReplicatedStorage:WaitForChild("ItemVisuals"))
local ItemRarity = require(ReplicatedStorage:WaitForChild("ItemRarity"))

-- Shared with PlotManager and the client UI.
local remote = ReplicatedStorage:FindFirstChild("GameUpdate")
if not remote then
	remote = Instance.new("RemoteEvent")
	remote.Name = "GameUpdate"
	remote.Parent = ReplicatedStorage
end

-- ---------- Tuning knobs. Change these, not the code below. ----------
local SPAWN_INTERVAL = 2      -- seconds between drops
local DESPAWN_AFTER  = 45     -- seconds before an ignored item disappears
local MAX_ITEMS      = 45     -- hard cap, so the yard never floods
local AREA_CENTER    = Vector3.new(0, 1.2, 0)  -- Y is the yard's ground surface, not an item's center
local AREA_SIZE      = 130    -- studs wide/deep (the central shared yard)

-- Golden scrap: the event that makes the shared yard competitive.
-- One spawn in 40 at a 2s interval works out to roughly every 80 seconds.
local GOLDEN_CHANCE  = 0.025
local GOLDEN_DESPAWN = 20     -- short, so it's a sprint and not a stroll
-- ---------------------------------------------------------------------

-- All spawned scrap lives in one folder. Keeps Explorer readable
-- and makes counting items trivial.
local scrapFolder = workspace:FindFirstChild("Scrap")
if not scrapFolder then
	scrapFolder = Instance.new("Folder")
	scrapFolder.Name = "Scrap"
	scrapFolder.Parent = workspace
end

-- Picks a random spot inside the square defined above.
local function randomSpawnPosition()
	local half = AREA_SIZE / 2
	local x = AREA_CENTER.X + math.random(-half, half)
	local z = AREA_CENTER.Z + math.random(-half, half)
	return Vector3.new(x, AREA_CENTER.Y, z)
end

-- Floating name tag so you can tell items apart while testing.
local function addLabel(part, itemName)
	local billboard = Instance.new("BillboardGui")
	billboard.Size = UDim2.new(0, 150, 0, 32)
	billboard.StudsOffset = Vector3.new(0, 2, 0)
	billboard.AlwaysOnTop = true
	-- Billboards hold a constant SCREEN size regardless of distance, so
	-- without a cutoff every drop across the whole yard stays fully
	-- legible at once and piles into an unreadable wall of text.
	billboard.MaxDistance = 45
	billboard.Parent = part

	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 1, 0)
	label.BackgroundTransparency = 1
	label.Text = itemName
	label.TextColor3 = itemName == "GOLDEN SCRAP"
		and ItemRarity.GoldenScrapColor()
		or ItemRarity.Color(FusionRecipes.GetTier(itemName), false)
	label.TextStrokeTransparency = 0.4
	label.TextScaled = true
	label.Parent = billboard
end

local function spawnScrap()
	-- Respect the cap. Better to skip a drop than lag the server.
	if #scrapFolder:GetChildren() >= MAX_ITEMS then
		return
	end

	local isGolden = math.random() < GOLDEN_CHANCE
	local itemName = isGolden and "GOLDEN SCRAP" or FusionRecipes.RollBaseItem()
	local position = randomSpawnPosition()

	local part
	if isGolden then
		local goldenSize = Vector3.new(6, 3, 8)
		part = Instance.new("Part")
		part.Name = itemName
		part.Size = goldenSize
		-- Doesn't go through ItemVisuals.Create, so it needs the same
		-- surface-to-center offset applied by hand.
		part.Position = Vector3.new(position.X, position.Y + goldenSize.Y / 2, position.Z)
		part.Anchored = true          -- v1: no physics. Simpler and cheaper.
		part.Material = Enum.Material.Neon
		part.Color = Color3.fromRGB(255, 205, 60)
	else
		-- Detailed mesh when one exists in ItemModels, else the old block.
		part = ItemVisuals.Create(itemName, position, 1)
	end

	-- Stores the item's identity as data, not just a display name.
	-- The fusion pad will read this attribute later, so renaming
	-- the part in Explorer won't break anything.
	part:SetAttribute("ItemName", itemName)
	part:SetAttribute("Tier", 1)
	if isGolden then
		part:SetAttribute("Golden", true)
	end

	addLabel(part, itemName)
	part.Parent = scrapFolder

	if isGolden then
		-- A beacon so people can find it from across the map.
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 205, 60)
		light.Range = 60
		light.Brightness = 5
		light.Parent = part

		local beam = Instance.new("Part")
		beam.Name = "GoldenBeacon"
		beam.Size = Vector3.new(3, 300, 3)
		beam.Position = part.Position + Vector3.new(0, 150, 0)
		beam.Anchored = true
		beam.CanCollide = false
		beam.Material = Enum.Material.Neon
		beam.Color = Color3.fromRGB(255, 205, 60)
		beam.Transparency = 0.6
		beam.Parent = part

		remote:FireAllClients({
			announce = "GOLDEN SCRAP has appeared in the yard — first one there keeps it!",
		})
		print("[ScrapSpawner] GOLDEN SCRAP spawned at", part.Position)
	else
		print("[ScrapSpawner] Dropped:", itemName)
	end

	-- Clean itself up later. task.delay doesn't block this loop.
	task.delay(isGolden and GOLDEN_DESPAWN or DESPAWN_AFTER, function()
		if part and part.Parent then
			part:Destroy()
		end
	end)
end

print("[ScrapSpawner] Running. Dropping scrap every", SPAWN_INTERVAL, "seconds.")

while true do
	spawnScrap()
	task.wait(SPAWN_INTERVAL)
end
