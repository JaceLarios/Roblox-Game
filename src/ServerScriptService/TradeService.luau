--[[
	TradeService (ModuleScript, ServerScriptService) — Junkyard Fusion v1

	Pure session bookkeeping for a 1-for-1 trade between two players in the
	same server — who's trading whom, what each side has offered, and
	whether each side has confirmed. Same shared-module shape as the other
	services: this module holds no item data and performs no item
	movement. PlotManager owns validating an offer and executing the
	actual swap, since it's the only place with direct access to carry
	slots and plot zones.

	The one rule this module exists to enforce: changing your offer resets
	BOTH sides' confirmation, not just your own. Without that, a player
	could confirm a good item, wait for the other side to confirm too,
	then swap in something worthless and re-confirm — the other side would
	still think they were getting the original offer. Resetting both
	sides closes that off entirely.
--]]

local TradeService = {}

local trades = {} -- [tradeId] = { players = {a, b}, offers = {[player]=itemRef}, confirmed = {[player]=true} }
local playerTrade = {} -- [player] = tradeId
local nextId = 0

-- Neither player can already be in a trade — one active trade at a time
-- keeps the state simple and keeps a player from being yanked into a
-- second negotiation mid-confirmation.
function TradeService.Start(playerA, playerB)
	if playerA == playerB then return nil end
	if playerTrade[playerA] or playerTrade[playerB] then return nil end

	nextId = nextId + 1
	local id = nextId
	trades[id] = { players = { playerA, playerB }, offers = {}, confirmed = {} }
	playerTrade[playerA] = id
	playerTrade[playerB] = id
	return id
end

function TradeService.Get(player)
	local id = playerTrade[player]
	return id and trades[id], id
end

function TradeService.Partner(player)
	local trade = TradeService.Get(player)
	if not trade then return nil end
	return trade.players[1] == player and trade.players[2] or trade.players[1]
end

-- itemRef shape: { source = "carry" | zoneKey, index = N, itemName = "..." }
function TradeService.SetOffer(player, itemRef)
	local trade = TradeService.Get(player)
	if not trade then return false end

	trade.offers[player] = itemRef
	trade.confirmed[player] = nil
	local partner = TradeService.Partner(player)
	if partner then trade.confirmed[partner] = nil end
	return true
end

function TradeService.Confirm(player)
	local trade = TradeService.Get(player)
	if not trade then return false end
	if not trade.offers[player] then return false end
	trade.confirmed[player] = true
	return true
end

function TradeService.BothConfirmed(player)
	local trade = TradeService.Get(player)
	if not trade then return false end
	return trade.confirmed[trade.players[1]] == true and trade.confirmed[trade.players[2]] == true
end

function TradeService.Snapshot(player)
	local trade = TradeService.Get(player)
	if not trade then return nil end
	local partner = TradeService.Partner(player)
	return {
		partnerName = partner.Name,
		myOffer = trade.offers[player],
		partnerOffer = trade.offers[partner],
		myConfirmed = trade.confirmed[player] == true,
		partnerConfirmed = trade.confirmed[partner] == true,
	}
end

-- Ends the session for both sides at once — used for cancel, a completed
-- trade, or either player leaving.
function TradeService.End(player)
	local trade, id = TradeService.Get(player)
	if not trade then return end
	for _, p in ipairs(trade.players) do
		playerTrade[p] = nil
	end
	trades[id] = nil
end

TradeService.Cleanup = TradeService.End

return TradeService
