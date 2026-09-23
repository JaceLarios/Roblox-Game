-- Salvage Works: a rebuilt, open junkyard. Other islands are not touched.
local Map={}
local V,CF,RGB=Vector3.new,CFrame.new,Color3.fromRGB
local Layout=require(game.ReplicatedStorage:WaitForChild("JunkyardLayout"))
local C={teal=RGB(10,164,181),blue=RGB(32,125,214),orange=RGB(248,136,37),yellow=RGB(255,196,48),cream=RGB(245,232,196),navy=RGB(32,47,61),steel=RGB(91,108,115),rust=RGB(143,77,42),green=RGB(113,155,80)}
local colors={C.teal,C.orange,C.blue,C.teal,C.orange,C.blue,C.teal,C.orange}
local function folder(parent,n) local f=Instance.new("Folder") f.Name=n f.Parent=parent return f end
local function p(parent,n,size,cf,color,mat,solid)
 local v=Instance.new("Part") v.Name=n v.Size=size v.CFrame=cf v.Color=color
 v.Material=mat or Enum.Material.Metal v.Anchored=true
 v.CanCollide=solid==true v.CanQuery=solid==true v.CanTouch=false
 v.TopSurface=Enum.SurfaceType.Smooth v.BottomSurface=Enum.SurfaceType.Smooth
 v.CastShadow=size.Y>.35 v.Parent=parent return v
end
local function cyl(parent,n,size,cf,color,mat,solid)
 local v=p(parent,n,size,cf,color,mat,solid) v.Shape=Enum.PartType.Cylinder return v
end
local function bar(f,n,a,b,w,h,col,mat)
 return p(f,n,V(w,h,(b-a).Magnitude),CFrame.lookAt((a+b)/2,b),col,mat)
end
local function sign(parent,cf,size,title,col)
 local v=p(parent,"WorkshopSign",size,cf,col)
 for _,face in ipairs({Enum.NormalId.Front,Enum.NormalId.Back}) do
  local gui=Instance.new("SurfaceGui",v) gui.Face=face gui.PixelsPerStud=20 gui.SizingMode=Enum.SurfaceGuiSizingMode.PixelsPerStud gui.LightInfluence=0
  local t=Instance.new("TextLabel",gui) t.BackgroundTransparency=1 t.Size=UDim2.fromScale(.94,.88) t.Position=UDim2.fromScale(.03,.06) t.Text=title t.TextColor3=C.cream t.Font=Enum.Font.FredokaOne t.TextScaled=true
 end
 return v
end
local function tyre(f,cf)
 cyl(f,"SalvageTyre",V(1.1,3.1,3.1),cf,C.navy,Enum.Material.SmoothPlastic)
 cyl(f,"RustHub",V(1.15,1.5,1.5),cf,C.rust,Enum.Material.CorrodedMetal)
