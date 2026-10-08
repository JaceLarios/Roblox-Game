-- Cosmetic only. Clients build these on world copies; templates, physics and data stay untouched.
local Recipes = require(script.Parent:WaitForChild("FusionRecipes"))
local EventAddons = require(script.Parent:WaitForChild("EventAddons"))
local Effects = {}
local results = {}
for _, car in Recipes.BaseItems do
	if not car.isAddon then
		for _, addon in Recipes.Addons do
			local name = Recipes.Fuse(car.name, addon.name)
			if name then results[name] = {addon = addon.name, rarity = addon.rarity} end
		end
	end
end
local profiles = {
	["Nitrous Tank"] = {color = Color3.fromRGB(65, 185, 255), kind = "exhaust"},
	["Straight Pipes"] = {color = Color3.fromRGB(255, 169, 80), kind = "exhaust"},
	["Scrap Turbo"] = {color = Color3.fromRGB(130, 230, 180), kind = "exhaust"},
	["Inline 4"] = {color = Color3.fromRGB(255, 193, 75), kind = "engine"},
	["Rotary Engine"] = {color = Color3.fromRGB(245, 120, 245), kind = "engine"},
	["Twin Turbo"] = {color = Color3.fromRGB(95, 210, 255), kind = "exhaust"},
	["V6 Engine"] = {color = Color3.fromRGB(255, 135, 55), kind = "engine"},
	["Supercharger"] = {color = Color3.fromRGB(255, 210, 70), kind = "engine"},
	["Diesel Stack"] = {color = Color3.fromRGB(110, 114, 125), kind = "smoke"},
	["V8 Engine"] = {color = Color3.fromRGB(255, 85, 65), kind = "engine"},
	["V12 Engine"] = {color = Color3.fromRGB(255, 190, 65), kind = "engine"},
	["Hover Fans"] = {color = Color3.fromRGB(85, 255, 215), kind = "hover"},
	["Jet Engine"] = {color = Color3.fromRGB(90, 165, 255), kind = "exhaust"},
	["Rocket Booster"] = {color = Color3.fromRGB(255, 140, 40), kind = "exhaust"},
	["Fusion Core"] = {color = Color3.fromRGB(65, 240, 255), kind = "plasma"},
	["Warp Drive"] = {color = Color3.fromRGB(170, 100, 255), kind = "warp"},
}
-- The Phantom addons: every ghost car (an EventAddon on its root, see
-- EventAddons) shows its Phantom's own effect, as well as its own addon's.
-- `at` is a point on the car as a fraction of its size (front is +Z, so the
-- back is -Z), `mirror` adds the same on the other side, "wheels" puts one on
-- every wheel. `dir` is the way particles leave ("Front" is backwards out of
-- the car, "Back" forwards, "Side" outwards). Sizes, speeds and `lift` are
-- for a 6-stud-long car and scale with it. `perp` turns rings to face their
-- direction of travel (sound waves, smoke rings).
local MINT, WISP, VIOLET = Color3.fromRGB(150, 255, 210), Color3.fromRGB(159, 216, 255), Color3.fromRGB(197, 139, 255)
local ECTO, GLOW, BONE = Color3.fromRGB(90, 255, 150), Color3.fromRGB(170, 90, 255), Color3.fromRGB(235, 255, 245)
local phantoms = {
	["Will-o'-Wisp Lanterns"] = { -- wisps drifting up off the lanterns
		{at = Vector3.new(.3, .45, .3), mirror = true, texture = "sparkles_main.dds", color = MINT, color2 = WISP, rate = 4.5, life = {1.4, 2.2}, speed = {.4, .8}, size = {.54, .78, 0}, alpha = .1, lift = .3, drag = 1, spread = 35},
	},
	["Phantom Exhaust"] = { -- ectoplasm smoke rings puffed out of the back
		{at = Vector3.new(.2, -.18, -.5), mirror = true, texture = "explosion01_shockwave_main.dds", color = MINT, dir = "Front", rate = 2.4, life = {.9, 1.2}, speed = {2, 3}, size = {.5, 1.6}, alpha = .1, drag = 1.5, spread = 8, perp = true},
		{at = Vector3.new(.2, -.18, -.5), mirror = true, texture = "smoke_main.dds", color = MINT, color2 = BONE, dir = "Front", rate = 6, life = {.6, 1}, speed = {1, 1.6}, size = {.4, 1.1}, alpha = .5, light = .4, lift = .6, spread = 18},
	},
	["Crystal Ball Ornament"] = { -- violet rings orbiting the car, motes over the ball
		{orbit = true, color = VIOLET, color2 = MINT, height = .2},
		{at = Vector3.new(0, .5, 0), texture = "sparkles_main.dds", color = VIOLET, color2 = GLOW, rate = 6, life = {1, 1.6}, speed = {.3, .7}, size = {.36, .6, 0}, alpha = .1, spread = 60},
	},
	["Graveyard Grille"] = { -- graveyard fog creeping out all round the car
		{at = Vector3.new(0, -.46, .45), texture = "smoke_main.dds", color = MINT, rate = 3.75, life = {2.5, 3.5}, speed = {.3, .6}, size = {1, 2.6}, alpha = .65, light = .35, lift = .05, drag = .5, spread = 85},
		{at = Vector3.new(0, -.46, -.45), texture = "smoke_main.dds", color = MINT, rate = 3.75, life = {2.5, 3.5}, speed = {.3, .6}, size = {1, 2.6}, alpha = .65, light = .35, lift = .05, drag = .5, spread = 85},
		{at = Vector3.new(.45, -.46, 0), mirror = true, texture = "smoke_main.dds", color = MINT, rate = 3, life = {2.5, 3.5}, speed = {.3, .6}, size = {1, 2.6}, alpha = .65, light = .35, lift = .05, drag = .5, spread = 85},
	},
	["Ecto Tank"] = { -- bubbles rising out of the tank, drips underneath
		{at = Vector3.new(0, .35, -.15), texture = "sparkles_main.dds", color = ECTO, color2 = MINT, rate = 9, life = {1.2, 2}, speed = {.6, 1.2}, size = {.3, .48, 0}, alpha = 0, lift = .4, spread = 20},
		{at = Vector3.new(0, -.45, 0), texture = "sparkles_main.dds", color = ECTO, dir = "Bottom", rate = 3, life = {.4, .6}, speed = {.4, .6}, size = {.36, 0}, alpha = .1, spread = 30},
	},
	["Banshee Horn"] = { -- violet sound waves wailing out of the front
		{at = Vector3.new(0, .3, .5), texture = "explosion01_shockwave_main.dds", color = VIOLET, color2 = GLOW, dir = "Back", rate = 2.1, life = {.7, .9}, speed = {2.5, 3.5}, size = {.4, 2}, alpha = .2, spread = 0, perp = true},
		{at = Vector3.new(0, .3, .5), texture = "smoke_main.dds", color = VIOLET, dir = "Back", rate = 4.5, life = {.6, .9}, speed = {1, 2}, size = {.4, 1}, alpha = .55, light = .6, spread = 15},
	},
	["Poltergeist Spoiler"] = { -- the spoiler rattles, sparks flying, things floating up
		{at = Vector3.new(0, .42, -.42), texture = "sparkles_main.dds", color = VIOLET, rate = 10.5, life = {.3, .6}, speed = {1.5, 3}, size = {.3, 0}, alpha = 0, spread = 180},
		{at = Vector3.new(.35, .5, -.42), mirror = true, texture = "sparkles_main.dds", color = GLOW, color2 = VIOLET, rate = 2.25, life = {1.5, 2.5}, speed = {.2, .5}, size = {.42, .6, 0}, alpha = .1, lift = .2, spread = 40},
	},
	["Coffin Carrier"] = { -- ectoplasm leaking out of the coffin
		{at = Vector3.new(0, .5, 0), texture = "smoke_main.dds", color = MINT, rate = 4.5, life = {1.2, 1.8}, speed = {.3, .7}, size = {.4, 1.2}, alpha = .55, light = .7, lift = .3, spread = 25},
		{at = Vector3.new(0, .5, 0), texture = "sparkles_main.dds", color = ECTO, rate = 3, life = {1, 1.5}, speed = {.2, .5}, size = {.42, 0}, alpha = .1, spread = 40},
	},
	["Witch's Cauldron"] = { -- the brew bubbling over green flames
		{at = Vector3.new(0, .45, 0), texture = "sparkles_main.dds", color = VIOLET, color2 = GLOW, rate = 9, life = {.8, 1.4}, speed = {.6, 1.2}, size = {.42, .66, 0}, alpha = .1, lift = .5, spread = 25},
		{at = Vector3.new(0, .42, 0), texture = "fire_main.dds", color = ECTO, color2 = MINT, rate = 9, life = {.3, .5}, speed = {.5, 1}, size = {.5, 0}, alpha = .2, spread = 15},
	},
	["Specter Sails"] = { -- a ghostly wake behind the ship, wisps round the masts
		{at = Vector3.new(0, .3, -.5), texture = "smoke_main.dds", color = BONE, color2 = MINT, dir = "Front", rate = 7.5, life = {1.4, 2}, speed = {1, 2}, size = {.6, 2.2}, alpha = .6, light = .5, lift = .2, spread = 25},
		{at = Vector3.new(0, .5, 0), texture = "sparkles_main.dds", color = MINT, rate = 3, life = {1.5, 2.5}, speed = {.2, .4}, size = {.45, 0}, alpha = .1, spread = 70},
	},
	["Wraith Wheels"] = { -- blue ghost fire burning on every wheel
		{at = "wheels", texture = "fire_main.dds", color = WISP, color2 = Color3.fromRGB(90, 160, 255), rate = 18, life = {.5, .8}, speed = {1, 2}, size = {1.2, .2}, alpha = 0, lift = 1.5, spread = 20},
		{at = "wheels", texture = "fire_sparks_main.dds", color = WISP, rate = 6, life = {.5, .9}, speed = {1, 2}, size = {.35, 0}, alpha = 0, spread = 40},
	},
	["Soul Turbo"] = { -- a soul vortex at the back, souls streaming out of it
		{at = Vector3.new(0, .1, -.48), texture = "forcefield_vortex_main.dds", color = MINT, color2 = VIOLET, dir = "Front", rate = 3, life = {.8, 1.1}, speed = {.6, 1}, size = {1.4, 2.8}, alpha = .2, spin = 200, spread = 10},
		{at = Vector3.new(0, .1, -.48), texture = "sparkles_main.dds", color = BONE, dir = "Front", rate = 6, life = {.8, 1.2}, speed = {1.5, 2.5}, size = {.42, 0}, alpha = 0, spread = 25},
	},
	["Hearse Canopy"] = { -- slow mourning smoke, candle glints at the corners
		{at = Vector3.new(0, .5, 0), texture = "smoke_main.dds", color = Color3.fromRGB(70, 45, 110), color2 = Color3.fromRGB(30, 20, 45), rate = 4.5, life = {2, 3}, speed = {.3, .6}, size = {.6, 1.8}, alpha = .4, light = 0, lift = .2, spread = 40},
		{at = Vector3.new(.35, .5, .35), mirror = true, texture = "sparkles_main.dds", color = Color3.fromRGB(255, 215, 120), rate = 1.8, life = {.6, 1}, speed = {.2, .4}, size = {.3, 0}, alpha = 0, spread = 20},
		{at = Vector3.new(.35, .5, -.35), mirror = true, texture = "sparkles_main.dds", color = Color3.fromRGB(255, 215, 120), rate = 1.8, life = {.6, 1}, speed = {.2, .4}, size = {.3, 0}, alpha = 0, spread = 20},
	},
	["Reaper Scythes"] = { -- the scythes throw green sparks out to each side
		{at = Vector3.new(.5, -.1, 0), mirror = true, texture = "fire_sparks_main.dds", color = MINT, color2 = ECTO, dir = "Side", rate = 9, life = {.25, .45}, speed = {2, 3.5}, size = {.5, 0}, alpha = 0, spread = 35},
		{at = Vector3.new(.5, -.1, 0), mirror = true, texture = "sparkles_main.dds", color = MINT, dir = "Side", rate = 3, life = {.5, .8}, speed = {.3, .6}, size = {.48, 0}, alpha = .1, spread = 50},
	},
	["Ghost Chauffeur"] = { -- a ghost trail behind the driver
		{at = Vector3.new(0, .35, -.1), texture = "smoke_main.dds", color = BONE, color2 = MINT, dir = "Front", rate = 6, life = {1.2, 1.8}, speed = {.8, 1.4}, size = {.5, 1.6}, alpha = .55, light = .5, lift = .3, spread = 20},
		{at = Vector3.new(0, .45, .1), texture = "sparkles_main.dds", color = MINT, rate = 3.75, life = {1, 1.8}, speed = {.3, .6}, size = {.42, 0}, alpha = .1, spread = 50},
	},
}
local function attachment(root, position)
	local a = Instance.new("Attachment")
	a.Name = "AddonFX"; a.Position = position; a.Parent = root
	return a
