-- Play-session-only hooks: provides QA cars without editing ownership or rewards.
assert(game:GetService('RunService'):IsRunning(),'Use Server in Play')
local race=require(game.ServerScriptService.RaceService)
local track=require(game.ServerStorage.RaceTrack)
local player=game.Players:GetPlayers()[1];assert(player and player.Character)
_G.QARaceCar=_G.QARaceCar or 'Toro'
_G.QARaceEvents={}
race.Configure({
 cars=function()return {_G.QARaceCar}end,
 owns=function(_,name)return name==_G.QARaceCar end,
 unlocked=function()return true end,
 canRace=function()return true end,
 levelCleared=function(_,level)table.insert(_G.QARaceEvents,{level=level});return false end,
 runOver=function(_,distance)table.insert(_G.QARaceEvents,{distance=distance})end,
 sendHome=function(p)if p.Character then p.Character:PivotTo(track.LobbySpawn())end end,
})
race.Leave(player)
task.delay(1,function()
 local h=player.Character:FindFirstChildOfClass('Humanoid');h.Sit=false
 player.Character:PivotTo(CFrame.new(track.PointAt(-30,0,4)))
 task.wait(1);workspace:SetAttribute('RaceNextAt',workspace:GetServerTimeNow()+1)
end)
return 'Queued disposable race test: '.._G.QARaceCar
