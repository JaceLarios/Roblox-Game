-- Shared white illustration tiles. Return values preserve Rewards integration.
local TweenService = game:GetService("TweenService")
local Style = require(script.Parent:WaitForChild("UIStyle"))
local NavButton = { SIZE = 120, GAP = 20 }
function NavButton.RailPosition(side, slot)
	return UDim2.new(side == "left" and 0 or 1, side == "left" and 20 or -140, .5, (slot-1)*140-270)
end
function NavButton.ReadableTextColor()
	return Color3.fromRGB(20,23,30)
end
-- How many buttons each rail holds (its highest slot), and every button's
-- fit, so a rail growing refits the buttons already on screen.
local railRows = { left = 0, right = 0 }
local fits = {}
function NavButton.Create(gui, icon, caption, accentColor, position)
	local holder = Instance.new("Frame")
	holder.Name = caption .. "Navigation"
	holder.BackgroundTransparency = 1
	holder.Size = UDim2.fromOffset(140,148)
	holder.ZIndex = 2
	holder.Parent = gui
	Style.Navigation(holder)
	local scale = Instance.new("UIScale")
	scale.Parent = holder
	local slot = math.round((position.Y.Offset+270)/140)
	local right = position.X.Scale == 1
	local side = right and "right" or "left"
	railRows[side] = math.max(railRows[side], slot + 1)
	local art, label
	local function fit()
		local bounds = gui.AbsoluteSize
		local mobile = bounds.Y > 100 and (bounds.Y < 480 or bounds.X < 600)
		if mobile then
			-- Four separate buttons per side, above the movement controls.
			-- Use pixel-sized labels rather than shrinking their text with the art.
			local top = bounds.Y < 480 and 4 or 110
			local bottom = math.clamp(bounds.Y * .28, 88, 190)
			local height = math.clamp(math.floor((bounds.Y - top - bottom - 12) / 4), 32, 58)
			scale.Scale = 1
			holder.Size = UDim2.fromOffset(70, height)
			holder.Position = UDim2.new(right and 1 or 0, right and -76 or 6, 0, top + slot * (height + 4))
			if art then
				local edge = height - 13
				art.Position = UDim2.fromOffset((70 - edge) / 2, 0)
				art.Size = UDim2.fromOffset(edge, edge)
				label.Size = UDim2.new(1, -2, 0, 14)
				label.Position = UDim2.new(0, 1, 1, -14)
				label.TextSize = 11
			end
			return
		end
		holder.Size = UDim2.fromOffset(140, 148)
		if art then
			art.Position = UDim2.fromOffset(2, 0)
			art.Size = UDim2.new(1, -4, 0, 118)
			label.Size = UDim2.new(1, -8, 0, 28)
			label.Position = UDim2.new(0, 4, 1, -34)
			label.TextSize = 22
		end
		-- On a computer both rails share one size, as big as fits: the
		-- left rail between the top bar and the coin counter (bottom left),
		-- the right one under the player list, each by how many buttons it
		-- holds. Up to 1.3x (was 1.1x). Measured in this ScreenGui, below
		-- Roblox's top bar: it used the whole window, top bar included, so
		-- on a 16:10 laptop (a MacBook) the right rail ran off the bottom
		-- and QUESTS sat on the coin counter.
		local size = bounds
		local leftTop, rightTop = 110, 260
		if size.Y < 650 then leftTop, rightTop = 90, 90 end
		local top = right and rightTop or leftTop
		local function railHeight(rows) return 148 + (math.max(rows, 1) - 1) * 156 end
		-- The coin card's top (with its art) is about 210 above the bottom:
		-- the bolts sit under the coins.
		local fitLeft = (size.Y - 224 - leftTop) / railHeight(railRows.left)
		local fitRight = (size.Y - 28 - rightTop) / railHeight(railRows.right)
		local factor = math.clamp(math.min(fitLeft, fitRight), .3, 1.3)
		scale.Scale = factor
		holder.Position = UDim2.new(right and 1 or 0, right and (-16-140*factor) or 16, 0, top+slot*156*factor)
	end
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	table.insert(fits, fit)
	for _, refit in ipairs(fits) do refit() end
	local btn = Instance.new("TextButton")
	btn.Name = caption
	btn.Size = UDim2.fromScale(1,1)
	btn.Text = ""
	btn.AutoButtonColor = false
	btn.ZIndex = 2
	btn.Parent = holder
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0,20)
	corner.Parent = btn
	btn.BackgroundTransparency = 1
	btn:SetAttribute("Designed",true)
	-- Surface() is still called for the stroke object and the hover hooks
	-- below, but the rail is deliberately UNPLATED: the icons float clean
	-- over the world with no tile and no border behind them. Tried plating
	-- them for the enamel restyle and it boxed in a HUD that reads better
	-- open, so everything Surface paints is switched straight back off.
	Style.Surface(btn)
	btn.BackgroundTransparency = 1
	local stroke = btn:FindFirstChildOfClass("UIStroke")
	stroke.Thickness = 0
	local surface = btn:FindFirstChild("SurfaceGradient")
	if surface then surface.Enabled = false end
	local gradient = Instance.new("UIGradient")
	gradient.Enabled = false
	gradient.Parent = btn
	art = Style.Art(btn,caption,UDim2.fromOffset(2,0),UDim2.new(1,-4,0,118))
	local iconLabel = Instance.new("TextLabel")
	iconLabel.Text = icon
	iconLabel.Visible = false
	iconLabel.Parent = btn
	label = Instance.new("TextLabel")
	label.Name = "Caption"
	label.BackgroundTransparency = 1
	label.Size = UDim2.new(1,-8,0,28)
	label.Position = UDim2.new(0,4,1,-34)
	label.Text = caption
	label.TextColor3 = NavButton.ReadableTextColor()
	label.Font = Enum.Font.FredokaOne
	label.TextSize = 19
	label.ZIndex = 3
	label.Parent = btn
	Style.Outline(label,22)
	fit()
	btn.MouseEnter:Connect(function()
		TweenService:Create(art,TweenInfo.new(.15),{Rotation=-5}):Play()
		stroke.Thickness=0
	end)
	btn.MouseLeave:Connect(function()
		TweenService:Create(art,TweenInfo.new(.15),{Rotation=0}):Play()
		stroke.Thickness=0
	end)
	btn.MouseButton1Down:Connect(function() btn.Position=UDim2.fromOffset(0,3) end)
	btn.MouseButton1Up:Connect(function() btn.Position=UDim2.fromOffset(0,0) end)
	return btn,iconLabel,label,stroke,gradient
end
return NavButton