end
local function wreck(f,cf,color)
 p(f,"WreckChassis",V(7,.7,13),cf*CF(0,1.7,0),C.navy)
 p(f,"DentedBody",V(7,1.8,12),cf*CF(0,2.5,0),color)
 p(f,"SquashedCab",V(5.7,1.8,5.6),cf*CF(0,4.0,.2)*CFrame.Angles(.025,0,.045),color)
 p(f,"FrontGlass",V(5.15,1.25,.16),cf*CF(0,4.0,-2.65)*CFrame.Angles(-.10,0,0),C.navy,Enum.Material.Glass)
 p(f,"BackGlass",V(5.15,1.2,.15),cf*CF(0,4,3.04),C.navy,Enum.Material.Glass)
 for _,x in ipairs({-3.0,3.0}) do
  p(f,"SideGlass",V(.16,1.2,4.65),cf*CF(x,4,.2),C.navy,Enum.Material.Glass)
  p(f,"WindowDivider",V(.18,1.2,.15),cf*CF(x,4,0),color)
  p(f,"DoorHandle",V(.17,.17,.65),cf*CF(x*1.17,2.9,.3),C.cream)
 end
 for _,z in ipairs({-6.2,6.2}) do
  p(f,"BentBumper",V(7.2,.5,.45),cf*CF(0,2,z)*CFrame.Angles(0,.025,.04),C.steel,Enum.Material.CorrodedMetal)
  for _,x in ipairs({-2.45,2.45}) do p(f,"WreckLamp",V(1.1,.65,.18),cf*CF(x,2.9,z),z<0 and C.cream or C.orange,Enum.Material.Glass) end
 end
 p(f,"RustedHood",V(5.6,.14,2.5),cf*CF(.15,3.46,-4.3)*CFrame.Angles(0,.03,.03),C.rust,Enum.Material.CorrodedMetal)
 for _,x in ipairs({-3.56,3.56}) do
  p(f,"DoorRepair",V(.07,.8,1.5),cf*CF(x,2.5,1.4)*CFrame.Angles(.09,0,0),C.rust,Enum.Material.CorrodedMetal)
  for z=-2,2,2 do p(f,"PanelSeam",V(.08,1.35,.07),cf*CF(x,2.7,z),C.navy) end
 end
 for _,x in ipairs({-3.4,3.4}) do for _,z in ipairs({-4,4}) do tyre(f,cf*CF(x,1.5,z)) end end
end
local function garage(parent,i)
 local radial=V(math.cos((i-1)*math.pi/4),0,math.sin((i-1)*math.pi/4))
 -- The facade sits beyond the existing square plot, even at diagonal bays.
 local position=radial*(Layout.PlotRadius+61)
 local cf=CFrame.lookAt(position,V(0,0,0)) local col=colors[i]
 local f=folder(parent,"Garage"..i)
 -- Yard-facing negative Z is the open shop front. No new colliders on plots.
 p(f,"WorkshopFoundation",V(62,1,30),cf*CF(0,.3,0),C.steel,Enum.Material.Concrete)
 p(f,"BackWall",V(60,22,1),cf*CF(0,12,13),col)
 for x=-27,27,4.5 do p(f,"BackSidingRib",V(.18,20,.15),cf*CF(x,12,12.4),col:Lerp(C.cream,.25)) end
 for _,x in ipairs({-29.5,29.5}) do
  p(f,"SideWall",V(1,22,26),cf*CF(x,12,0),col)
  p(f,"FrontPost",V(1.6,23,1.6),cf*CF(x,12,-13),C.navy)
  for y=2,6,1.4 do p(f,"SafetyBand",V(1.65,.6,1.65),cf*CF(x,y,-13),C.yellow) end
  for z=-10,10,4 do p(f,"SidingRib",V(.15,20,.20),cf*CF(x+(x>0 and .57 or -.57),12,z),col:Lerp(C.cream,.18)) end
  p(f,"SteelKickPlate",V(.18,3.5,24),cf*CF(x+(x>0 and .60 or -.60),2.8,0),C.steel,Enum.Material.DiamondPlate)
 end
 p(f,"UpperFacade",V(60,5,1),cf*CF(0,21,-13),col)
 p(f,"RoofLeft",V(32,.7,30),cf*CF(-15,25.2,0)*CFrame.Angles(0,0,.09),C.navy)
 p(f,"RoofRight",V(32,.7,30),cf*CF(15,25.2,0)*CFrame.Angles(0,0,-.09),C.navy)
 p(f,"RoofRidge",V(1.2,.65,30),cf*CF(0,26.8,0),C.steel)
 for x=-26,26,6.5 do p(f,"RoofSeam",V(.15,.16,29),cf*CF(x,26.7-math.abs(x)*.09,0),C.steel) end
 p(f,"RoofPatch",V(8,.15,9),cf*CF(-18,25.85,4)*CFrame.Angles(0,.06,.09),C.rust,Enum.Material.CorrodedMetal)
 sign(f,cf*CF(0,21.4,-13.7),V(45,4.2,.30),string.format("BAY %02d  /  SALVAGE WORKS",i),C.navy)
 for _,x in ipairs({-23,23}) do
  p(f,"Workbench",V(9,.7,5),cf*CF(x,4,8),C.steel,Enum.Material.DiamondPlate)
  p(f,"ToolCabinet",V(7,3.6,4),cf*CF(x,2,8),C.orange)
  for y=1,3,1 do p(f,"DrawerHandle",V(4,.12,.15),cf*CF(x,y,5.9),C.cream) end
  p(f,"ToolBoard",V(9,6,.2),cf*CF(x,9,12.4),C.navy)
  for k=-2,2,2 do
   p(f,"ToolHandle",V(.25,2.7,.25),cf*CF(x+k,9,12.1),C.cream)
   p(f,"ToolHead",V(1.2,.4,.25),cf*CF(x+k,10.5,12.1),C.steel)
  end
  local lightPart=p(f,"WorkLight",V(7,.25,.6),cf*CF(x,18,-10),C.cream,Enum.Material.Neon)
  local lamp=Instance.new("PointLight",lightPart)
  lamp.Color=C.cream lamp.Range=20 lamp.Brightness=.5 lamp.Shadows=false
 end
 for _,x in ipairs({-27,27}) do
  p(f,"RustSkirt",V(4,2,.18),cf*CF(x,2.4,-13.65),C.rust,Enum.Material.CorrodedMetal)
  for y=9,16,3.5 do
   p(f,"FrameBolt",V(.3,.3,.18),cf*CF(x,y,-13.7),C.steel,Enum.Material.Metal)
  end
 end
 -- A restrained concrete apron connects shop and plot, with no tall props.
 p(f,"EntryApron",V(60,.08,22),cf*CF(0,.56,-25),RGB(189,187,166),Enum.Material.Concrete)
