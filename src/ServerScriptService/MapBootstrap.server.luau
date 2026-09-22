-- Also reconstructs the authored map when opening a fresh checkout/build.
local ServerStorage = game:GetService("ServerStorage")
local Baseline = require(ServerStorage:WaitForChild("MapBaseline"))
local Map = require(ServerStorage:WaitForChild("MapRevamp"))
local YardFeatures = require(ServerStorage:WaitForChild("YardFeatures"))
Baseline.Restore()
Map.Build()
Map.DressYard()
-- The crane, junk piles and container stacks inside the yard. Its own
-- module, so it rebuilds itself whenever its VERSION changes.
YardFeatures.Build()
local plots = workspace:WaitForChild("Plots",30)
if plots then
 local function dress(plot)
  if not plot:IsA("Model") then return end
  task.spawn(function()
   plot:WaitForChild("garageSign",10)
   Map.DressPlot(plot)
  end)
 end
 for _,plot in plots:GetChildren() do dress(plot) end
 plots.ChildAdded:Connect(dress)
end
print("[Map] Foundry District ready.")
