local function addReactorEffects(model, data)
 if model.Name ~= 'Reactor Rustbucket' then return end
 local position = assert(data.reactorEffectCenter, 'Missing authored reactor center')
 local host = assert(model:FindFirstChildWhichIsA('BasePart'), 'Missing reactor mesh')
 local center = Instance.new('Attachment')
 center.Name = 'FusionCoreEffects'
 center.Position = host.CFrame:PointToObjectSpace(Vector3.new(unpack(position)))
 center.Parent = host
 local light = Instance.new('PointLight')
 light.Name = 'PlasmaGlow'
 light.Color = Color3.fromRGB(55, 215, 255)
 light.Brightness = 1.5
 light.Range = 7
 light.Shadows = false
 light.Parent = center
 local wisps = Instance.new('ParticleEmitter')
 wisps.Name = 'PulsingEnergyWisps'
 wisps.Texture = 'rbxasset://textures/particles/smoke_main.dds'
 wisps.Color = ColorSequence.new(Color3.fromRGB(65,230,255), Color3.fromRGB(80,105,255))
 wisps.LightEmission = 1
 wisps.LightInfluence = 0
 wisps.Rate = 3
 wisps.Lifetime = NumberRange.new(.8,1.2)
 wisps.Speed = NumberRange.new(.12,.35)
 wisps.SpreadAngle = Vector2.new(180,180)
 wisps.Size = NumberSequence.new({NumberSequenceKeypoint.new(0,.95),NumberSequenceKeypoint.new(.4,1.65),NumberSequenceKeypoint.new(1,2.1)})
 wisps.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0,1),NumberSequenceKeypoint.new(.25,.72),NumberSequenceKeypoint.new(.6,.85),NumberSequenceKeypoint.new(1,1)})
 wisps.Rotation = NumberRange.new(0,360)
 wisps.RotSpeed = NumberRange.new(-25,25)
 wisps.LockedToPart = true
 wisps.Parent = center
 local sparks = Instance.new('ParticleEmitter')
 sparks.Name = 'CoreSparks'
 sparks.Texture = 'rbxasset://textures/particles/sparkles_main.dds'
 sparks.Color = ColorSequence.new(Color3.fromRGB(190,255,255),Color3.fromRGB(35,155,255))
 sparks.LightEmission = 1
 sparks.LightInfluence = 0
 sparks.Rate = 8
 sparks.Lifetime = NumberRange.new(.35,.65)
 sparks.Speed = NumberRange.new(1.2,2.3)
 sparks.Drag = 2
 sparks.SpreadAngle = Vector2.new(180,180)
 sparks.Size = NumberSequence.new({NumberSequenceKeypoint.new(0,.11),NumberSequenceKeypoint.new(.35,.18),NumberSequenceKeypoint.new(1,0)})
 sparks.Transparency = NumberSequence.new({NumberSequenceKeypoint.new(0,.1),NumberSequenceKeypoint.new(.6,.25),NumberSequenceKeypoint.new(1,1)})
 sparks.LockedToPart = true
 sparks.Parent = center
 model:SetAttribute('ReactorEffectsRevision', 'PlasmaWisps_20260925_v1')
end

