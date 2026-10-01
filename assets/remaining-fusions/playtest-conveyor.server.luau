-- Play-session-only QA. Adds disposable visual copies, never inventory items.
assert(game:GetService('RunService'):IsRunning(),'Use Server in Play')
local visuals=require(game.ReplicatedStorage.ItemVisuals)
local conveyor=require(game.ServerStorage.YardConveyor)
local player=game.Players:GetPlayers()[1];assert(player and player.Character)
_G.QAOriginalCharacterFrame=_G.QAOriginalCharacterFrame or player.Character:GetPivot()
local report={}
for i,name in {'Toro SVO','Toro'}do
 local position=conveyor.PointAt(25+(i-1)*35)
 local item=visuals.Create(name,position,1)
 item:SetAttribute('CodexDisposableQA',true);item:SetAttribute('DroppedBy',player.UserId)
 item.Parent=workspace:WaitForChild('Scrap')
 table.insert(report,{name=name,start={item.Position.X,item.Position.Y,item.Position.Z},size={item.Size.X,item.Size.Y,item.Size.Z}})
end
local point=conveyor.PointAt(42);player.Character:PivotTo(CFrame.new(point+point.Unit*14+Vector3.new(0,4,0)))
_G.SecretConveyorQA={started=os.clock(),models=report}
return game.HttpService:JSONEncode(report)
