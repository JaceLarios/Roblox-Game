-- Compact Salvage Works dressing. No plot, route, collider or spawn changes.
local M={}
local V,CF,RGB=Vector3.new,CFrame.new,Color3.fromRGB
local palette={RGB(12,155,177),RGB(242,129,39),RGB(38,119,202),RGB(16,156,167),RGB(229,112,32),RGB(32,126,193),RGB(14,162,175),RGB(232,139,44)}
local navy,cream,rust,steel=RGB(32,47,57),RGB(244,226,179),RGB(135,75,43),RGB(88,96,97)
local function part(parent,name,size,cf,col,mat,shape)
 local p=Instance.new("Part") p.Name=name p.Size=size p.CFrame=cf p.Color=col
 p.Material=mat or Enum.Material.Metal p.Anchored=true
 p.CanCollide=false p.CanTouch=false p.CanQuery=false
 p.TopSurface=Enum.SurfaceType.Smooth p.BottomSurface=Enum.SurfaceType.Smooth
 if shape then p.Shape=shape end
 p.CastShadow=size.Y>.4 p.Parent=parent return p
end
local function paint(p,col,mat)
 if p:GetAttribute("SalvageOriginalColor")==nil then
  p:SetAttribute("SalvageOriginalColor",p.Color)
  p:SetAttribute("SalvageOriginalMaterial",p.Material.Name)
 end
 p.Color=col if mat then p.Material=mat end
end
local function label(p,text)
 for _,face in ipairs({Enum.NormalId.Front,Enum.NormalId.Back}) do
 local gui=Instance.new("SurfaceGui",p) gui.Face=Enum.NormalId.Front gui.PixelsPerStud=28 gui.SizingMode=Enum.SurfaceGuiSizingMode.PixelsPerStud
 gui.Face=face gui.LightInfluence=0
 local l=Instance.new("TextLabel",gui) l.Size=UDim2.fromScale(1,1) l.BackgroundTransparency=1
 l.Text=text l.Font=Enum.Font.FredokaOne l.TextScaled=true l.TextColor3=cream
 end
end
local function beam(f,n,a,b,w,h,col,mat)
 return part(f,n,V(w,h,(b-a).Magnitude),CFrame.lookAt((a+b)/2,b),col,mat)
