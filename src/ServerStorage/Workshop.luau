-- Enclosed mechanic workshops. Geometry uses the same frame as the earning pads.
local Workshop={}
local V,CF,RGB=Vector3.new,CFrame.new,Color3.fromRGB
local steel=RGB(71,90,99) local dark=RGB(27,43,53) local cream=RGB(238,226,189)
local amber=RGB(255,186,43) local rust=RGB(134,73,39)
local function part(f,n,size,cf,col,mat,solid)
 local p=Instance.new("Part") p.Name=n p.Size=size p.CFrame=cf p.Color=col
 p.Material=mat or Enum.Material.Metal p.Anchored=true p.CanCollide=solid==true
 p.CanTouch=false p.CanQuery=solid==true p.TopSurface=Enum.SurfaceType.Smooth p.BottomSurface=Enum.SurfaceType.Smooth p.Parent=f
 return p
end
function Workshop.Build(parent,index,layout,color)
 local f=Instance.new("Folder",parent) f.Name="Garage"..index
 f:SetAttribute("EarningPads",8) f:SetAttribute("FutureSecondFloorHeight",19)
 local angle=(index-1)*math.pi/4
 local frame=CFrame.lookAt(V(math.cos(angle)*layout.PlotRadius,0,math.sin(angle)*layout.PlotRadius),V())
 local half=layout.PlotSize/2 local height=36
 local function p(n,size,x,y,z,col,mat,solid,rot)
  return part(f,n,size,frame*CF(x,y,z)*(rot or CFrame.identity),col,mat,solid)
 end
 p("Foundation",V(layout.PlotSize+2,1,layout.PlotSize+2),0,-.05,0,steel,Enum.Material.Concrete,true)
 -- True openings: glass is solid, transparent and has no opaque wall behind it.
 local function windowWall(cf,width,opening,name)
  local sill,top=3.5,17
  local function piece(n,size,x,y,col,mat,solid)
   return part(f,name..n,size,cf*CF(x,y,0),col,mat,solid)
  end
  piece("SillWall",V(width,sill-.5,1.2),0,(sill+.5)/2,color,Enum.Material.Concrete,true)
  piece("UpperWall",V(width,height+.5-top,1.2),0,(height+.5+top)/2,color,Enum.Material.Concrete,true)
  local endWidth=(width-opening)/2
  for _,side in ipairs({-1,1}) do
   piece("Pier",V(endWidth,top-sill,1.2),side*(opening/2+endWidth/2),(top+sill)/2,color,Enum.Material.Concrete,true)
   piece("WindowJamb",V(.3,top-sill,.4),side*opening/2,(top+sill)/2,cream,Enum.Material.Metal)
  end
  local pane=piece("WindowGlass",V(opening,top-sill,.22),0,(top+sill)/2,RGB(196,228,237),Enum.Material.Glass,true)
  pane.Transparency=.82 pane.Reflectance=0 pane:SetAttribute("VisibilityWindow",true)
  for _,y in ipairs({sill,top}) do piece("WindowRail",V(opening+.5,.3,.5),0,y,cream,Enum.Material.Metal) end
  for x=-opening/2+12,opening/2-1,12 do piece("WindowMullion",V(.18,top-sill,.35),x,(top+sill)/2,steel,Enum.Material.Metal) end
 end
 windowWall(frame*CF(0,0,half),layout.PlotSize,70,"Rear")
 for _,side in ipairs({-1,1}) do
  local x=side*half
  windowWall(frame*CF(x,0,0)*CFrame.Angles(0,math.pi/2,0),layout.PlotSize,72,side==-1 and "Left" or "Right")
  p("InteriorWainscot",V(.16,2.8,layout.PlotSize-2),x-side*.7,1.9,0,steel,Enum.Material.DiamondPlate)
  p("InteriorCreamWall",V(.12,15,layout.PlotSize-2),x-side*.72,25,0,cream,Enum.Material.Plaster)
  for z=-36,36,12 do
   p("StructuralColumn",V(.65,height,.65),x-side*1.4,height/2+.5,z,dark)
   p("ColumnFoot",V(1.2,2,1.2),x-side*1.4,1.5,z,amber,Enum.Material.DiamondPlate)
  end
  -- Four display bays per side; no clutter in the center aisle.
  for row=0,3 do
   local z=-24+row*16 local slot=(side==-1 and 1 or 5)+row
   p("PadBayTrim",V(13,.10,13),side*28,.57,z,amber,Enum.Material.DiamondPlate)
   p("PadBayInset",V(12,.12,12),side*28,.62,z,steel,Enum.Material.Concrete)
   for _,dx in ipairs({-6,6}) do p("BayGuide",V(.18,.05,12),side*28+dx,.72,z,cream) end
  end

 end
 -- One centered entrance only: side piers and overhead lintel fully close the facade.
 local doorHalf=13
 local wing=half-doorHalf
 for _,side in ipairs({-1,1}) do
  windowWall(frame*CF(side*(doorHalf+wing/2),0,-half),wing,22,side==-1 and "FrontLeft" or "FrontRight")
  p("DoorJamb",V(1.2,21,2),side*13.6,11,-half,dark,Enum.Material.Metal,true)
  for y=2,8,2 do p("DoorSafetyStripe",V(1.3,.7,2.1),side*13.6,y,-half,amber) end
 end
 p("DoorLintel",V(26,15,1.2),0,29,-half,color,Enum.Material.Concrete,true)
 p("RollerDoorHousing",V(29,2,3),0,23,-half-1,steel)
 for y=22.4,23.6,.4 do p("RollerSlat",V(27,.12,.12),0,y,-half-2.6,cream) end
 -- Front service windows, framed artwork, vents and lit entry fittings.
 for _,side in ipairs({-1,1}) do
  local x=side*29
  p("ExteriorKickPlate",V(26,3,.25),x,2,-half-.8,steel,Enum.Material.DiamondPlate)
  p("WallVentFrame",V(8,3,.5),x,25,-half-.85,dark)
  for y=24,26,.5 do p("VentSlat",V(7,.15,.3),x,y,-half-1.15,steel) end
  local lamp=p("EntryLamp",V(3,.4,1.5),side*15,21,-half-1.2,cream,Enum.Material.Neon)
  local light=Instance.new("PointLight",lamp) light.Range=16 light.Brightness=.8 light.Color=amber
 end
 -- High ceiling, roof and structural beams: no installed second floor yet.
 p("SolidRoof",V(layout.PlotSize+4,1,layout.PlotSize+4),0,37,0,dark,Enum.Material.Metal,true)
 for z=-36,36,18 do
  p("RoofBeam",V(layout.PlotSize,1.3,1),0,35,z,steel)
  p("OverheadLightHousing",V(18,.4,2),0,34,z,dark)
  local light=p("WorkshopLight",V(16,.12,1.4),0,33.7,z,cream,Enum.Material.Neon)
  local lamp=Instance.new("SurfaceLight",light) lamp.Face=Enum.NormalId.Bottom lamp.Angle=125 lamp.Range=42 lamp.Brightness=1.5 lamp.Color=RGB(255,240,211) lamp.Shadows=false
 end
 for x=-36,36,9 do p("RoofStandingSeam",V(.18,.25,layout.PlotSize+3),x,37.6,0,steel) end
 -- Detailed rear service bench, pegboard, drawers and spare equipment.
 for _,x in ipairs({-25,25}) do
  p("ServiceBench",V(18,1,5),x,4,half-4,steel,Enum.Material.DiamondPlate,true)
  p("ToolChest",V(9,3.2,4),x,2,half-4,color,Enum.Material.Metal,true)
  for y=1,3,1 do
   p("Drawer",V(8,.7,.15),x,y,half-6.1,dark)
   p("DrawerPull",V(4,.14,.24),x,y,half-6.3,cream)
  end
 end
 p("Pegboard",V(34,6,.25),0,23,half-.9,steel,Enum.Material.DiamondPlate)
 for x=-15,15,3 do
  p("HangingTool",V(.25,3,.2),x,23,half-1.2,cream)
  p("SpannerHead",V(1,.6,.25),x,24.7,half-1.2,amber)
 end
 for _,x in ipairs({-38,38}) do
  for row=0,2 do
   local tire=p("SpareTyre",V(1.3,4,4),x,1.2+row*1.4,half-5,dark,Enum.Material.SmoothPlastic,false,CFrame.Angles(0,0,math.pi/2))
   tire.Shape=Enum.PartType.Cylinder
  end
 end
 for x=-16,16,8 do
  p("FloorExpansionJoint",V(.045,.015,layout.PlotSize-3),x,.52,0,RGB(139,151,151),Enum.Material.Concrete)
 end
 -- Weathered lower repairs and small exposed bolts, kept outside walkways.
 for _,side in ipairs({-1,1}) do
  for z=-32,32,16 do
   p("RustedWallPatch",V(.1,2.4,3.4),side*(half-1),2.4,z,rust,Enum.Material.CorrodedMetal)
   for y=2,3,1 do p("PatchBolt",V(.16,.2,.2),side*(half-1.1),y,z-1.2,cream) end
  end
 end
 return f
end
return Workshop
