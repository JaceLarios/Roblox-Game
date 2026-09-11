
-- Studio Edit/MCP command environment. Creates and cleans a temporary validation folder.
-- Requires loadstring in that command environment; never enables it in the game.
local sandbox=Instance.new("Folder")
sandbox.Name="MapRebuildValidation"
sandbox.Parent=game.ServerStorage
local ok,result=pcall(function()
 local baseline=assert(loadstring("return function(workspace)\n"..game.ServerStorage.MapBaseline.Source.."\nend"))()(sandbox)
 assert(baseline.Restore()==true,"Baseline did not reconstruct")
 assert(#sandbox.JunkyardScene:GetDescendants()==534,"Original geometry count mismatch")
 assert(baseline.Restore()==false,"Baseline duplicated objects")
 local map=assert(loadstring("return function(workspace)\n"..game.ServerStorage.MapRevamp.Source.."\nend"))()(sandbox)
 local refresh=map.Build()
 assert(#refresh:GetDescendants()==#workspace.JunkyardRefresh:GetDescendants(),"Refresh rebuild mismatch")
 assert(map.Build()==refresh,"Refresh duplicated objects")
 return {rebuildFromSources=true,originalDescendants=#sandbox.JunkyardScene:GetDescendants(),newDescendants=#refresh:GetDescendants(),spawnRestored=sandbox:FindFirstChild("SpawnLocation")~=nil}
end)
sandbox:Destroy()
assert(ok,result)
return result
