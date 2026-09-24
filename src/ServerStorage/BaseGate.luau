-- Server-owned base gate and lock validation. No client controls lock state.
local Gate={}
local V,CF=Vector3.new,CFrame.new
local function part(parent,name,size,cf,color)
 local p=Instance.new("Part") p.Name=name p.Size=size p.CFrame=cf p.Color=color
 p.Anchored=true p.CanCollide=false p.CanTouch=false p.CanQuery=false
 p.Material=Enum.Material.Metal p.Parent=parent return p
end
function Gate.Create(model,position,side,group,width,height)
 local f=Instance.new("Folder",model) f.Name="BaseEntrance"
 local frame=CFrame.fromMatrix(position,side,V(0,1,0))
 local navy=Color3.fromRGB(30,46,57) local amber=Color3.fromRGB(255,179,37)
 for _,x in ipairs({-width/2-.7,width/2+.7}) do
  part(f,"GatePost",V(1.4,height+3,1.4),frame*CF(x,(height+3)/2,0),navy)
  for y=1,5,1.4 do part(f,"SafetyBand",V(1.45,.6,1.45),frame*CF(x,y,0),amber) end
 end
 local header=part(f,"GateStatus",V(width+3,2.5,1),frame*CF(0,height-.6,0),navy)
 local labels={}
 for _,face in ipairs({Enum.NormalId.Front,Enum.NormalId.Back}) do
  local gui=Instance.new("SurfaceGui",header) gui.Face=face gui.LightInfluence=0 gui.PixelsPerStud=25 gui.SizingMode=Enum.SurfaceGuiSizingMode.PixelsPerStud
  local t=Instance.new("TextLabel",gui) t.Size=UDim2.fromScale(.92,.8) t.Position=UDim2.fromScale(.04,.1) t.BackgroundTransparency=1 t.Font=Enum.Font.FredokaOne t.TextScaled=true t.TextColor3=Color3.fromRGB(210,255,226)
  table.insert(labels,t)
 end
 local barrier=part(f,"LockGate",V(width,height,1),frame*CF(0,height/2+.5,0),Color3.fromRGB(255,65,51))
 barrier.Material=Enum.Material.Neon barrier.Transparency=1 barrier.CollisionGroup=group
 local bars={}
 for x=-width/2+2,width/2-1,3 do
  local p=part(f,"GateBar",V(.22,height-.6,.3),frame*CF(x,height/2+.5,-.56),amber)
  p.Transparency=1 table.insert(bars,p)
 end
 return {barrier=barrier,bars=bars,labels=labels}
end
-- ownerName is the owning player's username, or nil for an empty base. An
-- owned base that is not locked shows whose garage it is.
function Gate.Update(gate,locked,remaining,cooldown,ownerName)
 gate.barrier.CanCollide=locked
 gate.barrier.Transparency=locked and .80 or 1
 for _,bar in ipairs(gate.bars) do bar.Transparency=locked and .12 or 1 end
 local text=not ownerName and "UNCLAIMED BASE" or (locked and ("LOCKED  "..math.max(0,math.ceil(remaining)).."s") or (ownerName.."'s Garage"))
 for _,label in ipairs(gate.labels) do
  label.Text=text label.TextColor3=locked and Color3.fromRGB(255,211,167) or Color3.fromRGB(190,255,218)
 end
end
function Gate.TryActivate(plot,player,now,seconds,cooldown)
 if plot.owner~=player then return false,"Only the owner can lock this base." end
 local char=player.Character local root=char and char:FindFirstChild("HumanoidRootPart")
 local humanoid=char and char:FindFirstChildOfClass("Humanoid")
 if not root or not humanoid or humanoid.Health<=0 then return false,"Your character must be alive to lock the base." end
 if (root.Position-plot.lockButton.Position).Magnitude>12 then return false,"Move closer to the Lock Base button." end
 if now<plot.lockedUntil then return false,"Your base is already locked." end
 if now<plot.lockCooldownUntil then return false,string.format("The lock is recharging — %ds left.",math.ceil(plot.lockCooldownUntil-now)) end
 plot.lockedUntil=now+seconds plot.lockCooldownUntil=plot.lockedUntil+cooldown
 return true
end
return Gate