end
function M.Build()
 local scene=assert(workspace:FindFirstChild("JunkyardScene"),"Baseline missing")
 local refresh=assert(workspace:FindFirstChild("JunkyardRefresh"),"Refresh missing")
 local yard=assert(workspace:FindFirstChild("YardFeatures"),"Yard missing")
 local existing=workspace:FindFirstChild("SalvageWorksTouchup")
 if existing then
  assert(existing:GetAttribute("Version")==1,"Inspect older touchup before replacing")
  return existing
 end
 local root=Instance.new("Folder") root.Name="SalvageWorksTouchup" root:SetAttribute("Version",1)
 local function folder(n) local f=Instance.new("Folder",root) f.Name=n return f end
 local garages=folder("GarageDetail")
 for i=1,8 do
  local g=assert(refresh.Garages:FindFirstChild("Garage"..i))
  local roof=g.Canopy local center=g.BayApron.Position*V(1,0,1) local color=palette[i]
  paint(roof,color) paint(g.WorkshopBack,color:Lerp(navy,.3))
  paint(g.RoofEdge,cream) paint(g.GarageNumber,navy)
  for _,l in ipairs(g.GarageNumber:GetDescendants()) do
   if l:IsA("TextLabel") then
    if l:GetAttribute("SalvageOriginalTextColor")==nil then l:SetAttribute("SalvageOriginalTextColor",l.TextColor3) end
    l.TextColor3=cream
   end
  end
  -- Rear siding and upper fascia only: no new walls in placement areas.
  for x=-30,30,5 do
   part(garages,"RearSidingRib",V(.18,10.5,.15),CF(center+V(x,6,-33.65)),color)
  end
  for x=-30,30,6 do
   part(garages,"RoofSeam",V(.18,.10,16.5),roof.CFrame*CF(x,.65,0),color:Lerp(cream,.28))
  end
  for _,x in ipairs({-26,26}) do
   part(garages,"RoofRepair",V(7,.09,5),roof.CFrame*CF(x,.68,1.5)*CFrame.Angles(0,x<0 and .10 or -.07,0),rust,Enum.Material.CorrodedMetal)
   part(garages,"CornerCladding",V(5,10.5,.25),CF(center+V(x,6,-33.45)),color)
   for y=2,10,4 do
    part(garages,"CladdingBolt",V(.22,.22,.13),CF(center+V(x-2,y,-33.25)),steel,Enum.Material.Metal,Enum.PartType.Ball)
    part(garages,"CladdingBolt",V(.22,.22,.13),CF(center+V(x+2,y,-33.25)),steel,Enum.Material.Metal,Enum.PartType.Ball)
   end
  end
  local fascia=part(garages,"WorkshopFascia",V(62,2,.28),CF(center+V(0,16,-18.05)),color)
  label(fascia,string.format("SALVAGE WORKS   /   BAY %02d",i))
  for _,p in ipairs(g:GetChildren()) do
   if p.Name=="GaragePillar" then
    for y=1,5,1.4 do part(garages,"PillarSafetyBand",V(1.34,.55,1.34),p.CFrame*CF(0,y-9,0),cream) end
   end
  end
 end
 -- Dress only the twelve playable car blocks. Their original collision
 -- surfaces, heights and step layout stay intact.
 local wrecks=folder("WreckDetail")
 for _,m in ipairs(yard:GetChildren()) do
  if m.Name=="JunkPile" then
   for _,p in ipairs(m:GetChildren()) do
    if p.Name=="CrushedCar" then
     local s,cf=p.Size,p.CFrame
     local color=palette[(math.floor(math.abs(p.Position.X+p.Position.Z+p.Position.Y))%#palette)+1]:Lerp(rust,.25)
     paint(p,color,Enum.Material.Metal)
     for _,sign in ipairs({-1,1}) do
      part(wrecks,"BentBumper",V(.28,.45,s.Z*.82),cf*CF(sign*(s.X/2+.09),-.55,0)*CFrame.Angles(0,0,sign*.07),steel,Enum.Material.CorrodedMetal)
      for _,z in ipairs({-.30,.30}) do
       part(wrecks,"OldHeadlight",V(.16,.38,.58),cf*CF(sign*(s.X/2+.25),.02,s.Z*z),cream,Enum.Material.Glass)
      end
      -- Wheels face out along Z, tucked against the existing body.
      for _,x in ipairs({-.31,.31}) do
       local wc=cf*CF(s.X*x,-.85,sign*(s.Z/2+.05))*CFrame.Angles(0,math.pi/2,0)
       part(wrecks,"WreckWheel",V(.35,1.5,1.5),wc,navy,Enum.Material.SmoothPlastic,Enum.PartType.Cylinder)
       part(wrecks,"RustedHub",V(.38,.70,.70),wc,rust,Enum.Material.CorrodedMetal,Enum.PartType.Cylinder)
      end
      part(wrecks,"DoorSeam",V(.07,1.8,.04),cf*CF(-s.X*.08,0,sign*(s.Z/2+.065)),navy)
     end
     -- Small flattened roof silhouette; low enough not to hide pickups.
     part(wrecks,"CrushedRoof",V(s.X*.42,.22,s.Z*.70),cf*CF(-s.X*.06,s.Y/2+.10,0)*CFrame.Angles(0,0,.025),p.Color:Lerp(rust,.30),Enum.Material.CorrodedMetal)
     part(wrecks,"RoofPaintPatch",V(s.X*.22,.04,s.Z*.36),cf*CF(-s.X*.12,s.Y/2+.24,0),color,Enum.Material.Metal)
     for _,sign in ipairs({-1,1}) do
      part(wrecks,"SideWindow",V(s.X*.32,.60,.07),cf*CF(-s.X*.06,.70,sign*(s.Z/2+.08)),navy,Enum.Material.Glass)
      part(wrecks,"DoorHandle",V(.48,.12,.12),cf*CF(-s.X*.03,-.05,sign*(s.Z/2+.10)),cream)
      for z=-1,1 do
       part(wrecks,"GrilleSlot",V(.13,.10,.75),cf*CF(sign*(s.X/2+.18),-.20+z*.16,0),navy)
      end
     end
    end
   end
  end
 end
 local crane=folder("CraneDetail")
 local tower=yard.MagnetCrane
 -- Keep the existing moving arm untouched, including its pivot/drop origin.
 for _,p in ipairs(tower:GetChildren()) do
  if p:IsA("BasePart") and p.Name=="Leg" then
   paint(p,RGB(248,183,35))
   for y=2,5,1.4 do
    part(crane,"TowerSafetyBand",V(1.04,.6,1.04),CF(p.Position.X,y,p.Position.Z),navy)
   end
   for y=8,27,9 do
    part(crane,"TowerRepairPlate",V(1.2,1.8,.11),CF(p.Position.X,y,p.Position.Z+.56),rust,Enum.Material.CorrodedMetal)
   end
  end
 end
 -- Back-mounted ladder is decorative and remains inside the tower footprint.
 for y=3,27,1.8 do part(crane,"LadderRung",V(2,.14,.18),CF(0,y,-3.6),steel) end
 for _,x in ipairs({-1,1}) do part(crane,"LadderRail",V(.16,26,.18),CF(x,15,-3.6),cream) end
 local sign=part(crane,"CraneWorksPlate",V(7,2,.18),CF(0,28,-3.8),navy)
 label(sign,"SALVAGE WORKS")
 local ground=folder("GroundDetail")
 -- Short seams beside existing obstacles; no query surfaces or collision.
 for _,m in ipairs(yard:GetChildren()) do
  if m:IsA("Model") and m.Name~="MagnetCrane" then
   local cf=m:GetBoundingBox() local pos=cf.Position
   local a=V(pos.X-4,1.213,pos.Z+5)
   beam(ground,"AsphaltSeam",a,a+V(3,0,1.2),.075,.013,navy,Enum.Material.Asphalt)
   beam(ground,"AsphaltSeam",a+V(3,0,1.2),a+V(5,0,.7),.065,.013,navy,Enum.Material.Asphalt)
  end
 end
 -- A few weed tufts at the existing staging aprons, outside pickup square.
 for i=0,7 do
  local a=(i+.5)*math.pi/4
  local cf=CFrame.lookAt(V(math.cos(a)*128,0,math.sin(a)*128),V())
  for k=1,3 do
   part(ground,"GravelEdge",V(2.3,.12,1.7),cf*CF(19,.15,k*2),RGB(120,115,96),Enum.Material.Pebble)
   for j=1,2 do
    part(ground,"WeedBlade",V(.12,1.0+j*.25,.38),cf*CF(19+j*.24,.65,k*2)*CFrame.Angles(.1,0,j==1 and .28 or -.25),RGB(100,130,71),Enum.Material.Grass)
   end
  end
 end
 -- Ground-floor industrial color bands on the closest skyline buildings.
 local facades=folder("DistrictDetail")
 local buildings={}
 for _,p in ipairs(scene:GetChildren()) do if p.Name=="Building" then table.insert(buildings,p) end end
 table.sort(buildings,function(a,b) return a.Position.Magnitude<b.Position.Magnitude end)
 for i=1,math.min(8,#buildings) do
  local p=buildings[i] local s=p.Size local col=palette[(i-1)%#palette+1]:Lerp(navy,.30)
  for _,sign in ipairs({-1,1}) do
   part(facades,"WarehouseColorBand",V(s.X,6,.16),p.CFrame*CF(0,-s.Y/2+4,sign*(s.Z/2+.17)),col)
  end
 end
 root.Parent=workspace
 return root
end
return M
