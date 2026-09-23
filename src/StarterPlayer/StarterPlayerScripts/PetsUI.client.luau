-- Collector garage Pets menu. Ownership, bonuses and equip remain server-owned.
local RS=game:GetService("ReplicatedStorage")
local Players=game:GetService("Players")
local player=Players.LocalPlayer
local gui=player:WaitForChild("PlayerGui"):WaitForChild("JunkyardUI")
local Garage=require(RS:WaitForChild("GarageTheme"))
local Style=require(RS:WaitForChild("UIStyle"))
local Nav=require(RS:WaitForChild("NavButton"))
local Catalog=require(RS:WaitForChild("AreaPets"))
local equipped,selected,area=nil,nil,"junkyard"
local owned={}
local button=Nav.Create(gui,"🐾","PETS",Style.Palette.Mint,Nav.RailPosition("left",4))
local navArt=button:FindFirstChild("Illustration")
if navArt then navArt.Image="rbxassetid://98114882060104" navArt.ImageRectOffset=Vector2.zero navArt.ImageRectSize=Vector2.zero end
local panel=Garage.New("Frame",gui,"PetsFrame",{Visible=false,Size=UDim2.fromOffset(1200,820)})
Style.Modal(panel) Garage.Canvas(panel,1200,820) Garage.Shell(panel)
local title=Garage.Text(panel,"Title","MY PETS",UDim2.fromOffset(91,14),UDim2.fromOffset(360,64),46) Garage.Header(title)
Garage.Art(panel,"PETS",UDim2.fromOffset(12,9),UDim2.fromOffset(78,78))
local close=Garage.New("TextButton",panel,"Close",{Text="X",Position=UDim2.new(1,-75,0,16),Size=UDim2.fromOffset(56,56),TextSize=36,BackgroundColor3=Color3.fromRGB(255,94,28)}) Garage.Button(close)
close.Activated:Connect(function() panel.Visible=false end)
local search=Garage.New("TextBox",panel,"Search",{Text="",PlaceholderText="Search pets...",ClearTextOnFocus=false,Position=UDim2.fromOffset(824,98),Size=UDim2.fromOffset(352,42),TextSize=20,Font=Enum.Font.FredokaOne,BackgroundColor3=Color3.fromRGB(191,234,255)})
local scroll=Garage.New("ScrollingFrame",panel,"OwnedPets",{Position=UDim2.fromOffset(22,108),Size=UDim2.fromOffset(782,652),BackgroundTransparency=1,BorderSizePixel=0,CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y,ScrollBarThickness=5})
local layout=Instance.new("UIGridLayout") layout.CellSize=UDim2.fromOffset(246,296) layout.CellPadding=UDim2.fromOffset(12,18) layout.SortOrder=Enum.SortOrder.LayoutOrder layout.Parent=scroll
local details=Garage.New("Frame",panel,"PetDetails",{Position=UDim2.fromOffset(824,151),Size=UDim2.fromOffset(352,609),BackgroundColor3=Color3.fromRGB(44,171,237)})
Garage.Inset(details)
local counter=Garage.Text(panel,"OwnedCount","0 owned",UDim2.new(0,22,1,-49),UDim2.new(1,-44,0,32),28)
local tabs={}
local accents={junkyard=Color3.fromRGB(255,140,24),brainrot=Color3.fromRGB(233,62,237),haunted=Color3.fromRGB(46,218,203),secret=Color3.fromRGB(165,79,248)}
local function portraitIndex(pet)
 return pet.secret and 5 or tonumber(pet.key:match("_(%d+)$")) or 6
