-- Also reconstructs the authored map when opening a fresh checkout/build.
local ServerStorage = game:GetService("ServerStorage")
local Map = require(ServerStorage:WaitForChild("SalvageWorksMap"))
local YardFeatures = require(ServerStorage:WaitForChild("YardFeatures"))
Map.Build()
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
