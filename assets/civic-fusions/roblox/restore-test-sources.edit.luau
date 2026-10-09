-- Required cleanup after the isolated Civic Play session. Never publish QA hooks.
assert(not game.RunService:IsRunning(), 'Stop Play first')
local originals=_G.CivicTestOriginals
local H=game.HttpService
local previous=H.HttpEnabled
local ok,result=xpcall(function()
 if not originals then
  H.HttpEnabled=true;originals={}
  for _,name in {'DataManager','LeaderboardService','PlaytimeLeaderboardService','RaceLeaderboardService','PlotManager','ScrapSpawner','RaceService'}do
   originals[name]=H:GetAsync('http://127.0.0.1:18773/snapshots/before-test-'..name..'.luau')
  end
 end
 -- Fetch every original before changing anything, so missing backups fail safely.
 local count=0
 for name,source in originals do
  assert(not source:find('_G.Civic'),'Backup itself contains QA hooks: '..name)
  assert(not source:find('Isolated Studio test session'),'QA DataManager backup')
 end
 for name,source in originals do game.ServerScriptService[name].Source=source;count+=1 end
 _G.CivicTestOriginals=nil
 return count
end,debug.traceback)
H.HttpEnabled=previous
assert(ok,result)
return {restored=result}
