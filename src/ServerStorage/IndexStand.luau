--[[
	IndexStand (ModuleScript, ServerStorage) — Junkyard Fusion

	The Item Index's stand in the middle of the yard, between the crane and
	the conveyor: a round purple platform with a lectern holding a giant
	open book, a tall double-sided "ITEM INDEX" sign over it, and sparkles
	drifting off the pages. Walking up to it (its "Open Index" prompt) or
	clicking it opens the Index; GameUI.client does the opening. It replaced
	the INDEX button on the left of the screen on 2026-10-05 (user: "make a
	stand somewhere in the middle, something like the leaderboards but
	smaller and different").

	Built by MapBootstrap. Rebuilt from scratch every time, like the
	leaderboards.
--]]

local Stand = {}

-- South of the crane (its sweep is 20 studs), inside the conveyor ring,
-- facing out toward the bases on that side.
local CENTRE = Vector3.new(0, 1.2, 30)
local FACING = Vector3.new(0, 0, 1)

local PURPLE = Color3.fromRGB(122, 64, 214)
local DEEP = Color3.fromRGB(46, 28, 86)
local GOLD = Color3.fromRGB(255, 204, 65)
local PAGE = Color3.fromRGB(255, 250, 236)

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

local function sign(parent, face, text, sub)
	local gui = Instance.new("SurfaceGui")
	gui.Face = face
	gui.CanvasSize = Vector2.new(600, 170)
	gui.LightInfluence = 0
	gui.Parent = parent
	local title = Instance.new("TextLabel")
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, 0, 0.66, 0)
	title.Font = Enum.Font.FredokaOne
	title.TextScaled = true
	title.TextColor3 = GOLD
	title.Text = text
	title.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Color = DEEP
	stroke.Thickness = 4
	stroke.Parent = title
	local line = Instance.new("TextLabel")
	line.BackgroundTransparency = 1
	line.Position = UDim2.fromScale(0, 0.66)
	line.Size = UDim2.new(1, 0, 0.3, 0)
	line.Font = Enum.Font.FredokaOne
	line.TextScaled = true
	line.TextColor3 = Color3.new(1, 1, 1)
	line.Text = sub
	line.Parent = gui
end

function Stand.Build()
	local old = workspace:FindFirstChild("IndexStand")
	if old then old:Destroy() end
	local model = Instance.new("Model")
	model.Name = "IndexStand"
	-- Always on everyone's screen, so the client can hook up its prompt
	-- and click straight away (the place streams).
	model.ModelStreamingMode = Enum.ModelStreamingMode.Persistent

	local base = CFrame.lookAt(CENTRE, CENTRE + FACING)

	-- A round platform with a gold rim.
	local rim = part(model, "Rim", Vector3.new(0.5, 13, 13), base * CFrame.new(0, 0.25, 0) * CFrame.Angles(0, 0, math.pi / 2), GOLD, Enum.Material.Metal)
	rim.Shape = Enum.PartType.Cylinder
	local floor = part(model, "Platform", Vector3.new(0.7, 12, 12), base * CFrame.new(0, 0.35, 0) * CFrame.Angles(0, 0, math.pi / 2), DEEP)
	floor.Shape = Enum.PartType.Cylinder

	-- The lectern: a post and a sloped top, the book open on it.
	part(model, "LecternPost", Vector3.new(1.6, 3.2, 1.6), base * CFrame.new(0, 2.3, 0), PURPLE)
	part(model, "LecternFoot", Vector3.new(3.4, 0.5, 3.4), base * CFrame.new(0, 0.95, 0), PURPLE)
	local tilt = base * CFrame.new(0, 4.1, 0) * CFrame.Angles(math.rad(-28), 0, 0)
	part(model, "LecternTop", Vector3.new(6.4, 0.5, 4.2), tilt, PURPLE)
	-- The book: a purple cover with two cream pages bowing up from the spine.
	local cover = part(model, "BookCover", Vector3.new(7, 0.3, 4.8), tilt * CFrame.new(0, 0.4, 0), DEEP)
	for _, side in ipairs({ -1, 1 }) do
		local pageCf = tilt * CFrame.new(side * 1.7, 0.62, 0) * CFrame.Angles(0, 0, math.rad(side * -7))
		local page = part(model, "BookPage", Vector3.new(3.2, 0.25, 4.4), pageCf, PAGE)
		page.CanCollide = false
		-- Lines of "writing" across each page.
		for line = 1, 5 do
			local width = line == 1 and 1.6 or 2.4
			local ink = part(model, "PageLine", Vector3.new(width, 0.05, 0.22),
				pageCf * CFrame.new(0, 0.14, -1.6 + line * 0.62), line == 1 and PURPLE or Color3.fromRGB(150, 140, 170))
			ink.CanCollide = false
		end
	end
	-- A ribbon bookmark down the middle.
	part(model, "Bookmark", Vector3.new(0.35, 0.06, 5.4), tilt * CFrame.new(0, 0.78, 0.4), GOLD).CanCollide = false
	cover.Name = "Book"

	-- A tall sign behind it, readable from both sides.
	-- Behind the book (the stand faces -Z in its own frame).
	for _, x in ipairs({ -4.6, 4.6 }) do
		part(model, "SignPost", Vector3.new(0.7, 11, 0.7), base * CFrame.new(x, 6.2, 3.6), GOLD, Enum.Material.Metal)
	end
	local board = part(model, "SignBoard", Vector3.new(10.4, 3, 0.6), base * CFrame.new(0, 10.6, 3.6), PURPLE)
	sign(board, Enum.NormalId.Back, "ITEM INDEX", "Every car and addon")
	sign(board, Enum.NormalId.Front, "ITEM INDEX", "Every car and addon")
	part(model, "SignTrim", Vector3.new(10.8, 0.4, 0.8), base * CFrame.new(0, 12.3, 3.6), GOLD, Enum.Material.Metal)

	-- Sparkles drifting up off the pages.
	local glow = Instance.new("Attachment")
	glow.Name = "Sparkle"
	glow.Position = Vector3.new(0, 0.7, 0)
	glow.Parent = cover
	local sparkles = Instance.new("ParticleEmitter")
	sparkles.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparkles.Color = ColorSequence.new(Color3.fromRGB(205, 160, 255), GOLD)
	sparkles.Rate = 10
	sparkles.Lifetime = NumberRange.new(1.2, 2)
	sparkles.Speed = NumberRange.new(1, 2.5)
	sparkles.SpreadAngle = Vector2.new(30, 30)
	sparkles.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 0) })
	sparkles.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0), NumberSequenceKeypoint.new(1, 1) })
	sparkles.LightEmission = 0.5
	sparkles.Parent = glow
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(190, 140, 255)
	light.Brightness = 1.2
	light.Range = 14
	light.Parent = cover

	-- Walk up and press, or click it from further away. GameUI.client
	-- listens to both and opens the Index.
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "OpenIndex"
	prompt.ActionText = "Open Index"
	prompt.ObjectText = "Item Index"
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 12
	prompt.RequiresLineOfSight = false
	prompt.Parent = cover
	local click = Instance.new("ClickDetector")
	click.Name = "OpenIndexClick"
	click.MaxActivationDistance = 60
	click.Parent = model

	model.Parent = workspace
	return model
end

return Stand
