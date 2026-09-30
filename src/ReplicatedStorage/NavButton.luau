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
	local function fit()
		-- On a phone on its side each rail becomes a two-by-two grid in its
		-- top corner: twice the size a single column could be on a screen
		-- that short, and clear of the thumbstick (bottom left) and the jump
		-- button (bottom right).
		local sg = holder:FindFirstAncestorOfClass("ScreenGui")
		local gui = sg and sg.AbsoluteSize
		if gui and gui.Y > 100 and gui.Y < 480 then
			local factor = math.clamp(gui.Y / 610, 0.48, 0.62)
			local w, h = 140 * factor, 156 * factor
			local col, row = slot % 2, slot // 2
			local x = 8 + col * (w + 2)
			scale.Scale = factor
			holder.Position = right and UDim2.new(1, -8 - (1 - col) * (w + 2) - w, 0, 4 + row * h)
				or UDim2.new(0, x, 0, 4 + row * h)
			return
		end
		-- On a computer both rails share one size, as big as fits: the
		-- left rail between the top bar and the coin counter (bottom left),
		-- the right one under the player list. Up to 1.3x (was 1.1x).
		local size = workspace.CurrentCamera.ViewportSize
		local leftTop, rightTop = 110, 260
		if size.Y < 650 then leftTop, rightTop = 90, 90 end
		local top = right and rightTop or leftTop
		local fitLeft = (size.Y - 150 - leftTop) / 616
		local fitRight = (size.Y - 20 - rightTop) / 616
		local factor = math.clamp(math.min(fitLeft, fitRight), .3, 1.3)
		scale.Scale = factor
		holder.Position = UDim2.new(right and 1 or 0, right and (-16-140*factor) or 16, 0, top+slot*156*factor)
	end
	workspace.CurrentCamera:GetPropertyChangedSignal("ViewportSize"):Connect(fit)
	gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fit)
	fit()
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
	local art = Style.Art(btn,caption,UDim2.fromOffset(2,0),UDim2.new(1,-4,0,118))
	local iconLabel = Instance.new("TextLabel")
	iconLabel.Text = icon
	iconLabel.Visible = false
	iconLabel.Parent = btn
	local label = Instance.new("TextLabel")
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