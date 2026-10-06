--!strict
--[[
	EffectsController
	Client-side visual effects. The server confirms gameplay and broadcasts a
	compact Fx message; every client renders it locally, scaled to the size
	involved — so a titan stomp is huge and an ant's jump is a tiny puff.

	Performance:
	  * particle bursts and floating text are pooled
	  * counts scale with the Particles setting and the graphics preset
	  * effects from other players respect "Hide Other Players' Effects" and
	    are culled by distance relative to their size
	  * every temporary instance is cleaned up on a timer
]]

local Players = game:GetService("Players")
local TweenService = game:GetService("TweenService")
local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ScaleMath = require(Shared.Formulas.ScaleMath)
local SettingsConfig = require(Shared.Config.SettingsConfig)

local Client = script.Parent.Parent
local Net = require(Client.Net)
local UIManager = require(Client.UI.UIManager)
local SettingsController = require(script.Parent.SettingsController)
local MovementController = require(script.Parent.MovementController)
local CameraController = require(script.Parent.CameraController)
local AudioController = require(script.Parent.AudioController)
local DataController = require(script.Parent.DataController)

local EffectsController = {}

local player = Players.LocalPlayer
local folder: Folder
local burstPool: { Part } = {}
local textPool: { BillboardGui } = {}
local preset = SettingsConfig.Presets.High

local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"

function EffectsController:SetPreset(name: string)
	preset = SettingsConfig.Presets[name] or SettingsConfig.Presets.High
end

local function particleFactor(): number
	return (SettingsController:Get("Particles") or 1) * preset.Particles
end

local function newBurstPart(): Part
	local part = Instance.new("Part")
	part.Name = "Burst"
	part.Anchored = true
	part.CanCollide = false
	part.CanQuery = false
	part.CanTouch = false
	part.Transparency = 1
	part.Size = Vector3.one
	local emitter = Instance.new("ParticleEmitter")
	emitter.Name = "Emitter"
	emitter.Enabled = false
	emitter.Texture = SPARKLE
	emitter.LightEmission = 0.7
	emitter.Rate = 0
	emitter.SpreadAngle = Vector2.new(180, 180)
	emitter.Parent = part
	return part
end

-- One-shot particle burst at a position.
function EffectsController:Burst(position: Vector3, color: Color3, size: number, count: number, smoke: boolean?)
	local n = math.floor(math.min(count * particleFactor(), preset.MaxParticlesPerEmit))
	if n <= 0 then
		return
	end
	local part = table.remove(burstPool) or newBurstPart()
	part.Position = position
	part.Parent = folder
	local emitter = part:FindFirstChild("Emitter") :: ParticleEmitter
	emitter.Texture = if smoke then SMOKE else SPARKLE
	emitter.Color = ColorSequence.new(color)
	emitter.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, size * 0.6), NumberSequenceKeypoint.new(1, 0) })
	emitter.Speed = NumberRange.new(size * 2, size * 6)
	emitter.Lifetime = NumberRange.new(0.4, 0.9)
	emitter.Drag = 3
	emitter.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.1), NumberSequenceKeypoint.new(1, 1) })
	emitter:Emit(n)
	task.delay(1.2, function()
		part.Parent = nil
		table.insert(burstPool, part)
	end)
end

-- Expanding flat ring (landings, stomps, shockwaves).
function EffectsController:Ring(position: Vector3, color: Color3, radius: number, duration: number?)
	if particleFactor() <= 0.05 then
		return
	end
	local ring = Instance.new("Part")
	ring.Shape = Enum.PartType.Cylinder
	ring.Anchored = true
	ring.CanCollide = false
	ring.CanQuery = false
	ring.CanTouch = false
	ring.Material = Enum.Material.Neon
	ring.Color = color
	ring.Transparency = 0.35
	ring.Size = Vector3.new(math.max(0.05, radius * 0.04), radius * 0.2, radius * 0.2)
	ring.CFrame = CFrame.new(position) * CFrame.Angles(0, 0, math.rad(90))
	ring.Parent = folder
	local t = duration or 0.45
	TweenService:Create(ring, TweenInfo.new(t, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Size = Vector3.new(math.max(0.05, radius * 0.02), radius * 2, radius * 2),
		Transparency = 1,
	}):Play()
	Debris:AddItem(ring, t + 0.1)
