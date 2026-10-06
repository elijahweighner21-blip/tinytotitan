--!strict
--[[
	ScaleService
	Applies the player's size to their character.

	  * Gameplay scale = natural scale from Mass, modified by Shrink Mode
	    (cap at a smaller tier's scale) and Overgrowth (×1.3), clamped to the
	    safe physics range GameConfig.MinScale..MaxScale.
	  * Published as the "Scale" player attribute — the single value every
	    system (movement, combat, interaction, anti-exploit) reads.
	  * Continuous growth is applied in small throttled steps (no replication
	    spam); tier-ups play a short smooth growth sequence instead.
	  * Feet stay planted: after Model:ScaleTo the character is lifted by the
	    change in root-to-feet height so it never sinks into the floor.
	  * After growing, a bounds check detects characters wedged inside
	    geometry (e.g. Shrink Mode expiring inside a vent) and fires
	    `GrewIntoGeometry` so CharacterService can rescue them.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Progression = require(Shared.Formulas.Progression)
local SizeConfig = require(Shared.Config.SizeConfig)
local GameConfig = require(Shared.Config.GameConfig)
local MathUtil = require(Shared.Util.MathUtil)
local Signal = require(Shared.Util.Signal)

local PlayerDataService = require(script.Parent.PlayerDataService)
local CurrencyService = require(script.Parent.CurrencyService)
local ProgressionService = require(script.Parent.ProgressionService)
local StatService = require(script.Parent.StatService)

local ScaleService = {}

ScaleService.GrewIntoGeometry = Signal.new() :: Signal.Signal<Player>
-- (player, newScale)
ScaleService.ScaleChanged = Signal.new() :: Signal.Signal<Player, number>

type Modifier = { Scale: number?, Multiplier: number?, Fixed: number?, Expires: number }
type State = {
	LastApply: number,
	Sequence: boolean,
	Pending: boolean,
	Modifiers: { [string]: Modifier },
}

local states: { [Player]: State } = {}

local function getState(player: Player): State
	local s = states[player]
	if not s then
		s = { LastApply = 0, Sequence = false, Pending = false, Modifiers = {} }
		states[player] = s
	end
	return s
end

function ScaleService:GetNaturalScale(player: Player): number
	local data = PlayerDataService:Get(player)
	if not data then
		return GameConfig.MinScale
	end
	return Progression.scaleForMass(data.Currencies.Mass)
end

function ScaleService:GetTargetScale(player: Player): number
	local scale = ScaleService:GetNaturalScale(player)
	local s = getState(player)
	local now = os.clock()
	for _, mod in s.Modifiers do
		if mod.Expires > now then
			if mod.Scale then
				scale = math.min(scale, mod.Scale)
			end
		end
	end
	for _, mod in s.Modifiers do
		if mod.Expires > now and mod.Multiplier then
			scale *= mod.Multiplier
		end
	end
	-- Fixed overrides everything (e.g. the human-scale VIP Lounge).
	for _, mod in s.Modifiers do
		if mod.Expires > now and mod.Fixed then
			scale = mod.Fixed
		end
	end
	return math.clamp(scale, GameConfig.MinScale, GameConfig.MaxScale)
end

function ScaleService:GetScale(player: Player): number
	return (player:GetAttribute("Scale") :: number?) or ScaleService:GetTargetScale(player)
end

local function overlapsWorld(character: Model): boolean
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not root then
		return false
	end
	local cf, size = character:GetBoundingBox()
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { character }
	params.RespectCanCollide = true
	-- Shrink the probe box so merely standing on the floor is not "stuck".
	local probe = size * Vector3.new(0.6, 0.55, 0.6)
	local parts = workspace:GetPartBoundsInBox(cf + Vector3.new(0, size.Y * 0.1, 0), probe, params)
	for _, part in parts do
		if part.Anchored and part.CanCollide and part.Transparency < 1 then
			return true
		end
	end
	return false
end

-- Scales a character keeping its feet on the ground.
local function applyToCharacter(character: Model, scale: number): boolean
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	local root = character:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not humanoid or not root or humanoid.Health <= 0 then
		return false
	end
	local current = character:GetScale()
	if math.abs(scale / current - 1) < 0.002 then
		return false
	end
	local feetBefore = humanoid.HipHeight + root.Size.Y / 2
	local rootCF = root.CFrame
	local ok, err = pcall(function()
		character:ScaleTo(scale)
	end)
	if not ok then
		warn("[ScaleService] ScaleTo failed:", err)
		return false
	end
	local feetAfter = feetBefore * (scale / current)
	character:PivotTo(rootCF + Vector3.new(0, feetAfter - feetBefore, 0))
	return true
end

-- Applies the current target scale to the character now (no throttle).
function ScaleService:ApplyNow(player: Player)
	local target = ScaleService:GetTargetScale(player)
	player:SetAttribute("Scale", target)
	local character = player.Character
	if character then
		applyToCharacter(character, target)
	end
	getState(player).LastApply = os.clock()
	StatService:Invalidate(player)
	ScaleService.ScaleChanged:Fire(player, target)
end

-- Throttled refresh for continuous growth.
function ScaleService:Refresh(player: Player)
	local s = getState(player)
	if s.Sequence then
		s.Pending = true
		return
	end
	local target = ScaleService:GetTargetScale(player)
	local previous = (player:GetAttribute("Scale") :: number?) or target
	player:SetAttribute("Scale", target)
	if math.abs(target / previous - 1) > 1e-4 then
		StatService:Invalidate(player)
		ScaleService.ScaleChanged:Fire(player, target)
	end
	local character = player.Character
	if not character then
		return
	end
	local applied = character:GetScale()
	local drift = math.abs(target / applied - 1)
	if drift < SizeConfig.ScaleApplyThreshold then
		return
	end
	-- Large jumps (tier changes, admin edits) always animate. This also makes
	-- the result independent of which Mass listener runs first.
	if drift > 0.12 then
		task.spawn(function()
			(ScaleService :: any):PlaySequence(player, nil)
		end)
		return
	end
	local wait = SizeConfig.ScaleApplyMinInterval - (os.clock() - s.LastApply)
	if wait > 0 then
		if not s.Pending then
			s.Pending = true
			task.delay(wait, function()
				s.Pending = false
				if player.Parent then
					(ScaleService :: any):Refresh(player)
				end
			end)
		end
		return
	end
	s.LastApply = os.clock()
	local grew = target > applied
	if applyToCharacter(character, target) and grew and overlapsWorld(character) then
		ScaleService.GrewIntoGeometry:Fire(player)
	end
end

-- Smooth tween between two scales (tier-ups, shrink/overgrowth toggles).
function ScaleService:PlaySequence(player: Player, duration: number?)
	local s = getState(player)
	if s.Sequence then
		return
	end
	local character = player.Character
	if not character then
		ScaleService:ApplyNow(player)
		return
	end
	s.Sequence = true
	local from = character:GetScale()
	local to = ScaleService:GetTargetScale(player)
	player:SetAttribute("Scale", to)
	StatService:Invalidate(player)
	ScaleService.ScaleChanged:Fire(player, to)
	local total = duration or SizeConfig.GrowthSequenceDuration
	local steps = SizeConfig.GrowthSequenceSteps
	-- Brief pause so the client can start its camera pull-back + glow first.
	task.wait(math.min(0.5, total * 0.25))
	for i = 1, steps do
		if not character.Parent or player.Character ~= character then
			break
		end
		local t = MathUtil.easeInOutQuad(i / steps)
		applyToCharacter(character, MathUtil.logLerp(from, to, t))
		task.wait(total * 0.75 / steps)
	end
	s.Sequence = false
	s.LastApply = os.clock()
	if character.Parent and to > from and overlapsWorld(character) then
		ScaleService.GrewIntoGeometry:Fire(player)
	end
	if s.Pending then
		s.Pending = false;
		-- (cast: Refresh and PlaySequence are mutually recursive)
		(ScaleService :: any):Refresh(player)
	end
end

-- Temporary size modifiers (Shrink Mode, Overgrowth).
function ScaleService:SetModifier(
	player: Player,
	id: string,
	modifier: { Scale: number?, Multiplier: number?, Fixed: number? },
	duration: number
)
	local s = getState(player)
	s.Modifiers[id] = {
		Scale = modifier.Scale,
		Multiplier = modifier.Multiplier,
		Fixed = modifier.Fixed,
		Expires = os.clock() + duration,
	}
	player:SetAttribute(id, true)
	task.spawn(function()
		ScaleService:PlaySequence(player, 0.9)
	end)
	task.delay(duration, function()
		local current = s.Modifiers[id]
		if current and current.Expires <= os.clock() + 0.05 then
			ScaleService:ClearModifier(player, id)
		end
	end)
end

function ScaleService:ClearModifier(player: Player, id: string)
	local s = getState(player)
	if not s.Modifiers[id] then
		return
	end
	s.Modifiers[id] = nil
	if player.Parent then
		player:SetAttribute(id, nil)
		task.spawn(function()
			ScaleService:PlaySequence(player, 0.9)
		end)
	end
end

function ScaleService:HasModifier(player: Player, id: string): boolean
	local mod = getState(player).Modifiers[id]
	return mod ~= nil and mod.Expires > os.clock()
end

function ScaleService:ModifierRemaining(player: Player, id: string): number
	local mod = getState(player).Modifiers[id]
	return if mod then math.max(0, mod.Expires - os.clock()) else 0
end

function ScaleService:Start()
	CurrencyService.Changed:Connect(function(player, currency)
		if currency == "Mass" then
			ScaleService:Refresh(player)
		end
	end)
	ProgressionService.TierChanged:Connect(function(player, newTier, oldTier)
		task.spawn(function()
			ScaleService:PlaySequence(player, if newTier > oldTier then nil else 1.2)
		end)
	end)
	PlayerDataService.Loaded:Connect(function(player)
		player:SetAttribute("Scale", ScaleService:GetTargetScale(player))
	end)
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
	end)
end

return ScaleService
