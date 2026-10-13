--[[
	BoltShop (LocalScript, StarterPlayerScripts) — Junkyard Fusion

	The Bolt Shop's shop (the stall in the Race Wars lobby run by the game
	owner's avatar, built by ServerStorage.BoltShop): the fifteen shop
	addons for the bolts won racing (user, 2026-10-13), one shelf a rarity,
	each with its model turning on a pedestal, a line about it and its price
	in bolts (FusionRecipes.AddonBoltPrice). Opens from the stall's "Bolt
	Shop" prompt and closes when you walk away. Buying asks PlotManager's
	BuyBoltAddon, which checks everything again.

	The shop itself is BoltShelfShop, shared with the Phantom Garage.
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FusionRecipes = require(ReplicatedStorage:WaitForChild("FusionRecipes"))
local ItemRarity = require(ReplicatedStorage:WaitForChild("ItemRarity"))
local BoltShelfShop = require(script.Parent:WaitForChild("BoltShelfShop"))

local GREEN = Color3.fromRGB(110, 230, 90)
local RED = Color3.fromRGB(214, 44, 44)
local DARK = Color3.fromRGB(40, 42, 48)

-- One line about each.
local BLURBS = {
	["Nitrous Tank"] = "A bottle of go-fast gas",
	["Straight Pipes"] = "Loud chrome pipes, no muffler",
	["Scrap Turbo"] = "A turbo bolted together from scrap",
	["Inline 4"] = "A tidy four-cylinder engine",
	["Rotary Engine"] = "A spinning engine that loves to rev",
	["Twin Turbo"] = "Two turbos, twice the whoosh",
	["V6 Engine"] = "Six cylinders of muscle",
	["Supercharger"] = "A blower on top that screams",
	["Diesel Stack"] = "Smoke stacks and big torque",
	["V8 Engine"] = "The classic big-block V8",
	["V12 Engine"] = "Twelve cylinders of supercar power",
	["Hover Fans"] = "Fans that lift the car off the road",
	["Jet Engine"] = "A real jet engine on the back",
	["Rocket Booster"] = "Rockets. Hold on tight.",
	["Fusion Core"] = "A glowing core of pure power",
}

-- One shelf a rarity, worst first, as the addons are listed.
local shelves, byRarity = {}, {}
for _, addon in ipairs(FusionRecipes.ShopAddons) do
	local price = FusionRecipes.AddonBoltPrice(addon.name)
	if price then
		local shelf = byRarity[addon.rarity]
		if not shelf then
			shelf = { key = addon.rarity, items = {}, low = math.huge, high = 0, color = ItemRarity.RarityColor(addon.rarity) }
			byRarity[addon.rarity] = shelf
			table.insert(shelves, shelf)
		end
		shelf.low, shelf.high = math.min(shelf.low, price), math.max(shelf.high, price)
		table.insert(shelf.items, {
			name = addon.name,
			price = price,
			tag = ItemRarity.RarityName(addon.rarity),
			tagColor = shelf.color,
			blurb = BLURBS[addon.name] or "",
		})
	end
end
for _, shelf in ipairs(shelves) do
	local name = string.upper(ItemRarity.RarityName(shelf.key) or shelf.key)
	shelf.heading = string.format("%s  ·  %d to %d bolts", name, shelf.low, shelf.high)
end

BoltShelfShop.Create({
	guiName = "BoltShop",
	title = "BOLT SHOP",
	accent = GREEN,
	buyColor = RED,
	scrollColor = DARK,
	intro = "Spend the bolts you win in Race Wars on addons. Put one on a car at your Fusion Pad to fuse a build, just like the ones from your mechanic.",
	shelves = shelves,
	columns = 3,
	remote = ReplicatedStorage:WaitForChild("BuyBoltAddon"),
	stall = "BoltShop",
	prompt = "OpenBoltShop",
	resultText = {
		bought = "Added to your hotbar!",
		away = "Stand at the counter",
		full = "Inventory Full",
		bolts = "Need More Bolts",
	},
})
