-- Collector's Garage presentation. Never sends remotes or changes HUD layout.
local Theme = {}
Theme.Background = "rbxassetid://116747280492229"
local BLUE=Color3.fromRGB(15,151,229)
local CYAN=Color3.fromRGB(130,244,255)
local INK=Color3.fromRGB(8,43,77)
local GOLD=Color3.fromRGB(255,199,47)
local function corner(o,r)
 local c=o:FindFirstChildOfClass("UICorner") or Instance.new("UICorner")
 c.CornerRadius=UDim.new(0,r) c.Parent=o
end
local function stroke(o,color,width)
 local s=o:FindFirstChildOfClass("UIStroke") or Instance.new("UIStroke")
 s.ApplyStrokeMode=Enum.ApplyStrokeMode.Border s.Color=color s.Thickness=width s.Transparency=0 s.Parent=o
end
function Theme.Inset(o)
 o:SetAttribute("Designed",true)
 o.BackgroundColor3=Color3.fromRGB(103,213,249)
 o.BackgroundTransparency=.35
 o.BorderSizePixel=0
 corner(o,18) stroke(o,CYAN,2)
end
function Theme.Header(label)
 label:SetAttribute("Designed",true)
 for _,o in label:GetChildren() do if o:IsA("UIGradient") then o:Destroy() end end
 label.BackgroundTransparency=0 label.BackgroundColor3=GOLD
 label.TextColor3=Color3.fromRGB(255,255,250)
 label.Font=Enum.Font.FredokaOne
 label.TextStrokeColor3=INK label.TextStrokeTransparency=0
 corner(label,14)
 local edge=Instance.new("UIStroke") edge.Name="GaragePlateBorder"
 edge.ApplyStrokeMode=Enum.ApplyStrokeMode.Border edge.Color=Color3.fromRGB(148,91,12) edge.Thickness=3 edge.Parent=label
 local pad=Instance.new("UIPadding") pad.PaddingLeft=UDim.new(0,14) pad.PaddingRight=UDim.new(0,14) pad.Parent=label
end
function Theme.Shell(panel)
 if panel:GetAttribute("GarageShell") then return end
 panel:SetAttribute("GarageShell",true) panel:SetAttribute("Designed",true)
 panel.BackgroundColor3=BLUE panel.BackgroundTransparency=0 panel.BorderSizePixel=0
 corner(panel,24) stroke(panel,INK,4)
 for _,old in panel:GetChildren() do if old:IsA("UIGradient") then old:Destroy() end end
 local background=Instance.new("ImageLabel")
 background.Name="GarageBackdrop" background:SetAttribute("GarageDecoration",true)
 background:SetAttribute("Designed",true) background.Size=UDim2.fromScale(1,1)
 background.BackgroundColor3=BLUE background.BackgroundTransparency=0
 background.Image=Theme.Background background.ImageTransparency=.36
 background.ScaleType=Enum.ScaleType.Crop background.ZIndex=0
 corner(background,24) background.Parent=panel
 local rim=Instance.new("Frame") rim.Name="GarageRim"
 rim:SetAttribute("GarageDecoration",true) rim:SetAttribute("Designed",true)
 rim.BackgroundTransparency=1 rim.Position=UDim2.fromOffset(5,5) rim.Size=UDim2.new(1,-10,1,-10)
 rim.ZIndex=0 corner(rim,20) stroke(rim,CYAN,2) rim.Parent=panel
 for _,b in panel:GetChildren() do
  if b:IsA("TextButton") and (b.Text=="X" or b.Text=="×") and not b:GetAttribute("Designed") then
   b:SetAttribute("Designed",true) b.Size=UDim2.fromOffset(42,42) b.Position=UDim2.new(1,-56,0,12)
   b.BackgroundTransparency=0 b.BackgroundColor3=Color3.fromRGB(255,88,30)
   b.TextColor3=Color3.new(1,1,1) b.TextSize=30 b.TextStrokeColor3=INK b.TextStrokeTransparency=0
   corner(b,10) stroke(b,INK,3)
  end
 end
 local function skin(o)
  if o:GetAttribute("Designed") or o:GetAttribute("GarageDecoration") or o:IsA("ViewportFrame") then return end
  if o:IsA("TextBox") then
   o:SetAttribute("Designed",true) o.BackgroundColor3=Color3.fromRGB(187,235,255)
   o.BackgroundTransparency=0 o.TextColor3=INK o.PlaceholderColor3=Color3.fromRGB(38,103,162)
   stroke(o,Color3.fromRGB(12,101,174),2)
  elseif o:IsA("Frame") and o:FindFirstChildOfClass("UICorner") and o.BackgroundTransparency<.4 then
   local c=o.BackgroundColor3
   if math.min(c.R,c.G,c.B)>.7 then Theme.Inset(o) end
  end
 end
 for _,o in panel:GetDescendants() do skin(o) end
 panel.DescendantAdded:Connect(function(o) task.defer(function() if o.Parent then skin(o) end end) end)
