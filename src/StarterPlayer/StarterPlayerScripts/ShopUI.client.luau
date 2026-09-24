local Garage=require(game:GetService("ReplicatedStorage"):WaitForChild("GarageTheme"))
-- Reference-guided shop: illustrated offer grid, white shell, code redemption last.
local Players=game:GetService("Players")
local MarketplaceService=game:GetService("MarketplaceService")
local ReplicatedStorage=game:GetService("ReplicatedStorage")
local player=Players.LocalPlayer
local Config=require(ReplicatedStorage:WaitForChild("GamepassConfig"))
local NavButton=require(ReplicatedStorage:WaitForChild("NavButton"))
local Style=require(ReplicatedStorage:WaitForChild("UIStyle"))
local redeemCodeRemote=ReplicatedStorage:WaitForChild("RedeemCode")
local WHITE=Style.Palette.Cream
local GOLD=Style.Palette.Gold
local BLACK=Style.Palette.Ink
local gui=Instance.new("ScreenGui")
gui.Name="ShopUI"
gui.ZIndexBehavior=Enum.ZIndexBehavior.Sibling
gui.ResetOnSpawn=false
gui.DisplayOrder=20
gui:SetAttribute("Designed",true)
gui.Parent=player:WaitForChild("PlayerGui")
local function corner(p,r)
	local c=Instance.new("UICorner") c.CornerRadius=UDim.new(0,r or 16) c.Parent=p
end
local function text(p,n,t,pos,size,fontSize,outline)
	local l=Instance.new("TextLabel")
	l.Name=n l.BackgroundTransparency=1 l.Text=t l.Position=pos l.Size=size
	l.Font=Enum.Font.FredokaOne l.TextColor3=BLACK l.TextSize=fontSize
	l.TextWrapped=true l.ZIndex=3 l.Parent=p
	if outline then Style.Outline(l,fontSize) end
	return l
end
local open=NavButton.Create(gui,"","SHOP",WHITE,NavButton.RailPosition("right",3))
local overlay=Instance.new("Frame")
overlay.Name="Overlay" overlay.Size=UDim2.fromScale(1,1)
overlay.BackgroundColor3=BLACK overlay.BackgroundTransparency=.7 overlay.Visible=false
overlay.Parent=gui
Style.Modal(overlay)
local panel=Instance.new("Frame")
panel.Name="ShopPanel" panel.AnchorPoint=Vector2.new(.5,.5) panel.Position=UDim2.fromScale(.5,.55)
panel.Parent=overlay corner(panel,24) Style.Surface(panel,WHITE,5)
local scale=Instance.new("UIScale") scale.Parent=panel
local function fit()
	local size=overlay.AbsoluteSize
	if size.Y<100 then return end
	local compact=size.X<650
	local width=compact and 600 or 1200
	panel.Position=UDim2.fromScale(.5,.5)
	if Garage.IsPhone(size) and not compact then
		-- A phone on its side: as wide as the screen and as tall as it, not
		-- the whole 820 squeezed in and unreadable. The sections scroll.
		scale.Scale=math.min((size.X-16)/width,1)
		panel.Size=UDim2.fromOffset(width,(size.Y-12)/scale.Scale)
	else
		scale.Scale=math.min((size.X-34)/width,(size.Y-34)/820,1.45)
		panel.Size=UDim2.fromOffset(width,820)
	end
	panel:SetAttribute("Compact",compact)
end
overlay:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit) fit()
Garage.Art(panel,"SHOP",UDim2.fromOffset(14,8),UDim2.fromOffset(78,78))
local title=text(panel,"Title","Scrap Shop!",UDim2.fromOffset(104,12),UDim2.fromOffset(440,64),48,true)
title.TextXAlignment=Enum.TextXAlignment.Left
local close=Instance.new("TextButton") close.Name="Close" close.Parent=panel Style.Close(close)
local scroll=Instance.new("ScrollingFrame")
scroll.Name="Sections" scroll.Size=UDim2.new(1,-38,1,-126) scroll.Position=UDim2.fromOffset(19,95)
scroll.BackgroundTransparency=1 scroll.BorderSizePixel=0 scroll.ScrollBarThickness=7
scroll.ScrollBarImageColor3=BLACK scroll.AutomaticCanvasSize=Enum.AutomaticSize.Y scroll.CanvasSize=UDim2.new()
scroll.Parent=panel Style.ScrollPadding(scroll)
local list=Instance.new("UIListLayout") list.Padding=UDim.new(0,10) list.SortOrder=Enum.SortOrder.LayoutOrder list.Parent=scroll
local message=text(panel,"Message","",UDim2.new(0,18,1,-26),UDim2.new(1,-36,0,24),16,false)
local function section(name,order)
	local h=Instance.new("Frame") h.Name=name.."Section" h.BackgroundTransparency=1
	h.Size=UDim2.new(1,-10,0,50) h.LayoutOrder=order h.Parent=scroll
	local label=text(h,"Heading",name,UDim2.fromOffset(0,0),UDim2.fromOffset(260,42),30,false)
	label.TextXAlignment=Enum.TextXAlignment.Left
	local line=Instance.new("Frame") line.BorderSizePixel=0 line.BackgroundColor3=Color3.fromRGB(207,216,209)
	line.Position=UDim2.new(0,270,.5,0) line.Size=UDim2.new(1,-270,0,3) line.Parent=h
