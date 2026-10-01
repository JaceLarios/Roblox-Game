-- One local controller, capped at 12 nearby cars. No replicated per-frame changes.
local Effects=require(game.ReplicatedStorage:WaitForChild("VehicleAddonEffects"))
local RunService=game:GetService("RunService")
local candidates,states={},{}
local function consider(object)
	if not object:IsA("BasePart") then return end
	if object:GetAttribute("ItemAssembly") and Effects.Supports(object.Name) then candidates[object]=true end
end
workspace.DescendantAdded:Connect(consider)
for _,object in workspace:GetDescendants() do consider(object) end
workspace.DescendantRemoving:Connect(function(object)
	if candidates[object] then candidates[object]=nil end
	if states[object] then Effects.Destroy(states[object]);states[object]=nil end
end)
local elapsed=0
RunService.Heartbeat:Connect(function(dt)
	elapsed+=dt
	if elapsed<.25 then return end
	elapsed=0
	local camera=workspace.CurrentCamera
	if not camera then return end
	local nearby={}
	for root in candidates do
		if root.Parent then
			local distance=(root.Position-camera.CFrame.Position).Magnitude
			local visual=root:FindFirstChild("Visual")
			local body=visual and visual:FindFirstChildWhichIsA("BasePart",true)
			if distance<130 and body and body.Transparency<.9 and body.LocalTransparencyModifier<.9 then
				table.insert(nearby,{root=root,distance=distance})
			end
		end
	end
	table.sort(nearby,function(a,b)return a.distance<b.distance end)
	local selected={}
	for i=1,math.min(12,#nearby) do
		local root=nearby[i].root
		local state=states[root]
		if not state then state=Effects.Attach(root);states[root]=state end
		if state then selected[root]=true;Effects.Step(state,os.clock());Effects.SetActive(state,true) end
	end
	for root,state in states do if not selected[root] then Effects.SetActive(state,false) end end
end)
RunService.RenderStepped:Connect(function()
	local time=os.clock()
	for _,state in states do if state.active then Effects.Step(state,time) end end
end)
