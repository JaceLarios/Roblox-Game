-- Edit-mode asset and integration checks. No player data or awards.
local RS=game.ReplicatedStorage
local root=Instance.new('Folder');root.Name='CivicLifecycleQA';root.Parent=workspace
local modules=Instance.new('Folder');modules.Name='Modules';modules.Parent=root
for _,name in {'FusionRecipes','EventAddons','Mutations','ItemVisuals','RaceConfig','VehicleAddonEffects'}do local m=RS[name]:Clone();m.Parent=modules end
local source=modules.ItemVisuals.Source
source=source:gsub('local FusionRecipes = require%(RS:WaitForChild%("FusionRecipes"%)%)','local FusionRecipes = require(script.Parent.FusionRecipes)')
source=source:gsub('local Mutations = require%(RS:WaitForChild%("Mutations"%)%)','local Mutations = require(script.Parent.Mutations)')
source=source:gsub('local EventAddons = require%(RS:WaitForChild%("EventAddons"%)%)','local EventAddons = require(script.Parent.EventAddons)')
modules.ItemVisuals.Source=source
for _,name in {'RaceConfig','Mutations'}do
 local module=modules[name]
 for _,dep in {'FusionRecipes','EventAddons','Mutations'}do
  module.Source=module.Source:gsub('require%(ReplicatedStorage:WaitForChild%("'..dep..'"%)%)','require(script.Parent.'..dep..')')
 end
end
local recipes=require(modules.FusionRecipes);local visuals=require(modules.ItemVisuals)
local config=require(modules.RaceConfig);local effects=require(modules.VehicleAddonEffects)
local events=require(modules.EventAddons);local mutations=require(modules.Mutations)
local conveyor=require(game.ServerStorage.YardConveyor)
local raceSource=game.ServerScriptService.RaceService.Source
local first=assert(raceSource:find('local function seatedSpan',1,true))
local last=assert(raceSource:find('local function fastestCar',first,true))
local ctor=Instance.new('ModuleScript');ctor.Name='Constructor'
ctor.Source="local ItemVisuals=require(script.Parent.ItemVisuals)\nlocal RaceConfig=require(script.Parent.RaceConfig)\nlocal Mutations=require(script.Parent.Mutations)\nlocal Track={CAR_GROUP='Default'}\nlocal liveFolder=script.Parent.Parent\nlocal SLICK=PhysicalProperties.new(.7,0,.3,100,1)\n"..raceSource:sub(first,last-1)..'\nreturn buildCar'
ctor.Parent=modules
local results={};local ok,err=xpcall(function()
 local build=require(ctor)
 local names={};for _,m in RS.ItemModels:GetChildren()do if m:GetAttribute('VisualRevision')=='Civic_20261009_v1'then table.insert(names,m.Name)end end
 assert(#names==32,'Expected all 32 Civic models');table.sort(names)
 for _,name in names do
  local template=RS.ItemModels[name];local _,bounds=template:GetBoundingBox()
  local viewport,size=visuals.CloneForViewport(name);assert(viewport and (size-bounds).Magnitude<.02,name..' viewport bounds');viewport:Destroy()
  local item=visuals.Create(name,Vector3.new(0,1400,0),1);item.Parent=root
  assert(item:GetAttribute('ItemAssembly'),name..' fallback used')
  local original=item.Size;local wheelIds={};local rest={}
  for _,p in item:GetDescendants()do if p:IsA('BasePart')then assert(not p.Anchored and not p.CanCollide,name..' unsafe visual physics');local id=p:GetAttribute('WheelId');if id then wheelIds[id]=true;assert(typeof(p:GetAttribute('RollPivot'))=='Vector3')end end end
  local count=0;for _ in wheelIds do count+=1 end;assert(count==template:GetAttribute('ExpectedWheels'),name..' wheel count')
  for _,w in item:GetChildren()do if w:IsA('Weld')and w.Part1:GetAttribute('WheelId')then rest[w]=w.C0 end end
  visuals.RollWheels(item,1.2)
  for w,cf in rest do assert((w.C0.LookVector-cf.LookVector).Magnitude>.01,name..' wheel did not rotate')end
  visuals.Resize(item,original*.55);visuals.RollWheels(item,.5);visuals.Resize(item,original)
  assert((item.Size-original).Magnitude<.01,name..' pickup resize')
  local over=math.sqrt((conveyor.RADIUS+item.Size.X/2)^2+(item.Size.Z/2)^2)-conveyor.RADIUS-conveyor.WIDTH/2
  assert(over<.1,name..' too wide for belt: '..over)
  for step=0,23 do local point,travel=conveyor.PointAt(conveyor.Length*step/23);item.CFrame=CFrame.lookAt(point+Vector3.yAxis*1400,point+Vector3.yAxis*1400-travel);visuals.RollWheels(item,conveyor.Length/23)end
  local fx=effects.Attach(item);if name~='Civic'then assert(fx,name..' missing addon effects');effects.SetActive(fx,true);effects.Step(fx,1);effects.Destroy(fx)end
  item:Destroy()
  local car,chassis,seat,driverScale=build({Name='QA'},name,assert(config.CarStats(name)),CFrame.new(0,1500,0))
  local body;for _,p in car:GetChildren()do if p:GetAttribute('ItemAssembly')then body=p end end
  assert(body and math.abs(math.max(body.Size.X,body.Size.Z)-config.CAR_LENGTH)<.03,name..' race scale')
  assert(seat:IsA('VehicleSeat')and chassis.DriveVelocity and chassis.DriveHeading,name..' missing drive rig')
  assert(driverScale>=.55 and driverScale<=1,name..' driver scale')
  local cabinTop=-math.huge
  for _,p in body:GetDescendants()do if p:IsA('BasePart')and p:GetAttribute('DriverCabin')then
   for _,x in {-1,1}do for _,y in {-1,1}do for _,z in {-1,1}do cabinTop=math.max(cabinTop,(p.CFrame*Vector3.new(x*p.Size.X/2,y*p.Size.Y/2,z*p.Size.Z/2)).Y)end end end
  end end
  assert(seat.Position.Y+.3+3.4*driverScale<=cabinTop+.02,name..' driver above cabin')
  car:Destroy()
  table.insert(results,{name=name,triangles=template:GetAttribute('TriangleCount'),wheels=count,viewport=true,roll=true,resize=true,conveyorOverhang=over,race=true,driverScale=driverScale,effects=fx~=nil})
 end
 for _,addon in recipes.Addons do local result=recipes.Fuse('Civic',addon.name);assert(result and RS.ItemModels:FindFirstChild(result),'Missing Civic recipe model: '..addon.name)end
 for _,addon in recipes.PhantomAddons do
  local id=events.Of(addon.name);local named=events.IndexName('Civic',id);assert(RS.ItemModels:FindFirstChild(named))
  for _,base in {'Civic','Civic + Twin Turbo'}do
   local name=mutations.Wrap(base,'golden',id);local model=assert(visuals.CloneForViewport(name,mutations.Color('golden')))
   assert(model:FindFirstChildWhichIsA('MeshPart',true));model:Destroy()
  end
 end
end,debug.traceback)
root:Destroy();assert(ok,err)
_G.CivicLifecycleQA=results
return game.HttpService:JSONEncode({passed=#results,models=results,scope='All imported models: viewport, world, wheel rotation, pickup resizing, conveyor geometry, real race constructor, addon effects; all Phantom overlays and mutation combinations.'})
