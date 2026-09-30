-- Run in Studio Edit mode only, after inspecting the replacement model's pivot and scale.
-- Preserves an existing LogoCover unchanged. Never removes the rear lettering mesh.
local model = game.ReplicatedStorage.ItemModels:FindFirstChild("SVO")
assert(model, "SVO is missing")
if model:FindFirstChild("LogoCover") then
 return "Existing LogoCover preserved"
end
-- A replacement must retain the original pivot convention and Model scale.
-- For an externally resized mesh, adjust ratio to match before running.
local ratio = model:GetScale() / 1
local relative = CFrame.new(0.004000000189989805,0.47269344329833984,-5.734857082366943,1,0,0,0,0.6571351885795593,0.7537727355957031,0,-0.7537727355957031,0.6571351885795593)
relative = CFrame.new(relative.Position * ratio) * relative.Rotation
local cover = Instance.new("Part")
cover.Name = "LogoCover"
cover.Size = Vector3.new(0.5699999928474426,0.12999999523162842,0.00800000037997961) * ratio
cover.CFrame = model:GetPivot() * relative
cover.Color = Color3.new(0.01568627543747425,0.019607843831181526,0.027450980618596077)
cover.Material = Enum.Material.SmoothPlastic
cover.Anchored = true
cover.CanCollide = false
cover.CanTouch = false
cover.CanQuery = false
cover.Massless = true
cover.Parent = model
return "LogoCover restored; visually inspect the rear panel before publishing"