end

-- Rising spiral of light (growth / ascension / level up).
function EffectsController:Spiral(position: Vector3, color: Color3, height: number, duration: number)
	local count = math.floor(10 * particleFactor())
	for i = 1, count do
		local orb = Instance.new("Part")
		orb.Shape = Enum.PartType.Ball
		orb.Anchored = true
		orb.CanCollide = false
		orb.CanQuery = false
		orb.CanTouch = false
		orb.Material = Enum.Material.Neon
		orb.Color = color
		local s = height * 0.06
		orb.Size = Vector3.new(s, s, s)
		local a0 = i / count * math.pi * 2
		local r = height * 0.45
		orb.Position = position + Vector3.new(math.cos(a0) * r, 0, math.sin(a0) * r)
		orb.Parent = folder
		local steps = 10
		task.spawn(function()
			for step = 1, steps do
				if not orb.Parent then
					return
				end
				local t = step / steps
				local a = a0 + t * math.pi * 2
				local goal = position + Vector3.new(math.cos(a) * r * (1 - t * 0.6), height * t, math.sin(a) * r * (1 - t * 0.6))
				TweenService:Create(orb, TweenInfo.new(duration / steps, Enum.EasingStyle.Linear), { Position = goal, Transparency = t * 0.8 }):Play()
				task.wait(duration / steps)
			end
			orb:Destroy()
		end)
	end
end

local function getText(): BillboardGui
	local gui = table.remove(textPool)
	if gui then
		return gui
	end
	local billboard = Instance.new("BillboardGui")
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.Size = UDim2.fromOffset(200, 50)
	local label = Instance.new("TextLabel")
	label.Name = "Text"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromScale(1, 1)
	label.FontFace = Font.new("rbxasset://fonts/families/GothamSSm.json", Enum.FontWeight.Heavy)
	label.TextScaled = true
	label.TextStrokeTransparency = 0.3
	label.Parent = billboard
	return billboard
end

