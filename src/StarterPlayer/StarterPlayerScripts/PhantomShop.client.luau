--[[
	PhantomShop (LocalScript, StarterPlayerScripts) — Junkyard Fusion

	The Phantom Garage's shop (the stall in the Race Wars lobby, built by
	ServerStorage.PhantomGarage): the fifteen Phantom addons on three
	shelves, Wisp, Wraith and Reaper, each with its model turning on a
	pedestal, what it multiplies earnings by, a line about it and its price
	in bolts. Opens from the stall's "Phantom Shop" prompt and closes when
	you walk away. Buying asks PlotManager's BuyPhantom, which checks
	everything again.

	The shop itself is BoltShelfShop (shared with the Bolt Shop since
	2026-10-13); this is what is on its shelves. Until an addon has its own
	model it shows the one it borrows, drawn ghostly (ItemVisuals.Ghostly).
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FusionRecipes = require(ReplicatedStorage:WaitForChild("FusionRecipes"))
local EventAddons = require(ReplicatedStorage:WaitForChild("EventAddons"))
local BoltShelfShop = require(script.Parent:WaitForChild("BoltShelfShop"))

local MINT = Color3.fromRGB(150, 255, 210)
local VIOLET = Color3.fromRGB(58, 34, 96)
local BUY = Color3.fromRGB(122, 64, 214)

-- One line about each, from the concept sheet.
local BLURBS = {
	["Will-o'-Wisp Lanterns"] = "Iron lanterns with green spirit flames",
	["Phantom Exhaust"] = "Bone pipes that puff skull smoke rings",
	["Crystal Ball Ornament"] = "A ghost spins inside a crystal ball",
	["Graveyard Grille"] = "A cemetery gate grille and a tombstone bumper",
	["Ecto Tank"] = "A glass tank of bubbling green goo",
	["Banshee Horn"] = "A horn whose bell is a wailing spirit",
	["Poltergeist Spoiler"] = "A wing that floats and rattles on its own",
	["Coffin Carrier"] = "A coffin on the roof, lid knocking",
	["Witch's Cauldron"] = "A cauldron of purple brew for an engine",
	["Specter Sails"] = "A torn ghost-ship sail on a mast",
	["Wraith Wheels"] = "Wheels of blue ghost fire",
	["Soul Turbo"] = "A turbo that sucks in tiny ghosts",
	["Hearse Canopy"] = "A funeral-coach roof with lace curtains",
	["Reaper Scythes"] = "Scythe blades on the wheels, chariot style",
	["Ghost Chauffeur"] = "A see-through butler ghost drives for you",
}
local SHELVES = {
	{ key = "wisp", name = "WISP", line = "Small haunted parts" },
	{ key = "wraith", name = "WRAITH", line = "Bigger pieces that change the car's shape" },
	{ key = "reaper", name = "REAPER", line = "The showpieces" },
}

local shelves = {}
for _, shelf in ipairs(SHELVES) do
	-- The shelf's earnings range (each Phantom's `earn`, see EventAddons).
	local low, high = math.huge, 0
	local items = {}
	for _, addon in ipairs(FusionRecipes.PhantomAddons) do
		if addon.group == shelf.key then
			low, high = math.min(low, addon.earn), math.max(high, addon.earn)
			table.insert(items, {
				name = addon.name,
				price = addon.bolts,
				-- What it multiplies a car's earnings by, over the model.
				tag = string.format("x%s earnings", tostring(EventAddons.AddonMultiplier(addon.name))),
				blurb = BLURBS[addon.name] or "",
			})
		end
	end
	table.insert(shelves, {
		key = shelf.key,
		heading = string.format("%s  ·  %s  ·  x%s to x%s earnings", shelf.name, shelf.line, tostring(low), tostring(high)),
		items = items,
	})
end

BoltShelfShop.Create({
	guiName = "PhantomShop",
	title = "PHANTOM GARAGE",
	accent = MINT,
	buyColor = BUY,
	scrollColor = VIOLET,
	intro = "Win bolts in Race Wars and trade them here for ghost addons. Put one on any car or build at your Fusion Pad: it turns into a ghost for good and earns more. One phantom per car.",
	shelves = shelves,
	columns = 5,
	remote = ReplicatedStorage:WaitForChild("BuyPhantom"),
	stall = "PhantomGarage",
	prompt = "OpenPhantomShop",
	resultText = {
		bought = "Added to Inventory!",
		away = "Stand at the counter",
		full = "Inventory Full",
		bolts = "Need More Bolts",
	},
})
