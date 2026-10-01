local function attrs(o)
 local a=o:GetAttributes();for k,v in a do if typeof(v)=='Vector3' then a[k]={type='Vector3',value={v.X,v.Y,v.Z}}end end;return a
end
local m=game.ReplicatedStorage.ItemModels.SVO
local row={name=m.Name,attributes=attrs(m),parts={}}
for _,p in m:GetChildren()do
 if p:IsA('BasePart')then
  local r={name=p.Name,class=p.ClassName,mesh=p:IsA('MeshPart')and p.MeshId or nil,texture=p:IsA('MeshPart')and p.TextureID or nil,size={p.Size.X,p.Size.Y,p.Size.Z},cf={p.CFrame:GetComponents()},color={p.Color.R,p.Color.G,p.Color.B},material=p.Material.Name,variant=p.MaterialVariant,transparency=p.Transparency,reflectance=p.Reflectance,attributes=attrs(p),appearance={}}
  for _,s in p:GetChildren()do if s:IsA('SurfaceAppearance')then table.insert(r.appearance,{color=s.ColorMap,normal=s.NormalMap,roughness=s.RoughnessMap,metal=s.MetalnessMap,alpha=s.AlphaMode.Name})end end
  table.insert(row.parts,r)
 end
end
return game.HttpService:JSONEncode({models={row},verification=_G.SVOOptimizationVerification})
