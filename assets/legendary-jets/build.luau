-- Edit-time builder: only the three missing Legendary jet fusions.
-- Requires the detailed Sept 23 base vehicles; never edits their templates.
assert(not game:GetService("RunService"):IsRunning(),"Stop Play first")
local templates=game.ReplicatedStorage:WaitForChild("ItemModels")
assert(not game.ServerStorage:FindFirstChild("LegendaryBuildStaging_20260923"), "Inspect existing staging folder before rebuilding")
local stage=Instance.new("Folder") stage.Name="LegendaryBuildStaging_20260923" stage.Parent=game.ServerStorage
local steel=Color3.fromRGB(74,85,99)
local dark=Color3.fromRGB(22,29,40)
local silver=Color3.fromRGB(181,195,200)
local gold=Color3.fromRGB(255,180,39)
local cyan=Color3.fromRGB(36,226,255)
local function part(parent,name,size,cf,color,material,shape)
 local p=Instance.new("Part") p.Name=name p.Size=size p.CFrame=cf p.Color=color p.Material=material or Enum.Material.Metal
 p.Anchored=true p.CanCollide=false p.CanTouch=false p.CanQuery=false p.Massless=true
 if shape then p.Shape=shape end p.Parent=parent return p
end
local function bar(parent,name,a,b,width,color)
 return part(parent,name,Vector3.new(width,width,(b-a).Magnitude),CFrame.lookAt((a+b)/2,b),color)
end
local function ring(parent,name,center,radius,radial,depth,color,material)
 for i=1,16 do local a=i*math.pi/8
  part(parent,name,Vector3.new(2*radius*math.sin(math.pi/16)*1.02,radial,depth),
   CFrame.new(center+Vector3.new(math.cos(a)*radius,math.sin(a)*radius,0))*CFrame.Angles(0,0,a+math.pi/2),color,material)
 end
end
local function disc(parent,name,center,radius,depth,color,material)
 return part(parent,name,Vector3.new(depth,radius*2,radius*2),CFrame.new(center)*CFrame.Angles(0,math.pi/2,0),color,material,Enum.PartType.Cylinder)
end
local function turbine(parent,center,radius,length,paint)
 local jet=Instance.new("Model") jet.Name="DetailedJetTurbine" jet.Parent=parent
 -- Forward is +Z; separate intake fan, barrel, straps and rear nozzle.
 disc(jet,"CompressorBarrel",center,radius*.90,length,steel)
 for i=1,8 do local a=i*math.pi/4
  part(jet,"EnamelArmor",Vector3.new(radius*.56,.07,length*.52),
   CFrame.new(center+Vector3.new(math.cos(a)*radius*.9,math.sin(a)*radius*.9,.05))*CFrame.Angles(0,0,a+math.pi/2),paint)
 end
 for _,z in {-.26,.26} do
  ring(jet,"MountingBand",center+Vector3.new(0,0,length*z),radius*.94,.08,.14,gold)
  for i=1,8 do local a=i*math.pi/4
   part(jet,"BandFastener",Vector3.new(.07,.07,.09),CFrame.new(center+Vector3.new(math.cos(a)*radius,math.sin(a)*radius,length*z+.075)),silver,Enum.Material.Metal,Enum.PartType.Ball)
  end
 end
 local front=center+Vector3.new(0,0,length/2+.05)
 disc(jet,"DarkIntake",front,radius*.93,.10,dark)
 ring(jet,"RolledIntakeLip",front+Vector3.new(0,0,.10),radius,.12,.17,silver)
 for i=1,10 do local a=i*math.pi/5
  part(jet,"CompressorBlade",Vector3.new(radius*.64,.075,.12),
   CFrame.new(front+Vector3.new(math.cos(a)*radius*.48,math.sin(a)*radius*.48,.13))*CFrame.Angles(0,0,a+.55),silver)
 end
 part(jet,"IntakeSpinner",Vector3.new(radius*.40,radius*.40,radius*.45),CFrame.new(front+Vector3.new(0,0,.19)),gold,Enum.Material.Metal,Enum.PartType.Ball)
 local rear=center-Vector3.new(0,0,length/2+.08)
 disc(jet,"ExhaustRecess",rear,radius*.84,.10,dark)
 ring(jet,"HeatShield",rear,radius*.88,.12,.20,Color3.fromRGB(118,77,66))
 ring(jet,"AfterburnerGlow",rear-Vector3.new(0,0,.12),radius*.70,.065,.08,cyan,Enum.Material.Neon)
 disc(jet,"HotCore",rear-Vector3.new(0,0,.14),radius*.38,.07,Color3.fromRGB(255,133,29),Enum.Material.Neon)
 for i=1,10 do local a=i*math.pi/5
  part(jet,"NozzlePetal",Vector3.new(radius*.35,.12,.40),
   CFrame.new(rear+Vector3.new(math.cos(a)*radius*.82,math.sin(a)*radius*.82,-.14))*CFrame.Angles(0,0,a+math.pi/2),steel)
 end
 -- Heat-darkened seams, wiring, inspection bolts and service access.
 bar(jet,"FuelLine",center+Vector3.new(radius*.5,radius*.8,-length*.3),center+Vector3.new(radius*.5,radius*.8,length*.3),.055,cyan)
 -- Layered service panels, exposed fasteners and cooling ribs on both sides.
 for _,side in {-1,1} do
  local x=side*(radius*.94+.045)
  part(jet,"ServicePanelGasket",Vector3.new(.035,.35,.69),CFrame.new(center+Vector3.new(x,0,.02)),dark)
  part(jet,"ServicePanel",Vector3.new(.045,.29,.61),CFrame.new(center+Vector3.new(x+side*.025,0,.02)),paint)
  for _,dy in {-.105,.105} do for _,dz in {-.23,.23} do
   part(jet,"ServicePanelRivet",Vector3.new(.06,.045,.045),CFrame.new(center+Vector3.new(x+side*.06,dy,dz+.02)),silver,Enum.Material.Metal,Enum.PartType.Ball)
  end end
  for j=1,5 do
   part(jet,"CoolingLouvre",Vector3.new(.065,.19,.035),CFrame.new(center+Vector3.new(x+side*.06,0,-.17+j*.065))*CFrame.Angles(.25,0,0),dark)
  end
  for j=1,3 do
   part(jet,"WarningStripe",Vector3.new(.045,.16,.05),CFrame.new(center+Vector3.new(x+side*.02,.03,length*.31+j*.07))*CFrame.Angles(-.4,0,0),gold)
  end
 end
 for j=1,3 do
  ring(jet,"ExhaustCoolingRib",center+Vector3.new(0,0,-length*.32-j*.10),radius*.92,.045,.035,silver)
 end
 jet:SetAttribute("MountClearance",.20)
 return jet
