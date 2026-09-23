-- Decorative mechanic equipment only: no prompts, pickups, collisions or data writes.
local Props={}
local V,CF,RGB=Vector3.new,CFrame.new,Color3.fromRGB
local steel=RGB(146,163,169) local dark=RGB(32,42,48) local rust=RGB(140,77,41)
local red=RGB(215,65,39) local yellow=RGB(245,183,43)
local function group(parent,name)
 local f=Instance.new("Model",parent) f.Name=name f:SetAttribute("DecorationOnly",true) return f
end
local function part(f,n,size,cf,col,mat)
 local p=Instance.new("Part") p.Name=n p.Size=size p.CFrame=cf p.Color=col
 p.Material=mat or Enum.Material.Metal p.Anchored=true p.CanCollide=false p.CanTouch=false p.CanQuery=false
 p.TopSurface=Enum.SurfaceType.Smooth p.BottomSurface=Enum.SurfaceType.Smooth p.Parent=f return p
end
local function cyl(f,n,size,cf,col,mat)
 local p=part(f,n,size,cf,col,mat) p.Shape=Enum.PartType.Cylinder return p
end
local function rod(f,n,a,b,width,col)
 return part(f,n,V(width,width,(b-a).Magnitude),CFrame.lookAt((a+b)/2,b),col)
end
local function wrench(f,cf,scale)
 scale=scale or 1
 part(f,"WrenchShaft",V(.22,.12,1.6)*scale,cf,steel)
 for _,z in ipairs({-.9,.9}) do
  part(f,"WrenchJawBase",V(.65,.14,.28)*scale,cf*CF(0,0,z*scale),steel)
  for _,x in ipairs({-.25,.25}) do part(f,"OpenWrenchJaw",V(.17,.14,.45)*scale,cf*CF(x*scale,0,(z+math.sign(z)*.22)*scale),steel) end
 end
end
local function cart(parent,cf,col)
 local f=group(parent,"RollingToolCart")
 part(f,"Cabinet",V(4.6,3.6,2.5),cf*CF(0,2.4,0),col)
 part(f,"RubberWorktop",V(5,.3,2.8),cf*CF(0,4.35,0),dark,Enum.Material.DiamondPlate)
 for y=1.3,3.7,.8 do
  part(f,"DrawerFace",V(4.25,.66,.15),cf*CF(0,y,-1.34),col:Lerp(dark,.15))
  part(f,"ChromePull",V(2.7,.12,.18),cf*CF(0,y,-1.5),steel)
 end
 for _,x in ipairs({-1.8,1.8}) do for _,z in ipairs({-.85,.85}) do
  cyl(f,"Caster",V(.4,.8,.8),cf*CF(x,.5,z),dark,Enum.Material.SmoothPlastic)
  cyl(f,"CasterHub",V(.43,.34,.34),cf*CF(x,.5,z),steel)
 end end
 rod(f,"PushHandle",cf:PointToWorldSpace(V(2.6,3,-.8)),cf:PointToWorldSpace(V(2.6,3,.8)),.2,steel)
 wrench(f,cf*CF(-.8,4.55,0)*CFrame.Angles(0,.3,0),.8)
 part(f,"SocketTray",V(1.3,.12,.8),cf*CF(1,4.56,0),dark)
 for i=0,2 do cyl(f,"Socket",V(.3,.3,.3),cf*CF(.6+i*.4,4.76,0)*CFrame.Angles(0,0,math.pi/2),steel) end
 part(f,"ChippedPaint",V(.8,.38,.03),cf*CF(-1.5,1.4,-1.44),rust,Enum.Material.CorrodedMetal)
 return f