end
function Theme.Fit(panel)
 panel.AnchorPoint=Vector2.new(.5,.5) panel.Position=UDim2.fromScale(.5,.5)
 local scale=Instance.new("UIScale") scale.Parent=panel
 local gui=panel:FindFirstAncestorOfClass("ScreenGui")
 local function update()
  local size=gui.AbsoluteSize if size.X<100 or size.Y<100 then return end
  local compact=size.X<650
  local width=compact and 600 or 1200
  scale.Scale=math.min(1.25,(size.X-28)/width)
  panel.Size=UDim2.fromOffset(width,(size.Y-38)/scale.Scale)
  panel:SetAttribute("Compact",compact)
 end
 gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(update) update()
end
function Theme.Podium(model,color)
 if model:FindFirstChild("GaragePodium") then return end
 local cf,size=model:GetBoundingBox()
 local group=Instance.new("Model") group.Name="GaragePodium"
 local radius=math.max(size.X,size.Z)*.52
 local height=math.max(.13,math.max(size.X,size.Z)*.07)
 local bottom=cf.Position.Y-size.Y/2
 color=color or Color3.fromRGB(39,225,233)
 local function disc(name,y,h,r,c,material)
  local p=Instance.new("Part") p.Name=name p.Shape=Enum.PartType.Cylinder
  p.Size=Vector3.new(h,r*2,r*2) p.CFrame=CFrame.new(cf.Position.X,y,cf.Position.Z)*CFrame.Angles(0,0,math.pi/2)
  p.Color=c p.Material=material p.Anchored=true p.CanCollide=false p.CanTouch=false p.CanQuery=false p.CastShadow=false p.Parent=group
 end
 disc("EnamelBase",bottom-height*.5,height,radius,color,Enum.Material.SmoothPlastic)
 disc("LightRim",bottom-.01,.035,radius*1.015,Color3.fromRGB(220,255,255),Enum.Material.Neon)
 disc("DisplayTop",bottom+.008,.025,radius*.94,color:Lerp(Color3.new(1,1,1),.15),Enum.Material.SmoothPlastic)
 group.Parent=model
end

-- Reference-matched enamel components. These decorate live controls, not flat menu screenshots.
Theme.IconAtlas = "rbxassetid://118283775447762"
Theme.TravelAtlas = "rbxassetid://112069100804229"
Theme.PetAtlas = "rbxassetid://108663379877358"
local cells={DoubleCoins=0,value=0,coins=0,ExtraCarry=1,carry=1,AutoCollect=2,StarterPack=3,REWARDS=3,CODE=15,speed=4,luck=5,PETS=10,egg=6,crate=7,boost=8,rebirth=9,INVENTORY=11,TRADE=12,TRAVEL=13,UPGRADES=14,INDEX=11,SHOP=11}
function Theme.New(class,parent,name,props)
 local o=Instance.new(class) o.Name=name o:SetAttribute("Designed",true)
 for k,v in props or {} do o[k]=v end
 o.Parent=parent return o
end
function Theme.Text(parent,name,text,pos,size,fontSize,color)
 task.spawn(function()
 pcall(function() game:GetService("ContentProvider"):PreloadAsync({Theme.Background,Theme.IconAtlas,Theme.TravelAtlas,Theme.PetAtlas}) end)
end)
return Theme.New("TextLabel",parent,name,{Text=text,Position=pos,Size=size,TextSize=fontSize or 22,Font=Enum.Font.FredokaOne,TextColor3=color or INK,BackgroundTransparency=1,BorderSizePixel=0,TextWrapped=true,ZIndex=4})
end
function Theme.Art(parent,kind,pos,size)
 local i=cells[kind] or 14
 return Theme.New("ImageLabel",parent,"GarageArt",{Image=Theme.IconAtlas,ImageRectOffset=Vector2.new(math.floor((i%4)*1024/4),math.floor(math.floor(i/4)*1024/4)),ImageRectSize=Vector2.new(256,256),Position=pos,Size=size,BackgroundTransparency=1,ScaleType=Enum.ScaleType.Fit,ZIndex=3})
end
function Theme.PetArt(parent,index,pos,size)
 index=(index-1)%6
 return Theme.New("ImageLabel",parent,"PetPortrait",{Image=Theme.PetAtlas,ImageRectOffset=Vector2.new(math.floor((index%3)*1024/3),math.floor(index/3)*341),ImageRectSize=Vector2.new(341,341),Position=pos,Size=size,BackgroundTransparency=1,ScaleType=Enum.ScaleType.Fit,ZIndex=3})
