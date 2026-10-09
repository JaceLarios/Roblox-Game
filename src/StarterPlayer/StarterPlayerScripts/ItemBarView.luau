--[[
	ItemBarView (ModuleScript, StarterPlayerScripts) — Junkyard Fusion

	How the item bar looks (ItemBar.client is when and what): the hotbar at
	the bottom of the screen that replaced Roblox's own (2026-10-09, the
	user: real icons in the hotbar). Each slot shows its item as a small 3D
	model (ItemVisuals.CloneForViewport: a ghost car drawn ghostly with its
	Phantom, a mutation in its colour), framed in its rarity colour, with
	its number key. The Bat and the Speed Coil show their own icons. The
	equipped slot is lit, and the name of the item held (or hovered) sits
	above the bar. More items than fit turn into pages, with arrows.

	Restyle freely; keep View.Create(gui) returning Render(slots, held,
	page, pages, heldCaption) and the onClick / onPage hooks.
--]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Garage = require(ReplicatedStorage:WaitForChild("GarageTheme"))
local ItemVisuals = require(ReplicatedStorage:WaitForChild("ItemVisuals"))

local View = {}

local INK = Color3.fromRGB(8, 43, 77)
local SLOT_DARK = Color3.fromRGB(22, 30, 50)
local HELD = Color3.fromRGB(255, 214, 80)

local function corner(o, r)
	local c = Instance.new("UICorner") c.CornerRadius = UDim.new(0, r) c.Parent = o
end
local function outline(o, color, thickness)
	local s = Instance.new("UIStroke") s.ApplyStrokeMode = Enum.ApplyStrokeMode.Border
	s.Color = color s.Thickness = thickness s.Parent = o
	return s
end
local function textStroke(label, thickness)
	local s = Instance.new("UIStroke") s.ApplyStrokeMode = Enum.ApplyStrokeMode.Contextual
	s.Color = INK s.Thickness = thickness or 2 s.Parent = label
end

-- An item's model in a slot, turned three-quarters on like the Index.
local function modelView(parent, itemName, tint)
	local view = Instance.new("ViewportFrame")
	view.Name = "Model"
	view.BackgroundTransparency = 1
	view.Size = UDim2.new(1, -6, 1, -6)
	view.Position = UDim2.fromOffset(3, 3)
	view.Ambient = Color3.fromRGB(205, 205, 215)
	view.LightColor = Color3.new(1, 1, 1)
	view.LightDirection = Vector3.new(-1, -1, -1)
	view.ZIndex = 2
	view.Parent = parent
	local model, size = ItemVisuals.CloneForViewport(itemName, tint)
	if not model then return end
	model.Parent = view
	local cam = Instance.new("Camera")
	cam.FieldOfView = 35
	local reach = math.max(size.X, size.Y, size.Z) * 1.55 + .2
	cam.CFrame = CFrame.lookAt(Vector3.new(.6, .42, .85) * reach, Vector3.new(0, -size.Y * .05, 0))
	cam.Parent = view
	view.CurrentCamera = cam
end

