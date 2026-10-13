--[[
	BoltShop (ModuleScript, ServerStorage) — Junkyard Fusion

	The stall in the Race Wars lobby where the shop addons are sold for
	bolts (FusionRecipes.AddonBoltPrice; the bolts are won racing), the
	Phantom Garage's twin on the other side of the line-up box. The user
	asked (2026-10-13) for it to be run by their own avatar, seen by
	everyone: the shopkeeper is the game owner's Roblox avatar, loaded here
	on the server, standing behind the counter. A plain stand-in shows until
	(or if never) it loads.

	A garage market stall in the user's colours (bright green, red, white,
	dark grey): a striped awning, a big hex bolt on the back wall, real
	addon models on the counter, a "BOLT SHOP" sign. Its "Bolt Shop" prompt
	is on the Counter; BoltShop.client opens the shop from it, and
	PlotManager's BuyBoltAddon checks the buyer is standing near the
	Counter.

	Built by MapBootstrap, from scratch every time. Where it stands is
	RaceTrack's (Track.BoltShopFrame).
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local Track = require(ServerStorage:WaitForChild("RaceTrack"))

local Shop = {}

local GREEN = Color3.fromRGB(96, 214, 72)
local RED = Color3.fromRGB(214, 44, 44)
local WHITE = Color3.fromRGB(245, 245, 240)
local DARK = Color3.fromRGB(40, 42, 48)
local STEEL = Color3.fromRGB(176, 186, 196)

-- Roblox's own R15 idle, so the owner stands and breathes (as the base
-- mechanics do, MechanicService).
local IDLE = "rbxassetid://507766666"

local function part(parent, name, size, cf, color, material)
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material or Enum.Material.SmoothPlastic
	p.Anchored = true
	p.CanTouch = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function signText(board, face, text, color, stroke, font)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.CanvasSize = Vector2.new(560, 120)
	gui.LightInfluence = 0
	gui.Parent = board
	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.Font = font or Enum.Font.LuckiestGuy
	label.TextScaled = true
	label.TextColor3 = color
	label.Text = text
	label.Parent = gui
	local outline = Instance.new("UIStroke")
	outline.Color = stroke
	outline.Thickness = 4
	outline.Parent = label
	return gui
end

-- A hex bolt head, face on: three boxes turned 60 degrees apart make the
-- hexagon, with a washer behind and a slot of shade across the middle.
local function hexBolt(parent, cf, across)
	local side = across / math.sqrt(3)
	for i = 0, 2 do
		part(parent, "BoltHead", Vector3.new(side, across, 1), cf * CFrame.Angles(0, 0, math.rad(60 * i)), STEEL, Enum.Material.Metal)
	end
	local washer = part(parent, "BoltWasher", Vector3.new(0.4, across * 1.3, across * 1.3), cf * CFrame.new(0, 0, 0.55) * CFrame.Angles(0, math.pi / 2, 0), DARK, Enum.Material.Metal)
	washer.Shape = Enum.PartType.Cylinder
	part(parent, "BoltShade", Vector3.new(across * 0.12, across * 0.6, 1.05), cf, Color3.fromRGB(120, 130, 140), Enum.Material.Metal)
end

-- The game's owner, whose avatar runs the shop: the place's owning user,
-- else jace_343 (the owner, as in AdminConfig) if a group ever owns it.
local function ownerId()
	if game.CreatorType == Enum.CreatorType.User and game.CreatorId > 0 then
		return game.CreatorId
	end
	return 155083524
end

