--[[
	LegendaryTimer (LocalScript, StarterPlayerScripts) — Junkyard Fusion

	Runs the countdown on the timer in every base (the "LegendaryTimer"
	billboards PlotManager puts over each Lock Base button) to the next
	secret Legendary on the conveyor: workspace's LegendaryDropAt, which
	ScrapSpawner keeps, every 20 minutes. For a little while after one
	drops (LegendaryDroppedAt) it says so instead.
--]]

local CollectionService = game:GetService("CollectionService")

local TAG = "LegendaryTimer"
local SAY_DROPPED_FOR = 15

local function text()
	local now = workspace:GetServerTimeNow()
	local droppedAt = workspace:GetAttribute("LegendaryDroppedAt")
	if droppedAt and now - droppedAt < SAY_DROPPED_FOR then
		return "SECRET LEGENDARY\nON THE CONVEYOR!"
	end
	local dropAt = workspace:GetAttribute("LegendaryDropAt")
	if not dropAt then
		return "SECRET LEGENDARY"
	end
	local left = math.max(0, math.ceil(dropAt - now))
	return string.format("SECRET LEGENDARY\n%d:%02d", left // 60, left % 60)
end

while true do
	local shown = text()
	-- Only the bases streamed in to this player have a billboard here.
	for _, gui in ipairs(CollectionService:GetTagged(TAG)) do
		local label = gui:FindFirstChildOfClass("TextLabel")
		if label and label.Text ~= shown then
			label.Text = shown
		end
	end
	task.wait(0.25)
end
