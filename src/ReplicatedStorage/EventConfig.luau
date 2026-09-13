--[[
	EventConfig (ModuleScript, ReplicatedStorage) — Junkyard Fusion v1

	The developer's on/off switch for a limited-time event — no calendar
	automation, no admin panel. To run a promo: edit ACTIVE, NAME, and
	EXPIRES_AT here directly in Studio (or via a live script), publish,
	and it takes effect immediately for every server, since both client
	and server read this same module. Set EXPIRES_AT to nil for an event
	that stays on until you flip ACTIVE back to false yourself.

	Read by Mutations.luau (server-side gating of the exclusive "Frenzy"
	mutation tier and its chance boost) and GameUI.client.luau (the
	banner). Client-side reads are cosmetic only — the real gate is
	server-side, inside Mutations.Roll.
--]]

local EventConfig = {}

EventConfig.ACTIVE = false
EventConfig.NAME = "Frenzy Weekend"
EventConfig.EXPIRES_AT = nil -- os.time() timestamp, or nil to run until turned off
EventConfig.MUTATION_CHANCE_MULT = 2

function EventConfig.IsActive()
	if not EventConfig.ACTIVE then return false end
	if EventConfig.EXPIRES_AT and os.time() >= EventConfig.EXPIRES_AT then return false end
	return true
end

return EventConfig
