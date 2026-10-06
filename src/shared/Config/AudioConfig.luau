--!strict
--[[
	AudioConfig
	Every sound the game plays, grouped into mixer categories. IDs use sounds
	that ship with the Roblox client (rbxasset://sounds/...) so the game is
	audible out of the box; swap in uploaded rbxassetid:// IDs for final audio.
	Music and ambience entries left empty ("") are skipped gracefully — upload
	licensed tracks and paste their IDs here.
]]

export type SoundDef = {
	Id: string,
	Category: "UI" | "Ambient" | "Movement" | "Abilities" | "Combat" | "Environment" | "Music",
	Volume: number,
	Pitch: number?,
	PitchVariance: number?,
	MaxInstances: number?, -- simultaneous plays allowed (anti-stacking)
	Cooldown: number?, -- minimum seconds between plays of this sound
	Looped: boolean?,
}

local S = "rbxasset://sounds/"

local Sounds: { [string]: SoundDef } = {
	-- UI
	Click = { Id = S .. "button.wav", Category = "UI", Volume = 0.35, Pitch = 1.1, MaxInstances = 2, Cooldown = 0.04 },
	Hover = { Id = S .. "clickfast.wav", Category = "UI", Volume = 0.12, Pitch = 1.4, MaxInstances = 1, Cooldown = 0.05 },
	Open = { Id = S .. "swoosh.wav", Category = "UI", Volume = 0.25, Pitch = 1.3, MaxInstances = 1, Cooldown = 0.08 },
	Close = { Id = S .. "swoosh.wav", Category = "UI", Volume = 0.2, Pitch = 0.9, MaxInstances = 1, Cooldown = 0.08 },
	Purchase = { Id = S .. "electronicpingshort.wav", Category = "UI", Volume = 0.5, Pitch = 1.2, MaxInstances = 2 },
	Error = { Id = S .. "button.wav", Category = "UI", Volume = 0.4, Pitch = 0.6, MaxInstances = 1, Cooldown = 0.2 },
	Notify = { Id = S .. "electronicpingshort.wav", Category = "UI", Volume = 0.3, Pitch = 1.5, MaxInstances = 2, Cooldown = 0.1 },
	Reward = { Id = S .. "electronicpingshort.wav", Category = "UI", Volume = 0.45, Pitch = 1.8, MaxInstances = 3, Cooldown = 0.05 },
	LevelUp = { Id = S .. "electronicpingshort.wav", Category = "UI", Volume = 0.6, Pitch = 0.8, MaxInstances = 1 },
	Achievement = { Id = S .. "electronicpingshort.wav", Category = "UI", Volume = 0.55, Pitch = 1, MaxInstances = 1 },
	-- Movement
	Footstep = { Id = S .. "action_footsteps_plastic.mp3", Category = "Movement", Volume = 0.3, PitchVariance = 0.08, MaxInstances = 2, Cooldown = 0.06 },
	Jump = { Id = S .. "action_jump.mp3", Category = "Movement", Volume = 0.35, PitchVariance = 0.05, MaxInstances = 2, Cooldown = 0.05 },
	Land = { Id = S .. "action_jump_land.mp3", Category = "Movement", Volume = 0.45, PitchVariance = 0.05, MaxInstances = 2, Cooldown = 0.08 },
	Dash = { Id = S .. "swoosh.wav", Category = "Movement", Volume = 0.45, PitchVariance = 0.1, MaxInstances = 2, Cooldown = 0.1 },
	Slide = { Id = S .. "action_swim.mp3", Category = "Movement", Volume = 0.3, Pitch = 1.4, MaxInstances = 1 },
	WallRun = { Id = S .. "action_footsteps_plastic.mp3", Category = "Movement", Volume = 0.3, Pitch = 1.3, MaxInstances = 1, Cooldown = 0.1 },
	Glide = { Id = S .. "action_falling.mp3", Category = "Movement", Volume = 0.2, Pitch = 1.2, Looped = true, MaxInstances = 1 },
	Fall = { Id = S .. "action_falling.mp3", Category = "Movement", Volume = 0.25, MaxInstances = 1 },
	-- Abilities
	GroundPound = { Id = S .. "action_jump_land.mp3", Category = "Abilities", Volume = 0.7, Pitch = 0.5, MaxInstances = 2 },
	Stomp = { Id = S .. "action_jump_land.mp3", Category = "Abilities", Volume = 0.8, Pitch = 0.3, MaxInstances = 3, Cooldown = 0.1 },
	Shockwave = { Id = S .. "swoosh.wav", Category = "Abilities", Volume = 0.7, Pitch = 0.4, MaxInstances = 2 },
	Roar = { Id = S .. "uuhhh.mp3", Category = "Abilities", Volume = 0.6, Pitch = 0.35, MaxInstances = 1 },
	Scan = { Id = S .. "electronicpingshort.wav", Category = "Abilities", Volume = 0.45, Pitch = 0.7, MaxInstances = 1 },
	Shrink = { Id = S .. "swoosh.wav", Category = "Abilities", Volume = 0.5, Pitch = 2, MaxInstances = 1 },
	GrowthRise = { Id = S .. "swoosh.wav", Category = "Abilities", Volume = 0.6, Pitch = 0.6, MaxInstances = 1 },
	-- Combat
	Hit = { Id = S .. "action_jump_land.mp3", Category = "Combat", Volume = 0.4, Pitch = 1.6, PitchVariance = 0.15, MaxInstances = 4, Cooldown = 0.03 },
	HeavyHit = { Id = S .. "action_jump_land.mp3", Category = "Combat", Volume = 0.55, Pitch = 0.9, PitchVariance = 0.1, MaxInstances = 3, Cooldown = 0.05 },
	Swing = { Id = S .. "swoosh.wav", Category = "Combat", Volume = 0.3, Pitch = 1.5, PitchVariance = 0.1, MaxInstances = 3, Cooldown = 0.05 },
	Hurt = { Id = S .. "uuhhh.mp3", Category = "Combat", Volume = 0.3, Pitch = 1.3, MaxInstances = 1, Cooldown = 0.4 },
	EnemyDeath = { Id = S .. "electronicpingshort.wav", Category = "Combat", Volume = 0.3, Pitch = 0.5, MaxInstances = 3, Cooldown = 0.05 },
	BossRoar = { Id = S .. "uuhhh.mp3", Category = "Combat", Volume = 0.8, Pitch = 0.25, MaxInstances = 1 },
	Telegraph = { Id = S .. "clickfast.wav", Category = "Combat", Volume = 0.3, Pitch = 0.6, MaxInstances = 2, Cooldown = 0.15 },
	-- Environment
	Collect = { Id = S .. "electronicpingshort.wav", Category = "Environment", Volume = 0.35, Pitch = 2, PitchVariance = 0.1, MaxInstances = 3, Cooldown = 0.03 },
	RareCollect = { Id = S .. "electronicpingshort.wav", Category = "Environment", Volume = 0.55, Pitch = 1.3, MaxInstances = 1 },
	Break = { Id = S .. "action_jump_land.mp3", Category = "Environment", Volume = 0.5, Pitch = 1.2, MaxInstances = 3, Cooldown = 0.05 },
	Push = { Id = S .. "action_swim.mp3", Category = "Environment", Volume = 0.35, Pitch = 0.7, MaxInstances = 2 },
	Splash = { Id = S .. "impact_water.mp3", Category = "Environment", Volume = 0.5, MaxInstances = 2 },
	Discovery = { Id = S .. "electronicpingshort.wav", Category = "Environment", Volume = 0.6, Pitch = 0.9, MaxInstances = 1 },
	Teleport = { Id = S .. "swoosh.wav", Category = "Environment", Volume = 0.5, Pitch = 0.8, MaxInstances = 1 },
	EventHorn = { Id = S .. "electronicpingshort.wav", Category = "Environment", Volume = 0.6, Pitch = 0.55, MaxInstances = 1 },
	-- Ambient beds per zone (upload looping ambience and set IDs)
	AmbientIndoor = { Id = "", Category = "Ambient", Volume = 0.4, Looped = true },
	AmbientBedroom = { Id = "", Category = "Ambient", Volume = 0.4, Looped = true },
	AmbientKitchen = { Id = "", Category = "Ambient", Volume = 0.4, Looped = true },
	AmbientOutdoor = { Id = "", Category = "Ambient", Volume = 0.5, Looped = true },
	AmbientSuburb = { Id = "", Category = "Ambient", Volume = 0.45, Looped = true },
	AmbientCity = { Id = "", Category = "Ambient", Volume = 0.5, Looped = true },
	AmbientTitan = { Id = "", Category = "Ambient", Volume = 0.5, Looped = true },
	AmbientWild = { Id = "", Category = "Ambient", Volume = 0.5, Looped = true },
	-- Music (upload licensed tracks and paste IDs)
	MusicExplore = { Id = "", Category = "Music", Volume = 0.35, Looped = true },
	MusicBoss = { Id = "", Category = "Music", Volume = 0.45, Looped = true },
	MusicTitan = { Id = "", Category = "Music", Volume = 0.4, Looped = true },
}

local AudioConfig = {
	Sounds = Sounds,
	-- Master per-category volumes (multiplied by player settings).
	CategoryVolume = {
		UI = 1,
		Ambient = 1,
		Movement = 1,
		Abilities = 1,
		Combat = 1,
		Environment = 1,
		Music = 1,
	} :: { [string]: number },
	-- Global ceiling on concurrently playing one-shot sounds per client.
	MaxConcurrent = 24,
	-- Large sounds get quieter (but deeper) so titan stomps never clip.
	TitanVolumeCeiling = 0.85,
	MusicCrossfade = 2,
}

return AudioConfig
