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
  {name="AllTimeMoney",title="ALL-TIME MONEY",sub="Total coins earned • Global Top 100",color=RGB(255,204,65),z=-9,service=coins,format=function(e) return commas(e.coins).." coins" end},
  {name="AllTimePlaytime",title="ALL-TIME PLAYTIME",sub="Total time played • Global Top 100",color=RGB(86,212,255),z=9,service=playtime,format=function(e) local minutes=math.floor(e.minutes) return string.format("%dh %02dm",math.floor(minutes/60),minutes%60) end},
 }
 for _,cfg in ipairs(configs) do
  local model=Instance.new("Model",root) model.Name=cfg.name
  -- Outside the crane's 20-stud sweep/drop circle, still in the central yard.
  local cf=CF(29,1.2,cfg.z)*CFrame.Angles(0,-math.pi/2,0)
  part(model,"Footing",V(15,1,5),cf*CF(0,.5,0),RGB(39,55,67))
  for _,x in ipairs({-5,5}) do part(model,"Support",V(1,5,1),cf*CF(x,3,0),RGB(59,83,98)) end
  part(model,"Trim",V(15.1,20.1,.6),cf*CF(0,14,0),cfg.color)
  local panel=part(model,"Display",V(14.4,19.4,1),cf*CF(0,14,0),RGB(15,35,53))
  for _,face in ipairs({Enum.NormalId.Front,Enum.NormalId.Back}) do
   local gui=Instance.new("SurfaceGui",panel) gui.Name="RankingSurface" gui.Face=face gui.CanvasSize=Vector2.new(720,960) gui.SizingMode=Enum.SurfaceGuiSizingMode.FixedSize gui.LightInfluence=0 gui.MaxDistance=160
   label(gui,cfg.title,16,20,688,60,43,cfg.color)
   label(gui,cfg.sub,16,84,688,30,22,RGB(202,222,236))
   local scroll=Instance.new("ScrollingFrame",gui) scroll.Name="Rankings" scroll.BackgroundTransparency=1 scroll.BorderSizePixel=0 scroll.Position=UDim2.fromOffset(18,132) scroll.Size=UDim2.fromOffset(684,778) scroll.ScrollBarThickness=8 scroll.ScrollBarImageColor3=cfg.color
   scroll.AutomaticCanvasSize=Enum.AutomaticSize.Y scroll.CanvasSize=UDim2.new()
   local layout=Instance.new("UIListLayout",scroll) layout.Padding=UDim.new(0,8) layout.SortOrder=Enum.SortOrder.LayoutOrder
   label(gui,"Scroll for more  •  Updates periodically",16,920,688,24,20,RGB(168,192,209))
   local signature
   local function render(top)
    local fields={} for _,e in ipairs(top) do table.insert(fields,tostring(e.userId)..":"..tostring(e.name)..":"..cfg.format(e)) end
    local next=table.concat(fields,"|") if signature==next then return end signature=next
    for _,child in ipairs(scroll:GetChildren()) do if child:IsA("GuiObject") then child:Destroy() end end
    if #top==0 then label(scroll,"Rankings are loading. Check back shortly.",0,0,670,80,23,RGB(206,218,228)) return end
    for rank,e in ipairs(top) do
     local row=Instance.new("Frame",scroll) row.Name="Rank"..rank row.LayoutOrder=rank row.Size=UDim2.new(1,-12,0,88) row.BorderSizePixel=0 row.BackgroundColor3=rank%2==0 and RGB(27,56,76) or RGB(34,67,89)
     Instance.new("UICorner",row).CornerRadius=UDim.new(0,10)
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
