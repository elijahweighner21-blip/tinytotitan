--!strict
--[[
	CombatMath
	Damage formulas. Size difference is the dominant factor: a titan crushes
	ants instantly while ants barely scratch a titan, and enemies near the
	player's size are the meaningful fights.
]]

local CombatMath = {}

CombatMath.PLAYER_MAX_HEALTH = 100

CombatMath.Attacks = {
	Light = { Base = 10, Range = 1.6, Arc = 100, Cooldown = 0.35, Knockback = 0.6 },
	Heavy = { Base = 26, Range = 1.9, Arc = 120, Cooldown = 0.9, Knockback = 1.4 },
	Dash = { Base = 18, Range = 2.4, Arc = 80, Cooldown = 1.2, Knockback = 1.0 },
	Charged = { Base = 55, Range = 2.6, Arc = 140, Cooldown = 2.5, Knockback = 2.2 },
	GroundPound = { Base = 30, Range = 2.8, Arc = 360, Cooldown = 0, Knockback = 1.8 },
	Stomp = { Base = 80, Range = 4.5, Arc = 360, Cooldown = 0, Knockback = 3 },
	Shockwave = { Base = 60, Range = 9, Arc = 360, Cooldown = 0, Knockback = 3.5 },
	Earthquake = { Base = 70, Range = 6, Arc = 360, Cooldown = 0, Knockback = 2.5 },
	Throw = { Base = 45, Range = 2, Arc = 360, Cooldown = 0, Knockback = 2 },
} :: { [string]: { Base: number, Range: number, Arc: number, Cooldown: number, Knockback: number } }

-- How much more effective a bigger attacker is. Clamped so nothing becomes
-- literally invincible or one-shot from absurd ratios except at extremes.
function CombatMath.sizeAdvantage(attackerScale: number, defenderScale: number): number
	local ratio = math.max(attackerScale, 0.01) / math.max(defenderScale, 0.01)
	return math.clamp(ratio ^ 0.75, 0.15, 40)
end

-- Player -> enemy damage.
function CombatMath.playerDamage(
	attack: string,
	playerScale: number,
	enemyScale: number,
	attackPowerBonus: number,
	isCritical: boolean
): number
	local def = CombatMath.Attacks[attack]
	if not def then
		return 0
	end
	local dmg = def.Base * (1 + math.max(0, attackPowerBonus)) * CombatMath.sizeAdvantage(playerScale, enemyScale)
	if isCritical then
		dmg *= 1.75
	end
	return math.floor(dmg * 10 + 0.5) / 10
end

-- Enemy -> player damage in player-health points (players always have 100 HP).
function CombatMath.enemyDamage(
	baseDamage: number,
	enemyScale: number,
	playerScale: number,
	defenseBonus: number
): number
	local dmg = baseDamage * CombatMath.sizeAdvantage(enemyScale, playerScale) / (1 + math.max(0, defenseBonus))
	return math.clamp(dmg, 0, CombatMath.PLAYER_MAX_HEALTH * 0.6)
end

-- Rewards drop off when the player vastly outsizes the enemy so titans cannot
-- farm ants for meaningful income.
function CombatMath.rewardFactor(playerScale: number, enemyScale: number): number
	local ratio = playerScale / math.max(enemyScale, 0.01)
	if ratio <= 3 then
		return 1
	end
	return math.clamp(3 / ratio, 0.02, 1)
end

-- Range/arc check in the XZ plane. `facing` must be a unit vector.
function CombatMath.inArc(origin: Vector3, facing: Vector3, target: Vector3, range: number, arcDegrees: number): boolean
	local offset = target - origin
	local flat = Vector3.new(offset.X, 0, offset.Z)
	local distance = offset.Magnitude
	if distance > range then
		return false
	end
	if arcDegrees >= 360 or flat.Magnitude < 1e-3 then
		return true
	end
	local cos = flat.Unit:Dot(Vector3.new(facing.X, 0, facing.Z).Unit)
	return cos >= math.cos(math.rad(arcDegrees / 2))
end

return CombatMath
