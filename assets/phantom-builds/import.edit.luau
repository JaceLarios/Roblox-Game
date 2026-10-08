--[[
	Phantom builds: import into Studio (Edit mode), after build_builds.py.

	Serve this folder on http://127.0.0.1:8768/ first. For each build, the
	base car's own parts are copied from its model in ItemModels (same
	geometry, checked by size and position) and repainted in the haunted
	livery; only the addon's new parts are uploaded as Mesh assets
	(AssetService:CreateAssetAsync), and reused by GeometryHash on a second
	run. Wheel parts keep WheelId / WheelPivot / WheelRadius, the addon's
	rolling parts (the Wraith Crusher's wheel fire) get their wheel's, and the
	model is recentred like assets/remaining-fusions/import.edit.luau. Builds
	go to a new ServerStorage.PhantomBuilds_Staging_<time> folder; nothing in
	ItemModels changes here (install.edit.luau). Runs in the background: poll
	_G.PhantomBuildImport (done, errors, finished).
--]]
assert(not game:GetService('RunService'):IsRunning(), 'Stop Play before importing')
local AS = game:GetService('AssetService')
local H = game:GetService('HttpService')
local BASE = 'http://127.0.0.1:8768/'
local REVISION = 'PhantomBuilds_20261008_v1'
local templates = game.ReplicatedStorage.ItemModels

local previousHttp = H.HttpEnabled
H.HttpEnabled = true
local stage = Instance.new('Folder')
stage.Name = 'PhantomBuilds_Staging_' .. os.time()
stage.Parent = game.ServerStorage
local state = { stage = stage.Name, done = {}, errors = {}, active = '', uploads = 0, reused = 0, copied = 0, finished = false }
_G.PhantomBuildImport = state

local cache = {}
for _, p in game:GetDescendants() do
	if p:IsA('MeshPart') and p.MeshId ~= '' and p:GetAttribute('GeometryHash') then cache[p:GetAttribute('GeometryHash')] = p end
end

local function srgb(v) return v <= .0031308 and v * 12.92 or 1.055 * v ^ (1 / 2.4) - .055 end
local function vec(t) return Vector3.new(t[1], t[2], t[3]) end

-- The look of a material: `kind` (build_phantoms.py) for the ghost
-- materials, else its `finish` like every other vehicle part.
local function dress(p, m)
	local co = m.color
	p.Color = Color3.new(srgb(co[1]), srgb(co[2]), srgb(co[3]))
	p.Material = Enum.Material.SmoothPlastic
	p.MaterialVariant = ''
	p.Transparency = 0
	p.Reflectance = 0
	local kind, finish = m.kind, m.finish
	if kind == 'neon' or finish == 'Light' then
		p.Material = Enum.Material.Neon
	elseif kind == 'mist' then
		p.Material = Enum.Material.Neon; p.Transparency = .5
	elseif kind == 'ghost' then
		p.Transparency = 1 - m.alpha
	elseif kind == 'glass' then
		p.Material = Enum.Material.Glass; p.Transparency = .55
	elseif kind == 'wood' then
		p.Material = Enum.Material.Wood
	elseif kind == 'slate' then
		p.Material = Enum.Material.Slate
	elseif finish then
		local variant = finish == 'Carbon' and 'AddonCarbonTwill' or 'AddonDetail_' .. finish .. '_v2'
		assert(game.MaterialService:FindFirstChild(variant), 'Missing material variant ' .. variant)
		p.MaterialVariant = variant
	end
end

local function upload(build, part, center)
	local cached = cache[part.geometryHash]
	if cached and cached.Parent then
		state.reused += 1
		local p = cached:Clone(); p:ClearAllChildren()
		for k in p:GetAttributes() do p:SetAttribute(k, nil) end
		return p
	end
	local em = assert(AS:CreateEditableMesh(), 'EditableMesh unavailable')
	local ok, result = xpcall(function()
		local verts, normals = {}, {}
		for i, v in part.vertices do
			verts[i] = em:AddVertex(vec(v) - center)
			normals[i] = em:AddNormal(vec(part.normals[i]))
		end
		for _, t in part.triangles do
			local a, b, c = t[1] + 1, t[2] + 1, t[3] + 1
			local f = em:AddTriangle(verts[a], verts[b], verts[c]); em:SetFaceNormals(f, { normals[a], normals[b], normals[c] })
		end
		local id, lastError
		for attempt = 1, 5 do
			local success, status, assetId = pcall(function()
				return AS:CreateAssetAsync(em, Enum.AssetType.Mesh, { Name = build .. ' - ' .. part.name, Description = 'Junkyard Fusion Phantom build geometry (Blender, assets/phantom-builds)' })
			end)
			if success and tostring(status):find('Success') then id = assetId break end
			lastError = tostring(status); task.wait(attempt * 3)
		end
		assert(id, lastError); state.uploads += 1
		for attempt = 1, 8 do
			local loaded, p = pcall(function() return AS:CreateMeshPartAsync(Content.fromUri('rbxassetid://' .. id)) end)
			if loaded then p:SetAttribute('MeshAssetId', id) return p end
			lastError = tostring(p); task.wait(math.min(attempt * 2, 10))
		end
		error(lastError)
	end, debug.traceback)
	em:Destroy()
	assert(ok, result)
	return result
