--[[
	Phantom builds: install (Edit mode), after import.edit.luau finished.
	Checks each staged build is its recipe's Spectral result with all its
	wheels and under the 90,000 triangle budget, moves it into
	ReplicatedStorage.ItemModels (any same-named model first goes to a
	ServerStorage backup), then checks it the way the game uses it: no longer
	a ghostly stand-in, a viewport copy builds, a world copy builds, its wheels
	roll and it resizes. Rolls everything back if a check fails.
--]]
assert(not game:GetService('RunService'):IsRunning(), 'Stop Play first')
local state = assert(_G.PhantomBuildImport, 'Run import.edit.luau first')
assert(state.finished and #state.errors == 0, 'Import not ready')
local stage = assert(game.ServerStorage:FindFirstChild(state.stage))
local recipes = require(game.ReplicatedStorage.FusionRecipes)
local visuals = require(game.ReplicatedStorage.ItemVisuals)
local destination = game.ReplicatedStorage.ItemModels

local models = stage:GetChildren()
assert(#models == #state.done and #models > 0, 'Staging folder does not match the import')
for _, m in models do
	assert(recipes.Fuse(m:GetAttribute('FusionBase'), m:GetAttribute('FusionAddon')) == m.Name, 'Recipe mismatch ' .. m.Name)
	assert(recipes.GetRarity(m.Name) == 'spectral' and m:GetAttribute('Rarity') == 'spectral', 'Not Spectral: ' .. m.Name)
	local wheels, triangles = {}, 0
	for _, p in m:GetDescendants() do
		assert(not p:IsA('LuaSourceContainer'))
		if p:IsA('BasePart') then
			assert(p:IsA('MeshPart') and p.MeshId ~= '' and p.Anchored and not p.CanCollide and p.Massless, p:GetFullName())
			triangles += p:GetAttribute('TriangleCount') or 0
			local id = p:GetAttribute('WheelId')
			if id then assert(typeof(p:GetAttribute('WheelPivot')) == 'Vector3' and p:GetAttribute('WheelRadius') > 0); wheels[id] = true end
		end
	end
	local count = 0; for _ in wheels do count += 1 end
	assert(count == m:GetAttribute('ExpectedWheels'), 'Wheel count ' .. m.Name)
	assert(triangles < 90000, 'Geometry budget ' .. m.Name)
end

local backup = Instance.new('Folder'); backup.Name = 'PhantomBuilds_BeforeInstall_' .. os.time(); backup.Parent = game.ServerStorage
local installed = {}
for _, m in models do
	local old = destination:FindFirstChild(m.Name)
	if old then old.Parent = backup end
	m.Parent = destination; table.insert(installed, m)
end

local report = { backup = backup.Name, models = {} }
local ok, err = xpcall(function()
	for _, m in installed do
		assert(not visuals.IsGhostStandIn(m.Name), 'Still drawn as a stand-in: ' .. m.Name)
		local view, size = visuals.CloneForViewport(m.Name); assert(view and size.Magnitude > 0); view:Destroy()
		local item = visuals.Create(m.Name, Vector3.new(0, 10000, 0), 1)
		local before = {}
		for _, j in item:GetChildren() do if j:IsA('Weld') and j.Part1:GetAttribute('WheelPivot') then before[j] = j.C0 end end
		visuals.RollWheels(item, .45)
		local moved = 0; for j, cf in before do if j.C0 ~= cf then moved += 1 end end
		assert(moved > 0, 'Wheels did not move ' .. m.Name)
		visuals.Resize(item, item.Size * .75); item:Destroy()
		local triangles = 0; for _, p in m:GetChildren() do triangles += p:GetAttribute('TriangleCount') or 0 end
		local _, bounds = m:GetBoundingBox()
		table.insert(report.models, { name = m.Name, parts = #m:GetChildren(), triangles = triangles, wheelPartsMoved = moved, size = { bounds.X, bounds.Y, bounds.Z } })
	end
end, debug.traceback)
if not ok then
	for _, m in installed do m.Parent = stage end
	for _, m in backup:GetChildren() do m.Parent = destination end
	error('Rolled back Phantom build install: ' .. err)
end
stage:Destroy()
if #backup:GetChildren() == 0 then backup:Destroy(); report.backup = nil end
_G.PhantomBuildInstall = report
return game:GetService('HttpService'):JSONEncode(report)
