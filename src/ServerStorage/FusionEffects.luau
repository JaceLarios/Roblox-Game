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

return Effects
