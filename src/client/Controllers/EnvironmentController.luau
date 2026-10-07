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
local UIManager = require(Client.UI.UIManager)
local SettingsController = require(script.Parent.SettingsController)
local EffectsController = require(script.Parent.EffectsController)
local ZoneController = require(script.Parent.ZoneController)
local MovementController = require(script.Parent.MovementController)

local EnvironmentController = {}
EnvironmentController.Animated = 0

-- (presetName) when the effective graphics preset changes.
EnvironmentController.PresetChanged = Signal.new() :: Signal.Signal<string>

-- One look per region: the whole set (sun, ambient, atmosphere, clouds,
-- grade, bloom, rays, depth of field) blends together on zone change, so
-- moving between areas feels like one continuous world.
type LightPreset = {
	ClockTime: number,
	Brightness: number,
	Ambient: Color3,
	OutdoorAmbient: Color3,
	Exposure: number,
	Diffuse: number,
	Specular: number,
	Density: number,
	Offset: number,
	Haze: number,
	Glare: number,
	AtmosphereColor: Color3,
	Decay: Color3,
	Tint: Color3,
	Saturation: number,
	Contrast: number,
	Bloom: number,
	BloomThreshold: number,
	Rays: number,
	Blur: number, -- far depth-of-field intensity (0 = off)
	Clouds: number, -- cloud cover (0 = clear)
	CloudColor: Color3,
}

