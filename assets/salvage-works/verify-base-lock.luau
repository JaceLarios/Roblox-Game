local Gate=require(game.ServerStorage.BaseGate)
local char=Instance.new("Model") local root=Instance.new("Part",char) root.Name="HumanoidRootPart" root.Position=Vector3.zero
local h=Instance.new("Humanoid",char)
local button=Instance.new("Part") button.Position=Vector3.zero
local owner={Character=char} local visitor={Character=char}
local plot={owner=owner,lockButton=button,lockedUntil=0,lockCooldownUntil=0}
assert(not Gate.TryActivate(plot,visitor,100,60,60),"Visitor allowed")
root.Position=Vector3.new(30,0,0) assert(not Gate.TryActivate(plot,owner,100,60,60),"Distant activation")
root.Position=Vector3.zero
assert(Gate.TryActivate(plot,owner,100,60,60))
assert(plot.lockedUntil==160 and plot.lockCooldownUntil==220)
assert(not Gate.TryActivate(plot,owner,101,60,60),"Duplicate lock")
assert(not Gate.TryActivate(plot,owner,160,60,60),"Cooldown bypass")
assert(Gate.TryActivate(plot,owner,220,60,60),"Recharge failed")
local model=Instance.new("Model") local gate=Gate.Create(model,Vector3.zero,Vector3.xAxis,"Default",26,16)
Gate.Update(gate,true,60,120,true) assert(gate.barrier.CanCollide)
Gate.Update(gate,false,0,60,true) assert(not gate.barrier.CanCollide and gate.labels[1].Text:find("RECHARGING"))
Gate.Update(gate,false,0,0,false) assert(not gate.barrier.CanCollide and gate.labels[1].Text=="UNCLAIMED BASE")
char:Destroy() button:Destroy() model:Destroy()
return "Ownership, distance, duplicate lock, expiry state, cooldown, recharge and unclaimed reset passed"
