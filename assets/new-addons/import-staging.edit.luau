assert(not game:GetService('RunService'):IsRunning(),'Stop Play before importing')
local AS=game:GetService('AssetService')
local stage=Instance.new('Folder');stage.Name='BlenderAddons_Staging_'..os.time();stage.Parent=game.ServerStorage
_G.AddonImportState={stage=stage.Name,done={},errors={},active='',finished=false}
_G.AddonAssetManifest={}
local function srgb(v) return v<=.0031308 and v*12.92 or 1.055*v^(1/2.4)-.055 end
local names={'Straight Pipes','Scrap Turbo','Rotary Engine','Twin Turbo','Supercharger','Diesel Stack','V12 Engine','Hover Fans','Rocket Booster','Fusion Core'}
task.spawn(function()
for _,name in names do
 _G.AddonImportState.active=name
 local ok,err=xpcall(function()
 local data=assert(_G.BlenderAddonTransfer[name]);local m=Instance.new('Model');m.Name=name
 m:SetAttribute('DisplayName',name);m:SetAttribute('IsAddon',true);m:SetAttribute('Rarity',data.rarity)
 m:SetAttribute('VisualRevision','BlenderAddons_20260924_v2');m:SetAttribute('CodexModelRevision','BlenderAddons_20260924_v2')
 m:SetAttribute('AuthoredComponents',data.authoredComponents)
 local assets={}
 for _,part in data.parts do
  local em=AS:CreateEditableMesh();assert(em,'EditableMesh unavailable')
  local verts,normals={},{}
  for i,v in part.vertices do verts[i]=em:AddVertex(Vector3.new(v[1],v[2],v[3]));local n=part.normals[i];normals[i]=em:AddNormal(Vector3.new(n[1],n[2],n[3]))end
  for _,t in part.triangles do
   local a,b,c=t[1]+1,t[2]+1,t[3]+1
   local f=em:AddTriangle(verts[a],verts[b],verts[c]);em:SetFaceNormals(f,{normals[a],normals[b],normals[c]})
  end
  local status,id=AS:CreateAssetAsync(em,Enum.AssetType.Mesh,{Name=name..' - '..part.name,Description='Original Blender authored Junkyard Fusion addon geometry'})
  assert(tostring(status):find('Success'),tostring(status))
  local p=AS:CreateMeshPartAsync(Content.fromUri('rbxassetid://'..id));p.Name=part.name
  local co=part.material.color;p.Color=Color3.new(srgb(co[1]),srgb(co[2]),srgb(co[3]))
  p.Material=part.material.glow>0 and Enum.Material.Neon or part.material.metal>.4 and Enum.Material.Metal or Enum.Material.SmoothPlastic
  if part.name=='Rust' then p.Material=Enum.Material.CorrodedMetal end
  if part.name=='Carbon' then p.Material=Enum.Material.SmoothPlastic;p.MaterialVariant='AddonCarbonTwill';p.Color=Color3.new(1,1,1) end
  p.Transparency=1-part.material.alpha;p.Reflectance=part.name=='Chrome' and .08 or 0
  p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.Massless=true;p.DoubleSided=true
  p:SetAttribute('AuthoredComponents',#part.components);p:SetAttribute('TriangleCount',#part.triangles)
  p.CFrame=CFrame.identity
  local lo=Vector3.new(math.huge,math.huge,math.huge);local hi=-lo
  for _,v in part.vertices do local q=Vector3.new(v[1],v[2],v[3]);lo=lo:Min(q);hi=hi:Max(q)end
  p.CFrame+=(lo+hi)/2-p.ExtentsCFrame.Position
  p.Parent=m;table.insert(assets,{part=part.name,asset=id,triangles=#part.triangles})
  em:Destroy()
 end
 local cf,size=m:GetBoundingBox();m:PivotTo(CFrame.new(-cf.Position)*m:GetPivot())
 local maxdim=math.max(size.X,size.Y,size.Z)
 assert(math.abs(maxdim-data.targetMax)<.02,'Incorrect imported size '..tostring(size))
 m:SetAttribute('ReferenceMaxDimension',data.targetMax);m.Parent=stage
 _G.AddonAssetManifest[name]=assets;table.insert(_G.AddonImportState.done,{name=name,size={size.X,size.Y,size.Z},parts=#m:GetChildren()})
 end,debug.traceback)
 if not ok then table.insert(_G.AddonImportState.errors,{name=name,error=err})end
end
_G.AddonImportState.active='';_G.AddonImportState.finished=true
end)
return _G.AddonImportState
