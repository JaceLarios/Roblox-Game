-- Run in the Studio command bar to recover the 38 installed Junkyard models.
-- This is an EDIT-TIME recovery utility, not a runtime gameplay script.
-- Existing templates are backed up; world/island scripts are not touched.
local entries = game:GetService("HttpService"):JSONDecode([==[[{"name":"Rusted Sedan","assetId":"100600116921933","size":[2.9789962768554688,2.0747878551483154,4.269338607788086]},{"name":"Dirt Bike","assetId":"134564730883544","size":[1.6389567852020264,2.4625449180603027,3.8890252113342285]},{"name":"Golf Cart","assetId":"111364246323001","size":[3.109337091445923,4.964999198913574,5.093301773071289]},{"name":"Muscle Car","assetId":"82741408536940","size":[2.1630492210388184,1.44154953956604,4.5]},{"name":"Cop Cruiser","assetId":"111153973131351","size":[2.552804708480835,2.15450382232666,5.191882610321045]},{"name":"Box Truck","assetId":"129727140211602","size":[4.02410364151001,4.8967108726501465,6.450238227844238]},{"name":"Monster Truck","assetId":"91888969164832","size":[2.2091407775878906,2.309786558151245,3.8872032165527344]},{"name":"Jet Engine","assetId":"109709206471203","size":[3.298999309539795,2.5270721912384033,4.534169673919678]},{"name":"Lifted Cart","assetId":"122616695962225","size":[4.044156551361084,5.759180545806885,5.403830528259277]},{"name":"Highway Overlord","assetId":"75396314044912","size":[3.7804343700408936,4.344156265258789,6.291418075561523]},{"name":"Redline Reaper","assetId":"72230500661276","size":[3.015213966369629,2.065328598022461,4.356049537658691]},{"name":"Trail Blazer","assetId":"71565635507233","size":[3.6160073280334473,3.075030565261841,5.299999713897705]},{"name":"THE LAWNLORD","assetId":"105916772774718","size":[4.249810695648193,5.915003299713135,7]},{"name":"Chrome Sentinel","assetId":"131197731281846","size":[4.014759063720703,2.463994264602661,6]},{"name":"Sonic Scrapheap","assetId":"116025182117974","size":[5.844078540802002,2.896815776824951,7]},{"name":"Yard Destroyer","assetId":"83739390750561","size":[4.056917190551758,4.593681335449219,7]},{"name":"Undercover Muscle","assetId":"111514857715254","size":[2.6099045276641846,1.8664789199829102,5.299999713897705]},{"name":"Street Menace","assetId":"86361118230595","size":[3.977038860321045,3.682744026184082,6.929446220397949]},{"name":"Boosted Beater","assetId":"112469212446292","size":[3.502501964569092,3.5690512657165527,5.4967427253723145]},{"name":"Pursuit Bike","assetId":"81946492152572","size":[1.4727427959442139,2.3707194328308105,3.799999952316284]},{"name":"Scrapyard God","assetId":"84518828585379","size":[4.33057975769043,5.082792282104492,7]},{"name":"Cartpocalypse","assetId":"90690656973352","size":[3.569877862930298,5.3651838302612305,6]},{"name":"Turbo Interceptor","assetId":"93738068315959","size":[3.539520502090454,2.7618165016174316,6]},{"name":"Fairway Fighter","assetId":"140468092115141","size":[3.1963133811950684,2.268697500228882,5.0482497215271]},{"name":"Jet Hauler","assetId":"138816889177055","size":[2.533139228820801,2.4519643783569336,4.021328926086426]},{"name":"Suburban Assault","assetId":"109950315222722","size":[4.566988945007324,6.1401238441467285,7]},{"name":"Hauler Hemi","assetId":"134672412502255","size":[3.418617010116577,3.6736831665039062,5.299999713897705]},{"name":"Scrap Hybrid","assetId":"102014531607768","size":[2.957141399383545,2.903045415878296,3.799999952316284]},{"name":"Junk Mashup","assetId":"109340220116583","size":[2.7834317684173584,3.7029542922973633,4.5]},{"name":"Bent Fusion","assetId":"140019085121720","size":[2.491896867752075,2.302079677581787,4.007541179656982]},{"name":"Rusty Splice","assetId":"82707393943210","size":[2.333646297454834,2.389521598815918,3.799999952316284]},{"name":"Twisted Wreck","assetId":"125266148217308","size":[3.698194980621338,3.251418352127075,5.5]},{"name":"Chaos Hybrid","assetId":"70381121942511","size":[3.148472547531128,4.471209526062012,5.464056968688965]},{"name":"Scrap Titan","assetId":"98430504072993","size":[2.4582059383392334,3.0940752029418945,3.799999952316284]},{"name":"Junkyard Brute","assetId":"80191180887797","size":[2.888587236404419,3.3397305011749268,5.02750301361084]},{"name":"Mangled Overlord","assetId":"94187696133936","size":[2.2256507873535156,2.573094606399536,3.84964656829834]},{"name":"Junkyard Behemoth","assetId":"123239323654265","size":[3.089564085006714,3.807343006134033,4.901902198791504]},{"name":"Wreck Kraken","assetId":"77625656394861","size":[5.5,5.1239824295043945,3.3169901371002197]}]]==])
assert(not game:GetService("RunService"):IsRunning(), "Stop Play before restoring templates")
local templates = game.ReplicatedStorage:WaitForChild("ItemModels")
local backup = Instance.new("Folder")
backup.Name = "ItemModelsBackup_" .. os.time()
backup.Parent = game.ServerStorage
for _, entry in ipairs(entries) do
	local imported = game:GetObjects("rbxassetid://" .. entry.assetId)[1]
	assert(imported, "Asset did not load: " .. entry.name)
	local meshes = {}
	if imported:IsA("MeshPart") then table.insert(meshes, imported) end
	for _, child in ipairs(imported:GetDescendants()) do
		if child:IsA("BasePart") then
			assert(child:IsA("MeshPart"), "Unexpected primitive in asset")
			table.insert(meshes, child)
		end
	end
	assert(#meshes == 1, "Expected exactly one mesh: " .. entry.name)
	local mesh = meshes[1]:Clone()
	mesh.Name = entry.name
	mesh.Size = Vector3.new(unpack(entry.size))
	mesh.CFrame = CFrame.new()
	mesh.Anchored = true
	mesh.CanCollide = false
	local old = templates:FindFirstChild(entry.name)
	if old then
		mesh.CanCollide = old.CanCollide
		mesh.CanTouch = old.CanTouch
		mesh.CanQuery = old.CanQuery
		mesh.CollisionGroup = old.CollisionGroup
		for key, value in old:GetAttributes() do mesh:SetAttribute(key, value) end
	end
	mesh:SetAttribute("CodexModelRevision", "Junkyard_20260914")
	if old then old.Parent = backup end
	mesh.Parent = templates
	imported:Destroy()
end
print("Restored " .. #entries .. " item models; backup: " .. backup:GetFullName())
