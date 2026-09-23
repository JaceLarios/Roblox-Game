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
local function detailedWreck(f,cf,name,color)
 local library=game.ReplicatedStorage:FindFirstChild("ItemModels")
 local source=library and library:FindFirstChild(name)
 if not source or not source:IsA("Model") then wreck(f,cf,color) return 5 end
 local m=source:Clone() m.Name="Salvaged "..name
 for _,v in ipairs(m:GetDescendants()) do
  for _,tag in ipairs(game.CollectionService:GetTags(v)) do game.CollectionService:RemoveTag(v,tag) end
  if v:IsA("Script") or v:IsA("LocalScript") or v:IsA("ProximityPrompt") then v:Destroy()
  elseif v:IsA("BasePart") then v.Anchored=true v.CanCollide=false v.CanTouch=false v.CanQuery=false end
 end
 for _,tag in ipairs(game.CollectionService:GetTags(m)) do game.CollectionService:RemoveTag(m,tag) end
 local size=m:GetExtentsSize()
 m:ScaleTo(m:GetScale()*14/math.max(size.X,size.Z))
 local box,newSize=m:GetBoundingBox()
 m:PivotTo(cf*CF(0,newSize.Y/2,0)*box:Inverse()*m:GetPivot())
 m:SetAttribute("DisplayOnly",true) m.Parent=f
 return newSize.Y
end
local function container(f,cf,color)
 p(f,"StorageContainer",V(22,10,10),cf*CF(0,5,0),color)
 for x=-10,10,2 do
  p(f,"ContainerRib",V(.16,9,.18),cf*CF(x,5,-5.15),color:Lerp(C.cream,.20))
 end
 p(f,"ContainerRoof",V(23,.35,11),cf*CF(0,10.2,0),C.steel,Enum.Material.CorrodedMetal)
 for _,x in ipairs({-5.5,5.5}) do
  p(f,"ContainerDoor",V(10.5,9,.13),cf*CF(x,5,5.1),color:Lerp(C.navy,.15))
  p(f,"DoorLockBar",V(.18,8,.22),cf*CF(x,5,5.25),C.steel)
 end
 p(f,"RustRepair",V(5,3,.16),cf*CF(-6,2.5,-5.27)*CFrame.Angles(0,0,.08),C.rust,Enum.Material.CorrodedMetal)
