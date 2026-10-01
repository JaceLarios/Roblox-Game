assert(not game:GetService('RunService'):IsRunning(),'Stop Play')
local state=assert(_G.WarpImport)
assert(state.finished and #state.errors==0,'Import must complete successfully')
local staging=assert(game.ServerStorage:FindFirstChild(state.stage))
local recipes=require(game.ReplicatedStorage.FusionRecipes)
local visuals=require(game.ReplicatedStorage.ItemVisuals)
local templates=game.ReplicatedStorage.ItemModels
local models=staging:GetChildren();assert(#models==8,'Expected eight models')
for _,m in models do
 assert(m:GetAttribute('StagingComplete'),m.Name)
 local base=m:GetAttribute('FusionBase')
 if base then assert(recipes.Fuse(base,'Warp Drive')==m.Name,'Recipe mismatch: '..m.Name)
 else assert(m.Name=='Warp Drive' and recipes.IsAddon(m.Name),'Addon mismatch') end
 local wheels={};local triangles=0
 for _,p in m:GetChildren()do
  assert(p:IsA('MeshPart') and p.MeshId~='','Missing mesh')
  triangles+=p:GetAttribute('TriangleCount') or 0
  local id=p:GetAttribute('WheelId')
  if id then assert(typeof(p:GetAttribute('WheelPivot'))=='Vector3' and p:GetAttribute('WheelRadius')>0);wheels[id]=true end
 end
 local n=0;for _ in wheels do n+=1 end
 assert(n==(base=='Dirt Bike' and 2 or base and 4 or 0),'Wheel count: '..m.Name)
 assert(triangles<90000,'Geometry budget')
end
local backup=Instance.new('Folder');backup.Name='BeforeWarpBatch_'..os.time();backup.Parent=game.ServerStorage
local installed={}
for _,m in models do
 local old=templates:FindFirstChild(m.Name);if old then old.Parent=backup end
 local copy=m:Clone();copy:SetAttribute('StagingComplete',nil);copy:SetAttribute('Rarity','legendary')
 if copy.Name=='Warp Drive' then copy:SetAttribute('IsAddon',true) end
 copy.Parent=templates;table.insert(installed,copy)
end
local results={}
local ok,err=xpcall(function()
 for _,m in installed do
  local clone,size=visuals.CloneForViewport(m.Name);assert(clone and size.Magnitude>0);clone:Destroy()
  local item=visuals.Create(m.Name,Vector3.new(0,1000,0),1);assert(item)
  local joints={}
  for _,j in item:GetDescendants() do if j:IsA('Weld') and j.Part1 and j.Part1:GetAttribute('WheelPivot')then joints[j]=j.C0 end end
  visuals.RollWheels(item,.35)
  local changed=0;for j,cf in joints do if j.C0~=cf then changed+=1 end end
  if m:GetAttribute('FusionBase')then assert(changed>0,'Wheels did not turn: '..m.Name)end
  visuals.Resize(item,item.Size*.8);item:Destroy()
  table.insert(results,{name=m.Name,viewport=true,wheelPartsMoved=changed,resize=true})
 end
end,debug.traceback)
if not ok then
 for _,m in installed do m:Destroy() end
 for _,m in backup:GetChildren()do m.Parent=templates end
 error('Installation rolled back: '..tostring(err))
end
_G.WarpVerification=results
if _G.WarpPreview then _G.WarpPreview:Destroy();_G.WarpPreview=nil end
if _G.WarpPreviousHttp~=nil then game.HttpService.HttpEnabled=_G.WarpPreviousHttp end
return game.HttpService:JSONEncode({installed=results,backup=backup.Name})
