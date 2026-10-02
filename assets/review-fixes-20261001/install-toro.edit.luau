assert(not game:GetService('RunService'):IsRunning())
local state=assert(_G.ToroReviewImport);assert(state.finished and #state.errors==0,'Toro import incomplete')
local templates=game.ReplicatedStorage.ItemModels;local old=templates.Toro;local staged=game.ServerStorage[state.stage]
local _,a=old:GetBoundingBox();local _,b=staged:GetBoundingBox();assert((a-b).Magnitude<.0001)
local wheels=0
for _,p in staged:GetChildren()do if p:IsA('BasePart')then
 local q=assert(old:FindFirstChild(p.Name));assert(p.Color==q.Color and p.Material==q.Material and p.MaterialVariant==q.MaterialVariant)
 for k,v in q:GetAttributes()do if k~='TriangleCount'then assert(p:GetAttribute(k)==v,'Attribute changed '..k)end end
 if q:GetAttribute('WheelPivot')then wheels+=1 end
 local sa=p:FindFirstChildOfClass('SurfaceAppearance');local sb=q:FindFirstChildOfClass('SurfaceAppearance')
 assert((sa~=nil)==(sb~=nil));if sa then assert(sa.ColorMap==sb.ColorMap and sa.NormalMap==sb.NormalMap and sa.RoughnessMap==sb.RoughnessMap and sa.MetalnessMap==sb.MetalnessMap)end
end end
assert(wheels==24 and state.triangles<90000)
local backup=Instance.new('Folder');backup.Name='BeforeToroReviewOptimization_'..os.time();backup.Parent=game.ServerStorage;old.Parent=backup
local replacement=staged:Clone();replacement.Name='Toro';replacement.Parent=templates
local ok,err=xpcall(function()
 local v=require(game.ReplicatedStorage.ItemVisuals);local view=assert(v.CloneForViewport('Toro'));view:Destroy()
 local item=v.Create('Toro',Vector3.new(0,1600,0),1);local before={}
 for _,j in item:GetChildren()do if j:IsA('Weld')then before[j]=j.C0 end end
 v.RollWheels(item,1);local moved=0
 for j,cf in before do if j.Part1:GetAttribute('WheelPivot')then assert(j.C0~=cf);moved+=1 else assert(j.C0==cf)end end
 assert(moved==24);v.Resize(item,item.Size*.75);v.RollWheels(item,.5);item:Destroy()
end,debug.traceback)
if not ok then replacement:Destroy();old.Parent=templates;error(err)end
_G.ToroReviewVerification={backup=backup.Name,triangles=state.triangles,length=b.Z,wheelParts=24,appearancePreserved=true,viewport=true,resize=true}
return game.HttpService:JSONEncode(_G.ToroReviewVerification)