end
function Theme.Scene(parent,index,pos,size)
 local p=Theme.New("ImageLabel",parent,"DestinationArt",{Image=Theme.TravelAtlas,ImageRectOffset=Vector2.new(0,({0,239,467})[index+1]),ImageRectSize=Vector2.new(1024,({239,228,215})[index+1]),Position=pos,Size=size,BackgroundTransparency=1,ScaleType=Enum.ScaleType.Crop,ZIndex=2})
 corner(p,18) return p
end
function Theme.Gloss(o,color,r)
 o:SetAttribute("Designed",true) o.BackgroundColor3=color o.BorderSizePixel=0
 corner(o,r or 16) stroke(o,Color3.fromRGB(0,72,127),3)
 local prior=o:FindFirstChild("GarageEnamel") if prior then prior:Destroy() end
 local fill=Theme.New("Frame",o,"GarageEnamel",{Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.new(1,1,1),BorderSizePixel=0,ZIndex=0})
 corner(fill,r or 16)
 Theme.New("UIGradient",fill,"Gloss",{Rotation=90,Color=ColorSequence.new({
 ColorSequenceKeypoint.new(0,color:Lerp(Color3.new(1,1,1),.62)),ColorSequenceKeypoint.new(.09,color:Lerp(Color3.new(1,1,1),.16)),ColorSequenceKeypoint.new(.52,color),ColorSequenceKeypoint.new(1,color:Lerp(Color3.new(0,.12,.26),.3))})})
 local rim=Theme.New("Frame",fill,"Highlight",{Position=UDim2.fromOffset(3,3),Size=UDim2.new(1,-6,1,-6),BackgroundTransparency=1,ZIndex=1})
 corner(rim,(r or 16)-3) stroke(rim,color:Lerp(Color3.new(1,1,1),.75),1.5)
 return o
end
function Theme.Button(b,color)
 if b:GetAttribute("GarageButton") then return end
 b:SetAttribute("GarageButton",true) b:SetAttribute("Designed",true)
 for _,o in b:GetChildren() do if o:IsA("UIGradient") then o:Destroy() end end
 b.BackgroundColor3=color or b.BackgroundColor3
 Theme.Gloss(b,b.BackgroundColor3,14)
 b.TextTransparency=1 b.TextStrokeTransparency=1
 local text=Theme.Text(b,"GarageButtonCaption",b.Text,UDim2.fromOffset(8,0),UDim2.new(1,-16,1,0),b.TextSize,Color3.new(1,1,1))
 text.ZIndex=5 text.TextStrokeColor3=INK text.TextStrokeTransparency=1
 local outline=Instance.new("UIStroke") outline.ApplyStrokeMode=Enum.ApplyStrokeMode.Contextual outline.Color=INK outline.Thickness=2.5 outline.Parent=text
 local cap=Instance.new("UITextSizeConstraint") cap.MaxTextSize=36 cap.MinTextSize=12 cap.Parent=text
 text.TextScaled=true
 local function update()
  text.Text=b.Text
  for _,o in b:GetChildren() do if o:IsA("UIGradient") then o:Destroy() end end
  local fill=b:FindFirstChild("GarageEnamel")
  if fill then local g=fill:FindFirstChild("Gloss") local c=b.Active and b.BackgroundColor3 or Color3.fromRGB(104,136,180) if g then g.Color=ColorSequence.new(c:Lerp(Color3.new(1,1,1),.32),c:Lerp(Color3.new(0,.12,.26),.18)) end end
 end
 b:GetPropertyChangedSignal("Active"):Connect(update)
 b:GetPropertyChangedSignal("Text"):Connect(update)
 b:GetPropertyChangedSignal("BackgroundColor3"):Connect(update)
 update()
end
local oldHeader=Theme.Header
function Theme.Header(l)
 oldHeader(l)
 Theme.Gloss(l,GOLD,16)
 l.TextTransparency=1 l.TextStrokeTransparency=1
 local t=Theme.Text(l,"PlateCaption",l.Text,UDim2.fromOffset(12,0),UDim2.new(1,-24,1,0),l.TextSize,Color3.new(1,1,1))
 t.TextStrokeColor3=INK t.TextStrokeTransparency=0 t.TextXAlignment=l.TextXAlignment
 t.TextScaled=true
 t.TextStrokeTransparency=1
 local outline=Instance.new("UIStroke") outline.ApplyStrokeMode=Enum.ApplyStrokeMode.Contextual outline.Color=INK outline.Thickness=3.5 outline.Parent=t
 local cap=Instance.new("UITextSizeConstraint") cap.MaxTextSize=l.TextSize*1.5 cap.MinTextSize=14 cap.Parent=t
 l:GetPropertyChangedSignal("Text"):Connect(function() t.Text=l.Text end)
 l:GetPropertyChangedSignal("TextSize"):Connect(function() cap.MaxTextSize=l.TextSize*1.5 end)
 for _,x in {5,-10} do
  local screw=Theme.New("Frame",l,"Rivet",{Position=x>0 and UDim2.fromOffset(x,6) or UDim2.new(1,x,0,6),Size=UDim2.fromOffset(5,5),BackgroundColor3=Color3.fromRGB(150,104,42),BorderSizePixel=0,ZIndex=4}) corner(screw,4)
 end
