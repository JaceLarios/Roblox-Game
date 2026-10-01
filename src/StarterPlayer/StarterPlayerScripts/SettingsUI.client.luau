--[[
	SettingsUI (LocalScript, StarterPlayerScripts) — Junkyard Fusion

	The Settings button (a gear, top right) and its panel, in two tabs:
	  SETTINGS  music volume (a slider), sound effects on or off, and potato
	            mode, which turns down the graphics so the game runs smoothly
	            on a slow device.
	  CREDITS   every outside 3D model the game uses, with its creator,
	            source, licence and what we changed (ModelCredits), in a list
	            that scrolls.
	Everything here is applied on this player's screen only. The choices are
	kept between visits by the PlayerSettings server script, which loads
	them as attributes on the player (MusicVolume 0-1, SFXOn, PotatoMode)
	and takes changes through the PlayerSettings remote.

	Sound: every Sound is put in one of two SoundGroups made here, "music"
	for the tracks in SoundService.Music (MusicService) and "sfx" for
	everything else, wherever it plays (yard sounds, fusion popups,
	footsteps). The groups' volumes are the settings, so nothing else in the
	game has to know about them.
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")
local Lighting = game:GetService("Lighting")
local UserInputService = game:GetService("UserInputService")

local Garage = require(ReplicatedStorage:WaitForChild("GarageTheme"))
local Style = require(ReplicatedStorage:WaitForChild("UIStyle"))
local ModelCredits = require(ReplicatedStorage:WaitForChild("ModelCredits"))
local remote = ReplicatedStorage:WaitForChild("PlayerSettings")

local player = Players.LocalPlayer

local INK = Style.Palette.Ink
local GOLD = Color3.fromRGB(255, 199, 47)
local BLUE = Color3.fromRGB(121, 154, 200)
local GREEN = Color3.fromRGB(40, 200, 110)
local GREY = Color3.fromRGB(120, 128, 142)
local TRACK = Color3.fromRGB(214, 206, 186)

local WIDTH, HEIGHT = 900, 640

local settings = { MusicVolume = 1, SFXOn = true, PotatoMode = false }

------------------------------------------------------------------
-- Sound
------------------------------------------------------------------

local musicGroup = Instance.new("SoundGroup")
musicGroup.Name = "SettingsMusic"
musicGroup.Parent = SoundService
local sfxGroup = Instance.new("SoundGroup")
sfxGroup.Name = "SettingsSFX"
sfxGroup.Parent = SoundService

local musicFolder = SoundService:WaitForChild("Music", 10)

local function route(object)
	if not object:IsA("Sound") then return end
	local isMusic = musicFolder ~= nil and object:IsDescendantOf(musicFolder)
	object.SoundGroup = isMusic and musicGroup or sfxGroup
end

for _, root in ipairs({ workspace, SoundService, player:WaitForChild("PlayerGui") }) do
	for _, object in ipairs(root:GetDescendants()) do route(object) end
	root.DescendantAdded:Connect(route)
end

------------------------------------------------------------------
-- Potato mode
------------------------------------------------------------------

-- Turned off while potato mode is on: shadows, the bloom/sun-ray style
-- screen effects, particles, beams, trails, glows (Highlights), extra
-- lights and clouds. Each is put back just as it was when it goes off.
local POTATO_OFF = {
	ParticleEmitter = true, Beam = true, Trail = true, Smoke = true, Fire = true, Sparkles = true,
	PointLight = true, SpotLight = true, SurfaceLight = true, Highlight = true, Clouds = true,
	BloomEffect = true, BlurEffect = true, SunRaysEffect = true, DepthOfFieldEffect = true,
}
local potato = false
local switchedOff = {}   -- [instance] = true: on before potato mode turned it off
local savedShadows = nil
local savedDecoration = nil

local function dim(object)
	if POTATO_OFF[object.ClassName] and object.Enabled then
		object.Enabled = false
		switchedOff[object] = true
	end
end

local function setPotato(on)
	if on == potato then return end
	potato = on
	if on then
		savedShadows = Lighting.GlobalShadows
		Lighting.GlobalShadows = false
		for _, root in ipairs({ workspace, Lighting }) do
			for _, object in ipairs(root:GetDescendants()) do dim(object) end
		end
		pcall(function()
			savedDecoration = workspace.Terrain.Decoration
			workspace.Terrain.Decoration = false
		end)
	else
		if savedShadows ~= nil then Lighting.GlobalShadows = savedShadows end
		for object in pairs(switchedOff) do
			if object.Parent then object.Enabled = true end
		end
		table.clear(switchedOff)
		if savedDecoration ~= nil then
			pcall(function() workspace.Terrain.Decoration = savedDecoration end)
		end
	end
end

-- Anything new (a crate's burst, a rare car's light) stays off too.
for _, root in ipairs({ workspace, Lighting }) do
	root.DescendantAdded:Connect(function(object)
		if potato then dim(object) end
	end)
end

------------------------------------------------------------------
-- The button
------------------------------------------------------------------

local gui = Instance.new("ScreenGui")
gui.Name = "SettingsUI"
gui.ResetOnSpawn = false
gui.DisplayOrder = 21
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui:SetAttribute("Designed", true)
gui.Parent = player:WaitForChild("PlayerGui")

local open = Garage.New("TextButton", gui, "SettingsButton", {
	AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -14, 0, 10), Size = UDim2.fromOffset(50, 46),
	Text = "", AutoButtonColor = false,
})
Garage.Gloss(open, Color3.fromRGB(0, 150, 235), 14)
Garage.Art(open, "UPGRADES", UDim2.fromOffset(5, 3), UDim2.new(1, -10, 1, -6))

-- Top right; on a phone on its side the nav buttons fill that corner as a
-- two-by-two grid (NavButton), so it sits just left of them.
local function placeButton()
	local size = gui.AbsoluteSize
	if size.Y < 100 then return end
	if size.Y < 480 then
		local factor = math.clamp(size.Y / 610, 0.48, 0.62)
		open.Position = UDim2.new(1, -(8 + 2 * (140 * factor + 2) + 8), 0, 4)
	else
		open.Position = UDim2.new(1, -14, 0, 10)
	end
end
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(placeButton)
placeButton()

------------------------------------------------------------------
-- The panel
------------------------------------------------------------------

local overlay = Instance.new("Frame")
overlay.Name = "Overlay"
overlay.Size = UDim2.fromScale(1, 1)
overlay.BackgroundColor3 = INK
overlay.BackgroundTransparency = 0.7
overlay.Visible = false
overlay.Parent = gui
Style.Modal(overlay)

local panel = Garage.New("Frame", overlay, "SettingsPanel", { BackgroundColor3 = Style.Palette.Cream })
Garage.Canvas(panel, WIDTH, HEIGHT)

Garage.Art(panel, "UPGRADES", UDim2.fromOffset(18, 10), UDim2.fromOffset(80, 80))
local title = Garage.Text(panel, "Title", "SETTINGS", UDim2.fromOffset(106, 16), UDim2.fromOffset(300, 62), 40)
title.TextXAlignment = Enum.TextXAlignment.Left
local close = Garage.New("TextButton", panel, "Close", {
	Text = "X", TextSize = 30, Font = Enum.Font.FredokaOne,
	AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -20, 0, 18), Size = UDim2.fromOffset(64, 56), ZIndex = 6,
})