end
local function keys(values)
	local points = {}
	for i, v in values do points[i] = NumberSequenceKeypoint.new(#values == 3 and (i == 2 and .35 or i == 3 and 1 or 0) or (i - 1), v) end
	return NumberSequence.new(points)
end
-- The Spectral rarity's aura: ghost mist curling off the car, wisps
-- drifting up round it and a mint glow. Earning pads get it from the server
-- (FusionEffects' AURAS.spectral calls this); everywhere else a Spectral car
-- gets its own copy here (phantomEffects). `scale` 1 is a car on a pad;
-- `prefix` goes in front of the part names.
function Effects.FitSpectralAura(aura, scale)
	aura.mist.Speed = NumberRange.new(.5 * scale, 1.2 * scale)
	aura.mist.Size = keys({1.5 * scale, 3 * scale, 4 * scale})
	aura.wisps.Speed = NumberRange.new(scale, 2 * scale)
	aura.wisps.Size = keys({.3 * scale, scale, 0})
	aura.wisps.Acceleration = Vector3.new(0, 1.2 * scale, 0)
	aura.light.Range = 16 * scale
end
function Effects.SpectralAura(part, scale, prefix)
	prefix = prefix or ""
	local mist = Instance.new("ParticleEmitter")
	mist.Name = prefix .. "AuraMist"; mist.Texture = "rbxasset://textures/particles/smoke_main.dds"
	mist.Color = ColorSequence.new(Color3.fromRGB(225, 255, 240), MINT)
	mist.Rate = 6; mist.Lifetime = NumberRange.new(2, 3)
	mist.EmissionDirection = Enum.NormalId.Top; mist.SpreadAngle = Vector2.new(50, 50)
	mist.Rotation = NumberRange.new(0, 360); mist.RotSpeed = NumberRange.new(-30, 30)
	mist.Transparency = keys({.55, 1}); mist.LightEmission = .2
	local wisps = Instance.new("ParticleEmitter")
	wisps.Name = prefix .. "AuraWisps"; wisps.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	wisps.Color = ColorSequence.new(MINT, Color3.fromRGB(205, 175, 255))
	wisps.Rate = 14; wisps.Lifetime = NumberRange.new(1.6, 2.4)
	wisps.EmissionDirection = Enum.NormalId.Top; wisps.SpreadAngle = Vector2.new(60, 60)
	wisps.Transparency = keys({0, 1}); wisps.LightEmission = .4
	local light = Instance.new("PointLight")
	light.Name = prefix .. "AuraLight"; light.Color = MINT; light.Brightness = 1.6; light.Shadows = false
	local aura = {mist = mist, wisps = wisps, light = light}
	Effects.FitSpectralAura(aura, scale or 1)
	mist.Parent = part; wisps.Parent = part; light.Parent = part
	return aura
end
-- The car's own Spectral aura, on while its effects are, except on an
-- earning pad, where the server's is already there.
local function showAura(state)
	local on = state.active and not state.root:FindFirstChild("AuraMist")
	local aura = state.aura
	if aura.mist.Enabled == on then return end
	for _, e in {aura.mist, aura.wisps} do e.Enabled = on; if not on then e:Clear() end end
	aura.light.Enabled = on
end
local function orbit(state, root, color0, color1)
	state.orbit = {}
	for i=1,12 do
		local a=attachment(root,Vector3.zero); table.insert(state.attachments,a); table.insert(state.orbit,a)
	end
	for i=1,12 do
		local b=Instance.new("Beam"); b.Name="AddonOrbit"
		b.Attachment0=state.orbit[i]; b.Attachment1=state.orbit[i%12+1]
		b.Color=ColorSequence.new(color0,color1); b.FaceCamera=true
		b.Width0=.025; b.Width1=.025; b.LightEmission=1; b.Segments=8
		b.Transparency=NumberSequence.new(.4); b.Enabled=false; b.Parent=state.orbit[i]; table.insert(state.beams,b)
	end
end
-- The top of each wheel's outer face as a fraction of the car's size, from
-- the axles ItemVisuals.Create leaves on the wheel parts (fire lit at the
-- axle would burn inside the tyre); the corners if it has none.
local function wheelPoints(root)
	local points, seen = {}, {}
	local visual = root:FindFirstChild("Visual")
	for _, p in visual and visual:GetDescendants() or {} do
		local pivot, radius = p:IsA("BasePart") and p:GetAttribute("RollPivot"), p:GetAttribute("RollRadius")
		local key = typeof(pivot) == "Vector3" and type(radius) == "number" and string.format("%.1f %.1f", pivot.X, pivot.Z)
		if key and not seen[key] then
			seen[key] = true
			local outside = math.sign(pivot.X) * (math.max(root.Size.X / 2 - math.abs(pivot.X), radius * .3) + radius * .2)
			table.insert(points, (pivot + Vector3.new(outside, radius * .6, 0)) / root.Size)
		end
	end
	if #points == 0 then
		for _, x in {-.42, .42} do for _, z in {-.3, .3} do table.insert(points, Vector3.new(x, -.3, z)) end end
	end
	return points
end
-- Adds a Phantom's effect and the Spectral aura to a car's state.
local function phantomEffects(state, root, specs)
	state.scaled = {}
	for _, spec in specs do
		if spec.orbit then
			-- One orbit a car: a Warp Drive build keeps its own.
			if not state.orbit then orbit(state, root, spec.color, spec.color2); state.orbitHeight = spec.height end
		else
			local points = spec.at == "wheels" and wheelPoints(root) or spec.mirror and {spec.at * Vector3.new(-1, 1, 1), spec.at} or {spec.at}
			for _, offset in points do
				local a = attachment(root, offset * root.Size)
				table.insert(state.attachments, a); table.insert(state.anchors, {a = a, offset = offset})
				local p = Instance.new("ParticleEmitter")
				p.Name = "PhantomAura"; p.Texture = "rbxasset://textures/particles/" .. spec.texture
				p.Color = ColorSequence.new(spec.color, spec.color2 or spec.color)
				p.LightEmission = spec.light or .9; p.LightInfluence = 0; p.Rate = spec.rate
				p.Lifetime = NumberRange.new(spec.life[1], spec.life[2])
				p.SpreadAngle = Vector2.new(spec.spread, spec.spread); p.Drag = spec.drag or 0
				local dir = spec.dir or "Top"
				if dir == "Side" then dir = offset.X < 0 and "Left" or "Right" end
				p.EmissionDirection = Enum.NormalId[dir]
				p.Transparency = keys({spec.alpha, (spec.alpha + 1) / 2, 1})
				p.Rotation = NumberRange.new(0, 360); p.RotSpeed = NumberRange.new(-(spec.spin or 60), spec.spin or 60)
				if spec.perp then p.Orientation = Enum.ParticleOrientation.VelocityPerpendicular end
				p.Enabled = false; p.Parent = a
				table.insert(state.emitters, p); table.insert(state.scaled, {p = p, spec = spec})
			end
		end
	end
	local aura = Effects.SpectralAura(root, 1, "Phantom")
	aura.mist.Enabled = false; aura.wisps.Enabled = false; aura.light.Enabled = false
	state.aura = aura
	table.insert(state.attachments, aura.mist); table.insert(state.attachments, aura.wisps); table.insert(state.attachments, aura.light)
end
function Effects.Supports(name)
	return results[name] ~= nil
end
-- A car in the world that has an effect: a build with an addon that has
-- one, or a ghost car.
function Effects.SupportsRoot(root)
	return results[root.Name] ~= nil or root:GetAttribute("EventAddon") ~= nil
end
function Effects.Attach(root)
	if not root:IsA("BasePart") then return nil end
	local entry = results[root.Name]
	local phantom = EventAddons.Addon(root:GetAttribute("EventAddon")) or (entry and phantoms[entry.addon] and entry.addon)
	local profile = entry and profiles[entry.addon]
	if not (profile or phantom) then return nil end
	local rank = Recipes.RarityIndex[entry and entry.rarity or "spectral"] or 2
	local state = {root = root, profile = profile or {kind = "phantom"}, rank = rank, attachments = {}, emitters = {}, plain = {}, beams = {}, anchors = {}, active = false}
	if not profile then phantomEffects(state, root, phantoms[phantom]) return state end
	local function anchor(offset)
		local a = attachment(root, offset * root.Size)
		table.insert(state.attachments, a); table.insert(state.anchors, {a = a, offset = offset})
		return a
	end
	local offsets
	if profile.kind == "hover" then offsets = {Vector3.new(-.38,-.35,0),Vector3.new(.38,-.35,0)}
	elseif profile.kind == "engine" then offsets = {Vector3.new(0,.12,.28)}
	elseif profile.kind == "smoke" then offsets = {Vector3.new(-.3,.4,-.25),Vector3.new(.3,.4,-.25)}
	elseif profile.kind == "warp" or profile.kind == "plasma" then offsets = {Vector3.new(-.38,.05,0),Vector3.new(.38,.05,0)}
	else offsets = {Vector3.new(-.26,-.16,-.48),Vector3.new(.26,-.16,-.48)} end
	for _, offset in offsets do
		local a = anchor(offset)
		local p = Instance.new("ParticleEmitter")
		p.Name = "AddonAura"; p.Texture = "rbxasset://textures/particles/" .. (profile.kind == "smoke" and "smoke_main.dds" or "sparkles_main.dds")
		p.Color = ColorSequence.new(profile.color, Color3.new(1,1,1))
		p.LightEmission = profile.kind == "smoke" and .05 or .8
		p.LightInfluence = 0; p.Rate = 2 + rank * 1.4
		p.Lifetime = NumberRange.new(.3,.65); p.Speed = NumberRange.new(.3,1.2)
		p.SpreadAngle = Vector2.new(24,24)
		p.EmissionDirection = profile.kind == "exhaust" and Enum.NormalId.Back or profile.kind == "hover" and Enum.NormalId.Bottom or Enum.NormalId.Top
		p.Size = NumberSequence.new({NumberSequenceKeypoint.new(0,.06),NumberSequenceKeypoint.new(.35,.15),NumberSequenceKeypoint.new(1,0)})
		p.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0,.3),NumberSequenceKeypoint.new(.7,.65),NumberSequenceKeypoint.new(1,1)})
		p.Rotation = NumberRange.new(0,360); p.RotSpeed = NumberRange.new(-80,80)
		p.Enabled = false; p.Parent = a; table.insert(state.emitters,p); table.insert(state.plain,p)
	end
	-- Only the top energy addons get orbiting ribbons. Lower rarities retain clear silhouettes.
	if profile.kind == "warp" or profile.kind == "plasma" or profile.kind == "hover" then
		orbit(state, root, profile.color, Color3.fromRGB(75,235,255))
	end
	if phantom then phantomEffects(state, root, phantoms[phantom]) end
	return state
