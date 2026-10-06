--[[
	FusionEffects (ModuleScript, ServerStorage) — Junkyard Fusion

	ALL visual design for these two effects lives here: texture, color,
	size, speed, lifetime, rate — everything about what they look like.
	This is the Codex-owned half, same split as FusionCelebrationView (see
	StarterPlayerScripts) — redesign the emitters below as freely as you
	want, including swapping the whole approach (different texture, a
	BillboardGui-based effect, whatever), as long as the two functions
	below keep doing what their names say:

		Effects.FusionShimmer(pad)        - a one-shot burst, meant to read
		                                     as "these two items just fused"
		Effects.AttachPlacedGlow(part, color) - a continuous ambient effect
		                                     on an item currently earning
		                                     on a pet pad, tinted by rarity
		Effects.AttachSecretAura(part, tint)  - the same for a Secret car: a
		                                     light glow, a halo, rising stars
		Effects.AttachRarityAura(part, rarity) - every other car's aura, one
		                                     look per rarity (see AURAS)

	PlotManager.server.luau (a sibling script, not this one) calls these
	two functions and owns WHEN each fires and WHAT pad/part/color to pass
	— it should never need to know or care what's inside them.

	Everything below is a working placeholder, already tuned once for
	visibility/contrast (see the comments on each), not a final design.
--]]

local Effects = {}

function Effects.FusionShimmer(pad)
	local attachment = Instance.new("Attachment")
	attachment.Position = Vector3.new(0, 1, 0)
	attachment.Parent = pad

	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	-- White-to-gold (the original pairing) all but disappears against the pad's
	-- own bright yellow surface — confirmed visually close-up in Studio. Signature
	-- BLUE instead of gold keeps the sparkle high-contrast on any pad color.
	emitter.Color = ColorSequence.new(Color3.fromRGB(255, 255, 255), Color3.fromRGB(70, 150, 255))
	emitter.Lifetime = NumberRange.new(0.5, 1.0)
	emitter.Speed = NumberRange.new(8, 16)
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Rate = 0
	emitter.LightEmission = 0.75
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.9),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Parent = attachment

	emitter:Emit(70)
	task.delay(2, function()
		if attachment.Parent then attachment:Destroy() end
	end)
end

-- Parented to the item part itself (not the pad), so it lives and dies
-- with that part — no separate bookkeeping needed when a pet gets taken
-- back off, since PlotManager already destroys the old itemPart outright.
function Effects.AttachPlacedGlow(part, color)
	local attachment = Instance.new("Attachment")
	attachment.Parent = part

	local emitter = Instance.new("ParticleEmitter")
	emitter.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	emitter.Color = ColorSequence.new(color)
	emitter.Lifetime = NumberRange.new(1.0, 1.6)
	emitter.Speed = NumberRange.new(1.5, 3)
	emitter.SpreadAngle = Vector2.new(180, 180)
	-- Rate/Size/LightEmission/starting-Transparency tuned up from an initial
	-- pass that was confirmed (via a cranked-up debug emitter) to render
	-- fine but was too faint to read at normal play distance — matches the
	-- "bright, big, no dull colors" standing art direction instead of a
	-- barely-there ambient hint.
	emitter.Rate = 16
	emitter.LightEmission = 0.75
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.65),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.05),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Parent = attachment
end