local function tabButton(name, text, x)
	local b = Garage.New("TextButton", panel, name, {
		Text = text, TextSize = 24, Font = Enum.Font.FredokaOne, AutoButtonColor = true, ZIndex = 5,
		Position = UDim2.fromOffset(x, 20), Size = UDim2.fromOffset(160, 52),
	})
	Garage.Button(b, BLUE)
	return b
end
local settingsTab = tabButton("SettingsTab", "SETTINGS", WIDTH - 104 - 2 * 160 - 10)
local creditsTab = tabButton("CreditsTab", "CREDITS", WIDTH - 104 - 160)

local CONTENT_TOP = 100
local function page(name)
	return Garage.New("Frame", panel, name, {
		BackgroundTransparency = 1, Position = UDim2.fromOffset(24, CONTENT_TOP),
		Size = UDim2.new(1, -48, 1, -(CONTENT_TOP + 24)), ZIndex = 2,
	})
end
local settingsPage = page("SettingsPage")
local creditsPage = page("CreditsPage")

------------------------------------------------------------------
-- SETTINGS: one card per setting
------------------------------------------------------------------

local function card(order, heading, blurb)
	local c = Garage.New("Frame", settingsPage, heading, {
		Position = UDim2.fromOffset(0, (order - 1) * 166), Size = UDim2.new(1, 0, 0, 150),
	})
	Garage.Inset(c)
	local h = Garage.Text(c, "Heading", heading, UDim2.fromOffset(22, 12), UDim2.new(1, -260, 0, 40), 30)
	h.TextXAlignment = Enum.TextXAlignment.Left
	local b = Garage.Text(c, "Blurb", blurb, UDim2.fromOffset(22, 54), UDim2.new(1, -260, 0, 44), 18)
	b.TextXAlignment = Enum.TextXAlignment.Left
	b.TextYAlignment = Enum.TextYAlignment.Top
	b.TextColor3 = Color3.fromRGB(90, 96, 104)
	return c
