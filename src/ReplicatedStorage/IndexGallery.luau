local Garage=require(script.Parent:WaitForChild("GarageTheme"))
local ItemNames = require(game:GetService("ReplicatedStorage"):WaitForChild("ItemNames"))
-- Open Gallery presentation. Discovery and companion ownership remain server-owned.
local Style = require(script.Parent:WaitForChild("UIStyle"))
local Rarity = require(script.Parent:WaitForChild("ItemRarity"))
local Models = script.Parent:WaitForChild("ItemModels")
local P = Style.Palette
local Gallery = {}
local ORDER = {1, 2, 3, 4, "secret"}
-- These filter by fusion TIER, which is not the same ladder as an item's
-- rarity. Calling tier 1 "Common" was survivable while nothing else on the
-- card showed rarity; now that the disc behind each item is its rarity
-- colour, it filed an epic-purple Box Truck under a tab marked Common.
-- Named for what they actually filter instead.
local NAMES = {"Base", "Tier 2", "Tier 3", "Tier 4"}

-- Addons are junkyard finds, but they are parts you bolt ONTO something
-- rather than things in their own right, so they get their own tab
-- instead of padding out the Junkyard list. Equipping one still reports
-- "junkyard" to the server: the tab is a view, not a new island.
local AREAS = {
	{ key = "junkyard", tab = "JunkyardTab", label = "Junkyard", island = "junkyard" },
	{ key = "brainrot", tab = "BrainrotTab", label = "Brainrot", island = "brainrot" },
	{ key = "addons",   tab = "AddonsTab",   label = "Addons",   island = "junkyard" },
}
local ISLAND_OF = {}
for _, a in ipairs(AREAS) do ISLAND_OF[a.key] = a.island end

local function make(class, parent, name, props)
	local o = Instance.new(class)
	o.Name = name
	o:SetAttribute("Designed", true)
	for k, v in pairs(props or {}) do o[k] = v end
	o.Parent = parent
	return o
end
local function corner(o, r)
	make("UICorner", o, "Corner", {CornerRadius = UDim.new(0, r)})
end
local function caption(parent, name, text, size)
	return make("TextLabel", parent, name, {
		Text = ItemNames.Display(text), Font = Enum.Font.FredokaOne, TextSize = size,
		TextColor3 = P.Ink, BackgroundTransparency = 1, BorderSizePixel = 0,
		TextWrapped = true,
	})
end
local function modelView(parent, name)
	local view = make("ViewportFrame", parent, "Model", {
		BackgroundTransparency = 1, BorderSizePixel = 0,
		Size = UDim2.new(1, -12, 1, -68), Position = UDim2.fromOffset(6, 10),
		Ambient = Color3.fromRGB(205, 205, 215), LightColor = Color3.new(1, 1, 1),
		LightDirection = Vector3.new(-1, -1, -1), ZIndex = 3,
	})
	local template = Models:FindFirstChild(name)
	if not template then return view end
	local world = make("WorldModel", view, "World")
	local clone = template:Clone()
	clone.Parent = world
	local cf, size
	if clone:IsA("BasePart") then
		clone.Anchored = true
		clone.CFrame = CFrame.new()
		cf, size = clone.CFrame, clone.Size
	elseif clone:IsA("Model") then
		clone:PivotTo(CFrame.new())
		for _, p in ipairs(clone:GetDescendants()) do
			if p:IsA("BasePart") then p.Anchored = true end
		end
		cf, size = clone:GetBoundingBox()
	else
		clone:Destroy()
		return view
	end
	Garage.Podium(world, Color3.fromRGB(62,226,223))
	local cam = make("Camera", view, "Camera", {FieldOfView = 35})
	view.CurrentCamera = cam
	local reach = math.max(size.X, size.Y, size.Z) * 1.78 + .2
	cam.CFrame = CFrame.lookAt(cf.Position + Vector3.new(.6, .4, .9) * reach, cf.Position)
	return view
end

