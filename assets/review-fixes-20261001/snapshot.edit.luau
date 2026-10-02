local H=game.HttpService
local function vec(v)return {v.X,v.Y,v.Z}end
local function attrs(o)local a=o:GetAttributes();for k,v in a do if typeof(v)=='Vector3' then a[k]={type='Vector3',value=vec(v)}end end return a end
local data={models={},verification=_G.ReviewModelsVerification,toroVerification=_G.ToroReviewVerification}
local names={};for _,row in _G.ReviewModelsVerification.models do table.insert(names,row.name)end;table.insert(names,'Toro')
for _,name in names do
 local m=game.ReplicatedStorage.ItemModels[name];local entry={name=name,attributes=attrs(m),parts={}}
 for _,p in m:GetChildren()do if p:IsA('BasePart')then
  local r={name=p.Name,class=p.ClassName,size=vec(p.Size),cf={p.CFrame:GetComponents()},color={p.Color.R,p.Color.G,p.Color.B},material=p.Material.Name,variant=p.MaterialVariant,attributes=attrs(p),transparency=p.Transparency,reflectance=p.Reflectance,appearance={}}
  if p:IsA('MeshPart')then r.mesh=p.MeshId;r.texture=p.TextureID end
  for _,a in p:GetChildren()do if a:IsA('SurfaceAppearance')then table.insert(r.appearance,{color=a.ColorMap,normal=a.NormalMap,roughness=a.RoughnessMap,metal=a.MetalnessMap,alpha=a.AlphaMode.Name})end end
  table.insert(entry.parts,r)
 end end
 table.insert(data.models,entry)
end
local previous=H.HttpEnabled;H.HttpEnabled=true
local encoded=H:JSONEncode(data);local total=math.ceil(#encoded/400000)
for i=1,total do H:PostAsync('http://127.0.0.1:18769/capture/installed-review-models.json',H:JSONEncode({chunk=encoded:sub((i-1)*400000+1,i*400000),index=i,total=total}),Enum.HttpContentType.ApplicationJson)end
H.HttpEnabled=previous
return {models=#data.models,bytes=#encoded}
