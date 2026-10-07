--[[
	AdminPanel (LocalScript, StarterPlayerScripts) — Junkyard Fusion

	An ADMIN button at the top right of the screen, for admins only
	(AdminConfig), opening a small panel of test tools:
	  • Show the whole Index: every entry shows as found, so every model
	    can be checked. On this screen only (GameUI reads the
	    AdminShowAllIndex attribute); saved discoveries are untouched.
	  • Drop the secret Legendary now, start the next race now, and run a
	    yard event now. The server does these, and only for an admin
	    (AdminService).
	Nobody else gets the button, and the server ignores anyone else who
	sends the remote.
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local AdminConfig = require(ReplicatedStorage:WaitForChild("AdminConfig"))

local player = Players.LocalPlayer
if not AdminConfig.IsAdmin(player) then
	return
end

local Garage = require(ReplicatedStorage:WaitForChild("GarageTheme"))
local remote = ReplicatedStorage:WaitForChild("AdminAction")

local RED = Color3.fromRGB(226, 58, 70)
local BLUE = Color3.fromRGB(0, 150, 235)
local GREEN = Color3.fromRGB(20, 190, 120)

local gui = Instance.new("ScreenGui")
gui.Name = "AdminPanel"
gui.ResetOnSpawn = false
gui.DisplayOrder = 20
gui.Parent = player:WaitForChild("PlayerGui")

local toggle = Garage.New("TextButton", gui, "AdminButton", {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -14, 0, 10),
	Size = UDim2.fromOffset(130, 46),
	Text = "ADMIN",
	TextSize = 26,
	AutoButtonColor = false,
})
Garage.Button(toggle, RED)

-- Phone rails start just below the top bar. Keep the admin-only shortcut
-- inside the safe top bar so it cannot cover Travel or a menu's close button.
local mobileTopbar = Instance.new("ScreenGui")
mobileTopbar.Name = "AdminTopbar"
mobileTopbar.ResetOnSpawn = false
mobileTopbar.DisplayOrder = 20
mobileTopbar.ScreenInsets = Enum.ScreenInsets.TopbarSafeInsets
mobileTopbar.Parent = player.PlayerGui
local function fitToggle()
	local bounds = gui.AbsoluteSize
	local phone = bounds.Y > 100 and (bounds.Y < 480 or bounds.X < 600)
	toggle.Parent = phone and mobileTopbar or gui
	toggle.AnchorPoint = Vector2.new(1, phone and .5 or 0)
	toggle.Position = phone and UDim2.new(1, -4, .5, 0) or UDim2.new(1, -14, 0, 10)
	toggle.Size = phone and UDim2.fromOffset(72, 40) or UDim2.fromOffset(130, 46)
	toggle.TextSize = phone and 16 or 26
end
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(fitToggle)
fitToggle()

local PANEL_WIDTH, MARGIN = 320, 12
local panel = Garage.New("Frame", gui, "Panel", {
	AnchorPoint = Vector2.new(1, 0),
	Position = UDim2.new(1, -14, 0, 64),
	Size = UDim2.fromOffset(PANEL_WIDTH, 100),
	Visible = false,
})
Garage.Gloss(panel, Color3.fromRGB(255, 244, 211), 16)
-- The buttons go in their own frame: the gloss is itself a child frame of
-- the panel, which a list layout on the panel would try to arrange too.
local content = Garage.New("Frame", panel, "Content", {
	Position = UDim2.fromOffset(MARGIN, MARGIN),
	Size = UDim2.new(1, -MARGIN * 2, 1, -MARGIN * 2),
	BackgroundTransparency = 1,
	ZIndex = 2,
})
local layout = Garage.New("UIListLayout", content, "Layout", {
	Padding = UDim.new(0, 8),
	SortOrder = Enum.SortOrder.LayoutOrder,
})
layout:GetPropertyChangedSignal("AbsoluteContentSize"):Connect(function()
	panel.Size = UDim2.fromOffset(PANEL_WIDTH, layout.AbsoluteContentSize.Y + MARGIN * 2)
end)

local order = 0
local function button(text, color, onClick)
	order += 1
	local b = Garage.New("TextButton", content, "Action" .. order, {
		LayoutOrder = order,
		Size = UDim2.new(1, 0, 0, 44),
		Text = text,
		TextSize = 20,
		AutoButtonColor = false,
		ZIndex = 3,
	})
	Garage.Button(b, color)
	b.Activated:Connect(onClick)
	return b
end

local status = Garage.Text(content, "Status", "Test tools. Only you can see this.", UDim2.new(), UDim2.new(1, 0, 0, 40), 16)
status.LayoutOrder = 1000
status.TextXAlignment = Enum.TextXAlignment.Left

local function say(text)
	status.Text = text
end

local showAll = false
local indexButton
indexButton = button("Show whole Index: OFF", BLUE, function()
	showAll = not showAll
	player:SetAttribute("AdminShowAllIndex", showAll)
	indexButton.Text = showAll and "Show whole Index: ON" or "Show whole Index: OFF"
	say(showAll and "Every Index entry shows as found (your screen only)." or "Index back to what you've found.")
end)

local function action(text, name)
	button(text, GREEN, function()
		remote:FireServer(name)
		say("Asking the server…")
	end)
end
action("Drop secret Legendary now", "legendary")
action("Start next race now", "race")
action("Scrap Rush now", "ScrapRush")
action("Mutation Frenzy now", "MutationFrenzy")
action("Drop a Secret car now", "SecretCar")
action("Give me 100 bolts", "bolts")
-- Replays the first-join tutorial on your screen only (Tutorial.client);
-- finishing it again changes nothing on the server.
button("Play the tutorial", BLUE, function()
	player:SetAttribute("TutorialReplay", true)
	say("Tutorial started (your screen only).")
end)

remote.OnClientEvent:Connect(function(message)
	if type(message) == "string" then
		say(message)
	end
end)

toggle.Activated:Connect(function()
	panel.Visible = not panel.Visible
end)
