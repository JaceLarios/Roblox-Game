-- Isolated credits UI; does not change vehicle availability or gameplay.
local starterGui = game:GetService("StarterGui")
assert(not starterGui:FindFirstChild("VehicleModelCredits"), "Credits UI already exists; inspect before replacing")
local function make(class, parent, props)
 local o=Instance.new(class)
 for k,v in pairs(props) do o[k]=v end
 o.Parent=parent
 return o
end
local gui=make("ScreenGui",starterGui,{Name="VehicleModelCredits",ResetOnSpawn=false,DisplayOrder=85,ZIndexBehavior=Enum.ZIndexBehavior.Sibling})
local function round(o) make("UICorner",o,{CornerRadius=UDim.new(0,12)}) end
local open=make("TextButton",gui,{Name="OpenCredits",AnchorPoint=Vector2.new(1,1),Position=UDim2.new(1,-18,1,-18),Size=UDim2.fromOffset(116,30),Text="Model Credits",TextSize=14,Font=Enum.Font.GothamBold,TextColor3=Color3.new(1,1,1),BackgroundColor3=Color3.fromRGB(12,54,83),BorderSizePixel=0})
round(open)
local panel=make("Frame",gui,{Name="CreditsPanel",Visible=false,AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(.5,.5),Size=UDim2.fromScale(.88,.8),BackgroundColor3=Color3.fromRGB(12,36,55),BorderSizePixel=0})
round(panel)
make("UISizeConstraint",panel,{MaxSize=Vector2.new(800,610)})
make("UIStroke",panel,{Color=Color3.fromRGB(65,206,245),Thickness=2})
make("TextLabel",panel,{Name="Title",Position=UDim2.fromOffset(18,10),Size=UDim2.new(1,-80,0,42),BackgroundTransparency=1,Text="MODEL CREDITS",Font=Enum.Font.GothamBold,TextSize=23,TextColor3=Color3.new(1,1,1),TextXAlignment=Enum.TextXAlignment.Left})
local close=make("TextButton",panel,{Name="Close",Position=UDim2.new(1,-48,0,12),Size=UDim2.fromOffset(34,34),Text="X",TextSize=20,Font=Enum.Font.GothamBold,TextColor3=Color3.new(1,1,1),BackgroundColor3=Color3.fromRGB(206,73,46),BorderSizePixel=0})
round(close)
local scroll=make("ScrollingFrame",panel,{Name="Entries",Position=UDim2.fromOffset(16,62),Size=UDim2.new(1,-32,1,-78),BackgroundTransparency=1,BorderSizePixel=0,CanvasSize=UDim2.new(),AutomaticCanvasSize=Enum.AutomaticSize.Y,ScrollBarThickness=6})
make("UIListLayout",scroll,{Padding=UDim.new(0,16),SortOrder=Enum.SortOrder.LayoutOrder})
local entries={
 {title="Toro SVO / SVO (Aventador SVJ-based)",author="\"Lamborghini Aventador SVJ SDC ( FREE )\" by SDC PERFORMANCE (Sketchfab)",source="https://sketchfab.com/3d-models/lamborghini-aventador-svj-sdc-free-784e4656aca649cca55d6b18740a19b2",license="CC BY 4.0",url="https://creativecommons.org/licenses/by/4.0/",changes="Modified for Junkyard Fusion: bodywork, roof scoop, hood, materials, colors, wheels, decals and branding.",note="Credit identifies the source; it does not imply creator endorsement."},
 -- The source in the user's model list (Google Doc), checked on Sketchfab
 -- 2026-09-30: CC BY 4.0, commercial use allowed.
 {title="Toro (Temerario-based)",author="\"Lamborghini Temerario (2025)\" by Harsh Palan (Sketchfab)",source="https://sketchfab.com/3d-models/lamborghini-temerario-2025-83bcf28aade742a3b726c28812fd9672",license="CC BY 4.0",url="https://creativecommons.org/licenses/by/4.0/",changes="Modified for Junkyard Fusion: lime paint, widebody kit, carbon accents, custom wheels, wing and diffuser; renamed and branding removed.",note="Credit identifies the source; it does not imply creator endorsement."}
}
for i,e in ipairs(entries) do
 local card=make("Frame",scroll,{Name=i==1 and "SVO" or "Toro",LayoutOrder=i,Size=UDim2.new(1,-10,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundColor3=Color3.fromRGB(233,246,253),BorderSizePixel=0})
 round(card)
 make("UIPadding",card,{PaddingTop=UDim.new(0,14),PaddingBottom=UDim.new(0,14),PaddingLeft=UDim.new(0,14),PaddingRight=UDim.new(0,14)})
 make("UIListLayout",card,{Padding=UDim.new(0,9),SortOrder=Enum.SortOrder.LayoutOrder})
 local rows={e.title,"Original model: "..e.author,"Source: "..e.source,"License: "..e.license.."\n"..e.url,e.changes,e.note}
 for j,t in ipairs(rows) do
  make("TextBox",card,{Name="Line"..j,LayoutOrder=j,Size=UDim2.new(1,0,0,0),AutomaticSize=Enum.AutomaticSize.Y,BackgroundTransparency=1,Text=t,TextEditable=false,ClearTextOnFocus=false,MultiLine=true,TextWrapped=true,TextSize=j==1 and 19 or 14,Font=j==1 and Enum.Font.GothamBold or Enum.Font.Gotham,TextColor3=Color3.fromRGB(15,36,56),TextXAlignment=Enum.TextXAlignment.Left,TextYAlignment=Enum.TextYAlignment.Top})
 end
end
local controller=make("LocalScript",gui,{Name="CreditsController"})
controller.Source=[[
local gui=script.Parent
local panel=gui:WaitForChild("CreditsPanel")
gui:WaitForChild("OpenCredits").Activated:Connect(function()
 panel.Visible=not panel.Visible
end)
panel:WaitForChild("Close").Activated:Connect(function()
 panel.Visible=false
end)
]]
return {created=gui:GetFullName(),entries=#entries,gameplayChanged=false}

