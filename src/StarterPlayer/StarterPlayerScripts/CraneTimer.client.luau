--[[
	CraneTimer (LocalScript, StarterPlayerScripts) — Junkyard Fusion

	The big countdown in the sky over a coming Crane Drop. ScrapSpawner
	calls one two minutes ahead and sets workspace's CraneDropAt (server
	time) and CraneDropSpot (where the crate lands); this hangs a timer high
	over that spot, on top of its light pillar, big enough to read from
	anywhere on the island, until the crate comes down. Local only.
--]]

local RunService = game:GetService("RunService")

-- Studs above the landing spot: up the light pillar, clear of the crane.
local HEIGHT = 55
-- Its size in studs, so it reads as a sign in the sky rather than a HUD.
local SIZE = UDim2.fromScale(46, 24)
-- The last seconds count down in red.
local HURRY = 15

local GOLD = Color3.fromRGB(255, 205, 40)
local RED = Color3.fromRGB(255, 80, 70)
local INK = Color3.fromRGB(22, 30, 48)

local anchor, timeLabel = nil, nil

local function outline(label, thickness)
	local stroke = Instance.new("UIStroke")
	stroke.Color = INK
	stroke.Thickness = thickness
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	stroke.Parent = label
end

local function text(parent, name, value, position, size, font, color)
	local label = Instance.new("TextLabel")
	label.Name = name
	label.BackgroundTransparency = 1
	label.Position = position
	label.Size = size
	label.Font = font
	label.Text = value
	label.TextColor3 = color
	label.TextScaled = true
	label.Parent = parent
	outline(label, 4)
	return label
end

local function build(spot)
	local part = Instance.new("Part")
	part.Name = "CraneTimer"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Size = Vector3.new(1, 1, 1)
	part.CFrame = CFrame.new(spot + Vector3.new(0, HEIGHT, 0))

	local gui = Instance.new("BillboardGui")
	gui.Size = SIZE
	gui.LightInfluence = 0
	gui.AlwaysOnTop = true
	gui.MaxDistance = 3000
	gui.Adornee = part
	gui.Parent = part

	local back = Instance.new("Frame")
	back.Size = UDim2.fromScale(1, 1)
	back.BackgroundColor3 = INK
	back.BackgroundTransparency = 0.2
	back.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0.12, 0)
	corner.Parent = back
	local rim = Instance.new("UIStroke")
	rim.Color = GOLD
	rim.Thickness = 6
	rim.Parent = back

	text(back, "Title", "CRANE DROP", UDim2.fromScale(0.05, 0.04), UDim2.fromScale(0.9, 0.26), Enum.Font.LuckiestGuy, GOLD)
	timeLabel = text(back, "Time", "2:00", UDim2.fromScale(0.05, 0.28), UDim2.fromScale(0.9, 0.46), Enum.Font.LuckiestGuy,
		Color3.new(1, 1, 1))
	text(back, "Hint", "GET UNDER THE MAGNET!", UDim2.fromScale(0.08, 0.76), UDim2.fromScale(0.84, 0.18), Enum.Font.FredokaOne,
		Color3.new(1, 1, 1))

	part.Parent = workspace
	anchor = part
end

local function clear()
	if anchor then
		anchor:Destroy()
	end
	anchor, timeLabel = nil, nil
end

local function refresh()
	local dropAt = workspace:GetAttribute("CraneDropAt")
	local spot = workspace:GetAttribute("CraneDropSpot")
	if type(dropAt) ~= "number" or typeof(spot) ~= "Vector3" then
		clear()
		return
	end
	if not anchor then
		build(spot)
	end
	anchor.CFrame = CFrame.new(spot + Vector3.new(0, HEIGHT, 0))
end

workspace:GetAttributeChangedSignal("CraneDropAt"):Connect(refresh)
workspace:GetAttributeChangedSignal("CraneDropSpot"):Connect(refresh)
refresh()

RunService.Heartbeat:Connect(function()
	if not timeLabel then return end
	local dropAt = workspace:GetAttribute("CraneDropAt")
	if type(dropAt) ~= "number" then return end
	local left = math.max(0, math.ceil(dropAt - workspace:GetServerTimeNow()))
	local shown = string.format("%d:%02d", left // 60, left % 60)
	if timeLabel.Text ~= shown then
		timeLabel.Text = shown
		timeLabel.TextColor3 = left <= HURRY and RED or Color3.new(1, 1, 1)
	end
end)
