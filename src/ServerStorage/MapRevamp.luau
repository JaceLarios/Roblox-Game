-- Junkyard Fusion: Foundry District. Deterministic, rebuildable map refresh.
-- Retains the shared 130-stud spawn area and all eight original plot centres.
local Map = {}
local V = Vector3.new
local CF = CFrame.new
local RGB = Color3.fromRGB
local C = {
 teal=RGB(28,139,143), orange=RGB(244,143,57), navy=RGB(34,53,68),
 cream=RGB(233,223,192), steel=RGB(76,91,97), dark=RGB(37,48,55),
 yellow=RGB(255,206,80), green=RGB(78,139,104), pale=RGB(162,209,198),
}
local plotColors={RGB(255,120,0),RGB(0,210,210),RGB(60,140,255),RGB(255,70,110),RGB(40,220,120),RGB(255,190,40),RGB(170,80,255),RGB(0,225,200)}
local root
local function folder(name,parent)
 local f=Instance.new("Folder") f.Name=name f.Parent=parent or root return f
end
local function part(name,size,cf,color,material,parent,collide)
 local p=Instance.new("Part") p.Name=name p.Size=size p.CFrame=cf
 p.Color=color p.Material=material or Enum.Material.SmoothPlastic
 p.Anchored=true p.CanCollide=collide==true p.CanTouch=false p.CanQuery=collide==true
 p.TopSurface=Enum.SurfaceType.Smooth p.BottomSurface=Enum.SurfaceType.Smooth
 p.CastShadow=size.Y>0.5
 if name=="Window" or name=="WindowSill" or name=="SideWindowBand" or name=="Corrugation" then p.CastShadow=false end
 p.Parent=parent or root return p
end
local function beam(name,a,b,width,color,parent)
 local mid=(a+b)*0.5
 return part(name,V(width,width,(a-b).Magnitude),CFrame.lookAt(mid,b),color,Enum.Material.Metal,parent)
end
local function sign(name,title,subtitle,cf,width,height,color,parent)
 local board=part(name,V(width,height,0.45),cf,color or C.navy,Enum.Material.SmoothPlastic,parent)
 for _,face in {Enum.NormalId.Front,Enum.NormalId.Back} do
  local gui=Instance.new("SurfaceGui") gui.Name="SignFace" gui.Face=face
  gui.SizingMode=Enum.SurfaceGuiSizingMode.PixelsPerStud gui.PixelsPerStud=20
  gui.LightInfluence=0.2 gui.AlwaysOnTop=false gui.Parent=board
  local label=Instance.new("TextLabel") label.Name="Heading" label.Size=UDim2.new(1,-12,0.65,0)
  label.Position=UDim2.fromOffset(6,0) label.BackgroundTransparency=1 label.Text=title
  label.Font=Enum.Font.GothamBlack label.TextScaled=true
  local bright=board.Color.R>0.65 and board.Color.G>0.45
  label.TextColor3=bright and C.navy or C.cream label.Parent=gui
  local small=label:Clone() small.Name="Subtitle" small.Size=UDim2.new(1,-12,0.28,0)
  small.Position=UDim2.new(0,6,0.67,0) small.Font=Enum.Font.GothamBold small.Text=subtitle
  small.TextColor3=bright and C.navy or C.yellow small.Parent=gui
 end
 return board
end
local function cylinder(name,size,cf,color,parent)
 local p=part(name,size,cf,color,Enum.Material.Metal,parent) p.Shape=Enum.PartType.Cylinder return p
end
local function light(p,color,brightness,range)
 local l=Instance.new("PointLight") l.Color=color l.Brightness=brightness l.Range=range l.Shadows=false l.Parent=p
end
local function container(cf,color,parent,label)
 part("Container",V(28,12,13),cf*CF(0,6,0),color,Enum.Material.Metal,parent,true)
 part("Roof",V(29,0.6,14),cf*CF(0,12.3,0),C.cream,Enum.Material.Metal,parent)
 for x=-13,13,2 do
  part("Corrugation",V(0.22,10.6,0.16),cf*CF(x,6,-6.6),color:Lerp(C.cream,0.15),Enum.Material.Metal,parent)
  part("Corrugation",V(0.22,10.6,0.16),cf*CF(x,6,6.6),color:Lerp(C.cream,0.15),Enum.Material.Metal,parent)
 end
 for z=-4,4,8 do
  part("DoorBar",V(0.25,9,0.25),cf*CF(14.2,6,z),C.cream,Enum.Material.Metal,parent)
 end
 sign("ContainerLabel",label,"RECYCLE / REBUILD",cf*CF(0,8,6.8),14,3.5,C.navy,parent)
