assert(not game.RunService:IsRunning())
assert(not _G.CivicTestOriginals,'Test source overrides already exist')
local H=game.HttpService;local old=H.HttpEnabled;H.HttpEnabled=true
local originals={};_G.CivicTestOriginals=originals
local function edit(name,change)
 local module=game.ServerScriptService[name];originals[name]=module.Source
 H:PostAsync('http://127.0.0.1:18773/snapshot',H:JSONEncode({name='before-test-'..name..'.luau',content=module.Source}),Enum.HttpContentType.ApplicationJson)
 module.Source=change(module.Source)
end
edit('DataManager',function(s)return s:gsub('return DataManager%s*$',[[
-- Isolated Studio test session: never read/write the user's saved progress.
assert(game.RunService:IsStudio())
DataManager.Load=function(player)
 local d=DataManager.DefaultData();d.coins=100000;d.bolts=500;d.tutorialDone=true;d.starterPackGiven=true;d.lastDailyDay=math.floor(os.time()/86400)
 return d,true
end
DataManager.Save=function()return false end
return DataManager
]])end)
for _,name in {'LeaderboardService','PlaytimeLeaderboardService','RaceLeaderboardService'}do edit(name,function(s)return s:gsub('return '..name..'%s*$',name..'.PushToStore=function()end\nreturn '..name)end)end
local hooks=H:GetAsync('http://127.0.0.1:18773/gameplay-hooks.luau')
edit('PlotManager',function(s)return s..hooks end)
edit('ScrapSpawner',function(s)
 local marker='while true do\n\tspawnScrap()'
 local first=assert(s:find(marker,1,true))
 return s:sub(1,first-1)..'_G.CivicSpawnerQA={spawn=spawnItemAt,ride=ride,riders=riders}\n'..s:sub(first)
end)
edit('RaceService',function(s)return s:gsub('return Race%s*$','_G.CivicRaceQA={racers=racers,build=buildCar}\nreturn Race')end)
H.HttpEnabled=old
return 'Temporary isolated QA session configured; restore originals after Play'
