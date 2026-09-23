local L=require(game.ReplicatedStorage.JunkyardLayout)
local out={}
for i=1,8 do
 local plot=workspace.Plots["Plot"..i] local shop=workspace.JunkyardRefresh.Garages["Garage"..i]
 local cf=CFrame.lookAt(plot.Ground.Position,Vector3.zero)
 local count=0
 for n=1,8 do local pad=assert(plot:FindFirstChild("PetPad"..n),"Missing pad") local pos=cf:PointToObjectSpace(pad.Position)
 assert(math.abs(pos.X-(n<=4 and -28 or 28))<.01) assert(math.abs(pos.Z-(-24+((n-1)%4)*16))<.01) count+=1 end
 local rp=RaycastParams.new() rp.FilterType=Enum.RaycastFilterType.Include rp.FilterDescendantsInstances={shop} rp.RespectCanCollide=true
 for _,target in ipairs({Vector3.new(-60,5,0),Vector3.new(60,5,0),Vector3.new(0,5,60),Vector3.new(0,60,0),Vector3.new(25,5,-60)}) do
  local start=cf:PointToWorldSpace(Vector3.new(0,5,0))
  assert(workspace:Raycast(start,cf:PointToWorldSpace(target)-start,rp),"Enclosure gap "..i)
 end
 local start=cf:PointToWorldSpace(Vector3.new(0,5,0))
 assert(not workspace:Raycast(start,cf:VectorToWorldSpace(Vector3.new(0,0,-50)),rp),"Door blocked "..i)
 out[i]={pads=count,enclosed=true,entranceClear=true}
end
return out
