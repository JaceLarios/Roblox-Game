assert(not game:GetService('RunService'):IsRunning(), 'Stop Play before import')
local H,AS=game:GetService('HttpService'),game:GetService('AssetService')
local URL='http://127.0.0.1:18773/'
local oldHttp=H.HttpEnabled;H.HttpEnabled=true
local state=_G.CivicImport or {done={},errors={},uploads=0,reused=0}
assert(not state.running,'Import already running')
state.running=true;state.finished=false;state.errors={};_G.CivicImport=state
local stage=state.stage and game.ServerStorage:FindFirstChild(state.stage)
if not stage then stage=Instance.new('Folder');stage.Name='Civic_Staging_'..os.time();stage.Parent=game.ServerStorage;state.stage=stage.Name end
state.assetIds=state.assetIds or {}
local cache={}
for _,p in game:GetDescendants()do if p:IsA('MeshPart') and p.MeshId~='' and p:GetAttribute('CivicGeometryHash') then cache[p:GetAttribute('CivicGeometryHash')]=p end end
local function vec(t)return Vector3.new(t[1],t[2],t[3])end
local function srgb(x)return x<=.0031308 and 12.92*x or 1.055*x^(1/2.4)-.055 end
local function color(t)return Color3.new(srgb(t[1]),srgb(t[2]),srgb(t[3]))end
local function upload(meta,carName)
 if cache[meta.geometryHash]and cache[meta.geometryHash].Parent then state.reused+=1;local p=cache[meta.geometryHash]:Clone();p:ClearAllChildren();for k in p:GetAttributes()do p:SetAttribute(k,nil)end;return p end
 local data=H:JSONDecode(H:GetAsync(URL..meta.file));local em=assert(AS:CreateEditableMesh())
 local ok,result=xpcall(function()
  local v,n,uv={},{},{}
  for i,point in data.vertices do v[i]=em:AddVertex(vec(point));n[i]=em:AddNormal(vec(data.normals[i]));uv[i]=em:AddUV(Vector2.new(data.uvs[i][1],data.uvs[i][2]))end
  for _,t in data.triangles do local a,b,c=t[1]+1,t[2]+1,t[3]+1;local f=em:AddTriangle(v[a],v[b],v[c]);em:SetFaceNormals(f,{n[a],n[b],n[c]});em:SetFaceUVs(f,{uv[a],uv[b],uv[c]})end
  em:RemoveUnused()
  local id,lastError=state.assetIds[meta.geometryHash],nil
  for attempt=1,5 do
   if id then break end
   local success,status,asset=pcall(function()return AS:CreateAssetAsync(em,Enum.AssetType.Mesh,{Name=(carName..' '..meta.name):sub(1,48),Description='Modified Civic vehicle geometry for Junkyard Fusion; source provenance retained in asset package'})end)
   if success and tostring(status):find('Success')then id=asset;break end
   lastError=tostring(status)..' | '..tostring(asset);task.wait(attempt*3)
  end
  assert(id,lastError);state.assetIds[meta.geometryHash]=id;state.uploads+=1
  for attempt=1,12 do
   local good,p=pcall(function()return AS:CreateMeshPartAsync(Content.fromUri('rbxassetid://'..id))end)
   if good then p:SetAttribute('MeshAssetId',id);return p end
   lastError=tostring(p);task.wait(math.min(10,attempt*2))
  end
  error(meta.name..' asset '..tostring(id)..': '..tostring(lastError))
 end,debug.traceback)
 em:Destroy();assert(ok,result);return result
