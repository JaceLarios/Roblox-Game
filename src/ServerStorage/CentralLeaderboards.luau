-- Two readable central boards; reads existing ranking caches without writing player data.
local Boards={}
local RGB,V,CF=Color3.fromRGB,Vector3.new,CFrame.new
local function part(f,name,size,cf,col)
 local p=Instance.new("Part") p.Name=name p.Size=size p.CFrame=cf p.Color=col
 p.Anchored=true p.Material=Enum.Material.Metal p.CanTouch=false p.Parent=f return p
end
local function label(parent,text,x,y,w,h,size,col)
 local t=Instance.new("TextLabel",parent) t.BackgroundTransparency=1 t.Position=UDim2.fromOffset(x,y) t.Size=UDim2.fromOffset(w,h)
 t.Font=Enum.Font.FredokaOne t.TextSize=size t.TextColor3=col t.Text=text return t
end
local function commas(n)
 local s=tostring(math.floor(n)) repeat local next,count=s:gsub("^(-?%d+)(%d%d%d)","%1,%2") s=next if count==0 then break end until false return s
end
function Boards.Start(coins,playtime)
 local old=workspace:FindFirstChild("CentralLeaderboards") if old then old:Destroy() end
 local root=Instance.new("Model",workspace) root.Name="CentralLeaderboards"
 local renders={}
 local configs={
  {name="AllTimeMoney",title="ALL-TIME MONEY",sub="Total coins earned • Global Top 100",color=RGB(255,204,65),side=1,service=coins,format=function(e) return commas(e.coins).." coins" end},
  {name="AllTimePlaytime",title="ALL-TIME PLAYTIME",sub="Total time played • Global Top 100",color=RGB(86,212,255),side=-1,service=playtime,format=function(e) local minutes=math.floor(e.minutes) return string.format("%dh %02dm",math.floor(minutes/60),minutes%60) end},
 }
 for _,cfg in ipairs(configs) do
  local model=Instance.new("Model",root) model.Name=cfg.name
  -- Opposite sides of the crane, beyond its 20-stud sweep.
  local center=V(cfg.side*32,1.2,0)
  local cf=CFrame.lookAt(center,center+V(cfg.side,0,0))
  local navy=RGB(23,43,59) local steel=RGB(108,131,145)
  part(model,"Footing",V(21,1.1,5),cf*CF(0,.55,0),navy).Material=Enum.Material.DiamondPlate
  for _,x in ipairs({-8,8}) do
   part(model,"SteelUpright",V(1.3,23,.8),cf*CF(x,12,0),steel)
   for y=1.8,4.2,1.2 do part(model,"SafetyStripe",V(1.4,.4,1.6),cf*CF(x,y,0),cfg.color) end
  end
  part(model,"OuterHousing",V(20.7,17.7,1.3),cf*CF(0,13,0),navy)
  part(model,"MetalBevel",V(20.1,17.1,1.4),cf*CF(0,13,0),steel)
  local panel=part(model,"Display",V(19.4,16.4,1.5),cf*CF(0,13,0),RGB(15,35,53))
  for _,x in ipairs({-10.2,10.2}) do
   local rail=part(model,"AccentLight",V(.18,17,.18),cf*CF(x,13,-.82),cfg.color) rail.Material=Enum.Material.Neon
   for _,y in ipairs({5.1,20.9}) do
    local bolt=part(model,"FrameBolt",V(.4,.4,.2),cf*CF(x,y,-.83),RGB(206,222,232)) bolt.Shape=Enum.PartType.Ball
   end
  end
  part(model,"HeaderPlate",V(18,3.6,1.8),cf*CF(0,24,0),cfg.color)
  part(model,"RainCanopy",V(22,.4,3.2),cf*CF(0,26,0),navy)
  -- Raised coin/clock emblems, recognizable from either approach.
  for _,sign in ipairs({-1,1}) do
   local emblem=part(model,"Emblem",V(.4,2.6,2.6),cf*CF(-7,24,sign*1.05)*CFrame.Angles(0,math.pi/2,0),navy) emblem.Shape=Enum.PartType.Cylinder
   local gui=Instance.new("SurfaceGui",emblem) gui.Face=sign==-1 and Enum.NormalId.Right or Enum.NormalId.Left gui.CanvasSize=Vector2.new(128,128) gui.LightInfluence=0
   if cfg.side==1 then label(gui,"$",0,0,128,128,100,cfg.color)
   else
    local rim=Instance.new("Frame",gui) rim.Position=UDim2.fromOffset(18,18) rim.Size=UDim2.fromOffset(92,92) rim.BackgroundTransparency=1
    Instance.new("UICorner",rim).CornerRadius=UDim.new(1,0)
    local outline=Instance.new("UIStroke",rim) outline.Color=cfg.color outline.Thickness=6
    for _,d in ipairs({{61,32,6,34},{64,61,26,6}}) do local hand=Instance.new("Frame",gui) hand.Position=UDim2.fromOffset(d[1],d[2]) hand.Size=UDim2.fromOffset(d[3],d[4]) hand.BackgroundColor3=cfg.color hand.BorderSizePixel=0 end
   end
   local plate=Instance.new("SurfaceGui",model.HeaderPlate) plate.Face=sign==-1 and Enum.NormalId.Front or Enum.NormalId.Back plate.CanvasSize=Vector2.new(900,180) plate.LightInfluence=0
   label(plate,"GLOBAL TOP 100",170,15,560,150,56,navy)
  end
  for _,face in ipairs({Enum.NormalId.Front,Enum.NormalId.Back}) do
   local gui=Instance.new("SurfaceGui",panel) gui.Name="RankingSurface" gui.Face=face gui.CanvasSize=Vector2.new(720,610) gui.SizingMode=Enum.SurfaceGuiSizingMode.FixedSize gui.LightInfluence=0 gui.MaxDistance=160 gui.Active=true gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
   local banner=Instance.new("Frame",gui) banner.Size=UDim2.fromOffset(720,96) banner.BackgroundColor3=RGB(25,78,112) banner.BorderSizePixel=0
   local grad=Instance.new("UIGradient",banner) grad.Color=ColorSequence.new(RGB(24,108,153),RGB(13,43,71)) grad.Rotation=90
   label(gui,cfg.title,16,6,688,54,36,cfg.color)
   label(gui,cfg.sub,16,58,688,26,20,RGB(202,222,236))
   local scroll=Instance.new("ScrollingFrame",gui) scroll.Name="Rankings" scroll.BackgroundTransparency=1 scroll.BorderSizePixel=0 scroll.Position=UDim2.fromOffset(18,104) scroll.Size=UDim2.fromOffset(684,460) scroll.ScrollBarThickness=18 scroll.ScrollBarImageColor3=cfg.color
   scroll.Active=true scroll.ScrollingEnabled=true scroll.ScrollingDirection=Enum.ScrollingDirection.Y
   scroll.AutomaticCanvasSize=Enum.AutomaticSize.Y scroll.CanvasSize=UDim2.new()
   local layout=Instance.new("UIListLayout",scroll) layout.Padding=UDim.new(0,8) layout.SortOrder=Enum.SortOrder.LayoutOrder
   local footer=label(gui,"SCROLL TO EXPLORE THE TOP 100",16,578,688,24,20,cfg.color)
   local signature
   local function render(top)
    local fields={} for _,e in ipairs(top) do table.insert(fields,tostring(e.userId)..":"..tostring(e.name)..":"..cfg.format(e)) end
    local next=table.concat(fields,"|") if signature==next then return end signature=next
    footer.Text=string.format("%d RANKED  •  SCROLL FOR MORE",math.min(#top,100))
    for _,child in ipairs(scroll:GetChildren()) do if child:IsA("GuiObject") then child:Destroy() end end
    if #top==0 then label(scroll,"Rankings are loading. Check back shortly.",0,0,670,80,23,RGB(206,218,228)) return end
    for rank,e in ipairs(top) do
     if rank>100 then break end
     local row=Instance.new("Frame",scroll) row.Name="Rank"..rank row.LayoutOrder=rank row.Size=UDim2.new(1,-12,0,88) row.BorderSizePixel=0 row.BackgroundColor3=rank%2==0 and RGB(27,56,76) or RGB(34,67,89)
     Instance.new("UICorner",row).CornerRadius=UDim.new(0,10)
     local stroke=Instance.new("UIStroke",row) stroke.Thickness=rank<=3 and 2 or 1 stroke.Color=rank<=3 and cfg.color or RGB(66,100,124) stroke.Transparency=rank<=3 and .15 or .55
     local rankColor=rank<=3 and cfg.color or RGB(222,235,244)
     label(row,"#"..rank,4,20,65,48,27,rankColor)
     local image=Instance.new("ImageLabel",row) image.Name="PlayerAvatar" image.Position=UDim2.fromOffset(72,8) image.Size=UDim2.fromOffset(72,72) image.BackgroundColor3=RGB(213,233,242) image.BorderSizePixel=0 image.ScaleType=Enum.ScaleType.Fit
     Instance.new("UICorner",image).CornerRadius=UDim.new(0,8)
     if e.userId then image.Image="rbxthumb://type=Avatar&id="..tostring(e.userId).."&w=150&h=150" end
     local name=label(row,e.name or "Player",158,8,490,34,28,RGB(246,250,255)) name.TextXAlignment=Enum.TextXAlignment.Left name.TextTruncate=Enum.TextTruncate.AtEnd
     local value=label(row,cfg.format(e),158,45,490,30,25,cfg.color) value.TextXAlignment=Enum.TextXAlignment.Left
    end
   end
   table.insert(renders,{service=cfg.service,render=render})
  end
 end
 task.spawn(function()
  while root.Parent do
   coins.RefreshIfStale() playtime.RefreshIfStale()
   for _,item in ipairs(renders) do item.render(item.service.GetTopCached()) end
   task.wait(15)
  end
 end)
 return root
end
return Boards
