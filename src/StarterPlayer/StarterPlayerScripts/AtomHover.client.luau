-- Independent Atom Rider cosmetics. RaceDrive, wheel joints, seats and physics stay owned by the race system.
local RS = game:GetService('ReplicatedStorage')
local RunService = game:GetService('RunService')
local CollectionService = game:GetService('CollectionService')
local HoverVisuals = require(RS:WaitForChild('HoverVisuals'))
local tag = 'ReactorHoverVisual'
local active, pending = {}, {}
local function eligible(root)
 return root:IsA('BasePart') and ((root.Name == 'Atom Rider' and root:GetAttribute('ItemAssembly') == true) or CollectionService:HasTag(root,tag))
end
local function consider(root)
 if not eligible(root) or active[root] or pending[root] then return end
 pending[root] = true
 task.spawn(function()
  for _=1,50 do
   if not root:IsDescendantOf(workspace) then break end
   local visual = root:FindFirstChild('Visual')
   if visual and visual:IsA('Model') then
    local ok, controller = pcall(HoverVisuals.Attach,root,visual)
    if ok then active[root] = {controller=controller,last=root.CFrame} else warn('[AtomHover] '..tostring(controller)) end
    break
   end
   task.wait(.1)
  end
  pending[root] = nil
 end)
end
workspace.DescendantAdded:Connect(consider)
CollectionService:GetInstanceAddedSignal(tag):Connect(consider)
for _, o in workspace:GetDescendants() do consider(o) end
RunService:BindToRenderStep('AtomHoverCosmetics',Enum.RenderPriority.Last.Value+10,function(dt)
 local camera = workspace.CurrentCamera
 for root,state in active do
  if not root:IsDescendantOf(workspace) or not eligible(root) or root:FindFirstChild('Visual') ~= state.controller.Source then
   state.controller:Destroy(); active[root] = nil
   if root:IsDescendantOf(workspace) then consider(root) end
  else
   local near = camera and (camera.CFrame.Position-root.Position).Magnitude < 180
   state.controller:SetEnabled(near == true)
   if near then
    local delta = state.last:ToObjectSpace(root.CFrame)
    local speed = math.min((root.Position-state.last.Position).Magnitude / math.max(dt,.001) / 70,1)
    local yaw = math.atan2(delta.ZVector.X,delta.ZVector.Z)
    state.controller:Step(dt,speed,math.clamp(yaw/math.max(dt,.001),-1,1))
   end
   state.last = root.CFrame
  end
 end
end)
