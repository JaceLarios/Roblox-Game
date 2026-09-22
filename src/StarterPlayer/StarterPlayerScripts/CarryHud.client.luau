--[[
	CarryHud (LocalScript, StarterPlayerScripts) — Junkyard Fusion v1

	The "you are holding loot, RUN" overlay: a red banner across the top of
	the screen, and a trail of red flashing arrows on the ground showing the
	way back to your own base. Both appear the moment you pick something up
	and vanish the moment you deliver it, die, or get it knocked out of you.

	Deliberately its own script rather than another section of
	GameUI.client.luau — the same isolation pattern PetsUI and ShopUI use —
	and it is purely reactive to fields the existing GameUpdate payload
	already carries (carrying, baseCentre, carryFrom).

	The arrows are built on the CLIENT. They cost the server nothing, they
	replicate to nobody, and only the player actually being hunted sees
	their own route home.

	This is also where the hotbar gets hidden while carrying: the rule is
	"your only job is to get home", so the bat and speed coil are out of
	reach until you have delivered.
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local StarterGui = game:GetService("StarterGui")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local updateRemote = ReplicatedStorage:WaitForChild("GameUpdate")

local RED = Color3.fromRGB(255, 40, 40)

-- Plots sit on a ring of this radius around the yard, each a square this
-- wide; the same two numbers PlotManager and MapRevamp use to lay roads.
local RING_RADIUS = 190
local PLOT_HALF = 35
-- Where a trail starts: just inside the yard, in front of the gate, so it
-- leads you INTO the road rather than starting halfway down it.
local TRAIL_START = 76
local ARROWS_PER_ROAD = 10

-- One arrow: a shaft and a filled head, laid flat on the road.
local SHAFT_LENGTH, SHAFT_WIDTH = 4, 2.4
local HEAD_LENGTH, HEAD_WIDTH = 4.5, 7
local THICKNESS = 0.3

-- The flash runs along the trail toward home, so the trail reads as
-- moving in the direction you need to go rather than just blinking.
local CHASE_SPEED = 9       -- arrows per second the light travels
local CHASE_LENGTH = 3      -- how many arrows are lit at once
local LIT, DIM = 0.02, 0.78 -- transparency at the head of the chase vs at rest

------------------------------------------------------------------
-- Banner
------------------------------------------------------------------

local gui = Instance.new("ScreenGui")
gui.Name = "CarryHud"
gui.ResetOnSpawn = false
gui.IgnoreGuiInset = true
gui.DisplayOrder = 20
gui.Enabled = false
gui.Parent = playerGui

local banner = Instance.new("TextLabel")
banner.Name = "RunBanner"
banner.AnchorPoint = Vector2.new(0.5, 0)
banner.Size = UDim2.fromOffset(360, 96)
banner.Position = UDim2.new(0.5, 0, 0, 14)
banner.BackgroundTransparency = 1
banner.Text = "RUN"
banner.TextColor3 = RED
banner.Font = Enum.Font.LuckiestGuy
banner.TextSize = 80
banner.TextStrokeColor3 = Color3.new(0, 0, 0)
banner.TextStrokeTransparency = 0
banner:SetAttribute("Designed", true)
banner.Parent = gui

local subtitle = Instance.new("TextLabel")
subtitle.AnchorPoint = Vector2.new(0.5, 0)
subtitle.Size = UDim2.fromOffset(420, 26)
subtitle.Position = UDim2.new(0.5, 0, 0, 104)
subtitle.BackgroundTransparency = 1
subtitle.Text = "Get it back to your base!"
subtitle.TextColor3 = Color3.fromRGB(255, 225, 225)
subtitle.Font = Enum.Font.FredokaOne
subtitle.TextSize = 20
subtitle.TextStrokeColor3 = Color3.new(0, 0, 0)
subtitle.TextStrokeTransparency = 0.2
subtitle:SetAttribute("Designed", true)
subtitle.Parent = gui

------------------------------------------------------------------
-- Ground arrows
------------------------------------------------------------------

local arrowFolder = nil
-- Arrows in the order the light should travel, each a list of its parts.
local trail = {}

local function clearArrows()
	if arrowFolder then
		arrowFolder:Destroy()
		arrowFolder = nil
	end
	trail = {}
end

local function newPart(className)
	local p = Instance.new(className)
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	p.Material = Enum.Material.Neon
	p.Color = RED
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = arrowFolder
	return p
end

-- A filled triangle out of two WedgeParts. A single wedge will NOT do:
-- its triangular faces are on its sides, so seen from above it is a plain
-- rectangle — which is exactly why the old arrows read as squares.
local function triangle(a, b, c, parts)
	local ab, ac, bc = b - a, c - a, c - b
	local abd, acd, bcd = ab:Dot(ab), ac:Dot(ac), bc:Dot(bc)
	if abd > acd and abd > bcd then
		c, a = a, c
	elseif acd > bcd and acd > abd then
		a, b = b, a
	end
	ab, ac, bc = b - a, c - a, c - b
	local right = ac:Cross(ab).Unit
	local up = bc:Cross(right).Unit
	local back = bc.Unit
	local height = math.abs(ab:Dot(up))

	local w1 = newPart("WedgePart")
	w1.Size = Vector3.new(THICKNESS, height, math.abs(ab:Dot(back)))
	w1.CFrame = CFrame.fromMatrix((a + b) / 2, right, up, back)
	local w2 = newPart("WedgePart")
	w2.Size = Vector3.new(THICKNESS, height, math.abs(ac:Dot(back)))
	w2.CFrame = CFrame.fromMatrix((a + c) / 2, -right, up, -back)
	table.insert(parts, w1)
	table.insert(parts, w2)
end

local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Exclude

-- Sit each arrow on whatever the road actually is at that spot. The plots
-- folder is skipped so an arrow never perches on top of a laser bar.
local function groundY(x, z)
	local ignore = { arrowFolder }
	local plots = workspace:FindFirstChild("Plots")
	if plots then table.insert(ignore, plots) end
	local scrap = workspace:FindFirstChild("Scrap")
	if scrap then table.insert(ignore, scrap) end
	for _, other in ipairs(Players:GetPlayers()) do
		if other.Character then table.insert(ignore, other.Character) end
	end
	groundParams.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(Vector3.new(x, 40, z), Vector3.new(0, -80, 0), groundParams)
	return hit and hit.Position.Y or 1.2
end

local function addArrow(pos, dir)
	dir = Vector3.new(dir.X, 0, dir.Z).Unit
	local side = Vector3.new(-dir.Z, 0, dir.X)
	local y = groundY(pos.X, pos.Z) + THICKNESS / 2 + 0.06
	local centre = Vector3.new(pos.X, y, pos.Z)

	local length = SHAFT_LENGTH + HEAD_LENGTH
	local tail = centre - dir * (length / 2)
	local headBase = tail + dir * SHAFT_LENGTH
	local tip = centre + dir * (length / 2)

	local parts = {}
	local shaft = newPart("Part")
	-- A hair longer than the gap so the shaft tucks under the head.
	shaft.Size = Vector3.new(SHAFT_WIDTH, THICKNESS, SHAFT_LENGTH + 0.2)
	local mid = tail + dir * (SHAFT_LENGTH / 2)
	shaft.CFrame = CFrame.lookAt(mid, mid + dir)
	table.insert(parts, shaft)
	triangle(headBase + side * (HEAD_WIDTH / 2), headBase - side * (HEAD_WIDTH / 2), tip, parts)

	table.insert(trail, parts)
end

-- Where a base's road stops: the radial line through its centre meets the
-- edge of its square plot, which is further out for the four diagonal
-- plots than for the four straight ones.
local function roadEnd(radial)
	return RING_RADIUS - PLOT_HALF / math.max(math.abs(radial.X), math.abs(radial.Z))
end

-- A row of arrows down one base's road, either out toward that base or in
-- toward the yard.
local function laneArrows(centre, outward)
	local flat = Vector3.new(centre.X, 0, centre.Z)
	if flat.Magnitude < 1 then return end
	local radial = flat.Unit
	local finish = roadEnd(radial) - 4
	for i = 1, ARROWS_PER_ROAD do
		local t = (i - 1) / math.max(ARROWS_PER_ROAD - 1, 1)
		if not outward then t = 1 - t end
		local r = TRAIL_START + (finish - TRAIL_START) * t
		addArrow(radial * r, outward and radial or -radial)
	end
end

local function buildArrows(home, from)
	clearArrows()
	if not home then return end

	arrowFolder = Instance.new("Folder")
	arrowFolder.Name = "CarryArrows"
	arrowFolder.Parent = workspace

	-- Stolen out of someone else's base: first their road back into the
	-- yard, then yours out to home. Every other carry starts in the yard.
	if from and (from - home).Magnitude > 1 then
		laneArrows(from, false)
	end
	laneArrows(home, true)
end

------------------------------------------------------------------
-- State
------------------------------------------------------------------

local carrying = nil
local baseCentre = nil
local carryFrom = nil

local function setCarrying(nextCarrying, nextFrom)
	local changed = nextCarrying ~= carrying or nextFrom ~= carryFrom
	if not changed then return end
	carrying = nextCarrying
	carryFrom = nextFrom

	gui.Enabled = carrying ~= nil
	subtitle.Text = carryFrom and "You stole it — now get it back to YOUR base!" or "Get it back to your base!"

	if carrying then
		buildArrows(baseCentre, carryFrom)
	else
		clearArrows()
	end

	-- Hiding the hotbar is the whole point of the carry state: no bat, no
	-- speed coil, nothing to do but run. pcall because SetCoreGuiEnabled
	-- throws if the CoreGui is not ready yet on a fresh join.
	pcall(function()
		StarterGui:SetCoreGuiEnabled(Enum.CoreGuiType.Backpack, carrying == nil)
	end)
end

updateRemote.OnClientEvent:Connect(function(data)
	if data.baseCentre ~= nil then
		baseCentre = data.baseCentre
	end
	-- `carrying` is absent from payloads that are not about carrying at
	-- all (a toast, an announcement), so only react when the field is
	-- actually part of this update.
	if data.inventory ~= nil or data.carrying ~= nil then
		setCarrying(data.carrying, data.carryFrom)
	end
end)

RunService.RenderStepped:Connect(function()
	if not carrying then return end
	local now = os.clock()
	local pulse = (math.sin(now * 5) + 1) * 0.5
	banner.TextTransparency = pulse * 0.35

	-- The chase: a short run of lit arrows sweeping toward home, looping.
	local count = #trail
	if count == 0 then return end
	local head = (now * CHASE_SPEED) % (count + CHASE_LENGTH)
	for index, parts in ipairs(trail) do
		local behind = head - index
		local transparency = DIM
		if behind >= 0 and behind < CHASE_LENGTH then
			transparency = LIT + (DIM - LIT) * (behind / CHASE_LENGTH)
		end
		for _, part in ipairs(parts) do
			part.Transparency = transparency
		end
	end
end)

-- Dying wipes the arrows even if the next payload is slow to arrive.
player.CharacterAdded:Connect(function()
	if not carrying then clearArrows() end
end)