end
task.spawn(function()
 local ok,err=xpcall(function()
  local textures=H:JSONDecode(H:GetAsync(URL..'texture-ids.json'))
  local manifest=H:JSONDecode(H:GetAsync(URL..'manifest.json'))
  for index,entry in manifest do
   if _G.CivicImportLimit and index>_G.CivicImportLimit then break end
   if stage:FindFirstChild(entry.name)then continue end
   state.active=entry.name;state.part=0
   local d=H:JSONDecode(H:GetAsync(URL..entry.file));local m=Instance.new('Model');m.Name=d.name..' [Importing]';m.Parent=stage
   for key,val in {NoseAxis='+Z',VisualRevision='Civic_20261009_v1',FusionBase='Civic',FusionAddon=d.addon,EventAddon=d.event,ExpectedWheels=d.expectedWheels,TriangleCount=d.triangles,SourceTriangles=d.sourceTriangles}do m:SetAttribute(key,val)end
   local cursor,finishedWorkers,failures=0,0,{}
   for worker=1,3 do task.spawn(function()
    local good,problem=xpcall(function()
    while true do
    cursor+=1;local part=d.parts[cursor];if not part then break end
    local p=upload(part,d.name);p.Name=part.name;p.Size=vec(part.size):Max(Vector3.new(.001,.001,.001));p.CFrame=CFrame.new(vec(part.center))
    p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.Massless=true;p.DoubleSided=true
    local a=part.appearance;p.Material=Enum.Material[a.finish];p.Color=color(a.color);p.Transparency=a.transparency
    if a.variant then p.MaterialVariant=a.variant end
    -- Direct color textures remain visible while newly uploaded PBR packs are
    -- being processed. Preserve the authored PBR references for future editing.
    p.TextureID=a.maps.ColorMap and assert(textures[a.maps.ColorMap]) or ''
    for key,file in a.maps do p:SetAttribute('Authored'..key,assert(textures[file])) end
    if not a.variant and a.finish=='SmoothPlastic' then
     local metal=tonumber((a.maps.MetalnessMap or ''):match('constant%-(%d+)')) or 0
     local rough=tonumber((a.maps.RoughnessMap or ''):match('constant%-(%d+)')) or 128
     if metal>=166 and not a.maps.ColorMap then p.Material=Enum.Material.Metal;p.Reflectance=rough<90 and .08 or 0 end
    end
    if part.name:find('Silver_MAT') then p.MaterialVariant='';p.Material=Enum.Material.Metal;p.Reflectance=.04 end
    p:SetAttribute('DriverCabin',part.name:match('^Glass_Glass_MAT_')~=nil);p:SetAttribute('CivicGeometryHash',part.geometryHash);p:SetAttribute('TriangleCount',part.triangles)
    if part.wheel then p:SetAttribute('WheelId',part.wheel.id);p:SetAttribute('WheelPivot',vec(part.wheel.pivot));p:SetAttribute('WheelRadius',part.wheel.radius)end
    p.Parent=m;cache[part.geometryHash]=p;state.part+=1
    end
    end,debug.traceback)
    if not good then table.insert(failures,problem) end
    finishedWorkers+=1
   end)end
   while finishedWorkers<3 do task.wait(.1)end
   assert(#failures==0,table.concat(failures,'\n'))
   local cf,size=m:GetBoundingBox();assert((size-vec(d.targetSize)).Magnitude<.02,'Export bounds differ '..d.name)
   m:PivotTo(CFrame.new(-cf.Position)*m:GetPivot())
   for _,p in m:GetChildren()do local pivot=p:GetAttribute('WheelPivot');if pivot then p:SetAttribute('WheelPivot',pivot-cf.Position)end end
   m:SetAttribute('WheelPivotRecentered',true);for _,old in stage:GetChildren()do if old~=m and old.Name==d.name..' [Importing]'then old:Destroy()end end;m.Name=d.name;m:SetAttribute('ImportComplete',true)
   table.insert(state.done,{name=m.Name,parts=#d.parts,triangles=d.triangles,size={size.X,size.Y,size.Z}})
   H:PostAsync(URL..'snapshot',H:JSONEncode({name='civic-import-progress.json',content=H:JSONEncode(state)}),Enum.HttpContentType.ApplicationJson)
  end
 end,debug.traceback)
 if not ok then table.insert(state.errors,err)end
 H.HttpEnabled=oldHttp;state.running=false;state.finished=true
end)
return state.stage
