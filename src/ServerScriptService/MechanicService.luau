-- Own-base addon counter. Existing PlotManager remains authoritative for price/inventory.
-- The mechanic behind the counter is the base owner's own avatar, loaded when they claim
-- the base. A base nobody owns (or whose owner's avatar can't be loaded) shows the stock
-- mechanic in overalls instead.
local Service = {}
local RS = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")
local desks = {}
local started = false
local IDLE = "rbxassetid://507766666" -- Roblox's own R15 idle, so the owner stands and breathes
local function part(parent,name,size,cf,color,material)
 local p=Instance.new("Part");p.Name=name;p.Size=size;p.CFrame=cf;p.Color=color
 p.Material=material or Enum.Material.SmoothPlastic;p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.Parent=parent
 return p
end
function Service.CanPurchase(player)
 local root=player.Character and player.Character:FindFirstChild("HumanoidRootPart")
 if not root then return false end
 for plot,desk in pairs(desks) do
  if plot.Parent and plot:GetAttribute("OwnerUserId")==player.UserId and (root.Position-desk.Position).Magnitude<=14 then return true end
 end
 return false
end
function Service.Start()
 if started then return end;started=true
 local remote=RS:FindFirstChild("OpenMechanicShop") or Instance.new("RemoteEvent")
 remote.Name="OpenMechanicShop";remote.Parent=RS
 local function build(plot)
  if not plot:IsA("Model") or desks[plot] then return end
  local ground=plot:WaitForChild("Ground",15);if not ground then return end
  local model=Instance.new("Model");model.Name="AddonMechanic";model.Parent=plot
  -- Against the back wall, facing the door, between the Lock Base button and the rear
  -- bench on the left as you walk in: the pads, center aisle and benches stay clear.
  local base=ground.CFrame*CFrame.new(9,.55,40)
  local blue=Color3.fromRGB(28,83,126);local dark=Color3.fromRGB(28,35,44)
  local skin=Color3.fromRGB(205,148,105);local steel=Color3.fromRGB(162,179,190)
  local into=model
  local function p(n,s,x,y,z,c,m)return part(into,n,s,base*CFrame.new(x,y,z),c,m)end
  local counter=p("Counter",Vector3.new(6,2.5,2),0,1.25,-1.7,blue,Enum.Material.Metal)
  p("Worktop",Vector3.new(6.3,.2,2.3),0,2.6,-1.7,dark,Enum.Material.DiamondPlate)
  for i=-2,2 do p("DrawerHandle",Vector3.new(.65,.09,.15),i,1.8,-2.75,steel,Enum.Material.Metal)end
  local stock=Instance.new("Model");stock.Name="StockMechanic";stock.Parent=model
  into=stock
  for _,x in {-0.48,0.48}do
   p("Boot",Vector3.new(.8,.45,1.1),x,.25,.1,dark)
   p("OverallLeg",Vector3.new(.72,1.45,.75),x,1.1,.1,blue)
  end
  p("Workshirt",Vector3.new(1.8,1.65,.85),0,2.55,.1,Color3.fromRGB(236,191,73))
  p("OverallBib",Vector3.new(1.4,1.35,.12),0,2.42,-.38,blue)
  for _,x in {-.56,.56}do p("OverallStrap",Vector3.new(.19,.6,.14),x,3.05,-.39,blue)end
  p("BibPocket",Vector3.new(.64,.4,.1),0,2.5,-.48,dark)
  local head=p("Head",Vector3.new(1.05,1.08,.95),0,3.93,.1,skin);head.Shape=Enum.PartType.Ball
  p("MechanicCap",Vector3.new(1.13,.34,1.02),0,4.43,.1,blue)
  p("CapBrim",Vector3.new(1.13,.1,.55),0,4.28,-.56,blue)
  for _,x in {-.23,.23}do p("Eye",Vector3.new(.09,.09,.05),x,3.98,-.37,dark)end
  p("Smile",Vector3.new(.28,.055,.05),0,3.72,-.36,dark)
  for _,x in {-1.16,1.16}do
   p("Sleeve",Vector3.new(.52,.85,.62),x,2.93,.1,Color3.fromRGB(236,191,73))
   p("Glove",Vector3.new(.5,.6,.52),x,2.27,-.06,dark)
  end
  p("HeldWrenchShaft",Vector3.new(.14,1.3,.14),1.16,2.5,-.4,steel,Enum.Material.Metal)
  p("WrenchJawBridge",Vector3.new(.5,.16,.18),1.16,3.2,-.4,steel,Enum.Material.Metal)
  for _,x in {.95,1.37}do p("WrenchJaw",Vector3.new(.12,.3,.18),x,3.37,-.4,steel,Enum.Material.Metal)end
  -- The owner as the mechanic: their avatar stands where the stock one does, wrench in
  -- hand. Rebuilt whenever the base changes hands; `loads` drops a slow avatar load that
  -- a newer owner (or nobody) has overtaken.
  local loads=0
  local function showOwner()
   loads+=1
   local load=loads
   local old=model:FindFirstChild("OwnerMechanic");if old then old:Destroy()end
   stock.Parent=model
   local userId=plot:GetAttribute("OwnerUserId")
   if type(userId)~="number" or userId<=0 then return end
   local ok,rig=pcall(function()
    return Players:CreateHumanoidModelFromDescription(Players:GetHumanoidDescriptionFromUserId(userId),Enum.HumanoidRigType.R15)
   end)
   if not ok or load~=loads or not model.Parent then
    if ok and rig then rig:Destroy()end
    return
   end
   local humanoid=rig:FindFirstChildOfClass("Humanoid");local root=rig:FindFirstChild("HumanoidRootPart")
   if not(humanoid and root)then rig:Destroy();return end
   rig.Name="OwnerMechanic"
   humanoid.DisplayDistanceType=Enum.HumanoidDisplayDistanceType.None
   humanoid.HealthDisplayType=Enum.HumanoidHealthDisplayType.AlwaysOff
   for _,d in rig:GetDescendants()do
    if d:IsA("BasePart")then d.Anchored=false;d.CanCollide=false;d.CanTouch=false;d.CanQuery=false end
   end
   root.Anchored=true
   rig:PivotTo(base*CFrame.new(0,humanoid.HipHeight+root.Size.Y/2,.1))
   local hand=rig:FindFirstChild("RightHand")
   if hand then
    local function held(n,s,offset)
     local w=part(rig,n,s,hand.CFrame*offset,steel,Enum.Material.Metal)
     w.Anchored=false;w.CanQuery=false;w.Massless=true
     local weld=Instance.new("WeldConstraint");weld.Part0=hand;weld.Part1=w;weld.Parent=w
    end
    held("HeldWrenchShaft",Vector3.new(.14,1.2,.14),CFrame.new(0,-.35,-.15))
    held("WrenchJawBridge",Vector3.new(.45,.14,.18),CFrame.new(0,-.95,-.15))
   end
   rig.Parent=model
   stock.Parent=nil
   local animator=humanoid:FindFirstChildOfClass("Animator")or Instance.new("Animator",humanoid)
   local idle=Instance.new("Animation");idle.AnimationId=IDLE
   pcall(function()local track=animator:LoadAnimation(idle);track.Looped=true;track:Play()end)
  end
  plot:GetAttributeChangedSignal("OwnerUserId"):Connect(function()task.spawn(showOwner)end)
  task.spawn(showOwner)
  -- A name tag over the mechanic, seen from across the base like the pads'
  -- labels (PlotManager's makeLabel: same look, gone past 55 studs).
  local tag=Instance.new("BillboardGui");tag.Name="MechanicTag";tag.Size=UDim2.fromOffset(260,60)
  tag.StudsOffset=Vector3.new(0,6.4,0);tag.AlwaysOnTop=true;tag.MaxDistance=55;tag.Parent=counter
  local tagText=Instance.new("TextLabel");tagText.Size=UDim2.fromScale(1,1);tagText.BackgroundTransparency=1
  tagText.Text="MECHANIC";tagText.TextColor3=Color3.new(1,1,1);tagText.TextStrokeTransparency=.3
  tagText.TextScaled=true;tagText.Font=Enum.Font.FredokaOne;tagText.Parent=tag
  local prompt=Instance.new("ProximityPrompt");prompt.Name="BuyAddons";prompt.ActionText="Addons";prompt.ObjectText="Your Mechanic"
  prompt.MaxActivationDistance=10;prompt.RequiresLineOfSight=false;prompt.HoldDuration=.15;prompt.Parent=counter
  desks[plot]=counter
  prompt.Triggered:Connect(function(player)
   if plot:GetAttribute("OwnerUserId")==player.UserId and Service.CanPurchase(player)then remote:FireClient(player,counter)end
  end)
  plot.Destroying:Connect(function()desks[plot]=nil end)
 end
 task.spawn(function()
  local folder=workspace:WaitForChild("Plots")
  folder.ChildAdded:Connect(function(plot)task.spawn(build,plot)end)
  for _,plot in folder:GetChildren()do task.spawn(build,plot)end
 end)
end
return Service
