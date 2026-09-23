-- Studio Server Play only. Temporary NPC copies; no player data is changed.
-- Tests route geometry ONLY. NPCs do not trigger player-only lethal road lasers.
local Layout=require(game.ReplicatedStorage.JunkyardLayout)
local player=game.Players:GetPlayers()[1] local character=assert(player and player.Character,"Character unavailable")
local prev=character.Archivable character.Archivable=true local template=character:Clone() character.Archivable=prev
for _,v in ipairs(template:GetDescendants()) do if v:IsA("Script") or v:IsA("LocalScript") or v:IsA("Tool") then v:Destroy() end end
local f=Instance.new("Folder",workspace) f.Name="TemporaryRouteProbes"
local probes={}
for i=1,8 do
 local a=(i-1)*math.pi/4 local dir=Vector3.new(math.cos(a),0,math.sin(a))
 local rig=template:Clone() rig.Name="Route"..i
 for _,p in ipairs(rig:GetDescendants()) do if p:IsA("BasePart") then p.CollisionGroup="PlotOwner"..i end end
 rig.Parent=f rig:PivotTo(CFrame.new(dir*90+Vector3.new(0,5,0)))
 local humanoid=rig:FindFirstChildOfClass("Humanoid") humanoid.WalkSpeed=22
 local root=rig:FindFirstChild("HumanoidRootPart") root:SetNetworkOwner(nil)
 probes[i]={rig=rig,humanoid=humanoid,root=root,target=dir*Layout.PlotRadius+Vector3.new(0,3,0)}
end
template:Destroy()
task.wait(.5)
local started=os.clock()
for _,v in ipairs(probes) do v.humanoid:MoveTo(v.target) end
local done={} local completed=0
while os.clock()-started<9 do
 for i,v in ipairs(probes) do
  if not done[i] and (v.root.Position*Vector3.new(1,0,1)-v.target*Vector3.new(1,0,1)).Magnitude<2 then done[i]=os.clock()-started completed+=1 end
 end
 if completed==8 then break end task.wait(.05)
end
local out={} for i,v in ipairs(probes) do out[i]={base=i,seconds=done[i],remaining=(v.root.Position*Vector3.new(1,0,1)-v.target*Vector3.new(1,0,1)).Magnitude} end
f:Destroy()
assert(completed==8,"Incomplete routes: "..game.HttpService:JSONEncode(out))
return game.HttpService:JSONEncode(out)
