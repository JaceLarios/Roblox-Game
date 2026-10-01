assert(not game:GetService('RunService'):IsRunning(),'Stop Play before import')
local AS=game:GetService('AssetService');local H=game:GetService('HttpService')
local previousHttp=H.HttpEnabled;H.HttpEnabled=true
local stage=Instance.new('Folder');stage.Name='AllModelsStaging_'..os.time();stage.Parent=game.ServerStorage
local state={stage=stage.Name,done={},errors={},workers={},uploads=0,reused=0,finished=false,previousHttp=previousHttp}
_G.AllModelImport=state
local cache={}
for _,p in game:GetDescendants()do
 if p:IsA('MeshPart') and p.MeshId~='' and p:GetAttribute('GeometryHash') then cache[p:GetAttribute('GeometryHash')]=p end
end
local function srgb(v)return v<=.0031308 and v*12.92 or 1.055*v^(1/2.4)-.055 end
local function loadMesh(d,g,center)
 local cached=cache[g.geometryHash]
 if cached and cached.Parent then state.reused+=1;local p=cached:Clone();p:ClearAllChildren();for k in p:GetAttributes()do p:SetAttribute(k,nil)end;return p end
 local em=assert(AS:CreateEditableMesh(),'EditableMesh allocation failed')
 local ok,result=xpcall(function()
  local vs,ns={},{}
  for i,v in g.vertices do vs[i]=em:AddVertex(Vector3.new(unpack(v))-center);ns[i]=em:AddNormal(Vector3.new(unpack(g.normals[i])))end
  for _,t in g.triangles do local a,b,c=t[1]+1,t[2]+1,t[3]+1;local f=em:AddTriangle(vs[a],vs[b],vs[c]);em:SetFaceNormals(f,{ns[a],ns[b],ns[c]})end
  local assetId,lastError
  for attempt=1,5 do
   local success,status,id=pcall(function()return AS:CreateAssetAsync(em,Enum.AssetType.Mesh,{Name=d.name..' '..g.name,Description='Junkyard Fusion authored vehicle geometry'})end)
   if success and tostring(status):find('Success')then assetId=id;break end
   lastError=tostring(status);task.wait(attempt*3)
  end
  assert(assetId,lastError);state.uploads+=1
  for attempt=1,8 do
   local loaded,p=pcall(function()return AS:CreateMeshPartAsync(Content.fromUri('rbxassetid://'..assetId))end)
   if loaded then return p end
   lastError=tostring(p);task.wait(math.min(attempt*2,10))
  end
  error(lastError)
 end,debug.traceback)
 em:Destroy();assert(ok,result);return result
end
local function build(spec,worker)
 local d=H:JSONDecode(H:GetAsync('http://127.0.0.1:18769/model-import-20261001/data/'..spec.file))
 local m=Instance.new('Model');m.Name=d.name;m.Parent=stage
 for k,v in {DisplayName=d.name,NoseAxis='+Z',VisualRevision=d.revision,FusionBase=d.base,FusionAddon=d.addon,Rarity=d.rarity,ExpectedWheels=d.expectedWheels,AuthoredComponents=d.authoredComponents}do m:SetAttribute(k,v)end
 if d.fitScaleToBase then m:SetAttribute('FitScaleToBase',d.fitScaleToBase)end
 if d.reactorEffectCenter then m:SetAttribute('ReactorLocalCenter',Vector3.new(unpack(d.reactorEffectCenter)))end
 for index,g in d.parts do
  state.workers[worker]={name=d.name,part=index,total=#d.parts}
  local lo=Vector3.new(math.huge,math.huge,math.huge);local hi=-lo
  for _,v in g.vertices do local a=Vector3.new(unpack(v));lo=lo:Min(a);hi=hi:Max(a)end
  local center=(lo+hi)/2;local p=loadMesh(d,g,center)
  p.Size=(hi-lo):Max(Vector3.new(.001,.001,.001))
  p.Name=g.name;p.Color=Color3.new(srgb(g.material.color[1]),srgb(g.material.color[2]),srgb(g.material.color[3]))
  p.Material=Enum.Material.SmoothPlastic;p.MaterialVariant='';p.Transparency=0
  local finish=g.material.finish
  if finish=='Light'then p.Material=Enum.Material.Neon
  elseif finish=='Glass'then p.Material=Enum.Material.Glass
  else local variant=finish=='Carbon' and 'AddonCarbonTwill' or 'AddonDetail_'..finish..'_v2';assert(game.MaterialService:FindFirstChild(variant),variant);p.MaterialVariant=variant end
  p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.Massless=true;p.DoubleSided=true
  p:SetAttribute('TriangleCount',#g.triangles);p:SetAttribute('GeometryHash',g.geometryHash)
  if g.wheel then p:SetAttribute('WheelId',g.wheel.id);p:SetAttribute('WheelPivot',Vector3.new(unpack(g.wheel.pivot)));p:SetAttribute('WheelRadius',g.wheel.radius)end
  p.CFrame=CFrame.new(center);p.Parent=m;cache[g.geometryHash]=p
 end
 local cf,size=m:GetBoundingBox();assert((size-Vector3.new(unpack(d.targetSize))).Magnitude<.06,'Bounds mismatch '..d.name)
 m:PivotTo(CFrame.new(-cf.Position)*m:GetPivot())
 for _,p in m:GetChildren()do local w=p:GetAttribute('WheelPivot');if w then p:SetAttribute('WheelPivot',w-cf.Position)end end
 m:SetAttribute('WheelPivotRecentered',true);m:SetAttribute('StagingComplete',true)
 table.insert(state.done,{name=m.Name,parts=#m:GetChildren()})
end
task.spawn(function()
 local ok,err=xpcall(function()
  local manifest=H:JSONDecode(H:GetAsync('http://127.0.0.1:18769/model-import-20261001/manifest.json'))
  local nextIndex,workers=0,2
  for worker=1,2 do task.spawn(function()
   local success,problem=xpcall(function()
    while #state.errors==0 do
     nextIndex+=1;local spec=manifest[nextIndex];if not spec then break end
     build(spec,worker)
    end
   end,debug.traceback)
   if not success then table.insert(state.errors,problem)end
   state.workers[worker]={finished=true};workers-=1
  end)end
  while workers>0 do task.wait(.5)end
 end,debug.traceback)
 if not ok then table.insert(state.errors,err)end
 H.HttpEnabled=previousHttp;state.finished=true
end)
return stage.Name
