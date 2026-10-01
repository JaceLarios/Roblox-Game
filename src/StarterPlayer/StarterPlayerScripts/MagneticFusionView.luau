-- Client-only magnetic teardown. Never edits templates, inventory, or fusion outcomes.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local ContentProvider = game:GetService("ContentProvider")
local Garage = require(RS:WaitForChild("GarageTheme"))
local Visuals = require(RS:WaitForChild("ItemVisuals"))
local Recipes = require(RS:WaitForChild("FusionRecipes"))
local Mutations = require(RS:WaitForChild("Mutations"))
local Names = require(RS:WaitForChild("ItemNames"))
local View = {}
local CYAN, GOLD = Color3.fromRGB(66,231,255), Color3.fromRGB(255,183,52)
local function new(kind,parent,name,props)
 local o=Instance.new(kind) o.Name=name
 for k,v in pairs(props or {}) do o[k]=v end
 o.Parent=parent return o
end
local function clean(s)
 return (tostring(s or ""):gsub("<[^>]*>",""):gsub("&amp;","&"):gsub("&lt;","<"):gsub("&gt;",">"))
end
local function smooth(t) t=math.clamp(t,0,1) return t*t*(3-2*t) end
local function progress(t,a,b) return smooth((t-a)/(b-a)) end
local function text(parent,name,value,pos,size,max)
 local t=new("TextLabel",parent,name,{Text=value,Position=pos,Size=size,BackgroundTransparency=1,
  Font=Enum.Font.FredokaOne,TextSize=max or 34,TextScaled=true,TextWrapped=true,TextColor3=Color3.new(1,1,1),ZIndex=4})
 new("UITextSizeConstraint",t,"Limit",{MinTextSize=9,MaxTextSize=max or 34})
 new("UIStroke",t,"Outline",{Color=Color3.fromRGB(8,34,58),Thickness=2})
 return t
end
local function part(parent,name,size,color)
 return new("Part",parent,name,{Size=size,Color=color,Anchored=true,CanCollide=false,CanTouch=false,CanQuery=false,
  CastShadow=false,Material=Enum.Material.Metal})
end
-- Wheel materials stay on the same axle. Optional FusionGroup attributes let
-- authored hood/door meshes override this fallback without animation changes.
local function groupFor(p)
 local explicit=p:GetAttribute("FusionGroup")
 if type(explicit)=="string" then return explicit end
 if p:GetAttribute("WheelPivot") or p.Name:lower():find("wheel") or p.Name:lower():find("tire") then
  return (p.Position.X<0 and "WheelLeft" or "WheelRight")..(p.Position.Z<0 and "Rear" or "Front")
 end
 local n=p.Name:lower()
 if n:find("seat") or n:find("upholstery") or n:find("glass") or n:find("roof") then return "Cabin" end
 if n:find("iron") or n:find("rubber") or n:find("chassis") then return "Chassis" end
 if n:find("lamp") or n:find("headlight") or n:find("chrome") then return "FrontTrim" end
 if n:find("titanium") or n:find("heat") or n:find("energy") or n:find("engine") or n:find("exhaust") or n:find("copper") then return "Powertrain" end
 return "Body"
end
local function displacement(name)
 if name:find("Wheel") then return Vector3.new(name:find("Left") and -1.65 or 1.65,.32,name:find("Rear") and -.25 or .25),.72 end
 if name=="Chassis" then return Vector3.new(0,-.15,0),0 end
 if name=="Cabin" or name:lower():find("roof") then return Vector3.new(0,1.7,0),.43 end
 if name=="FrontTrim" or name:lower():find("hood") then return Vector3.new(0,.65,1.7),.54 end
 if name=="Powertrain" then return Vector3.new(0,.85,-1.65),.24 end
 if name:lower():find("left") then return Vector3.new(-1.5,.5,0),.5 end
 if name:lower():find("right") then return Vector3.new(1.5,.5,0),.5 end
 return Vector3.new(0,1.05,.12),.35
