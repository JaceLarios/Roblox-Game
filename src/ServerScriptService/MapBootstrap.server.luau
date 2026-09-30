-- Also reconstructs the authored map when opening a fresh checkout/build.
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Map = require(ServerStorage:WaitForChild("SalvageWorksMap"))
local YardFeatures = require(ServerStorage:WaitForChild("YardFeatures"))
local Layout = require(ReplicatedStorage:WaitForChild("JunkyardLayout"))
Map.Build()

-- An invisible wall all the way round the island, standing in the
-- perimeter fence (which is only decoration), like the invisible walls down
-- the laser roads' shoulders: nobody walks past the fence onto the banks,
-- trees and cliffs. Tall enough that a bat hit cannot launch anyone over.
do
	local HEIGHT, SEGMENTS = 40, 96
	local old = workspace:FindFirstChild("IslandBorder")
	if old then old:Destroy() end
	-- Always on every player's screen: their own client moves their
	-- character, so a wall that has not streamed in would not stop them.
	local folder = Instance.new("Model")
	folder.Name = "IslandBorder"
	folder.ModelStreamingMode = Enum.ModelStreamingMode.Persistent
	local radius = Layout.IslandBorderRadius
	local step = math.pi * 2 / SEGMENTS
	-- Each wall is one side of a 96-sided ring, a little long so the
	-- corners overlap and leave no gap.
	local length = 2 * radius * math.tan(step / 2) + 0.5
	for i = 0, SEGMENTS - 1 do
		local out = Vector3.new(math.cos(i * step), 0, math.sin(i * step))
		local centre = out * radius + Vector3.new(0, HEIGHT / 2, 0)
		local wall = Instance.new("Part")
		wall.Name = "Border"
		wall.Anchored = true
		-- X along the fence, Z (its thickness) facing out from the middle.
		wall.Size = Vector3.new(length, HEIGHT, 1)
		wall.CFrame = CFrame.lookAt(centre, centre + out)
		wall.Transparency = 1
		wall.CanCollide = true
		wall.CanQuery = false
		wall.CanTouch = false
		wall.CastShadow = false
		wall.Parent = folder
	end
	folder.Parent = workspace
end

-- The crane, junk piles and container stacks inside the yard. Its own
-- module, so it rebuilds itself whenever its VERSION changes.
YardFeatures.Build()
Map.DressYard()
local plots = workspace:WaitForChild("Plots",30)
if plots then
 local function dress(plot)
  if not plot:IsA("Model") then return end
  task.spawn(function()
   plot:WaitForChild("Ground",10)
   Map.DressPlot(plot)
  end)
 end
 for _,plot in plots:GetChildren() do dress(plot) end
 plots.ChildAdded:Connect(dress)
end
print("[Map] Open Salvage Works ready.")
