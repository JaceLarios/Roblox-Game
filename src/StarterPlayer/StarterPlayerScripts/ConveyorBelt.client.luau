--[[
	ConveyorBelt (LocalScript, StarterPlayerScripts) — Junkyard Fusion

	Scrolls the chevrons on the yard's conveyor belt at the belt's own
	speed, so the belt visibly runs the way the scrap on it is going. Purely
	cosmetic and per client: the server moves the scrap (ScrapSpawner), and
	the belt itself is a ring of still parts.
--]]

local RunService = game:GetService("RunService")

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
RunService.RenderStepped:Connect(function(dt)
	offset = (offset - speed * dt) % tile
	for _, texture in ipairs(textures) do
		texture.OffsetStudsV = offset
	end
end)