end
local function clone(world,tag,target)
 local base,mutation=Mutations.Unwrap(clean(tag))
 local model=Visuals.CloneForViewport(base,mutation and Mutations.Color(mutation))
 if not model then return nil end
 for _,o in model:GetDescendants() do
  if o:IsA("LuaSourceContainer") or o:IsA("JointInstance") or o:IsA("Constraint") then o:Destroy() end
 end
 local _,size=model:GetBoundingBox()
 model:ScaleTo(model:GetScale()*target/math.max(size.X,size.Y,size.Z,.01))
 model.Name=base model.Parent=world
 local rig={model=model,parts={}}
 for _,p in model:GetDescendants() do
  if p:IsA("BasePart") then
   local group=groupFor(p) local offset,delay=displacement(group)
   table.insert(rig.parts,{p=p,rest=p.CFrame,alpha=p.Transparency,offset=offset,delay=delay,group=group})
  end
 end
 return rig
end
local function pose(rig,root,explode,visibility,rebuild)
 if not rig then return end
 if visibility<=0 and rig.hidden then return end
 rig.hidden=visibility<=0
 for _,v in rig.parts do
  local amount=explode
  if rebuild then amount=1-smooth((rebuild-v.delay*.3)/.7) end
  v.p.CFrame=root*CFrame.new(v.offset*amount)*v.rest
  v.p.Transparency=1-(1-v.alpha)*visibility
 end