assert(not game:GetService('RunService'):IsRunning(),'Stop Play first')
local AS=game:GetService('AssetService');local stage=Instance.new('Folder');stage.Name='KartFusionsStaging_'..os.time();stage.Parent=game.ServerStorage
_G.KartFusionImport={stage=stage.Name,done={},errors={},finished=false,active='',part=0,uploaded=0,reused=0}
_G.KartFusionMeshCache=_G.KartFusionMeshCache or {}
local function srgb(v)return v<=.0031308 and v*12.92 or 1.055*v^(1/2.4)-.055 end
task.spawn(function()
 for _,spec in _G.KartFusionDesigns do
  local name=spec.name;_G.KartFusionImport.active=name
  local m=Instance.new('Model');m.Name=name;m.Parent=stage
  local ok,err=xpcall(function()
   local d=assert(_G.KartFusionTransfer[name]);m:SetAttribute('DisplayName',name);m:SetAttribute('VisualRevision','ScrapKartFusions_20260925_v7');m:SetAttribute('NoseAxis','+Z');m:SetAttribute('AuthoredComponents',d.authoredComponents);m:SetAttribute('FusionBase','Rusted Sedan');m:SetAttribute('FusionAddon',d.addon)
   for index,g in d.parts do
    _G.KartFusionImport.part=index
    local lo=Vector3.new(math.huge,math.huge,math.huge);local hi=-lo
    for _,v in g.vertices do local a=Vector3.new(unpack(v));lo=lo:Min(a);hi=hi:Max(a)end
    local center=(lo+hi)/2;local cached=_G.KartFusionMeshCache[g.geometryHash];local p
    if cached then p=cached:Clone();_G.KartFusionImport.reused+=1
    else
     local em=assert(AS:CreateEditableMesh());local success,result=xpcall(function()
      local vs,ns={},{}
      for i,v in g.vertices do vs[i]=em:AddVertex(Vector3.new(unpack(v))-center);ns[i]=em:AddNormal(Vector3.new(unpack(g.normals[i])))end
      for _,t in g.triangles do local a,b,c=t[1]+1,t[2]+1,t[3]+1;local f=em:AddTriangle(vs[a],vs[b],vs[c]);em:SetFaceNormals(f,{ns[a],ns[b],ns[c]})end
      local status,id=AS:CreateAssetAsync(em,Enum.AssetType.Mesh,{Name=name..' '..g.name,Description='Original Scrap Kart fusion collectible mesh'})
      assert(tostring(status):find('Success'),tostring(status))
      -- Fresh uploads can take time to become readable; retry the same asset ID.
      local loadError
      for attempt=1,8 do
       local loaded,mesh=pcall(function()return AS:CreateMeshPartAsync(Content.fromUri('rbxassetid://'..id))end)
       if loaded then return mesh end
       loadError=mesh;task.wait(math.min(attempt*2,10))
      end
      error('Uploaded mesh '..tostring(id)..' not readable: '..tostring(loadError))
     end,debug.traceback);em:Destroy();assert(success,result);p=result;_G.KartFusionMeshCache[g.geometryHash]=p:Clone();_G.KartFusionImport.uploaded+=1
    end
    p.Name=g.name;p.Color=Color3.new(srgb(g.material.color[1]),srgb(g.material.color[2]),srgb(g.material.color[3]));p.Material=Enum.Material.SmoothPlastic;p.MaterialVariant='';p.Reflectance=0;p.Transparency=0
    if g.material.finish=='Light'then p.Material=Enum.Material.Neon
    elseif g.material.finish=='Glass'then p.Material=Enum.Material.Glass;p.Reflectance=.08
    elseif g.material.finish=='Carbon'then assert(game.MaterialService:FindFirstChild('AddonCarbonTwill'));p.MaterialVariant='AddonCarbonTwill'
    else local variant='AddonDetail_'..g.material.finish..'_v2';assert(game.MaterialService:FindFirstChild(variant));p.MaterialVariant=variant end
    p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.Massless=true;p.DoubleSided=true
    p:SetAttribute('TriangleCount',#g.triangles);p:SetAttribute('GeometryHash',g.geometryHash);p:SetAttribute('AuthoredComponents',#g.components)
    if g.wheel then p:SetAttribute('WheelId',g.wheel.id);p:SetAttribute('WheelPivot',Vector3.new(unpack(g.wheel.pivot)));p:SetAttribute('WheelRadius',g.wheel.radius)end
    p.CFrame=CFrame.new(center);p.Parent=m
   end
   addReactorEffects(m,d)
   local cf,size=m:GetBoundingBox();m:PivotTo(CFrame.new(-cf.Position)*m:GetPivot())
   for _,p in m:GetChildren()do local wp=p:GetAttribute('WheelPivot');if wp then p:SetAttribute('WheelPivot',wp-cf.Position)end end
   m:SetAttribute('WheelPivotRecentered',true);assert((size-Vector3.new(unpack(d.targetSize))).Magnitude<.05,'Size mismatch '..tostring(size))
   table.insert(_G.KartFusionImport.done,{name=name,size={size.X,size.Y,size.Z},parts=#m:GetChildren()})
  end,debug.traceback)
  if not ok then table.insert(_G.KartFusionImport.errors,{name=name,error=err})end
 end
 _G.KartFusionImport.active='';_G.KartFusionImport.finished=true
end)
return _G.KartFusionImport
