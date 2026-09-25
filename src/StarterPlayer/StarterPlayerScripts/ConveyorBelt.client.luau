--[[
	ConveyorBelt (LocalScript, StarterPlayerScripts) — Junkyard Fusion

	Scrolls the chevrons on the yard's conveyor belt at the belt's own
	speed, so the belt visibly runs the way the scrap on it is going. Purely
	cosmetic and per client: the server moves the scrap (ScrapSpawner), and
	the belt itself is a ring of still parts.

	Also turns the wheels of the cars riding it, by how far each one moved
	since the last frame. That is done here and not on the server, which
	would send every wheel's new angle to every player every frame (about
	ten thousand updates a second with the belt full).
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local ItemVisuals = require(ReplicatedStorage:WaitForChild("ItemVisuals"))

local folder = workspace:WaitForChild("YardConveyor")
local speed = folder:GetAttribute("Speed") or 8
local tile = folder:GetAttribute("TextureTile") or 5

local textures = {}
for _, d in ipairs(folder:GetDescendants()) do
	if d:IsA("Texture") and d.Name == "BeltChevrons" then
		table.insert(textures, d)
	end
end

-- A growing OffsetStudsV slides the chevrons toward the segment's +Z, which
-- is backwards along the belt (segments look the way it runs), so this
-- counts down.
local offset = 0
-- The cars on the belt, and where each was last frame. A car being
-- grabbed flies to the player and is not rolled; a bigger jump than
-- MAX_ROLL in one frame is a teleport.
local scrap = workspace:WaitForChild("Scrap")
local MAX_ROLL = 4
local lastPosition = {}

local function track(item)
	if item:IsA("BasePart") and item:GetAttribute("ItemAssembly") then
		lastPosition[item] = item.Position
	end
end
for _, item in ipairs(scrap:GetChildren()) do
	track(item)
end
scrap.ChildAdded:Connect(track)
scrap.ChildRemoved:Connect(function(item)
	lastPosition[item] = nil
end)

RunService.RenderStepped:Connect(function(dt)
	offset = (offset - speed * dt) % tile
	for _, texture in ipairs(textures) do
		texture.OffsetStudsV = offset
	end

	for item, was in pairs(lastPosition) do
		local now = item.Position
		local moved = now - was
		lastPosition[item] = now
		local distance = moved.Magnitude
		if distance > 0 and distance < MAX_ROLL and not item:GetAttribute("Collected") then
			ItemVisuals.RollWheels(item, moved:Dot(item.CFrame.ZVector))
		end
	end
end)
