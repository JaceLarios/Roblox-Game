assert(not game:GetService('RunService'):IsRunning(),'Stop Play first')
local state=assert(_G.KartFusionImport);assert(state.finished and #state.errors==0 and #state.done==15,'All fifteen imports must succeed first')
local stage=game.ServerStorage[state.stage];local dest=game.ReplicatedStorage.ItemModels
local recipes=require(game.ReplicatedStorage.FusionRecipes)
for _,spec in _G.KartFusionDesigns do
 assert((dest:FindFirstChild(spec.name)or false)==_G.KartFusionBaseline[spec.name],'Existing model changed during import: '..spec.name)
 assert(recipes.Fuse('Rusted Sedan',spec.addon)==spec.name,'Recipe name mismatch')
 assert(recipes.GetRarity(spec.name)==spec.rarity,'Recipe rarity mismatch')
 assert(stage:FindFirstChild(spec.name),'Missing staged model')
end
local backup=Instance.new('Folder');backup.Name='KartFusionsBeforeRebuild_'..os.time();backup.Parent=game.ServerStorage
for _,spec in _G.KartFusionDesigns do
 local old=dest:FindFirstChild(spec.name);local new=stage[spec.name]
 if old then
  for k,v in old:GetAttributes()do if new:GetAttribute(k)==nil and not k:match('^RBX_AI')then new:SetAttribute(k,v)end end
  old.Parent=backup
 end
 new.Parent=dest
end
local module=game.ReplicatedStorage.ItemVisuals:Clone();module.Name='KartFusionVerification';module.Parent=game.ServerStorage
local handles={};local report={backup=backup.Name,models={}}
local ok,err=xpcall(function()
 local visuals=require(module)
 for _,spec in _G.KartFusionDesigns do
  local m=dest[spec.name]
  for _,p in m:GetDescendants()do assert(not p:IsA('LuaSourceContainer'));if p:IsA('BasePart')then assert(p.Anchored and not p.CanCollide and p.Massless)end end
  local preview,size=visuals.CloneForViewport(spec.name);assert(preview and size.Magnitude>0);preview:Destroy()
  for _,scale in {.55,1,1.3}do
   local handle=visuals.Create(spec.name,Vector3.new(0,10000,0),scale);table.insert(handles,handle);assert(handle:GetAttribute('ItemAssembly'))
   local count=0;local wheelJoint
   for _,j in handle:GetChildren()do if j:IsA('Weld')then count+=1;if j.Part1:GetAttribute('WheelId')then wheelJoint=j end end end
   assert(count==#m:GetChildren(),'Missing mesh weld')
   if spec.name~='Hover Heap'then assert(wheelJoint,'Missing wheel rig');local before=wheelJoint.C0;visuals.RollWheels(handle,.4);assert((before.UpVector-wheelJoint.C0.UpVector).Magnitude>.01,'Wheel did not turn')end
   local fx=handle:FindFirstChild('FusionCoreEffects',true)
   local beforePos=fx and fx.Position
   local beforeSize=fx and fx.PulsingEnergyWisps.Size.Keypoints[2].Value
   if spec.name=='Reactor Rustbucket'then assert(fx and fx.CoreSparks.Enabled and fx.PlasmaGlow.Enabled,'Missing reactor effects')end
   visuals.Resize(handle,handle.Size*.5)
   if fx then
    assert((fx.Position-beforePos*.5).Magnitude<.001,'Reactor attachment did not resize')
    assert(math.abs(fx.PulsingEnergyWisps.Size.Keypoints[2].Value-beforeSize*.5)<.001,'Reactor particles did not resize')
   end
   visuals.RollWheels(handle,.2);handle:Destroy()
  end
  table.insert(report.models,{name=spec.name,addon=spec.addon,rarity=spec.rarity,viewport=true,scaledAssemblies=3,parts=#m:GetChildren(),size={size.X,size.Y,size.Z}})
 end
end,debug.traceback)
for _,h in handles do h:Destroy()end;module:Destroy()
if not ok then
 for _,spec in _G.KartFusionDesigns do dest[spec.name].Parent=stage;local old=backup:FindFirstChild(spec.name);if old then old.Parent=dest end end
 error('Installation rolled back: '..err)
end
stage:Destroy();_G.KartFusionInstallReport=report
for _,mesh in _G.KartFusionMeshCache do mesh:Destroy()end;_G.KartFusionMeshCache={}
return report