local rgb = Color3.fromRGB
local PRESETS: { [string]: LightPreset } = {
	-- Living room: warm late-afternoon light pouring through the windows.
	Living = {
		ClockTime = 15.6,
		Brightness = 2.4,
		Ambient = rgb(150, 128, 108),
		OutdoorAmbient = rgb(170, 152, 132),
		Exposure = 0.25,
		Diffuse = 0.8,
		Specular = 0.6,
		Density = 0.18,
		Offset = 0,
		Haze = 1,
		Glare = 0,
		AtmosphereColor = rgb(255, 226, 190),
		Decay = rgb(200, 160, 120),
		Tint = rgb(255, 243, 228),
		Saturation = 0.12,
		Contrast = 0.1,
		Bloom = 0.45,
		BloomThreshold = 1.3,
		Rays = 0.06,
		Blur = 0,
		Clouds = 0.4,
		CloudColor = rgb(255, 240, 225),
	},
	-- Bedroom: cozy golden hour with soft lavender shadows.
	Bedroom = {
		ClockTime = 16.6,
		Brightness = 2.3,
		Ambient = rgb(162, 142, 156),
		OutdoorAmbient = rgb(182, 162, 176),
		Exposure = 0.35,
		Diffuse = 0.8,
		Specular = 0.6,
		Density = 0.2,
		Offset = 0,
		Haze = 1.2,
		Glare = 0,
		AtmosphereColor = rgb(255, 215, 200),
		Decay = rgb(190, 140, 160),
		Tint = rgb(255, 238, 226),
		Saturation = 0.14,
		Contrast = 0.1,
		Bloom = 0.5,
		BloomThreshold = 1.2,
		Rays = 0.08,
		Blur = 0,
		Clouds = 0.45,
		CloudColor = rgb(255, 225, 215),
	},
	-- Kitchen: clean, bright midday light with crisp reflections.
	Kitchen = {
		ClockTime = 12.6,
		Brightness = 3,
		Ambient = rgb(165, 166, 172),
		OutdoorAmbient = rgb(185, 190, 200),
		Exposure = 0.3,
		Diffuse = 1,
		Specular = 1,
		Density = 0.15,
		Offset = 0,
		Haze = 0.6,
		Glare = 0,
		AtmosphereColor = rgb(232, 240, 250),
		Decay = rgb(170, 185, 205),
		Tint = rgb(248, 252, 255),
		Saturation = 0.1,
		Contrast = 0.08,
		Bloom = 0.4,
		BloomThreshold = 1.4,
		Rays = 0.04,
		Blur = 0,
		Clouds = 0.35,
		CloudColor = rgb(255, 255, 255),
	},
	-- Backyard: bright natural sunlight, clear blue sky, puffy clouds.
	Backyard = {
		ClockTime = 13.2,
		Brightness = 3,
		Ambient = rgb(110, 116, 126),
		OutdoorAmbient = rgb(150, 162, 178),
		Exposure = 0.1,
		Diffuse = 1,
		Specular = 0.7,
		Density = 0.22,
		Offset = 0.2,
		Haze = 1,
		Glare = 0.3,
		AtmosphereColor = rgb(199, 222, 244),
		Decay = rgb(106, 129, 160),
		Tint = rgb(255, 254, 250),
		Saturation = 0.14,
		Contrast = 0.08,
		Bloom = 0.35,
		BloomThreshold = 1.5,
		Rays = 0.06,
		Blur = 0,
		Clouds = 0.55,
		CloudColor = rgb(255, 255, 255),
	},
	-- Neighborhood: warm, colourful late afternoon.
	Suburb = {
		ClockTime = 16.4,
		Brightness = 2.8,
		Ambient = rgb(122, 106, 100),
		OutdoorAmbient = rgb(172, 152, 140),
		Exposure = 0.1,
		Diffuse = 1,
		Specular = 0.7,
		Density = 0.17,
		Offset = 0.25,
		Haze = 1.2,
		Glare = 0.4,
		AtmosphereColor = rgb(236, 212, 190),
		Decay = rgb(142, 112, 112),
		Tint = rgb(255, 242, 228),
		Saturation = 0.16,
		Contrast = 0.1,
		Bloom = 0.4,
		BloomThreshold = 1.4,
		Rays = 0.08,
		Blur = 0,
		Clouds = 0.6,
		CloudColor = rgb(255, 236, 220),
	},
	-- Downtown: dramatic golden hour, long shadows, glowing signs.
	City = {
		ClockTime = 16.9,
		Brightness = 2.7,
		Ambient = rgb(98, 88, 112),
		OutdoorAmbient = rgb(150, 130, 152),
		Exposure = 0.05,
		Diffuse = 1,
		Specular = 1,
		Density = 0.16,
		Offset = 0.3,
		Haze = 1.6,
		Glare = 0.8,
		AtmosphereColor = rgb(240, 192, 170),
		Decay = rgb(112, 82, 112),
		Tint = rgb(255, 238, 222),
		Saturation = 0.1,
		Contrast = 0.15,
		Bloom = 0.7,
		BloomThreshold = 1.1,
		Rays = 0.12,
		Blur = 0.06,
		Clouds = 0.5,
		CloudColor = rgb(255, 200, 175),
	},
	-- Titan City: epic scale — bright sun, cool blue distance haze.
	Titan = {
		ClockTime = 15,
		Brightness = 3.2,
		Ambient = rgb(92, 102, 138),
		OutdoorAmbient = rgb(140, 156, 200),
		Exposure = 0,
		Diffuse = 1,
		Specular = 1,
		Density = 0.15,
		Offset = 0.45,
		Haze = 1.6,
		Glare = 0.6,
		AtmosphereColor = rgb(165, 196, 248),
		Decay = rgb(92, 112, 172),
		Tint = rgb(242, 247, 255),
		Saturation = 0.15,
		Contrast = 0.14,
		Bloom = 0.55,
		BloomThreshold = 1.2,
		Rays = 0.1,
		Blur = 0.1,
		Clouds = 0.7,
		CloudColor = rgb(240, 245, 255),
	},
	-- Titan Wilderness: golden morning — warm low sun, deep blue sky, mist
	-- in the distance. Warm light against cool shadows reads as cinematic.
	Wild = {
		ClockTime = 9.1,
		Brightness = 3,
		Ambient = rgb(98, 102, 130),
		OutdoorAmbient = rgb(150, 158, 190),
		Exposure = 0.05,
		Diffuse = 1,
		Specular = 0.8,
		Density = 0.17,
		Offset = 0.35,
		Haze = 1.8,
		Glare = 0.9,
		AtmosphereColor = rgb(196, 214, 242),
		Decay = rgb(210, 150, 120),
		Tint = rgb(255, 246, 234),
		Saturation = 0.14,
		Contrast = 0.16,
		Bloom = 0.55,
		BloomThreshold = 1.2,
		Rays = 0.16,
		Blur = 0.1,
		Clouds = 0.6,
		CloudColor = rgb(255, 240, 225),
	},
	-- World event: the power goes out.
	Outage = {
		ClockTime = 21,
		Brightness = 0.4,
		Ambient = rgb(28, 30, 48),
		OutdoorAmbient = rgb(44, 46, 70),
		Exposure = -0.2,
		Diffuse = 0.5,
		Specular = 0.5,
		Density = 0.42,
		Offset = 0,
		Haze = 0.5,
		Glare = 0,
		AtmosphereColor = rgb(60, 70, 110),
		Decay = rgb(30, 35, 70),
		Tint = rgb(170, 185, 255),
		Saturation = -0.1,
		Contrast = 0.12,
		Bloom = 0.8,
		BloomThreshold = 0.9,
		Rays = 0,
		Blur = 0,
		Clouds = 0.8,
		CloudColor = rgb(60, 65, 90),
	},
	-- World event: Titan Storm rolls in.
	Storm = {
		ClockTime = 16,
		Brightness = 1.2,
		Ambient = rgb(70, 72, 98),
		OutdoorAmbient = rgb(100, 104, 140),
		Exposure = -0.05,
		Diffuse = 0.8,
		Specular = 1,
		Density = 0.45,
		Offset = 0.1,
		Haze = 2.4,
		Glare = 0,
		AtmosphereColor = rgb(120, 130, 170),
		Decay = rgb(60, 60, 110),
		Tint = rgb(215, 225, 255),
		Saturation = -0.05,
		Contrast = 0.2,
		Bloom = 0.8,
		BloomThreshold = 1,
		Rays = 0,
		Blur = 0.05,
		Clouds = 0.95,
		CloudColor = rgb(80, 85, 110),
	},
}

