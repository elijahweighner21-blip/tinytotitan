--!strict
--[[
	EnvironmentController
	Client-side atmosphere and performance:

	  * zone lighting presets (indoor lamp-light, kitchen, outdoor day, city
	    dusk, titan city, the wilderness) blended smoothly on zone change
	  * world-event overrides (Power Outage darkens everything; it lifts when
	    the event ends)
	  * small ambient animations (swaying grass, the VIP disco floor) for
	    nearby tagged parts only
	  * graphics presets and the Auto preset, which steps quality down when
	    the frame rate stays low and back up when it recovers
]]

local CollectionService = game:GetService("CollectionService")
local Lighting = game:GetService("Lighting")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ZoneConfig = require(Shared.Config.ZoneConfig)
local SettingsConfig = require(Shared.Config.SettingsConfig)
local Signal = require(Shared.Util.Signal)

local Client = script.Parent.Parent
local Net = require(Client.Net)
local SettingsController = require(script.Parent.SettingsController)
local EffectsController = require(script.Parent.EffectsController)
local ZoneController = require(script.Parent.ZoneController)
local MovementController = require(script.Parent.MovementController)

local EnvironmentController = {}

-- (presetName) when the effective graphics preset changes.
EnvironmentController.PresetChanged = Signal.new() :: Signal.Signal<string>

type LightPreset = {
	ClockTime: number,
	Brightness: number,
	Ambient: Color3,
	OutdoorAmbient: Color3,
	Density: number,
	Haze: number,
	AtmosphereColor: Color3,
	Tint: Color3,
	Exposure: number,
}

local PRESETS: { [string]: LightPreset } = {
	Indoor = {
		ClockTime = 14.5,
		Brightness = 1.6,
		Ambient = Color3.fromRGB(95, 85, 80),
		OutdoorAmbient = Color3.fromRGB(140, 125, 115),
		Density = 0.25,
		Haze = 0.8,
		AtmosphereColor = Color3.fromRGB(235, 215, 190),
		Tint = Color3.fromRGB(255, 244, 230),
		Exposure = 0.15,
	},
	Kitchen = {
		ClockTime = 13,
		Brightness = 2,
		Ambient = Color3.fromRGB(100, 100, 105),
		OutdoorAmbient = Color3.fromRGB(150, 150, 160),
		Density = 0.2,
		Haze = 0.6,
		AtmosphereColor = Color3.fromRGB(225, 230, 240),
		Tint = Color3.fromRGB(245, 250, 255),
		Exposure = 0.2,
	},
	Outdoor = {
		ClockTime = 11,
		Brightness = 2.6,
		Ambient = Color3.fromRGB(80, 90, 100),
		OutdoorAmbient = Color3.fromRGB(135, 150, 165),
		Density = 0.3,
		Haze = 1.4,
		AtmosphereColor = Color3.fromRGB(200, 220, 240),
		Tint = Color3.fromRGB(255, 255, 255),
		Exposure = 0.05,
	},
	City = {
		ClockTime = 17.4,
		Brightness = 2.2,
		Ambient = Color3.fromRGB(90, 80, 95),
		OutdoorAmbient = Color3.fromRGB(150, 130, 140),
		Density = 0.35,
		Haze = 1.8,
		AtmosphereColor = Color3.fromRGB(240, 200, 180),
		Tint = Color3.fromRGB(255, 240, 225),
		Exposure = 0.05,
	},
	Titan = {
		ClockTime = 16,
		Brightness = 2.4,
		Ambient = Color3.fromRGB(85, 85, 110),
		OutdoorAmbient = Color3.fromRGB(140, 140, 175),
		Density = 0.4,
		Haze = 2.2,
		AtmosphereColor = Color3.fromRGB(190, 200, 240),
		Tint = Color3.fromRGB(240, 245, 255),
		Exposure = 0,
	},
	Wild = {
		ClockTime = 7.2,
		Brightness = 2.1,
		Ambient = Color3.fromRGB(95, 80, 110),
		OutdoorAmbient = Color3.fromRGB(160, 130, 170),
		Density = 0.42,
		Haze = 2.6,
		AtmosphereColor = Color3.fromRGB(230, 190, 220),
		Tint = Color3.fromRGB(255, 235, 245),
		Exposure = 0.05,
	},
	Outage = {
		ClockTime = 21,
		Brightness = 0.4,
		Ambient = Color3.fromRGB(25, 25, 40),
		OutdoorAmbient = Color3.fromRGB(40, 40, 60),
		Density = 0.45,
		Haze = 0.5,
		AtmosphereColor = Color3.fromRGB(60, 70, 110),
		Tint = Color3.fromRGB(170, 185, 255),
		Exposure = -0.3,
	},
}

