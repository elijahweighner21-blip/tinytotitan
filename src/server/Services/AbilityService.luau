--!strict
--[[
	AbilityService
	One framework for every active ability (AbilityConfig): unlock check,
	server-clock cooldown, energy cost, then either

	  * movement abilities — the client already moved (instant feel); the
	    server charges energy/cooldown, opens an anti-exploit burst window and
	    tells the client to cancel if the use was invalid; or
	  * server-executed abilities — damage, stuns, scans and size changes run
	    entirely on the server.

	Cooldown tolerance (15%) absorbs network jitter without letting clients
	meaningfully speed up abilities; repeated violations are reported.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AbilityConfig = require(Shared.Config.AbilityConfig)
local SizeConfig = require(Shared.Config.SizeConfig)
local CombatMath = require(Shared.Formulas.CombatMath)
local ScaleMath = require(Shared.Formulas.ScaleMath)
local Guard = require(Shared.Util.Guard)

local ServerRoot = script.Parent.Parent
local Net = require(ServerRoot.Net)
local GameEvents = require(ServerRoot.GameEvents)
local PlayerDataService = require(script.Parent.PlayerDataService)
local CharacterService = require(script.Parent.CharacterService)
local StatService = require(script.Parent.StatService)
local EnergyService = require(script.Parent.EnergyService)
local ScaleService = require(script.Parent.ScaleService)
local CombatService = require(script.Parent.CombatService)
local CollectibleService = require(script.Parent.CollectibleService)
local StatisticsService = require(script.Parent.StatisticsService)
local AntiExploitService = require(script.Parent.AntiExploitService)
local ProgressionService = require(script.Parent.ProgressionService)
local PartyService = require(script.Parent.PartyService)

local AbilityService = {}

type State = {
	lastUse: { [string]: number },
	poundPending: number,
	violations: number,
	violationWindow: number,
	lastJumpReport: number,
}

local states: { [Player]: State } = {}

local BURST: { [string]: number } = {
	AirDash = 0.6,
	GroundDash = 0.6,
	ChargedLeap = 2.5,
	MegaJump = 3,
	LongJump = 1.5,
	WallJump = 0.6,
	DashAttack = 0.6,
}

local TELEMETRY = { Jump = true, WallRunEnd = true, GlideEnd = true } :: { [string]: boolean }

local function stateFor(player: Player): State
	local s = states[player]
	if not s then
		s = { lastUse = {}, poundPending = 0, violations = 0, violationWindow = 0, lastJumpReport = 0 }
		states[player] = s
	end
	return s
end

function AbilityService:HasAbility(player: Player, abilityId: string): boolean
	local def = AbilityConfig.get(abilityId)
	if not def then
		return false
	end
	if not def.RequiresSkill then
		return true
	end
	local data = PlayerDataService:Get(player)
	return data ~= nil and data.Skills[def.RequiresSkill] == true
end

function AbilityService:CooldownRemaining(player: Player, abilityId: string): number
	local def = AbilityConfig.get(abilityId)
	local last = stateFor(player).lastUse[abilityId]
	if not def or not last then
		return 0
	end
	local cd = def.Cooldown * StatService:GetDerived(player).CooldownMultiplier
	return math.max(0, cd - (os.clock() - last))
end

local function reject(player: Player, abilityId: string, reason: string)
	Net.energy(player, { E = EnergyService:Get(player), M = EnergyService:GetMax(player), Reject = abilityId, Why = reason })
	if reason == "cooldown" then
		local s = stateFor(player)
		local now = os.clock()
		if now - s.violationWindow > 10 then
			s.violationWindow = now
			s.violations = 0
		end
		s.violations += 1
		if s.violations > 6 then
			AntiExploitService:Flag(player, "ability spam " .. abilityId, 1)
		end
	end
end

-- Validates and charges an ability. Returns true when the use is allowed.
function AbilityService:TryUse(player: Player, abilityId: string): boolean
	local def = AbilityConfig.get(abilityId)
	if not def then
		return false
	end
	if not AbilityService:HasAbility(player, abilityId) then
		reject(player, abilityId, "locked")
		return false
	end
	if not CharacterService:IsAlive(player) then
		return false
	end
	local s = stateFor(player)
	local now = os.clock()
	local cd = def.Cooldown * StatService:GetDerived(player).CooldownMultiplier
	local last = s.lastUse[abilityId]
	if last and now - last < cd * 0.85 then
		reject(player, abilityId, "cooldown")
		return false
	end
	local cost = def.EnergyCost
	if def.Kind == "Movement" then
		cost *= StatService:GetDerived(player).MovementEnergyMultiplier
	end
	if not EnergyService:Spend(player, cost) then
		reject(player, abilityId, "energy")
		return false
	end
	s.lastUse[abilityId] = now
	return true
end

local function heightOf(player: Player): number
	return ScaleMath.height(ScaleService:GetScale(player))
end

local function impact(player: Player): number
	return 1 + StatService:Get(player, "ImpactForce") * 0.5
end

local function broadcast(player: Player, abilityId: string, position: Vector3?)
	Net.fx("Ability", { U = player.UserId, Id = abilityId, P = position, S = ScaleService:GetScale(player) })
end

------------------------------------------------------------------ server abilities

local handlers: { [string]: (player: Player, root: BasePart) -> () } = {}

handlers.GroundPound = function(player)
	-- Damage happens on landing (Landed action), within a short window.
	stateFor(player).poundPending = os.clock() + 3
end

handlers.TitanStomp = function(player, root)
	local h = heightOf(player)
	local radius = CombatMath.Attacks.Stomp.Range * h * impact(player)
	CombatService:AreaDamage(player, root.Position, radius, "Stomp")
	CombatService:StunArea(root.Position, radius, 1.5)
	broadcast(player, "TitanStomp", root.Position)
end

handlers.Shockwave = function(player, root)
	local h = heightOf(player)
	local origin = root.Position
	broadcast(player, "Shockwave", origin)
	task.delay(0.3, function()
		local radius = CombatMath.Attacks.Shockwave.Range * h * impact(player)
		CombatService:AreaDamage(player, origin, radius, "Shockwave")
		CombatService:StunArea(origin, radius, 1)
	end)
end

handlers.TitanRoar = function(player, root)
	local radius = heightOf(player) * 10
	CombatService:StunArea(root.Position, radius, 3)
	for _, ally in PartyService:GetMembers(player) do
		EnergyService:Refill(ally, 0.4)
	end
	for _, other in Players:GetPlayers() do
		local otherRoot = CharacterService:GetRoot(other)
		if other ~= player and otherRoot and (otherRoot.Position - root.Position).Magnitude <= radius then
			EnergyService:Refill(other, 0.25)
		end
	end
	broadcast(player, "TitanRoar", root.Position)
end

handlers.Scan = function(player, root)
	local radius = heightOf(player) * 40 * (1 + StatService:Get(player, "SecretFinder"))
	Net.signal(player, "ScanResult", { Items = CollectibleService:Scan(player, root.Position, radius), Radius = radius })
	broadcast(player, "Scan", root.Position)
end

handlers.ShrinkMode = function(player)
	if ScaleService:HasModifier(player, "Shrink") then
		ScaleService:ClearModifier(player, "Shrink")
		return
	end
	local data = PlayerDataService:Get(player)
	if not data then
		return
	end
	local natural = ProgressionService:GetTier(player)
	local target = data.Progress.ShrinkTier
	if target <= 0 or target >= natural then
		target = math.max(1, natural - 4)
	end
	ScaleService:ClearModifier(player, "Overgrowth")
	ScaleService:SetModifier(player, "Shrink", { Scale = SizeConfig.getTier(target).Scale }, AbilityConfig.ShrinkDuration)
	Net.signal(player, "Notify", { Text = "Shrunk to " .. SizeConfig.getTier(target).Name .. " for " .. AbilityConfig.ShrinkDuration .. "s", Kind = "Info" })
end

handlers.Overgrowth = function(player, root)
	if ScaleService:HasModifier(player, "Shrink") then
		return
	end
	ScaleService:SetModifier(player, "Overgrowth", { Multiplier = AbilityConfig.OvergrowthScale }, AbilityConfig.OvergrowthDuration)
	broadcast(player, "Overgrowth", root.Position)
end

------------------------------------------------------------------ lifecycle

local function onAbility(player: Player, payload: { Id: string })
	local id = payload.Id
	if TELEMETRY[id] then
		local s = stateFor(player)
		if id == "Jump" then
			local now = os.clock()
			if now - s.lastJumpReport > 0.2 then
				s.lastJumpReport = now
				StatisticsService:Increment(player, "Jumps")
				GameEvents.fire("Jumped", player)
			end
		elseif id == "WallRunEnd" then
			EnergyService:SetDrain(player, "WallRun", nil)
		elseif id == "GlideEnd" then
			EnergyService:SetDrain(player, "Glide", nil)
		end
		return
	end
	local def = AbilityConfig.get(id)
	if not def or def.Kind == "Combat" then
		return -- combat abilities go through the Attack action
	end
	if not AbilityService:TryUse(player, id) then
		return
	end
	local root = CharacterService:GetRoot(player)
	if not root then
		return
	end
	local burst = BURST[id]
	if burst then
		AntiExploitService:AllowBurst(player, burst)
	end
	if id == "AirDash" or id == "GroundDash" then
		StatisticsService:Increment(player, "Dashes")
		GameEvents.fire("Dashed", player)
	elseif id == "WallRun" then
		EnergyService:SetDrain(player, "WallRun", AbilityConfig.WallRunDrainPerSecond)
		task.delay(AbilityConfig.WallRunDurationMax + 0.5, function()
			EnergyService:SetDrain(player, "WallRun", nil)
		end)
	elseif id == "Glide" then
		EnergyService:SetDrain(player, "Glide", AbilityConfig.GlideDrainPerSecond)
	end
	local handler = handlers[id]
	if handler then
		handler(player, root)
	elseif def.Kind == "Movement" then
		broadcast(player, id, root.Position)
	end
	GameEvents.fire("AbilityUsed", player, id)
end

local function onLanded(player: Player, payload: { Height: number, Pound: boolean })
	local root = CharacterService:GetRoot(player)
	if not root then
		return
	end
	EnergyService:SetDrain(player, "Glide", nil)
	local s = stateFor(player)
	local h = heightOf(player)
	local now = os.clock()
	if payload.Pound and s.poundPending > now then
		s.poundPending = 0
		local radius = CombatMath.Attacks.GroundPound.Range * h * impact(player)
		CombatService:AreaDamage(player, root.Position, radius, "GroundPound")
		broadcast(player, "GroundPound", root.Position)
	end
	-- Earthquake Landing: passive on high falls (server re-validates cooldown).
	local fallBodies = math.clamp(payload.Height, 0, 1e5) / h
	if fallBodies > 2.5 and AbilityService:HasAbility(player, "EarthquakeLanding") then
		local last = s.lastUse.EarthquakeLanding or 0
		if now - last >= 3 then
			s.lastUse.EarthquakeLanding = now
			local radius = CombatMath.Attacks.Earthquake.Range * h * impact(player)
			CombatService:AreaDamage(player, root.Position, radius, "Earthquake", math.min(2, fallBodies / 4))
			broadcast(player, "EarthquakeLanding", root.Position)
		end
	end
end

function AbilityService:Init()
	Net.onAction("Ability", Guard.shape({ Id = Guard.id(32) }), onAbility)
	Net.onAction("Landed", Guard.shape({ Height = Guard.number(0, 1e6), Pound = Guard.boolean() }), onLanded)
	Net.onRequest("ToggleShrink", Guard.shape({ Tier = Guard.integer(0, 30) }), function(player, payload)
		local data = PlayerDataService:Get(player)
		if not data then
			return { ok = false }
		end
		local natural = ProgressionService:GetTier(player)
		if payload.Tier ~= 0 and payload.Tier >= natural then
			return { ok = false, err = "Choose a size smaller than you are now" }
		end
		data.Progress.ShrinkTier = payload.Tier
		PlayerDataService:Changed(player, "Progress")
		return { ok = true }
	end)
end

function AbilityService:Start()
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
	end)
	CharacterService.Spawned:Connect(function(player)
		local s = stateFor(player)
		s.poundPending = 0
	end)
end

return AbilityService
