--[[
	PickupEffects (ModuleScript, ServerStorage) — Junkyard Fusion v1

	One-shot "flies to you and shrinks away" animation for grabbing an
	item off the ground — the Junkyard's scrap grab, Brainrot's and
	Haunted's creature grabs all used to just `itemPart:Destroy()`
	instantly. Same controller/view split every other visual effect this
	project uses (see FusionEffects.luau): the calling script decides
	WHEN an item was picked up and by whom; this module owns 100% of
	what that looks like.

	Deliberately fire-and-forget and NOT part of the actual pickup
	decision — call this AFTER the real game logic (inserting into carry
	slots, etc.) already ran synchronously, so grabbing feels exactly as
	responsive as before; only the item's own destruction is delayed by
	the animation, never the player's turn.
--]]

local TweenService = game:GetService("TweenService")

local ItemVisuals = require(game:GetService("ReplicatedStorage"):WaitForChild("ItemVisuals"))
local PickupEffects = {}

local FLIGHT_TIME = 0.22

-- itemPart: the world Part being picked up (already excluded from being
-- grabbed again by the caller's own state check). targetPosition: where
-- it flies to, almost always the picking-up player's HumanoidRootPart
-- position.
function PickupEffects.Play(itemPart, targetPosition)
	if not itemPart or not itemPart.Parent then return end

	-- The floating name label would otherwise shrink/warp along with the
	-- part at the same rate, which reads as broken rather than a clean
	-- "collected" flourish — just hide it immediately instead.
	for _, child in ipairs(itemPart:GetChildren()) do
		if child:IsA("BillboardGui") then
			child.Enabled = false
		end
	end

	itemPart.CanCollide = false
	itemPart.CanTouch = false
	local prompt = itemPart:FindFirstChildOfClass("ProximityPrompt")
	if prompt then
		prompt.Enabled = false
	end

	local goalCFrame = CFrame.new(targetPosition + Vector3.new(0, 2.2, 0))
	if itemPart:GetAttribute("ItemAssembly") then
		local startCFrame, startSize = itemPart.CFrame, itemPart.Size
		local driver = Instance.new("NumberValue")
		driver.Parent = itemPart
		local connection = driver.Changed:Connect(function(alpha)
			if not itemPart.Parent then return end
			ItemVisuals.Resize(itemPart, startSize * (1 - .85 * alpha))
			itemPart.CFrame = startCFrame:Lerp(goalCFrame, alpha)
			ItemVisuals.SetTransparency(itemPart, alpha)
		end)
		local flight = TweenService:Create(driver, TweenInfo.new(FLIGHT_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {Value = 1})
		flight.Completed:Once(function()
			connection:Disconnect()
			if itemPart.Parent then itemPart:Destroy() end
		end)
		flight:Play()
		return
	end
	local tween = TweenService:Create(itemPart, TweenInfo.new(FLIGHT_TIME, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
		CFrame = goalCFrame,
		Size = itemPart.Size * 0.15,
		Transparency = 1,
	})

	tween.Completed:Connect(function()
		if itemPart.Parent then
			itemPart:Destroy()
		end
	end)
	tween:Play()
end

return PickupEffects
