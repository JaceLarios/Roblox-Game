local names={'Warp Wreck','Wormhole Wheelie','Hole in Space','Warp Warden','Star Freighter','Starcrusher'}
local function vec(v)return {v.X,v.Y,v.Z}end
local function attrs(o)
 local a=o:GetAttributes()
 for k,v in a do if typeof(v)=='Vector3' then a[k]={type='Vector3',value=vec(v)} end end
 return a
end
local data={models={},verification=_G.WarpVerification}
for _,name in names do
 local m=assert(game.ReplicatedStorage.ItemModels:FindFirstChild(name));local entry={name=name,attributes=attrs(m),parts={}}
 for _,p in m:GetChildren()do
  if p:IsA('MeshPart')then table.insert(entry.parts,{name=p.Name,mesh=p.MeshId,size=vec(p.Size),cf={p.CFrame:GetComponents()},color={p.Color.R,p.Color.G,p.Color.B},material=p.Material.Name,variant=p.MaterialVariant,attributes=attrs(p)})end
 end
 table.insert(data.models,entry)
end
return game.HttpService:JSONEncode(data)
