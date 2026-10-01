assert(not game:GetService('RunService'):IsRunning(),'Stop Play')
local state=assert(_G.RemainingModelImport);assert(state.finished and #state.errors==0,'Import not complete')
local stage=assert(game.ServerStorage:FindFirstChild(state.stage))
local recipes=require(game.ReplicatedStorage.FusionRecipes)
local visuals=require(game.ReplicatedStorage.ItemVisuals)
local hover=require(game.ReplicatedStorage.HoverVisuals)
local templates=game.ReplicatedStorage.ItemModels
local models=stage:GetChildren();assert(#models==52,'Expected 52 models')
-- Authored core position, retained for the existing wheel-less reactor hover controller.
for _,m in models do
 assert(m:GetAttribute('StagingComplete'),m.Name)
 assert(recipes.Fuse(m:GetAttribute('FusionBase'),m:GetAttribute('FusionAddon'))==m.Name,'Recipe mismatch '..m.Name)
 assert(recipes.GetRarity(m.Name)==m:GetAttribute('Rarity'),'Rarity mismatch')
 local wheels,triangles={},0
 for _,p in m:GetChildren()do
  assert(p:IsA('MeshPart')and p.MeshId~='','Missing mesh')
  triangles+=p:GetAttribute('TriangleCount')or 0
  local id=p:GetAttribute('WheelId')
  if id then assert(typeof(p:GetAttribute('WheelPivot'))=='Vector3'and p:GetAttribute('WheelRadius')>0);wheels[id]=true end
 end
 local count=0;for _ in wheels do count+=1 end
 assert(count==m:GetAttribute('ExpectedWheels'),'Wheel count '..m.Name)
 assert(triangles<90000,'Geometry budget '..m.Name)
end
local backup=Instance.new('Folder');backup.Name='BeforeRemainingModels_'..os.time();backup.Parent=game.ServerStorage
local installed={};local results={}
for _,m in models do
 local old=templates:FindFirstChild(m.Name);if old then old.Parent=backup end
 local copy=m:Clone();copy:SetAttribute('StagingComplete',nil);copy.Parent=templates;table.insert(installed,copy)
end
local ok,err=xpcall(function()
 for _,m in installed do
  local clone,size=visuals.CloneForViewport(m.Name);assert(clone and size.Magnitude>0);clone:Destroy()
  local item=visuals.Create(m.Name,Vector3.new(0,1500,0),1)
  local before={}
  for _,j in item:GetChildren()do if j:IsA('Weld')and j.Part1:GetAttribute('WheelPivot')then before[j]=j.C0 end end
  visuals.RollWheels(item,.45)
  local moved=0;for j,cf in before do if j.C0~=cf then moved+=1 end end
  local hovering=m:GetAttribute('ExpectedWheels')==0
  if hovering then
   assert(moved==0);local controller=hover.Attach(item,item.Visual)
   controller:Step(.1,.5,.2);controller:Destroy()
  else assert(moved>0,'Wheels did not move '..m.Name)end
  visuals.Resize(item,item.Size*.75);item:Destroy()
  table.insert(results,{name=m.Name,viewport=true,resize=true,wheelPartsMoved=moved,hoverChecked=hovering})
 end
end,debug.traceback)
if not ok then
 for _,m in installed do m:Destroy()end
 for _,m in backup:GetChildren()do m.Parent=templates end
 error('Rolled back installation: '..tostring(err))
end
_G.RemainingModelsVerification={models=results,backup=backup.Name}
return game.HttpService:JSONEncode(_G.RemainingModelsVerification)
