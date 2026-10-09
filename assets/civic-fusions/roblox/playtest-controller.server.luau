-- Created only in the isolated Play session, never installed in Edit.
assert(game.RunService:IsStudio())
local Players=game.Players;local RS=game.ReplicatedStorage
local QA=assert(_G.CivicGameplayQA);local spawner=assert(_G.CivicSpawnerQA)
local Recipes=require(RS.FusionRecipes);local Mutations=require(RS.Mutations);local Events=require(RS.EventAddons)
local Race=require(game.ServerScriptService.RaceService);local Track=require(game.ServerStorage.RaceTrack)
local Conveyor=require(game.ServerStorage.YardConveyor);local AntiCheat=require(game.ServerScriptService.AntiCheat)
local control=Instance.new('BindableFunction');control.Name='CivicQAControl';control.Parent=workspace
local function player()return assert(Players:GetPlayers()[1])end
local function move(p,frame)AntiCheat.Allow(p,5);p.Character:PivotTo(frame)end
local function clean(p)
 local s=QA.state[p];p.Character.Humanoid:UnequipTools()
 if s.carrying then QA.clearCarry(s);s.carrying=nil end
 s.inventory={};s.slots={};s.placed={};QA.refreshPad(p);QA.refreshPlaced(p);QA.refresh(p)
end
local function seed(p,names)
 clean(p);local s=QA.state[p];s.inventory=table.clone(names);QA.refresh(p);return s
end
local function status(p)
 local s=QA.state[p];local racer=_G.CivicRaceQA.racers[p]
 return {inventory=s.inventory,slots=s.slots,placed=s.placed,carrying=s.carrying and s.carrying.name,coins=s.coins,unclaimed=s.unclaimed,race=racer and {state=racer.state,item=racer.itemName,distance=racer.distance},attributes=p:GetAttributes()}
end
local lastSpawn
control.OnInvoke=function(action,arg)
 local p=player();local s=QA.state[p];assert(s,'Player not initialized')
 if action=='status'then return status(p)
 elseif action=='seed'then seed(p,arg);return status(p)
 elseif action=='home'then move(p,QA.plots[s.plotIndex].spawnPoint.CFrame+Vector3.new(0,2,0));return status(p)
 elseif action=='conveyor'then
  clean(p);lastSpawn=spawner.spawn(arg,Conveyor.PointAt(25),{onBelt=true,silent=true});spawner.ride(lastSpawn,25)
  move(p,CFrame.new(lastSpawn.Position+Vector3.new(4,3,0)));return {position=tostring(lastSpawn.Position),item=lastSpawn.Name,prompt=lastSpawn:FindFirstChildOfClass('ProximityPrompt')~=nil}
 elseif action=='pickup'then
  move(p,CFrame.new(lastSpawn.Position+Vector3.new(4,3,0)));assert(QA.grab(p,lastSpawn));return status(p)
 elseif action=='deliver'then move(p,QA.plots[s.plotIndex].spawnPoint.CFrame+Vector3.new(0,2,0));task.wait(.5);return status(p)
 elseif action=='equip'then
  local tool;for _,t in p.Backpack:GetChildren()do if t:GetAttribute('ItemName')==arg then tool=t;break end end
  assert(tool,'Missing tool '..arg);p.Character.Humanoid:EquipTool(tool);task.wait(.3);local held=assert(tool:FindFirstChild('HeldItem'))
  return {name=tool.Name,held=true,size=tostring(held.Size)}
 elseif action=='place'then QA.hotbar.place(p,1);return status(p)
 elseif action=='unplace'then QA.unplace(p,1);return status(p)
 elseif action=='fuse'then
  seed(p,arg);assert(QA.hotbar.stage(p,1));assert(QA.hotbar.stage(p,1));QA.fuse(p);return status(p)
 elseif action=='startRace'then
  seed(p,{arg});Race.SendToLobby(p);move(p,CFrame.new(Track.PointAt(-30,0,4)));task.wait(.6);workspace:SetAttribute('RaceNextAt',workspace:GetServerTimeNow()-1);return status(p)
 elseif action=='raceStatus'then
  local r=_G.CivicRaceQA.racers[p];local car=r and r.car;local seat=car and car:FindFirstChild('RaceSeat');local chassis=car and car:FindFirstChild('Chassis')
  return {attributes=p:GetAttributes(),car=car and car.Name,seat=seat and seat.Occupant~=nil,position=chassis and tostring(chassis.Position),speed=chassis and chassis.AssemblyLinearVelocity.Magnitude,go=seat and seat:GetAttribute('Go'),scale=p.Character:GetScale()}
 elseif action=='endRace'then Race.SendToLobby(p);return status(p)
 elseif action=='allModels'then
  task.spawn(function()
   local results={};workspace:SetAttribute('CivicBatchQA','running')
   local ok,err=xpcall(function()
    local names={};for _,m in RS.ItemModels:GetChildren()do if m:GetAttribute('VisualRevision')=='Civic_20261009_v1'then table.insert(names,m.Name)end end;table.sort(names)
    for _,modelName in names do
     local car,id=Events.FromIndexName(modelName);local itemName=car and Mutations.Wrap(car,nil,id)or modelName
     seed(p,{itemName});local tool
     for _,t in p.Backpack:GetChildren()do if t:GetAttribute('ItemName')==itemName then tool=t;break end end
     assert(tool,modelName..' missing hotbar tool');p.Character.Humanoid:EquipTool(tool);task.wait(.12)
     local held=assert(tool:FindFirstChild('HeldItem'),modelName..' missing held model');assert(held:GetAttribute('ItemAssembly'))
     p.Character.Humanoid:UnequipTools();QA.hotbar.place(p,1);assert(s.placed[1]==itemName and #s.inventory==0,modelName..' placement failed')
     task.wait(.12);QA.unplace(p,1);assert(s.inventory[1]==itemName and #s.placed==0,modelName..' unplace failed')
     table.insert(results,{name=modelName,item=itemName,hotbar=true,held=true,place=true,unplace=true});workspace:SetAttribute('CivicBatchCount',#results)
    end
   end,debug.traceback)
   workspace:SetAttribute('CivicBatchQA',ok and 'passed' or tostring(err));workspace:SetAttribute('CivicBatchResults',game.HttpService:JSONEncode(results))
  end)
  return 'started'
 end
 error('Unknown QA action '..tostring(action))
end
workspace:SetAttribute('CivicQAReady',true)
