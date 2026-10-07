--[[
	RaceChase (LocalScript, StarterPlayerScripts) — Junkyard Fusion

	The chase music in Race Wars (user, 2026-10-07: "taunting music when
	the monster is coming after you, louder the closer it gets"). While you
	race, a tension loop plays, quiet when the monster is far back and full
	volume when it is on your bumper, and the monster growls when it gets
	right behind you. The background music is turned down for the race and
	put back after. Reads RaceGap, the studs between you and the monster
	that RaceService sets on you while you race (gone when your run ends).
	Plays in the game's music group, so the Settings music volume applies.
--]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")

local RaceConfig = require(ReplicatedStorage:WaitForChild("RaceConfig"))

local player = Players.LocalPlayer

-- Volume by how far back the monster is: full at NEAR studs or closer,
-- down to QUIET by FAR studs.
local NEAR, FAR = 35, 360
local QUIET = 0.12
local MAX_VOLUME = 0.9
-- It growls when it is this close, at most once every GROWL_GAP seconds.
local GROWL_RANGE = 110
local GROWL_GAP = 6
-- The background music while racing, as a share of its own volume.
local DUCK = 0.15

-- In the Music folder, so Settings routes it to the music group.
local musicFolder = SoundService:WaitForChild("Music", 30) or SoundService
local chase = Instance.new("Sound")
chase.Name = "RaceChase"
chase.SoundId = RaceConfig.CHASE_MUSIC
chase.Looped = true
chase.Volume = 0
chase.Parent = musicFolder

local growl = Instance.new("Sound")
growl.Name = "MonsterGrowl"
growl.SoundId = RaceConfig.MONSTER_GROWL
growl.Volume = 0.8
growl.Parent = SoundService

local racing = false
local lastGrowl = 0
local ducked = {} -- [background track] = its own volume

local function setDucked(on)
	for _, sound in ipairs(musicFolder:GetChildren()) do
		if sound:IsA("Sound") and sound ~= chase then
			if on and not ducked[sound] then
				ducked[sound] = sound.Volume
				TweenService:Create(sound, TweenInfo.new(1), { Volume = sound.Volume * DUCK }):Play()
			elseif not on and ducked[sound] then
				TweenService:Create(sound, TweenInfo.new(1.5), { Volume = ducked[sound] }):Play()
				ducked[sound] = nil
			end
		end
	end
end

local function loudness(gap)
	local t = math.clamp((gap - NEAR) / (FAR - NEAR), 0, 1)
	return QUIET + (1 - QUIET) * (1 - t) ^ 2
end

RunService.Heartbeat:Connect(function(dt)
	local gap = player:GetAttribute("RaceGap")
	if gap and not racing then
		racing = true
		chase.TimePosition = 0
		chase:Play()
		setDucked(true)
	elseif not gap and racing then
		racing = false
		setDucked(false)
	end

	local target = racing and loudness(gap) * MAX_VOLUME or 0
	-- Eased toward the target so it swells and fades rather than jumps.
	chase.Volume += (target - chase.Volume) * math.min(1, dt * 3)
	if not racing and chase.IsPlaying and chase.Volume < 0.01 then
		chase:Stop()
	end

	if racing and gap < GROWL_RANGE and os.clock() - lastGrowl > GROWL_GAP then
		lastGrowl = os.clock()
		growl.PlaybackSpeed = 0.9 + math.random() * 0.25
		growl.Volume = 0.5 + 0.5 * (1 - math.clamp(gap / GROWL_RANGE, 0, 1))
		growl:Play()
	end
end)
