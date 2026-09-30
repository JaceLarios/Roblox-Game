--[[
	SocialConfig (ModuleScript, ReplicatedStorage) — Junkyard Fusion

	The friend and group bonuses on pad income (PlotManager).

	Friends: +FRIEND_BONUS for every Roblox friend in the same server, up
	to MAX_FRIENDS of them. Group: +GROUP_BONUS for anyone in the game's
	Roblox group. Put the group's id in GROUP_ID (from its page on
	roblox.com: roblox.com/communities/<id>/...); 0 means no group bonus.
--]]

return table.freeze({
	FRIEND_BONUS = 0.10,
	MAX_FRIENDS = 5,
	GROUP_ID = 0,
	GROUP_BONUS = 0.10,
})