local basePreset = "Living"
local override: string? = nil
local overrideUntil = 0
local effectivePreset = "High"
local autoLevel = "High"
local frameTimes: { number } = {}
local lowSince: number? = nil
local highSince: number? = nil
local swayParts: { [BasePart]: CFrame } = {}
local discoParts: { BasePart } = {}
type SpinInfo = { Home: CFrame, Speed: number, Parts: { BasePart }, Offsets: { CFrame }, Radius: number }
local spinners: { [PVInstance]: SpinInfo } = {}
local nearbySpin: { PVInstance } = {}
local discoNear = false
local movingParts: { BasePart } = {}
local movingFrames: { CFrame } = {}
local lastSwayRefresh = 0
local nearbySway: { BasePart } = {}

local function lightingChild(className: string, name: string): Instance
	local existing = Lighting:FindFirstChild(name)
	if existing and existing.ClassName == className then
		return existing
	end
	local inst = Instance.new(className)
	inst.Name = name
	inst.Parent = Lighting
	return inst
end

local function clouds(): Clouds
	local existing = workspace.Terrain:FindFirstChildOfClass("Clouds")
	if existing then
		return existing
	end
	local c = Instance.new("Clouds")
	c.Cover = 0.5
	c.Density = 0.6
	c.Parent = workspace.Terrain
	return c
end

