local ItemNames=require(game:GetService("ReplicatedStorage"):WaitForChild("ItemNames"))
local Garage=require(game:GetService("ReplicatedStorage"):WaitForChild("GarageTheme"))
-- Area-specific fusion presentation. Contract: Play(data) yields until fully
-- hidden, including skip/cleanup. Claude's controller owns the queue and the
-- server owns all fusion outcomes. This module never writes player data.
local Players = game:GetService("Players")
local RS = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local Mutations = require(RS:WaitForChild("Mutations"))
local Models = RS:WaitForChild("ItemModels")
local View = {}
local INK = Color3.fromRGB(28,39,58)
local CREAM = Color3.fromRGB(255,251,234)
local CYAN = Color3.fromRGB(65,225,240)
local GOLD = Color3.fromRGB(255,208,88)
local PINK = Color3.fromRGB(255,123,189)
local THEMES = {
	junkyard = {title="MAGNETIC FUSION",phase="MAGNETIZING",base=Color3.fromRGB(22,62,72),colors={CYAN,GOLD},symbol="✦"},
	brainrot = {title="BRAINROT OVERLOAD",phase="GETTING A LITTLE WEIRD...",base=Color3.fromRGB(117,151,211),colors={CYAN,PINK,GOLD},symbol="★"},
}
local function make(class,parent,name,props)
	local o=Instance.new(class) o.Name=name
	for k,v in pairs(props or {}) do o[k]=v end
	o.Parent=parent return o
end
local function round(o,r) make("UICorner",o,"Corner",{CornerRadius=UDim.new(0,r)}) end
local function label(parent,name,value,pos,size,fontSize)
	local o=make("TextLabel",parent,name,{Text=value,Position=pos,Size=size,BackgroundTransparency=1,
		Font=Enum.Font.FredokaOne,TextColor3=CREAM,TextScaled=true,TextWrapped=true,ZIndex=6})
	make("UITextSizeConstraint",o,"TextLimit",{MinTextSize=10,MaxTextSize=fontSize})
	make("UIStroke",o,"Outline",{Color=INK,Thickness=2,ApplyStrokeMode=Enum.ApplyStrokeMode.Contextual})
	return o
end
local function plain(tag)
	local s=tostring(tag or ""):gsub("<[^>]*>","")
	return (s:gsub("&lt;","<"):gsub("&gt;",">"):gsub("&quot;",'"'):gsub("&apos;","'"):gsub("&amp;","&"))
end
local function item(parent,tag,name)
	local v=make("ViewportFrame",parent,name,{AnchorPoint=Vector2.new(.5,.5),BackgroundTransparency=1,
		Size=UDim2.fromScale(.34,.45),Position=UDim2.fromScale(.5,.46),ZIndex=4,
		Ambient=Color3.fromRGB(210,215,230),LightColor=Color3.new(1,1,1),LightDirection=Vector3.new(-1,-1,-1)})
	local base,mutation=Mutations.Unwrap(plain(tag))
	local template=Models:FindFirstChild(base or "")
	if template then
		local world=make("WorldModel",v,"World")
		local model=make("Model",world,"Item")
		local clone=template:Clone() clone.Parent=model
		for _,p in ipairs(model:GetDescendants()) do
			if p:IsA("BasePart") then p.Anchored=true p.CanCollide=false if mutation then p.Color=Mutations.Color(mutation) end end
		end
		local cf,size=model:GetBoundingBox()
		model:PivotTo(CFrame.new(-cf.Position)*model:GetPivot())
		model:ScaleTo(4.5/math.max(size.X,size.Y,size.Z,.01))
		local cam=make("Camera",v,"Camera",{FieldOfView=35})
		cam.CFrame=CFrame.lookAt(Vector3.new(7,4.5,10),Vector3.zero)
		v.CurrentCamera=cam
		v:SetAttribute("ModelName",base)
		return v,cam
	end
	-- Generic hybrid recipes may have no authored mesh. Keep their exact
	-- result name rather than inventing a replacement collectible model.
	label(v,"MissingModel","★",UDim2.fromScale(.1,.1),UDim2.fromScale(.8,.7),100)
	return v,nil