end
function Theme.Plate(l,color)
 l:SetAttribute("Designed",true) l.BackgroundColor3=color or Color3.fromRGB(255,244,211)
 l.BackgroundTransparency=0 l.TextColor3=INK l.TextStrokeTransparency=1
 corner(l,12) stroke(l,Color3.fromRGB(191,151,66),1.5)
end
function Theme.Pedestal(parent,color,pos,size)
 local holder=Theme.New("Frame",parent,"DisplayPedestal",{Position=pos,Size=size,BackgroundTransparency=1,ZIndex=1})
 for _,v in {{.28,.68,color:Lerp(Color3.new(0,.25,.5),.35)},{0,.65,color},{0,.44,color:Lerp(Color3.new(1,1,1),.55)}} do
  local d=Theme.New("Frame",holder,"Disc",{Position=UDim2.fromScale(0,v[1]),Size=UDim2.fromScale(1,v[2]),BackgroundColor3=v[3],BorderSizePixel=0,ZIndex=1})
  local c=Instance.new("UICorner") c.CornerRadius=UDim.new(1,0) c.Parent=d
  stroke(d,Color3.fromRGB(207,255,255),2)
 end
 return holder
end
function Theme.Canvas(panel,width,height)
 local scale=panel:FindFirstChildOfClass("UIScale") or Instance.new("UIScale") scale.Parent=panel
 panel.AnchorPoint=Vector2.new(.5,.5)
 local function update()
  local sg=panel:FindFirstAncestorOfClass("ScreenGui")
  local v=sg and sg.AbsoluteSize or workspace.CurrentCamera.ViewportSize
  panel.Position=UDim2.fromScale(.5,.5)
  panel.Size=UDim2.fromOffset(width,height)
  scale.Scale=math.min((v.X-34)/width,(v.Y-34)/height,1.45)
 end
 workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(update)
 update() return scale
end
local oldShell=Theme.Shell
function Theme.Shell(panel)
 oldShell(panel)
 local bar=Theme.New("Frame",panel,"GarageHeaderBar",{Position=UDim2.fromOffset(10,10),Size=UDim2.new(1,-20,0,76),BackgroundColor3=Color3.fromRGB(0,96,169),BorderSizePixel=0,ZIndex=0})
 corner(bar,17)
 local g=Theme.New("UIGradient",bar,"Shade",{Rotation=90,Color=ColorSequence.new(Color3.fromRGB(18,161,227),Color3.fromRGB(0,69,137))})
 local sg=panel:FindFirstAncestorOfClass("ScreenGui")
 if sg then
  local root=panel
  while root.Parent and root.Parent~=sg do root=root.Parent end
  if root:IsA("GuiObject") then root.ZIndex=10 end
  local bg=Theme.New("ImageLabel",sg,"GarageWorldBackdrop",{Size=UDim2.fromScale(1,1),Image=Theme.Background,ScaleType=Enum.ScaleType.Crop,BackgroundColor3=BLUE,BorderSizePixel=0,ZIndex=8,Visible=false})
  local inset=sg.IgnoreGuiInset and Vector2.zero or game:GetService("GuiService"):GetGuiInset()
  bg.Position=UDim2.fromOffset(0,-inset.Y) bg.Size=UDim2.new(1,0,1,inset.Y)
  local function vis()
   local shown=panel.Visible local p=panel.Parent
   while p and p~=sg do if p:IsA("GuiObject") and not p.Visible then shown=false end p=p.Parent end
   bg.Visible=shown
  end
  panel:GetPropertyChangedSignal("Visible"):Connect(vis)
  if panel.Parent:IsA("GuiObject") then panel.Parent:GetPropertyChangedSignal("Visible"):Connect(vis) end
  panel.Destroying:Once(function() bg:Destroy() end) vis()
 end
 for _,o in panel:GetDescendants() do
  if o:IsA("TextButton") and (o.Text=="X" or o.Text=="×") then Theme.Button(o,Color3.fromRGB(255,94,28)) end
 end
end

return Theme