local function applyLighting(name: string, duration: number)
	local p = PRESETS[name]
	if not p then
		return
	end
	local info = TweenInfo.new(duration, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut)
	local function tween(target: Instance, goal: { [string]: any })
		if duration <= 0 then
			for k, v in goal do
				(target :: any)[k] = v
			end
		else
			TweenService:Create(target, info, goal):Play()
		end
	end
	tween(Lighting, {
		ClockTime = p.ClockTime,
		Brightness = p.Brightness,
		Ambient = p.Ambient,
		OutdoorAmbient = p.OutdoorAmbient,
		ExposureCompensation = p.Exposure,
		EnvironmentDiffuseScale = p.Diffuse,
		EnvironmentSpecularScale = p.Specular,
	})
	tween(lightingChild("Atmosphere", "Atmosphere"), {
		Density = p.Density,
		Offset = p.Offset,
		Haze = p.Haze,
		Glare = p.Glare,
		Color = p.AtmosphereColor,
		Decay = p.Decay,
	})
	tween(lightingChild("ColorCorrectionEffect", "Grade"), {
		TintColor = p.Tint,
		Saturation = p.Saturation,
		Contrast = p.Contrast,
	})
	tween(lightingChild("BloomEffect", "Bloom"), { Intensity = p.Bloom, Threshold = p.BloomThreshold })
	tween(lightingChild("SunRaysEffect", "SunRays"), { Intensity = p.Rays })
	local dof = lightingChild("DepthOfFieldEffect", "DistanceBlur") :: DepthOfFieldEffect
	dof.NearIntensity = 0
	dof.FocusDistance = 400
	dof.InFocusRadius = 600
	dof.Enabled = (SettingsConfig.Presets[effectivePreset] or SettingsConfig.Presets.High).PostEffects
	tween(dof, { FarIntensity = p.Blur })
	tween(clouds(), { Cover = p.Clouds, Color = p.CloudColor })
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
	UIManager:SetBlurAllowed(preset.PostEffects)
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

