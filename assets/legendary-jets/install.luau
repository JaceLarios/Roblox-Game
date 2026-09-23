-- Run in Studio Edit mode after build.luau. Preserves the previous jet build.
assert(not game:GetService("RunService"):IsRunning(), "Stop Play first")
local templates = game.ReplicatedStorage:WaitForChild("ItemModels")
local stage = assert(game.ServerStorage:FindFirstChild("LegendaryBuildStaging_20260923"), "Run build.luau first")
local names = {"Rocket Rider", "Afterburner GT", "Sky Marshal"}
for _, name in ipairs(names) do
    local old = templates:FindFirstChild(name)
    assert(not old or old:GetAttribute("CodexModelRevision") == "LegendaryJetFusions_20260923", "Unexpected existing revision preserved: " .. name)
    local model = assert(stage:FindFirstChild(name), "Missing staged model: " .. name)
    assert(model:IsA("Model"), "Expected Model: " .. name)
    local _, size = model:GetBoundingBox()
    assert(math.abs(math.max(size.X, size.Y, size.Z) - 7) < .01, "Unexpected bounds: " .. name)
    assert(model:GetAttribute("CodexModelRevision") == "LegendaryJetFusions_20260923_v2")
end
local backup = Instance.new("Folder")
backup.Name = "LegendaryJetBackup_" .. tostring(os.time())
backup.Parent = game.ServerStorage
for _, name in ipairs(names) do
    local old = templates:FindFirstChild(name)
    if old then old.Parent = backup end
    stage[name].Parent = templates
end
stage:Destroy()
print("Installed Rocket Rider, Afterburner GT, and Sky Marshal")
