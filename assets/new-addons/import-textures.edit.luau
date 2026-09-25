assert(not game:GetService('RunService'):IsRunning())
local h=game:GetService('HttpService');local AS=game:GetService('AssetService')
_G.AddonTextureState={finished=false,done={},error=nil,active=''}
task.spawn(function()
 local old=h.HttpEnabled
 local ok,err=xpcall(function()
  h.HttpEnabled=true
  for _,kind in {'Cast','Brushed','Enamel','Rubber','Oxidized'}do
   _G.AddonTextureState.active=kind
   local data=h:JSONDecode(h:GetAsync('http://127.0.0.1:18763/textures/'..kind..'.json'))
   local maps={}
   for _,key in {'ColorMap','NormalMap','RoughnessMap','MetalnessMap'}do
    local im=assert(AS:CreateEditableImage({Size=Vector2.new(data.size,data.size)}))
    local pixels=data.maps[key];local buf=buffer.create(#pixels)
    for i,value in pixels do buffer.writeu8(buf,i-1,value)end
    im:WritePixelsBuffer(Vector2.zero,Vector2.new(data.size,data.size),buf)
    local status,id=AS:CreateAssetAsync(im,Enum.AssetType.Image,{Name='Junkyard Addon '..kind..' '..key,Description='Original seamless procedural material for Junkyard Fusion addons'})
    assert(tostring(status):find('Success'),tostring(status));maps[key]='rbxassetid://'..id;im:Destroy()
   end
   local v=Instance.new('MaterialVariant');v.Name='AddonDetail_'..kind..'_v2';v.BaseMaterial=Enum.Material.SmoothPlastic
   v.StudsPerTile=kind=='Brushed' and .48 or kind=='Rubber' and .42 or .85
   for key,id in maps do v[key]=id end
   v.Parent=game.MaterialService
   table.insert(_G.AddonTextureState.done,{name=v.Name,maps=maps,tile=v.StudsPerTile})
  end
 end,debug.traceback)
 h.HttpEnabled=old
 if not ok then _G.AddonTextureState.error=err end
 _G.AddonTextureState.active='';_G.AddonTextureState.finished=true
end)
return _G.AddonTextureState