end
local configs={
 {name="Rocket Rider",base="Dirt Bike",length=5.8,color=Color3.fromRGB(239,71,39)},
 {name="Afterburner GT",base="Muscle Car",length=6.0,color=Color3.fromRGB(255,115,21)},
 {name="Sky Marshal",base="Cop Cruiser",length=6.0,color=Color3.fromRGB(24,113,233)}
}
local results={}
for _,c in configs do
 local m=templates[c.base]:Clone() m.Name=c.name m.Parent=stage
 local cf,size=m:GetBoundingBox() m:PivotTo(CFrame.new(-cf.Position)*m:GetPivot())
 m:ScaleTo(m:GetScale()*c.length/size.Z)
 local _,baseBounds=m:GetBoundingBox()
 -- Keep the entire intake lip outside the base vehicle's bounding envelope.
 local jetX=baseBounds.X/2+.59+.20
 local hardware=Instance.new("Model") hardware.Name="LegendaryJetHardware" hardware.Parent=m
 if c.base=="Dirt Bike" then
  -- A single side-mounted turbine retains the two-wheel bike silhouette.
  turbine(hardware,Vector3.new(jetX,.20,-.35),.59,3.35,c.color)
  for _,z in {-1.35,.7} do
   bar(hardware,"WeldedEngineCradle",Vector3.new(.25,-.55,z),Vector3.new(jetX,-.45,z),.14,steel)
   bar(hardware,"DiagonalEngineStay",Vector3.new(.18,.55,z),Vector3.new(jetX,-.44,z),.085,silver)
   part(hardware,"CradleMountFoot",Vector3.new(.30,.12,.28),CFrame.new(jetX,-.45,z),gold)
  end
  part(hardware,"RearAeroFin",Vector3.new(.10,.60,1.15),CFrame.new(0,1.04,-1.93)*CFrame.Angles(.12,0,0),c.color)
  for _,x in {-.45,.45} do
   bar(hardware,"FrameBrace",Vector3.new(x,-.4,-1.6),Vector3.new(x,.72,.28),.065,gold)
  end
  part(hardware,"FrontRacePlate",Vector3.new(.67,.58,.085),CFrame.new(0,.73,1.42)*CFrame.Angles(-.12,0,0),gold)
 else
  local cop=c.base=="Cop Cruiser"
  local y=cop and .95 or .68
  for _,sign in {-1,1} do
   turbine(hardware,Vector3.new(sign*jetX,y,-1.02),.56,2.85,c.color)
   for _,z in {-1.85,-.15} do
    bar(hardware,"ChassisPylon",Vector3.new(sign*.9,-.05,z),Vector3.new(sign*jetX,y-.53,z),.14,steel)
    bar(hardware,"TriangulatedMount",Vector3.new(sign*1.1,-.45,z+.25),Vector3.new(sign*jetX,y-.53,z),.09,silver)
    part(hardware,"PylonSaddle",Vector3.new(.34,.12,.32),CFrame.new(sign*jetX,y-.53,z),gold)
    for _,offset in {-.10,.10} do
     part(hardware,"SaddleBolt",Vector3.new(.065,.065,.065),CFrame.new(sign*jetX+offset,y-.44,z),silver,Enum.Material.Metal,Enum.PartType.Ball)
    end
   end
   part(hardware,"AeroFin",Vector3.new(.10,.76,1.10),CFrame.new(sign*1.1,y+.82,-1.80)*CFrame.Angles(.12,0,0),c.color)
   part(hardware,"FinStripe",Vector3.new(.112,.14,.78),CFrame.new(sign*1.1,y+.84,-1.77)*CFrame.Angles(.12,0,0),gold)
   for j=1,4 do
    part(hardware,"SideVent",Vector3.new(.09,.23,.09),CFrame.new(sign*1.73,.11,-.30+j*.16)*CFrame.Angles(.22,0,0),dark)
   end
  end
  part(hardware,"RearWing",Vector3.new(3.48,.11,.49),CFrame.new(0,y+.77,-2.16)*CFrame.Angles(-.12,0,0),c.color)
  if cop then
   -- Keep the original roof lights and push bar visible; add pursuit strobes.
   for _,sign in {-1,1} do
    part(hardware,"InterceptorLamp",Vector3.new(.30,.12,.08),CFrame.new(sign*.82,-.3,2.98),sign<0 and Color3.fromRGB(255,42,57) or cyan,Enum.Material.Neon)
    part(hardware,"GoldAuthorityFlash",Vector3.new(.055,.30,.75),CFrame.new(sign*1.70,.25,.55),gold)
   end
  else
   for _,x in {-.33,.33} do
    part(hardware,"RamAirScoop",Vector3.new(.49,.22,.76),CFrame.new(x,.48,1.19),dark)
    part(hardware,"ScoopMouth",Vector3.new(.37,.13,.035),CFrame.new(x,.49,1.59),silver)
   end
   part(hardware,"FrontSplitter",Vector3.new(3.35,.10,.30),CFrame.new(0,-.26,2.90),dark)
  end
 end
 -- Deterministic small scratches at exposed hardware edges; actual geometry
 -- remains visible in ViewportFrames, unlike SurfaceGui-only wear.
 for i=1,12 do
  local side=i%2==0 and 1 or -1
  local x=c.base=="Dirt Bike" and jetX+.59 or side*(jetX+.57)
  local y=c.base=="Dirt Bike" and .20 or c.base=="Cop Cruiser" and .95 or .68
  part(hardware,"EdgeScuff",Vector3.new(.018,.022,.12+(i%3)*.04),CFrame.new(x,y+(i%4)*.07,-1.8+(i%6)*.33)*CFrame.Angles(.28,0,0),silver)
 end
 local _,bounds=m:GetBoundingBox()
 m:ScaleTo(m:GetScale()*7/math.max(bounds.X,bounds.Y,bounds.Z))
 local center=m:GetBoundingBox() m:PivotTo(CFrame.new(-center.Position)*m:GetPivot())
 m:SetAttribute("CodexModelRevision","LegendaryJetFusions_20260923_v2")
 m:SetAttribute("DisplayName",c.name) m:SetAttribute("BaseVehicle",c.base) m:SetAttribute("Addon","Jet Engine") m:SetAttribute("Rarity","Legendary")
 for _,p in m:GetDescendants() do if p:IsA("BasePart") then p.Anchored=true p.CanCollide=false p.CanTouch=false p.CanQuery=false end end
 local _,final=m:GetBoundingBox() local count=0 for _,p in m:GetDescendants() do if p:IsA("BasePart") then count+=1 end end
 table.insert(results,{name=c.name,size=tostring(final),parts=count})
end
return game.HttpService:JSONEncode(results)