end
local function build(data)
 local player=Players.LocalPlayer
 local rarity=clean(data.rarityName):upper()
 local rank=({COMMON=1,UNCOMMON=1,RARE=2,EPIC=3,MYTHIC=4,LEGENDARY=5,SECRET=5})[rarity] or 1
 local duration=4.6+(rank-1)*.45
 local gui=new("ScreenGui",player:WaitForChild("PlayerGui"),"FusionCelebrationGui",{
  IgnoreGuiInset=true,ResetOnSpawn=false,DisplayOrder=100,ZIndexBehavior=Enum.ZIndexBehavior.Sibling})
 gui:SetAttribute("Area","junkyard") gui:SetAttribute("Duration",duration) gui:SetAttribute("Rarity",rarity)
 local overlay=new("Frame",gui,"MagneticAssembly",{Size=UDim2.fromScale(1,1),BorderSizePixel=0,BackgroundColor3=Color3.fromRGB(8,25,46),Active=true})
 new("ImageLabel",overlay,"Workshop",{Image=Garage.Background,Size=UDim2.fromScale(1,1),ScaleType=Enum.ScaleType.Crop,BackgroundTransparency=1,ImageTransparency=.55})
 local heading=text(overlay,"Title","MAGNETIC FUSION",UDim2.fromScale(.13,.025),UDim2.fromScale(.74,.065),48)
 Garage.Header(heading)
 local phase=text(overlay,"Phase","LIFTING CAR",UDim2.fromScale(.16,.095),UDim2.fromScale(.68,.045),26)
 local viewport=new("ViewportFrame",overlay,"AssemblyViewport",{Position=UDim2.fromScale(.005,.14),Size=UDim2.fromScale(.99,.65),
  BackgroundTransparency=1,Ambient=Color3.fromRGB(185,200,225),LightColor=Color3.fromRGB(255,242,222),LightDirection=Vector3.new(-1,-2,-1),ZIndex=2})
 local world=new("WorldModel",viewport,"WorkshopStage")
 local camera=new("Camera",viewport,"Camera",{FieldOfView=37}) viewport.CurrentCamera=camera
 local a,b=clean(data.aTag),clean(data.bTag)
 local baseA=Mutations.Unwrap(a)
 if Recipes.IsAddon(baseA) then a,b=b,a end
 local car=clone(world,a,6)
 local addon=clone(world,b,1.9)
 local result=clone(world,data.resultTag,6)
 local output=text(overlay,"Result",Names.Display(clean(data.resultTag)),UDim2.fromScale(.12,.795),UDim2.fromScale(.76,.055),36)
 Garage.Plate(output)
 local rate=text(overlay,"Rate",clean(data.rateLine),UDim2.fromScale(.12,.85),UDim2.fromScale(.76,.045),23)
 local ingredients=text(overlay,"Ingredients",Names.Display(a).."  +  "..Names.Display(b),UDim2.fromScale(.05,.90),UDim2.fromScale(.90,.035),20)
 local skip=new("TextButton",overlay,"Skip",{Text="Skip",Font=Enum.Font.FredokaOne,TextScaled=true,
  Size=UDim2.fromScale(.24,.055),Position=UDim2.fromScale(.38,.935),ZIndex=8})
 Garage.Button(skip,GOLD)
 local flash=new("Frame",overlay,"ImpactFlash",{Size=UDim2.fromScale(1,1),BackgroundColor3=CYAN,BackgroundTransparency=1,BorderSizePixel=0,ZIndex=6,Active=false})
 local platform=part(world,"Magnetic lift",Vector3.new(.22,7,7),Color3.fromRGB(26,77,100))
 platform.Shape=Enum.PartType.Cylinder platform.CFrame=CFrame.new(0,-1.75,0)*CFrame.Angles(0,0,math.pi/2)
 local rings={}
 for r=1,3 do
  local segments={}
  for j=1,24 do local p=part(world,"Magnetic coil",Vector3.new(.035,.035,.1),r==2 and GOLD or CYAN) p.Material=Enum.Material.Neon segments[j]=p end
  rings[r]=segments
 end
 local sparks={}
 for i=1,36 do
  local p=part(world,"Hot fastener",Vector3.new(.09,.09,.75),i%2==0 and GOLD or CYAN)
  p.Material=Enum.Material.Neon sparks[i]=p
 end
 local bolts={}
 for i=1,12 do bolts[i]=part(world,"Orbit bolt",Vector3.new(.10,.10,.24),Color3.fromRGB(185,205,218)) end
 local sounds,connections={},{}
 local stop=false
 table.insert(connections,skip.Activated:Connect(function()stop=true end))
 table.insert(connections,player.CharacterRemoving:Connect(function()stop=true end))
 local cues={}
 local function sound(file,pitch,volume)
  if player:GetAttribute("SFXOn")==false then return end
  local s=new("Sound",SoundService,"MagneticFusionSFX",{SoundId="rbxasset://sounds/"..file,PlaybackSpeed=pitch,Volume=volume})
  local group=SoundService:FindFirstChild("SettingsSFX") if group and group:IsA("SoundGroup") then s.SoundGroup=group end
  table.insert(sounds,s) s:Play()
 end
 local function cue(key,at,t,file,pitch,volume,audible)
  if audible and t>=at and not cues[key] then cues[key]=true if audible then sound(file,pitch,volume) end end
 end
 local lastPhase
 local function render(q,audible)
  local reduced=player:GetAttribute("PotatoMode")==true
  local t=math.clamp(q,0,1)
  local lift=progress(t,0,.10)*.7+math.sin(t*math.pi*3)*.10
  local explode=progress(t,.06,.30)*(1+.10*math.sin(t*14))
  local exchange=progress(t,.52,.60)
  local rebuild=progress(t,.60,.80)
  local reveal=t>=.8
  local burst=math.clamp((t-.80)/.09,0,1)
  local spin=-.55+t*.85+math.sin(t*math.pi*2)*.10
  local kick=not reduced and t>=.8 and math.sin(burst*math.pi)*.32 or 0
  local root=CFrame.new(0,lift+kick,0)*CFrame.Angles(0,spin,0)
  pose(car,root,explode,1-exchange)
  pose(result,root,1,exchange,rebuild)
  local travel=progress(t,.18,.55)
  local addonRoot=CFrame.new(Vector3.new(4,1.4,0):Lerp(Vector3.new(0,1.0,-.7),travel)+Vector3.new(0,math.sin(travel*math.pi)*1.7,0))*CFrame.Angles(0,-.5+travel*.8,0)
  pose(addon,addonRoot,0,1-progress(t,.55,.65))
  local phaseName=t<.12 and "Lift" or t<.34 and "Teardown" or t<.52 and "Addon" or t<.6 and "Transform" or t<.8 and "Rebuild" or "Reveal"
  if lastPhase~=phaseName then
  lastPhase=phaseName
  gui:SetAttribute("Phase",phaseName)
  phase.Text=({Lift="MAGNETIC LIFT",Teardown="PULLING APART",Addon="INSTALLING "..Names.Display(b):upper(),Transform="FUSION CHARGED",Rebuild="LOCKING PARTS INTO PLACE",Reveal="FUSION COMPLETE!"})[phaseName]
  output.Visible=reveal rate.Visible=reveal ingredients.Visible=true skip.Text=reveal and "Continue" or "Skip"
  if not result then phase.Text=reveal and "FUSION COMPLETE — MODEL PREVIEW UNAVAILABLE" or phase.Text end
  end
  local aspect=math.max(.3,viewport.AbsoluteSize.X/math.max(1,viewport.AbsoluteSize.Y))
  local distance=math.max(13.5,15/aspect)*(1-.08*progress(t,.3,.57)-.12*progress(t,.80,.94))
  local shake=not reduced and t>=.8 and t<.86 and math.sin((t-.8)*220)*.18*(1-burst) or 0
  camera.CFrame=CFrame.lookAt(Vector3.new(.55*distance+shake,.34*distance,.83*distance),Vector3.new(0,.6,0))
  -- Helical ribbons enclose the complete car with true front/back occlusion.
  local energy=progress(t,.015,.12)*(1-progress(t,.80,.96))
  local rotation=t*math.pi*14+t*t*math.pi*12
  for r,segments in rings do
   local radius=4.35-.35*progress(t,.45,.68)+burst*2
   local function point(u)
    local theta=u*math.pi*2+rotation+r*math.pi*2/3
    return root*Vector3.new(math.cos(theta)*radius,-1.8+u*5.4,math.sin(theta)*radius)
   end
   for j,p in segments do
    local u=(j-1)/#segments local v=j/#segments
    local x,y=point(u),point(v)
    p.Size=Vector3.new(.075,.11,(x-y).Magnitude+.035)
    p.CFrame=CFrame.lookAt((x+y)/2,y)
    p.Transparency=(reduced and r>1) and 1 or 1-energy*(.42+.46*math.sin(u*math.pi))
   end
  end
  for i,p in bolts do
   local theta=i/#bolts*math.pi*2+rotation local radius=4.2*(1-progress(t,.5,.76))
   p.CFrame=CFrame.new(math.cos(theta)*radius,-.8+(i%4)*1.1,math.sin(theta)*radius)*CFrame.Angles(t*8,i,t*4)
   p.Transparency=(t<.2 or t>.72 or reduced) and 1 or 0
  end
  for i,p in sparks do
   local theta=i*2.399 local r=1+burst*6
   p.CFrame=CFrame.new(math.cos(theta)*r,.3+math.sin(i*4)*burst*2,math.sin(theta)*r)*CFrame.Angles(0,-theta,math.pi/3)
   p.Transparency=(t<.8 or reduced) and 1 or burst
  end
  flash.BackgroundTransparency=reduced and 1 or (1-.34*math.max(0,1-math.abs(t-.805)/.025))
  -- No full-screen offscreen compositing pass.
  cue("lift",.02,t,"electronicpingshort.wav",.55,.28,audible)
  cue("release",.14,t,"switch.wav",.7,.35,audible)
  cue("charge",.4,t,"electronicpingshort.wav",.85,.3,audible)
  for i=1,6 do cue("bolt"..i,.6+i*.026,t,"clickfast.wav",.7+i*.1,.3,audible) end
  cue("impact",.8,t,"bass.wav",.65,.55,audible)
  cue("lock",.805,t,"switch.wav",.8,.35,audible)
  cue("finish",.835,t,"electronicpingshort.wav",1.35,.32,audible)
 end
 local function cleanup()
  for _,c in connections do c:Disconnect() end
  for _,s in sounds do s:Destroy() end
  gui:Destroy()
 end
 return {gui=gui,world=world,phase=phase,duration=duration,render=render,cleanup=cleanup,stopped=function()return stop or not gui.Parent end}
end
function View.Play(data)
 if type(data)~="table" then return end
 local scene
 local ok,err=xpcall(function()
  scene=build(data)
  -- Preload asynchronously; never freeze an onscreen frame waiting for assets.
  task.spawn(function() pcall(function()ContentProvider:PreloadAsync(scene.world:GetDescendants())end) end)
  local start=os.clock()
  while not scene.stopped() do
   local q=(os.clock()-start)/scene.duration if q>=1 then break end
   scene.render(q,true) RunService.RenderStepped:Wait()
  end
 end,debug.traceback)
 if scene then scene.cleanup()
 else
  local orphan=Players.LocalPlayer.PlayerGui:FindFirstChild("FusionCelebrationGui")
  if orphan and orphan:FindFirstChild("MagneticAssembly") then orphan:Destroy() end
 end
 if not ok then warn("[MagneticFusionView] "..tostring(err)) end
end
-- Studio-only visual QA: freeze a phase without firing a fusion or changing data.
function View.Preview(data,fraction)
 assert(RunService:IsStudio(),"Preview is Studio only")
 local scene=build(data) scene.render(fraction,false)
 return scene
end
return View
