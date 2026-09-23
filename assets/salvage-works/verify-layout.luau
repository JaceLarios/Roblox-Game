local L=require(game.ReplicatedStorage.JunkyardLayout)
local plots=workspace:WaitForChild("Plots",20) assert(#plots:GetChildren()==8)
local root=workspace.JunkyardRefresh assert(root:GetAttribute("Version")==11)
local rays=RaycastParams.new() rays.FilterType=Enum.RaycastFilterType.Include rays.FilterDescendantsInstances={workspace.JunkyardScene,root.Routes}
local means={} local report={}
for i=1,8 do
 local plot=plots["Plot"..i] local center=plot.Ground.Position
 assert(math.abs(Vector3.new(center.X,0,center.Z).Magnitude-L.PlotRadius)<.01,"Base radius")
 assert((plot.FusionPad.Position-Vector3.new(center.X,1,center.Z)).Magnitude<.01)
 local a=(i-1)*math.pi/4 local radial=Vector3.new(math.cos(a),0,math.sin(a))
 for d=8,180,2 do
  local pos=radial*d
  local hit=workspace:Raycast(pos+Vector3.new(0,50,0),Vector3.new(0,-60,0),rays)
  -- Final samples may be over the plot ground; it is excluded from this ground-only ray.
  if d<L.PlotRadius-L.PlotSize/2 then assert(hit and hit.Position.Y>.2 and hit.Position.Y<1.25,"Road floor gap "..i.." "..d) end
 end
 local sum=0 local count=0
 for ring=1,3 do for k=0,63 do
  local theta=k*math.pi/32 local pos=Vector3.new(math.cos(theta),0,math.sin(theta))*(26*ring)
  sum+=(pos-Vector3.new(center.X,0,center.Z)).Magnitude count+=1
 end end
 means[i]=sum/count
 report[i]={base=i,radius=center.Magnitude,meanSampleDistance=means[i]}
end
for i=2,8 do assert(math.abs(means[i]-means[1])<.001,"Distance distribution bias") end
assert(#workspace.YardFeatures:GetChildren()==1,"Old central obstacles remain")
assert(workspace.YardFeatures.MagnetCrane.Arm.Magnet:GetAttribute("DropOrigin"))
return game.HttpService:JSONEncode(report)
