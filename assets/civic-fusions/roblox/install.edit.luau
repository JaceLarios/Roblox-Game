-- Installs only the confirmed Civic batch and the compatible recipe registry.
assert(not game.RunService:IsRunning(),'Stop Play before installing')
local H=game.HttpService;local oldHttp=H.HttpEnabled;H.HttpEnabled=true
local URL='http://127.0.0.1:18773/'
local result
local ok,err=xpcall(function()
 local manifest=H:JSONDecode(H:GetAsync(URL..'manifest.json'))
 local stage=assert(game.ServerStorage:FindFirstChild(assert(_G.CivicImport.stage)))
 assert(not _G.CivicImport.running and #_G.CivicImport.errors==0,'Import must finish without errors')
 assert(#manifest==32)
 for _,r in manifest do
  local m=assert(stage:FindFirstChild(r.name),'Missing '..r.name)
  assert(m:GetAttribute('ImportComplete')and m:GetAttribute('TriangleCount')<90000)
 end
 for _,name in {'FusionRecipes'}do
  local before=H:GetAsync(URL..'snapshots/ReplicatedStorage.'..name..'.luau')
  assert(game.ReplicatedStorage[name].Source:gsub('\r','')==before:gsub('\r',''),'Studio source changed during import: '..name)
 end
 local backup=Instance.new('Folder');backup.Name='BeforeCivicImport_'..os.time();backup.Parent=game.ServerStorage
 for _,name in {'FusionRecipes'}do
  local module=game.ReplicatedStorage[name];module:Clone().Parent=backup
  module.Source=H:GetAsync(URL..name..'.luau')
 end
 for _,r in manifest do
  local old=game.ReplicatedStorage.ItemModels:FindFirstChild(r.name);if old then old.Parent=backup end
  local m=stage[r.name]
  m.Parent=game.ReplicatedStorage.ItemModels
 end
 result={installed=#manifest,backup=backup.Name,placeId=game.PlaceId}
 _G.CivicInstalled=result
 game.ChangeHistoryService:SetWaypoint('Install Civic and 31 approved fusion variants')
end,debug.traceback)
H.HttpEnabled=oldHttp;assert(ok,err);return result
