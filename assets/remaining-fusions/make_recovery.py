from pathlib import Path
import json
P=Path(__file__).resolve().parent
golf=P.parent/'golf-cart-fusions'
snapshots=list((golf/'fit-snapshot').glob('*.json'))
if len(snapshots)==15:
 models=[json.loads(path.read_text())['models'][0]for path in sorted(snapshots)]
 (golf/'installed-fit-models.json').write_text(json.dumps({'models':models,'note':'Live snapshot with approved 1.2x fit'},separators=(',',':')))
tail='''
local folder=Instance.new('Folder');folder.Name='RecoveredModels_'..os.time();folder.Parent=game.ServerStorage
local function setAttributes(o,a)
 for k,v in a or {} do if type(v)=='table'and v.type=='Vector3' then v=Vector3.new(unpack(v.value))end;o:SetAttribute(k,v)end
end
for _,record in data.models do
 local m=Instance.new('Model');m.Name=record.name;setAttributes(m,record.attributes)
 for _,r in record.parts do
  local p=r.mesh and game.AssetService:CreateMeshPartAsync(Content.fromUri(r.mesh))or Instance.new(r.class or 'Part')
  p.Name=r.name;p.Size=Vector3.new(unpack(r.size));p.CFrame=CFrame.new(unpack(r.cf));p.Color=Color3.new(unpack(r.color));p.Material=Enum.Material[r.material];p.MaterialVariant=r.variant
  p.Transparency=r.transparency or 0;p.Reflectance=r.reflectance or 0
  if p:IsA('MeshPart')then p.TextureID=r.texture or '';p.DoubleSided=true end
  for _,a in r.appearance or {}do local s=Instance.new('SurfaceAppearance');s.ColorMap=a.color;s.NormalMap=a.normal;s.RoughnessMap=a.roughness;s.MetalnessMap=a.metal;s.AlphaMode=Enum.AlphaMode[a.alpha];s.Parent=p end
  p.Anchored=true;p.CanCollide=false;p.CanTouch=false;p.CanQuery=false;p.Massless=true;setAttributes(p,r.attributes);p.Parent=m
 end
 m.Parent=folder
end
return folder.Name
'''
for folder,filename in [(P,'installed-models.json'),(P.parent/'golf-cart-fusions','installed-fit-models.json'),(P.parent/'svo','installed-optimized.json')]:
 path=folder/filename
 if not path.exists():continue
 data=json.loads(path.read_text())
 out='restore-fit.edit.luau'if 'golf-cart'in str(folder)else'restore-optimized.edit.luau'if folder.name=='svo'else'restore.edit.luau'
 (folder/out).write_text("-- Recovery into ServerStorage only; never replaces active templates.\nassert(not game:GetService('RunService'):IsRunning(),'Stop Play')\nlocal data=game.HttpService:JSONDecode([==["+json.dumps(data,separators=(',',':'))+"]==])\n"+tail)
 print('RECOVERY',folder.name,len(data['models']))
