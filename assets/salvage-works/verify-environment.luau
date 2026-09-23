local root=workspace.WorldBackdrop local out={}
for _,zone in ipairs({{name="Junkyard",center=Vector3.zero},{name="Brainrot",center=Vector3.new(0,0,900)},{name="Haunted",center=Vector3.new(1000,0,900)}}) do
 local rp=RaycastParams.new() rp.FilterType=Enum.RaycastFilterType.Include rp.FilterDescendantsInstances={root[zone.name]}
 local rays=0
 for _,height in ipairs({5,45,65}) do for i=0,359 do local a=math.rad(i) local hit=workspace:Raycast(zone.center+Vector3.new(0,height,0),Vector3.new(math.cos(a),0,math.sin(a))*500,rp) assert(hit,"Horizon gap "..zone.name.." "..height.." "..i) rays+=1 end end
 out[zone.name]=rays
end
local lamps={} for i=1,8 do local n=0 for _,v in ipairs(workspace.JunkyardRefresh.Garages["Garage"..i]:GetDescendants()) do if v:IsA("SurfaceLight") then n+=1 end end assert(n==15) lamps[i]=n end
assert(workspace.Terrain.FairWeatherClouds.Enabled)
assert(game.Players:GetPlayers()[1].CameraMaxZoomDistance==40)
return {horizonRays=out,ceilingLightsPerBase=lamps}
