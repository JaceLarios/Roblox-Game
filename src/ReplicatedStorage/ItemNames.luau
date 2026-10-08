-- Player-facing names only. Stable item keys remain unchanged in saves and recipes.
local ItemNames = {}
local DISPLAY_NAMES = { ["Rusted Sedan"] = "Scrap Kart" }
function ItemNames.Display(name)
	if type(name) ~= "string" then return name end
	-- Also handles mutation prefixes and formatted item messages.
	for key, display in pairs(DISPLAY_NAMES) do
		name = name:gsub(key, display)
	end
	-- An event addon's word (EventAddons): "{Wisp} Warp Wreck" reads
	-- "Wisp Warp Wreck".
	name = name:gsub("{(%a+)} ", "%1 ")
	return name
end
return ItemNames