end
local function bench(cf,parent)
 part("BenchSeat",V(9,0.7,2.8),cf*CF(0,2,0),C.orange,Enum.Material.WoodPlanks,parent,true)
 part("BenchBack",V(9,2,0.6),cf*CF(0,3.6,1.1),C.orange,Enum.Material.WoodPlanks,parent)
 for _,x in {-3,3} do part("BenchLeg",V(0.6,2,2),cf*CF(x,1,0),C.navy,Enum.Material.Metal,parent) end
end
local function planter(cf,parent)
 part("Planter",V(9,2,5),cf*CF(0,1,0),C.cream,Enum.Material.Concrete,parent,true)
 for x=-3,3,3 do
  local shrub=part("Shrub",V(3.6,3.6,3.6),cf*CF(x,3.2,0),C.green,Enum.Material.Grass,parent)
  shrub.Shape=Enum.PartType.Ball
 end
end
local function fan(cf,parent)
 local m=Instance.new("Model") m.Name="WorkshopFan" m.ModelStreamingMode=Enum.ModelStreamingMode.Atomic m.Parent=parent
 cylinder("FanHub",V(0.8,1.5,1.5),cf*CFrame.Angles(0,math.pi/2,0),C.orange,m)
 for angle=0,3 do part("Blade",V(5,0.85,0.3),cf*CFrame.Angles(0,0,angle*math.pi/2)*CF(2,0,0),C.steel,Enum.Material.Metal,m) end
 m.WorldPivot=cf
end
local function forklift(cf,parent)
 local m=Instance.new("Model") m.Name="DeliveryForklift" m.ModelStreamingMode=Enum.ModelStreamingMode.Persistent m.Parent=parent
 part("Chassis",V(6,2.2,8),cf*CF(0,2.5,0),C.orange,Enum.Material.Metal,m)
 part("RearWeight",V(6,2.4,2),cf*CF(0,4,-3),C.teal,Enum.Material.Metal,m)
 part("Seat",V(3,1,2.5),cf*CF(0,4.5,0),C.navy,nil,m)
 part("SeatBack",V(3,2,0.5),cf*CF(0,5.4,-1),C.navy,nil,m)
 for _,x in {-2.5,2.5} do
  for _,z in {-2.4,2.4} do
   cylinder("Wheel",V(1.4,3.4,3.4),cf*CF(x,1.7,z),C.dark,m)
   part("CabPost",V(0.35,5,0.35),cf*CF(x,6,z),C.navy,Enum.Material.Metal,m)
  end
  part("Fork",V(0.7,0.45,5),cf*CF(x*0.55,0.7,5.3),C.steel,Enum.Material.Metal,m)
 end
 part("Roof",V(6.2,0.5,5.8),cf*CF(0,8.7,0),C.teal,Enum.Material.Metal,m)
 part("Mast",V(4,8,0.6),cf*CF(0,4.5,3.6),C.navy,Enum.Material.Metal,m)
 local beacon=part("Beacon",V(0.8,0.8,0.8),cf*CF(0,9.3,0),C.orange,Enum.Material.Neon,m)
 m.WorldPivot=cf
 return m