end
local function jack(parent,cf)
 local f=group(parent,"HydraulicFloorJack")
 for _,x in ipairs({-.6,.6}) do
  part(f,"JackRail",V(.35,.35,3.5),cf*CF(x,.55,0),red)
  for _,z in ipairs({-1.4,1.4}) do cyl(f,"JackWheel",V(.35,.6,.6),cf*CF(x,.35,z),steel) end
 end
 part(f,"JackCrossMember",V(1.5,.3,.6),cf*CF(0,.55,.9),red)
 rod(f,"LiftArm",cf:PointToWorldSpace(V(0,.6,1)),cf:PointToWorldSpace(V(0,1.35,-1)),.55,red)
 cyl(f,"LiftSaddle",V(.2,.9,.9),cf*CF(0,1.5,-1)*CFrame.Angles(0,0,math.pi/2),dark)
 rod(f,"JackHandle",cf:PointToWorldSpace(V(0,.7,1.4)),cf:PointToWorldSpace(V(0,3.5,2.3)),.14,steel)
 rod(f,"HandleGrip",cf:PointToWorldSpace(V(0,3,2.14)),cf:PointToWorldSpace(V(0,3.5,2.3)),.22,dark)
 return f
end
local function compressor(parent,cf)
 local f=group(parent,"AirCompressor")
 cyl(f,"PressureTank",V(4.2,2,2),cf*CF(0,1.65,0),red)
 for _,x in ipairs({-1.4,1.4}) do cyl(f,"Wheel",V(.5,1,1),cf*CF(x,.55,.4),dark,Enum.Material.SmoothPlastic) end
 part(f,"Motor",V(1.6,.9,1.4),cf*CF(.2,3,0),dark)
 for x=-.5,.8,.26 do part(f,"CoolingFin",V(.10,1,1.55),cf*CF(x,3,0),steel) end
 cyl(f,"GaugeRim",V(.16,.65,.65),cf*CF(-1,3,-.3)*CFrame.Angles(0,math.pi/2,0),steel)
 cyl(f,"GaugeFace",V(.18,.52,.52),cf*CF(-1,3,-.32)*CFrame.Angles(0,math.pi/2,0),RGB(246,235,200))
 part(f,"GaugeNeedle",V(.04,.22,.03),cf*CF(-1,3.1,-.43)*CFrame.Angles(0,0,-.4),dark)
 for i=0,11 do
  local a=i*math.pi/6 local b=(i+1)*math.pi/6
  rod(f,"CoiledAirHose",cf:PointToWorldSpace(V(math.cos(a)*1.3,.18,math.sin(a)*1.0-2)),cf:PointToWorldSpace(V(math.cos(b)*1.3,.18,math.sin(b)*1.0-2)),.13,dark)
 end
 part(f,"TankWear",V(.8,.2,.06),cf*CF(.6,1.6,-1.01),rust,Enum.Material.CorrodedMetal)
 return f
end
function Props.Workshop(parent,frame)
 local f=group(parent,"MechanicEquipment")
 cart(f,frame*CF(-36,.55,-35)*CFrame.Angles(0,math.pi,0),red)
 compressor(f,frame*CF(36,.55,-35))
 jack(f,frame*CF(-16,.55,36)*CFrame.Angles(0,-.5,0))
 for _,x in ipairs({-25,25}) do
  wrench(f,frame*CF(x-3,4.62,39)*CFrame.Angles(0,.6,0),1.2)
  part(f,"HammerHandle",V(.2,.2,2),frame*CF(x,4.65,39),RGB(171,112,55),Enum.Material.Wood)
  part(f,"HammerHead",V(1,.4,.5),frame*CF(x,4.75,38),steel)
  part(f,"OilCan",V(.8,1,.55),frame*CF(x+4,5,39),yellow)
  rod(f,"OilSpout",frame:PointToWorldSpace(V(x+4,5.5,39)),frame:PointToWorldSpace(V(x+4.8,5.9,39)),.10,steel)
 end
 return f
end
function Props.Yard(parent)
 local f=group(parent,"YardMechanicStations")
 -- Between the eight approach roads, beyond the 78-stud random drop disk.
 for i=0,7 do
  local a=(i+.5)*math.pi/4 local cf=CFrame.lookAt(V(math.cos(a)*87,1.23,math.sin(a)*87),V(0,1.23,0))
  local station=group(f,"RepairStation"..(i+1))
  if i%2==0 then cart(station,cf,RGB(29,136,174)) jack(station,cf*CF(4,0,0))
  else compressor(station,cf) end
  part(station,"ServiceMat",V(9,.06,7),cf*CF(1,.03,0),dark,Enum.Material.DiamondPlate)
 end
 return f
end
return Props
