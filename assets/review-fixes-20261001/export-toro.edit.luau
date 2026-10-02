assert(not game:GetService('RunService'):IsRunning())
local H=game.HttpService;local AS=game.AssetService;local old=game.ReplicatedStorage.ItemModels.Toro
local previous=H.HttpEnabled;H.HttpEnabled=true
local state={done=0,errors={},finished=false};_G.ToroCapture=state
task.spawn(function()
 local ok,err=xpcall(function()
  local records={}
  for _,p in old:GetChildren() do if p:IsA('MeshPart') then
   local em=AS:CreateEditableMeshAsync(Content.fromUri(p.MeshId));assert(em,p.Name)
   local vertices,normals,uvs,triangles={},{},{},{}
   for _,f in em:GetFaces() do
    local vs=em:GetFaceVertices(f);local ns=em:GetFaceNormals(f);local us=em:GetFaceUVs(f);local t={}
    for j,v in vs do
     local pos=em:GetPosition(v);local n=em:GetNormal(ns[j]);local uv=em:GetUV(us[j]);table.insert(t,#vertices)
     table.insert(vertices,{pos.X,pos.Y,pos.Z});table.insert(normals,{n.X,n.Y,n.Z});table.insert(uvs,{uv.X,uv.Y})
    end
    table.insert(triangles,t)
   end
   em:Destroy()
   local d={name=p.Name,vertices=vertices,normals=normals,uvs=uvs,triangles=triangles}
   local data=H:JSONEncode(d);local total=math.ceil(#data/400000)
   for i=1,total do H:PostAsync('http://127.0.0.1:18769/capture/part-'..state.done..'.json',H:JSONEncode({chunk=data:sub((i-1)*400000+1,i*400000),index=i,total=total}),Enum.HttpContentType.ApplicationJson) end
   table.insert(records,{name=p.Name,file='part-'..state.done..'.json',triangles=#triangles,wheel=p:GetAttribute('WheelPivot')~=nil})
   state.done+=1
  end end
  H:PostAsync('http://127.0.0.1:18769/capture/manifest.json',H:JSONEncode(records),Enum.HttpContentType.ApplicationJson)
 end,debug.traceback)
 if not ok then table.insert(state.errors,err) end
 H.HttpEnabled=previous;state.finished=true
end)
return 'Capturing current Toro mesh geometry with UVs'
