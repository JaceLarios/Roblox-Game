-- Load installed-models.json into _G.KartFusionInstalledSnapshot before running.
-- Stages a complete restore; no existing templates are replaced by this script.
assert(not game:GetService('RunService'):IsRunning(),'Stop Play first')
local data=assert(_G.KartFusionInstalledSnapshot,'Load the installed snapshot first')
local function decode(v)
 if type(v)~='table'or not v.type then return v end
 local t,a=v.type,v.value
 if t=='Vector3'then return Vector3.new(unpack(a))elseif t=='Vector2'then return Vector2.new(unpack(a))
 elseif t=='Color3'then return Color3.new(unpack(a))elseif t=='CFrame'then return CFrame.new(unpack(a))
 elseif t=='EnumItem'then return Enum[v.enum:gsub('Enum%.','')][a]
 elseif t=='NumberRange'then return NumberRange.new(unpack(a))
 elseif t=='NumberSequence'then local keys={};for _,k in a do table.insert(keys,NumberSequenceKeypoint.new(k.time,decode(k.value),k.envelope or 0))end;return NumberSequence.new(keys)
 elseif t=='ColorSequence'then local keys={};for _,k in a do table.insert(keys,ColorSequenceKeypoint.new(k.time,decode(k.value)))end;return ColorSequence.new(keys)
 end
 error('Unsupported snapshot type '..t)
end
for _,v in data.materials do
 local current=game.MaterialService:FindFirstChild(v.name)
 if current then
  assert(current:IsA('MaterialVariant')and current.ColorMap==v.color and current.NormalMap==v.normal and current.RoughnessMap==v.roughness and current.MetalnessMap==v.metalness,'Material conflict '..v.name)
 else
  local m=Instance.new('MaterialVariant');m.Name=v.name;m.BaseMaterial=Enum.Material[v.base];m.StudsPerTile=v.tile
  m.ColorMap=v.color;m.NormalMap=v.normal;m.RoughnessMap=v.roughness;m.MetalnessMap=v.metalness;m.Parent=game.MaterialService
 end
end
local stage=Instance.new('Folder');stage.Name='KartFusionSnapshotRestore_'..os.time();stage.Parent=game.ServerStorage
local meshCache={}
local function restore(node,parent)
 local object
 if node.class=='MeshPart'then
  local id=node.properties.MeshId
  if not meshCache[id]then meshCache[id]=game.AssetService:CreateMeshPartAsync(Content.fromUri(id))end
  object=meshCache[id]:Clone()
 else object=Instance.new(node.class)end
 object.Name=node.name
 for key,value in node.properties do if key~='MeshId'then object[key]=decode(value)end end
 for key,value in node.attributes do object:SetAttribute(key,decode(value))end
 for _,child in node.children do restore(child,object)end
 object.Parent=parent;return object
end
local ok,err=xpcall(function()for _,node in data.models do restore(node,stage)end end,debug.traceback)
for _,mesh in meshCache do mesh:Destroy()end
if not ok then stage:Destroy();error(err)end
return {staged=stage.Name,models=#stage:GetChildren(),note='Existing ItemModels remain unchanged; review staged models before backup/swap.'}