function Gallery.Create(gui, onEquip)
	local api = {}
	local activeArea, activeRarity = "junkyard", 1
	local data, companion = {junkyard = {}, brainrot = {}, addons = {}}, nil
	local dimmer = make("Frame", gui, "IndexBackdrop", {
		Size = UDim2.fromScale(1, 1), BackgroundColor3 = Color3.new(),
		BackgroundTransparency = .35, BorderSizePixel = 0, Visible = false,
		ZIndex = 9, Active = true,
	})
	local panel = make("Frame", gui, "IndexPanel", {Visible = false, ClipsDescendants = false})
	corner(panel, 24)
	Style.Surface(panel, P.Cream, 4)
	Style.Modal(panel)
	local scale = make("UIScale", panel, "ResponsiveScale")
	panel.AnchorPoint = Vector2.new(.5, .5)
	panel.Position = UDim2.fromScale(.5, .52)
	local title = caption(panel, "Title", "Item Index", 52)
	title.TextXAlignment = Enum.TextXAlignment.Left
	Style.Outline(title, 52)
	local bookArt = Style.Art(panel, "INDEX", UDim2.fromOffset(16, 10), UDim2.fromOffset(94, 94))
	local close = make("TextButton", panel, "Close")
	Style.Close(close)
	close.Position = UDim2.new(1, -65, 0, 12)
	local areaTabs = {}
	for _, area in ipairs(AREAS) do
		local b = make("TextButton", panel, area.tab, {
			Text = "", AutoButtonColor = false, BorderSizePixel = 0,
		})
		corner(b, 18)
		Style.Surface(b, P.Cream, 2)
		local t = caption(b, "Caption", area.label, 21)
		t.Position, t.Size = UDim2.new(.36, 0, 0, 0), UDim2.new(.64, -6, 1, 0)
		areaTabs[area.key] = b
	end
	local filter = make("Frame", panel, "RarityFilters", {BackgroundTransparency = 1})
	local filters = {}
	for i, key in ipairs(ORDER) do
		local b = make("TextButton", filter, key == "secret" and "Secret" or NAMES[key], {
			Size = UDim2.new(.2, -8, 1, 0), Position = UDim2.new((i-1)*.2, 0, 0, 0),
			Text = key == "secret" and "Secret" or NAMES[key],
			Font = Enum.Font.FredokaOne, TextSize = 19, AutoButtonColor = false,
		})
		corner(b, 14)
		Style.Surface(b, P.Cream, 1.5)
		filters[key] = b
	end
	local search = make("TextBox", panel, "Search", {
		PlaceholderText = "Search discovered...", Text = "", ClearTextOnFocus = false,
		Font = Enum.Font.FredokaOne, TextSize = 19, TextColor3 = P.Ink,
		PlaceholderColor3 = Color3.fromRGB(112, 116, 116),
	})
	corner(search, 16)
	Style.Surface(search, Color3.new(1,1,1), 1.5)
	local count = caption(panel, "DiscoveryCount", "", 23)
	count.TextXAlignment = Enum.TextXAlignment.Left
	local hint = caption(panel, "CompanionHint", "Select a discovered item to equip your companion", 16)
	hint.TextXAlignment = Enum.TextXAlignment.Right
	hint.TextColor3 = Color3.fromRGB(100, 112, 111)
	local scroll = make("ScrollingFrame", panel, "Gallery", {
		BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 6,
		ScrollBarImageColor3 = P.Teal, CanvasSize = UDim2.new(),
		ScrollingDirection = Enum.ScrollingDirection.Y,
	})
	local grid = make("UIGridLayout", scroll, "Grid", {
		CellPadding = UDim2.fromOffset(12, 14), SortOrder = Enum.SortOrder.LayoutOrder,
	})
	local empty = caption(panel, "EmptyResults", "No discovered items match your search.", 24)
	empty.Visible = false
	local function layout()
		local size = gui.AbsoluteSize
		if size.X < 100 or size.Y < 100 then return end
		local portrait = size.X / size.Y < 1
		local width = portrait and 600 or 1200
		local factor = math.min((size.X - 32) / width, 1.5)
		local height = (size.Y - 86) / factor
		panel.Size = UDim2.fromOffset(width, height)
		scale.Scale = factor
		title.Position = UDim2.fromOffset(108, 15)
		title.Size = UDim2.fromOffset(portrait and 390 or 425, 80)
		title.TextSize = portrait and 48 or 52
		close.Size = UDim2.fromOffset(portrait and 76 or 58, portrait and 76 or 58)
		close.Position = UDim2.new(1, portrait and -84 or -65, 0, 12)
		bookArt.Size = UDim2.fromOffset(88, 88)
		-- Three tabs now, so they are narrower and start further left; in
		-- portrait they still have to clear the title on their own row.
		for i, area in ipairs(AREAS) do
			local b = areaTabs[area.key]
			b.Size = UDim2.fromOffset(portrait and 178 or 182, portrait and 82 or 78)
			b.Position = portrait and UDim2.fromOffset(24 + (i-1)*184, 109)
				or UDim2.fromOffset(548 + (i-1)*192, 22)
		end
		-- Every addon is a tier-1 find, so the tier filter would put all four
		-- under "Common" and filter nothing. Drop it on that tab and show the
		-- whole set; in portrait the rows below move up into the space.
		local flatArea = activeArea == "addons"
		filter.Visible = not flatArea
		filter.Position = UDim2.fromOffset(28, portrait and 205 or 118)
		filter.Size = UDim2.new(1, portrait and -48 or -350, 0, portrait and 74 or 44)
		search.Position = portrait and UDim2.fromOffset(28, flatArea and 205 or 292)
			or UDim2.new(1, -312, 0, 118)
		search.Size = portrait and UDim2.new(1, -56, 0, 74) or UDim2.fromOffset(284,44)
		count.Position = UDim2.fromOffset(28, portrait and (flatArea and 291 or 378) or 176)
		count.Size = UDim2.new(1, -56, 0, 36)
		count.TextSize = portrait and 22 or 23
		hint.Position = UDim2.new(1, -510, 0, 179)
		hint.Size = UDim2.fromOffset(482,30)
		hint.Visible = not portrait
		local top = portrait and (flatArea and 337 or 424) or 224
		scroll.Position = UDim2.fromOffset(28, top)
		scroll.Size = UDim2.new(1, -56, 1, -top-20)
		local cols = portrait and 2 or 4
		local cellWidth = (width - 68 - 12*(cols-1))/cols
		grid.CellSize = UDim2.fromOffset(cellWidth, math.max(cellWidth+30, (height-top-34)/2))
		empty.Position, empty.Size = scroll.Position, scroll.Size
	end
	local function updateCanvas()
		scroll.CanvasSize = UDim2.fromOffset(0, grid.AbsoluteContentSize.Y + 8)
	end
	grid:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(updateCanvas)
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(layout)
	-- Studio can report a stale camera viewport while minimized. Use the UI's
	-- own dimensions, and catch parent/safe-area changes after layout settles.
	local lastSize, elapsed = Vector2.zero, 0
	game:GetService("RunService").Heartbeat:Connect(function(dt)
		elapsed += dt
		if elapsed < .2 then return end
		elapsed = 0
		if gui.Parent and gui.AbsoluteSize ~= lastSize then
			lastSize = gui.AbsoluteSize
			layout()
		end
	end)
	local function redraw()
		for _, child in ipairs(scroll:GetChildren()) do
			if child ~= grid then child:Destroy() end
		end
		for area, tab in pairs(areaTabs) do
			local selected = area == activeArea
			Style.Surface(tab, selected and Color3.fromRGB(255,158,27) or Color3.fromRGB(13,148,219), selected and 3 or 1.5)
            Garage.Button(tab)
			-- Use an actual discovered model for each area; never expose an unknown collectible.
			if not tab:FindFirstChild("AreaArt") then
				for _, entry in ipairs(data[area]) do
					if entry.known and Models:FindFirstChild(entry.name) then
						local v = modelView(tab, entry.name)
						v.Name = "AreaArt"
						v.Size, v.Position = UDim2.new(.38,0,1,-6), UDim2.fromOffset(2,3)
						break
					end
				end
			end
		end
		for key, btn in pairs(filters) do
			local rc = Rarity.Color(type(key)=="number" and key or 1, key=="secret")
			-- Was 90% cream, which washed every pill to the same near-white
			-- and made the rarity filters indistinguishable from each other.
			Style.Surface(btn, key==activeRarity and P.Teal or rc:Lerp(P.Cream,.58), key==activeRarity and 3 or 2.5)
			-- Ink on the bright fill, not cream: the selected teal is a
			-- button colour now and cream on it is unreadable.
			btn.TextColor3 = P.Ink
            Garage.Button(btn)
		end
		local flatArea = activeArea == "addons"
		local total, known, shown = 0, 0, 0
		local query = string.lower(search.Text):match("^%s*(.-)%s*$")
		local UNKNOWN_HALO = Color3.fromRGB(226,222,214)
		for i, entry in ipairs(data[activeArea]) do
			local key = entry.isSecret and "secret" or entry.tier
			if flatArea or key == activeRarity then
				total += 1
				if entry.known then known += 1 end
				if query == "" or (entry.known and string.find(string.lower(ItemNames.Display(entry.name)), query, 1, true)) then
					shown += 1
					local selected = companion and companion.name == entry.name
						and companion.island == ISLAND_OF[activeArea]
					local card = make(entry.known and "TextButton" or "Frame", scroll, "Item"..i, {
						BackgroundTransparency = 1, BorderSizePixel = 0, LayoutOrder = i,
					})
					card:SetAttribute("ItemName", entry.known and entry.name or "???")
					card:SetAttribute("Known", entry.known == true)
					corner(card, 16)
					if selected then
						make("UIStroke", card, "CompanionOutline", {Color=P.Teal,Thickness=2.5,ApplyStrokeMode=Enum.ApplyStrokeMode.Border})
					end
					-- The disc behind an item is its RARITY, not a pastel picked
					-- off a rotating list by grid position. The old version gave
					-- the same item a different colour depending on where it
					-- happened to land, so the colour meant nothing; now the
					-- Index reads the same way the inventory and the yard name
					-- tags do, and you can pick a legendary out at a glance.
					local haloRarity = Rarity.Color(entry.tier, entry.isSecret, entry.rarity)
					local halo = make("Frame", card, "PastelBackdrop", {
                        Visible=false,
						Size=UDim2.new(.82,0,.63,0), Position=UDim2.fromScale(.09,.09),
						BackgroundColor3=entry.known and haloRarity:Lerp(P.Cream,.58) or UNKNOWN_HALO,
						BorderSizePixel=0,
					})
					make("UICorner", halo, "Round", {CornerRadius=UDim.new(1,0)})
					-- Lit from above like every other surface in the restyle.
					if entry.known then
						make("UIGradient", halo, "HaloLight", {
							Rotation = 90,
							Color = ColorSequence.new(
								haloRarity:Lerp(P.Cream,.30),
								haloRarity:Lerp(P.Cream,.74)
							),
						})
					end
					if entry.known then
						card.Text = ""
						card.AutoButtonColor = false
						local island = ISLAND_OF[activeArea]
						card.Activated:Connect(function() onEquip(entry.name, island) end)
						modelView(card, entry.name)
					else
						local lock = caption(card,"Undiscovered","?",70)
						lock.Position,lock.Size=UDim2.fromScale(.1,.08),UDim2.new(.8,0,.65,0)
						lock.TextColor3=Color3.fromRGB(151,162,161)
					end
					local name = caption(card,"ItemName",entry.known and ItemNames.Display(entry.name) or "Undiscovered",21)
                    Garage.Plate(name)
					name.Size,name.Position=UDim2.new(1,-12,0,46),UDim2.new(0,6,1,-62)
					name.TextScaled=true
					make("UITextSizeConstraint",name,"NameLimit",{MinTextSize=12,MaxTextSize=21})
					local status=caption(card,"Status",selected and "COMPANION" or entry.known and "✓ Discovered" or "Keep exploring",13)
					status.Size,status.Position=UDim2.new(1,-12,0,18),UDim2.new(0,6,1,-18)
					status.TextColor3=entry.known and P.TealDeep or Color3.fromRGB(122,112,99)
				end
			end
		end
		count.Text=string.format("%s  •  %d / %d discovered",
			flatArea and "Addons" or activeRarity=="secret" and "Secret" or NAMES[activeRarity],known,total)
		empty.Text=query~="" and "No discovered items match your search."
			or flatArea and "No addons found yet." or "No items in this rarity yet."
		empty.Visible=shown==0
		updateCanvas()
	end
	for area, tab in pairs(areaTabs) do
		-- layout() before redraw(): the Addons tab hides the rarity filter,
		-- which moves everything under it.
		tab.Activated:Connect(function()
			activeArea=area scroll.CanvasPosition=Vector2.zero layout() redraw()
		end)
	end
	for key, btn in pairs(filters) do
		btn.Activated:Connect(function() activeRarity=key scroll.CanvasPosition=Vector2.zero redraw() end)
	end
	search:GetPropertyChangedSignal("Text"):Connect(function() scroll.CanvasPosition=Vector2.zero redraw() end)
	panel:GetPropertyChangedSignal("Visible"):Connect(function() dimmer.Visible=panel.Visible end)
	function api.Toggle() panel.Visible=not panel.Visible end
	function api.Update(nextData, nextCompanion) data=nextData companion=nextCompanion redraw() end
	close.Activated:Connect(api.Toggle)
	layout()
	redraw()
	Garage.Shell(panel) Garage.Header(title)
	return api
end
return Gallery