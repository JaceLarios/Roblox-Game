--[[
	DailyQuests (ModuleScript, ServerScriptService) — Junkyard Fusion

	Three quests a day for each player, picked fresh every day (the same
	UTC day the daily rewards use) from the list below, and the same three
	however often they rejoin that day. Only quests a player can actually
	do are picked: "discover a new build" waits for an Index that is not
	complete (race quests needed the first Rebirth until races opened to
	everyone).

	PlotManager tells this module what players do (Record) and pays out
	whatever it reports finished; all this module does is keep the list
	and the counting. A quest's reward is some seconds of its player's own
	pad income (`minutes` below, times PlotManager's
	Quests.SECONDS_PER_MINUTE; never under MIN_REWARD), so it means as much
	to a new player as to a Rebirth 6 one. Finishing all three wins bonus
	bolts.
--]]

local DailyQuests = {}

DailyQuests.PER_DAY = 3
DailyQuests.MIN_REWARD = 300

-- event: what PlotManager calls Record with; goals: one of these is picked
-- as the target; minutes: the reward, in minutes of pad income; needs: a
-- key in the player's context (see Ensure) that has to be true.
local QUESTS = {
	{ id = "grab",      event = "grab",      text = "Grab %d cars off the conveyor",         goals = { 6, 10, 14 }, minutes = 4 },
	{ id = "rareGrab",  event = "rareGrab",  text = "Grab a Rare or better car",             goals = { 1 },         minutes = 5 },
	{ id = "fuse",      event = "fuse",      text = "Fuse %d builds at your pad",            goals = { 3, 5 },      minutes = 5 },
	{ id = "fuseRare",  event = "fuseRare",  text = "Fuse a Rare or better build",           goals = { 1 },         minutes = 6, needs = "fusedThree" },
	{ id = "discover",  event = "discover",  text = "Discover a new build",                  goals = { 1 },         minutes = 6, needs = "indexOpen" },
	{ id = "place",     event = "place",     text = "Place %d builds on your earning pads",  goals = { 2, 3 },      minutes = 3 },
	{ id = "addon",     event = "addon",     text = "Buy an addon in the Shop",              goals = { 1 },         minutes = 3 },
	{ id = "play",      event = "play",      text = "Play for %d minutes",                   goals = { 10, 20 },    minutes = 4 },
	{ id = "raceLevel", event = "raceLevel", text = "Clear %d race levels",                  goals = { 2, 4 },      minutes = 6, needs = "races" },
	{ id = "bolts",     event = "bolts",     text = "Win %d bolts in Race Wars",             goals = { 4, 8 },      minutes = 5, needs = "races" },
}

local byId = {}
for _, quest in ipairs(QUESTS) do
	byId[quest.id] = quest
end
-- Races paid crates, and one quest was to open some, until 2026-10-05: a
-- saved "crate" quest from that day counts bolts instead.
byId.crate = byId.bolts

-- Makes sure s.quests holds today's quests, picking them if it does not.
-- context: { races = bool, fusedThree = bool, indexOpen = bool }.
-- Returns true when it picked a new set.
function DailyQuests.Ensure(s, userId, day, context)
	if s.quests and s.quests.day == day then
		return false
	end
	-- Seeded by the day and the player, so the same three come back
	-- however often they rejoin today.
	local rng = Random.new(day * 7919 + userId % 1000003)
	local pool = {}
	for _, quest in ipairs(QUESTS) do
		if not quest.needs or context[quest.needs] then
			table.insert(pool, quest)
		end
	end
	local list = {}
	for _ = 1, math.min(DailyQuests.PER_DAY, #pool) do
		local quest = table.remove(pool, rng:NextInteger(1, #pool))
		table.insert(list, {
			id = quest.id,
			goal = quest.goals[rng:NextInteger(1, #quest.goals)],
			progress = 0,
			done = false,
		})
	end
	s.quests = { day = day, list = list, bonus = false }
	return true
end

-- Counts `amount` of `event` toward today's quests. Returns the quests it
-- finished (each only ever once), and whether any quest moved at all.
function DailyQuests.Record(s, event, amount)
	local finished, changed = {}, false
	if not s.quests then return finished, changed end
	for _, entry in ipairs(s.quests.list) do
		local quest = byId[entry.id]
		if quest and quest.event == event and not entry.done then
			entry.progress = math.min(entry.goal, entry.progress + (amount or 1))
			changed = true
			if entry.progress >= entry.goal then
				entry.done = true
				table.insert(finished, entry)
			end
		end
	end
	return finished, changed
end

function DailyQuests.AllDone(s)
	if not s.quests or #s.quests.list == 0 then return false end
	for _, entry in ipairs(s.quests.list) do
		if not entry.done then return false end
	end
	return true
end

-- What a quest says, and how many minutes of pad income it pays.
function DailyQuests.Text(entry)
	local quest = byId[entry.id]
	return quest and string.format(quest.text, entry.goal) or entry.id
end

function DailyQuests.Minutes(entry)
	local quest = byId[entry.id]
	return quest and quest.minutes or 0
end

return DailyQuests
