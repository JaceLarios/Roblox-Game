-- Read-only gameplay-data checks; creates and destroys unparented visual clones only.
local visuals=require(game.ReplicatedStorage.ItemVisuals)
local recipes=require(game.ReplicatedStorage.FusionRecipes)
local roster=game.HttpService:JSONDecode([==[[{"name":"Rusted Sedan","tier":1},{"name":"Dirt Bike","tier":1},{"name":"Golf Cart","tier":1},{"name":"Muscle Car","tier":1},{"name":"Cop Cruiser","tier":1},{"name":"Box Truck","tier":1},{"name":"Monster Truck","tier":1},{"name":"Jet Engine","tier":1},{"name":"Lifted Cart","tier":2},{"name":"Highway Overlord","tier":4},{"name":"Redline Reaper","tier":3},{"name":"Trail Blazer","tier":2},{"name":"THE LAWNLORD","tier":4},{"name":"Chrome Sentinel","tier":3},{"name":"Sonic Scrapheap","tier":4},{"name":"Yard Destroyer","tier":3},{"name":"Undercover Muscle","tier":2},{"name":"Street Menace","tier":3},{"name":"Boosted Beater","tier":2},{"name":"Pursuit Bike","tier":2},{"name":"Scrapyard God","tier":5},{"name":"Cartpocalypse","tier":3},{"name":"Turbo Interceptor","tier":3},{"name":"Fairway Fighter","tier":2},{"name":"Jet Hauler","tier":2},{"name":"Suburban Assault","tier":3},{"name":"Hauler Hemi","tier":2},{"name":"Scrap Hybrid","tier":2},{"name":"Junk Mashup","tier":2},{"name":"Bent Fusion","tier":2},{"name":"Rusty Splice","tier":2},{"name":"Twisted Wreck","tier":3},{"name":"Chaos Hybrid","tier":3},{"name":"Scrap Titan","tier":3},{"name":"Junkyard Brute","tier":3},{"name":"Mangled Overlord","tier":4},{"name":"Junkyard Behemoth","tier":4},{"name":"Wreck Kraken","tier":4}]]==])
local checks=0
local known={}
for _,e in roster do known[e.name]=true end
for _,e in roster do
 local template=game.ReplicatedStorage.ItemModels:FindFirstChild(e.name)
 assert(template and template:IsA("MeshPart"),"Missing single mesh: "..e.name)
 assert(template:GetAttribute("CodexModelRevision")=="Junkyard_20260914","Wrong revision: "..e.name)
 for _,scale in {0.3,0.55,1} do
  local part=visuals.Create(e.name,Vector3.new(12,20,30),scale)
  assert(part:IsA("MeshPart") and part.MeshId==template.MeshId,"Wrong clone: "..e.name)
  assert(math.abs(part.Position.Y-part.Size.Y/2-20)<0.001,"Grounding error: "..e.name)
  assert((part.Size-template.Size*scale*visuals.GLOBAL_SCALE).Magnitude<0.001,"Scale error: "..e.name)
  assert(part.Anchored,"Unanchored: "..e.name)
  part:Destroy()
  checks+=1
 end
end
local combinations=0
for _,a in roster do for _,b in roster do
 local result=recipes.Fuse(a.name,b.name)
 assert(known[result],"Recipe result has no new model: "..tostring(result))
 assert(visuals.HasModel(result),"Missing result: "..result)
 combinations+=1
end end
return game.HttpService:JSONEncode({models=#roster,visualCloneChecks=checks,recipeCombinations=combinations})