end
local Workshop=require(game.ServerStorage:WaitForChild("Workshop"))
local function garage(parent,i)
 Workshop.Build(parent,i,Layout,colors[i])
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
 if old and old:GetAttribute("Version")==9 then return old end
 -- Replaced map geometry is archived, not destroyed. Terrain/other islands remain.
 local archive=folder(game.ServerStorage,"BeforeOpenSalvage_"..os.time())
 for _,n in ipairs({"JunkyardScene","JunkyardRefresh","SalvageWorksTouchup"}) do
  local item=workspace:FindFirstChild(n) if item then item.Parent=archive end
 end
 local root=folder(workspace,"JunkyardRefresh") root:SetAttribute("Version",9)
 local scene=folder(workspace,"JunkyardScene") scene:SetAttribute("Version",9)
 local routes=folder(root,"Routes") local garages=folder(root,"Garages")
 local props=folder(root,"SalvageDisplays") local scenery=folder(root,"Perimeter")
 folder(root,"Motion")
 -- Keep the original ground datum so pickups and plots continue to align.
 cyl(scene,"DistrictGround",V(1,650,650),CF(0,-.2,0)*CFrame.Angles(0,0,math.pi/2),RGB(137,132,108),Enum.Material.Ground,true)
 cyl(scene,"YardAsphalt",V(1,Layout.YardRadius*2,Layout.YardRadius*2),CF(0,.7,0)*CFrame.Angles(0,0,math.pi/2),RGB(96,112,122),Enum.Material.Asphalt,true)
 for i=1,8 do
  local a=(i-1)*math.pi/4 local radial=V(math.cos(a),0,math.sin(a)) local side=V(-math.sin(a),0,math.cos(a))
  local finish=Layout.PlotRadius-Layout.PlotSize/2
  local from=radial*(Layout.RouteStart-2) local to=radial*(finish+2)
  local road=bar(routes,"ReturnRoad",from+V(0,.7,0),to+V(0,.7,0),25,1,RGB(101,118,126),Enum.Material.Asphalt)
  road.CanCollide=true road.CanQuery=true
  for _,offset in ipairs({-11.7,11.7}) do
   bar(routes,"RouteGuide",from+side*offset+V(0,1.23,0),to+side*offset+V(0,1.23,0),.35,.025,colors[i])
  end
  for r=107,finish-4,14 do p(routes,"RoadDash",V(.7,.025,5),CFrame.lookAt(radial*r+V(0,1.23,0),radial*(r+1)+V(0,1.23,0)),C.cream) end
  local apron=p(routes,"BayApron",V(Layout.PlotSize,.16,Layout.PlotSize),CFrame.lookAt(radial*Layout.PlotRadius+V(0,.30,0),V(0,.30,0)),RGB(166,179,181),Enum.Material.Concrete)
  garage(garages,i)
  -- Low, clearly grouped displays in the wedges; empty playable core.
  local pa=a+math.pi/8 local base=V(math.cos(pa)*125,0,math.sin(pa)*125)
  local cf=CFrame.lookAt(base,V()) local f=folder(props,"ScrapPocket"..i)
  p(f,"GravelPocket",V(43,.12,47),cf*CF(0,.35,4),RGB(149,139,117),Enum.Material.Pebble)
  local roster={"Rusted Sedan","Muscle Car","Cop Cruiser","Box Truck"}
  local height=detailedWreck(f,cf*CF(-7,.4,0)*CFrame.Angles(0,.30,0),roster[(i-1)%4+1],colors[i])
  detailedWreck(f,cf*CF(-6,height+.5,1)*CFrame.Angles(.025,-.10,.025),roster[i%4+1],colors[(i%8)+1])
  -- Steel rack supports the upper wreck instead of floating above a low hood.
  for _,x in ipairs({-13,1}) do
   for _,z in ipairs({-5,6}) do p(f,"WreckRackPost",V(.45,height+.5,.45),cf*CF(x,(height+.5)/2,z),C.rust,Enum.Material.CorrodedMetal) end
  end
  for _,z in ipairs({-4,5}) do p(f,"WreckRackBeam",V(15,.4,.65),cf*CF(-6,height+.3,z),C.steel,Enum.Material.CorrodedMetal) end
  container(f,cf*CF(0,0,21),colors[(i%8)+1])
  for k=1,3 do tyre(f,cf*CF(9,.7+k*1.1,5)*CFrame.Angles(0,0,math.pi/2)) end
  p(f,"PartsBin",V(8,4,7),cf*CF(8,2.4,-7),colors[i])
  p(f,"BinInterior",V(7.2,.2,6.2),cf*CF(8,4.45,-7),C.navy)
  for k=1,3 do cyl(f,"SparePipe",V(3,1,1),cf*CF(6+k,4.8,-7)*CFrame.Angles(0,0,.2*k),C.steel) end
  for k=1,3 do
   local drum=cf*CF(16,.3,k*4-2)
   cyl(f,"OilDrum",V(4.4,2.8,2.8),drum*CF(0,2.2,0)*CFrame.Angles(0,0,math.pi/2),k%2==0 and C.orange or C.steel,Enum.Material.CorrodedMetal)
   for _,y in ipairs({.7,3.7}) do cyl(f,"DrumBand",V(.15,2.9,2.9),drum*CF(0,y,0)*CFrame.Angles(0,0,math.pi/2),C.navy) end
  end
  for _,x in ipairs({-20,20}) do
   p(f,"RackPost",V(.4,10,.4),cf*CF(x,5,19),C.navy)
   for y=2,7,5 do p(f,"ScrapRack",V(6,.3,5),cf*CF(x,y,19),C.steel,Enum.Material.DiamondPlate) end
   for z=17,21,2 do tyre(f,cf*CF(x,8.5,z)) end
  end
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
  local a=(i+.5)*math.pi/8 local pos=V(math.cos(a)*312,0,math.sin(a)*312)
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
 for i=0,3 do
  local a=(i*2+.5)*math.pi/4
  local depot=CFrame.lookAt(V(math.cos(a)*236,0,math.sin(a)*236),V())
  local f=folder(scenery,"SalvageDepot"..i)
  container(f,depot*CF(-9,0,0),C.orange)
  container(f,depot*CF(11,0,9)*CFrame.Angles(0,.12,0),C.teal)
  container(f,depot*CF(-9,10.5,0),C.steel)
  sign(f,depot*CF(-9,16,-5.4),V(18,3,.2),i%2==0 and "PARTS & SALVAGE" or "REPAIR / REUSE",C.navy)
  for k=1,3 do
   p(f,"Pallet",V(8,.6,7),depot*CF(11,.5+(k-1)*.7,-6),C.rust,Enum.Material.WoodPlanks)
  end
 end
 local cf=CFrame.lookAt(V(221,0,221),V())
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
