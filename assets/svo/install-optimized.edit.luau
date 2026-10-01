assert(not game:GetService('RunService'):IsRunning(),'Stop Play')
local state=assert(_G.SVOOptimize);assert(state.finished and #state.errors==0,'SVO staging incomplete')
local templates=game.ReplicatedStorage.ItemModels
local old=assert(templates:FindFirstChild('SVO'));local staged=assert(game.ServerStorage:FindFirstChild(state.stage))
local backup=Instance.new('Folder');backup.Name='BeforeSVOOptimization_'..os.time();backup.Parent=game.ServerStorage
old.Parent=backup;local replacement=staged:Clone();replacement.Name='SVO';replacement.Parent=templates
local result={backup=backup.Name,triangles=state.triangles,wheels={}}
local ok,err=xpcall(function()
 assert(replacement:FindFirstChild('LogoCover'),'LogoCover lost')
 local _,size=replacement:GetBoundingBox();assert(math.abs(size.Z-12.13484)<.02)
 local visuals=require(game.ReplicatedStorage.ItemVisuals)
 local view=assert(visuals.CloneForViewport('SVO'));view:Destroy()
 local item=visuals.Create('SVO',Vector3.new(0,1600,0),1)
 local before={}
 for _,joint in item:GetChildren()do if joint:IsA('Weld')then before[joint]=joint.C0 end end
 visuals.RollWheels(item,1)
 for joint,cf in before do
  local id=joint.Part1:GetAttribute('WheelId')
  if id then assert(joint.C0~=cf,'Wheel failed '..id);result.wheels[id]=(result.wheels[id]or 0)+1
  else assert(joint.C0==cf,'Non-wheel moved '..joint.Part1.Name)end
 end
 local count=0;for _ in result.wheels do count+=1 end;assert(count==4,'Expected four wheel groups')
 visuals.Resize(item,item.Size*.7);visuals.RollWheels(item,2);item:Destroy()
 result.viewport=true;result.resize=true;result.logoCover=true;result.length=size.Z
end,debug.traceback)
if not ok then replacement:Destroy();old.Parent=templates;backup:Destroy();error(err)end
_G.SVOOptimizationVerification=result
local preview=workspace:FindFirstChild('CodexSVOReview');if preview then preview:Destroy()end
if _G.SVOPreviewCamera then workspace.CurrentCamera.CFrame=_G.SVOPreviewCamera.cf;workspace.CurrentCamera.Focus=_G.SVOPreviewCamera.focus end
return game.HttpService:JSONEncode(result)