-- A Secret car on a pet pad. Its rarity colour is near-black, which glows
-- nothing, so it gets a light glow of its own instead of the tinted
-- sparkle: a soft white light, a silver halo on the floor under it, and
-- stars drifting up off its whole body. `tint` (a mutation's colour, or
-- nil) tints the stars. Like the glow above, it all lives and dies with the
-- part.
function Effects.AttachSecretAura(part, tint)
	local light = Instance.new("PointLight")
	light.Name = "SecretGlow"
	light.Color = Color3.fromRGB(235, 240, 255)
	light.Brightness = 1.2
	light.Range = math.clamp(part.Size.Magnitude * 0.8, 10, 18)
	light.Shadows = false
	light.Parent = part

	-- Two flat neon discs, welded on so they move with the car: a faint
	-- wide ring and a brighter middle.
	local across = math.max(part.Size.X, part.Size.Z) * 0.95
	for _, disc in ipairs({
		{ name = "SecretHaloOuter", size = across, alpha = 0.75, y = 0.04, color = Color3.fromRGB(205, 210, 255) },
		{ name = "SecretHaloInner", size = across * 0.8, alpha = 0.55, y = 0.06, color = Color3.fromRGB(245, 246, 255) },
	}) do
		local halo = Instance.new("Part")
		halo.Name = disc.name
		halo.Shape = Enum.PartType.Cylinder
		halo.Material = Enum.Material.Neon
		halo.Color = disc.color
		halo.Transparency = disc.alpha
		halo.Size = Vector3.new(0.06, disc.size, disc.size)
		halo.CanCollide, halo.CanQuery, halo.CanTouch, halo.CastShadow = false, false, false, false
		halo.Massless = true
		halo.CFrame = part.CFrame * CFrame.new(0, -part.Size.Y / 2 + disc.y, 0) * CFrame.Angles(0, 0, math.pi / 2)
		local weld = Instance.new("WeldConstraint")
		weld.Part0, weld.Part1 = part, halo
		weld.Parent = halo
		halo.Parent = part
	end

	-- On the part itself, not an attachment, so the stars rise from
	-- anywhere on the car's body rather than one point in its middle.
	local stars = Instance.new("ParticleEmitter")
	stars.Name = "SecretStars"
	stars.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	stars.Color = ColorSequence.new(Color3.new(1, 1, 1), tint or Color3.fromRGB(165, 180, 255))
	-- Low light emission: a bright additive sparkle vanishes against the
	-- garage's white floor and walls.
	stars.LightEmission = 0.35
	stars.Rate = 28
	stars.Lifetime = NumberRange.new(1.2, 2)
	stars.Speed = NumberRange.new(1, 2.5)
	stars.EmissionDirection = Enum.NormalId.Top
	stars.SpreadAngle = Vector2.new(25, 25)
	stars.Acceleration = Vector3.new(0, 1.5, 0)
	stars.Rotation = NumberRange.new(0, 360)
	stars.RotSpeed = NumberRange.new(-60, 60)
	stars.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.3),
		NumberSequenceKeypoint.new(0.3, 1),
		NumberSequenceKeypoint.new(1, 0),
	})
	stars.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	})
	stars.Parent = part
end

