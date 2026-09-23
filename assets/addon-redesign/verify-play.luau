-- Run on Server in a fresh Studio Play session. Does not grant inventory.
local V=require(game.ReplicatedStorage.ItemVisuals)
local R=require(game.ReplicatedStorage.FusionRecipes)
local report={}
for _,name in ipairs({"Nitrous Tank","Inline 4","V6 Engine","V8 Engine","Jet Engine"}) do
 local combinations=0
 for _,car in ipairs({"Rusted Sedan","Dirt Bike","Golf Cart","Muscle Car","Cop Cruiser","Box Truck","Monster Truck"}) do
  assert(R.Fuse(car,name),"Missing recipe for "..car.." + "..name)
  combinations+=1
 end
 local parts=0
 for _,scale in ipairs({.55,1,1.3}) do
  local root=V.Create(name,Vector3.new(0,800,0),scale)
  assert(root:GetAttribute("ItemAssembly"),"Placeholder/legacy part: "..name)
  assert(math.abs(root.Position.Y-root.Size.Y/2-800)<.001,"Ground placement")
  root.Parent=workspace
  root.CFrame=CFrame.new(10,810,10)*CFrame.Angles(.1,.7,0)
  V.Resize(root,root.Size*.8)
  task.wait(.1)
  parts=0
  for _,joint in ipairs(root:GetChildren()) do
   if joint:IsA("Weld") then
    assert((joint.Part1.Position-(root.CFrame*joint.C0).Position).Magnitude<.01,"Detached visual")
    parts+=1
   end
  end
  local color=Color3.fromRGB(255,190,45)
  V.Tint(root,color) V.SetTransparency(root,.6)
  for _,part in ipairs(root:GetDescendants()) do
   if part:IsA("BasePart") then
    assert(part.Transparency>=.59 and part.Color==color,"Mutation/fade failure")
   end
  end
  root:Destroy()
 end
 local model=assert(V.CloneForViewport(name)) model:Destroy()
 report[name]={recipePairs=combinations,parts=parts,scales=3}
end
return game.HttpService:JSONEncode(report)
