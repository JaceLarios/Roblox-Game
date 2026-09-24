--[[
	CarryHud (LocalScript, StarterPlayerScripts) — Junkyard Fusion v1

	The "you are holding loot, RUN" overlay: a red banner across the top of
	the screen, a red arrow running from your body to your own base's door,
	and a Drop button on the item over your head. All of it appears the
	moment you pick something up and vanishes the moment you deliver it,
	drop it, die, or get it knocked out of you.

	Deliberately its own script rather than another section of
	GameUI.client.luau — the same isolation pattern ShopUI uses —
	and it is purely reactive to fields the existing GameUpdate payload
	already carries (carrying, baseCentre, carryFrom).

	The arrow and the Drop button are built on the CLIENT. They cost the
	server nothing, they replicate to nobody, and only the player actually
	carrying sees them — nobody else gets a Drop button on someone else's
	loot.

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
local dropRemote = ReplicatedStorage:WaitForChild("DropCarried")

local RED = Color3.fromRGB(255, 40, 40)

-- The map's dimensions come from the same shared layout PlotManager builds
-- the workshops and roads from, so the arrow always ends at the real door.
local Layout = require(ReplicatedStorage:WaitForChild("JunkyardLayout"))

-- A white chevron, tinted red by the beam. Tiles every ARROW_SPACING studs
-- along the arrow and scrolls toward home, so it reads as moving the way
-- you need to go. Roblox runs a beam texture's VERTICAL axis along the
-- beam, so the chevron is drawn pointing down the image (source file:
-- assets/carry-arrow/chevron.png).
local ARROW_TEXTURE = "rbxassetid://93791096336970"
local ARROW_SPACING = 3
local ARROW_SCROLL = 2.5    -- chevron spacings per second
local ARROW_WIDTH = 2.6
-- Where on the body the arrow starts: a little below the root, about the
-- waist, so it comes out of the player rather than their chest.
local ARROW_BODY_OFFSET = Vector3.new(0, -0.9, 0)
-- Height of the far end above the door's floor, level with a player
-- walking through it, so the arrow does not dive into the ground.
local ARROW_DOOR_HEIGHT = 3.5

-- A grab is a held E, so the Drop button waits a moment before it takes
-- input; otherwise mashing E to grab could drop the item straight away.
local DROP_ARM_DELAY = 0.4

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
-- Arrow home: body to door
------------------------------------------------------------------

local arrowFolder = nil
local arrowBeam = nil

local function clearArrow()
	if arrowFolder then
		arrowFolder:Destroy()
		arrowFolder = nil
	end
	arrowBeam = nil
end

-- Every workshop faces the yard, so its door sits this far out along the
-- line from the yard's centre through the base — the same formula
-- PlotManager places the entrance gate with.
local function doorPosition(home)
	local flat = Vector3.new(home.X, 0, home.Z)
	if flat.Magnitude < 1 then return nil end
	local out = flat.Unit * (Layout.PlotRadius - Layout.PlotSize / 2)
	return Vector3.new(out.X, home.Y + ARROW_DOOR_HEIGHT, out.Z)
end

local function buildArrow(home)
	clearArrow()
	local door = home and doorPosition(home)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
	if not (door and root) then return end

	-- The body end rides on the character, so the arrow follows every step;
	-- the far end is pinned to the door. The folder holds both, so clearing
	-- it takes the attachment off the character too.
	arrowFolder = Instance.new("Folder")
	arrowFolder.Name = "CarryArrow"
	arrowFolder.Parent = workspace

	local bodyEnd = Instance.new("Attachment")
	bodyEnd.Name = "CarryArrowStart"
	bodyEnd.Position = ARROW_BODY_OFFSET
	bodyEnd.Parent = root
	-- Tie the attachment's life to the folder's.
	arrowFolder.Destroying:Connect(function() bodyEnd:Destroy() end)

	local anchor = Instance.new("Part")
	anchor.Name = "DoorEnd"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.Position = door
	anchor.Parent = arrowFolder
	local doorEnd = Instance.new("Attachment")
	doorEnd.Parent = anchor

	local beam = Instance.new("Beam")
	beam.Attachment0 = bodyEnd
	beam.Attachment1 = doorEnd
	beam.Texture = ARROW_TEXTURE
	beam.TextureMode = Enum.TextureMode.Wrap
	beam.TextureLength = ARROW_SPACING
	beam.TextureSpeed = ARROW_SCROLL
	beam.Width0 = ARROW_WIDTH
	beam.Width1 = ARROW_WIDTH
	beam.FaceCamera = true
	-- Mostly solid rather than glowing: fully additive red washes out to
	-- pink on the pale yard floor.
	beam.LightEmission = 0.25
	beam.LightInfluence = 0
	beam.Color = ColorSequence.new(RED)
	beam.Parent = arrowFolder
	arrowBeam = beam
end

------------------------------------------------------------------
-- Drop button on the carried item
------------------------------------------------------------------

-- A ProximityPrompt is a real button: click or tap it, or press E. Made on
-- this client only, parented to the item over your own head, so nobody
-- else ever sees it. The server decides what dropping actually does.
local dropToken = 0

-- While you carry, the only thing E should do is drop. The Grab prompts on
-- loose scrap are also on E, and Roblox shows one E prompt at a time
-- without always picking the nearest, so a Grab could win and pressing E
-- would do nothing (the server refuses a second grab). They are switched
-- off on this screen until you are empty-handed again.
local scrapFolder = workspace:WaitForChild("Scrap")
local scrapWatch = nil

local function setGrabPrompts(enabled)
	for _, item in ipairs(scrapFolder:GetChildren()) do
		local grab = item:FindFirstChildOfClass("ProximityPrompt")
		if grab then grab.Enabled = enabled end
	end
	if scrapWatch then
		scrapWatch:Disconnect()
		scrapWatch = nil
	end
	if not enabled then
		scrapWatch = scrapFolder.DescendantAdded:Connect(function(descendant)
			if descendant:IsA("ProximityPrompt") then descendant.Enabled = false end
		end)
	end
end

local function addDropButton()
	dropToken += 1
	local token = dropToken
	task.spawn(function()
		local character = player.Character
		local held = character and character:WaitForChild("CarriedItem", 5)
		if not held then return end
		task.wait(DROP_ARM_DELAY)
		if token ~= dropToken or not held.Parent then return end

		local prompt = Instance.new("ProximityPrompt")
		prompt.Name = "DropPrompt"
		prompt.ActionText = "Drop"
		prompt.ObjectText = ""
		prompt.KeyboardKeyCode = Enum.KeyCode.E
		prompt.GamepadKeyCode = Enum.KeyCode.ButtonX
		prompt.HoldDuration = 0
		prompt.MaxActivationDistance = 15
		prompt.RequiresLineOfSight = false
		prompt.ClickablePrompt = true
		prompt.Parent = held
		prompt.Triggered:Connect(function()
			prompt.Enabled = false
			dropRemote:FireServer()
		end)
	end)
end

local function removeDropButton()
	-- The prompt lives on the carried item and goes with it; this only
	-- stops a button that is still waiting to arm from appearing late.
	dropToken += 1
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
		buildArrow(baseCentre)
		addDropButton()
		setGrabPrompts(false)
	else
		clearArrow()
		removeDropButton()
		setGrabPrompts(true)
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
	local pulse = (math.sin(os.clock() * 5) + 1) * 0.5
	banner.TextTransparency = pulse * 0.35
	-- The arrow flashes in step with the banner.
	if arrowBeam then
		arrowBeam.Transparency = NumberSequence.new(pulse * 0.3)
	end
end)

-- Dying wipes the arrow even if the next payload is slow to arrive; a new
-- body needs the arrow re-attached if the carry somehow survived.
player.CharacterAdded:Connect(function()
	if carrying then
		buildArrow(baseCentre)
	else
		clearArrow()
	end
end)
