-- Client-only cosmetic controller. Never changes the vehicle root or its welds.
local HoverVisuals = {}
local Controllers = setmetatable({}, {__mode = 'k'})

function HoverVisuals.Sample(t, speed, steer, scale)
 speed = math.clamp(speed or 0, 0, 1)
 steer = math.clamp(steer or 0, -1, 1)
 scale = scale or 1
 local bob = (.13 + .04 * speed) * math.sin(t * 2.5) * scale
 local sway = math.rad(1.3) * math.sin(t * 1.6)
 return CFrame.new(0, bob, 0) * CFrame.Angles(math.rad(-2.5) * speed, 0, sway - math.rad(7) * steer),
  .5 + .5 * math.sin(t * 3.6), speed
end

function HoverVisuals.Attach(root, source)
 assert(root:IsA('BasePart') and source:IsA('Model'), 'Expected vehicle root and visual Model')
 if Controllers[root] then return Controllers[root] end
 local clone = source:Clone()
 clone.Name = 'AtomHoverCosmetic'
 local hidden, disabled, parts, originals = {}, {}, {}, {}
 for _, o in clone:GetDescendants() do
  if o:IsA('LuaSourceContainer') or o:IsA('JointInstance') or o:IsA('Constraint') or o:IsA('BodyMover') then o:Destroy()
  elseif o:IsA('BasePart') then
   o.Anchored = true; o.CanCollide = false; o.CanTouch = false; o.CanQuery = false
   o.LocalTransparencyModifier = 0
   table.insert(parts, o); originals[o] = source:FindFirstChild(o.Name,true)
  end
 end
 assert(#parts > 0, 'Visual has no mesh parts')
 local offset = root.CFrame:ToObjectSpace(clone:GetPivot())
 local originalWidth, originalScale, lastFactor = root.Size.X, clone:GetScale(), 1
 local _, bounds = source:GetBoundingBox()
 local scale = math.clamp(bounds.Magnitude / 6, .25, 4)
 local glowHost
 for _, p in parts do if p.Name:find('Energy') then glowHost = p; break end end
 glowHost = glowHost or parts[1]
 local corePosition = source:GetAttribute('ReactorLocalCenter')
 local core = clone:FindFirstChild('FusionCoreEffects',true)
 if not (core and core:IsA('Attachment')) then
  if typeof(corePosition) ~= 'Vector3' then clone:Destroy(); error('Atom Rider requires an authored FusionCoreEffects attachment or ReactorLocalCenter attribute') end
  core = Instance.new('Attachment'); core.Name = 'FusionCoreEffects'
  core.Position = glowHost.CFrame:PointToObjectSpace(source:GetPivot():PointToWorldSpace(corePosition))
  core.Parent = glowHost
 end
 local light = core:FindFirstChild('PlasmaGlow') or Instance.new('PointLight')
 light.Name = 'PlasmaGlow'; light.Color = Color3.fromRGB(50,220,255)
 light.Range = 6 * scale; light.Shadows = false; light.Brightness = 1.2; light.Parent = core
 local mist = {}
 for _, y in {-bounds.Z * .28, bounds.Z * .28} do
  local a = Instance.new('Attachment'); a.Name = 'DownwardEnergy'
  a.Position = glowHost.CFrame:PointToObjectSpace(root.CFrame:PointToWorldSpace(Vector3.new(0,-bounds.Y*.32,y)))
  a.Parent = glowHost
  local e = Instance.new('ParticleEmitter'); e.Name = 'HoverEnergyWisps'
  e.Texture = 'rbxasset://textures/particles/smoke_main.dds'
  e.Color = ColorSequence.new(Color3.fromRGB(85,245,255),Color3.fromRGB(145,75,255))
  e.EmissionDirection = Enum.NormalId.Bottom; e.SpreadAngle = Vector2.new(12,12)
  e.Lifetime = NumberRange.new(.25,.45); e.Speed = NumberRange.new(.8*scale,1.5*scale)
  e.Size = NumberSequence.new({NumberSequenceKeypoint.new(0,.18*scale),NumberSequenceKeypoint.new(.5,.45*scale),NumberSequenceKeypoint.new(1,.65*scale)})
  e.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.2,.55),NumberSequenceKeypoint.new(1,1)})
  e.LightEmission = 1; e.LightInfluence = 0; e.Rate = 5; e.LockedToPart = false; e.Parent = a
  table.insert(mist,e)
 end
 for _, o in source:GetDescendants() do
  if o:IsA('BasePart') then hidden[o] = o.LocalTransparencyModifier
  elseif o:IsA('ParticleEmitter') or o:IsA('Light') or o:IsA('Beam') or o:IsA('Trail') then disabled[o] = o.Enabled end
 end
 local controller = {time=0, speed=0, steer=0, active=false, destroyed=false, Clone=clone, Source=source}
 function controller:SetEnabled(enabled)
  if self.destroyed or self.active == enabled then return end
  self.active = enabled
  for p, before in hidden do if p.Parent then p.LocalTransparencyModifier = enabled and 1 or before end end
  for e, before in disabled do if e.Parent then e.Enabled = not enabled and before end end
  clone.Parent = enabled and workspace or nil
 end
 function controller:Step(dt, speed, steer)
  if self.destroyed or not self.active then return end
  dt = math.max(0, dt); self.time += dt
  local blend = 1 - math.exp(-8 * math.min(dt,.25))
  self.speed += (math.clamp(speed or 0,0,1) - self.speed) * blend
  self.steer += (math.clamp(steer or 0,-1,1) - self.steer) * blend
  local factor = math.max(.001,root.Size.X / originalWidth)
  if math.abs(factor-lastFactor)>.0001 then clone:ScaleTo(originalScale*factor);lastFactor=factor end
  local motion, pulse = HoverVisuals.Sample(self.time,self.speed,self.steer,scale*factor)
  local scaledOffset = CFrame.new(offset.Position*factor)*offset.Rotation
  clone:PivotTo(root.CFrame * scaledOffset * motion)
  light.Brightness = 1.0 + pulse * 1.3
  for _, e in mist do e.Rate = 5 + self.speed * 5 end
  -- Honor concealment/fades owned by the game, so carried/hidden items do not leak.
  for _, p in parts do
   local original = originals[p]
   if original and original:IsA('BasePart') then p.Transparency = original.Transparency end
  end
 end
 function controller:Destroy()
  if self.destroyed then return end
  self:SetEnabled(false); self.destroyed = true; clone:Destroy(); Controllers[root] = nil
  if self.connection then self.connection:Disconnect() end
 end
 controller.connection = root.Destroying:Connect(function() controller:Destroy() end)
 Controllers[root] = controller
 controller:SetEnabled(true)
 return controller
end
return HoverVisuals
