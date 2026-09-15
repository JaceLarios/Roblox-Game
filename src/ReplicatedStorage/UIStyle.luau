-- Shared presentation only. No remotes, currencies, or player-data writes.
local Style = {}
-- Salvage Yard palette: warm enamel, oxidized teal, copper and steel.
Style.Palette = {
	Cream = Color3.fromRGB(255,250,241),
	Ink = Color3.fromRGB(31,44,46),
	Copper = Color3.fromRGB(231,125,73),
	Teal = Color3.fromRGB(57,157,153),
	Steel = Color3.fromRGB(111,145,177),
	Mint = Color3.fromRGB(110,209,172),
	Gold = Color3.fromRGB(236,183,78),
}
local BLACK = Style.Palette.Ink
local WHITE = Style.Palette.Cream
local modals = {}
local navigation = {}
local function updateNavigation()
	local visible = true
	for _, modal in ipairs(modals) do
		if modal.Parent and modal.Visible then visible = false break end
	end
	for _, holder in ipairs(navigation) do if holder.Parent then holder.Visible = visible end end
end
function Style.Navigation(holder)
	table.insert(navigation,holder)
	updateNavigation()
end
function Style.ScrollDetails(panel, height)
	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "DetailsScroll"
	scroll.Size = panel.Size
	scroll.Position = panel.Position
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 5
	scroll.CanvasSize = UDim2.fromOffset(0,height+12)
	scroll.Parent = panel.Parent
	panel.Parent = scroll
	panel.Position = UDim2.fromOffset(4,4)
	panel.Size = UDim2.new(1,-12,0,height)
end
function Style.UpgradeLayout(panel, scroll)
	local compact = panel:GetAttribute("Compact")
	for _, row in ipairs(scroll:GetChildren()) do
		if row:IsA("Frame") then
			row.Size = UDim2.new(1,-10,0,compact and 290 or 156)
			local art = row:FindFirstChild("Illustration")
			if art then art.Size = UDim2.fromOffset(compact and 110 or 140,140) end
			for _, name in ipairs({"UpgradeName","UpgradeNow","UpgradeNext"}) do
				local label = row:FindFirstChild(name)
				if label then
					label.Size = UDim2.new(1,compact and -150 or -360,0,compact and 60 or 32)
					label.Position = UDim2.fromOffset(compact and 130 or 166, name == "UpgradeName" and 14 or name == "UpgradeNow" and (compact and 82 or 62) or (compact and 148 or 98))
					label.TextSize = name == "UpgradeName" and 24 or (compact and 21 or 18)
					label.TextWrapped = true
				end
			end
			local buy = row:FindFirstChild("UpgradeBuy")
			if buy then
				buy.Size = compact and UDim2.new(1,-28,0,58) or UDim2.fromOffset(170,60)
				buy.Position = compact and UDim2.new(0,14,1,-70) or UDim2.new(1,-184,.5,-30)
			end
		end
	end
end
function Style.ScrollPadding(scroll)
	local pad = Instance.new("UIPadding")
	pad.PaddingLeft = UDim.new(0,6)
	pad.PaddingTop = UDim.new(0,6)
	pad.PaddingRight = UDim.new(0,6)
	pad.PaddingBottom = UDim.new(0,6)
	pad.Parent = scroll
end
function Style.Modal(panel)
	panel.ZIndex = 10
	panel.Active = true
	table.insert(modals, panel)
	panel:GetPropertyChangedSignal("Visible"):Connect(function()
		if panel.Visible then
			for _, other in ipairs(modals) do
				if other ~= panel and other.Parent then other.Visible = false end
			end
		end
		updateNavigation()
	end)
end

function Style.Surface(object, color, thickness)
	object.BackgroundColor3 = color or WHITE
	object.BackgroundTransparency = 0
	object.BorderSizePixel = 0
	local stroke = object:FindFirstChildOfClass("UIStroke") or Instance.new("UIStroke")
	stroke.Color = BLACK
	stroke.Transparency = 0
	stroke.Thickness = thickness or 2
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	stroke.Parent = object
end
function Style.Outline(label, size)
	label:SetAttribute("Designed",true)
	label.Font = Enum.Font.FredokaOne
	label.TextColor3 = WHITE
	label.TextStrokeTransparency = 1
	if size then label.TextSize = size end
	local stroke = label:FindFirstChild("TextOutline") or Instance.new("UIStroke")
	stroke.Name = "TextOutline"
	stroke.Color = BLACK
	stroke.Thickness = 3
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	stroke.Parent = label
end
function Style.Close(button)
	button:SetAttribute("Designed",true)
	button.Size = UDim2.fromOffset(58,58)
	button.Position = UDim2.new(1,-44,0,-28)
	button.BackgroundTransparency = 0
	button.BackgroundColor3 = Style.Palette.Copper
	button.Text = "X"
	button.ZIndex = 20
	local corner = button:FindFirstChildOfClass("UICorner") or Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0,12)
	corner.Parent = button
	Style.Surface(button,button.BackgroundColor3,4)
	Style.Outline(button,38)