-- One aura per rarity for a car on a pad, so each rarity reads differently
-- at a glance and not just in a different colour (user, 2026-10-05: "give
-- each rarity of car their own aura"). All of it lives and dies with the
-- part, like the glow above. Built only from Roblox's own particle
-- textures. `rarity` is a FusionRecipes rarity key; the Secret cars keep
-- AttachSecretAura.
local TEXTURES = "rbxasset://textures/particles/"

local function emitter(parent, props)
	local e = Instance.new("ParticleEmitter")
	for key, value in pairs(props) do
		e[key] = value
	end
	e.Parent = parent
	return e
end

local function fade(from, to)
	return NumberSequence.new({ NumberSequenceKeypoint.new(0, from), NumberSequenceKeypoint.new(1, to) })
end

local function grow(from, peak, to)
	return NumberSequence.new({
		NumberSequenceKeypoint.new(0, from),
		NumberSequenceKeypoint.new(0.35, peak),
		NumberSequenceKeypoint.new(1, to),
	})
end

local function glowLight(part, name, color, brightness, range)
	local light = Instance.new("PointLight")
	light.Name = name
	light.Color = color
	light.Brightness = brightness
	light.Range = range
	light.Shadows = false
	light.Parent = part
end

-- A part welded to the car that moves with it and touches nothing.
local function welded(part, name, props)
	local p = Instance.new("Part")
	p.Name = name
	p.CanCollide, p.CanQuery, p.CanTouch, p.CastShadow = false, false, false, false
	p.Massless = true
	p.Anchored = false
	for key, value in pairs(props) do
		p[key] = value
	end
	local weld = Instance.new("WeldConstraint")
	weld.Part0, weld.Part1 = part, p
	weld.Parent = p
	p.Parent = part
	return p
end

-- A point on the floor under the middle of the car, to emit from.
local function floorPoint(part, name)
	local a = Instance.new("Attachment")
	a.Name = name
	a.Position = Vector3.new(0, -part.Size.Y / 2 + 0.15, 0)
	a.Parent = part
	return a
end

local RAINBOW = ColorSequence.new({
	ColorSequenceKeypoint.new(0, Color3.fromRGB(255, 80, 80)),
	ColorSequenceKeypoint.new(0.2, Color3.fromRGB(255, 190, 60)),
	ColorSequenceKeypoint.new(0.4, Color3.fromRGB(120, 255, 110)),
	ColorSequenceKeypoint.new(0.6, Color3.fromRGB(80, 220, 255)),
	ColorSequenceKeypoint.new(0.8, Color3.fromRGB(140, 110, 255)),
	ColorSequenceKeypoint.new(1, Color3.fromRGB(255, 110, 230)),
})

local AURAS = {}

-- Common (the base cars): a little workshop dust drifting off the floor.
function AURAS.common(part)
	emitter(part, {
		Name = "AuraDust", Texture = TEXTURES .. "smoke_main.dds",
		Color = ColorSequence.new(Color3.fromRGB(200, 200, 206)),
		Rate = 3, Lifetime = NumberRange.new(2, 3), Speed = NumberRange.new(0.4, 1),
		EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(40, 40),
		Size = grow(0.8, 2, 2.6), Transparency = fade(0.65, 1), LightEmission = 0,
	})
end

-- Uncommon: green sparks fizzing up off the body, and a faint green floor.
function AURAS.uncommon(part)
	local green = Color3.fromRGB(90, 220, 120)
	emitter(part, {
		Name = "AuraSparks", Texture = TEXTURES .. "sparkles_main.dds",
		Color = ColorSequence.new(green, Color3.fromRGB(200, 255, 200)),
		Rate = 22, Lifetime = NumberRange.new(1.1, 1.7), Speed = NumberRange.new(1.5, 3),
		EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(30, 30),
		Acceleration = Vector3.new(0, 1, 0),
		Size = fade(1.1, 0), Transparency = fade(0, 1), LightEmission = 0.3,
	})
	glowLight(part, "AuraLight", green, 0.8, 10)
end

-- Rare: blue rings rippling out across the floor from under the car.
function AURAS.rare(part)
	local blue = Color3.fromRGB(90, 170, 255)
	local across = math.max(part.Size.X, part.Size.Z)
	emitter(floorPoint(part, "AuraFloor"), {
		Name = "AuraRipples", Texture = TEXTURES .. "explosion01_shockwave_main.dds",
		Color = ColorSequence.new(blue), Rate = 2, Lifetime = NumberRange.new(1.8),
		Speed = NumberRange.new(0.01), EmissionDirection = Enum.NormalId.Top,
		Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
		Size = fade(across * 0.4, across * 1.4), Transparency = fade(0, 1), LightEmission = 0.3,
	})
	emitter(part, {
		Name = "AuraGlints", Texture = TEXTURES .. "sparkles_main.dds",
		Color = ColorSequence.new(blue, Color3.fromRGB(210, 235, 255)),
		Rate = 14, Lifetime = NumberRange.new(1, 1.5), Speed = NumberRange.new(1, 2),
		EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(25, 25),
		Size = fade(1, 0), Transparency = fade(0, 1), LightEmission = 0.3,
	})
	glowLight(part, "AuraLight", blue, 1.2, 12)
end

-- Epic: a purple vortex turning round the car.
function AURAS.epic(part)
	local purple = Color3.fromRGB(190, 110, 255)
	local across = math.max(part.Size.X, part.Size.Z)
	emitter(part, {
		Name = "AuraVortex", Texture = TEXTURES .. "forcefield_vortex_main.dds",
		Color = ColorSequence.new(purple), Rate = 6, Lifetime = NumberRange.new(1.4, 1.8),
		Speed = NumberRange.new(0), Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(160, 220),
		Size = grow(across * 0.5, across * 0.9, across * 1), Transparency = fade(0.2, 1),
		LightEmission = 0.4, LockedToPart = true,
	})
	emitter(part, {
		Name = "AuraMotes", Texture = TEXTURES .. "sparkles_main.dds",
		Color = ColorSequence.new(purple, Color3.fromRGB(240, 210, 255)),
		Rate = 12, Lifetime = NumberRange.new(1, 1.5), Speed = NumberRange.new(1, 2),
		EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(180, 180),
		Size = fade(0.9, 0), Transparency = fade(0, 1), LightEmission = 0.3,
	})
	glowLight(part, "AuraLight", purple, 1.1, 12)
end

-- Mythic: red flames licking up round the car, and embers.
function AURAS.mythic(part)
	local red = Color3.fromRGB(255, 70, 50)
	emitter(part, {
		Name = "AuraFlames", Texture = TEXTURES .. "fire_main.dds",
		Color = ColorSequence.new(Color3.fromRGB(255, 150, 60), red),
		Rate = 12, Lifetime = NumberRange.new(0.6, 1), Speed = NumberRange.new(2.5, 4.5),
		EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(10, 10),
		Size = grow(1.6, 2.6, 0.4), Transparency = fade(0.25, 1), LightEmission = 0.6,
	})
	emitter(part, {
		Name = "AuraEmbers", Texture = TEXTURES .. "fire_sparks_main.dds",
		Color = ColorSequence.new(Color3.fromRGB(255, 190, 90)),
		Rate = 10, Lifetime = NumberRange.new(1, 1.6), Speed = NumberRange.new(2, 4),
		EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(25, 25),
		Acceleration = Vector3.new(0, 2, 0),
		Size = fade(0.7, 0), Transparency = fade(0, 1), LightEmission = 0.8,
	})
	glowLight(part, "AuraLight", red, 1.3, 13)
end

-- Legendary: a pillar of golden light, and gold glitter showering down.
function AURAS.legendary(part)
	local gold = Color3.fromRGB(255, 221, 51)
	local across = math.max(part.Size.X, part.Size.Z)
	local height = 16
	welded(part, "AuraPillar", {
		Shape = Enum.PartType.Cylinder, Material = Enum.Material.Neon, Color = gold, Transparency = 0.86,
		Size = Vector3.new(height, across * 0.85, across * 0.85),
		CFrame = part.CFrame * CFrame.new(0, -part.Size.Y / 2 + height / 2, 0) * CFrame.Angles(0, 0, math.pi / 2),
	})
	local top = Instance.new("Attachment")
	top.Name = "AuraTop"
	top.Position = Vector3.new(0, -part.Size.Y / 2 + height - 1, 0)
	top.Parent = part
	emitter(top, {
		Name = "AuraGlitter", Texture = TEXTURES .. "sparkles_main.dds",
		Color = ColorSequence.new(gold, Color3.new(1, 1, 1)),
		Rate = 22, Lifetime = NumberRange.new(1.6, 2.2), Speed = NumberRange.new(2, 4),
		EmissionDirection = Enum.NormalId.Bottom, SpreadAngle = Vector2.new(18, 18),
		Size = fade(0.9, 0.2), Transparency = fade(0, 1), LightEmission = 0.5,
		Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-90, 90),
	})
	glowLight(part, "AuraLight", gold, 1.6, 16)
