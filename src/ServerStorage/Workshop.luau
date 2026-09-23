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
local function text(f,cf,size,title,bg,fg)
 local p=part(f,"WallArtwork",size,cf,bg)
 local g=Instance.new("SurfaceGui",p) g.Face=Enum.NormalId.Front g.PixelsPerStud=32 g.SizingMode=Enum.SurfaceGuiSizingMode.PixelsPerStud g.LightInfluence=.2
 local t=Instance.new("TextLabel",g) t.Size=UDim2.fromScale(.92,.86) t.Position=UDim2.fromScale(.04,.07) t.BackgroundTransparency=1
 t.Text=title t.TextColor3=fg or cream t.TextScaled=true t.Font=Enum.Font.FredokaOne
 return p,g
end
local function art(f,cf,title,col)
 local _,g=text(f,cf,V(20,11,.15),"",dark)
 local head=Instance.new("TextLabel",g) head.BackgroundTransparency=1 head.Position=UDim2.fromScale(.05,.04) head.Size=UDim2.fromScale(.9,.2)
 head.Text=title head.Font=Enum.Font.FredokaOne head.TextScaled=true head.TextColor3=col
 local function box(x,y,w,h,color,round)
  local b=Instance.new("Frame",g) b.Position=UDim2.fromScale(x,y) b.Size=UDim2.fromScale(w,h) b.BackgroundColor3=color b.BorderSizePixel=0
  if round then local c=Instance.new("UICorner",b) c.CornerRadius=UDim.new(1,0) end
  return b
 end
 -- Original workshop blueprint: side-profile hot rod, wheels, engine and dimension lines.
 box(.18,.47,.64,.20,col,true) box(.36,.32,.30,.19,col,true)
 box(.40,.35,.20,.12,dark) box(.19,.65,.16,.25,cream,true) box(.66,.65,.16,.25,cream,true)
 box(.225,.70,.09,.15,steel,true) box(.695,.70,.09,.15,steel,true)
 box(.22,.40,.11,.07,amber) box(.25,.35,.025,.06,cream)
 box(.1,.94,.8,.007,cream) box(.1,.87,.004,.10,cream) box(.9,.87,.004,.10,cream)
 for x=.1,.9,.1 do box(x,.29,.002,.02,steel) end
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
 p("BackWall",V(layout.PlotSize,height,1.2),0,height/2+.5,half,color,Enum.Material.Concrete,true)
 for _,side in ipairs({-1,1}) do
  local x=side*half
  p("WorkshopSideWall",V(1.2,height,layout.PlotSize),x,height/2+.5,0,color,Enum.Material.Concrete,true)
  p("InteriorWainscot",V(.16,8,layout.PlotSize-2),x-side*.7,4.5,0,steel,Enum.Material.DiamondPlate)
  p("InteriorCreamWall",V(.12,24,layout.PlotSize-2),x-side*.72,21,0,cream,Enum.Material.Plaster)
  for z=-36,36,12 do
   p("StructuralColumn",V(1.4,height,1.4),x-side*1.4,height/2+.5,z,dark)
   p("ColumnFoot",V(2,3,2),x-side*1.4,2,z,amber,Enum.Material.DiamondPlate)
   p("ExteriorSidingRib",V(.22,height,.32),x+side*.72,height/2+.5,z,color:Lerp(cream,.25))
  end
  -- Four display bays per side; no clutter in the center aisle.
  for row=0,3 do
   local z=-24+row*16 local slot=(side==-1 and 1 or 5)+row
   p("PadBayTrim",V(13,.10,13),side*28,.57,z,amber,Enum.Material.DiamondPlate)
   p("PadBayInset",V(12,.12,12),side*28,.62,z,steel,Enum.Material.Concrete)
   for _,dx in ipairs({-6,6}) do p("BayGuide",V(.18,.05,12),side*28+dx,.72,z,cream) end
   text(f,frame*CF(side*28,.76,z+5.3)*CFrame.Angles(math.pi/2,0,0),V(5,1.7,.05),"PAD "..slot,dark,amber)
  end
  local rotate=CFrame.Angles(0,side==1 and math.pi/2 or -math.pi/2,0)
  art(f,frame*CF(side*(half-2.3),14,-16)*rotate,side==-1 and "SALVAGE / REBUILD" or "BUILT FROM SCRAP",color:Lerp(amber,.45))
  text(f,frame*CF(side*(half-2.3),14,16)*rotate,V(20,10,.18),
   side==-1 and "GOOD PARTS\nGREAT BUILDS\nREPAIR / REUSE" or "WORKSHOP RULES\nFIND • FUSE • EARN\nMAKE SOMETHING GREAT",color,cream)
  -- Upper clerestory glazing leaves a full future upper-floor volume.
  for z=-24,24,24 do
   p("WindowFrame",V(.20,6.5,16),x-side*.84,29,z,dark)
   local pane=p("ClerestoryGlass",V(.12,5.7,15),x-side*.98,29,z,RGB(157,220,238),Enum.Material.Glass)
   pane.Transparency=.25
   p("WindowMullion",V(.15,5.9,.25),x-side*1.08,29,z,cream)
  end
 end
 -- One centered entrance only: side piers and overhead lintel fully close the facade.
 local doorHalf=13
 local wing=half-doorHalf
 for _,side in ipairs({-1,1}) do
  p("FrontWall",V(wing,height,1.2),side*(doorHalf+wing/2),height/2+.5,-half,color,Enum.Material.Concrete,true)
  for x=doorHalf+2,half-2,5 do p("FacadeRib",V(.25,height-1,.22),side*x,height/2+.5,-half-.72,color:Lerp(cream,.2)) end
  p("DoorJamb",V(1.2,21,2),side*13.6,11,-half,dark,Enum.Material.Metal,true)
  for y=2,8,2 do p("DoorSafetyStripe",V(1.3,.7,2.1),side*13.6,y,-half,amber) end
 end
 p("DoorLintel",V(26,15,1.2),0,29,-half,color,Enum.Material.Concrete,true)
 text(f,frame*CF(0,29,-half-.8),V(49,6,.3),string.format("BAY %02d  •  MECHANIC WORKSHOP",index),dark,cream)
 p("RollerDoorHousing",V(29,2,3),0,23,-half-1,steel)
 for y=22.4,23.6,.4 do p("RollerSlat",V(27,.12,.12),0,y,-half-2.6,cream) end
 -- Front service windows, framed artwork, vents and lit entry fittings.
 for _,side in ipairs({-1,1}) do
  local x=side*29
  p("ServiceWindowFrame",V(17,8,.35),x,16,-half-.85,dark)
  local pane=p("ServiceWindowGlass",V(15.8,6.8,.15),x,16,-half-1.10,RGB(111,191,215),Enum.Material.Glass)
  pane.Transparency=.12
  p("ServiceWindowCrossbar",V(16,.24,.18),x,16,-half-1.25,cream)
  p("ServiceWindowMullion",V(.24,7,.18),x,16,-half-1.25,cream)
  text(f,frame*CF(x,8,-half-1),V(17,4,.2),side==-1 and "REPAIR • REBUILD" or "PARTS • PERFORMANCE",dark,amber)
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
 p("ServiceBench",V(36,1,5),0,4,half-4,steel,Enum.Material.DiamondPlate,true)
 for _,x in ipairs({-13,13}) do
  p("ToolChest",V(9,3.2,4),x,2,half-4,color,Enum.Material.Metal,true)
  for y=1,3,1 do
   p("Drawer",V(8,.7,.15),x,y,half-6.1,dark)
   p("DrawerPull",V(4,.14,.24),x,y,half-6.3,cream)
  end
 end
 p("Pegboard",V(34,8,.25),0,10,half-.9,steel,Enum.Material.DiamondPlate)
 for x=-15,15,3 do
  p("HangingTool",V(.25,3,.2),x,10,half-1.2,cream)
  p("SpannerHead",V(1,.6,.25),x,11.7,half-1.2,amber)
 end
 text(f,frame*CF(0,21,half-1),V(34,7,.2),"SALVAGE WORKS\nOLD PARTS. NEW LEGENDS.",dark,amber)
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
