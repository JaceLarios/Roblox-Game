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

-- Golden Scrap removed 2026-09-14 ("its litteary worthless now, get rid
-- of the gold scrap idea in general") — its old role as "the exciting
-- thing to chase" is replaced below by just announcing it when the
-- regular roll itself lands on a naturally rare base item.
-- Anything at or under this weight gets the same "come get it" broadcast
-- Golden Scrap used to have — Jet Engine (3) and Monster Truck (8) both
-- qualify at the current BaseItems weights.
local RARE_SPAWN_WEIGHT_THRESHOLD = 10

-- Hard ceiling on how many addons can be lying in the yard at once.
-- FusionRecipes.AddonSpawnChance sets the long-run rate; this stops the
-- short-run clumping a rate cannot. Four engines inside twenty drops is
-- unremarkable dice, and it reads as the yard being full of engines.
local MAX_ACTIVE_ADDONS = 2
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
	label.TextColor3 = ItemRarity.Color(FusionRecipes.GetTier(itemName), false, FusionRecipes.GetRarity(itemName))
	label.TextStrokeTransparency = 0.4
	label.TextScaled = true
	label.Parent = billboard
end

-- The lowest-weight (rarest) base items — Golden Scrap's old "worth
-- announcing" role, now just surfacing when the regular roll itself
-- lands on something already rare instead of a separate spawn type.
-- Addons need no special case here: the weight bar already lands on the
-- V8 and the Jet Engine and skips the Inline 4 and V6, which is the right
-- line. At a drop every SPAWN_INTERVAL seconds, announcing every addon
-- would fire roughly four times a minute and stop meaning anything.
local function isRareRoll(itemName)
	for _, item in ipairs(FusionRecipes.BaseItems) do
		if item.name == itemName then
			return item.weight <= RARE_SPAWN_WEIGHT_THRESHOLD
		end
	end
	return false
end

local function activeAddonCount()
	local live = 0
	for _, item in ipairs(scrapFolder:GetChildren()) do
		if item:GetAttribute("IsAddon") then
			live += 1
		end
	end
	return live
end

local function spawnScrap()
	-- Respect the cap. Better to skip a drop than lag the server.
	if #scrapFolder:GetChildren() >= MAX_ITEMS then
		return
	end

	local itemName = FusionRecipes.RollSpawn()
	-- Already enough engines out there. Swap in a vehicle rather than
	-- skipping the drop, so the yard stays as busy as it always was.
	if FusionRecipes.IsAddon(itemName) and activeAddonCount() >= MAX_ACTIVE_ADDONS then
		itemName = FusionRecipes.RollBaseItem()
	end
	local position = randomSpawnPosition()

	-- Detailed mesh when one exists in ItemModels, else the old block.
	local part = ItemVisuals.Create(itemName, position, 1)

	-- Stores the item's identity as data, not just a display name.
	-- The fusion pad will read this attribute later, so renaming
	-- the part in Explorer won't break anything.
	part:SetAttribute("ItemName", itemName)
	part:SetAttribute("Tier", 1)
	-- What activeAddonCount() counts. Set on the part rather than tracked
	-- in a table so the despawn timer and any other removal path keep the
	-- tally honest for free.
	part:SetAttribute("IsAddon", FusionRecipes.IsAddon(itemName))

	addLabel(part, itemName)
	part.Parent = scrapFolder

	-- Worth announcing on its own merits — no separate "golden" spawn
	-- type needed to make a rare drop feel exciting. Keep this one (per
	-- the user's own call, "keep the one for when something rare spawns
	-- like a jet engine"); it's the sole surviving world-spawn announcement.
	if isRareRoll(itemName) then
		local rareTag = ItemRarity.Tag(itemName, FusionRecipes.GetTier(itemName), false, FusionRecipes.GetRarity(itemName))
		remote:FireAllClients({
			announce = string.format("%s just dropped in the yard — grab it before it's gone!", rareTag),
		})
		print("[ScrapSpawner] RARE spawn:", itemName)
	else
		print("[ScrapSpawner] Dropped:", itemName)
	end

	-- Clean itself up later. task.delay doesn't block this loop.
	task.delay(DESPAWN_AFTER, function()
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