end
function Map.Build()
 local lighting=game.Lighting
 lighting.ClockTime=13.5 lighting.Brightness=3 lighting.ExposureCompensation=.15
 lighting.Ambient=RGB(140,150,162) lighting.OutdoorAmbient=RGB(165,174,180)
 lighting.EnvironmentSpecularScale=.20 lighting.EnvironmentDiffuseScale=.75
 lighting.FogStart=340 lighting.FogEnd=650 lighting.FogColor=RGB(204,233,245)
 local at=lighting:FindFirstChildOfClass("Atmosphere")
 if at then at.Density=.16 at.Haze=.35 at.Glare=.08 at.Color=RGB(211,238,249) at.Decay=RGB(180,204,219) end
 local bloom=lighting:FindFirstChildOfClass("BloomEffect") if bloom then bloom.Intensity=.10 end
 local old=workspace:FindFirstChild("JunkyardRefresh")
 if old and old:GetAttribute("Version")==6 then return old end
 -- Replaced map geometry is archived, not destroyed. Terrain/other islands remain.
 local archive=folder(game.ServerStorage,"BeforeOpenSalvage_"..os.time())
 for _,n in ipairs({"JunkyardScene","JunkyardRefresh","SalvageWorksTouchup"}) do
  local item=workspace:FindFirstChild(n) if item then item.Parent=archive end
 end
 local root=folder(workspace,"JunkyardRefresh") root:SetAttribute("Version",6)
 local scene=folder(workspace,"JunkyardScene") scene:SetAttribute("Version",6)
 local routes=folder(root,"Routes") local garages=folder(root,"Garages")
 local props=folder(root,"SalvageDisplays") local scenery=folder(root,"Perimeter")
 folder(root,"Motion")
 -- Keep the original ground datum so pickups and plots continue to align.
 cyl(scene,"DistrictGround",V(1,710,710),CF(0,-.2,0)*CFrame.Angles(0,0,math.pi/2),RGB(161,168,126),Enum.Material.Grass,true)
 cyl(scene,"YardAsphalt",V(1,Layout.YardRadius*2,Layout.YardRadius*2),CF(0,.7,0)*CFrame.Angles(0,0,math.pi/2),RGB(96,112,122),Enum.Material.Asphalt,true)
 for i=1,8 do
  local a=(i-1)*math.pi/4 local radial=V(math.cos(a),0,math.sin(a)) local side=V(-math.sin(a),0,math.cos(a))
  local finish=Layout.PlotRadius-35/math.max(math.abs(radial.X),math.abs(radial.Z))
  local from=radial*(Layout.RouteStart-2) local to=radial*(finish+2)
  local road=bar(routes,"ReturnRoad",from+V(0,.7,0),to+V(0,.7,0),25,1,RGB(101,118,126),Enum.Material.Asphalt)
  road.CanCollide=true road.CanQuery=true
  for _,offset in ipairs({-11.7,11.7}) do
   bar(routes,"RouteGuide",from+side*offset+V(0,1.23,0),to+side*offset+V(0,1.23,0),.35,.025,colors[i])
  end
  for r=107,finish-4,14 do p(routes,"RoadDash",V(.7,.025,5),CFrame.lookAt(radial*r+V(0,1.23,0),radial*(r+1)+V(0,1.23,0)),C.cream) end
  local apron=p(routes,"BayApron",V(70,.16,70),CF(radial*Layout.PlotRadius+V(0,.30,0)),RGB(166,179,181),Enum.Material.Concrete)
  garage(garages,i)
  -- Low, clearly grouped displays in the wedges; empty playable core.
  local pa=a+math.pi/8 local base=V(math.cos(pa)*143,0,math.sin(pa)*143)
  local cf=CFrame.lookAt(base,V()) local f=folder(props,"ScrapPocket"..i)
  p(f,"GravelPocket",V(33,.12,31),cf*CF(0,.35,0),RGB(166,153,126),Enum.Material.Pebble)
  wreck(f,cf*CF(-7,.4,1)*CFrame.Angles(0,.15,0),colors[i])
  wreck(f,cf*CF(-6,5.2,1)*CFrame.Angles(.06,-.10,.06),colors[(i%8)+1])
  for k=1,3 do tyre(f,cf*CF(9,.7+k*1.1,5)*CFrame.Angles(0,0,math.pi/2)) end
  p(f,"PartsBin",V(8,4,7),cf*CF(8,2.4,-7),colors[i])
  p(f,"BinInterior",V(7.2,.2,6.2),cf*CF(8,4.45,-7),C.navy)
  for k=1,3 do cyl(f,"SparePipe",V(3,1,1),cf*CF(6+k,4.8,-7)*CFrame.Angles(0,0,.2*k),C.steel) end
  -- Low boundary rails keep the collection visibly separate from paths.
  for _,x in ipairs({-17,17}) do p(f,"PocketBollard",V(1,3,1),cf*CF(x,1.8,-11),C.yellow) end
 end
 -- Thin ground markings, no gates or fences across the pickup entrances.
 for i=0,47 do
  local a=i*math.pi/24 local b=a+.075
  bar(routes,"YardEdgeMark",V(math.cos(a)*93,1.23,math.sin(a)*93),V(math.cos(b)*93,1.23,math.sin(b)*93),.45,.025,C.cream)
 end
 for i=0,15 do
  local a=i*math.pi/8 local b=a+.20
  bar(routes,"CraneDropRing",V(math.cos(a)*25,1.23,math.sin(a)*25),V(math.cos(b)*25,1.23,math.sin(b)*25),.55,.025,C.yellow)
 end
 -- Outer service road; no tall city blocks enclosing the map.
 for i=0,63 do
  local a=i*math.pi/32 local b=(i+1)*math.pi/32 local radius=Layout.OuterRoadRadius
  local va=V(math.cos(a)*radius,.38,math.sin(a)*radius) local vb=V(math.cos(b)*radius,.38,math.sin(b)*radius)
  p(scenery,"ServiceRoad",V(14,.10,(vb-va).Magnitude+.4),CFrame.lookAt((va+vb)/2,vb),C.navy,Enum.Material.Asphalt)
  bar(scenery,"ServiceDash",va:Lerp(vb,.25)+V(0,.065,0),va:Lerp(vb,.65)+V(0,.065,0),.35,.025,C.cream)
 end
 for i=0,15 do
  local a=(i+.5)*math.pi/8 local pos=V(math.cos(a)*339,0,math.sin(a)*339)
  local cf=CFrame.lookAt(pos,V())
  p(scenery,"BoundaryPanel",V(37,9,.5),cf*CF(0,4.8,0),i%2==0 and C.teal or C.steel)
  for x=-18,18,6 do p(scenery,"FenceRib",V(.3,9,.30),cf*CF(x,4.8,-.4),C.navy) end
  cyl(scenery,"TreeTrunk",V(10,1.6,1.6),cf*CF(12,5,9)*CFrame.Angles(0,0,math.pi/2),RGB(111,83,56),Enum.Material.Wood)
  local crown=p(scenery,"TreeCrown",V(13,14,13),cf*CF(12,16,9),C.green,Enum.Material.Grass) crown.Shape=Enum.PartType.Ball
  -- Low natural boundary replaces the old apartment-block skyline.
  local bank=p(scenery,"RockyBoundary",V(64,17+(i%3)*3,30),cf*CF(0,2,25),RGB(115,134,118),Enum.Material.Rock)
  bank.Shape=Enum.PartType.Ball
  local shrub=p(scenery,"BoundaryShrub",V(17,11,14),cf*CF(-12,8,17),RGB(99,147,76),Enum.Material.Grass)
  shrub.Shape=Enum.PartType.Ball
 end
 -- One recognizable water tower beyond the workshops, rather than a city wall.
 local cf=CFrame.lookAt(V(242,0,242),V())
 for _,x in ipairs({-6,6}) do for _,z in ipairs({-6,6}) do p(scenery,"WaterTowerLeg",V(.7,32,.7),cf*CF(x,16,z),C.steel) end end
 cyl(scenery,"WaterTank",V(15,20,20),cf*CF(0,37,0)*CFrame.Angles(0,0,math.pi/2),C.teal)
 cyl(scenery,"TankRoof",V(.8,22,22),cf*CF(0,45,0)*CFrame.Angles(0,0,math.pi/2),C.navy)
 sign(scenery,cf*CF(0,38,-10.3),V(15,5,.3),"SALVAGE",C.navy)
 return root
end
function Map.DressYard()
 local features=workspace:FindFirstChild("YardFeatures") if not features then return end
 -- Keep the event crane exactly where the spawner expects it; remove the
 -- former central obstacle ring into storage so the new core stays open.
 local archive
 for _,v in ipairs(features:GetChildren()) do
  if v.Name~="MagnetCrane" then
   archive=archive or folder(game.ServerStorage,"RetiredYardObstacles_"..os.time())
   v.Parent=archive
  end
 end
 local crane=features:FindFirstChild("MagnetCrane")
 if crane and not crane:FindFirstChild("SalvageDetail") then
  local f=folder(crane,"SalvageDetail")
  for _,x in ipairs({-3.5,3.5}) do for _,z in ipairs({-3.5,3.5}) do
   for y=2,6,1.5 do p(f,"SafetyStripe",V(1.05,.6,1.05),CF(x,y,z),C.navy) end
  end end
  sign(f,CF(0,28,-3.8),V(7,2,.2),"SALVAGE",C.navy)
 end
end
function Map.DressPlot(plot)
 local ground=plot:FindFirstChild("Ground")
 if ground then ground.Color=RGB(186,197,199) ground.Material=Enum.Material.Concrete end
end
return Map