function View.Create(gui)
	local api = { onClick = nil, onPage = nil }
	local phone = false

	local holder = Garage.New("Frame", gui, "ItemBar", {
		AnchorPoint = Vector2.new(.5, 1), Position = UDim2.new(.5, 0, 1, -8),
		Size = UDim2.fromOffset(100, 74), BackgroundTransparency = 1,
	})
	local row = Garage.New("Frame", holder, "Slots", {
		AnchorPoint = Vector2.new(.5, 1), Position = UDim2.new(.5, 0, 1, 0),
		Size = UDim2.fromScale(1, 1), BackgroundTransparency = 1,
	})
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.VerticalAlignment = Enum.VerticalAlignment.Bottom
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Padding = UDim.new(0, 6)
	layout.Parent = row

	-- The held (or hovered) item's name, above the bar.
	local caption = Garage.Text(holder, "HeldName", "", UDim2.new(.5, 0, 0, -34), UDim2.fromOffset(320, 28), 22, Color3.new(1, 1, 1))
	caption.AnchorPoint = Vector2.new(.5, 0)
	caption.RichText = true
	caption.TextScaled = true
	textStroke(caption, 2.5)

	local function arrow(name, text, order, delta)
		local b = Garage.New("TextButton", row, name, {
			Text = text, TextSize = 26, Font = Enum.Font.FredokaOne, TextColor3 = Color3.new(1, 1, 1),
			BackgroundColor3 = SLOT_DARK, BackgroundTransparency = .15, AutoButtonColor = true,
			Size = UDim2.fromOffset(30, 66), LayoutOrder = order, Visible = false,
		})
		corner(b, 10) outline(b, Color3.fromRGB(130, 244, 255), 2) textStroke(b)
		b.Activated:Connect(function() if api.onPage then api.onPage(delta) end end)
		return b
	end
	local back = arrow("PagePrev", "<", -1, -1)
	local nextPage = arrow("PageNext", ">", 1000, 1)
	local pageLabel = Garage.Text(holder, "Page", "", UDim2.new(1, 0, 0, -20), UDim2.fromOffset(60, 18), 15, Color3.new(1, 1, 1))
	pageLabel.AnchorPoint = Vector2.new(1, 0)
	textStroke(pageLabel, 1.5)

	local frames = {} -- [tool] = { frame, stroke, itemName, tint }
	local slotSize = 66
	local heldName, hoverName = "", nil
	local function showCaption() caption.Text = hoverName or heldName end

	local function makeSlot(slot)
		local frame = Garage.New("TextButton", row, "Slot", {
			Text = "", AutoButtonColor = false, BackgroundColor3 = SLOT_DARK, BackgroundTransparency = .2,
			Size = UDim2.fromOffset(slotSize, slotSize),
		})
		corner(frame, 12)
		local stroke = outline(frame, slot.color, 2.5)
		if slot.itemName then
			modelView(frame, slot.itemName, slot.tint)
		elseif slot.art then
			Garage.Art(frame, slot.art, UDim2.fromScale(.12, .1), UDim2.fromScale(.76, .76)).ZIndex = 2
		else
			local t = Garage.Text(frame, "Name", slot.name, UDim2.fromOffset(4, 4), UDim2.new(1, -8, 1, -8), 14, Color3.new(1, 1, 1))
			t.TextScaled = true textStroke(t, 1.5)
		end
		local key = Garage.Text(frame, "Key", "", UDim2.fromOffset(5, 2), UDim2.fromOffset(20, 18), 15, Color3.new(1, 1, 1))
		key.TextXAlignment = Enum.TextXAlignment.Left key.ZIndex = 5 textStroke(key, 1.5)
		frame.Activated:Connect(function() if api.onClick then api.onClick(slot.tool) end end)
		frame.MouseEnter:Connect(function() hoverName = slot.caption showCaption() end)
		frame.MouseLeave:Connect(function() hoverName = nil showCaption() end)
		return { frame = frame, stroke = stroke, key = key, itemName = slot.itemName, tint = slot.tint, color = slot.color }
	end

	-- slots: this page's { tool, itemName (nil for the Bat, the coil), art,
	-- name, caption (rich text), color, tint, key }; held: the equipped tool,
	-- heldCaption its name (rich text), whichever page it is on.
	function api.Render(slots, held, page, pages, heldCaption)
		phone = Garage.IsPhone(gui.AbsoluteSize)
		slotSize = phone and 52 or 66
		local keep = {}
		for order, slot in slots do
			local entry = frames[slot.tool]
			-- Rebuilt when the item changed (fused, ghosted, re-tinted).
			if entry and (entry.itemName ~= slot.itemName or entry.tint ~= slot.tint) then
				entry.frame:Destroy() entry = nil
			end
			entry = entry or makeSlot(slot)
			frames[slot.tool] = entry
			keep[slot.tool] = true
			entry.frame.LayoutOrder = order
			entry.frame.Size = UDim2.fromOffset(slotSize, slotSize)
			entry.key.Text = slot.key or ""
			local isHeld = slot.tool == held
			entry.stroke.Color = isHeld and HELD or slot.color
			entry.stroke.Thickness = isHeld and 4 or 2.5
			entry.frame.BackgroundTransparency = isHeld and 0 or .2
		end
		for tool, entry in frames do
			if not keep[tool] then entry.frame:Destroy() frames[tool] = nil end
		end
		local count = #slots + (pages > 1 and 2 or 0)
		holder.Size = UDim2.fromOffset(count * (slotSize + 6) + (pages > 1 and -2 * (slotSize - 30) or 0), slotSize + 8)
		back.Visible, nextPage.Visible = pages > 1, pages > 1
		back.Size, nextPage.Size = UDim2.fromOffset(30, slotSize), UDim2.fromOffset(30, slotSize)
		pageLabel.Text = pages > 1 and string.format("%d/%d", page, pages) or ""
		heldName = heldCaption or ""
		showCaption()
	end

	return api
end

return View
