--[[
	PromoCodes (ModuleScript, ReplicatedStorage) — Junkyard Fusion v1

	Redeemable codes for the Shop UI. Matched case-insensitively with
	whitespace trimmed (see RedeemCode's handler in PlotManager). Each
	code is one-time use PER PLAYER — tracked in their save under
	redeemedCodes — never per-server, so it doesn't run out.

	Add new codes here; no other file needs to change.
--]]

return {
	LAUNCH = { coins = 500 },
	JUNKYARD = { coins = 250 },
}
