-- Uses the game's current race-car constructor without starting races or awarding data.
local RS=game.ReplicatedStorage;local visuals=require(RS.ItemVisuals)
local config=require(RS.RaceConfig);local conveyor=require(game.ServerStorage.YardConveyor)
local folder=Instance.new('Folder');folder.Name='CodexModelLifecycleQA';folder.Parent=workspace
local source=game.ServerScriptService.RaceService.Source
local start=assert(source:find('local function buildCar',1,true));local finish=assert(source:find('local function fastestCar',start,true))
local module=Instance.new('ModuleScript');module.Name='IsolatedRaceConstructor'
module.Source="local ReplicatedStorage=game.ReplicatedStorage\nlocal ItemVisuals=require(ReplicatedStorage.ItemVisuals)\nlocal RaceConfig=require(ReplicatedStorage.RaceConfig)\nlocal Mutations=require(ReplicatedStorage.Mutations)\nlocal Track={CAR_GROUP='Default'}\nlocal liveFolder=workspace.CodexModelLifecycleQA\nlocal SLICK=PhysicalProperties.new(.7,0,.3,100,1)\n"..source:sub(start,finish-1)..'\nreturn buildCar'
module.Parent=folder
local results={};local ok,err=xpcall(function()
 local build=require(module)
 local names={};for _,m in RS.ItemModels:GetChildren()do if m:GetAttribute('VisualRevision')=='ClaudeReviewFixes_20261001_v2'then table.insert(names,m.Name)end end
 assert(#names==17,'Expected all 17 reviewed variants');table.sort(names)
 table.insert(names,'Toro')
 for index,name in names do
  local stats=assert(config.CarStats(name),'No driving stats '..name)
  local car,chassis,seat=build({Name='QA'},name,stats,CFrame.new(0,1400,0))
  assert(seat:IsA('VehicleSeat')and seat:GetAttribute('TopSpeed')==stats.topSpeed)
  assert(chassis:FindFirstChild('DriveVelocity')and chassis:FindFirstChild('DriveHeading'))
  local body
  for _,p in car:GetChildren()do if p:GetAttribute('ItemAssembly')then body=p end end
  assert(body and math.abs(math.max(body.Size.X,body.Size.Z)-config.CAR_LENGTH)<.03,'Race normalization failed '..name)
  local wheelParts=0;for _,p in body:GetDescendants()do if p:IsA('BasePart')then assert(not p.Anchored and not p.CanCollide);if p:GetAttribute('WheelId')then wheelParts+=1 end end end
  visuals.RollWheels(body,12);car:Destroy()
  local item=visuals.Create(name,Vector3.new(0,1500,0),1);item.Parent=folder
  local original=item.Size;local maxOverhang=0
  for step=0,23 do
   local point,travel=conveyor.PointAt(conveyor.Length*step/23)
   item.CFrame=CFrame.lookAt(point+Vector3.new(0,item.Size.Y/2+1500,0),point+Vector3.new(0,item.Size.Y/2+1500,0)-travel)
   visuals.RollWheels(item,conveyor.Length/23)
   local outside=math.sqrt((conveyor.RADIUS+item.Size.X/2)^2+(item.Size.Z/2)^2)-conveyor.RADIUS
   maxOverhang=math.max(maxOverhang,outside-conveyor.WIDTH/2)
  end
  assert(maxOverhang<.1,'Conveyor footprint too wide '..name..' '..maxOverhang)
  visuals.Resize(item,original*.55);visuals.RollWheels(item,1);visuals.Resize(item,original)
  assert((item.Size-original).Magnitude<.01);item:Destroy()
  table.insert(results,{name=name,raceConstructor=true,raceLength=config.CAR_LENGTH,wheelParts=wheelParts,conveyorPath=true,conveyorOverhang=maxOverhang,pickupResize=true})
 end
end,debug.traceback)
folder:Destroy();assert(ok,err)
_G.ModelLifecycleVerification=results
return game.HttpService:JSONEncode({passed=#results,results=results,scope='Isolated current race constructor, conveyor path and resize. Not a player-driven race.',playSession=game:GetService('RunService'):IsRunning()})