local function trackSpin(instance: Instance)
	if instance:IsA("PVInstance") then
		local home = instance:GetPivot()
		local info: SpinInfo = {
			Home = home,
			Speed = (instance:GetAttribute("Speed") :: number?) or 1,
			Parts = {},
			Offsets = {},
			Radius = 0,
		}
		-- Offsets from the pivot, so a frame's spin is one batched move.
		local list: { Instance } = if instance:IsA("BasePart") then { instance } else instance:GetDescendants()
		for _, d in list do
			if d:IsA("BasePart") then
				table.insert(info.Parts, d)
				local offset = home:ToObjectSpace(d.CFrame)
				table.insert(info.Offsets, offset)
				info.Radius = math.max(info.Radius, offset.Position.Magnitude + d.Size.Magnitude * 0.5)
			end
		end
		spinners[instance] = info
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
		table.clear(nearbySpin)
		local camera = workspace.CurrentCamera
		if camera then
			local eye = camera.CFrame.Position
			local h = MovementController:GetHeight()
			-- Sway only what's near and big enough to notice at this size;
			-- how many depends on the graphics preset.
			local swayRange = math.max(h * 12, 150)
			local swayCap = if effectivePreset == "High" then 250 else 100
			local minSize = h * 0.03
			for part in swayParts do
				local d = (part.Position - eye).Magnitude
				-- Too small on screen to notice swaying? Skip it.
				if part.Size.Y >= minSize and d < swayRange and part.Size.Y / math.max(d, 1) > 0.01 then
					table.insert(nearbySway, part)
					if #nearbySway >= swayCap then
						break
					end
				end
			end
			-- Spinning holograms: only the nearest few (each is many parts).
			local spinRange = math.max(h * 30, 150)
			local found: { { Spinner: PVInstance, D: number } } = {}
			for spinner, info in spinners do
				local d = (info.Home.Position - eye).Magnitude
				if d < spinRange and info.Radius / math.max(d, 1) > 0.008 then
					table.insert(found, { Spinner = spinner, D = d })
				end
			end
			table.sort(found, function(a, b)
				return a.D < b.D
			end)
			for i = 1, math.min(#found, 10) do
				table.insert(nearbySpin, found[i].Spinner)
			end
			EnvironmentController.Animated = #nearbySway + #nearbySpin
			discoNear = #discoParts > 0 and (discoParts[1].Position - eye).Magnitude < math.max(h * 40, 1500)
		end
	end
	-- Everything that moves this frame goes into one BulkMoveTo call.
	table.clear(movingParts)
	table.clear(movingFrames)
	for _, spinner in nearbySpin do
		local info = spinners[spinner]
		if info and spinner.Parent then
			local cf = info.Home * CFrame.Angles(0, now * info.Speed, 0)
			for i, part in info.Parts do
				table.insert(movingParts, part)
				table.insert(movingFrames, cf * info.Offsets[i])
			end
		end
	end
	for _, part in nearbySway do
		local home = swayParts[part]
		if home and part.Parent then
			local phase = home.Position.X * 0.05 + home.Position.Z * 0.03
			local angle = math.sin(now * 1.3 + phase) * 0.06
			local pivot = home.Position - home.UpVector * part.Size.Y * 0.5
			table.insert(movingParts, part)
			table.insert(
				movingFrames,
				CFrame.new(pivot) * CFrame.Angles(angle, 0, angle * 0.6) * CFrame.new(-pivot) * home
			)
		end
	end
	if #movingParts > 0 then
		workspace:BulkMoveTo(movingParts, movingFrames, Enum.BulkMoveMode.FireCFrameChanged)
	end
	for i, part in discoParts do
		if discoNear and part.Parent then
			part.Color = Color3.fromHSV((now * 0.2 + i * 0.13) % 1, 0.7, 1)
		end
	end
end

-- Growth Surge: green energy motes drifting through the air around you.
local surgeAnchor: Part? = nil
local surgeConn: RBXScriptConnection? = nil
local function setSurge(on: boolean)
	if on and not surgeAnchor then
		local anchor = Instance.new("Part")
		anchor.Name = "TT_SurgeMotes"
		anchor.Anchored = true
		anchor.CanCollide = false
		anchor.CanQuery = false
		anchor.CanTouch = false
		anchor.Transparency = 1
		anchor.Size = Vector3.new(1, 1, 1)
		anchor.Parent = workspace
		local motes = Instance.new("ParticleEmitter")
		motes.Color = ColorSequence.new(Color3.fromRGB(130, 255, 160), Color3.fromRGB(220, 255, 170))
		motes.LightEmission = 1
		motes.LightInfluence = 0
		motes.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.3, 0.3),
			NumberSequenceKeypoint.new(1, 1),
		})
		motes.Lifetime = NumberRange.new(2.5, 4)
		motes.Rate = if effectivePreset == "Low" then 6 else 18
		motes.SpreadAngle = Vector2.new(180, 180)
		motes.Parent = anchor
		surgeAnchor = anchor
		surgeConn = RunService.RenderStepped:Connect(function()
			local camera = workspace.CurrentCamera
			if camera and surgeAnchor then
				-- Follow the camera; motes sized to the player's scale.
				local h = MovementController:GetHeight()
				surgeAnchor.Size = Vector3.new(h * 12, h * 6, h * 12)
				surgeAnchor.CFrame = CFrame.new(camera.CFrame.Position + camera.CFrame.LookVector * h * 4)
				motes.Size = NumberSequence.new(h * 0.06)
				motes.Speed = NumberRange.new(h * 0.1, h * 0.4)
			end
		end)
	elseif not on and surgeAnchor then
		surgeAnchor:Destroy()
		surgeAnchor = nil
		if surgeConn then
			surgeConn:Disconnect()
			surgeConn = nil
		end
	end
end

function EnvironmentController:Init()
	Net.onSignal("WorldEvent", function(payload)
		if type(payload) ~= "table" then
			return
		end
		if payload.State == "Lighting" and type(payload.Preset) == "string" then
			-- Zone-limited looks (a storm over the titan lands) only apply
			-- to players standing in those zones.
			local zones = payload.Zones
			if type(zones) == "table" and #zones > 0 and not table.find(zones, ZoneController:GetZone()) then
				return
			end
			EnvironmentController:SetOverride(payload.Preset, (payload.Duration :: number?) or 60)
		elseif payload.State == "Start" and payload.Id == "GrowthSurge" then
			setSurge(true)
		elseif payload.State == "End" then
			if payload.Id == "GrowthSurge" then
				setSurge(false)
			end
			if override then
				EnvironmentController:SetOverride(nil)
			end
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
	for _, spinner in CollectionService:GetTagged("Spin") do
		trackSpin(spinner)
	end
	CollectionService:GetInstanceAddedSignal("Spin"):Connect(trackSpin)
	CollectionService:GetInstanceRemovedSignal("Spin"):Connect(function(spinner)
		spinners[spinner :: PVInstance] = nil
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