end
local function run(data,area)
	local theme=THEMES[area]
	local rarity=string.upper(tostring(data.rarityName or "COMMON"))
	local rank=({COMMON=1,UNCOMMON=1,RARE=2,EPIC=3,SECRET=4})[rarity] or 1
	local gather=1.25+(rank-1)*.24
	local revealAt=gather+.38
	local duration=({2.9,4.1,4.9,5.8})[rank]
	local gui=make("ScreenGui",Players.LocalPlayer:WaitForChild("PlayerGui"),"FusionCelebrationGui",{
		ResetOnSpawn=false,IgnoreGuiInset=true,DisplayOrder=100,ZIndexBehavior=Enum.ZIndexBehavior.Sibling})
	gui:SetAttribute("Area",area) gui:SetAttribute("Rarity",rarity) gui:SetAttribute("Duration",duration)
	local sounds,connections={},{}
	local alive,skip=true,false
	local ok,err=xpcall(function()
		local overlay=make("CanvasGroup",gui,"Backdrop",{Size=UDim2.fromScale(1,1),
			BackgroundTransparency=1,BorderSizePixel=0,GroupTransparency=1,Active=true})
		local background=make("Frame",overlay,"Atmosphere",{Size=UDim2.fromScale(1,1),BackgroundColor3=Color3.new(1,1,1),BackgroundTransparency=.06,BorderSizePixel=0,ZIndex=0})
		make("UIGradient",background,"Gradient",{Rotation=75,Color=ColorSequence.new(theme.base,area=="brainrot" and Color3.fromRGB(210,175,229) or Color3.fromRGB(53,114,113))})
		make("ImageLabel",background,"Workshop",{Image=Garage.Background,ImageTransparency=.1,Size=UDim2.fromScale(1,1),ScaleType=Enum.ScaleType.Crop,BackgroundTransparency=1,ZIndex=0})
		local stage=make("Frame",overlay,"Stage",{Size=UDim2.fromScale(.94,.94),Position=UDim2.fromScale(.03,.03),BackgroundTransparency=1,ZIndex=2})
		label(stage,"AreaTitle",theme.title,UDim2.fromScale(.12,.02),UDim2.fromScale(.76,.075),44)
		label(stage,"Announcement",plain(data.headerText or "FUSION COMPLETE"),UDim2.fromScale(.12,.10),UDim2.fromScale(.76,.05),23)
		local phase=label(stage,"Phase",theme.phase,UDim2.fromScale(.13,.70),UDim2.fromScale(.74,.065),44)
		local resultName=label(stage,"ResultName",plain(data.resultTag),UDim2.fromScale(.08,.78),UDim2.fromScale(.84,.075),35)
		local reward=label(stage,"Reward",plain(data.rateLine),UDim2.fromScale(.1,.865),UDim2.fromScale(.8,.045),22)
		local rarityLabel=label(stage,"Rarity",rarity,UDim2.fromScale(.3,.925),UDim2.fromScale(.4,.035),18)
		resultName.Visible=false reward.Visible=false rarityLabel.Visible=false
		local skipButton=make("TextButton",overlay,"Skip",{Text="Skip",Font=Enum.Font.FredokaOne,TextSize=19,
			TextColor3=INK,BackgroundColor3=CREAM,Size=UDim2.fromOffset(88,44),AnchorPoint=Vector2.new(1,1),
			Position=UDim2.new(1,-16,1,-14),ZIndex=12,BorderSizePixel=0})
		round(skipButton,14)
  skipButton.Size=UDim2.fromOffset(210,70) skipButton.TextSize=32
  Garage.Button(skipButton,Color3.fromRGB(255,171,29))
  local banner=stage.AreaTitle
  banner.Position=UDim2.fromScale(.1,.015) banner.Size=UDim2.fromScale(.8,.10)
  banner.TextSize=52 Garage.Header(banner)
  Garage.Plate(stage.Announcement,Color3.fromRGB(133,223,255))
  resultName.Position=UDim2.fromScale(.32,.77) resultName.Size=UDim2.fromScale(.36,.064) Garage.Plate(resultName)
  rarityLabel.Position=UDim2.fromScale(.36,.841) rarityLabel.Size=UDim2.fromScale(.28,.044) rarityLabel.TextSize=26
  Garage.Plate(rarityLabel,Color3.fromRGB(211,98,255))
  reward.Position=UDim2.fromScale(.33,.897) reward.Size=UDim2.fromScale(.34,.053) Garage.Plate(reward)
  local podium=Garage.Pedestal(stage,Color3.fromRGB(46,237,174),UDim2.fromScale(.26,.66),UDim2.fromScale(.48,.15))
  podium.Visible=false

		table.insert(connections,skipButton.Activated:Connect(function() skip=true end))
		local a,acam=item(stage,data.aTag,"IngredientA")
		local b,bcam=item(stage,data.bTag,"IngredientB")
		local result,rcam=item(stage,data.resultTag,"Result") result.Visible=false
		local core=label(stage,"EnergyCore","★",UDim2.fromScale(.4,.32),UDim2.fromScale(.2,.25),140)
		core.TextColor3=GOLD core.Visible=false
		local rings={}
		for r=1,(rank>=3 and 3 or 2) do
			local lines={}
			for j=1,48 do
				local line=make("Frame",stage,"OrbitSegment",{AnchorPoint=Vector2.new(.5,.5),BorderSizePixel=0,
					BackgroundColor3=theme.colors[(r-1)%#theme.colors+1],ZIndex=2})
				round(line,5) lines[j]=line
			end
			rings[r]=lines
		end
		local particles={}
		for i=1,rank>=3 and 24 or 16 do
			local p=label(stage,"Spark"..i,area=="junkyard" and "★" or (i%3==0 and "ϟ" or "★"),UDim2.fromScale(.5,.45),UDim2.fromOffset(25,25),28)
			p.AnchorPoint=Vector2.new(.5,.5) p.ZIndex=3 p.TextColor3=theme.colors[(i-1)%#theme.colors+1]
			particles[i]=p
		end
		if area=="junkyard" then
			for _,x in ipairs({.035,.965}) do
				local magnet=make("Frame",stage,"Magnet",{AnchorPoint=Vector2.new(.5,.5),Position=UDim2.fromScale(x,.45),
					Size=UDim2.fromScale(.07,.18),BackgroundColor3=Color3.fromRGB(236,142,63),BorderSizePixel=0,ZIndex=3})
				round(magnet,18)
				local inset=make("Frame",magnet,"Coil",{Position=UDim2.fromScale(.18,.12),Size=UDim2.fromScale(.64,.76),BackgroundColor3=CYAN,BorderSizePixel=0}) round(inset,14)
			end
		end
		local function sound(id,pitch,volume)
			if not alive then return end
			local s=make("Sound",SoundService,"FusionUI",{SoundId=id,PlaybackSpeed=pitch,Volume=volume})
			table.insert(sounds,s) s:Play()
		end
		local ping="rbxasset://sounds/electronicpingshort.wav"
		local bass="rbxasset://sounds/bass.wav"
		sound(ping,area=="brainrot" and 1.35 or .65,.24)
		local start=os.clock()
		local revealed,beat=false,0
		while alive and gui.Parent do
			local t=os.clock()-start
			if skip or t>=duration then break end
			overlay.GroupTransparency=1-math.clamp(t/.18,0,1)
			local gathering=t<revealAt
			gui:SetAttribute("Phase",gathering and (t<gather and "Gather" or "Fuse") or "Reveal")
			local q=math.clamp(t/gather,0,1)
			local angle=t*(3+q*3)
			local contraction=gathering and 1-.85*q*q or 1
			local size=stage.AbsoluteSize
			for r,lines in ipairs(rings) do
				local rot=(r==1 and -.25 or r==2 and .28 or -.4)+math.sin(t*1.4+r)*.05
				local rx=size.X*.32*contraction
				local ry=size.Y*(.075+r*.018)*contraction
				for j,line in ipairs(lines) do
					local aa=(j-1)/48*math.pi*2+t*.45
					local bb=j/48*math.pi*2+t*.45
					local function point(theta)
						local x,y=math.cos(theta)*rx,math.sin(theta)*ry
						return Vector2.new(size.X*.5+x*math.cos(rot)-y*math.sin(rot),size.Y*.45+x*math.sin(rot)+y*math.cos(rot))
					end
					local p1,p2=point(aa),point(bb) local d=p2-p1
					line.Position=UDim2.fromOffset((p1.X+p2.X)/2,(p1.Y+p2.Y)/2)
					line.Size=UDim2.fromOffset(d.Magnitude+2,math.clamp(size.X/240,2,6))
					line.Rotation=math.deg(math.atan2(d.Y,d.X))
				end
			end
			for i,p in ipairs(particles) do
				local theta=i*2.399+t*(gathering and 1.4 or .18)
				local radius=gathering and .34*contraction or .25+math.min(t-revealAt,.65)*.12
				p.Position=UDim2.fromScale(.5+math.cos(theta)*radius,.45+math.sin(theta)*radius*.67)
				p.Rotation=t*35+i*29 p.Visible=t>.2
			end
			if gathering then
				local radius=.27*(1-q*q)
				local shrink=1-math.clamp((q-.68)/.32,0,1)
				local bounce=area=="brainrot" and math.abs(math.sin(t*8))*.04 or 0
				a.Position=UDim2.fromScale(.5+math.cos(angle)*radius,.45+math.sin(angle)*.06-bounce)
				b.Position=UDim2.fromScale(.5-math.cos(angle)*radius,.45-math.sin(angle)*.06-bounce)
				a.Size=UDim2.fromScale(.34*shrink,.43*shrink) b.Size=a.Size
				core.Visible=q>.7 core.Rotation=t*100
				if t>=gather then phase.Text=area=="junkyard" and "MAGNETIC LOCK!" or "OVERLOAD!" end
				if t>beat+.32 and t<gather then beat=t sound(ping,(area=="brainrot" and 1.1 or .55)+q*.7,.12) end
			else
				local u=t-revealAt
				if not revealed then
					revealed=true podium.Visible=true core.Visible=false result.Visible=true
                    a.Position=UDim2.fromScale(.075,.82) b.Position=UDim2.fromScale(.215,.82)
                    a.Size=UDim2.fromScale(.14,.17) b.Size=a.Size
                    local ingredients=Garage.Text(stage,"Ingredients","FUSION INGREDIENTS",UDim2.fromScale(.015,.69),UDim2.fromScale(.27,.04),22,Color3.new(1,1,1))
                    Garage.Text(stage,"Plus","+",UDim2.fromScale(.12,.78),UDim2.fromScale(.05,.06),38,Color3.new(1,1,1))
                    local al=Garage.Text(stage,"IngredientNameA",ItemNames.Display(plain(data.aTag)),UDim2.fromScale(.005,.915),UDim2.fromScale(.14,.042),17) Garage.Plate(al)
                    local bl=Garage.Text(stage,"IngredientNameB",ItemNames.Display(plain(data.bTag)),UDim2.fromScale(.155,.915),UDim2.fromScale(.14,.042),17) Garage.Plate(bl)
					phase.Text="FUSED!" resultName.Visible=true reward.Visible=true rarityLabel.Visible=true
					skipButton.Text="Continue"
					sound(bass,area=="brainrot" and 1.35 or .8,.4)
					sound(ping,area=="brainrot" and 1.7 or 1.1,.32)
					beat=t
				end
				local pop=math.clamp(u/.32,0,1)
				local pulse=1+math.sin(u*12)*math.exp(-u*5)*.12
				result.Size=UDim2.fromScale(.76*pop*pulse,.60*pop*pulse)
				result.Position=UDim2.fromScale(.5,.43-(area=="brainrot" and math.abs(math.sin(u*5))*math.exp(-u*2)*.04 or 0))
				if rcam then rcam.CFrame=CFrame.lookAt(Vector3.new(math.sin(.6+u*.25)*12,4.5,math.cos(.6+u*.25)*12),Vector3.zero) end
				if rank>=2 and t>beat+.4 and u<1.3 then beat=t sound(ping,1.4+u*.25,.16) end
			end
			RunService.Heartbeat:Wait()
		end
		local fadeStart=os.clock()
		while gui.Parent and os.clock()-fadeStart<.2 do
			overlay.GroupTransparency=math.clamp((os.clock()-fadeStart)/.2,0,1)
			RunService.Heartbeat:Wait()
		end
	end,debug.traceback)
	alive=false
	for _,c in ipairs(connections) do c:Disconnect() end
	for _,s in ipairs(sounds) do s:Destroy() end
	gui:Destroy()
	if not ok then warn("[FusionCelebrationView] "..tostring(err)) end
end
local Variants={
	junkyard=function(data) run(data,"junkyard") end,
	brainrot=function(data) run(data,"brainrot") end,
}
function View.Play(data)
	if type(data)~="table" then return end
	(Variants[data.area] or Variants.junkyard)(data)
end
return View