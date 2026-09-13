--[[
	NavButton (ModuleScript, ReplicatedStorage) — Junkyard Fusion v1

	The shared "chunky cartoon button" look for every main HUD nav trigger:
	a solid drop-shadow block sits behind the button, which visibly pops up
	off it at rest and pushes flush into it on click — the classic
	mobile-game satisfying-button feel — plus a quick icon wiggle on hover
	so the rail feels alive before anything is even clicked.

	Two independent LocalScripts (GameUI and GamepassUI) each build main
	nav buttons, so this lives here instead of being copy-pasted twice —
	that duplication was fine for a plain hover/press tween, but not once
	the animation grew a shadow layer, a lift, and a wiggle.
--]]

local TweenService = game:GetService("TweenService")

local NavButton = {}

NavButton.SIZE = 120
NavButton.GAP = 20

local DEPTH = 10
local RAIL_COUNT = 3
local RAIL_HEIGHT = RAIL_COUNT * NavButton.SIZE + (RAIL_COUNT - 1) * NavButton.GAP

-- Three tiles per side, vertically centered as one group.
function NavButton.RailPosition(side, slot)
	local yOffset = (slot - 1) * (NavButton.SIZE + NavButton.GAP) - RAIL_HEIGHT / 2
	if side == "left" then
		return UDim2.new(0, 20, 0.5, yOffset)
	end
	return UDim2.new(1, -20 - NavButton.SIZE, 0.5, yOffset)
end

local function rounded(instance, radius)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = instance
end

-- One-shot tilt-tilt-settle, not a loop — fires again every time the mouse
-- re-enters, which reads as "alive" without ever fighting the hover/press
-- tweens for control of the same property.
local function wiggle(target)
	TweenService:Create(target, TweenInfo.new(0.08), { Rotation = -12 }):Play()
	task.delay(0.08, function()
		if target.Parent then
			TweenService:Create(target, TweenInfo.new(0.08), { Rotation = 10 }):Play()
			task.delay(0.08, function()
				if target.Parent then
					TweenService:Create(target, TweenInfo.new(0.1), { Rotation = 0 }):Play()
				end
			end)
		end
	end)
end

-- Returns btn, iconLabel, captionLabel, stroke, gradient — the last two so
-- a caller that needs to re-theme the button later (Daily Rewards lights
-- up green when a reward's ready) can reach in without rebuilding it.
function NavButton.Create(gui, icon, caption, accentColor, position)
	local SIZE = NavButton.SIZE
	local restPosition = position
	local liftPosition = position - UDim2.new(0, 0, 0, 6)
	local pressedPosition = position + UDim2.new(0, 0, 0, DEPTH)

	-- The solid block peeking out from behind/below — this is what makes
	-- the button read as a raised, pressable 3D object instead of a flat
	-- rectangle with a color on it.
	local shadow = Instance.new("Frame")
	shadow.Size = UDim2.new(0, SIZE, 0, SIZE)
	shadow.Position = pressedPosition
	shadow.BackgroundColor3 = accentColor:Lerp(Color3.new(0, 0, 0), 0.72)
	shadow.BorderSizePixel = 0
	shadow.ZIndex = 1
	shadow.Parent = gui
	rounded(shadow, 26)

	local btn = Instance.new("TextButton")
	btn.Size = UDim2.new(0, SIZE, 0, SIZE)
	btn.Position = restPosition
	btn.ZIndex = 2
	btn.BackgroundColor3 = accentColor:Lerp(Color3.new(0, 0, 0), 0.68)
	btn.Text = ""
	btn.AutoButtonColor = false
	btn.BorderSizePixel = 0
	btn.Parent = gui
	rounded(btn, 26)

	local gradient = Instance.new("UIGradient")
	gradient.Color = ColorSequence.new({
		ColorSequenceKeypoint.new(0, accentColor:Lerp(Color3.new(1, 1, 1), 0.2)),
		ColorSequenceKeypoint.new(1, accentColor:Lerp(Color3.new(0, 0, 0), 0.45)),
	})
	gradient.Rotation = 90
	gradient.Parent = btn

	-- White, not the accent color — a thick white outline is what makes
	-- this read as a cartoon sticker/app-icon rather than a UI chip.
	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.fromRGB(255, 255, 255)
	stroke.Thickness = 3
	stroke.Transparency = 0.5
	stroke.Parent = btn

	-- The ScreenGui these mount into runs ZIndexBehavior.Global, where a
	-- child's default ZIndex (1) does NOT automatically win over its own
	-- parent the way it would under the default Sibling behavior — btn
	-- sits at ZIndex 2 (to clear the shadow behind it), so anything drawn
	-- on top of btn needs a higher ZIndex explicitly, or btn's own opaque
	-- background paints right over it.
	local iconLabel = Instance.new("TextLabel")
	iconLabel.Size = UDim2.new(1, 0, 0, 60)
	iconLabel.Position = UDim2.new(0, 0, 0, 8)
	iconLabel.BackgroundTransparency = 1
	iconLabel.Text = icon
	iconLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	iconLabel.Font = Enum.Font.FredokaOne
	iconLabel.TextSize = 48
	iconLabel.TextXAlignment = Enum.TextXAlignment.Center
	iconLabel.ZIndex = 3
	iconLabel.Parent = btn

	local captionLabel = Instance.new("TextLabel")
	captionLabel.Size = UDim2.new(1, -8, 0, 22)
	captionLabel.Position = UDim2.new(0, 4, 0, 76)
	captionLabel.BackgroundTransparency = 1
	captionLabel.Text = caption
	captionLabel.TextColor3 = Color3.fromRGB(255, 255, 255)
	captionLabel.Font = Enum.Font.FredokaOne
	captionLabel.TextSize = 15
	captionLabel.TextScaled = true
	captionLabel.TextXAlignment = Enum.TextXAlignment.Center
	captionLabel.ZIndex = 3
	captionLabel.Parent = btn

	local hovering = false

	btn.MouseEnter:Connect(function()
		hovering = true
		TweenService:Create(btn, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Size = UDim2.new(0, SIZE + 10, 0, SIZE + 10),
			Position = liftPosition,
		}):Play()
		TweenService:Create(stroke, TweenInfo.new(0.18), { Thickness = 4, Transparency = 0.1 }):Play()
		wiggle(iconLabel)
	end)

	btn.MouseLeave:Connect(function()
		hovering = false
		TweenService:Create(btn, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
			Size = UDim2.new(0, SIZE, 0, SIZE),
			Position = restPosition,
		}):Play()
		TweenService:Create(stroke, TweenInfo.new(0.18), { Thickness = 3, Transparency = 0.5 }):Play()
	end)

	btn.MouseButton1Down:Connect(function()
		TweenService:Create(btn, TweenInfo.new(0.05), {
			Size = UDim2.new(0, SIZE - 4, 0, SIZE - 4),
			Position = pressedPosition,
		}):Play()
	end)

	-- Elastic on the way back up — a little overshoot-and-settle "boing"
	-- reads as much livelier than easing straight back to rest.
	btn.MouseButton1Up:Connect(function()
		local size = hovering and UDim2.new(0, SIZE + 10, 0, SIZE + 10) or UDim2.new(0, SIZE, 0, SIZE)
		local pos = hovering and liftPosition or restPosition
		TweenService:Create(btn, TweenInfo.new(0.35, Enum.EasingStyle.Elastic, Enum.EasingDirection.Out), {
			Size = size,
			Position = pos,
		}):Play()
	end)

	return btn, iconLabel, captionLabel, stroke, gradient
end

return NavButton