end

local function send(key, value)
	remote:FireServer(key, value)
end

-- Music volume: a slider.
local musicCard = card(1, "MUSIC VOLUME", "How loud the background music is.")
local track = Garage.New("Frame", musicCard, "Track", {
	Position = UDim2.fromOffset(22, 104), Size = UDim2.new(1, -260, 0, 26), BackgroundColor3 = TRACK,
	Active = true, ZIndex = 4,
})
Garage.New("UICorner", track, "Corner", { CornerRadius = UDim.new(1, 0) })
local fill = Garage.New("Frame", track, "Fill", { Size = UDim2.fromScale(1, 1), BackgroundColor3 = GOLD, ZIndex = 5 })
Garage.New("UICorner", fill, "Corner", { CornerRadius = UDim.new(1, 0) })
local knob = Garage.New("Frame", track, "Knob", {
	AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(1, 0.5), Size = UDim2.fromOffset(40, 40),
	BackgroundColor3 = Color3.new(1, 1, 1), ZIndex = 6,
})
Garage.New("UICorner", knob, "Corner", { CornerRadius = UDim.new(1, 0) })
local knobStroke = Instance.new("UIStroke")
knobStroke.Color = INK
knobStroke.Thickness = 3
knobStroke.Parent = knob
local percent = Garage.Text(musicCard, "Percent", "100%", UDim2.new(1, -210, 0, 46), UDim2.fromOffset(180, 60), 30)
Garage.Plate(percent)

-- Sound effects and potato mode: ON / OFF buttons.
local function toggle(parent)
	local b = Garage.New("TextButton", parent, "Toggle", {
		Text = "ON", TextSize = 30, Font = Enum.Font.FredokaOne, AutoButtonColor = true, ZIndex = 5,
		AnchorPoint = Vector2.new(0, 0.5), Position = UDim2.new(1, -210, 0.5, 0), Size = UDim2.fromOffset(180, 64),
	})
	Garage.Button(b, GREEN)
	return b
end
local sfxCard = card(2, "SOUND EFFECTS", "Grabs, fusing, crates, footsteps and every other game sound.")
local sfxToggle = toggle(sfxCard)
local potatoCard = card(3, "POTATO MODE", "Lower graphics so the game runs smoothly: no shadows, particles, glows or extra lights.")
local potatoToggle = toggle(potatoCard)

local function showToggle(b, on)
	b.Text = on and "ON" or "OFF"
	b.BackgroundColor3 = on and GREEN or GREY
end

local function showVolume()
	local v = settings.MusicVolume
	fill.Size = UDim2.fromScale(v, 1)
	knob.Position = UDim2.fromScale(v, 0.5)
	percent.Text = string.format("%d%%", math.round(v * 100))
end

-- Applies the settings to this screen and shows them on the panel.
local function apply()
	musicGroup.Volume = settings.MusicVolume
	sfxGroup.Volume = settings.SFXOn and 1 or 0
	setPotato(settings.PotatoMode)
	showVolume()
	showToggle(sfxToggle, settings.SFXOn)
	showToggle(potatoToggle, settings.PotatoMode)
end

local dragging = false
local function volumeAt(x)
	local fraction = (x - track.AbsolutePosition.X) / math.max(track.AbsoluteSize.X, 1)
	settings.MusicVolume = math.clamp(math.round(fraction * 20) / 20, 0, 1)
	apply()
end
track.InputBegan:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragging = true
		volumeAt(input.Position.X)
	end
end)
UserInputService.InputChanged:Connect(function(input)
	if dragging and (input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch) then
		volumeAt(input.Position.X)
	end
end)
UserInputService.InputEnded:Connect(function(input)
	if dragging and (input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch) then
		dragging = false
		send("MusicVolume", settings.MusicVolume)
	end
end)

sfxToggle.Activated:Connect(function()
	settings.SFXOn = not settings.SFXOn
	apply()
	send("SFXOn", settings.SFXOn)
end)
potatoToggle.Activated:Connect(function()
	settings.PotatoMode = not settings.PotatoMode
	apply()
	send("PotatoMode", settings.PotatoMode)
end)