-- The owner's avatar behind the counter, `base` the spot they stand on.
local function placeOwner(model, base, stock)
	local userId = ownerId()
	local ok, rig = pcall(function()
		return Players:CreateHumanoidModelFromDescription(Players:GetHumanoidDescriptionFromUserId(userId), Enum.HumanoidRigType.R15)
	end)
	if not ok or not rig or not model.Parent then
		if ok and rig then rig:Destroy() end
		return
	end
	local humanoid = rig:FindFirstChildOfClass("Humanoid")
	local root = rig:FindFirstChild("HumanoidRootPart")
	if not (humanoid and root) then rig:Destroy() return end
	rig.Name = "Shopkeeper"
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	for _, d in ipairs(rig:GetDescendants()) do
		if d:IsA("BasePart") then
			d.Anchored = false
			d.CanCollide = false
			d.CanTouch = false
			d.CanQuery = false
		end
	end
	root.Anchored = true
	rig:PivotTo(base * CFrame.new(0, humanoid.HipHeight + root.Size.Y / 2, 0))
	rig.Parent = model
	stock:Destroy()
	local animator = humanoid:FindFirstChildOfClass("Animator") or Instance.new("Animator", humanoid)
	local idle = Instance.new("Animation")
	idle.AnimationId = IDLE
	pcall(function()
		local track = animator:LoadAnimation(idle)
		track.Looped = true
		track:Play()
	end)
	-- The owner's name over them, whoever they are.
	local nameOk, name = pcall(Players.GetNameFromUserIdAsync, Players, userId)
	local tag = model:FindFirstChild("OwnerTag", true)
	if tag and nameOk then
		tag.Who.Text = name
	end
end

