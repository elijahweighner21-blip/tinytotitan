--!strict
--[[
	CosmeticsController
	Renders equipped cosmetics for EVERY player from the replicated
	"Cosmetics" attribute (a JSON list the server builds only from owned,
	entitled, slot-limited items — the client never decides ownership).

	  Trail     Trail between two root attachments (+ particles for Sparks,
	            Dots and Leaves styles), width scales with body size
	  Aura      particle emitter / light around the body by Style
	  Footstep  burst at each local footstep
	  Landing   ring/burst on hard landings
	  Dash      streak/bolt when dashing (also for other players' dashes)
	  Growth    replaces the default spiral during tier-ups
	  NameColor read by OverheadController

	Performance caps: other players' effects follow "Hide Other Players'
	Effects", the preset's OtherPlayerEffects limit (closest players win),
	and trails are skipped entirely on the Low preset.
]]

local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CosmeticConfig = require(Shared.Config.CosmeticConfig)
local Types = require(Shared.Types)
local SettingsConfig = require(Shared.Config.SettingsConfig)
local ScaleMath = require(Shared.Formulas.ScaleMath)
local Trove = require(Shared.Util.Trove)

local Client = script.Parent.Parent
local Net = require(Client.Net)
local SettingsController = require(script.Parent.SettingsController)
local MovementController = require(script.Parent.MovementController)
local EffectsController = require(script.Parent.EffectsController)
local EnvironmentController = require(script.Parent.EnvironmentController)

local CosmeticsController = {}

type Rendered = {
	Trove: Trove.Trove,
	Ids: { string },
	Scale: number,
	Active: boolean,
}

local localPlayer = Players.LocalPlayer
local rendered: { [Player]: Rendered } = {}
local lastBudget = 0

local SPARKLE = "rbxasset://textures/particles/sparkles_main.dds"
local SMOKE = "rbxasset://textures/particles/smoke_main.dds"
local FIRE = "rbxasset://textures/particles/fire_main.dds"

local function decode(player: Player): { string }
	local raw = player:GetAttribute("Cosmetics")
	if type(raw) ~= "string" or raw == "" then
		return {}
	end
	local ok, list = pcall(function()
		return HttpService:JSONDecode(raw)
	end)
	if not ok or type(list) ~= "table" then
		return {}
	end
	local out = {}
	for _, id in list do
		if type(id) == "string" and CosmeticConfig.get(id) then
			table.insert(out, id)
		end
	end
	return out
end

function CosmeticsController:GetEquipped(player: Player, category: string): Types.Cosmetic?
	for _, id in decode(player) do
		local def = CosmeticConfig.get(id)
		if def and def.Category == category then
			return def
		end
	end
	return nil
end

local function sequence(colors: { Color3 }): ColorSequence
	if #colors <= 1 then
		return ColorSequence.new(colors[1] or Color3.new(1, 1, 1))
	end
	local points = {}
	for i, c in colors do
		table.insert(points, ColorSequenceKeypoint.new((i - 1) / (#colors - 1), c))
	end
	return ColorSequence.new(points)
end

local function emitter(parent: Instance, def: Types.Cosmetic, h: number, props: { [string]: any }): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	e.Color = sequence(def.Colors)
	e.LightEmission = 0.6
	e.Texture = SPARKLE
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, h * 0.06), NumberSequenceKeypoint.new(1, 0) })
	e.Lifetime = NumberRange.new(0.6, 1.2)
	e.Rate = 12
	e.Speed = NumberRange.new(h * 0.05, h * 0.2)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	for k, v in props do
		(e :: any)[k] = v
	end
	e.Parent = parent
	return e
end

local function buildTrail(root: BasePart, def: Types.Cosmetic, h: number, trove: Trove.Trove)
	local top = trove:Add(Instance.new("Attachment"))
	top.Name = "TT_TrailTop"
	top.Position = Vector3.new(0, h * 0.12, 0)
	top.Parent = root
	local bottom = trove:Add(Instance.new("Attachment"))
	bottom.Name = "TT_TrailBottom"
	bottom.Position = Vector3.new(0, -h * 0.25, 0)
	bottom.Parent = root
	local trail = trove:Add(Instance.new("Trail"))
	trail.Attachment0 = top
	trail.Attachment1 = bottom
	trail.Color = sequence(def.Colors)
	trail.Lifetime = 0.45
	trail.MinLength = h * 0.05
	trail.LightEmission = 0.5
	trail.FaceCamera = true
	trail.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 1) })
	trail.WidthScale = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(1, 0.1) })
	trail.Parent = root
	if def.Style ~= "Ribbon" then
		trail.Transparency =
			NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1) })
		trove:Add(emitter(bottom, def, h, {
			Rate = 18,
			Texture = if def.Style == "Leaves" then SMOKE else SPARKLE,
			Acceleration = if def.Style == "Sparks" then Vector3.new(0, h * 0.4, 0) else Vector3.new(0, -h * 0.2, 0),
			Speed = NumberRange.new(0, h * 0.05),
		}))
	end
