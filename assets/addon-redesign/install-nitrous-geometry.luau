assert(not game:GetService("RunService"):IsRunning(),"Stop Play first")
local s=game.ServerStorage
local m=assert(s:FindFirstChild("NitrousGeometryStaging"),"Build staging first")
assert(m:GetAttribute("CodexModelRevision")=="NitrousGeometry_20260923_v4")
local t=game.ReplicatedStorage.ItemModels
local old=assert(t:FindFirstChild("Nitrous Tank"))
assert(old:GetAttribute("CodexModelRevision")=="AddonHeavyWear_20260923_v3","Unexpected installed revision")
local backup=Instance.new("Folder") backup.Name="NitrousBeforeGeometry_"..os.time() backup.Parent=s
old.Parent=backup
m.Name="Nitrous Tank" m.Parent=t
local n=0 for _,p in ipairs(m:GetDescendants()) do if p:IsA("BasePart") then n+=1 end end
return backup.Name.." | parts="..n.." | size="..tostring(m:GetExtentsSize())