end
function Style.Attach(gui)
	if gui:GetAttribute("Designed") then return end
	local function apply(object)
		if object:GetAttribute("Designed") or object:GetAttribute("KeepOverlay") then return end
		if object:IsA("UIStroke") and object.Parent:GetAttribute("Floating") then object.Transparency=object.Parent:GetAttribute("Selected") and 0 or 1 return end
		if object:IsA("GuiObject") and object:GetAttribute("Floating") then object.BackgroundTransparency=1 return end
		if object:IsA("TextLabel") or object:IsA("TextBox") then
			object.TextColor3=BLACK
			object.TextStrokeTransparency=1
		elseif (object:IsA("Frame") or object:IsA("TextButton")) and object:FindFirstChildOfClass("UICorner") then
			local c=object.BackgroundColor3
			if (c.R+c.G+c.B)/3 < .35 then
				Style.Surface(object)
				local gradient=object:FindFirstChildOfClass("UIGradient")
				if gradient then gradient.Enabled=false end
			end
			if object:IsA("TextButton") then object.TextColor3=BLACK end
		end
	end
	for _,o in ipairs(gui:GetDescendants()) do apply(o) end
	gui.DescendantAdded:Connect(function(o) task.defer(function() if o:IsDescendantOf(gui) then apply(o) end end) end)
end

function Style.FixedFit(panel, width, height)
	panel.AnchorPoint = Vector2.new(.5,.5)
	panel.Position = UDim2.fromScale(.5,.5)
	local scale = Instance.new("UIScale")
	scale.Parent = panel
	local function update()
		local size = workspace.CurrentCamera.ViewportSize
		scale.Scale = math.min(1.3,(size.X-40)/width,(size.Y-80)/height)
	end
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(update)
	update()
end

-- Fixed design canvas fitted to the viewport: large desktop modals,
-- every action still reachable on smaller screens.
function Style.Fit(panel, width, height)
	Style.Modal(panel)
	panel.AnchorPoint = Vector2.new(0.5, 0.5)
	panel.Position = UDim2.fromScale(0.5, 0.55)
	panel.Size = UDim2.fromOffset(width, height)
	local scale = Instance.new("UIScale")
	scale.Parent = panel
	local function update()
		local camera = workspace.CurrentCamera
		if not camera then return end
		local size = camera.ViewportSize
		local compact = size.X < 650
		local designWidth = compact and 600 or width
		scale.Scale = math.min((size.X - 70) / designWidth, 1.4)
		panel.Size = UDim2.fromOffset(designWidth, (size.Y * .78) / scale.Scale)
		panel:SetAttribute("Compact", compact)
	end
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(update)
	update()
end

-- Original illustrated atlas; nine transparent sprites, loaded as one texture.
Style.Atlas = "rbxassetid://82552057143764"
local cells={DoubleCoins=0,value=0,ExtraCarry=1,INVENTORY=1,carry=1,AutoCollect=2,REWARDS=3,CODE=3,PETS=3,TRAVEL=4,speed=4,INDEX=5,SHOP=6,UPGRADES=7,luck=7,TRADE=8}
function Style.Art(parent,kind,position,size)
	local image=Instance.new("ImageLabel")
	image.Name="Illustration"
	image:SetAttribute("Designed",true)
	image.BackgroundTransparency=1
	image.Position=position
	image.Size=size
	image.Image=Style.Atlas
	local cell=cells[kind] or 7
	image.ImageRectOffset=Vector2.new(math.round((cell%3)*1024/3),math.round(math.floor(cell/3)*1024/3))
	image.ImageRectSize=Vector2.new(341,341)
	image.ScaleType=Enum.ScaleType.Fit
	image.ZIndex=3
	image.Parent=parent
	return image
end
return Style