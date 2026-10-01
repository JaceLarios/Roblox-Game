assert(not game:GetService('RunService'):IsRunning(),'Stop Play')
local H=game:GetService('HttpService');local AS=game:GetService('AssetService')
local old=assert(game.ReplicatedStorage.ItemModels:FindFirstChild('SVO'))
assert(old:FindFirstChild('LogoCover'),'Required logo cover missing')
local previous=H.HttpEnabled;H.HttpEnabled=true
local stage=Instance.new('Model');stage.Name='SVO_Optimized_Staging';stage.Parent=game.ServerStorage
for k,v in old:GetAttributes()do stage:SetAttribute(k,v)end
local state={done=0,errors={},finished=false,stage=stage.Name};_G.SVOOptimize=state
task.spawn(function()
 local ok,err=xpcall(function()
  local manifest=H:JSONDecode(H:GetAsync('http://127.0.0.1:18769/svo/optimized/manifest.json'))
  for i=0,manifest.parts-1 do
   local d=H:JSONDecode(H:GetAsync('http://127.0.0.1:18769/svo/optimized/part-'..i..'.json'))
   local reference
   for _,p in old:GetChildren()do if p:IsA('MeshPart')and p.Name:sub(1,#d.sourcePrefix)==d.sourcePrefix then reference=p;break end end
   if not reference then reference=old:FindFirstChild(d.object)end
   assert(reference and reference:IsA('MeshPart'),'No appearance reference '..d.name)
   local lo=Vector3.new(math.huge,math.huge,math.huge);local hi=-lo
   for _,v in d.vertices do local p=Vector3.new(unpack(v));lo=lo:Min(p);hi=hi:Max(p)end
   local center=(lo+hi)/2;local em=assert(AS:CreateEditableMesh())
   local good,result=xpcall(function()
    local vs,ns,uv={},{},{}
    for j,v in d.vertices do vs[j]=em:AddVertex(Vector3.new(unpack(v))-center);ns[j]=em:AddNormal(Vector3.new(unpack(d.normals[j])));uv[j]=em:AddUV(Vector2.new(unpack(d.uvs[j])))end
    for _,t in d.triangles do local a,b,c=t[1]+1,t[2]+1,t[3]+1;local f=em:AddTriangle(vs[a],vs[b],vs[c]);em:SetFaceNormals(f,{ns[a],ns[b],ns[c]});em:SetFaceUVs(f,{uv[a],uv[b],uv[c]})end
    local id
    for attempt=1,5 do
     local success,status,asset=pcall(function()return AS:CreateAssetAsync(em,Enum.AssetType.Mesh,{Name='SVO optimized '..i,Description='Optimized modified vehicle; existing source attribution retained'})end)
     if success and tostring(status):find('Success')then id=asset;break end
     task.wait(attempt*3)
    end
    assert(id,'Upload failed '..d.name)
    for attempt=1,8 do local loaded,p=pcall(function()return AS:CreateMeshPartAsync(Content.fromUri('rbxassetid://'..id))end);if loaded then return p end;task.wait(attempt*2)end
    error('Mesh loading failed')
   end,debug.traceback)
   em:Destroy();assert(good,result)
   local p=result;p.Name=d.name;p.Size=(hi-lo):Max(Vector3.new(.001,.001,.001));p.CFrame=CFrame.new(center)
   p.Color=reference.Color;p.Material=reference.Material;p.MaterialVariant=reference.MaterialVariant;p.Transparency=reference.Transparency;p.Reflectance=reference.Reflectance
   p.TextureID=reference.TextureID;p:SetAttribute('AppearanceSourcePrefix',d.sourcePrefix)
   for _,c in reference:GetChildren()do if c:IsA('SurfaceAppearance')or c:IsA('Texture')or c:IsA('Decal')then c:Clone().Parent=p end end
   p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.Massless=true;p.DoubleSided=true
   p:SetAttribute('TriangleCount',#d.triangles)
   if d.wheel then p:SetAttribute('WheelId',d.wheel.id);p:SetAttribute('WheelPivot',Vector3.new(unpack(d.wheel.pivot)));p:SetAttribute('WheelRadius',d.wheel.radius)end
   p.Parent=stage;state.done+=1
  end
  old.LogoCover:Clone().Parent=stage
  stage:SetAttribute('VisualRevision','Optimized_SeparateWheels_v8');stage:SetAttribute('TriangleCount',manifest.triangles);stage:SetAttribute('ExpectedWheels',4)
  local cf,size=stage:GetBoundingBox();local oldCf,oldSize=old:GetBoundingBox()
  assert(math.abs(size.Z-oldSize.Z)<.05,'SVO length changed')
  state.size={size.X,size.Y,size.Z};state.triangles=manifest.triangles
 end,debug.traceback)
 if not ok then table.insert(state.errors,err)end
 H.HttpEnabled=previous;state.finished=true
end)
return stage.Name
