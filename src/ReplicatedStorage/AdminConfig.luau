--[[
	AdminConfig (ModuleScript, ReplicatedStorage) — Junkyard Fusion

	Who is an admin: who gets the ADMIN button (AdminPanel.client), and
	whose admin actions the server carries out (AdminService). The
	experience's owner always is; anyone else goes in ADMINS by UserId.
--]]

local AdminConfig = {}

local ADMINS = {
	[155083524] = true, -- jace_343 (the owner)
}

function AdminConfig.IsAdmin(player)
	if ADMINS[player.UserId] then
		return true
	end
	return game.CreatorType == Enum.CreatorType.User and game.CreatorId ~= 0 and player.UserId == game.CreatorId
end

return AdminConfig
