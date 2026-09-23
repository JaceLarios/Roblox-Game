assert(not game:GetService("RunService"):IsRunning(),"Stop Play first")
local names={"Inline 4","V6 Engine","V8 Engine","Jet Engine"}
local t=game.ReplicatedStorage.ItemModels local stage=assert(game.ServerStorage:FindFirstChild("AddonHardwareStaging"))
for _,n in ipairs(names) do
 assert(t[n]:GetAttribute("CodexModelRevision")=="AddonHeavyWear_20260923_v3","Unexpected installed "..n)
 assert(stage[n]:GetAttribute("CodexModelRevision")=="AddonHardware_20260923_v4","Unexpected staged "..n)
end
local backup=Instance.new("Folder",game.ServerStorage) backup.Name="AddonsBeforeHardware_"..os.time()
for _,n in ipairs(names) do t[n].Parent=backup stage[n].Parent=t end
stage:Destroy()
return backup.Name