end

-- Godly: rainbow rings rippling out and rainbow stars rising.
function AURAS.godly(part)
	local across = math.max(part.Size.X, part.Size.Z)
	emitter(floorPoint(part, "AuraFloor"), {
		Name = "AuraRipples", Texture = TEXTURES .. "explosion01_shockwave_main.dds",
		Color = RAINBOW, Rate = 1.6, Lifetime = NumberRange.new(2),
		Speed = NumberRange.new(0.01), EmissionDirection = Enum.NormalId.Top,
		Orientation = Enum.ParticleOrientation.VelocityPerpendicular,
		Size = fade(across * 0.4, across * 1.4), Transparency = fade(0, 1), LightEmission = 0.4,
	})
	emitter(part, {
		Name = "AuraStars", Texture = TEXTURES .. "sparkles_main.dds",
		Color = RAINBOW, Rate = 24, Lifetime = NumberRange.new(1.3, 2),
		Speed = NumberRange.new(1.5, 3), EmissionDirection = Enum.NormalId.Top, SpreadAngle = Vector2.new(30, 30),
		Acceleration = Vector3.new(0, 1.5, 0), Rotation = NumberRange.new(0, 360), RotSpeed = NumberRange.new(-80, 80),
		Size = grow(0.4, 1.2, 0), Transparency = fade(0, 1), LightEmission = 0.4,
	})
	glowLight(part, "AuraLight", Color3.fromRGB(150, 255, 245), 1.6, 16)
end

-- Gives a car on a pad its rarity's aura. False for a rarity with none (the
-- caller falls back to the plain tinted glow).
function Effects.AttachRarityAura(part, rarity)
	local build = AURAS[rarity]
	if not build then
		return false
	end
	build(part)
	return true
end

return Effects