end

local function build(entry)
	local d = H:JSONDecode(H:GetAsync(BASE .. entry.file))
	local source = assert(templates:FindFirstChild(d.base), 'Base car missing from ItemModels: ' .. d.base)
	local sourceCenter = source:GetBoundingBox().Position
	local m = Instance.new('Model'); m.Name = d.name
	for k, v in { DisplayName = d.displayName, NoseAxis = d.noseAxis, VisualRevision = REVISION, ClaudeModelRevision = REVISION,
		FusionBase = d.base, FusionAddon = d.addon, Rarity = d.rarity, ExpectedWheels = d.expectedWheels,
		AuthoredComponents = d.authoredComponents } do m:SetAttribute(k, v) end
	for _, part in d.parts do
		local p
		local center = vec(part.center or { 0, 0, 0 })
		if part.clone then
			local original = assert(source:FindFirstChild(part.name), d.base .. ' has no part ' .. part.name)
			assert((original.Size - vec(part.size)).Magnitude < .02, 'Size differs: ' .. d.base .. '.' .. part.name)
			assert((original.Position - sourceCenter - center).Magnitude < .02, 'Position differs: ' .. d.base .. '.' .. part.name)
			p = original:Clone(); p:ClearAllChildren()
			for k in p:GetAttributes() do p:SetAttribute(k, nil) end
			p:SetAttribute('CopiedFrom', d.base)
			if part.material then dress(p, part.material) end
			state.copied += 1
		else
			local lo = Vector3.new(math.huge, math.huge, math.huge); local hi = -lo
			for _, v in part.vertices do local q = vec(v); lo = lo:Min(q); hi = hi:Max(q) end
			center = (lo + hi) / 2
			p = upload(d.name, part, center)
			dress(p, part.material)
			if part.name:find('Chrome') then p.Reflectance = .08 end
			p:SetAttribute('GeometryHash', part.geometryHash)
			p:SetAttribute('AuthoredComponents', #part.components)
			cache[part.geometryHash] = p
		end
		p.Name = part.name
		p.CFrame = CFrame.new(center)
		p.Anchored = true; p.CanCollide = false; p.CanTouch = false; p.CanQuery = false; p.Massless = true; p.DoubleSided = true
		p:SetAttribute('TriangleCount', part.triangles and (type(part.triangles) == 'number' and part.triangles or #part.triangles) or 0)
		if part.wheel then
			p:SetAttribute('WheelId', part.wheel.id); p:SetAttribute('WheelPivot', vec(part.wheel.pivot)); p:SetAttribute('WheelRadius', part.wheel.radius)
		end
		p.Parent = m
	end
	local cf, size = m:GetBoundingBox()
	assert((size - vec(d.targetSize)).Magnitude < .06, 'Wrong imported size for ' .. d.name .. ': ' .. tostring(size))
	m:PivotTo(CFrame.new(-cf.Position) * m:GetPivot())
	for _, p in m:GetChildren() do
		local w = p:GetAttribute('WheelPivot'); if w then p:SetAttribute('WheelPivot', w - cf.Position) end
	end
	m:SetAttribute('WheelPivotRecentered', true)
	m.Parent = stage
	table.insert(state.done, { name = d.name, parts = #m:GetChildren(), size = { size.X, size.Y, size.Z } })
end

task.spawn(function()
	local ok, err = xpcall(function()
		local manifest = H:JSONDecode(H:GetAsync(BASE .. 'manifest.json'))
		for _, entry in manifest do
			state.active = entry.name
			build(entry)
		end
	end, debug.traceback)
	if not ok then table.insert(state.errors, err) end
	H.HttpEnabled = previousHttp
	state.active = ''; state.finished = true
end)
return stage.Name
