--[[
	EventAddons (ModuleScript, ReplicatedStorage) — Junkyard Fusion

	Event addons (user, 2026-10-08): special addons, the 15 Phantom addons
	first, that go on ANY car at any stage (a base car or any build, mutated
	or not) as a layer on top of what it already is, instead of making a new
	build:
	  - a car holds one event addon at a time. To put on another, the one it
	    has comes off first, at the Phantom Garage, and is lost;
	  - it stays through everything else: a ghost car that later takes a
	    better addon at the Fusion Pad is still a ghost;
	  - it multiplies the car's value (and so its pad earnings) by its
	    `earn` (FusionRecipes: x1.4 to x3.0, more for a pricier Phantom),
	    on top of any mutation;
	  - the car looks ghostly with the addon's model mounted on it, plus the
	    addon's effect and the Spectral aura (ItemVisuals, VehicleAddonEffects).

	It is written into the item's name after any mutation: "[Golden] {Wisp}
	Warp Wreck" (shown as "Golden Wisp Warp Wreck", ItemNames). Each Phantom
	addon's id is its ghost word (FusionRecipes' `ghost`). Mutations.Unwrap
	takes it off along with the mutation (its third value), so every recipe
	and model lookup keeps working on the bare name; Mutations.Wrap puts
	both back.

	The 105 named Spectral builds (Wisp Kart...) stay in FusionRecipes as the
	Index's Spectral tab: one entry per car and Phantom addon, found the
	first time that Phantom goes on any build of that car (IndexName).
--]]

local FusionRecipes = require(script.Parent:WaitForChild("FusionRecipes"))

local EventAddons = {}

local byId, byAddon = {}, {}
for _, addon in ipairs(FusionRecipes.PhantomAddons) do
	local entry = { id = addon.ghost, addon = addon.name, multiplier = addon.earn }
	assert(entry.id and entry.multiplier and not byId[entry.id], "EventAddons: " .. addon.name .. " needs a unique ghost word and an `earn`")
	byId[entry.id] = entry
	byAddon[addon.name] = entry
end

-- "{Wisp} Warp Wreck" -> "Warp Wreck", "Wisp". A name without one comes
-- back as it is, with nil. Takes a name without its mutation.
function EventAddons.Split(name)
	if type(name) ~= "string" then return name, nil end
	local id, rest = name:match("^{(%a+)}%s(.+)$")
	if id and byId[id] then return rest, id end
	return name, nil
end

-- "Warp Wreck", "Wisp" -> "{Wisp} Warp Wreck"; no id, the name unchanged.
function EventAddons.Join(name, id)
	if id and byId[id] then return string.format("{%s} %s", id, name) end
	return name
end

-- The id an addon puts on a car, or nil when it is not an event addon.
function EventAddons.Of(addonName)
	local entry = byAddon[addonName]
	return entry and entry.id
end

-- The addon behind an id, or nil.
function EventAddons.Addon(id)
	local entry = byId[id]
	return entry and entry.addon
end

-- What a Phantom addon multiplies a car's value by (nil for anything else).
function EventAddons.AddonMultiplier(addonName)
	local entry = byAddon[addonName]
	return entry and entry.multiplier
end

-- What it multiplies the car's value by (1 for none).
function EventAddons.Multiplier(id)
	local entry = byId[id]
	return entry and entry.multiplier or 1
end

-- The Index entry (a named Spectral build) a car with this event addon
-- fills: its car's build with that Phantom. Nil for a car outside the seven
-- (a Secret car).
function EventAddons.IndexName(itemName, id)
	local car, addon = FusionRecipes.CarOf(itemName), EventAddons.Addon(id)
	return car and addon and (FusionRecipes.Fuse(car, addon)) or nil
end

-- The car and event addon a named Spectral build stands for ("Wisp Kart"
-- -> "Rusted Sedan", "Wisp"), or nil for any other name.
function EventAddons.FromIndexName(name)
	local car, addon = FusionRecipes.CarOf(name), FusionRecipes.AddonOf(name)
	local entry = addon and byAddon[addon]
	if car and entry and car ~= name then return car, entry.id end
	return nil
end

-- Why an event addon can't go on with the other item, or nil when it can.
-- Bare names, each with the event addon it already has (or nil). Nil as
-- well when neither is an event addon: that pair is an ordinary fusion.
function EventAddons.Problem(itemA, eventA, itemB, eventB)
	local idA, idB = EventAddons.Of(itemA), EventAddons.Of(itemB)
	if not (idA or idB) then return nil end
	if idA and idB then
		return "You can't fuse two addons together. Put a phantom on a car."
	end
	local car, carEvent = itemB, eventB
	if idB then car, carEvent = itemA, eventA end
	if FusionRecipes.IsAddon(car) or not FusionRecipes.GetRarity(car) then
		return "Phantoms go on a car, not on an addon."
	end
	if carEvent then
		return "That car already has a phantom. Remove it at the Phantom Garage first (the phantom is lost)."
	end
	return nil
end

return EventAddons
