local function encode(value)
 local kind=typeof(value)
 if kind=='Vector3'then return {type=kind,value={value.X,value.Y,value.Z}}
 elseif kind=='Vector2'then return {type=kind,value={value.X,value.Y}}
 elseif kind=='Color3'then return {type=kind,value={value.R,value.G,value.B}}
 elseif kind=='CFrame'then return {type=kind,value={value:GetComponents()}}
 elseif kind=='EnumItem'then return {type=kind,enum=tostring(value.EnumType),value=value.Name}
 elseif kind=='NumberRange'then return {type=kind,value={value.Min,value.Max}}
 elseif kind=='NumberSequence'or kind=='ColorSequence'then
  local keys={};for _,key in value.Keypoints do table.insert(keys,{time=key.Time,value=encode(key.Value),envelope=kind=='NumberSequence'and key.Envelope or nil})end
  return {type=kind,value=keys}
 end
 return value
end
local properties={
 Model={},
 MeshPart={'MeshId','Size','CFrame','Color','Material','MaterialVariant','Reflectance','Transparency','Anchored','CanCollide','CanTouch','CanQuery','Massless','DoubleSided'},
 Attachment={'CFrame'},
 PointLight={'Color','Brightness','Range','Shadows','Enabled'},
 ParticleEmitter={'Texture','Color','LightEmission','LightInfluence','Rate','Lifetime','Speed','Drag','SpreadAngle','Size','Transparency','Rotation','RotSpeed','LockedToPart','Enabled','Acceleration','EmissionDirection'}
}
local function record(object)
 local props=assert(properties[object.ClassName],object.ClassName)
 local node={class=object.ClassName,name=object.Name,properties={},attributes={},children={}}
 for _,key in props do node.properties[key]=encode(object[key])end
 for key,value in object:GetAttributes()do node.attributes[key]=encode(value)end
 for _,child in object:GetChildren()do table.insert(node.children,record(child))end
 return node
end
local models={};local variants={}
for _,spec in _G.KartFusionDesigns do
 local m=assert(game.ReplicatedStorage.ItemModels:FindFirstChild(spec.name))
 table.insert(models,record(m))
 for _,p in m:GetDescendants()do if p:IsA('MeshPart')and p.MaterialVariant~=''then variants[p.MaterialVariant]=true end end
end
local materials={}
for name in variants do local v=game.MaterialService[name];table.insert(materials,{name=name,base=v.BaseMaterial.Name,tile=v.StudsPerTile,color=v.ColorMap,normal=v.NormalMap,roughness=v.RoughnessMap,metalness=v.MetalnessMap})end
return game.HttpService:JSONEncode({models=models,materials=materials,verification=_G.KartFusionInstallReport,revision='20260925_v7'})
