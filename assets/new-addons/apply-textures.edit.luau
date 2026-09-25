local ts=assert(_G.AddonTextureState);assert(ts.finished and not ts.error and #ts.done==5,'Textures not ready')
local state=assert(_G.AddonImportState);assert(state.finished and #state.errors==0)
local stage=game.ServerStorage[state.stage]
local map={Chrome='Brushed',Copper='Brushed',Gold='Brushed',BlueHeat='Brushed',PurpleHeat='Brushed',Steel='Cast',Iron='Cast',Rubber='Rubber',Rust='Oxidized',Red='Enamel',Orange='Enamel',ElectricBlue='Enamel',Teal='Enamel',Violet='Enamel'}
local report={}
for _,m in stage:GetChildren()do
 local textured=0;local special=0
 for _,p in m:GetChildren()do if p:IsA('MeshPart')then
  local kind=map[p.Name]
  if kind then
   assert(game.MaterialService:FindFirstChild('AddonDetail_'..kind..'_v2'))
   p.Material=Enum.Material.SmoothPlastic;p.MaterialVariant='AddonDetail_'..kind..'_v2';p.Reflectance=0;textured+=1
  elseif p.Name=='Carbon' then
   p.Material=Enum.Material.SmoothPlastic;p.MaterialVariant='AddonCarbonTwill';p.Color=Color3.new(1,1,1);textured+=1
  else
   assert(p.Name=='Cyan' or p.Name=='Plasma' or p.Name=='Glass','Missing finish for '..p.Name);special+=1
  end
 end end
 assert(textured>0);m:SetAttribute('TextureRevision','AddonMaterials_20260924_v2')
 table.insert(report,{name=m.Name,texturedParts=textured,glassOrEmissiveParts=special})
end
_G.AddonTextureCoverage=report
return report
