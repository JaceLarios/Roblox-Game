--[[
	CoilAura (ModuleScript, ServerStorage) — Junkyard Fusion

	The blue aura a player wears while their Speed Coil is out. Built on the
	server so everyone sees it. Same controller/view split as FusionEffects:
	PlotManager decides when (the coil's Equipped and Unequipped), this
	decides how it looks.

	Three layers, all moving all the time:
	  - sparks rising off an invisible shell around the body, spinning as
	    they go, so the aura hugs the whole character;
	  - soft blue wisps that stay where they were made, so running leaves a
	    short streak behind you;
	  - a blue light, so the aura glows on the ground and walls around you.
--]]

local Debris = game:GetService("Debris")

local CoilAura = {}

local NAME = "CoilAura"
local BLUE = Color3.fromRGB(70, 175, 255)
local DEEP = Color3.fromRGB(35, 100, 255)
local PALE = Color3.fromRGB(175, 225, 255)

local SPARK_TEXTURE = "rbxasset://textures/particles/sparkles_main.dds"
local WISP_TEXTURE = "rbxasset://textures/particles/smoke_main.dds"

-- How long the last particles get to fade after the coil is put away,
-- rather than the whole aura vanishing mid-spark.
local FADE_SECONDS = 1

function CoilAura.Attach(character)
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not root or character:FindFirstChild(NAME) then return end

	-- A cylinder a little wider than the body, from the shins to the top of
	-- the head. The sparks come off its surface, not from one point, which
	-- is what makes it read as an aura around the player.
	local shell = Instance.new("Part")
	shell.Name = NAME
	shell.Size = Vector3.new(3.4, 5.2, 3.4)
	shell.Transparency = 1
	shell.CanCollide = false
	shell.CanQuery = false
	shell.CanTouch = false
	shell.Massless = true
	shell.CastShadow = false
	shell.CFrame = root.CFrame * CFrame.new(0, -0.4, 0)
	shell.Parent = character

	local weld = Instance.new("WeldConstraint")
	weld.Part0 = root
	weld.Part1 = shell
	weld.Parent = shell

	local sparks = Instance.new("ParticleEmitter")
	sparks.Name = "Sparks"
	sparks.Texture = SPARK_TEXTURE
	sparks.Shape = Enum.ParticleEmitterShape.Cylinder
	sparks.ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface
	sparks.ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward
	sparks.EmissionDirection = Enum.NormalId.Top
	sparks.Color = ColorSequence.new(PALE, DEEP)
	sparks.LightEmission = 1
	sparks.LightInfluence = 0
	sparks.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.45),
		NumberSequenceKeypoint.new(1, 0.05),
	})
	sparks.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(0.7, 0.35),
		NumberSequenceKeypoint.new(1, 1),
	})
	sparks.Lifetime = NumberRange.new(0.6, 1.1)
	sparks.Rate = 45
	sparks.Speed = NumberRange.new(0.3, 1.2)
	sparks.Acceleration = Vector3.new(0, 6, 0)
	sparks.Rotation = NumberRange.new(0, 360)
	sparks.RotSpeed = NumberRange.new(-220, 220)
	sparks.Parent = shell

	local wisps = Instance.new("ParticleEmitter")
	wisps.Name = "Wisps"
	wisps.Texture = WISP_TEXTURE
	wisps.Shape = Enum.ParticleEmitterShape.Cylinder
	wisps.ShapeStyle = Enum.ParticleEmitterShapeStyle.Volume
	wisps.EmissionDirection = Enum.NormalId.Top
	wisps.Color = ColorSequence.new(BLUE)
	wisps.LightEmission = 0.9
	wisps.LightInfluence = 0
	wisps.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1.2),
		NumberSequenceKeypoint.new(1, 2.6),
	})
	wisps.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.6),
		NumberSequenceKeypoint.new(1, 1),
	})
	wisps.Lifetime = NumberRange.new(0.45, 0.8)
	wisps.Rate = 16
	wisps.Speed = NumberRange.new(0.2, 0.7)
	wisps.Acceleration = Vector3.new(0, 3, 0)
	wisps.Rotation = NumberRange.new(0, 360)
	wisps.RotSpeed = NumberRange.new(-90, 90)
	wisps.Parent = shell

	local light = Instance.new("PointLight")
	light.Color = BLUE
	light.Brightness = 2
	light.Range = 9
	light.Shadows = false
	light.Parent = shell
end

function CoilAura.Detach(character)
	local shell = character and character:FindFirstChild(NAME)
	if not shell then return end
	-- Stop making new particles and let the ones in the air finish, then
	-- clean up. Renamed first so a quick re-equip builds a fresh aura
	-- instead of finding this fading one.
	shell.Name = NAME .. "Fading"
	for _, child in ipairs(shell:GetChildren()) do
		if child:IsA("ParticleEmitter") then
			child.Enabled = false
		elseif child:IsA("PointLight") then
			child.Enabled = false
		end
	end
	Debris:AddItem(shell, FADE_SECONDS)
end

return CoilAura