function Shop.Build()
	local old = workspace:FindFirstChild("BoltShop")
	if old then old:Destroy() end
	local model = Instance.new("Model")
	model.Name = "BoltShop"
	-- On everyone's screen all the time, so the client can find its prompt.
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent

	local base = Track.BoltShopFrame()

	-- The stall: a floor, three walls and a striped awning, open at the front.
	part(model, "Floor", Vector3.new(18, 0.6, 12), base * CFrame.new(0, 0.3, 0), DARK, Enum.Material.DiamondPlate)
	part(model, "BackWall", Vector3.new(18, 12, 0.8), base * CFrame.new(0, 6, 5.6), DARK, Enum.Material.Metal)
	for _, x in ipairs({ -8.6, 8.6 }) do
		part(model, "SideWall", Vector3.new(0.8, 12, 12), base * CFrame.new(x, 6, 0), RED, Enum.Material.SmoothPlastic)
		part(model, "SideStripe", Vector3.new(0.9, 0.8, 12.1), base * CFrame.new(x, 8.5, 0), WHITE)
	end
	-- Awning: green and white stripes, tipped down toward the front.
	for i = 0, 8 do
		local x = -9 + (i + 0.5) * 2
		part(model, "Awning", Vector3.new(2, 0.4, 9), base * CFrame.new(x, 12.4, -2.2) * CFrame.Angles(math.rad(14), 0, 0),
			i % 2 == 0 and GREEN or WHITE)
	end
	part(model, "Roof", Vector3.new(19, 0.8, 8), base * CFrame.new(0, 12.6, 3), DARK, Enum.Material.Metal)
	-- Green light strips round the opening.
	part(model, "TrimTop", Vector3.new(18.4, 0.4, 0.4), base * CFrame.new(0, 11, -5.8), GREEN, Enum.Material.Neon)
	for _, x in ipairs({ -9, 9 }) do
		part(model, "TrimSide", Vector3.new(0.4, 10.6, 0.4), base * CFrame.new(x, 5.6, -5.8), GREEN, Enum.Material.Neon)
	end

	-- A big hex bolt on the back wall, the shop's emblem.
	-- (Face on to the customers: the stall's front is its -Z.)
	hexBolt(model, base * CFrame.new(-5, 7.6, 4.65), 3.6)
	hexBolt(model, base * CFrame.new(5, 7.6, 4.65), 3.6)

	-- The counter, with the prompt.
	local counter = part(model, "Counter", Vector3.new(12, 3.4, 2.4), base * CFrame.new(0, 2.3, -3.4), RED)
	part(model, "CounterTop", Vector3.new(12.6, 0.3, 3), base * CFrame.new(0, 4.1, -3.4), WHITE, Enum.Material.Marble)
	part(model, "CounterStripe", Vector3.new(12.1, 0.5, 2.45), base * CFrame.new(0, 3.2, -3.4), WHITE)

	-- Real addons on show at the ends of the counter (the middle is kept
	-- clear: the shopkeeper stands behind it).
	local ItemVisuals = require(ReplicatedStorage:WaitForChild("ItemVisuals"))
	for _, show in ipairs({ { "Twin Turbo", 4.4 }, { "Jet Engine", -4.4 } }) do
		local ok, shown = pcall(ItemVisuals.CloneForViewport, show[1])
		if ok and shown then
			local _, size = shown:GetBoundingBox()
			shown:ScaleTo(shown:GetScale() * (2.2 / math.max(size.X, size.Y, size.Z)))
			local _, scaled = shown:GetBoundingBox()
			shown:PivotTo(base * CFrame.new(show[2], 4.25 + scaled.Y / 2, -3.4) * CFrame.Angles(0, math.rad(200), 0))
			shown.Name = "OnShow"
			shown.Parent = model
		end
	end

	-- The shopkeeper stands on a step behind the counter, so even a short
	-- avatar shows over it: a plain stand-in until the owner's avatar loads.
	part(model, "Step", Vector3.new(6, 1.4, 3), base * CFrame.new(0, 1.3, 0.8), DARK, Enum.Material.DiamondPlate)
	local spot = base * CFrame.new(0, 2, 0.8)
	local stock = Instance.new("Model")
	stock.Name = "StockShopkeeper"
	stock.Parent = model
	local body = part(stock, "Body", Vector3.new(2, 3, 1), spot * CFrame.new(0, 3, 0), RED)
	body.CanCollide = false
	local head = part(stock, "Head", Vector3.new(1.2, 1.2, 1.2), spot * CFrame.new(0, 5.2, 0), Color3.fromRGB(234, 184, 146))
	head.Shape = Enum.PartType.Ball
	head.CanCollide = false

	-- Their name over them, and what they do.
	local tag = Instance.new("BillboardGui")
	tag.Name = "OwnerTag"
	tag.Size = UDim2.fromOffset(240, 64)
	tag.StudsOffsetWorldSpace = Vector3.new(0, 7.4, 0)
	tag.AlwaysOnTop = true
	tag.MaxDistance = 70
	tag.Adornee = counter
	tag.Parent = counter
	local who = Instance.new("TextLabel")
	who.Name = "Who"
	who.Size = UDim2.fromScale(1, 0.58)
	who.BackgroundTransparency = 1
	who.Text = "THE OWNER"
	who.TextColor3 = WHITE
	who.TextStrokeTransparency = 0.2
	who.TextScaled = true
	who.Font = Enum.Font.FredokaOne
	who.Parent = tag
	local role = Instance.new("TextLabel")
	role.Name = "Role"
	role.Position = UDim2.fromScale(0, 0.58)
	role.Size = UDim2.fromScale(1, 0.42)
	role.BackgroundTransparency = 1
	role.Text = "SHOP OWNER"
	role.TextColor3 = GREEN
	role.TextStrokeTransparency = 0.2
	role.TextScaled = true
	role.Font = Enum.Font.FredokaOne
	role.Parent = tag

	-- The sign over the opening, readable from the front.
	local board = part(model, "SignBoard", Vector3.new(16, 3, 0.5), base * CFrame.new(0, 14.6, -6.6), DARK)
	signText(board, Enum.NormalId.Front, "BOLT SHOP", WHITE, RED)
	part(model, "SignRim", Vector3.new(16.6, 3.6, 0.3), base * CFrame.new(0, 14.6, -6.3), RED)
	local sub = part(model, "SubSign", Vector3.new(10, 1.2, 0.3), base * CFrame.new(0, 13.2, -7.2), RED)
	sub.CanCollide = false
	signText(sub, Enum.NormalId.Front, "Addons for bolts", WHITE, DARK, Enum.Font.FredokaOne)

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "OpenBoltShop"
	prompt.ActionText = "Bolt Shop"
	prompt.ObjectText = "Addons for your bolts"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 14
	prompt.RequiresLineOfSight = false
	prompt.Parent = counter

	model.Parent = workspace
	-- The owner's avatar takes a web request or two: not on the way in.
	task.spawn(placeOwner, model, spot, stock)
	return model
end

return Shop
