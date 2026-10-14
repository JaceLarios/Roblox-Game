--[[
	BoltShelfShop (ModuleScript, StarterPlayerScripts) — Junkyard Fusion

	A shop of things for bolts at a stall in the Race Wars lobby: shelves of
	cards, each with the thing's model turning on a pedestal, a tag in the
	corner, a line about it and its price in bolts. Opens from the stall's
	prompt and closes when you walk away. Buying asks the server over the
	shop's remote, which checks everything again; its answer shows on the
	thing's own button for a moment.

	The Phantom Garage uses it (PhantomShop.client: the Phantom addons), and
	any later stall selling event addons for bolts can too. It was the
	Phantom Garage's own script until a Bolt Shop shared it (2026-10-13,
	taken out the same day: bolts only buy event addons). Same look as the
	mechanic's shop (MechanicAddons.client).

	Shop.Create(config):
	  guiName      the ScreenGui's name
	  title        the panel's heading
	  accent       balance, shelf headings and the pedestals' colour
	  buyColor     the price buttons
	  scrollColor  the scroll bar
	  intro        the line under the heading
	  shelves      { { key, heading, items = { { name, price, tag, tagColor, blurb } } } }
	  columns      cards a row on a big screen (2 on a small one)
	  remote       RemoteEvent: FireServer(name); OnClientEvent(name, result)
	  stall        the stall's Workspace model; its Counter holds `prompt`
	  prompt       the prompt that opens the shop
	  resultText   { [result] = text shown on the button }
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Garage = require(ReplicatedStorage:WaitForChild("GarageTheme"))
local ItemVisuals = require(ReplicatedStorage:WaitForChild("ItemVisuals"))
local ItemNames = require(ReplicatedStorage:WaitForChild("ItemNames"))
local UIStyle = require(ReplicatedStorage:WaitForChild("UIStyle"))

local player = Players.LocalPlayer

local Shop = {}

local function commas(n)
	local s = tostring(math.floor(n))
	local formatted = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (formatted:gsub("^,", ""))
end
function Shop.BoltsText(n)
	return "🔩 " .. commas(n) .. (n == 1 and " bolt" or " bolts")
end
local boltsText = Shop.BoltsText

local function outline(label)
	local stroke = Instance.new("UIStroke")
	stroke.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	stroke.Color = Color3.fromRGB(20, 12, 36)
	stroke.Thickness = 2
	stroke.Parent = label
end

function Shop.Create(config)
	local playerGui = player:WaitForChild("PlayerGui")
	local shopGui = Instance.new("ScreenGui")
	shopGui.Name = config.guiName
	shopGui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	shopGui.ResetOnSpawn = false
	shopGui.DisplayOrder = 30
	shopGui.Enabled = false
	shopGui.Parent = playerGui
	-- Counts as an open menu, so the HUD buttons and phone controls step aside.
	UIStyle.ModalGui(shopGui)

	local panel = Garage.New("Frame", shopGui, config.guiName .. "Panel", {})
	Garage.Shell(panel)
	Garage.Fit(panel)
	local title = Garage.Text(panel, "Title", config.title, UDim2.fromOffset(18, 14), UDim2.new(0.55, 0, 0, 54), 28)
	Garage.Header(title)
	title.TextScaled = true
	local balance = Garage.Text(panel, "Balance", boltsText(0), UDim2.new(0.58, 0, 0, 20), UDim2.new(0.42, -88, 0, 44), 24, config.accent)
	balance.TextXAlignment = Enum.TextXAlignment.Right
	local close = Garage.New("TextButton", panel, "Close", {
		Text = "X", Position = UDim2.new(1, -62, 0, 14), Size = UDim2.fromOffset(46, 46), ZIndex = 10,
	})
	Garage.Button(close, Color3.fromRGB(255, 88, 30))
	close.Activated:Connect(function() shopGui.Enabled = false end)

	local page = Garage.New("ScrollingFrame", panel, "Shelves", {
		BackgroundTransparency = 1, BorderSizePixel = 0, ScrollBarThickness = 7,
		ScrollBarImageColor3 = config.scrollColor or config.accent, AutomaticCanvasSize = Enum.AutomaticSize.Y,
		CanvasSize = UDim2.new(), ZIndex = 2,
	})
	Garage.New("UIListLayout", page, "Layout", { Padding = UDim.new(0, 12), SortOrder = Enum.SortOrder.LayoutOrder })
	Garage.New("UIPadding", page, "Padding", { PaddingTop = UDim.new(0, 4), PaddingLeft = UDim.new(0, 4), PaddingRight = UDim.new(0, 10) })

	local intro = Garage.Text(page, "Intro", config.intro or "", UDim2.new(), UDim2.new(1, -8, 0, 64), 21, Color3.new(1, 1, 1))
	intro.LayoutOrder = 0
	intro.TextXAlignment = Enum.TextXAlignment.Left
	outline(intro)

	-- A turntable view of the thing's model, on a pedestal.
	local spinning = {}
	local function modelView(card, name)
		local view = Garage.New("ViewportFrame", card, "Model", {
			BackgroundTransparency = 1, Position = UDim2.fromOffset(8, 8), Size = UDim2.new(1, -16, 0, 150),
			Ambient = Color3.fromRGB(205, 205, 215), LightColor = Color3.new(1, 1, 1),
			LightDirection = Vector3.new(-1, -1, -1), ZIndex = 3,
		})
		local model, size = ItemVisuals.CloneForViewport(name)
		if not model then return end
		local world = Instance.new("WorldModel")
		world.Parent = view
		model.Parent = world
		Garage.Podium(model, config.accent)
		local camera = Instance.new("Camera")
		camera.FieldOfView = 35
		camera.Parent = view
		view.CurrentCamera = camera
		local reach = math.max(size.X, size.Y, size.Z) * 1.78 + 0.2
		camera.CFrame = CFrame.lookAt(Vector3.new(0.6, 0.45, 0.9) * reach, Vector3.zero)
		table.insert(spinning, { model = model, base = model:GetPivot() })
	end

	local cards = {}
	local grids = {}
	local order = 0
	for shelfIndex, shelf in ipairs(config.shelves) do
		local heading = Garage.Text(page, shelf.key .. "Heading", shelf.heading, UDim2.new(), UDim2.new(1, -8, 0, 36), 24, shelf.color or config.accent)
		heading.LayoutOrder = shelfIndex * 2 - 1
		heading.TextXAlignment = Enum.TextXAlignment.Left
		outline(heading)
		local gridFrame = Garage.New("Frame", page, shelf.key .. "Shelf", {
			BackgroundTransparency = 1, LayoutOrder = shelfIndex * 2, AutomaticSize = Enum.AutomaticSize.Y,
		})
		local grid = Garage.New("UIGridLayout", gridFrame, "Grid", {
			CellPadding = UDim2.fromOffset(12, 12), SortOrder = Enum.SortOrder.LayoutOrder,
		})
		table.insert(grids, { layout = grid, frame = gridFrame })

		for _, item in ipairs(shelf.items) do
			order += 1
			local card = Garage.New("Frame", gridFrame, item.name, { LayoutOrder = order })
			Garage.Inset(card)
			modelView(card, item.name)

			local name = Garage.Text(card, "Title", ItemNames.Display(item.name),
				UDim2.new(0, 8, 0, 164), UDim2.new(1, -16, 0, 34), 22)
			Garage.Plate(name)
			name.TextScaled = true

			-- The corner tag, over the model.
			if item.tag then
				local tag = Garage.Text(card, "Tag", item.tag, UDim2.new(0, 10, 0, 8), UDim2.new(1, -20, 0, 26), 20, item.tagColor or config.accent)
				tag.TextXAlignment = Enum.TextXAlignment.Right
				tag.ZIndex = 6
				outline(tag)
			end

			local blurb = Garage.Text(card, "Blurb", item.blurb or "",
				UDim2.new(0, 8, 0, 202), UDim2.new(1, -16, 0, 44), 17, Color3.new(1, 1, 1))
			blurb.TextWrapped = true
			outline(blurb)

			local buy = Garage.New("TextButton", card, "Purchase", {
				Text = boltsText(item.price), TextSize = 24, Font = Enum.Font.FredokaOne,
				Position = UDim2.new(0, 9, 1, -56), Size = UDim2.new(1, -18, 0, 46), ZIndex = 5,
			})
			Garage.Button(buy, config.buyColor)
			local function purchase()
				if buy.Active and shopGui.Enabled then
					config.remote:FireServer(item.name)
				end
			end
			buy.Activated:Connect(purchase)
			-- The whole card buys, not just its button: people tap the model.
			local cardButton = Garage.New("TextButton", card, "CardButton", {
				Text = "", BackgroundTransparency = 1, Size = UDim2.fromScale(1, 1), ZIndex = 4,
			})
			cardButton.Activated:Connect(purchase)
			cards[item.name] = { price = item.price, button = buy, shown = 0 }
		end
	end

	-- The server's answer, on the thing's own button for a moment (toasts
	-- are drawn under an open shop).
	config.remote.OnClientEvent:Connect(function(itemName, result)
		local card = cards[itemName]
		local text = config.resultText[result]
		if not card or not text then return end
		card.shown += 1
		local shown = card.shown
		card.button.Text = text
		task.delay(1.6, function()
			if card.shown == shown then
				card.button.Text = boltsText(card.price)
			end
		end)
	end)

	-- Greys out what you cannot afford yet, and shows how many bolts you
	-- have. The server checks again on every purchase.
	local function refresh()
		local stats = player:FindFirstChild("leaderstats")
		local bolts = stats and stats:FindFirstChild("Bolts")
		local have = bolts and bolts.Value or 0
		balance.Text = boltsText(have)
		for _, card in pairs(cards) do
			card.button.Active = have >= card.price
			card.button.AutoButtonColor = card.button.Active
		end
	end
	task.spawn(function()
		local bolts = player:WaitForChild("leaderstats"):WaitForChild("Bolts", 30)
		if not bolts then return end
		bolts.Changed:Connect(refresh)
		refresh()
	end)

	local function layout()
		page.Position = UDim2.fromOffset(19, 84)
		page.Size = UDim2.new(1, -38, 1, -103)
		local cols = panel:GetAttribute("Compact") and 2 or (config.columns or 5)
		for _, grid in ipairs(grids) do
			grid.layout.CellSize = UDim2.new(1 / cols, -12, 0, 310)
			grid.frame.Size = UDim2.new(1, -4, 0, 0)
		end
	end
	panel:GetAttributeChangedSignal("Compact"):Connect(layout)
	layout()

	-- Opens from the stall's prompt; closes when you walk away from it.
	local counter
	task.spawn(function()
		local stall = workspace:WaitForChild(config.stall, 120)
		counter = stall and stall:WaitForChild("Counter", 30)
		local prompt = counter and counter:WaitForChild(config.prompt, 30)
		if prompt then
			prompt.Triggered:Connect(function()
				refresh()
				shopGui.Enabled = true
			end)
		end
	end)

	RunService.Heartbeat:Connect(function()
		if not shopGui.Enabled then return end
		local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart")
		if not root or not counter or not counter.Parent or (root.Position - counter.Position).Magnitude > 18 then
			shopGui.Enabled = false
			return
		end
		local angle = os.clock() * 0.6
		for _, s in ipairs(spinning) do
			s.model:PivotTo(CFrame.Angles(0, angle, 0) * s.base)
		end
	end)

	return shopGui
end

return Shop
