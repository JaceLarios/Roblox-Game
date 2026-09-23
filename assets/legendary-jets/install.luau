-- Run in Studio Edit mode after build.luau. Never overwrites existing work.
assert(not game:GetService("RunService"):IsRunning(), "Stop Play first")
local templates = game.ReplicatedStorage:WaitForChild("ItemModels")
local stage = assert(game.ServerStorage:FindFirstChild("LegendaryBuildStaging_20260923"), "Run build.luau first")
local names = {"Rocket Rider", "Afterburner GT", "Sky Marshal"}
for _, name in ipairs(names) do
    assert(not templates:FindFirstChild(name), "Existing template preserved: " .. name)
    local model = assert(stage:FindFirstChild(name), "Missing staged model: " .. name)
    assert(model:IsA("Model"), "Expected Model: " .. name)
    local _, size = model:GetBoundingBox()
    assert(math.abs(math.max(size.X, size.Y, size.Z) - 7) < .01, "Unexpected bounds: " .. name)
    assert(model:GetAttribute("CodexModelRevision") == "LegendaryJetFusions_20260923")
end
for _, name in ipairs(names) do stage[name].Parent = templates end
stage:Destroy()
print("Installed Rocket Rider, Afterburner GT, and Sky Marshal")