end
local function showDetails(pet)
 selected=pet and pet.key or nil
 for _,c in details:GetChildren() do if c:IsA("GuiObject") then c:Destroy() end end
 if not pet then Garage.Text(details,"Empty","Select a pet",UDim2.fromOffset(20,250),UDim2.new(1,-40,0,50),26) return end
 local name=Garage.Text(details,"Name",pet.name,UDim2.fromOffset(12,14),UDim2.new(1,-24,0,67),25,Color3.new(1,1,1))
 name.TextStrokeColor3=Color3.fromRGB(0,38,75) name.TextStrokeTransparency=0
 Garage.Pedestal(details,accents[area],UDim2.fromOffset(18,280),UDim2.new(1,-36,0,94))
 Garage.PetArt(details,portraitIndex(pet),UDim2.fromOffset(20,88),UDim2.new(1,-40,0,256))
 local coins=Garage.Text(details,"Coins",string.format("Coin bonus   +%d%%",math.floor((pet.coinMult-1)*100+.5)),UDim2.fromOffset(16,386),UDim2.new(1,-32,0,50),23) Garage.Plate(coins)
 local speed=Garage.Text(details,"Speed",string.format("Speed bonus   +%d%%",math.floor((pet.speedMult-1)*100+.5)),UDim2.fromOffset(16,445),UDim2.new(1,-32,0,50),23) Garage.Plate(speed)
 local equip=Garage.New("TextButton",details,"Equip",{Position=UDim2.fromOffset(16,514),Size=UDim2.new(1,-32,0,71),Text=equipped==pet.key and "EQUIPPED" or "EQUIP",TextSize=34,BackgroundColor3=equipped==pet.key and Color3.fromRGB(19,215,148) or Color3.fromRGB(255,156,18)})
 Garage.Button(equip)
 equip.Activated:Connect(function() if owned[pet.key] then RS.EquipAreaPet:FireServer(pet.key) end end)
end
local function redraw()
 for _,c in scroll:GetChildren() do if c:IsA("GuiObject") then c:Destroy() end end
 local count,first,selection=0,nil,nil
 for _,egg in Catalog.Areas[area].eggs do for _,pet in egg.pets do
  if owned[pet.key] then
   count+=1 if not first then first=pet end if pet.key==selected then selection=pet end
   if search.Text=="" or string.find(string.lower(pet.name),string.lower(search.Text),1,true) then
    local card=Garage.New("TextButton",scroll,pet.key,{Text="",LayoutOrder=count,BackgroundColor3=Color3.fromRGB(82,187,231),AutoButtonColor=false})
    Garage.Inset(card)
    Garage.Pedestal(card,accents[area],UDim2.new(.04,0,0,168),UDim2.new(.92,0,0,65))
    Garage.PetArt(card,portraitIndex(pet),UDim2.new(.08,0,0,14),UDim2.new(.84,0,0,197))
    local name=Garage.Text(card,"Name",pet.name,UDim2.new(.04,0,0,218),UDim2.new(.92,0,0,41),17) Garage.Plate(name)
    local stats=Garage.Text(card,"Bonuses",string.format("+%d%% coins  •  +%d%% speed",math.floor((pet.coinMult-1)*100+.5),math.floor((pet.speedMult-1)*100+.5)),UDim2.new(.04,0,0,266),UDim2.new(.92,0,0,25),15) Garage.Plate(stats)
    if pet.key==equipped then local badge=Garage.Text(card,"Equipped","✓ EQUIPPED",UDim2.new(.08,0,0,2),UDim2.new(.84,0,0,30),19) Garage.Plate(badge,Color3.fromRGB(255,219,66)) end
    card.Activated:Connect(function() showDetails(pet) end)
   end
  end
 end end
 counter.Text=count.." owned"
 if count==0 then Garage.Text(scroll,"Empty","No pets from this area yet.\nHatch an egg to start your collection.",UDim2.fromOffset(0,0),UDim2.fromOffset(740,180),25) end
 showDetails(selection or first)
end
for i,key in {"junkyard","brainrot","haunted","secret"} do
 local tab=Garage.New("TextButton",panel,key,{Text=string.upper(key),Position=UDim2.fromOffset(470+(i-1)*151,21),Size=UDim2.fromOffset(143,52),TextSize=20,BackgroundColor3=accents[key]})
 Garage.Button(tab) tabs[key]=tab
 tab.Activated:Connect(function() area=key selected=nil redraw() end)
end
search:GetPropertyChangedSignal("Text"):Connect(redraw)
button.Activated:Connect(function() panel.Visible=not panel.Visible if panel.Visible then redraw() end end)
RS.GameUpdate.OnClientEvent:Connect(function(data)
 local changed=false
 if data.ownedAreaPets~=nil then owned=data.ownedAreaPets changed=true end
 if data.equippedAreaPet~=nil then equipped=data.equippedAreaPet and data.equippedAreaPet.key or nil changed=true end
 if changed and panel.Visible then redraw() end
end)
