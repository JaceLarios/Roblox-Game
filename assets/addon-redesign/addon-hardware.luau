-- Edit-mode build. Produces staged copies only; originals remain installed.
assert(not game:GetService("RunService"):IsRunning(),"Stop Play first")
local names={"Inline 4","V6 Engine","V8 Engine","Jet Engine"}
local templates=game.ReplicatedStorage.ItemModels
for _,name in ipairs(names) do
 assert(templates[name]:GetAttribute("CodexModelRevision")=="AddonHeavyWear_20260923_v3","Unexpected source: "..name)
end
assert(not game.ServerStorage:FindFirstChild("AddonHardwareStaging"),"Inspect existing staging")
local stage=Instance.new("Folder",game.ServerStorage) stage.Name="AddonHardwareStaging"
local steel=Color3.fromRGB(71,67,60)
local rust=Color3.fromRGB(124,73,43)
local edge=Color3.fromRGB(153,139,112)
for _,name in ipairs(names) do
 local m=templates[name]:Clone() m.Parent=stage
 local detail=Instance.new("Model",m) detail.Name="WeatheredSteelHardware"
 local function p(n,size,cf,color,kind)
  local v=Instance.new(kind or "Part") v.Name=n v.Size=size v.CFrame=cf
  v.Color=color or steel v.Material=Enum.Material.CorrodedMetal
  v.Anchored=true v.Massless=true v.CanCollide=false v.CanTouch=false v.CanQuery=false
  v.TopSurface=Enum.SurfaceType.Smooth v.BottomSurface=Enum.SurfaceType.Smooth v.Parent=detail return v
 end
 local function beam(n,a,b,w,h,color)
  return p(n,Vector3.new(w,h,(b-a).Magnitude),CFrame.lookAt((a+b)/2,b),color)
 end
 local function weld(a,b,count)
  for i=0,count-1 do
   local v=p("RaisedWeldBead",Vector3.new(.055,.038,.055),CFrame.new(a:Lerp(b,i/(count-1))),edge)
   v.Shape=Enum.PartType.Ball v.Material=Enum.Material.Metal
  end
 end
 if name=="Jet Engine" then
  -- Broken-angle clamp bands follow the barrel, leaving the fan opening clear.
  for _,z in ipairs({.79,-.73}) do
   local prev
   for i=0,14 do
    local a=2*math.pi*i/14
    local r=(z>0 and .985 or .80)+(i==3 and .018 or 0)
    local point=Vector3.new(math.cos(a)*r,.13+math.sin(a)*r,z+(i==4 and .035 or 0))
    if prev then beam("UnevenBarrelClamp",prev,point,.11,.04,i%4==0 and rust or edge) end
    prev=point
   end
   p("ClampJoinPlate",Vector3.new(.21,.18,.065),CFrame.new(.0,.13+(z>0 and .985 or .80),z)*CFrame.Angles(.08,0,.13),rust)
  end
  for _,x in ipairs({-.73,.73}) do
   beam("BentJetSkid",Vector3.new(x,-1.19,-1.3),Vector3.new(x+.035,-1.23,.3),.13,.13,rust)
   beam("SkidLip",Vector3.new(x,-1.115,-1.3),Vector3.new(x+.035,-1.155,.3),.15,.025,edge)
   p("SkidChippedEnd",Vector3.new(.15,.12,.22),CFrame.new(x,-1.19,.36),rust,"WedgePart")
   weld(Vector3.new(x-.07,-1.11,-.62),Vector3.new(x+.07,-1.11,-.62),4)
  end
 else
  local specs={
   ["Inline 4"]={x=.70,y=-1.25,z=.98,patchX=.77,patchY=-.45,patchZ=-.25},
   ["V6 Engine"]={x=.78,y=-1.10,z=.89,patchX=.89,patchY=-.55,patchZ=-.30},
   ["V8 Engine"]={x=1.22,y=-1.60,z=1.18,patchX=1.65,patchY=.0,patchZ=-.26},
  }
  local s=specs[name]
  for _,sign in ipairs({-1,1}) do
   local x=s.x*sign
   local a=Vector3.new(x,s.y,-s.z)
   local b=Vector3.new(x+sign*.035,s.y-.035,.0)
   local c=Vector3.new(x-sign*.02,s.y+.015,s.z)
   beam("BentMountRail",a,b,.14,.15,rust)
   beam("BentMountRail",b,c,.14,.15,steel)
   beam("ExposedRailLip",a+Vector3.new(0,.083,0),b+Vector3.new(0,.083,0),.17,.023,edge)
   for _,z in ipairs({-s.z*.75,s.z*.75}) do
    p("BuckledMountFoot",Vector3.new(.37,.07,.27),CFrame.new(x,s.y-.11,z)*CFrame.Angles(.06,0,sign*.10),rust)
    local washer=p("DarkBoltSeat",Vector3.new(.13,.025,.13),CFrame.new(x,s.y-.055,z),Color3.fromRGB(40,37,31))
    washer.Material=Enum.Material.Metal
    p("MountBolt",Vector3.new(.07,.045,.07),CFrame.new(x,s.y-.026,z)*CFrame.Angles(0,.4,0),edge)
   end
   p("ChippedRailEnd",Vector3.new(.15,.13,.18),CFrame.new(x,s.y,s.z+.07),rust,"WedgePart")
   local px=s.patchX*sign
   p("UnevenSideRepairPlate",Vector3.new(.047,.37,.51),CFrame.new(px,s.patchY,s.patchZ)*CFrame.Angles(.12,0,sign*.06),rust)
   weld(Vector3.new(px+sign*.035,s.patchY+.19,s.patchZ-.20),Vector3.new(px+sign*.035,s.patchY+.19,s.patchZ+.20),7)
   for _,z in ipairs({s.patchZ-.17,s.patchZ+.17}) do
    local rivet=p("RepairRivet",Vector3.new(.036,.07,.07),CFrame.new(px+sign*.042,s.patchY-.09,z),edge)
    rivet.Shape=Enum.PartType.Ball
   end
  end
  beam("LowerCrossBrace",Vector3.new(-s.x,s.y,-s.z*.7),Vector3.new(s.x,s.y,-s.z*.7),.13,.11,steel)
 end
 m:SetAttribute("CodexModelRevision","AddonHardware_20260923_v4")
 local cf=m:GetBoundingBox()
 m:PivotTo(CFrame.new(-cf.Position)*m:GetPivot()) m.WorldPivot=CFrame.new()
end
return "Four hardware variants staged; originals unchanged."