-- Floating text (damage numbers, +Mass popups) that rises and fades.
function EffectsController:FloatText(position: Vector3, text: string, color: Color3, worldSize: number?)
	local gui = getText()
	local label = gui:FindFirstChild("Text") :: TextLabel
	label.Text = text
	label.TextColor3 = color
	label.TextTransparency = 0
	label.TextStrokeTransparency = 0.3
	local size = worldSize or 2
	gui.Size = UDim2.new(size * 4, 0, size, 0)
	local attachment = Instance.new("Attachment")
	attachment.WorldPosition = position
	attachment.Parent = workspace.Terrain
	gui.Adornee = attachment
	gui.Parent = folder
	local rise = TweenService:Create(attachment, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { WorldPosition = position + Vector3.new(0, size * 2, 0) })
	rise:Play()
	TweenService:Create(label, TweenInfo.new(0.9, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { TextTransparency = 1, TextStrokeTransparency = 1 }):Play()
	task.delay(0.95, function()
		attachment:Destroy()
		gui.Parent = nil
		gui.Adornee = nil :: any
		table.insert(textPool, gui)
	end)
end

function EffectsController:Flash(color: Color3, strength: number?)
	if not SettingsController:Get("ScreenFlashes") then
		return
	end
	local frame = Instance.new("Frame")
	frame.BackgroundColor3 = color
	frame.BackgroundTransparency = 1 - (strength or 0.35)
	frame.Size = UDim2.fromScale(1, 1)
	frame.ZIndex = 40
	frame.Parent = UIManager.Overlay
	TweenService:Create(frame, TweenInfo.new(0.5), { BackgroundTransparency = 1 }):Play()
	Debris:AddItem(frame, 0.6)
end

------------------------------------------------------------------ telegraphs

local function flatPart(color: Color3, transparency: number): Part
	local p = Instance.new("Part")
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Material = Enum.Material.Neon
	p.Color = color
	p.Transparency = transparency
	p.CastShadow = false
	p.Parent = folder
	return p
end

function EffectsController:Telegraph(payload: { [string]: any })
	local kind = payload.K or "Circle"
	local position = payload.P :: Vector3
	local radius = (payload.R :: number?) or 4
	local duration = (payload.T :: number?) or 1
	if typeof(position) ~= "Vector3" then
		return
	end
	local warn = Color3.fromRGB(255, 60, 60)
	local thickness = math.max(0.05, radius * 0.02)
	local parts: { Part } = {}
	if kind == "Circle" or kind == "Ring" or kind == "Cone" then
		local outline = flatPart(warn, 0.55)
		outline.Shape = Enum.PartType.Cylinder
		outline.Size = Vector3.new(thickness, radius * 2, radius * 2)
		outline.CFrame = CFrame.new(position + Vector3.new(0, thickness, 0)) * CFrame.Angles(0, 0, math.rad(90))
		table.insert(parts, outline)
		local fill = flatPart(warn, 0.35)
		fill.Shape = Enum.PartType.Cylinder
		fill.Size = Vector3.new(thickness * 1.5, 0.1, 0.1)
		fill.CFrame = outline.CFrame
		table.insert(parts, fill)
		TweenService:Create(fill, TweenInfo.new(duration, Enum.EasingStyle.Linear), { Size = Vector3.new(thickness * 1.5, radius * 2, radius * 2) }):Play()
		if kind == "Cone" and typeof(payload.D) == "Vector3" then
			local dir = (payload.D :: Vector3)
			local arrow = flatPart(Color3.fromRGB(255, 200, 60), 0.3)
			arrow.Size = Vector3.new(radius * 0.15, thickness * 2, radius)
			arrow.CFrame = CFrame.lookAt(position + dir * radius * 0.5, position + dir * radius) + Vector3.new(0, thickness * 2, 0)
			table.insert(parts, arrow)
		end
	elseif kind == "Lane" and typeof(payload.D) == "Vector3" then
		local dir = payload.D :: Vector3
		local length = (payload.L :: number?) or radius * 6
		local lane = flatPart(warn, 0.5)
		lane.Size = Vector3.new(radius * 2, thickness, length)
		lane.CFrame = CFrame.lookAt(position + dir * length * 0.5, position + dir * length) - Vector3.new(0, position.Y - position.Y, 0)
		table.insert(parts, lane)
	end
	AudioController:Play("Telegraph", { Position = position })
	task.delay(duration + 0.05, function()
		for _, p in parts do
			p:Destroy()
		end
		if kind == "Ring" then
			EffectsController:Ring(position, warn, radius, 0.35)
		end
	end)
end

------------------------------------------------------------------ handlers

local function fromOther(payload: { [string]: any }): boolean
	return type(payload.U) == "number" and payload.U ~= player.UserId
end

local function shouldRender(payload: { [string]: any }, position: Vector3?, size: number?): boolean
	if fromOther(payload) and SettingsController:Get("HideOtherEffects") then
		return false
	end
	local camera = workspace.CurrentCamera
	if not position or not camera then
		return true
	end
	local myScale = DataController:GetScale()
	local range = math.max(ScaleMath.height(myScale), size or 0) * 120 + 200
	return (camera.CFrame.Position - position).Magnitude < range
end

local function abilityFx(payload: { [string]: any })
	local position = payload.P
	local scale = (payload.S :: number?) or 1
	if typeof(position) ~= "Vector3" or not shouldRender(payload, position, ScaleMath.height(scale)) then
		return
	end
	local h = ScaleMath.height(scale)
	local id = payload.Id
	local feet = position - Vector3.new(0, h * 0.5, 0)
	if id == "TitanStomp" or id == "EarthquakeLanding" or id == "GroundPound" then
		local radius = h * (if id == "TitanStomp" then 4.5 elseif id == "GroundPound" then 2.8 else 6)
		EffectsController:Ring(feet, Color3.fromRGB(255, 200, 120), radius, 0.5)
		EffectsController:Burst(feet, Color3.fromRGB(200, 180, 150), h * 0.5, 30, true)
		CameraController:ShakeAt(feet, if id == "GroundPound" then 0.35 else 0.7, radius * 3)
		AudioController:Play(if id == "GroundPound" then "GroundPound" else "Stomp", { Position = feet })
	elseif id == "Shockwave" then
		EffectsController:Ring(feet, Color3.fromRGB(120, 200, 255), h * 9, 0.7)
		CameraController:ShakeAt(feet, 0.6, h * 30)
		AudioController:Play("Shockwave", { Position = feet })
	elseif id == "TitanRoar" then
		EffectsController:Ring(position, Color3.fromRGB(255, 120, 80), h * 10, 0.9)
		CameraController:ShakeAt(position, 0.5, h * 40)
		AudioController:Play("Roar", { Position = position })
	elseif id == "Scan" then
		EffectsController:Ring(feet, Color3.fromRGB(120, 255, 200), h * 40, 1.2)
		AudioController:Play("Scan", { Position = position })
	elseif id == "Overgrowth" then
		EffectsController:Spiral(feet, Color3.fromRGB(120, 255, 140), h * 1.5, 0.8)
	elseif fromOther(payload) then
		-- Other players' movement abilities: a small puff so motion reads.
		EffectsController:Burst(position, Color3.fromRGB(230, 240, 255), h * 0.3, 8)
	end
end

function EffectsController:Init()
	folder = Instance.new("Folder")
	folder.Name = "TT_Effects"
	folder.Parent = workspace
	SettingsController.Changed:Connect(function(key, value)
		if key == "PerformancePreset" and value ~= "Auto" then
			EffectsController:SetPreset(value)
		end
	end)
	Net.onFx("Hit", function(p)
		if typeof(p.P) == "Vector3" and SettingsController:Get("DamageNumbers") then
			local h = MovementController:GetHeight()
			EffectsController:FloatText(p.P, tostring(p.A) .. (if p.C then "!" else ""), if p.C then Color3.fromRGB(255, 220, 80) else Color3.fromRGB(255, 255, 255), h * (if p.C then 0.6 else 0.45))
			EffectsController:Burst(p.P, Color3.fromRGB(255, 240, 200), h * 0.2, 6)
			AudioController:Play(if p.C then "HeavyHit" else "Hit", { Position = p.P })
		end
	end)
	Net.onFx("Ability", abilityFx)
	Net.onFx("EnemyDeath", function(p)
		if typeof(p.P) == "Vector3" and shouldRender(p, p.P) then
			local h = ScaleMath.height((p.S :: number?) or 1)
			EffectsController:Burst(p.P, if typeof(p.C) == "Color3" then p.C else Color3.new(1, 1, 1), h * 0.5, 16, true)
			AudioController:Play("EnemyDeath", { Position = p.P })
		end
	end)
	Net.onFx("Telegraph", function(p)
		EffectsController:Telegraph(p)
	end)
	Net.onFx("BossImpact", function(p)
		if typeof(p.P) == "Vector3" then
			EffectsController:Ring(p.P, Color3.fromRGB(255, 120, 80), (p.R :: number?) or 10, 0.4)
			EffectsController:Burst(p.P, Color3.fromRGB(200, 170, 140), ((p.R :: number?) or 10) * 0.3, 20, true)
			CameraController:ShakeAt(p.P, 0.45, ((p.R :: number?) or 10) * 6)
			AudioController:Play("HeavyHit", { Position = p.P })
		end
	end)
	Net.onFx("BossShockwave", function(p)
		if typeof(p.P) == "Vector3" then
			EffectsController:Ring(p.P, Color3.fromRGB(255, 80, 80), (p.R :: number?) or 10, 0.5)
			CameraController:ShakeAt(p.P, 0.5, ((p.R :: number?) or 10) * 4)
		end
	end)
	Net.onFx("BossIntro", function(p)
		if typeof(p.P) == "Vector3" then
			CameraController:ShakeAt(p.P, 0.6, ScaleMath.height((p.S :: number?) or 1) * 40)
			AudioController:Play("BossRoar", { Position = p.P })
			AudioController:SetBossMusic(true)
		end
	end)
	Net.onFx("BossDefeat", function(p)
		if typeof(p.P) == "Vector3" then
			local h = ScaleMath.height((p.S :: number?) or 1)
			EffectsController:Burst(p.P, Color3.fromRGB(255, 220, 120), h, 40)
			EffectsController:Ring(p.P, Color3.fromRGB(255, 220, 120), h * 4, 1)
			EffectsController:Flash(Color3.fromRGB(255, 240, 200), 0.3)
			AudioController:SetBossMusic(false)
		end
	end)
	Net.onFx("ObjectHit", function(p)
		if typeof(p.P) == "Vector3" then
			EffectsController:Burst(p.P, Color3.fromRGB(230, 220, 200), ((p.S :: number?) or 2) * 0.15, 6, true)
			AudioController:Play("Hit", { Position = p.P, Pitch = 0.8 })
		end
	end)
	Net.onFx("ObjectBreak", function(p)
		if typeof(p.P) == "Vector3" then
			EffectsController:Burst(p.P, if typeof(p.C) == "Color3" then p.C else Color3.new(1, 1, 1), ((p.S :: number?) or 2) * 0.25, 18, true)
			AudioController:Play("Break", { Position = p.P })
		end
	end)
	Net.onFx("Push", function(p)
		if typeof(p.P) == "Vector3" then
			AudioController:Play("Push", { Position = p.P })
		end
	end)
	Net.onFx("Splash", function(p)
		if typeof(p.P) == "Vector3" then
			EffectsController:Burst(p.P, Color3.fromRGB(120, 190, 255), MovementController:GetHeight() * 0.3, 12)
			AudioController:Play("Splash", { Position = p.P })
		end
	end)
	Net.onFx("Lightning", function(p)
		if typeof(p.P) == "Vector3" then
			local h = (p.S :: number?) or 10
			local bolt = flatPart(Color3.fromRGB(255, 250, 200), 0.1)
			bolt.Size = Vector3.new(h * 0.2, h * 20, h * 0.2)
			bolt.Position = p.P + Vector3.new(0, h * 10, 0)
			Debris:AddItem(bolt, 0.25)
			EffectsController:Flash(Color3.fromRGB(255, 255, 230), 0.2)
			CameraController:ShakeAt(p.P, 0.4, h * 20)
		end
	end)
	Net.onFx("Meteor", function(p)
		if typeof(p.P) == "Vector3" then
			local h = (p.S :: number?) or 10
			local t = (p.T :: number?) or 6
			local rock = flatPart(Color3.fromRGB(120, 200, 255), 0)
			rock.Shape = Enum.PartType.Ball
			rock.Size = Vector3.new(h, h, h)
			rock.Position = p.P + Vector3.new(h * 30, h * 120, 0)
			TweenService:Create(rock, TweenInfo.new(t, Enum.EasingStyle.Quad, Enum.EasingDirection.In), { Position = p.P }):Play()
			Debris:AddItem(rock, t + 0.1)
		end
	end)
end

return EffectsController
