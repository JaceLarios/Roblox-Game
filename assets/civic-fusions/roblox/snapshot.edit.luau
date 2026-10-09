-- Export persistent asset IDs and properties; no source player data.
local H=game.HttpService;local previous=H.HttpEnabled;H.HttpEnabled=true
local function attrs(o)
 local t=o:GetAttributes();for k,v in t do if typeof(v)=='Vector3' then t[k]={type='Vector3',value={v.X,v.Y,v.Z}}end end;return t
end
local data={placeId=game.PlaceId,revision='Civic_20261009_v1',models={},materials={}}
local used={}
for _,m in game.ReplicatedStorage.ItemModels:GetChildren()do if m:GetAttribute('VisualRevision')==data.revision then
 local r={name=m.Name,attributes=attrs(m),pivot={m:GetPivot():GetComponents()},parts={}}
 for _,p in m:GetChildren()do if p:IsA('MeshPart')then
  table.insert(r.parts,{name=p.Name,mesh=p.MeshId,texture=p.TextureID,size={p.Size.X,p.Size.Y,p.Size.Z},cf={p.CFrame:GetComponents()},color={p.Color.R,p.Color.G,p.Color.B},material=p.Material.Name,variant=p.MaterialVariant,transparency=p.Transparency,reflectance=p.Reflectance,attributes=attrs(p)})
  if p.MaterialVariant~='' then used[p.MaterialVariant]=true end
 end end
 table.sort(r.parts,function(a,b)return a.name<b.name end);table.insert(data.models,r)
end end
table.sort(data.models,function(a,b)return a.name<b.name end)
assert(#data.models==32)
for name in used do local m=assert(game.MaterialService:FindFirstChild(name));table.insert(data.materials,{name=name,base=m.BaseMaterial.Name,color=m.ColorMap,normal=m.NormalMap,roughness=m.RoughnessMap,metalness=m.MetalnessMap,studs=m.StudsPerTile})end
H:PostAsync('http://127.0.0.1:18773/snapshot',H:JSONEncode({name='studio-models.json',content=H:JSONEncode(data)}),Enum.HttpContentType.ApplicationJson)
H.HttpEnabled=previous
return {models=#data.models,materials=#data.materials}
