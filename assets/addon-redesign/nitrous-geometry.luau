-- Edit-mode geometry study for the Nitrous Tank. Other addons are untouched.
assert(not game:GetService("RunService"):IsRunning(), "Stop Play first")
local templates=game.ReplicatedStorage.ItemModels
local source=templates["Nitrous Tank"]
assert(source:GetAttribute("CodexModelRevision")=="AddonHeavyWear_20260923_v3", "Unexpected source revision")
assert(not game.ServerStorage:FindFirstChild("NitrousGeometryStaging"), "Inspect existing staging model")
local m=source:Clone() m.Name="NitrousGeometryStaging" m.Parent=game.ServerStorage
local detail=Instance.new("Model",m) detail.Name="BentSteelHardware"
local steel=Color3.fromRGB(69,65,57)
local rust=Color3.fromRGB(117,64,35)
local edge=Color3.fromRGB(151,137,111)
local function p(name,size,cf,color,material,kind)
 local v=Instance.new(kind or "Part") v.Name=name v.Size=size v.CFrame=cf
 v.Color=color v.Material=material or Enum.Material.CorrodedMetal
 v.Anchored=true v.Massless=true v.CanCollide=false v.CanTouch=false v.CanQuery=false
 v.TopSurface=Enum.SurfaceType.Smooth v.BottomSurface=Enum.SurfaceType.Smooth v.Parent=detail return v
end
local function beam(name,a,b,w,h,color)
 return p(name,Vector3.new(w,h,(b-a).Magnitude),CFrame.lookAt((a+b)/2,b),color)
end
-- The side rails deliberately kink at welded joints, rather than a perfect box.
for _,z in ipairs({-.49,.49}) do
 local points={Vector3.new(-1.37,-.54,z),Vector3.new(-.65,-.58,z+.025),Vector3.new(.05,-.545,z-.018),Vector3.new(.79,-.57,z)}
 for i=1,3 do
  beam("BentChannelRail",points[i],points[i+1],.095,.17,i==2 and rust or steel)
  beam("ExposedRailLip",points[i]+Vector3.new(0,.088,0),points[i+1]+Vector3.new(0,.088,0),.105,.022,edge)
 end
 -- Small irregular repair plates create visible relief on the rail face.
 for i,x in ipairs({-.76,.15}) do
  p("WeldedRepairPlate",Vector3.new(.27,.14,.027),CFrame.new(x,-.535,z+(z>0 and .064 or -.064))*CFrame.Angles(0,0,i==1 and .10 or -.13),rust)
  for j=1,4 do
   local b=p("RaisedWeldBead",Vector3.new(.045,.027,.024),CFrame.new(x-.13+j*.055,-.47+(j%2)*.007,z+(z>0 and .084 or -.084)),edge,Enum.Material.Metal)
   b.Shape=Enum.PartType.Ball
  end
 end
end
for _,x in ipairs({-1.05,.54}) do
 beam("Crossmember",Vector3.new(x,-.62,-.52),Vector3.new(x,-.62,.52),.13,.11,steel)
 for _,z in ipairs({-.45,.45}) do
  p("BuckledMountFoot",Vector3.new(.30,.07,.24),CFrame.new(x,-.705,z)*CFrame.Angles(0,0,x<0 and .09 or -.07),rust)
  -- Black recessed washer, raised six-sided suggestion via rotated square head.
  local washer=p("RecessedBoltSeat",Vector3.new(.02,.115,.115),CFrame.new(x,-.65,z)*CFrame.Angles(0,0,math.pi/2),Color3.fromRGB(29,28,25),Enum.Material.Metal)
  washer.Shape=Enum.PartType.Cylinder
  p("MountBolt",Vector3.new(.067,.034,.067),CFrame.new(x,-.622,z)*CFrame.Angles(0,.35,0),edge,Enum.Material.Metal)
 end
end
-- Segmented straps wrap the bottle with slightly uneven edges and bent tabs.
for strap,x in ipairs({-.85,.37}) do
 local previous
 for i=0,10 do
  local a=math.pi*i/10
  local r=.475+(i==3 and .019 or i==7 and -.008 or 0)
  local point=Vector3.new(x+(i==4 and .012 or 0),-.03+math.sin(a)*r,math.cos(a)*r)
  if previous then beam("UnevenSteelStrap",previous,point,.15+(i%3)*.009,.028,i%4==0 and rust or edge) end
  previous=point
 end
 for _,z in ipairs({-.49,.49}) do
  p("BentStrapTab",Vector3.new(.19,.29,.045),CFrame.new(x,-.19,z)*CFrame.Angles(z>0 and .17 or -.12,0,.06),steel)
  local rivet=p("StrapRivet",Vector3.new(.062,.062,.028),CFrame.new(x,-.20,z+(z>0 and .04 or -.04)),edge,Enum.Material.Metal)
  rivet.Shape=Enum.PartType.Ball
 end
end
-- Angular breaks on the exposed rail ends interrupt the smooth silhouette.
for _,z in ipairs({-.49,.49}) do
 p("ChippedRailEnd",Vector3.new(.13,.15,.095),CFrame.new(-1.40,-.54,z)*CFrame.Angles(0,math.pi/2,0),rust,nil,"WedgePart")
end
m:SetAttribute("CodexModelRevision","NitrousGeometry_20260923_v4")
local cf,size=m:GetBoundingBox()
m:PivotTo(CFrame.new(-cf.Position)*m:GetPivot()) m.WorldPivot=CFrame.new()
print("Nitrous geometry staged. Previous installed tank untouched.")
