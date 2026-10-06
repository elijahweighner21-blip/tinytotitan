--!strict
--[[
	AudioController
	Centralised audio:
	  * SoundGroups per category (UI, Ambient, Movement, Abilities, Combat,
	    Environment, Music) driven by the player's volume settings
	  * per-sound cooldowns and max-instance limits so effects never stack
	    into noise (e.g. 30 orbs collected at once)
	  * pooled 3D sounds at world positions
	  * size-aware footsteps (light, high taps for specks; deep thuds for
	    titans, with a volume ceiling so titans never clip)
	  * zone ambience and music with crossfades (empty IDs are skipped)
]]

local SoundService = game:GetService("SoundService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AudioConfig = require(Shared.Config.AudioConfig)
local ZoneConfig = require(Shared.Config.ZoneConfig)
local ScaleMath = require(Shared.Formulas.ScaleMath)

local Client = script.Parent.Parent
local UISound = require(Client.UI.Sound)
local SettingsController = require(script.Parent.SettingsController)
local MovementController = require(script.Parent.MovementController)

local AudioController = {}

local groups: { [string]: SoundGroup } = {}
local templates: { [string]: Sound } = {}
local lastPlayed: { [string]: number } = {}
local playing: { [string]: number } = {}
local concurrent = 0
local ambient: Sound? = nil
local music: Sound? = nil
local attachmentPool: { Attachment } = {}
local anchorPart: Part

local function categoryVolume(category: string): number
	local base = AudioConfig.CategoryVolume[category] or 1
	if category == "Music" then
		return base * (SettingsController:Get("MusicVolume") or 0.5)
	elseif category == "Ambient" then
		return base * (SettingsController:Get("AmbientVolume") or 0.6)
	end
	return base * (SettingsController:Get("SfxVolume") or 0.8)
end

local function applyVolumes()
	for name, group in groups do
		group.Volume = categoryVolume(name)
	end
end

local function template(name: string): Sound?
	local existing = templates[name]
	if existing then
		return existing
	end
	local def = AudioConfig.Sounds[name]
	if not def or def.Id == "" then
		return nil
	end
	local sound = Instance.new("Sound")
	sound.Name = name
	sound.SoundId = def.Id
	sound.Volume = def.Volume
	sound.PlaybackSpeed = def.Pitch or 1
	sound.Looped = def.Looped == true
	sound.SoundGroup = groups[def.Category]
	templates[name] = sound
	return sound
end

local function getAttachment(position: Vector3): Attachment
	local pooled = table.remove(attachmentPool)
	local a: Attachment = if pooled then pooled else Instance.new("Attachment")
	a.Parent = anchorPart
	a.WorldPosition = position
	return a
end

export type PlayOptions = { Position: Vector3?, Volume: number?, Pitch: number?, Parent: Instance? }

function AudioController:Play(name: string, opts: PlayOptions?): Sound?
	local def = AudioConfig.Sounds[name]
	local t = template(name)
	if not def or not t then
		return nil
	end
	local now = os.clock()
	if def.Cooldown and now - (lastPlayed[name] or 0) < def.Cooldown then
		return nil
	end
	if (playing[name] or 0) >= (def.MaxInstances or 4) or concurrent >= AudioConfig.MaxConcurrent then
		return nil
	end
	lastPlayed[name] = now
	local o: PlayOptions = opts or {}
	local sound = t:Clone()
	local variance = def.PitchVariance or 0
	sound.PlaybackSpeed = (o.Pitch or def.Pitch or 1) * (1 + (math.random() * 2 - 1) * variance)
	sound.Volume = math.min(def.Volume * (o.Volume or 1), AudioConfig.TitanVolumeCeiling * 1.5)
	local attachment: Attachment? = nil
	if o.Position then
		attachment = getAttachment(o.Position)
		sound.Parent = attachment
		sound.RollOffMode = Enum.RollOffMode.InverseTapered
	else
		sound.Parent = o.Parent or SoundService
	end
	playing[name] = (playing[name] or 0) + 1
	concurrent += 1
	sound.Ended:Once(function()
		playing[name] = math.max(0, (playing[name] or 1) - 1)
		concurrent = math.max(0, concurrent - 1)
		sound:Destroy()
		if attachment then
			table.insert(attachmentPool, attachment)
		end
	end)
	sound:Play()
	-- Safety: never leak a sound that fails to load/end.
	task.delay(10, function()
		if sound.Parent then
			sound:Stop()
			sound:Destroy()
			playing[name] = math.max(0, (playing[name] or 1) - 1)
			concurrent = math.max(0, concurrent - 1)
		end
	end)
	return sound
end

-- Size-aware footstep: pitch drops and volume rises (capped) with scale.
function AudioController:Footstep(position: Vector3, scale: number, material: Enum.Material)
	local pitch = ScaleMath.footstepPitch(scale)
	local volume = ScaleMath.footstepVolume(scale)
	if material == Enum.Material.Fabric or material == Enum.Material.Grass then
		volume *= 0.7
	elseif material == Enum.Material.Metal or material == Enum.Material.DiamondPlate then
		pitch *= 1.15
	end
	AudioController:Play(
		"Footstep",
		{ Position = position, Pitch = pitch, Volume = math.min(volume / 0.3, AudioConfig.TitanVolumeCeiling / 0.3) }
	)
end

local function crossfade(current: Sound?, name: string): Sound?
	local def = AudioConfig.Sounds[name]
	if current and current.Name == name then
		return current
	end
	if current then
		local old = current
		TweenService:Create(old, TweenInfo.new(AudioConfig.MusicCrossfade), { Volume = 0 }):Play()
		task.delay(AudioConfig.MusicCrossfade, function()
			old:Destroy()
		end)
	end
	local t = template(name)
	if not def or not t then
		return nil
	end
	local sound = t:Clone()
	sound.Looped = true
	sound.Volume = 0
	sound.Parent = SoundService
	sound:Play()
	TweenService:Create(sound, TweenInfo.new(AudioConfig.MusicCrossfade), { Volume = def.Volume }):Play()
	return sound
end

function AudioController:SetZone(zoneId: string)
	local zone = ZoneConfig.get(zoneId)
	if not zone then
		return
	end
	ambient = crossfade(ambient, "Ambient" .. zone.Ambience)
	music = crossfade(music, if zone.Order >= 7 then "MusicTitan" else "MusicExplore")
end

function AudioController:SetBossMusic(on: boolean)
	music = crossfade(music, if on then "MusicBoss" else "MusicExplore")
end

function AudioController:Init()
	for category in AudioConfig.CategoryVolume do
		local group = Instance.new("SoundGroup")
		group.Name = "TT_" .. category
		group.Parent = SoundService
		groups[category] = group
	end
	anchorPart = Instance.new("Part")
	anchorPart.Name = "TT_AudioAnchor"
	anchorPart.Anchored = true
	anchorPart.CanCollide = false
	anchorPart.CanQuery = false
	anchorPart.CanTouch = false
	anchorPart.Transparency = 1
	anchorPart.Size = Vector3.one
	anchorPart.Position = Vector3.zero
	anchorPart.Parent = workspace
	applyVolumes()
	SettingsController.Changed:Connect(applyVolumes)
	UISound.play = function(name: string)
		AudioController:Play(name)
	end
end

function AudioController:Start()
	MovementController.Footstep:Connect(function(position, scale, material)
		AudioController:Footstep(position, scale, material)
	end)
	MovementController.Jumped:Connect(function(kind)
		local root = MovementController:GetRoot()
		AudioController:Play(
			if kind == "Jump" then "Jump" else "Dash",
			{ Position = if root then root.Position else nil, Pitch = if kind == "DoubleJump" then 1.25 else nil }
		)
	end)
	MovementController.Landed:Connect(function(bodies, pound)
		local root = MovementController:GetRoot()
		if not root then
			return
		end
		if pound then
			AudioController:Play("GroundPound", { Position = root.Position })
		elseif bodies > 0.6 then
			AudioController:Play("Land", { Position = root.Position, Volume = math.clamp(bodies / 2, 0.4, 1.4) })
		end
	end)
	MovementController.AbilityUsed:Connect(function(id)
		local root = MovementController:GetRoot()
		local position = if root then root.Position else nil
		if id == "AirDash" or id == "GroundDash" then
			AudioController:Play("Dash", { Position = position })
		elseif id == "Slide" then
			AudioController:Play("Slide", { Position = position })
		elseif id == "WallRun" then
			AudioController:Play("WallRun", { Position = position })
		end
	end)
end

return AudioController
