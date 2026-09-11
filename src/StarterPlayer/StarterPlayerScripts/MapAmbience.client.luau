-- Cosmetic client-only movement. No physics, earnings, or player-data changes.
local RunService = game:GetService("RunService")
local root = workspace:WaitForChild("JunkyardRefresh",30)
if not root then return end
local motion = root:WaitForChild("Motion",10)
if not motion then return end
local fans,magnet,forklift = {},nil,nil
local magnetBase
local function register(m)
 if not m:IsA("Model") then return end
 if m.Name=="WorkshopFan" then fans[m]={model=m,base=m:GetPivot()}
 elseif m.Name=="CraneMagnet" then magnet=m magnetBase=m:GetPivot()
 elseif m.Name=="DeliveryForklift" then forklift=m end
end
for _,m in motion:GetChildren() do register(m) end
motion.ChildAdded:Connect(register)
motion.ChildRemoved:Connect(function(m)
 fans[m]=nil
 if magnet==m then magnet=nil end
 if forklift==m then forklift=nil end
end)
local elapsed,accumulated=0,0
local connection
connection=RunService.Heartbeat:Connect(function(dt)
 if not root.Parent then connection:Disconnect() return end
 elapsed+=dt accumulated+=dt
 if accumulated<1/30 then return end
 accumulated=0
 local camera=workspace.CurrentCamera
 if not camera then return end
 local eye=camera.CFrame.Position
 for _,f in fans do
  if f.model.Parent and (eye-f.base.Position).Magnitude<250 then
   f.model:PivotTo(f.base*CFrame.Angles(0,0,elapsed*1.5))
  end
 end
 if magnet and magnet.Parent and (eye-magnetBase.Position).Magnitude<350 then
  magnet:PivotTo(magnetBase*CFrame.new(0,math.sin(elapsed*0.55)*0.9,0))
 end
 if forklift and forklift.Parent then
  -- Stays on the outer delivery lane, beyond every player plot.
  local angle=elapsed*0.035
  local pos=Vector3.new(math.cos(angle)*263,0.3,math.sin(angle)*263)
  local tangent=Vector3.new(-math.sin(angle),0,math.cos(angle))
  if (eye-pos).Magnitude<500 then
   forklift:PivotTo(CFrame.lookAt(pos,pos-tangent))
  end
 end
end)