end
function Effects.SetActive(state, active)
	if state.active == active then return end
	state.active=active
	for _,p in state.emitters do p.Enabled=active; if not active then p:Clear() end end
	for _,b in state.beams do b.Enabled=active end
	if state.aura then showAura(state) end
end
function Effects.Step(state, time)
	local size=state.root.Size
	local scale=math.clamp(size.Z/6,.3,3)
	if state.lastSize ~= size then
	state.lastSize = size
	for _,item in state.anchors do item.a.Position=item.offset*size end
	if state.aura then Effects.FitSpectralAura(state.aura,math.clamp(size.Z/7.5,.35,1.5)) end
	for _,item in state.scaled or {} do
		local spec,sizes=item.spec,{}
		for i,v in spec.size do sizes[i]=v*scale end
		item.p.Speed=NumberRange.new(spec.speed[1]*scale,spec.speed[2]*scale)
		item.p.Size=keys(sizes)
		item.p.Acceleration=Vector3.new(0,(spec.lift or 0)*scale,0)
	end
	for _,p in state.plain do
		p.Speed=NumberRange.new(.3*scale,1.2*scale)
		p.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,.06*scale),NumberSequenceKeypoint.new(.35,(.09+state.rank*.015)*scale),NumberSequenceKeypoint.new(1,0)})
	end
	end
	-- A car only just put on a pad may get the server's aura after its own.
	if state.aura and time>=(state.auraCheck or 0) then state.auraCheck=time+.5;showAura(state) end
	if state.orbit then
		local tangents = {}
		for i,a in state.orbit do
			local t=i/12*math.pi*2+time*(state.profile.kind=="warp" and 1.8 or .9)
			local hover=state.profile.kind=="hover"
			local y=hover and -.35 or (state.orbitHeight or -.08)+math.sin(t*2)*.12
			local position=Vector3.new(math.cos(t)*size.X*.62,size.Y*y,math.sin(t)*size.Z*.61)
			local tangent=Vector3.new(-math.sin(t)*size.X*.62,hover and 0 or math.cos(t*2)*size.Y*.24,math.cos(t)*size.Z*.61)
			local x=tangent.Unit;local z=x:Cross(Vector3.yAxis).Unit;local up=z:Cross(x)
			a.CFrame=CFrame.fromMatrix(position,x,up,z)
			tangents[i]=tangent.Magnitude*math.pi*2/12/3
		end
		for i,b in state.beams do b.Width0=.035*scale; b.Width1=.035*scale;b.CurveSize0=tangents[i];b.CurveSize1=tangents[i%12+1] end
	end
end
function Effects.Destroy(state)
	for _,a in state.attachments do a:Destroy() end
end
return Effects
