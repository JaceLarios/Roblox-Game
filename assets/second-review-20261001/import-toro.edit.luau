assert(not game:GetService('RunService'):IsRunning())
local H=game.HttpService;local AS=game.AssetService;local old=game.ReplicatedStorage.ItemModels.Toro
local prior=_G.ToroBadgeImport
local stage=prior and game.ServerStorage:FindFirstChild(prior.stage)
if not stage then stage=old:Clone();stage.Name='Toro_BadgeRemoval_Staging';stage.Parent=game.ServerStorage end
local previous=H.HttpEnabled;H.HttpEnabled=true
local state={done=prior and prior.done or 0,errors={},finished=false,stage=stage.Name};_G.ToroBadgeImport=state
task.spawn(function()
 local ok,err=xpcall(function()
  local root='http://127.0.0.1:18769/second-review-20261001/'
  local manifest=H:JSONDecode(H:GetAsync(root..'toro-manifest.json'))
  for index,record in manifest.parts do
   if index<=state.done then continue end
   local p=assert(stage:FindFirstChild(record.name));local reference=old[record.name]
   if record.originalTriangles>120 then
    local d=H:JSONDecode(H:GetAsync(root..record.file));local em=assert(AS:CreateEditableMesh())
    local success,result=xpcall(function()
     local vs,ns,us={},{},{}
     for i,v in d.vertices do vs[i]=em:AddVertex(Vector3.new(unpack(v)));ns[i]=em:AddNormal(Vector3.new(unpack(d.normals[i])));us[i]=em:AddUV(Vector2.new(unpack(d.uvs[i])))end
     for _,t in d.triangles do local a,b,c=t[1]+1,t[2]+1,t[3]+1;local f=em:AddTriangle(vs[a],vs[b],vs[c]);em:SetFaceNormals(f,{ns[a],ns[b],ns[c]});em:SetFaceUVs(f,{us[a],us[b],us[c]})end
     local id,lastError
     for attempt=1,5 do
      local good,status,asset=pcall(function()return AS:CreateAssetAsync(em,Enum.AssetType.Mesh,{Name='Toro optimized part '..index,Description='Optimized existing modified model; original attribution unchanged'})end)
      if good and tostring(status):find('Success')then id=asset;break end;lastError=tostring(status)..' '..tostring(asset);task.wait(attempt*5)
     end
     assert(id,'Upload failed '..record.name..' '..tostring(lastError))
     for attempt=1,8 do local good,part=pcall(function()return AS:CreateMeshPartAsync(Content.fromUri('rbxassetid://'..id))end);if good then return part end;task.wait(attempt*2)end
     error('Mesh loading failed')
    end,debug.traceback)
    em:Destroy();assert(success,result)
    local cf,size=p.CFrame,p.Size;local texture=p.TextureID
    p:ApplyMesh(result);result:Destroy();p.Size=size;p.CFrame=cf;p.TextureID=texture
   end
   p:SetAttribute('TriangleCount',record.triangles);state.done+=1
  end
  -- Roblox retains mesh-origin offsets after ApplyMesh. Align each rendered
  -- bound to its original, while leaving all wheel pivot/radius tags untouched.
  local probe=Instance.new('Model');probe.WorldPivot=CFrame.identity
  local function box(part)local c=part:Clone();c.Parent=probe;local cf,size=probe:GetBoundingBox();c:Destroy();return cf,size end
  for _,p in stage:GetChildren()do if p:IsA('BasePart')then
   local q=old[p.Name];local target,targetSize=box(q)
   for _=1,3 do local current,size=box(p);p.Size=p.Size*(targetSize/size);current=box(p);p.CFrame=p.CFrame+(target.Position-current.Position)end
  end end
  probe:Destroy()
  stage:SetAttribute('VisualRevision','Toro_BadgeRemoved_v16');stage:SetAttribute('TriangleCount',manifest.triangles)
  local _,a=old:GetBoundingBox();local _,b=stage:GetBoundingBox();assert((a-b).Magnitude<.001,'Bounds changed')
  state.triangles=manifest.triangles
 end,debug.traceback)
 if not ok then table.insert(state.errors,err)end
 H.HttpEnabled=previous;state.finished=true
end)
return stage.Name
