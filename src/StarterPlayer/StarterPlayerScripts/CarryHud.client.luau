--[[
	CarryHud (LocalScript, StarterPlayerScripts) — Junkyard Fusion v1

	The "you are holding loot, RUN" overlay: a red banner across the top of
	the screen, and a line of red arrows on the ground pointing the way
	back to your own base. Both appear the moment you pick something up and
	vanish the moment you deliver it, die, or get it knocked out of you.

	Deliberately its own script rather than another section of
	GameUI.client.luau — the same isolation pattern PetsUI and ShopUI use —
	and it is purely reactive to two fields the existing GameUpdate payload
	already carries (carrying, baseCentre).

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

local RED = Color3.fromRGB(255, 45, 45)
local ARROW_COUNT = 12
-- The road runs radially from about r=86 out to the plot edge, so the
-- trail is laid along that same line rather than straight at the base:
-- pointing through the barriers would send people into a wall.
local TRAIL_START, TRAIL_END = 72, 168
local ARROW_SIZE = Vector3.new(7, 0.4, 9)

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

local function clearArrows()
	if arrowFolder then
		arrowFolder:Destroy()
		arrowFolder = nil
	end
end

local function buildArrows(baseCentre)
	clearArrows()
	if not baseCentre then return end

	-- The plots sit on a ring centred on the origin, so the direction from
	-- the world centre out to this base IS the road.
	local flat = Vector3.new(baseCentre.X, 0, baseCentre.Z)
	if flat.Magnitude < 1 then return end
	local radial = flat.Unit

	arrowFolder = Instance.new("Folder")
	arrowFolder.Name = "CarryArrows"
	arrowFolder.Parent = workspace

	for i = 1, ARROW_COUNT do
		local t = (i - 1) / math.max(ARROW_COUNT - 1, 1)
		local r = TRAIL_START + (TRAIL_END - TRAIL_START) * t
		local pos = radial * r + Vector3.new(0, 2.2, 0)

		-- A wedge read from above is a triangle, which is the cheapest
		-- convincing arrowhead available without shipping a mesh.
		local arrow = Instance.new("WedgePart")
		arrow.Name = "CarryArrow"
		arrow.Size = ARROW_SIZE
		arrow.Anchored = true
		arrow.CanCollide = false
		arrow.CanQuery = false
		arrow.CanTouch = false
		arrow.Material = Enum.Material.Neon
		arrow.Color = RED
		arrow.Transparency = 0.25
		-- Tip toward the base, laid flat: the wedge slopes up along its
		-- own -Z, so looking down the radial puts the point the right way.
		arrow.CFrame = CFrame.lookAt(pos, pos + radial) * CFrame.Angles(math.rad(-90), 0, 0)
		arrow.Parent = arrowFolder
	end
end

------------------------------------------------------------------
-- State
------------------------------------------------------------------

local carrying = nil
local baseCentre = nil

local function setCarrying(nextCarrying, nextBase)
	baseCentre = nextBase or baseCentre
	if nextCarrying == carrying then return end
	carrying = nextCarrying

	gui.Enabled = carrying ~= nil

	if carrying then
		buildArrows(baseCentre)
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
		setCarrying(data.carrying, baseCentre)
	end
end)

-- A slow pulse on the banner and arrows, so the warning reads as urgent
-- rather than as a static label somebody forgot to clear.
RunService.RenderStepped:Connect(function()
	if not carrying then return end
	local pulse = (math.sin(os.clock() * 5) + 1) * 0.5
	banner.TextTransparency = pulse * 0.35
	if arrowFolder then
		for _, arrow in ipairs(arrowFolder:GetChildren()) do
			arrow.Transparency = 0.15 + pulse * 0.35
		end
	end
end)

-- Dying wipes the arrows even if the next payload is slow to arrive.
player.CharacterAdded:Connect(function()
	if not carrying then clearArrows() end
end)
