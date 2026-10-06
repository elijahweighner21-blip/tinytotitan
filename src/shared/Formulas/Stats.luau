--!strict
--[[
	Stats
	Aggregates every stat bonus a player has (upgrades, skills, ascension tree,
	temporary states) into one table. Server and client both call `compute`
	with the same data so movement prediction and server validation agree.

	Conventions: values are fractional bonuses (0.25 = +25%). Final movement
	numbers come from `derive`, which combines bonuses with ScaleMath curves.
]]

local UpgradeConfig = require(script.Parent.Parent.Config.UpgradeConfig)
local SkillConfig = require(script.Parent.Parent.Config.SkillConfig)
local AscensionConfig = require(script.Parent.Parent.Config.AscensionConfig)
local AbilityConfig = require(script.Parent.Parent.Config.AbilityConfig)
local ScaleMath = require(script.Parent.ScaleMath)
local Pricing = require(script.Parent.Pricing)

export type StatTable = { [string]: number }

export type StatSource = {
	Upgrades: { [string]: number }?,
	Skills: { [string]: boolean }?,
	AscensionTree: { [string]: number }?,
}

export type Derived = {
	Scale: number,
	Height: number,
	WalkSpeed: number,
	SprintSpeed: number,
	JumpVelocity: number,
	JumpHeight: number,
	Gravity: number,
	GravityMultiplier: number,
	AirControl: number,
	Acceleration: number,
	ClimbSpeed: number,
	MaxEnergy: number,
	EnergyRegen: number,
	CooldownMultiplier: number,
	Strength: number,
	PushStrength: number,
	CarryStrength: number,
	ThrowStrength: number,
	BreakPower: number,
	InteractRange: number,
	CollectRange: number,
	MovementEnergyMultiplier: number,
}

local Stats = {}

Stats.Keys = {
	"WalkSpeed",
	"SprintSpeed",
	"JumpHeight",
	"AirControl",
	"Acceleration",
	"ClimbSpeed",
	"MassGain",
	"GrowthEnergyGain",
	"XPGain",
	"ShardGain",
	"ResourceGain",
	"ChallengeRewards",
	"QuestRewards",
	"RareResourceChance",
	"PushStrength",
	"CarryCapacity",
	"BreakPower",
	"ImpactForce",
	"MaxEnergy",
	"EnergyRegen",
	"CooldownReduction",
	"Luck",
	"GoldenOrbChance",
	"BonusRewardChance",
	"DetectionRadius",
	"SecretFinder",
	"MapReveal",
	"AttackPower",
	"Defense",
	"BossDamage",
	"MovementEnergyDiscount",
	"TravelCooldownReduction",
	"UpgradeDiscount",
	"StartEnergy",
	"StartSkills",
}

function Stats.empty(): StatTable
	local t = {}
	for _, key in Stats.Keys do
		t[key] = 0
	end
	return t
end

function Stats.compute(source: StatSource): StatTable
	local stats = Stats.empty()
	if source.Upgrades then
		for id, level in source.Upgrades do
			local def = UpgradeConfig.get(id)
			if def and type(level) == "number" and level > 0 then
				local key = def.Effect.Stat
				stats[key] = (stats[key] or 0) + Pricing.effectAt(def.Effect.PerLevel, math.min(level, def.MaxLevel))
			end
		end
	end
	if source.Skills then
		for id, owned in source.Skills do
			local def = SkillConfig.get(id)
			if owned and def and def.Grants.Stats then
				for key, value in def.Grants.Stats do
					stats[key] = (stats[key] or 0) + value
				end
			end
		end
	end
	if source.AscensionTree then
		for id, rank in source.AscensionTree do
			local node = AscensionConfig.getNode(id)
			if node and type(rank) == "number" and rank > 0 then
				local value = node.PerRank * math.min(rank, node.MaxRank)
				if node.Stat == "EnergyBoth" then
					stats.MaxEnergy += value
					stats.EnergyRegen += value
				else
					stats[node.Stat] = (stats[node.Stat] or 0) + value
				end
			end
		end
	end
	-- Safety caps: some stats would break the game past these values.
	stats.CooldownReduction = math.min(stats.CooldownReduction, 0.6)
	stats.MovementEnergyDiscount = math.min(stats.MovementEnergyDiscount, 0.5)
	stats.UpgradeDiscount = math.min(stats.UpgradeDiscount, 0.5)
	stats.TravelCooldownReduction = math.min(stats.TravelCooldownReduction, 0.75)
	stats.Defense = math.min(stats.Defense, 0.75)
	stats.Luck = math.min(stats.Luck, 2)
	stats.GoldenOrbChance = math.min(stats.GoldenOrbChance, 0.6)
	stats.BonusRewardChance = math.min(stats.BonusRewardChance, 0.5)
	stats.RareResourceChance = math.min(stats.RareResourceChance, 0.6)
	return stats
end

-- Combines stat bonuses with the size curves into concrete numbers.
function Stats.derive(stats: StatTable, scale: number): Derived
	local strength = ScaleMath.strength(scale)
	local jumpMult = 1 + stats.JumpHeight
	return {
		Scale = scale,
		Height = ScaleMath.height(scale),
		WalkSpeed = ScaleMath.walkSpeed(scale) * (1 + stats.WalkSpeed),
		SprintSpeed = ScaleMath.walkSpeed(scale)
			* (1 + stats.WalkSpeed)
			* ScaleMath.sprintMultiplier(scale)
			* (1 + stats.SprintSpeed),
		JumpVelocity = ScaleMath.jumpVelocity(scale, jumpMult),
		JumpHeight = ScaleMath.jumpHeight(scale) * jumpMult,
		Gravity = ScaleMath.effectiveGravity(scale),
		GravityMultiplier = ScaleMath.gravityMultiplier(scale),
		AirControl = 0.55 * (1 + stats.AirControl),
		Acceleration = 7 * (1 + stats.Acceleration),
		ClimbSpeed = ScaleMath.walkSpeed(scale) * 0.6 * (1 + stats.ClimbSpeed),
		MaxEnergy = AbilityConfig.BaseMaxEnergy * (1 + stats.MaxEnergy),
		EnergyRegen = AbilityConfig.BaseRegenPerSecond * (1 + stats.EnergyRegen),
		CooldownMultiplier = 1 - stats.CooldownReduction,
		Strength = strength,
		PushStrength = strength * (1 + stats.PushStrength),
		CarryStrength = strength * 0.6 * (1 + stats.CarryCapacity),
		ThrowStrength = strength * 0.35 * (1 + stats.CarryCapacity) * (1 + stats.ImpactForce),
		BreakPower = strength * (1 + stats.BreakPower),
		InteractRange = ScaleMath.interactRange(scale),
		CollectRange = ScaleMath.collectRange(scale) * (1 + stats.DetectionRadius),
		MovementEnergyMultiplier = 1 - stats.MovementEnergyDiscount,
	}
end

return Stats
