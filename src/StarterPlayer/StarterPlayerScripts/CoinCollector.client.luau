--[[
	CoinCollector (LocalScript, StarterPlayerScripts) — Junkyard Fusion

	The number over every base's coin collector (the gold pad at the back of
	each garage, PlotManager's Income.bank), counting up live as the base
	earns: the server sets the pad's Unclaimed, Rate (coins a second) and At
	(server time) every few seconds, and this counts on from them every
	frame, so the number climbs smoothly instead of jumping. "COIN
	COLLECTOR" while there is nothing on it. Finds the pads by their
	"CoinCollector" tag, so pads that stream in later get a label too.
--]]

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")

local GOLD = Color3.fromRGB(255, 205, 50)
local INK = Color3.fromRGB(40, 26, 6)
-- The server updates every 3 seconds; never count further ahead than this
-- past its last update, in case one is late.
local MAX_AHEAD = 3.5

local labels = {} -- [pad] = { amount, hint }

local function commas(n)
	local s = tostring(math.floor(n))
	local formatted = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return (formatted:gsub("^,", ""))
end

local function attach(pad)
	if labels[pad] or not pad:IsA("BasePart") then return end
	local gui = Instance.new("BillboardGui")
	gui.Name = "CollectorLabel"
	gui.Size = UDim2.fromOffset(320, 96)
	gui.StudsOffset = Vector3.new(0, 5, 0)
	gui.AlwaysOnTop = true
	gui.MaxDistance = 60
	gui.Parent = pad
	local amount = Instance.new("TextLabel")
	amount.BackgroundTransparency = 1
	amount.Size = UDim2.new(1, 0, 0.66, 0)
	amount.Font = Enum.Font.LuckiestGuy
	amount.TextScaled = true
	amount.TextColor3 = GOLD
	amount.Parent = gui
	local stroke = Instance.new("UIStroke")
	stroke.Color = INK
	stroke.Thickness = 3
	stroke.Parent = amount
	local hint = Instance.new("TextLabel")
	hint.BackgroundTransparency = 1
	hint.Position = UDim2.fromScale(0, 0.66)
	hint.Size = UDim2.new(1, 0, 0.32, 0)
	hint.Font = Enum.Font.FredokaOne
	hint.TextScaled = true
	hint.TextColor3 = Color3.new(1, 1, 1)
	hint.Text = "STEP HERE TO COLLECT"
	hint.Parent = gui
	local hintStroke = Instance.new("UIStroke")
	hintStroke.Color = INK
	hintStroke.Thickness = 2
	hintStroke.Parent = hint
	labels[pad] = { amount = amount, hint = hint }
	pad.Destroying:Once(function() labels[pad] = nil end)
end

for _, pad in ipairs(CollectionService:GetTagged("CoinCollector")) do attach(pad) end
CollectionService:GetInstanceAddedSignal("CoinCollector"):Connect(attach)
CollectionService:GetInstanceRemovedSignal("CoinCollector"):Connect(function(pad)
	local entry = labels[pad]
	if entry then entry.amount.Parent:Destroy() end
	labels[pad] = nil
end)

RunService.Heartbeat:Connect(function()
	local now = workspace:GetServerTimeNow()
	for pad, entry in pairs(labels) do
		local unclaimed = pad:GetAttribute("Unclaimed") or 0
		local rate = pad:GetAttribute("Rate") or 0
		local at = pad:GetAttribute("At") or now
		local shown = unclaimed + rate * math.clamp(now - at, 0, MAX_AHEAD)
		if shown >= 1 then
			entry.amount.Text = "💰 " .. commas(shown)
			entry.hint.Visible = true
		else
			entry.amount.Text = "COIN COLLECTOR"
			entry.hint.Visible = false
		end
	end
end)
