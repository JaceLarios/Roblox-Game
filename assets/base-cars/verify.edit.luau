local module=Instance.new('ModuleScript');module.Name='RollingVerification';module.Source=_G.RollingNewSources.ItemVisuals;module.Parent=game.ServerStorage
local objects={};local report={models={},checks={}}
local ok,err=xpcall(function()
 local v=require(module)
 local function near(a,b,label)
  local aa,bb={a:GetComponents()},{b:GetComponents()}
  for i=1,12 do assert(math.abs(aa[i]-bb[i])<.001,label..' component '..i)end
 end
 for _,name in {'Rusted Sedan','Dirt Bike','Golf Cart','Muscle Car','Cop Cruiser','Box Truck','Monster Truck'}do
  for _,scale in {.55,1,1.3}do
   local probe=game.ReplicatedStorage.ItemModels[name]:Clone();probe:ScaleTo(probe:GetScale()*scale*v.GLOBAL_SCALE)
   local boundsCF=probe:GetBoundingBox();local pivotCF=probe:GetPivot();probe:Destroy()
   local root=v.Create(name,Vector3.new(0,500,0),scale);table.insert(objects,root)
   local wheels,body={},{};local ids={}
   for _,joint in root:GetChildren()do if joint:IsA('Weld')then
    local p=joint.Part1;local pivot=p:GetAttribute('WheelPivot');local radius=p:GetAttribute('WheelRadius')
    if pivot then
     local localPivot=game.ReplicatedStorage.ItemModels[name]:GetPivot():PointToObjectSpace(pivot)
     local expectedPivot=pivotCF:PointToWorldSpace(localPivot*scale*v.GLOBAL_SCALE)-boundsCF.Position
     table.insert(wheels,{joint=joint,rest=joint.C0,pivot=expectedPivot,radius=radius*scale*v.GLOBAL_SCALE});ids[p:GetAttribute('WheelId')]=true
    else table.insert(body,{joint=joint,rest=joint.C0})end
   end end
   local count=0;for _ in ids do count+=1 end
   assert(count==(name=='Dirt Bike' and 2 or 4),'Wheel count '..name)
   assert(#body>0)
   local distance=wheels[1].radius*math.pi/2
   v.RollWheels(root,distance)
   for _,w in wheels do near(w.joint.C0,CFrame.new(w.pivot)*CFrame.Angles(distance/w.radius,0,0)*CFrame.new(-w.pivot)*w.rest,'Quarter turn '..name)end
   for _,w in body do near(w.joint.C0,w.rest,'Body must stay fixed')end
   v.RollWheels(root,-distance)
   for _,w in wheels do near(w.joint.C0,w.rest,'Reverse return')end
   for i=1,60 do v.RollWheels(root,wheels[1].radius*math.pi*2/60)end
   for _,w in wheels do near(w.joint.C0,w.rest,'Full revolution')end
   v.Resize(root,root.Size*.5)
   v.RollWheels(root,distance*.5)
   for _,w in wheels do
    local rest=CFrame.new(w.rest.Position*.5)*w.rest.Rotation;local pivot=w.pivot*.5
    near(w.joint.C0,CFrame.new(pivot)*CFrame.Angles(distance/w.radius,0,0)*CFrame.new(-pivot)*rest,'Resize then roll')
   end
   root:Destroy()
  end
  local viewport,size=v.CloneForViewport(name);assert(viewport and size.Magnitude>0);viewport:Destroy()
  table.insert(report.models,{name=name,scales=3,rolling=true,resize=true,viewport=true})
 end
 -- Legacy non-car models remain compatible with RollWheels.
 local addon=v.Create('Nitrous Tank',Vector3.zero,1);table.insert(objects,addon);v.RollWheels(addon,2);addon:Destroy()
 report.checks={'21 assemblies: independent wheel pivots, quarter turn, reverse, full revolution, resize, fixed body','Seven inventory viewport clones','Legacy addon no-op compatibility'}
end,debug.traceback)
for _,o in objects do o:Destroy()end;module:Destroy()
assert(ok,err);return report
