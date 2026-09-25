-- Exercise the actual conveyor Heartbeat block without starting player/data scripts.
local src=_G.RollingNewSources.ScrapSpawner
local first=assert(src:find('local riders = {}',1,true));local last=assert(src:find('-- Anything a player drops',first,true))
local block=src:sub(first,last-1)
local factory=assert(loadstring('return function(RunService, Conveyor, ItemVisuals, workspace)\n'..block..'\nreturn {ride=ride,count=riderCount}\nend'))()
local mod=Instance.new('ModuleScript');mod.Source=_G.RollingNewSources.ItemVisuals;mod.Parent=game.ServerStorage
local folder=Instance.new('Folder');folder.Name='RollingConveyorVerification';folder.Parent=workspace
local report={}
local ok,err=xpcall(function()
 local v=require(mod);local conveyor=require(game.ServerStorage.YardConveyor);local tick
 local fakeRun={Heartbeat={Connect=function(_,fn)tick=fn end}}
 local mover={BulkMoveTo=function(_,parts,frames)for i,p in parts do p.CFrame=frames[i]end end}
 local harness=factory(fakeRun,conveyor,v,mover)
 local root=v.Create('Monster Truck',Vector3.new(0,500,0),1);root.Parent=folder
 harness.ride(root,0)
 local wheel;for _,j in root:GetChildren()do if j:IsA('Weld')and j.Part1:GetAttribute('WheelPivot')then wheel=j;break end end
 assert(wheel);local initial=wheel.C0
 for i=1,60 do tick(1/60)end
 local point,travel=conveyor.PointAt(conveyor.SPEED)
 assert((root.Position-(point+Vector3.new(0,root.Size.Y/2,0))).Magnitude<.001,'Conveyor distance')
 assert(root.CFrame.ZVector:Dot(travel)>.999,'Nose forward')
 assert((wheel.C0.UpVector-initial.UpVector).Magnitude>.01,'Wheel did not turn')
 root:SetAttribute('Collected',true);local frozen=wheel.C0;local position=root.Position;tick(.5)
 assert(harness.count()==0 and root.Position==position and wheel.C0==frozen,'Pickup must stop conveyor control')
 local tail=v.Create('Golf Cart',Vector3.zero,1);tail.Parent=folder;harness.ride(tail,conveyor.Length+100);tick(.1);assert(tail.Parent==nil and harness.count()==0,'Despawn cleanup')
 local dropped=v.Create('Dirt Bike',Vector3.zero,1);dropped.Parent=folder;harness.ride(dropped,20);dropped:Destroy();tick(.1);assert(harness.count()==0,'Destroyed cleanup')
 report={distanceAndNose=true,wheelsTurn=true,collectedStops=true,despawn=true,destroyedCleanup=true,method='Edit-mode harness executes actual conveyor Heartbeat block; no player or datastore scripts'}
end,debug.traceback)
folder:Destroy();mod:Destroy();assert(ok,err);return report