local basePreset = "Indoor"
local override: string? = nil
local overrideUntil = 0
local effectivePreset = "High"
local autoLevel = "High"
local frameTimes: { number } = {}
local lowSince: number? = nil
local highSince: number? = nil
local swayParts: { [BasePart]: CFrame } = {}
local discoParts: { BasePart } = {}
local lastSwayRefresh = 0
local nearbySway: { BasePart } = {}

local function applyLighting(name: string, duration: number)
	local p = PRESETS[name]
	if not p then
		return
	end
	local info = TweenInfo.new(duration, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
	TweenService:Create(Lighting, info, {
		ClockTime = p.ClockTime,
		Brightness = p.Brightness,
		Ambient = p.Ambient,
		OutdoorAmbient = p.OutdoorAmbient,
		ExposureCompensation = p.Exposure,
	}):Play()
	local atmosphere = Lighting:FindFirstChildOfClass("Atmosphere")
	if atmosphere then
		TweenService:Create(atmosphere, info, { Density = p.Density, Haze = p.Haze, Color = p.AtmosphereColor }):Play()
	end
	local grade = Lighting:FindFirstChild("Grade")
	if grade and grade:IsA("ColorCorrectionEffect") then
		TweenService:Create(grade, info, { TintColor = p.Tint }):Play()
	end
end

local function refreshLighting(duration: number)
	applyLighting(override or basePreset, duration)
end

function EnvironmentController:SetOverride(name: string?, duration: number?)
	override = name
	overrideUntil = if name and duration then os.clock() + duration else 0
	refreshLighting(1.5)
end

------------------------------------------------------------------ graphics

local function applyGraphics(name: string)
	local preset = SettingsConfig.Presets[name] or SettingsConfig.Presets.High
	effectivePreset = name
	Lighting.GlobalShadows = preset.Shadows
	for _, child in Lighting:GetChildren() do
		if child:IsA("BloomEffect") or child:IsA("SunRaysEffect") or child:IsA("DepthOfFieldEffect") then
			child.Enabled = preset.PostEffects
		end
	end
	EffectsController:SetPreset(name)
	EnvironmentController.PresetChanged:Fire(name)
end

function EnvironmentController:GetPreset(): string
	return effectivePreset
end

local function settingPreset(): string
	return (SettingsController:Get("PerformancePreset") :: string?) or "Auto"
end

-- Auto preset: step down when FPS stays low, back up when it recovers.
local function autoTick(now: number)
	if #frameTimes < 30 then
		return
	end
	local total = 0
	for _, dt in frameTimes do
		total += dt
	end
	local fps = #frameTimes / total
	local t = SettingsConfig.AutoThresholds
	local lowLimit = if autoLevel == "High" then t.HighToMedium elseif autoLevel == "Medium" then t.MediumToLow else 0
	if fps < lowLimit then
		lowSince = lowSince or now
		highSince = nil
		if now - (lowSince :: number) >= t.Window then
			autoLevel = if autoLevel == "High" then "Medium" else "Low"
			lowSince = nil
			applyGraphics(autoLevel)
		end
	elseif fps >= t.Recover and autoLevel ~= "High" then
		highSince = highSince or now
		lowSince = nil
		-- Recover slowly so quality doesn't flap.
		if now - (highSince :: number) >= t.Window * 4 then
			autoLevel = if autoLevel == "Low" then "Medium" else "High"
			highSince = nil
			applyGraphics(autoLevel)
		end
	else
		lowSince = nil
		highSince = nil
	end
end

------------------------------------------------------------------ ambient motion

local function trackSway(part: Instance)
	if part:IsA("BasePart") then
		swayParts[part] = part.CFrame
	end
end

local function trackDisco(part: Instance)
	if part:IsA("BasePart") then
		table.insert(discoParts, part)
	end
end

local function animateAmbient(now: number)
	if effectivePreset == "Low" then
		return
	end
	if now - lastSwayRefresh > 1 then
		lastSwayRefresh = now
		table.clear(nearbySway)
		local camera = workspace.CurrentCamera
		if camera then
			local range = math.max(MovementController:GetHeight() * 30, 150)
			for part in swayParts do
				if (part.Position - camera.CFrame.Position).Magnitude < range then
					table.insert(nearbySway, part)
					if #nearbySway >= 250 then
						break
					end
				end
			end
		end
	end
	for _, part in nearbySway do
		local home = swayParts[part]
		if home and part.Parent then
			local phase = home.Position.X * 0.05 + home.Position.Z * 0.03
			local angle = math.sin(now * 1.3 + phase) * 0.06
			local pivot = home.Position - home.UpVector * part.Size.Y * 0.5
			part.CFrame = CFrame.new(pivot) * CFrame.Angles(angle, 0, angle * 0.6) * CFrame.new(-pivot) * home
		end
	end
	for i, part in discoParts do
		if part.Parent then
			part.Color = Color3.fromHSV((now * 0.2 + i * 0.13) % 1, 0.7, 1)
		end
	end
end

function EnvironmentController:Init()
	Net.onSignal("WorldEvent", function(payload)
		if type(payload) ~= "table" then
			return
		end
		if payload.State == "Lighting" and type(payload.Preset) == "string" then
			EnvironmentController:SetOverride(payload.Preset, (payload.Duration :: number?) or 60)
		elseif payload.State == "End" and override then
			EnvironmentController:SetOverride(nil)
		end
	end)
	ZoneController.ZoneChanged:Connect(function(zoneId)
		local zone = ZoneConfig.get(zoneId)
		if zone and zone.Lighting ~= basePreset then
			basePreset = zone.Lighting
			if not override then
				refreshLighting(2.5)
			end
		end
	end)
	SettingsController.Changed:Connect(function(key, value)
		if key == "PerformancePreset" then
			if value == "Auto" then
				applyGraphics(autoLevel)
			else
				applyGraphics(value)
			end
		end
	end)
end

function EnvironmentController:Start()
	local chosen = settingPreset()
	applyGraphics(if chosen == "Auto" then autoLevel else chosen)
	refreshLighting(0)
	for _, part in CollectionService:GetTagged("Sway") do
		trackSway(part)
	end
	CollectionService:GetInstanceAddedSignal("Sway"):Connect(trackSway)
	CollectionService:GetInstanceRemovedSignal("Sway"):Connect(function(part)
		swayParts[part :: BasePart] = nil
	end)
	for _, part in CollectionService:GetTagged("Disco") do
		trackDisco(part)
	end
	CollectionService:GetInstanceAddedSignal("Disco"):Connect(trackDisco)
	local lastAuto = 0
	RunService.RenderStepped:Connect(function(dt)
		local now = os.clock()
		table.insert(frameTimes, dt)
		if #frameTimes > 90 then
			table.remove(frameTimes, 1)
		end
		if override and overrideUntil > 0 and now > overrideUntil then
			EnvironmentController:SetOverride(nil)
		end
		if settingPreset() == "Auto" and now - lastAuto > 1 then
			lastAuto = now
			autoTick(now)
		end
		animateAmbient(now)
	end)
end

return EnvironmentController