------------------------------------------------------------------
-- CREDITS: every outside model, in a list that scrolls
------------------------------------------------------------------

local list = Garage.New("ScrollingFrame", creditsPage, "CreditsList", {
	Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 8,
	ScrollBarImageColor3 = INK, AutomaticCanvasSize = Enum.AutomaticSize.Y, CanvasSize = UDim2.new(),
	ScrollingDirection = Enum.ScrollingDirection.Y, ZIndex = 3,
})
Garage.New("UIListLayout", list, "Layout", { Padding = UDim.new(0, 14), SortOrder = Enum.SortOrder.LayoutOrder })
Garage.New("UIPadding", list, "Padding", { PaddingRight = UDim.new(0, 14), PaddingBottom = UDim.new(0, 8) })

local function line(parent, order, text, size, color, selectable)
	-- URLs are a read-only TextBox, so they can be selected and copied.
	local l = Garage.New(selectable and "TextBox" or "TextLabel", parent, "Line" .. order, {
		LayoutOrder = order, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1, Text = text, TextSize = size, Font = Enum.Font.FredokaOne,
		TextColor3 = color or INK, TextWrapped = true, TextXAlignment = Enum.TextXAlignment.Left,
		TextYAlignment = Enum.TextYAlignment.Top, ZIndex = 5,
	})
	if selectable then
		l.TextEditable = false
		l.ClearTextOnFocus = false
		l.MultiLine = true
	end
	return l
end

local intro = line(list, 0, "The Secret cars are built from free 3D models shared under Creative Commons licences. Thank you to their creators!", 20)
intro.LayoutOrder = 0

for i, entry in ipairs(ModelCredits) do
	local c = Garage.New("Frame", list, "Credit" .. i, {
		LayoutOrder = i, Size = UDim2.new(1, 0, 0, 0), AutomaticSize = Enum.AutomaticSize.Y, ZIndex = 4,
	})
	Garage.Inset(c)
	Garage.New("UIPadding", c, "Padding", {
		PaddingTop = UDim.new(0, 14), PaddingBottom = UDim.new(0, 16),
		PaddingLeft = UDim.new(0, 18), PaddingRight = UDim.new(0, 18),
	})
	Garage.New("UIListLayout", c, "Layout", { Padding = UDim.new(0, 6), SortOrder = Enum.SortOrder.LayoutOrder })
	line(c, 1, entry.title, 28)
	line(c, 2, "Original model: " .. entry.author, 18)
	line(c, 3, "Source: " .. entry.source, 16, Color3.fromRGB(0, 102, 170), true)
	line(c, 4, "Licence: " .. entry.license .. "  " .. entry.licenseUrl, 16, Color3.fromRGB(0, 102, 170), true)
	line(c, 5, entry.changes, 18, Color3.fromRGB(90, 96, 104))
end

line(list, #ModelCredits + 1, "Credit identifies where a model came from; it does not mean its creator endorses this game. Car names and badges are changed, and the game is not affiliated with any car maker.", 16, Color3.fromRGB(90, 96, 104))

Garage.Shell(panel)
Garage.Header(title)

------------------------------------------------------------------
-- Switching and opening
------------------------------------------------------------------

local function show(which)
	settingsPage.Visible = which == "settings"
	creditsPage.Visible = which == "credits"
	settingsTab.BackgroundColor3 = which == "settings" and GOLD or BLUE
	creditsTab.BackgroundColor3 = which == "credits" and GOLD or BLUE
end
settingsTab.Activated:Connect(function() show("settings") end)
creditsTab.Activated:Connect(function() show("credits") end)
show("settings")

open.Activated:Connect(function()
	overlay.Visible = not overlay.Visible
end)
close.Activated:Connect(function()
	overlay.Visible = false
end)

------------------------------------------------------------------
-- Loading the saved choices
------------------------------------------------------------------

local function fromAttributes()
	local v = player:GetAttribute("MusicVolume")
	if type(v) == "number" then settings.MusicVolume = math.clamp(v, 0, 1) end
	local sfx = player:GetAttribute("SFXOn")
	if type(sfx) == "boolean" then settings.SFXOn = sfx end
	local p = player:GetAttribute("PotatoMode")
	if type(p) == "boolean" then settings.PotatoMode = p end
	apply()
end

apply()
for _, key in ipairs({ "MusicVolume", "SFXOn", "PotatoMode" }) do
	player:GetAttributeChangedSignal(key):Connect(function()
		if not dragging then fromAttributes() end
	end)
end
if player:GetAttribute("SettingsLoaded") then
	fromAttributes()
end