end
section("Gamepasses",10)
local passGrid=Instance.new("Frame") passGrid.Name="GamepassesGrid" passGrid.BackgroundTransparency=1
passGrid.LayoutOrder=11 passGrid.Parent=scroll
local grid=Instance.new("UIGridLayout") grid.SortOrder=Enum.SortOrder.LayoutOrder grid.CellPadding=UDim2.fromOffset(12,12) grid.Parent=passGrid
-- 4 entries now (was 3, fixed at "one row" worth of height) — StarterPack
-- added below. gridFit computes its height from the real count so a
-- future 5th/6th gamepass doesn't silently clip or overlap again.
local PASS_ORDER={"DoubleCoins","ExtraCarry","AutoCollect","StarterPack"}
local function gridFit()
	local compact=panel:GetAttribute("Compact")
	local cols=compact and 2 or 4
	local rows=math.ceil(#PASS_ORDER/cols)
	local cellH=230
	grid.FillDirectionMaxCells=cols
	grid.CellSize=UDim2.new(1/cols,-12,0,cellH)
	passGrid.Size=UDim2.new(1,-6,0,rows*cellH+(rows-1)*12+10)
end
panel:GetAttributeChangedSignal("Compact"):Connect(gridFit) gridFit()
local PASS_ACCENTS={DoubleCoins=Color3.fromRGB(243,162,101),ExtraCarry=Color3.fromRGB(95,185,174),AutoCollect=Color3.fromRGB(129,164,194),StarterPack=Color3.fromRGB(180,140,210)}
local BENEFITS={DoubleCoins="Double your sale and reward coins!",ExtraCarry="Carry 2 extra items every trip!",AutoCollect="Collect nearby scrap automatically!",StarterPack="Permanent coin & speed boost!"}
local refreshers={}
local pendingId=nil
for i,key in ipairs(PASS_ORDER) do
	local item=Config[key]
	local banner=Instance.new("Frame") banner.Name=key banner.LayoutOrder=i banner.ClipsDescendants=true banner.Parent=passGrid
	corner(banner,17) Style.Surface(banner,WHITE,3)
	local gradient=Instance.new("UIGradient")
	gradient.Color=ColorSequence.new(PASS_ACCENTS[key]:Lerp(WHITE,.6),PASS_ACCENTS[key])
	gradient.Rotation=65 gradient.Parent=banner
	text(banner,"Title",item.name,UDim2.fromOffset(10,13),UDim2.new(1,-20,0,58),36,true)
	Garage.Art(banner,key,UDim2.new(0,5,0,84),UDim2.new(.51,0,0,186))
	text(banner,"Description",BENEFITS[key],UDim2.new(.51,0,0,90),UDim2.new(.46,0,0,165),25,true)
	local buy=Instance.new("TextButton")
	buy.Name="Purchase" buy.Size=UDim2.new(1,-28,0,60) buy.Position=UDim2.new(0,14,1,-76)
	buy.Font=Enum.Font.FredokaOne buy.TextSize=27 buy.TextWrapped=true buy.ZIndex=3 buy.Parent=banner
	corner(buy,12) Style.Surface(buy,WHITE,2)
	local info, loading = nil, false
	local function refresh()
		local owns = player:GetAttribute("Pass_" .. key) == true
		local status = player:GetAttribute("PassStatus_" .. key)
		local available = item.id > 0 and info and info.IsForSale == true and type(info.PriceInRobux) == "number"
		local enabled = not owns and available and status == "Ready" and pendingId == nil
		buy.Active = enabled == true
		buy.AutoButtonColor = enabled == true
		buy.BackgroundColor3 = enabled and GOLD or WHITE
		buy.TextColor3 = Color3.fromRGB(30, 30, 36)
		if owns then
			buy.Text = "OWNED"
		elseif item.id <= 0 then
			buy.Text = "COMING SOON"
		elseif pendingId then
			buy.Text = "PLEASE WAIT"
		elseif status == "Retry" then
			buy.Text = "TRY LATER"
		elseif not status or status == "Checking" or loading then
			buy.Text = "CHECKING..."
		elseif available then
			buy.Text = tostring(info.PriceInRobux) .. " Robux"
		else
			buy.Text = "UNAVAILABLE"
		end
	end
	refreshers[key] = refresh
	player:GetAttributeChangedSignal("Pass_" .. key):Connect(refresh)
	player:GetAttributeChangedSignal("PassStatus_" .. key):Connect(refresh)
	buy.Activated:Connect(function()
		if not buy.Active then return end
		pendingId = item.id
		message.Text = ""
		for _, f in pairs(refreshers) do f() end
		local ok = pcall(function() MarketplaceService:PromptGamePassPurchase(player, item.id) end)
		if not ok then
			pendingId = nil
			message.Text = "Purchase prompt unavailable. Please try again."
			for _, f in pairs(refreshers) do f() end
		end
	end)
	local function loadInfo()
		if item.id <= 0 or loading then refresh() return end
		loading = true
		refresh()
		local ok, result = pcall(function()
			return MarketplaceService:GetProductInfo(item.id, Enum.InfoType.GamePass)
		end)
		info = ok and result or nil
		loading = false
		refresh()
	end
	open.Activated:Connect(function() task.spawn(loadInfo) end)
	refresh()
end

MarketplaceService.PromptGamePassPurchaseFinished:Connect(function(who, id, purchased)
	if who ~= player or pendingId ~= id then return end
	pendingId = nil
	message.Text = purchased and "Purchase completed. Your benefits update automatically." or ""
	for _, f in pairs(refreshers) do f() end
end)

local function feature(name,kind,titleValue,description,order,color,action)
	local card=Instance.new("Frame") card.Name=name card.LayoutOrder=order card.Size=UDim2.new(1,-12,0,220)
	card.Parent=scroll corner(card,18) Style.Surface(card,color,3)
	Garage.Art(card,kind,UDim2.fromOffset(18,18),UDim2.fromOffset(180,180))
	local heading=text(card,"Title",titleValue,UDim2.fromOffset(218,24),UDim2.new(1,-440,0,52),34,true)
	heading.TextXAlignment=Enum.TextXAlignment.Left
	local desc=text(card,"Description",description,UDim2.fromOffset(218,84),UDim2.new(1,-440,0,110),22,false)
	desc.TextXAlignment=Enum.TextXAlignment.Left
	local button=Instance.new("TextButton") button.Name="Action" button.Size=UDim2.fromOffset(180,64)
	button.Position=UDim2.new(1,-200,.5,-32) button.Text=action and "View Rewards" or "Coming Soon"
	button.TextSize=24 button.TextWrapped=true button.Font=Enum.Font.FredokaOne button.Active=action~=nil
	button.AutoButtonColor=action~=nil button.Parent=card corner(button,12) Style.Surface(button,WHITE,2)
	if action then button.Activated:Connect(action) end
	return card
end
section("Boosts",200)
feature("RewardBoosts","DoubleCoins","Reward Boosts!","Find timed boosts in your daily rewards.",210,Color3.fromRGB(245,218,174),function()
	overlay.Visible=false
	local e=player.PlayerGui:FindFirstChild("OpenDailyRewards") if e then e:Fire() end
end)
section("Redeem a Code",300)
local codeBanner=Instance.new("Frame") codeBanner.Name="CodeBanner" codeBanner.LayoutOrder=310
codeBanner.Size=UDim2.new(1,-12,0,168) codeBanner.Parent=scroll corner(codeBanner,18)
Style.Surface(codeBanner,Color3.fromRGB(237,233,223),2)
Garage.Art(codeBanner,"CODE",UDim2.fromOffset(12,10),UDim2.fromOffset(144,144))
local codeBox=Instance.new("TextBox") codeBox.Name="Code" codeBox.Text="" codeBox.PlaceholderText="Enter your code..."
codeBox.Size=UDim2.new(1,-370,0,66) codeBox.Position=UDim2.new(0,164,.5,-33)
codeBox.Font=Enum.Font.FredokaOne codeBox.TextSize=25 codeBox.ClearTextOnFocus=false
codeBox.Parent=codeBanner corner(codeBox,12) Style.Surface(codeBox,WHITE,2)
local redeemBtn=Instance.new("TextButton") redeemBtn.Name="Redeem" redeemBtn.Text="Redeem!"
redeemBtn.Size=UDim2.fromOffset(170,66) redeemBtn.Position=UDim2.new(1,-190,.5,-33)
redeemBtn.Font=Enum.Font.FredokaOne redeemBtn.Parent=codeBanner corner(redeemBtn,12)
Style.Surface(redeemBtn,Style.Palette.Teal,3) Style.Outline(redeemBtn,28)
local function submitCode()
	local code=codeBox.Text if code=="" then return end
	redeemCodeRemote:FireServer(code) codeBox.Text=""
end
redeemBtn.Activated:Connect(submitCode)
codeBox.FocusLost:Connect(function(enter) if enter then submitCode() end end)
local function reflowFeatures()
 local compact=panel:GetAttribute("Compact")
 title.Text="SCRAP SHOP" title.TextSize=46 title.Size=UDim2.fromOffset(compact and 360 or 500,64)
 for _,n in {"BoostsSection","Redeem a CodeSection"} do local h=scroll:FindFirstChild(n) if h then h.Visible=false end end
 for _,card in passGrid:GetChildren() do if card:IsA("Frame") then
  Garage.Inset(card)
  card.Title.Position=UDim2.new(0,8,0,153) card.Title.Size=UDim2.new(1,-16,0,35) card.Title.TextSize=21 Garage.Plate(card.Title)
  local outline=card.Title:FindFirstChild("TextOutline") if outline then outline:Destroy() end
  card.Description.Visible=false
  local art=card:FindFirstChild("GarageArt") if art then art.Position=UDim2.new(.17,0,0,4) art.Size=UDim2.new(.66,0,0,153) end
  if not card:FindFirstChild("DisplayPedestal") then Garage.Pedestal(card,Color3.fromRGB(59,229,204),UDim2.new(.04,0,0,113),UDim2.new(.92,0,0,65)) end
  card.Purchase.Position=UDim2.new(0,9,1,-48) card.Purchase.Size=UDim2.new(1,-18,0,41) card.Purchase.TextSize=22 Garage.Button(card.Purchase,Color3.fromRGB(121,154,200))
 end end
 local boosts=scroll.RewardBoosts boosts.Size=UDim2.new(1,-12,0,84) Garage.Inset(boosts)
 boosts.Title.Position=UDim2.fromOffset(85,4) boosts.Title.Size=UDim2.new(.55,-85,0,37) boosts.Title.TextSize=26
 boosts.Description.Position=UDim2.fromOffset(85,42) boosts.Description.Size=UDim2.new(.55,-85,0,29) boosts.Description.TextSize=17
 boosts.GarageArt.Position=UDim2.fromOffset(8,4) boosts.GarageArt.Size=UDim2.fromOffset(72,72)
 boosts.Action.Position=UDim2.new(1,-210,.5,-27) boosts.Action.Size=UDim2.fromOffset(192,54) Garage.Button(boosts.Action,Color3.fromRGB(0,169,248))
 codeBanner.Size=UDim2.new(1,-12,0,83) Garage.Inset(codeBanner)
 codeBanner.GarageArt.Position=UDim2.fromOffset(8,6) codeBanner.GarageArt.Size=UDim2.fromOffset(66,66)
 if not codeBanner:FindFirstChild("Heading") then Garage.Text(codeBanner,"Heading","REDEEM CODE",UDim2.fromOffset(80,6),UDim2.fromOffset(240,63),25,Color3.new(1,1,1)) end
 codeBox.Position=UDim2.new(.34,0,.5,-26) codeBox.Size=UDim2.new(.46,-12,0,52)
 redeemBtn.Size=UDim2.new(.18,-8,0,52) redeemBtn.Position=UDim2.new(.81,0,.5,-26) Garage.Button(redeemBtn,Color3.fromRGB(93,147,195))
end
panel:GetAttributeChangedSignal("Compact"):Connect(reflowFeatures) reflowFeatures()
open.Activated:Connect(function() overlay.Visible=not overlay.Visible if overlay.Visible then fit() end end)
close.Activated:Connect(function() overlay.Visible=false end)
Garage.Shell(panel) Garage.Header(title)
close.Position=UDim2.new(1,-76,0,16)
