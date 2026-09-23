-- SurfaceGui scrolling requires a PlayerGui host. Move each replicated surface
-- locally while retaining its server-owned children and live ranking updates.
local Players=game:GetService("Players")
local playerGui=Players.LocalPlayer:WaitForChild("PlayerGui")
local function attach(gui)
 if not gui:IsA("SurfaceGui") or gui.Name~="RankingSurface" then return end
 local panel=gui.Parent
 if not panel or not panel:IsA("BasePart") then return end
 local root=workspace:FindFirstChild("CentralLeaderboards")
 if not root or not panel:IsDescendantOf(root) then return end
 gui.Adornee=panel gui.Active=true gui.ResetOnSpawn=false
 gui.Parent=playerGui
 local connection
 connection=panel.AncestryChanged:Connect(function()
  if not panel:IsDescendantOf(workspace) then
   connection:Disconnect() gui:Destroy()
  end
 end)
end
workspace.DescendantAdded:Connect(function(v) if v:IsA("SurfaceGui") then task.defer(attach,v) end end)
for _,v in ipairs(workspace:GetDescendants()) do if v:IsA("SurfaceGui") then attach(v) end end