end

local function buildAura(root: BasePart, def: Types.Cosmetic, h: number, trove: Trove.Trove)
	local style = def.Style
	local color = def.Colors[1]
	if style == "Glow" or style == "Halo" then
		local light = trove:Add(Instance.new("PointLight"))
		light.Color = color
		light.Range = math.clamp(h * 1.2, 2, 60)
		light.Brightness = 1.2
		light.Parent = root
	end
	if style == "Halo" then
		local att = trove:Add(Instance.new("Attachment"))
		att.Position = Vector3.new(0, h * 0.6, 0)
		att.Parent = root
		trove:Add(emitter(att, def, h, {
			Shape = Enum.ParticleEmitterShape.Disc,
			ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
			ShapeInOut = Enum.ParticleEmitterShapeInOut.Outward,
			Speed = NumberRange.new(0),
			Rate = 30,
			Lifetime = NumberRange.new(0.5, 0.7),
		}))
	elseif style == "Flame" then
		trove:Add(emitter(root, def, h, {
			Texture = FIRE,
			Rate = 25,
			Acceleration = Vector3.new(0, h * 0.6, 0),
			Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, h * 0.18), NumberSequenceKeypoint.new(1, 0) }),
			Speed = NumberRange.new(0, h * 0.05),
		}))
	elseif style == "Mist" then
		trove:Add(emitter(root, def, h, {
			Texture = SMOKE,
			Rate = 10,
			LightEmission = 0.2,
			Size = NumberSequence.new({
				NumberSequenceKeypoint.new(0, h * 0.25),
				NumberSequenceKeypoint.new(1, h * 0.4),
			}),
			Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(1, 1) }),
		}))
	elseif style == "Snow" then
		local att = trove:Add(Instance.new("Attachment"))
		att.Position = Vector3.new(0, h * 0.8, 0)
		att.Parent = root
		trove:Add(
			emitter(
				att,
				def,
				h,
				{ Rate = 20, Acceleration = Vector3.new(0, -h * 0.3, 0), Lifetime = NumberRange.new(1.5, 2) }
			)
		)
	elseif style == "Orbit" then
		local att = trove:Add(Instance.new("Attachment"))
		att.Parent = root
		trove:Add(emitter(att, def, h, {
			Texture = SMOKE,
			Rate = 14,
			RotSpeed = NumberRange.new(-90, 90),
			Shape = Enum.ParticleEmitterShape.Cylinder,
			ShapeStyle = Enum.ParticleEmitterShapeStyle.Surface,
		}))
	else
		trove:Add(emitter(root, def, h, { Rate = 16 }))
	end
end

local function clear(player: Player)
	local r = rendered[player]
	if r then
		r.Trove:Destroy()
		rendered[player] = nil
	end
end

local function preset(): SettingsConfig.Preset
	return SettingsConfig.Presets[EnvironmentController:GetPreset()] or SettingsConfig.Presets.High
end

local function render(player: Player)
	clear(player)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return
	end
	local scale = (player:GetAttribute("Scale") :: number?) or 1
	local h = ScaleMath.height(scale)
	local trove = Trove.new()
	local ids = decode(player)
	local p = preset()
	for _, id in ids do
		local def = CosmeticConfig.get(id)
		if def then
			if def.Category == "Trail" and p.Trails then
				buildTrail(root, def, h, trove)
			elseif def.Category == "Aura" then
				buildAura(root, def, h, trove)
			end
		end
	end
	rendered[player] = { Trove = trove, Ids = ids, Scale = scale, Active = true }
end

