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

return Effects
