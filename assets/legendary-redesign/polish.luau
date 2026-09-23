-- Apply after the v3 restore, or to installed v3 templates. Preserves originals.
assert(not game:GetService("RunService"):IsRunning(), "Stop Play first")
local templates=game.ReplicatedStorage.ItemModels
local names={"Rocket Rider","Afterburner GT","Sky Marshal"}
for _,name in ipairs(names) do
 assert(templates[name]:GetAttribute("CodexModelRevision")=="LegendaryFullBody_20260923_v3", "Unexpected revision: "..name)
end
local stage=Instance.new("Folder",game.ServerStorage)
stage.Name="LegendaryPolishStaging"
local function part(parent,name,size,cf,color,material)
 local p=Instance.new("Part") p.Name=name p.Size=size p.CFrame=cf
 p.Color=color p.Material=material or Enum.Material.Metal
 p.Anchored=true p.Massless=true p.CanCollide=false p.CanTouch=false p.CanQuery=false
 p.TopSurface=Enum.SurfaceType.Smooth p.BottomSurface=Enum.SurfaceType.Smooth p.Parent=parent
 return p
end
local function cylinder(parent,name,pos,radius,depth,color,material)
 local p=part(parent,name,Vector3.new(depth,radius*2,radius*2),CFrame.new(pos),color,material)
 p.Shape=Enum.PartType.Cylinder return p
end
for _,name in ipairs(names) do
 local model=templates[name]:Clone() model.Parent=stage
 local details=Instance.new("Model",model) details.Name="PrecisionDetails"
 local accent=name=="Sky Marshal" and Color3.fromRGB(22,194,255) or Color3.fromRGB(255,188,33)
 local wheels={}
 for _,p in ipairs(model:GetDescendants()) do
  if p:IsA("MeshPart") then
   -- Existing gray vertex tint was dimming every painted texture by ~36%.
   p.Color=Color3.new(1,1,1)
   if p.Name:find("wheel") then table.insert(wheels,p) end
  end
 end
 for _,wheel in ipairs(wheels) do
  local sides=name=="Rocket Rider" and {-1,1} or {wheel.Position.X<0 and -1 or 1}
  for _,side in ipairs(sides) do
   local center=wheel.Position+Vector3.new(side*(wheel.Size.X/2+.013),0,0)
   local radius=math.min(wheel.Size.Y,wheel.Size.Z)*.31
   cylinder(details,"MachinedBrakeRotor",center,radius*.78,.025,Color3.fromRGB(106,116,131))
   for i=1,16 do
    local angle=i*math.pi/8
    local point=center+Vector3.new(side*.021,math.cos(angle)*radius,math.sin(angle)*radius)
    part(details,"AnodizedRimLip",Vector3.new(.033,2*radius*math.sin(math.pi/16)*1.01,.035),CFrame.new(point)*CFrame.Angles(angle+math.pi/2,0,0),accent)
   end
   for i=1,6 do
    local angle=i*math.pi/3
    local point=center+Vector3.new(side*.05,math.cos(angle)*radius*.28,math.sin(angle)*radius*.28)
    cylinder(details,"WheelLug",point,.027,.04,Color3.fromRGB(228,234,242))
    local hole=center+Vector3.new(side*.021,math.cos(angle+.2)*radius*.61,math.sin(angle+.2)*radius*.61)
    cylinder(details,"RotorDrilling",hole,.023,.027,Color3.fromRGB(24,29,37))
   end
   cylinder(details,"HubCap",center+Vector3.new(side*.048,0,0),radius*.18,.065,accent)
   part(details,"BrakeCaliper",Vector3.new(.045,radius*.52,radius*.20),CFrame.new(center+Vector3.new(side*.018,radius*.18,radius*.59)),Color3.fromRGB(235,48,33))
  end
 end
 model:SetAttribute("CodexModelRevision","LegendaryFullBody_20260923_v4")
 local _,size=model:GetBoundingBox()
 assert(math.abs(math.max(size.X,size.Y,size.Z)-7)<.015, "Details exceeded size budget")
end
local backup=Instance.new("Folder",game.ServerStorage)
backup.Name="LegendaryBeforePolish_"..os.time()
for _,name in ipairs(names) do
 templates[name].Parent=backup
 stage[name].Parent=templates
end
stage:Destroy()
print("Brightened all three Legendary textures and added precision wheel hardware; originals backed up.")