-- Decides which other players get effects (closest N, or none).
local function budget()
	local p = preset()
	local hideOthers = SettingsController:Get("HideOtherEffects") == true
	local camera = workspace.CurrentCamera
	local others: { { player: Player, d: number } } = {}
	for _, player in Players:GetPlayers() do
		if player ~= localPlayer then
			local character = player.Character
			local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if root and camera then
				table.insert(others, { player = player, d = (root.Position - camera.CFrame.Position).Magnitude })
			end
		end
	end
	table.sort(others, function(a, b)
		return a.d < b.d
	end)
	local allowed: { [Player]: boolean } = { [localPlayer] = true }
	if not hideOthers then
		for i = 1, math.min(#others, p.OtherPlayerEffects) do
			allowed[others[i].player] = true
		end
	end
	for _, player in Players:GetPlayers() do
		local r = rendered[player]
		if allowed[player] then
			local scale = (player:GetAttribute("Scale") :: number?) or 1
			-- Re-render when missing or after a big size change.
			if not r or math.abs(scale / r.Scale - 1) > 0.15 then
				render(player)
			end
		elseif r then
			clear(player)
		end
	end
end

local function watch(player: Player)
	player:GetAttributeChangedSignal("Cosmetics"):Connect(function()
		if rendered[player] then
			render(player)
		end
	end)
	player.CharacterAdded:Connect(function()
		clear(player)
		task.defer(budget)
	end)
end

------------------------------------------------------------------ one-shot local effects

local function equipped(category: string): Types.Cosmetic?
	return CosmeticsController:GetEquipped(localPlayer, category)
end

function CosmeticsController:PlayGrowth(position: Vector3, h: number): boolean
	local def = equipped("Growth")
	if not def then
		return false
	end
	if def.Style == "Spiral" then
		EffectsController:Spiral(position, def.Colors[1], h * 2, 1.4)
	else
		EffectsController:Burst(position, def.Colors[1], h * 0.8, 40)
		EffectsController:Ring(position, def.Colors[#def.Colors], h * 5, 0.9)
	end
	return true
end

local function dashFx(def: Types.Cosmetic, position: Vector3, h: number)
	if def.Style == "Bolt" then
		EffectsController:Burst(position, def.Colors[1], h * 0.3, 16)
		EffectsController:Ring(position, def.Colors[#def.Colors], h * 1.2, 0.25)
	else
		EffectsController:Burst(position, def.Colors[1], h * 0.25, 10, true)
	end
end

function CosmeticsController:Init()
	MovementController.Footstep:Connect(function(position, scale)
		local def = equipped("Footstep")
		if def then
			local h = ScaleMath.height(scale)
			if def.Style == "Crack" then
				EffectsController:Ring(position, def.Colors[1], h * 0.35, 0.3)
			else
				EffectsController:Burst(position, def.Colors[1], h * 0.12, if def.Style == "Bloom" then 6 else 4)
			end
		end
	end)
	MovementController.Landed:Connect(function(fall, hard)
		local def = equipped("Landing")
		local root = MovementController:GetRoot()
		if def and root and (hard or fall > MovementController:GetHeight() * 2) then
			local h = MovementController:GetHeight()
			local feet = root.Position - Vector3.new(0, h * 0.5, 0)
			if def.Style == "Ring" then
				EffectsController:Ring(feet, def.Colors[1], h * 1.5, 0.4)
			else
				EffectsController:Burst(feet, def.Colors[1], h * 0.4, 20)
				EffectsController:Ring(feet, def.Colors[#def.Colors], h * 2, 0.45)
			end
		end
	end)
	MovementController.AbilityUsed:Connect(function(id)
		if id == "AirDash" or id == "GroundDash" then
			local def = equipped("Dash")
			local root = MovementController:GetRoot()
			if def and root then
				dashFx(def, root.Position, MovementController:GetHeight())
			end
		end
	end)
	Net.onFx("Ability", function(payload)
		if type(payload) ~= "table" or payload.U == localPlayer.UserId then
			return
		end
		if (payload.Id == "AirDash" or payload.Id == "GroundDash") and typeof(payload.P) == "Vector3" then
			local other = Players:GetPlayerByUserId(payload.U)
			if other and rendered[other] then
				local def = CosmeticsController:GetEquipped(other, "Dash")
				if def then
					dashFx(def, payload.P, ScaleMath.height((payload.S :: number?) or 1))
				end
			end
		end
	end)
	EnvironmentController.PresetChanged:Connect(function()
		for player in rendered do
			render(player)
		end
	end)
	SettingsController.Changed:Connect(function(key)
		if key == "HideOtherEffects" then
			budget()
		end
	end)
end

function CosmeticsController:Start()
	for _, player in Players:GetPlayers() do
		watch(player)
	end
	Players.PlayerAdded:Connect(watch)
	Players.PlayerRemoving:Connect(clear)
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		if now - lastBudget > 1.5 then
			lastBudget = now
			budget()
		end
	end)
end

return CosmeticsController
