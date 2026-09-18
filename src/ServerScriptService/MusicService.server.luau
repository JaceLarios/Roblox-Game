--[[
	MusicService (Script, ServerScriptService) — Junkyard Fusion v1

	Background music. A short playlist rather than one track on endless
	repeat, cycled on the server so everyone in the round hears the same
	thing at the same time.

	Sounds live in SoundService rather than in a part, so they play as flat
	2D audio everywhere instead of falling off with distance the way the
	yard and fusion effects do.

	Swapping the soundtrack is a one-line change per row in PLAYLIST.
--]]

local SoundService = game:GetService("SoundService")

-- Deliberately low: this sits underneath the pickup/fusion sounds, which
-- are the ones that actually carry feedback.
local VOLUME = 0.3
local GAP_BETWEEN_TRACKS = 2
-- Safety net only. A track that fails to load never fires Ended, and
-- without a ceiling one bad asset id would stall the playlist on silence
-- forever instead of moving on.
local MAX_TRACK_SECONDS = 240

local PLAYLIST = {
	{ name = "Your Time to Shine", id = 102972015112047 },
	{ name = "Main Theme",         id = 125536723574585 },
	{ name = "Retro Radiance",     id = 100333487341753 },
}

local existing = SoundService:FindFirstChild("Music")
if existing then existing:Destroy() end

local folder = Instance.new("Folder")
folder.Name = "Music"
folder.Parent = SoundService

local sounds = {}
for _, track in ipairs(PLAYLIST) do
	local sound = Instance.new("Sound")
	sound.Name = track.name
	sound.SoundId = "rbxassetid://" .. track.id
	sound.Volume = VOLUME
	sound.Looped = false
	sound.Parent = folder
	table.insert(sounds, sound)
end

task.spawn(function()
	local index = 0
	while #sounds > 0 do
		index = index % #sounds + 1
		local sound = sounds[index]

		sound.TimePosition = 0
		sound:Play()

		local done = Instance.new("BindableEvent")
		local conn = sound.Ended:Connect(function() done:Fire() end)
		task.delay(MAX_TRACK_SECONDS, function() done:Fire() end)
		done.Event:Wait()
		conn:Disconnect()
		done:Destroy()

		sound:Stop()
		task.wait(GAP_BETWEEN_TRACKS)
	end
end)

print(string.format("[Music] Playlist ready — %d tracks.", #sounds))
