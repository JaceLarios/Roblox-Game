-- Bright shared sky and continuous scenic boundaries outside gameplay.
local Environment={}
local V,CF,RGB=Vector3.new,CFrame.new,Color3.fromRGB
local function part(parent,name,size,cf,color,material)
 local p=Instance.new("Part") p.Name=name p.Size=size p.CFrame=cf p.Color=color
 p.Material=material p.Anchored=true p.CanCollide=true p.CanQuery=true p.CanTouch=false p.Parent=parent
 p.TopSurface=Enum.SurfaceType.Smooth p.BottomSurface=Enum.SurfaceType.Smooth return p
end
function Environment.Build()
 local L=game.Lighting
 L.ClockTime=13.2 L.Brightness=2.8 L.ExposureCompensation=.05
 L.Ambient=RGB(140,151,165) L.OutdoorAmbient=RGB(158,177,193)
 L.EnvironmentDiffuseScale=.8 L.EnvironmentSpecularScale=.22
 L.FogColor=RGB(171,216,248) L.FogStart=360 L.FogEnd=800
 local sky=L:FindFirstChildOfClass("Sky") or Instance.new("Sky",L)
 sky.Name="Sky"
 for _,face in ipairs({"Bk","Dn","Ft","Lf","Rt","Up"}) do
  sky["Skybox"..face]="rbxasset://textures/sky/sky512_"..string.lower(face)..".tex"
 end
 sky.StarCount=0 sky.CelestialBodiesShown=true sky.SunAngularSize=12
 local at=L:FindFirstChildOfClass("Atmosphere") or Instance.new("Atmosphere",L)
 at.Density=.24 at.Offset=.15 at.Color=RGB(187,224,255) at.Decay=RGB(120,159,196) at.Haze=1.2 at.Glare=.08
 local clouds=workspace.Terrain:FindFirstChildOfClass("Clouds") or Instance.new("Clouds",workspace.Terrain)
 clouds.Name="FairWeatherClouds" clouds.Enabled=true clouds.Cover=.48 clouds.Density=.58 clouds.Color=RGB(255,255,255)
 local bloom=L:FindFirstChildOfClass("BloomEffect") if bloom then bloom.Intensity=.08 bloom.Threshold=1.6 bloom.Size=20 end
 local sun=L:FindFirstChildOfClass("SunRaysEffect") if sun then sun.Intensity=.035 sun.Spread=.75 end
 game.StarterPlayer.CameraMaxZoomDistance=40
 for _,player in ipairs(game.Players:GetPlayers()) do player.CameraMaxZoomDistance=40 end
 if not Environment.connected then
  Environment.connected=true game.Players.PlayerAdded:Connect(function(player) player.CameraMaxZoomDistance=40 end)
 end
 local old=workspace:FindFirstChild("WorldBackdrop")
 if old and old:GetAttribute("Version")==4 then return old end
 if old then old:Destroy() end
 -- Persistent keeps the horizon present when streaming is enabled.
 local root=Instance.new("Model",workspace) root.Name="WorldBackdrop" root.ModelStreamingMode=Enum.ModelStreamingMode.Persistent root:SetAttribute("Version",4)
 local zones={
  {name="Junkyard",center=V(),radius=360,height=100,rock=RGB(109,123,111),green=RGB(92,151,73)},
  {name="Brainrot",center=V(0,0,900),radius=183,height=100,rock=RGB(135,160,135),green=RGB(84,182,100)},
  {name="Haunted",center=V(1000,0,900),radius=183,height=100,rock=RGB(100,107,129),green=RGB(77,120,110)},
 }
 for _,zone in ipairs(zones) do
  local f=Instance.new("Folder",root) f.Name=zone.name
  local r=zone.radius local n=48 local step=2*math.pi/n
  local ground=part(f,"EdgeGround",V(1,(r+30)*2,(r+30)*2),CF(zone.center+V(0,-.55,0))*CFrame.Angles(0,0,math.pi/2),zone.green,Enum.Material.Grass)
  ground.Shape=Enum.PartType.Cylinder
  for i=0,n-1 do
   local a=i*step local radial=V(math.cos(a),0,math.sin(a))
   local cf=CFrame.lookAt(zone.center+radial*r,zone.center)
   local h=zone.height+math.sin(i*1.7)*9
   -- Overlapping rock segments close every horizon gap; no invisible viewing wall.
   part(f,"ContinuousCliff",V(2*r*math.tan(step/2)+4,h+25,24),cf*CF(0,(h-45)/2,0),zone.rock,Enum.Material.Rock)
   local boulder=part(f,"RockFace",V(2*r*math.tan(step/2)*1.8,h+35,55),cf*CF(0,h/2-8,-11)*CFrame.Angles(0,0,math.sin(i)*.10),zone.rock:Lerp(RGB(161,171,149),(i%3)*.08),Enum.Material.Rock)
   local boulderMesh=Instance.new("SpecialMesh",boulder) boulderMesh.MeshType=Enum.MeshType.Sphere boulder.CanCollide=false boulder.CanQuery=false
   local crest=part(f,"PlantedRidge",V(2*r*math.tan(step/2)*1.7,36,55),cf*CF(0,h-6,0),zone.green,Enum.Material.Grass) local crestMesh=Instance.new("SpecialMesh",crest) crestMesh.MeshType=Enum.MeshType.Sphere crest.CanCollide=false crest.CanQuery=false
   if i%2==0 and i%12~=0 then -- Keep cardinal mainland travel gates clear.
    local bank=part(f,"LowerBank",V(39,24,34),cf*CF(0,5,-26),zone.green,Enum.Material.Grass) local bankMesh=Instance.new("SpecialMesh",bank) bankMesh.MeshType=Enum.MeshType.Sphere
    local trunk=part(f,"TreeTrunk",V(2,18,2),cf*CF(0,19,-26),RGB(112,85,60),Enum.Material.Wood)
    local crown=part(f,"TreeCanopy",V(21,23,21),cf*CF(0,34,-26),zone.green:Lerp(RGB(159,193,93),.25),Enum.Material.Grass) local crownMesh=Instance.new("SpecialMesh",crown) crownMesh.MeshType=Enum.MeshType.Sphere
   end
  end
 end
 return root
end
return Environment
