-- Cosmetic only. Clients build these on world copies; templates, physics and data stay untouched.
local Recipes = require(script.Parent:WaitForChild("FusionRecipes"))
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
local function attachment(root, position)
	local a = Instance.new("Attachment")
	a.Name = "AddonFX"; a.Position = position; a.Parent = root
	return a
end
function Effects.Supports(name)
	return results[name] ~= nil
end
function Effects.Attach(root)
	local entry = results[root.Name]
	if not entry or not root:IsA("BasePart") then return nil end
	local profile = profiles[entry.addon]
	if not profile then return nil end
	local rank = Recipes.RarityIndex[entry.rarity] or 2
	local state = {root = root, profile = profile, rank = rank, attachments = {}, emitters = {}, beams = {}, anchors = {}, active = false}
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
		p.Enabled = false; p.Parent = a; table.insert(state.emitters,p)
	end
	-- Only the top energy addons get orbiting ribbons. Lower rarities retain clear silhouettes.
	if profile.kind == "warp" or profile.kind == "plasma" or profile.kind == "hover" then
		state.orbit = {}
		for i=1,12 do
			local a=attachment(root,Vector3.zero); table.insert(state.attachments,a); table.insert(state.orbit,a)
		end
		for i=1,12 do
			local b=Instance.new("Beam"); b.Name="AddonOrbit"
			b.Attachment0=state.orbit[i]; b.Attachment1=state.orbit[i%12+1]
			b.Color=ColorSequence.new(profile.color,Color3.fromRGB(75,235,255)); b.FaceCamera=true
			b.Width0=.025; b.Width1=.025; b.LightEmission=1; b.Segments=8
			b.Transparency=NumberSequence.new(.4); b.Enabled=false; b.Parent=state.orbit[i]; table.insert(state.beams,b)
		end
	end
	return state
end
function Effects.SetActive(state, active)
	if state.active == active then return end
	state.active=active
	for _,p in state.emitters do p.Enabled=active; if not active then p:Clear() end end
	for _,b in state.beams do b.Enabled=active end
end
function Effects.Step(state, time)
	local size=state.root.Size
	local scale=math.clamp(size.Z/6,.3,3)
	if state.lastSize ~= size then
	state.lastSize = size
	for _,item in state.anchors do item.a.Position=item.offset*size end
	for _,p in state.emitters do
		p.Speed=NumberRange.new(.3*scale,1.2*scale)
		p.Size=NumberSequence.new({NumberSequenceKeypoint.new(0,.06*scale),NumberSequenceKeypoint.new(.35,(.09+state.rank*.015)*scale),NumberSequenceKeypoint.new(1,0)})
	end
	end
	if state.orbit then
		local tangents = {}
		for i,a in state.orbit do
			local t=i/12*math.pi*2+time*(state.profile.kind=="warp" and 1.8 or .9)
			local hover=state.profile.kind=="hover"
			local y=hover and -.35 or -.08+math.sin(t*2)*.12
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
