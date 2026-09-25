assert(not game:GetService('RunService'):IsRunning(),'Stop Play first')
local state=assert(_G.AddonImportState)
assert(state.finished and #state.errors==0 and #state.done==10,'Imports not ready')
local stage=assert(game.ServerStorage:FindFirstChild(state.stage))
local destination=game.ReplicatedStorage.ItemModels
for _,item in state.done do
 local m=assert(stage:FindFirstChild(item.name))
 local old=assert(destination:FindFirstChild(item.name))
 assert(old:GetAttribute('VisualRevision')=='BlenderAddons_20260924_v1','Model changed externally: '..item.name)
 assert(m:GetAttribute('VisualRevision')=='BlenderAddons_20260924_v2')
 for _,p in m:GetDescendants()do
  assert(not p:IsA('LuaSourceContainer'))
  if p:IsA('BasePart')then assert(p.Anchored and not p.CanCollide and p.Massless)end
 end
end
local backup=Instance.new('Folder');backup.Name='AddonBackup_BeforeColorDetail_'..os.time();backup.Parent=game.ServerStorage
for _,item in state.done do
 local old=destination[item.name];local new=stage[item.name]
 for key,value in old:GetAttributes() do if new:GetAttribute(key)==nil then new:SetAttribute(key,value)end end
 old.Parent=backup;new.Parent=destination
end
local report={backup=backup.Name,models={}}
local ok,err=xpcall(function()
 local visuals=require(game.ReplicatedStorage.ItemVisuals)
 for _,item in state.done do
  local m=destination[item.name]
  assert(visuals.HasModel(item.name))
  local view,size=visuals.CloneForViewport(item.name);assert(view and size.Magnitude>0);view:Destroy()
  local root=visuals.Create(item.name,Vector3.new(0,10000,0),1)
  assert(root:GetAttribute('ItemAssembly') and root:FindFirstChild('Visual'))
  local joints=0;for _,v in root:GetChildren()do if v:IsA('Weld')then joints+=1 end end
  root:Destroy();assert(joints==#m:GetChildren())
  local _,bounds=m:GetBoundingBox()
  table.insert(report.models,{name=item.name,size={bounds.X,bounds.Y,bounds.Z},parts=#m:GetChildren(),lookup=true,viewport=true,weldedPickup=true})
 end
end,debug.traceback)
if not ok then
 for _,item in state.done do destination[item.name].Parent=stage;backup[item.name].Parent=destination end
 error('Rolled back detail pass: '..err)
end
stage:Destroy();_G.AddonInstallReport=report
game:GetService('Selection'):Set(destination:GetChildren())
return report
