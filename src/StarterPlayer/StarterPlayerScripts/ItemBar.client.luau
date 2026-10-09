--[[
	ItemBar (LocalScript, StarterPlayerScripts) — Junkyard Fusion

	The hotbar, in place of Roblox's own (2026-10-09, the user: real icons
	in the hotbar). Every item is a Tool in the Backpack (PlotManager's
	"The hotbar"); this shows them as slots with each item's 3D model
	(ItemBarView draws them) and does what Roblox's bar did: a number key or
	a click/tap holds that slot's tool, again puts it away.

	Order: the Bat and the Speed Coil first, then cars best first (worth,
	with mutation and Phantom), then addons best first. More than fit go on
	pages (10 a page, 6 on a phone; the number keys work on the page shown).

	Hidden while carrying loot (CarryHud's CarryHidesHotbar) and while a
	menu is open on a touch screen (UIStyle's MenuOpen), as Roblox's bar was.
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterGui = game:GetService("StarterGui")
local UserInputService = game:GetService("UserInputService")

local FusionRecipes = require(ReplicatedStorage:WaitForChild("FusionRecipes"))
local Mutations = require(ReplicatedStorage:WaitForChild("Mutations"))
local EventAddons = require(ReplicatedStorage:WaitForChild("EventAddons"))
local ItemNames = require(ReplicatedStorage:WaitForChild("ItemNames"))
local ItemRarity = require(ReplicatedStorage:WaitForChild("ItemRarity"))
local Garage = require(ReplicatedStorage:WaitForChild("GarageTheme"))
local View = require(script.Parent:WaitForChild("ItemBarView"))

local player = Players.LocalPlayer

-- Roblox's own bar goes for good (it would show the same tools again).
task.spawn(function()
	for _ = 1, 30 do
		if pcall(StarterGui.SetCoreGuiEnabled, StarterGui, Enum.CoreGuiType.Backpack, false) then return end
		task.wait(1)
	end
end)

local gui = Instance.new("ScreenGui")
gui.Name = "ItemBarUI"
gui.ResetOnSpawn = false
gui.DisplayOrder = 2
gui.Parent = player:WaitForChild("PlayerGui")
local view = View.Create(gui)

-- The Bat and the coil's icons (GarageTheme.Art), and their place first.
local TOOL_ART = { Bat = "bat", ["Speed Coil"] = "coil" }
local TOOL_ORDER = { Bat = 1, ["Speed Coil"] = 2 }
local KEYS = {
	[Enum.KeyCode.One] = 1, [Enum.KeyCode.Two] = 2, [Enum.KeyCode.Three] = 3, [Enum.KeyCode.Four] = 4,
	[Enum.KeyCode.Five] = 5, [Enum.KeyCode.Six] = 6, [Enum.KeyCode.Seven] = 7, [Enum.KeyCode.Eight] = 8,
	[Enum.KeyCode.Nine] = 9, [Enum.KeyCode.Zero] = 10,
}

local page = 1
local shown = {} -- this page's tools, in slot order

local function worth(itemName)
	local base, mutation, event = Mutations.Unwrap(itemName)
	return FusionRecipes.GetValue(base) * Mutations.ValueMultiplier(mutation) * EventAddons.Multiplier(event)
end

local function tools()
	local list = {}
	for _, container in { player:FindFirstChildOfClass("Backpack"), player.Character } do
		if container then
			for _, t in container:GetChildren() do
				if t:IsA("Tool") then table.insert(list, t) end
			end
		end
	end
	table.sort(list, function(a, b)
		local ia, ib = a:GetAttribute("ItemName"), b:GetAttribute("ItemName")
		if not ia or not ib then
			if ia ~= ib then return ib ~= nil end
			return (TOOL_ORDER[a.Name] or 9) < (TOOL_ORDER[b.Name] or 9)
		end
		local addonA, addonB = FusionRecipes.IsAddon((Mutations.Unwrap(ia))), FusionRecipes.IsAddon((Mutations.Unwrap(ib)))
		if addonA ~= addonB then return addonB end
		local wa, wb = worth(ia), worth(ib)
		if wa ~= wb then return wa > wb end
		return ia < ib
	end)
	return list
end

local function caption(itemName, tool)
	if not itemName then return tool.Name end
	local base, mutation = Mutations.Unwrap(itemName)
	if mutation then return Mutations.Tag(itemName, mutation) end
	return ItemRarity.Tag(itemName, FusionRecipes.GetTier(base), FusionRecipes.IsSecretResult(base), FusionRecipes.GetRarity(base))
end

local function render()
	local list = tools()
	local perPage = Garage.IsPhone(gui.AbsoluteSize) and 6 or 10
	local pages = math.max(1, math.ceil(#list / perPage))
	page = math.clamp(page, 1, pages)
	local held = player.Character and player.Character:FindFirstChildOfClass("Tool")
	local slots = {}
	shown = {}
	for i = (page - 1) * perPage + 1, math.min(#list, page * perPage) do
		local tool = list[i]
		local itemName = tool:GetAttribute("ItemName")
		local base, mutation = Mutations.Unwrap(itemName)
		local color = Color3.fromRGB(130, 244, 255)
		if itemName then
			color = Mutations.Color(mutation)
				or ItemRarity.Color(FusionRecipes.GetTier(base), FusionRecipes.IsSecretResult(base), FusionRecipes.GetRarity(base))
		end
		table.insert(shown, tool)
		table.insert(slots, {
			tool = tool, itemName = itemName, art = not itemName and TOOL_ART[tool.Name] or nil,
			name = itemName and ItemNames.Display(itemName) or tool.Name, caption = caption(itemName, tool),
			color = color, tint = Mutations.Color(mutation), key = #shown <= 10 and tostring(#shown % 10) or nil,
		})
	end
	view.Render(slots, held, page, pages, held and caption(held:GetAttribute("ItemName"), held) or "")
end

local function hold(tool)
	local humanoid = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if not (humanoid and tool and tool.Parent) then return end
	if tool.Parent == player.Character then
		humanoid:UnequipTools()
	else
		humanoid:EquipTool(tool)
	end
end

view.onClick = hold
view.onPage = function(delta)
	page += delta
	render()
end

UserInputService.InputBegan:Connect(function(input, processed)
	if processed or UserInputService:GetFocusedTextBox() then return end
	local slot = KEYS[input.KeyCode]
	if slot and shown[slot] and gui.Enabled then hold(shown[slot]) end
end)

-- Shown unless carrying loot or (on a touch screen) a menu is open.
local function visibility()
	gui.Enabled = not player:GetAttribute("CarryHidesHotbar") and not player:GetAttribute("MenuOpen")
end
player:GetAttributeChangedSignal("CarryHidesHotbar"):Connect(visibility)
player:GetAttributeChangedSignal("MenuOpen"):Connect(visibility)
visibility()

-- Redrawn when tools come, go, change hands or change item; batched to one
-- redraw a frame.
local pending = false
local function changed()
	if pending then return end
	pending = true
	task.defer(function() pending = false render() end)
end
local function watch(container)
	if not container then return end
	container.ChildAdded:Connect(changed)
	container.ChildRemoved:Connect(changed)
	changed()
end
player.ChildAdded:Connect(function(child) if child:IsA("Backpack") then watch(child) end end)
watch(player:FindFirstChildOfClass("Backpack"))
player.CharacterAdded:Connect(watch)
watch(player.Character)
gui:GetPropertyChangedSignal("AbsoluteSize"):Connect(changed)
