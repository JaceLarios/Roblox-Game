--[[
	Phantom addons: import into Studio (Edit mode). Same shape as
	assets/new-addons/import-staging.edit.luau.

	Serve this folder on http://127.0.0.1:8766/ first. Each addon's JSON
	part becomes an EditableMesh, is uploaded as a Mesh asset
	(AssetService:CreateAssetAsync) and turned into a MeshPart, coloured and
	textured like the other addons (the AddonDetail material variants), in a
	new ServerStorage.PhantomAddons_Staging_<time> folder. Nothing in
	ItemModels is touched here; install.edit.luau moves them in. Runs in the
	background: poll _G.PhantomAddonImport (done, errors, finished).
--]]
assert(not game:GetService('RunService'):IsRunning(), 'Stop Play before importing')
local AS = game:GetService('AssetService')
local H = game:GetService('HttpService')
local BASE = 'http://127.0.0.1:8766/'
local REVISION = 'PhantomAddons_20261008_v1'

local previousHttp = H.HttpEnabled
H.HttpEnabled = true
local stage = Instance.new('Folder')
stage.Name = 'PhantomAddons_Staging_' .. os.time()
stage.Parent = game.ServerStorage
local state = { stage = stage.Name, done = {}, errors = {}, active = '', uploads = 0, finished = false }
_G.PhantomAddonImport = state

local function srgb(v) return v <= .0031308 and v * 12.92 or 1.055 * v ^ (1 / 2.4) - .055 end

-- Each material's look in Roblox, by its `kind` (build_phantoms.py).
local VARIANT = {
	Iron = 'AddonDetail_Cast_v2', Chrome = 'AddonDetail_Brushed_v2', Gold = 'AddonDetail_Brushed_v2',
	Violet = 'AddonDetail_Enamel_v2', DeepViolet = 'AddonDetail_Enamel_v2', Red = 'AddonDetail_Enamel_v2',
	Rubber = 'AddonDetail_Rubber_v2',
}
local function dress(p, partName, m)
	local co = m.color
	p.Color = Color3.new(srgb(co[1]), srgb(co[2]), srgb(co[3]))
	p.Material = Enum.Material.SmoothPlastic
	p.MaterialVariant = ''
	p.Transparency = 0
	local kind = m.kind
	if kind == 'neon' then
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
	elseif VARIANT[partName] and game.MaterialService:FindFirstChild(VARIANT[partName]) then
		p.MaterialVariant = VARIANT[partName]
	end
	p.Reflectance = partName == 'Chrome' and .08 or 0
end

local function upload(name, part)
	local em = assert(AS:CreateEditableMesh(), 'EditableMesh unavailable')
	local ok, result = xpcall(function()
		local verts, normals = {}, {}
		for i, v in part.vertices do
			verts[i] = em:AddVertex(Vector3.new(v[1], v[2], v[3]))
			local n = part.normals[i]; normals[i] = em:AddNormal(Vector3.new(n[1], n[2], n[3]))
		end
		for _, t in part.triangles do
			local a, b, c = t[1] + 1, t[2] + 1, t[3] + 1
			local f = em:AddTriangle(verts[a], verts[b], verts[c]); em:SetFaceNormals(f, { normals[a], normals[b], normals[c] })
		end
		local id, lastError
		for attempt = 1, 5 do
			local success, status, assetId = pcall(function()
				return AS:CreateAssetAsync(em, Enum.AssetType.Mesh, { Name = name .. ' - ' .. part.name, Description = 'Junkyard Fusion Phantom addon geometry (Blender, assets/phantom-addons)' })
			end)
			if success and tostring(status):find('Success') then id = assetId break end
			lastError = success and tostring(status) or tostring(status); task.wait(attempt * 3)
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

task.spawn(function()
	local ok, err = xpcall(function()
		local manifest = H:JSONDecode(H:GetAsync(BASE .. 'manifest.json'))
		for _, entry in manifest do
			state.active = entry.name
			local data = H:JSONDecode(H:GetAsync(BASE .. entry.file))
			local m = Instance.new('Model'); m.Name = data.name
			m:SetAttribute('DisplayName', data.name); m:SetAttribute('IsAddon', true); m:SetAttribute('Rarity', 'spectral')
			m:SetAttribute('PhantomGroup', data.group); m:SetAttribute('VisualRevision', REVISION)
			m:SetAttribute('ClaudeModelRevision', REVISION); m:SetAttribute('AuthoredComponents', data.authoredComponents)
			for _, part in data.parts do
				local p = upload(data.name, part)
				p.Name = part.name
				dress(p, part.name, part.material)
				p.Anchored = true; p.CanCollide = false; p.CanTouch = false; p.CanQuery = false; p.Massless = true; p.DoubleSided = true
				p:SetAttribute('AuthoredComponents', #part.components); p:SetAttribute('TriangleCount', #part.triangles)
				local lo = Vector3.new(math.huge, math.huge, math.huge); local hi = -lo
				for _, v in part.vertices do local q = Vector3.new(v[1], v[2], v[3]); lo = lo:Min(q); hi = hi:Max(q) end
				p.CFrame = CFrame.identity
				p.CFrame += (lo + hi) / 2 - p.ExtentsCFrame.Position
				p.Parent = m
			end
			local cf, size = m:GetBoundingBox(); m:PivotTo(CFrame.new(-cf.Position) * m:GetPivot())
			local maxdim = math.max(size.X, size.Y, size.Z)
			assert(math.abs(maxdim - data.targetMax) < .03, 'Wrong imported size for ' .. data.name .. ': ' .. tostring(size))
			m:SetAttribute('ReferenceMaxDimension', data.targetMax)
			m.Parent = stage
			table.insert(state.done, { name = data.name, parts = #m:GetChildren(), size = { size.X, size.Y, size.Z } })
		end
	end, debug.traceback)
	if not ok then table.insert(state.errors, err) end
	H.HttpEnabled = previousHttp
	state.active = ''; state.finished = true
end)
return stage.Name