end
function Map.Build()
 local old=workspace:FindFirstChild("JunkyardRefresh")
 if old and old:GetAttribute("Version")==5 then return old end
 local scene=assert(workspace:FindFirstChild("JunkyardScene"),"Restore the baseline map first")
 root=Instance.new("Folder") root.Name="JunkyardRefresh"
 root:SetAttribute("Version",5)
 local routes=folder("Routes")
 local garages=folder("Garages")
 local industry=folder("Industry")
 local district=folder("District")
 local landscape=folder("Landscape")
 local motion=folder("Motion")
 
 -- Brighter road network with colored guide rails. The centre remains clear.
 for i=1,8 do
  local angle=(i-1)*math.pi/4
  local radial=V(math.cos(angle),0,math.sin(angle))
  local side=V(-math.sin(angle),0,math.cos(angle))
  local col=plotColors[i]
  for _,offset in {-11.5,11.5} do
   local a=radial*86+side*offset+V(0,1.42,0)
   local finish=190-35/math.max(math.abs(radial.X),math.abs(radial.Z))
   local b=radial*finish+side*offset+V(0,1.42,0)
   beam("RouteColor",a,b,0.45,col,routes)
  end
  local gate=radial*82
  for _,offset in {-15.5,15.5} do
   part("GatePost",V(1.6,18,1.6),CF(gate+side*offset+V(0,9,0)),col,Enum.Material.Metal,routes)
  end
  beam("GateLintel",gate+side*16+V(0,18,0),gate-side*16+V(0,18,0),1.6,C.navy,routes)
  local face=CFrame.lookAt(gate+V(0,17.3,0),gate-radial+V(0,17.3,0))
  sign("YardGateway",i==7 and "SALVAGE YARD" or string.format("SECTOR %02d",i),"GRAB  /  FUSE  /  DISCOVER",face,27,4,C.navy,routes)
  for _,offset in {-13,13} do
   local p=part("GateLamp",V(0.8,0.8,0.8),CF(gate+side*offset+V(0,15,0)),C.yellow,Enum.Material.Neon,routes)
   light(p,C.yellow,0.35,12)
  end
  
  -- Garage shells stay on the outside edge of the existing 70x70 plots.
  local centre=radial*190
  local g=folder("Garage"..i,garages)
  part("BayApron",V(70,0.25,70),CF(centre+V(0,0.25,0)),RGB(70,86,94),Enum.Material.Concrete,g)
  for _,x in {-31,31} do
   part("GaragePillar",V(1.3,17,1.3),CF(centre+V(x,9,-27)),C.navy,Enum.Material.Metal,g)
   part("CornerBollard",V(1.8,3,1.8),CF(centre+V(x,2,30)),col,Enum.Material.Metal,g)
  end
  part("Canopy",V(65,1.2,17),CF(centre+V(0,18,-27)),col,Enum.Material.Metal,g)
  part("RoofEdge",V(66,0.7,0.8),CF(centre+V(0,17.3,-18.5)),C.cream,Enum.Material.Metal,g)
  part("WorkshopBack",V(64,11,0.5),CF(centre+V(0,6,-34)),C.navy,Enum.Material.Metal,g)
  for _,x in {-22,22} do
   part("ToolBoard",V(10,6,0.5),CF(centre+V(x,7,-33.5)),C.steel,Enum.Material.DiamondPlate,g)
   for dx=-3,3,2 do
    part("HangingTool",V(0.3,2.7,0.35),CF(centre+V(x+dx,7,-33)),C.cream,Enum.Material.Metal,g)
   end
  end
  sign("GarageNumber",string.format("BAY %02d",i),"FUSION WORKSHOP",CF(centre+V(0,21,-26)),30,5,col,g)
  for _,x in {-28,28} do
   beam("PlotSideStripe",centre+V(x,0.57,-15),centre+V(x,0.57,30),0.45,col,g)
  end
  fan(CF(centre+V(0,11,-33)),motion)
  for _,x in {-18,18} do
   local lamp=part("WorkshopLight",V(10,0.25,0.7),CF(centre+V(x,16.8,-22)),C.pale,Enum.Material.Neon,g)
   light(lamp,C.pale,0.35,20)
  end
 end
 -- A painted octagonal pad gives the shared yard a recognizable centre.
 for i=0,7 do
  local a=i*math.pi/4
  local b=(i+1)*math.pi/4
  beam("CentrePaint",V(math.cos(a)*23,1.24,math.sin(a)*23),V(math.cos(b)*23,1.24,math.sin(b)*23),0.5,C.orange,routes)
 end
 for _,x in {-55,55} do
  for z=-52,52,13 do part("FloorMarking",V(5,0.035,0.8),CF(x,1.225,z),C.cream,nil,routes) end
 end
 -- Eight staging pockets between spokes, away from the scrap spawn square.
 for i=0,7 do
  local a=(i+0.5)*math.pi/4
  local pos=V(math.cos(a)*128,0,math.sin(a)*128)
  local facing=CFrame.lookAt(pos,V(0,0,0))
  local pocket=folder("Staging"..i,industry)
  part("StagingApron",V(40,0.18,30),facing*CF(0,0.18,0),C.steel,Enum.Material.Concrete,pocket)
  if i~=0 and i~=4 then
   container(facing, i%2==0 and C.teal or C.orange,pocket,string.format("JF / %02d",i+1))
   if i==2 or i==6 then container(facing*CF(1,12.6,1),C.navy,pocket,"SALVAGE CO.") end
  end
  for k=1,3 do
   part("StackedCrate",V(4,4,4),facing*CF(-16,2+(k-1)*3.9,6),k%2==0 and C.cream or C.orange,Enum.Material.WoodPlanks,pocket)
  end
 end
 -- Landmark 1: a lattice crane and suspended salvage magnet.
 local base=V(118,0,49)
 part("CraneFooting",V(13,1,13),CF(base+V(0,0.6,0)),C.navy,Enum.Material.Concrete,industry,true)
 for _,x in {-4,4} do for _,z in {-4,4} do
  beam("CraneLeg",base+V(x,1,z),base+V(x,51,z),1,C.orange,industry)
 end end
 for y=3,43,8 do
  for _,z in {-4,4} do
   beam("CraneBrace",base+V(-4,y,z),base+V(4,y+8,z),0.45,C.yellow,industry)
  end
  for _,x in {-4,4} do
   beam("CraneBrace",base+V(x,y,-4),base+V(x,y+8,4),0.45,C.yellow,industry)
  end
 end
 local boomA=base+V(18,52,0)
 local boomB=base+V(-66,52,0)
 for _,z in {-2.5,2.5} do
  beam("BoomLower",boomA+V(0,0,z),boomB+V(0,0,z),1,C.orange,industry)
  beam("BoomUpper",boomA+V(0,5,z),boomB+V(0,5,z),0.7,C.yellow,industry)
  for x=-64,12,8 do beam("BoomLattice",base+V(x,52,z),base+V(x+8,57,z),0.45,C.orange,industry) end
 end
 part("CraneCab",V(9,7,9),CF(base+V(-8,49,0)),C.teal,Enum.Material.Metal,industry)
 part("CabGlass",V(0.25,4,7),CF(base+V(-12.6,49,0)),C.pale,Enum.Material.Glass,industry)
 part("CounterWeight",V(10,6,9),CF(base+V(14,51,0)),C.navy,Enum.Material.Concrete,industry)
 local hook=Instance.new("Model") hook.Name="CraneMagnet" hook.ModelStreamingMode=Enum.ModelStreamingMode.Atomic hook.Parent=motion
 local hookPos=base+V(-59,0,0)
 beam("Cable",hookPos+V(0,53,0),hookPos+V(0,25,0),0.22,C.dark,hook)
 cylinder("Electromagnet",V(2,8,8),CF(hookPos+V(0,24,0))*CFrame.Angles(0,0,math.pi/2),C.orange,hook)
 hook.WorldPivot=CF(hookPos+V(0,24,0))
 sign("CraneBrand","FUSION","HEAVY SALVAGE",CF(base+V(0,39,-4.8)),13,5,C.navy,industry)
 
 -- Landmark 2: a little staffed-looking depot, with a kiosk and rest area.
 local depot=CFrame.lookAt(V(-118,0,-49),V(0,0,0))
 container(depot,C.teal,industry,"PARTS & CO.")
 part("ServiceWindow",V(15,5,0.3),depot*CF(0,7,-6.7),C.navy,Enum.Material.Glass,industry)
 part("ServiceCounter",V(18,0.6,4),depot*CF(0,4,-8),C.orange,Enum.Material.WoodPlanks,industry)
 part("Awning",V(21,0.6,8),depot*CF(0,10,-9)*CFrame.Angles(0.12,0,0),C.cream,Enum.Material.Metal,industry)
 sign("DepotSign","PARTS & CO.","GOOD SCRAP. GREAT IDEAS.",depot*CF(0,15,0),28,5,C.teal,industry)
 bench(depot*CF(23,0,0),industry)
 planter(depot*CF(-23,0,0),industry)
 
 -- Delivery lane around the outside; no route or plot is displaced.
 for i=0,31 do
  local a=i*math.pi/16 local b=(i+1)*math.pi/16
  local p1=V(math.cos(a)*263,0.12,math.sin(a)*263)
  local p2=V(math.cos(b)*263,0.12,math.sin(b)*263)
  local road=beam("DistrictRoad",p1,p2,14,C.dark,district)
  road.Size=V(14,0.16,(p1-p2).Magnitude+0.6)
  local dash=beam("LaneDash",p1:Lerp(p2,0.35)+V(0,0.1,0),p1:Lerp(p2,0.65)+V(0,0.1,0),0.3,C.cream,district)
  dash.Size=V(0.35,0.04,dash.Size.Z)
 end
 forklift(CF(263,0.3,0)*CFrame.Angles(0,math.pi,0),motion)
 for i=0,7 do
  local a=(i+0.5)*math.pi/4
  local pos=V(math.cos(a)*234,0,math.sin(a)*234)
  local cf=CFrame.lookAt(pos,V(0,0,0))
  bench(cf,landscape)
  planter(cf*CF(-11,0,0),landscape)
  for k=1,3 do
   local rock=part("LandscapeRock",V(3+k,2+k,3+k),cf*CF(14+k*3,1,-3),C.steel,Enum.Material.Rock,landscape)
   rock.Shape=Enum.PartType.Ball
  end
 end
 -- Additional street trees frame the lane; distant hills soften the horizon.
 for i=0,23 do
  local a=(i+0.25)*math.pi/12
  local pos=V(math.cos(a)*289,0,math.sin(a)*289)
  part("StreetTreeTrunk",V(1.5,9,1.5),CF(pos+V(0,4.5,0)),RGB(106,85,62),Enum.Material.Wood,landscape)
  local crown=part("StreetTreeCrown",V(10,11,10),CF(pos+V(0,12,0)),i%3==0 and RGB(172,165,89) or C.green,Enum.Material.Grass,landscape)
  crown.Shape=Enum.PartType.Ball
 end
 for i=0,15 do
  local a=i*math.pi/8
  local pos=V(math.cos(a)*665,-18,math.sin(a)*665)
  local hill=part("DistantHill",V(210,130+(i%3)*25,170),CF(pos)*CFrame.Angles(0,a,0),RGB(94,128,119),Enum.Material.Grass,landscape)
  hill.Shape=Enum.PartType.Ball
 end
 -- Skyline façades: windows, parapets, colored belts and rooftop equipment.
 local buildingIndex=0
 for _,building in scene:GetChildren() do
  if building.Name=="Building" then
   buildingIndex+=1
   local cf=building.CFrame
   local sz=building.Size
   local col=buildingIndex%3==0 and C.teal or (buildingIndex%3==1 and C.cream or C.steel)
   local f=folder("Facade"..buildingIndex,district)
   for _,side in {-1,1} do
    for floor=1,math.min(5,math.floor(sz.Y/15)) do
     local y=-sz.Y/2+8+floor*(sz.Y-16)/(math.min(5,math.floor(sz.Y/15))+1)
     for column=-1,1 do
      local glass=(floor+column+buildingIndex)%4==0 and C.yellow or C.pale
      part("Window",V(sz.X/6,5,0.24),cf*CF(column*sz.X/3,y,side*(sz.Z/2+0.2)),glass,Enum.Material.SmoothPlastic,f)
      part("WindowSill",V(sz.X/6+0.7,0.4,0.7),cf*CF(column*sz.X/3,y-2.6,side*(sz.Z/2+0.3)),C.navy,Enum.Material.Metal,f)
     end
    end
    part("FacadeBelt",V(sz.X+0.7,2.5,0.6),cf*CF(0,-sz.Y/2+7,side*(sz.Z/2+0.3)),col,Enum.Material.Metal,f)
   end
   for _,side in {-1,1} do
    for floor=1,math.min(4,math.floor(sz.Y/16)) do
     part("SideWindowBand",V(0.3,4,sz.Z*0.65),cf*CF(side*(sz.X/2+0.2),-sz.Y/2+8+floor*(sz.Y-16)/(math.min(4,math.floor(sz.Y/16))+1),0),C.pale,nil,f)
    end
   end
   part("RoofUnit",V(9,5,12),cf*CF(0,sz.Y/2+4,0),C.steel,Enum.Material.Metal,f)
   if buildingIndex%6==0 then
    sign("RooftopBrand",({"FUSION","REBUILD","SALVAGE"})[buildingIndex/6%3+1],"FOUNDRY DISTRICT",cf*CF(0,sz.Y/2+10,0),math.min(45,sz.X-4),10,C.teal,f)
   end
  end
 end
 -- Apply the new palette to authored geometry after the new scene is built.
 local rng=Random.new(1209)
 local skyline={RGB(155,171,170),RGB(191,188,165),RGB(107,136,143),RGB(175,147,126)}
 for _,x in scene:GetDescendants() do
  if x:IsA("BasePart") then
   if x.Name:match("^Walkway") or x.Name=="Curb" then
    local radial=x.CFrame.LookVector*V(1,0,1)
    local pos=V(x.Position.X,0,x.Position.Z)
    if radial:Dot(pos)<0 then radial=-radial end
    local finish=190-35/math.max(math.abs(radial.X),math.abs(radial.Z))
    x.Size=V(x.Size.X,x.Size.Y,finish-80)
    x.CFrame=x.CFrame+radial*((80+finish)/2-radial:Dot(pos))
   elseif x.Name=="Dash" then
    local pos=V(x.Position.X,0,x.Position.Z)
    local radial=pos.Unit
    local finish=190-35/math.max(math.abs(radial.X),math.abs(radial.Z))
    if pos.Magnitude>finish-3 then x.Transparency=1 x.CanCollide=false end
   end
   if x.Name=="Trunk" or x.Name=="Leaves" then
    local flat=V(x.Position.X,0,x.Position.Z)
    if flat.Magnitude>248 and flat.Magnitude<278 then x.CFrame=x.CFrame+(flat.Unit*(293-flat.Magnitude)) end
   end
   if x.Name=="Building" then x.Color=skyline[rng:NextInteger(1,#skyline)]
   elseif x.Name=="RoofTrim" then x.Color=C.navy
   elseif x.Name=="GrassPlane" then x.Color=RGB(98,137,100)
   elseif x.Name=="YardAsphalt" then x.Color=RGB(66,82,88)
   elseif x.Name:match("^Walkway") then x.Color=RGB(90,106,111) x.Material=Enum.Material.Asphalt
   elseif x.Name=="Fence" then x.Color=C.teal x.Material=Enum.Material.Metal
   elseif x.Name=="FencePost" then x.Color=C.navy
   elseif x.Name=="Curb" then x.Color=C.cream
   elseif x.Name=="Leaves" then x.Color=({RGB(75,145,104),RGB(117,166,105),RGB(73,130,116)})[rng:NextInteger(1,3)]
   elseif x.Name=="CrushedCar" then x.Color=plotColors[rng:NextInteger(1,8)]
   elseif x.Name=="LampPost" then x.Color=C.navy
   elseif x.Name=="LampHead" then x.Color=C.yellow end
  end
 end
 local lighting=game:GetService("Lighting")
 lighting.ClockTime=15.7 lighting.Brightness=2.7 lighting.ExposureCompensation=0.1
 lighting.Ambient=RGB(113,122,133) lighting.OutdoorAmbient=RGB(143,148,145)
 lighting.EnvironmentDiffuseScale=0.65 lighting.EnvironmentSpecularScale=0.65
 lighting.ShadowSoftness=0.35 lighting.GlobalShadows=true
 local atmosphere=lighting:FindFirstChildOfClass("Atmosphere")
 if atmosphere then atmosphere.Density=0.22 atmosphere.Haze=0.65 atmosphere.Glare=0.15 atmosphere.Color=RGB(213,233,239) atmosphere.Decay=RGB(180,194,209) end
 local dof=lighting:FindFirstChildOfClass("DepthOfFieldEffect") if dof then dof.Enabled=false end
 local bloom=lighting:FindFirstChildOfClass("BloomEffect") if bloom then bloom.Intensity=0.12 bloom.Threshold=1.3 bloom.Size=24 end
 if old then old:Destroy() end
 root.Parent=workspace
 return root
end
-- Dresses the shared 130-stud scrap yard at the map's centre. Every other
-- area MapRevamp builds got roads, garages and landmarks — but the centre
-- was deliberately left clear (see Map.Build's routing comment), so next
-- to everything else it read as the plainest spot on the map. This frames
-- the edge with light, color and scattered junk; ScrapSpawner's own
-- 130-stud drop square (|x|,|z| <= 65) stays completely clear.
function Map.DressYard()
	-- Map.Build() almost always takes its early-return path (the map was
	-- already built in a prior session and just reused), which means the
	-- `root` upvalue it sets is usually never assigned. Look the refresh
	-- folder up directly instead of assuming Map.Build() just populated it.
	local refresh = workspace:FindFirstChild("JunkyardRefresh")
	if not refresh or refresh:FindFirstChild("YardDressing") then return end
	local f = Instance.new("Folder")
	f.Name = "YardDressing"
	f.Parent = refresh

	local INNER = 68  -- just outside ScrapSpawner's drop square
	local OUTER = 92

	-- Bright bollard ring right at the play-square edge, so the yard reads
	-- as a defined space instead of blending into the surrounding roads.
	for i = 0, 15 do
		local a = i * math.pi / 8
		local pos = V(math.cos(a) * INNER, 0, math.sin(a) * INNER)
		local col = plotColors[(i % 8) + 1]
		part("YardBollard", V(1.6, 3.2, 1.6), CF(pos + V(0, 1.6, 0)), col, Enum.Material.Neon, f)
	end

	-- Lamp posts a bit further out, spilling warm light onto the play square.
	for i = 0, 7 do
		local a = (i + 0.5) * math.pi / 4
		local pos = V(math.cos(a) * OUTER, 0, math.sin(a) * OUTER)
		part("YardLampPost", V(0.9, 16, 0.9), CF(pos + V(0, 8, 0)), C.navy, Enum.Material.Metal, f)
		local head = part("YardLampHead", V(2, 1, 2), CF(pos + V(0, 16.2, 0)), C.yellow, Enum.Material.Neon, f)
		light(head, C.yellow, 0.5, 45)
	end

	-- Scattered bright junk piles framing the yard between the bollards and
	-- the lamps — nothing sits inside INNER, so nothing blocks a live drop.
	local rng = Random.new(77)
	local junkColors = { plotColors[1], plotColors[2], plotColors[4], plotColors[6], plotColors[8] }
	for i = 0, 9 do
		local a = i * math.pi / 5 + rng:NextNumber(-0.1, 0.1)
		local dist = rng:NextNumber(INNER + 5, OUTER - 6)
		local base = V(math.cos(a) * dist, 0, math.sin(a) * dist)
		local col = junkColors[(i % #junkColors) + 1]
		for k = 0, 2 do
			local size = 3 + k * 0.6
			local rock = part("YardJunkPile", V(size, size, size),
				CF(base + V(k * 1.6 - 1.6, size / 2, k * 1.1 - 1.1)), col, Enum.Material.Neon, f)
			rock.Shape = Enum.PartType.Ball
		end
	end

	print("[Map] Yard dressed.")
end
function Map.DressPlot(plot)
 if not plot:IsA("Model") or plot:FindFirstChild("WorkshopFinish") then return end
 local index=tonumber(plot.Name:match("%d+")) or 1
 local ground=plot:FindFirstChild("Ground")
 local pad=plot:FindFirstChild("FusionPad")
 if not (ground and pad) then return end
 local col=plotColors[index] or C.teal
 ground.Color=col:Lerp(RGB(255,255,255),0.7) ground.Material=Enum.Material.SmoothPlastic
 pad.Color=col
 local f=folder("WorkshopFinish",plot)
 for _,x in {-7,7} do
  part("FusionPadRail",V(0.35,0.2,14),pad.CFrame*CF(x,0.6,0),C.pale,Enum.Material.Neon,f)
 end
 -- Placement zones replaced the single pedestal; trim their sign posts
 -- with the same per-plot accent color instead of PlotManager's old pedestal.
 for _, zoneKey in {"garage","workshop","trophy"} do
  local sign=plot:FindFirstChild(zoneKey.."Sign")
  if sign then part(zoneKey.."SignTrim",V(0.4,0.2,1.2),sign.CFrame*CF(0,2.6,0),col,Enum.Material.Neon,f) end
 end
end
return Map
