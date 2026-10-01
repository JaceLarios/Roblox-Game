assert(not game:GetService('RunService'):IsRunning(),'Stop Play before importing')
local AS=game:GetService('AssetService')
local H=game:GetService('HttpService')
local stage=Instance.new('Folder');stage.Name='WarpModelsStaging_'..os.time();stage.Parent=game.ServerStorage
_G.WarpImport={stage=stage.Name,done={},errors={},active='',part=0,finished=false}
local function srgb(v)return v<=.0031308 and v*12.92 or 1.055*v^(1/2.4)-.055 end
task.spawn(function()
 local ok,err=xpcall(function()
 local manifest=H:JSONDecode(H:GetAsync('http://127.0.0.1:18769/warp-drive-batch/import/manifest.json'))
 for _,spec in manifest do
  _G.WarpImport.active=spec.name
  local d=H:JSONDecode(H:GetAsync('http://127.0.0.1:18769/warp-drive-batch/import/'..spec.file))
  local m=Instance.new('Model');m.Name=d.name;m.Parent=stage
  m:SetAttribute('DisplayName',d.name);m:SetAttribute('NoseAxis','+Z');m:SetAttribute('VisualRevision','WarpBatch_20261001_v1')
  if d.base then m:SetAttribute('FusionBase',d.base);m:SetAttribute('FusionAddon','Warp Drive') end
  m:SetAttribute('AuthoredComponents',d.authoredComponents)
  for index,g in d.parts do
   _G.WarpImport.part=index
   local lo=Vector3.new(math.huge,math.huge,math.huge);local hi=-lo
   for _,v in g.vertices do local a=Vector3.new(unpack(v));lo=lo:Min(a);hi=hi:Max(a) end
   local center=(lo+hi)/2;local em=assert(AS:CreateEditableMesh())
   local built,p=xpcall(function()
    local vs,ns={},{}
    for i,v in g.vertices do vs[i]=em:AddVertex(Vector3.new(unpack(v))-center);ns[i]=em:AddNormal(Vector3.new(unpack(g.normals[i]))) end
    for _,t in g.triangles do local a,b,c=t[1]+1,t[2]+1,t[3]+1;local f=em:AddTriangle(vs[a],vs[b],vs[c]);em:SetFaceNormals(f,{ns[a],ns[b],ns[c]}) end
    local status,id=AS:CreateAssetAsync(em,Enum.AssetType.Mesh,{Name=d.name..' '..g.name,Description='Original Junkyard Fusion Warp Drive model'})
    assert(tostring(status):find('Success'),tostring(status))
    table.insert(_G.WarpImport.done,{assetOnly=true,name=d.name,part=g.name,id=tostring(id)})
    local problem
    for attempt=1,8 do
     local loaded,mesh=pcall(function()return AS:CreateMeshPartAsync(Content.fromUri('rbxassetid://'..id))end)
     if loaded then return mesh end
     problem=mesh;task.wait(math.min(attempt*2,10))
    end
    error(tostring(problem))
   end,debug.traceback)
   em:Destroy();assert(built,p)
   p.Name=g.name;p.Color=Color3.new(srgb(g.material.color[1]),srgb(g.material.color[2]),srgb(g.material.color[3]))
   p.Material=Enum.Material.SmoothPlastic
   local finish=g.material.finish
   if finish=='Light' then p.Material=Enum.Material.Neon
   elseif finish=='Glass' then p.Material=Enum.Material.Glass
   else local variant=finish=='Carbon' and 'AddonCarbonTwill' or 'AddonDetail_'..finish..'_v2';assert(game.MaterialService:FindFirstChild(variant),variant);p.MaterialVariant=variant end
   p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.Massless=true;p.DoubleSided=true
   p:SetAttribute('TriangleCount',#g.triangles);p:SetAttribute('GeometryHash',g.geometryHash)
   if g.wheel then p:SetAttribute('WheelId',g.wheel.id);p:SetAttribute('WheelPivot',Vector3.new(unpack(g.wheel.pivot)));p:SetAttribute('WheelRadius',g.wheel.radius) end
   p.CFrame=CFrame.new(center);p.Parent=m
  end
  local cf,size=m:GetBoundingBox();assert((size-Vector3.new(unpack(d.targetSize))).Magnitude<.05,'Bounds mismatch')
  m:PivotTo(CFrame.new(-cf.Position)*m:GetPivot())
  for _,p in m:GetChildren()do local w=p:GetAttribute('WheelPivot');if w then p:SetAttribute('WheelPivot',w-cf.Position) end end
  m:SetAttribute('WheelPivotRecentered',true);m:SetAttribute('StagingComplete',true)
  table.insert(_G.WarpImport.done,{name=d.name,parts=#m:GetChildren(),complete=true})
 end
 end,debug.traceback)
 if not ok then table.insert(_G.WarpImport.errors,err) end
 _G.WarpImport.finished=true
end)
return stage.Name
