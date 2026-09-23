-- Player-facing names only. Stable item keys remain unchanged in saves and recipes.
local ItemNames = {}
local DISPLAY_NAMES = { ["Rusted Sedan"] = "Scrap Kart" }
function ItemNames.Display(name)
	if type(name) ~= "string" then return name end
	-- Also handles mutation prefixes and formatted item messages.
	for key, display in pairs(DISPLAY_NAMES) do
		name = name:gsub(key, display)
	end
	return name
end
return ItemNames
