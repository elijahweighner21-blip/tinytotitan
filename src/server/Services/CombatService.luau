--!strict
--[[
	CombatService
	Server-authoritative combat. The client only says "I swung (kind, facing)";
	the server checks the attack is unlocked, off cooldown and affordable,
	then finds hits itself from the character's real position.

	Damageable things (enemies, bosses) register through :RegisterTarget, so
	this service never needs to know about EnemyService/BossService.
	Breakables and challenge targets listen to `AttackPerformed`.

	Player damage (:DamagePlayer) is only ever called by enemies, bosses and
	hazards — there is no player-vs-player path. Spawn protection and brief
	invulnerability frames prevent spawn camping and damage stacking.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local CombatMath = require(Shared.Formulas.CombatMath)
local ScaleMath = require(Shared.Formulas.ScaleMath)
local AbilityConfig = require(Shared.Config.AbilityConfig)
local EnemyConfig = require(Shared.Config.EnemyConfig)
local Guard = require(Shared.Util.Guard)
local Signal = require(Shared.Util.Signal)
local MathUtil = require(Shared.Util.MathUtil)

local ServerRoot = script.Parent.Parent
local Net = require(ServerRoot.Net)
local PlayerDataService = require(script.Parent.PlayerDataService)
local CharacterService = require(script.Parent.CharacterService)
local StatService = require(script.Parent.StatService)
local EnergyService = require(script.Parent.EnergyService)
local ScaleService = require(script.Parent.ScaleService)

export type Target = {
	Id: string,
	Kind: string, -- "Enemy" | "Boss"
	GetPosition: () -> Vector3,
	GetScale: () -> number,
	Radius: number,
	IsBoss: boolean,
	CanBeHitBy: ((player: Player, origin: Vector3) -> boolean)?,
	Damage: (player: Player, amount: number, kind: string, crit: boolean) -> (),
	Stun: ((seconds: number) -> ())?,
	Alive: () -> boolean,
}

local CombatService = {}

-- (player, origin, facing, range, arcDegrees, kind, powerBonus)
CombatService.AttackPerformed = Signal.new() :: Signal.Signal<Player, Vector3, Vector3, number, number, string, number>
-- (player, amount, sourceName)
CombatService.PlayerDamaged = Signal.new() :: Signal.Signal<Player, number, string>

local targets: { [Target]: boolean } = {}
local lastAttack: { [Player]: { [string]: number } } = {}
local invulnerableUntil: { [Player]: number } = {}
local rng = Random.new()

local ATTACK_ABILITY = {
	Light = "LightAttack",
	Heavy = "HeavyAttack",
	Dash = "DashAttack",
	Charged = "ChargedAttack",
} :: { [string]: string }

local SPAWN_PROTECTION = 3
local IFRAMES = 0.45

function CombatService:RegisterTarget(target: Target): () -> ()
	targets[target] = true
	return function()
		targets[target] = nil
	end
end

function CombatService:GetTargets(): { Target }
	local out = {}
	for t in targets do
		if t.Alive() then
			table.insert(out, t)
		end
	end
	return out
end

local function hasSkillFor(player: Player, abilityId: string): boolean
	local def = AbilityConfig.get(abilityId)
	if not def or not def.RequiresSkill then
		return def ~= nil
	end
	local data = PlayerDataService:Get(player)
	return data ~= nil and data.Skills[def.RequiresSkill] == true
end

local function powerBonus(player: Player): number
	local stats = StatService:GetStats(player)
	return stats.AttackPower + stats.BreakPower * 0.25
end

local function rollCrit(player: Player): boolean
	return rng:NextNumber() < EnemyConfig.CritChance + StatService:Get(player, "Luck") * 0.1
end

-- Applies `kind` damage to every valid target in an arc / radius.
local function hitTargets(player: Player, origin: Vector3, facing: Vector3, range: number, arc: number, kind: string, multiplier: number): number
	local scale = ScaleService:GetScale(player)
	local bonus = powerBonus(player)
	local bossBonus = StatService:Get(player, "BossDamage")
	local hits = 0
	for target in targets do
		if target.Alive() then
			local pos = target.GetPosition()
			if CombatMath.inArc(origin, facing, pos, range + target.Radius, arc) then
				if not target.CanBeHitBy or target.CanBeHitBy(player, origin) then
					local crit = rollCrit(player)
					local dmg = CombatMath.playerDamage(kind, scale, target.GetScale(), bonus, crit) * multiplier
					if target.IsBoss then
						dmg *= 1 + bossBonus
					end
					if dmg > 0 then
						target.Damage(player, dmg, kind, crit)
						hits += 1
						Net.fxTo(player, "Hit", { P = pos, A = math.floor(dmg), C = crit })
					end
				end
			end
		end
	end
	return hits
end

-- Area damage for abilities (stomp, shockwave, ground pound...).
function CombatService:AreaDamage(player: Player, center: Vector3, radius: number, kind: string, multiplier: number?): number
	local hits = hitTargets(player, center, Vector3.new(0, 0, -1), radius, 360, kind, multiplier or 1)
	CombatService.AttackPerformed:Fire(player, center, Vector3.new(0, 0, -1), radius, 360, kind, powerBonus(player))
	return hits
end

function CombatService:StunArea(center: Vector3, radius: number, seconds: number): number
	local count = 0
	for target in targets do
		if target.Alive() and target.Stun and (target.GetPosition() - center).Magnitude <= radius + target.Radius then
			target.Stun(seconds)
			count += 1
		end
	end
	return count
end

function CombatService:PerformAttack(player: Player, kind: string, facing: Vector3): boolean
	local abilityId = ATTACK_ABILITY[kind]
	local def = CombatMath.Attacks[kind]
	local ability = abilityId and AbilityConfig.get(abilityId)
	if not def or not ability or not hasSkillFor(player, abilityId) then
		return false
	end
	local root = CharacterService:GetRoot(player)
	if not root then
		return false
	end
	local now = os.clock()
	local history = lastAttack[player]
	if not history then
		history = {}
		lastAttack[player] = history
	end
	local cooldown = ability.Cooldown * StatService:GetDerived(player).CooldownMultiplier
	-- 15% tolerance for network jitter on client-timed attacks.
	if history[kind] and now - history[kind] < cooldown * 0.85 then
		return false
	end
	if not EnergyService:Spend(player, ability.EnergyCost) then
		return false
	end
	history[kind] = now
	local look = if facing.Magnitude > 0.01 then facing.Unit else root.CFrame.LookVector
	local scale = ScaleService:GetScale(player)
	local range = def.Range * ScaleMath.height(scale)
	local origin = root.Position
	hitTargets(player, origin, look, range, def.Arc, kind, 1)
	CombatService.AttackPerformed:Fire(player, origin, look, range, def.Arc, kind, powerBonus(player))
	Net.fx("Attack", { U = player.UserId, K = kind })
	return true
end

-- The only way players lose health. `sourceScale` lets small hazards hurt
-- small players more than big ones.
function CombatService:DamagePlayer(player: Player, amount: number, sourceName: string): boolean
	if not MathUtil.isFinite(amount) or amount <= 0 then
		return false
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if not humanoid or humanoid.Health <= 0 then
		return false
	end
	local now = os.clock()
	if (invulnerableUntil[player] or 0) > now then
		return false
	end
	local grace = (player:GetAttribute("TeleportGrace") :: number?) or 0
	if workspace:GetServerTimeNow() - grace < SPAWN_PROTECTION then
		return false
	end
	local defense = StatService:Get(player, "Defense")
	local final = amount / (1 + defense)
	invulnerableUntil[player] = now + IFRAMES
	humanoid:TakeDamage(final)
	Net.signal(player, "Damage", { Amount = math.floor(final), From = sourceName })
	CombatService.PlayerDamaged:Fire(player, final, sourceName)
	return true
end

function CombatService:Init()
	Net.onAction(
		"Attack",
		Guard.shape({ Kind = Guard.oneOf({ "Light", "Heavy", "Dash", "Charged" }), Facing = Guard.vector3(2) }),
		function(player, payload)
			CombatService:PerformAttack(player, payload.Kind, payload.Facing)
		end
	)
end

function CombatService:Start()
	Players.PlayerRemoving:Connect(function(player)
		lastAttack[player] = nil
		invulnerableUntil[player] = nil
	end)
end

return CombatService
