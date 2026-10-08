--[[
	Phantom addons: install (Edit mode), after import.edit.luau finished.
	Moves the 15 staged models into ReplicatedStorage.ItemModels (any
	same-named model there first goes to a ServerStorage backup), then checks
	each one the way the game uses it: its model is found, a viewport copy
	(shop, Index, hotbar) and a world copy (pads, held item) both build.
	Rolls everything back if a check fails.
--]]
assert(not game:GetService('RunService'):IsRunning(), 'Stop Play first')
local state = assert(_G.PhantomAddonImport, 'Run import.edit.luau first')
assert(state.finished and #state.errors == 0 and #state.done == 15, 'Import not ready')
local stage = assert(game.ServerStorage:FindFirstChild(state.stage))
local recipes = require(game.ReplicatedStorage.FusionRecipes)
local destination = game.ReplicatedStorage.ItemModels

for _, item in state.done do
	local m = assert(stage:FindFirstChild(item.name), item.name)
	assert(recipes.BoltPrice(item.name), 'Not a Phantom addon: ' .. item.name)
	for _, p in m:GetDescendants() do
		assert(not p:IsA('LuaSourceContainer'))
		if p:IsA('BasePart') then assert(p:IsA('MeshPart') and p.MeshId ~= '' and p.Anchored and not p.CanCollide and p.Massless, p:GetFullName()) end
	end
end

local backup = Instance.new('Folder'); backup.Name = 'PhantomAddons_BeforeInstall_' .. os.time(); backup.Parent = game.ServerStorage
local installed = {}
for _, item in state.done do
	local old = destination:FindFirstChild(item.name)
	if old then old.Parent = backup end
	local m = stage[item.name]; m.Parent = destination; table.insert(installed, m)
end

local report = { backup = backup.Name, models = {} }
local ok, err = xpcall(function()
	local visuals = require(game.ReplicatedStorage.ItemVisuals)
	for _, m in installed do
		assert(not visuals.IsGhostStandIn(m.Name), 'Still drawn as a stand-in: ' .. m.Name)
		local view, size = visuals.CloneForViewport(m.Name); assert(view and size.Magnitude > 0); view:Destroy()
		local root = visuals.Create(m.Name, Vector3.new(0, 10000, 0), 1)
		assert(root:GetAttribute('ItemAssembly') and root:FindFirstChild('Visual'))
		local joints = 0; for _, v in root:GetChildren() do if v:IsA('Weld') then joints += 1 end end
		root:Destroy(); assert(joints == #m:GetChildren(), 'Weld count ' .. m.Name)
		local triangles = 0; for _, p in m:GetChildren() do triangles += p:GetAttribute('TriangleCount') or 0 end
		local _, bounds = m:GetBoundingBox()
		table.insert(report.models, { name = m.Name, parts = #m:GetChildren(), triangles = triangles, size = { bounds.X, bounds.Y, bounds.Z } })
	end
end, debug.traceback)
if not ok then
	for _, m in installed do m.Parent = stage end
	for _, m in backup:GetChildren() do m.Parent = destination end
	error('Rolled back Phantom addon install: ' .. err)
end
stage:Destroy()
if #backup:GetChildren() == 0 then backup:Destroy(); report.backup = nil end
_G.PhantomAddonInstall = report
return game:GetService('HttpService'):JSONEncode(report)
