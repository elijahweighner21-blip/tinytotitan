--!strict
--[[
	BossConfig
	Bosses are built from shared attack primitives (BossService executes them):

	  Slam       telegraphed circle at a target player's position
	  Sweep      line/cone in front of the boss
	  Charge     the boss dashes toward a target along a telegraphed lane
	  Shockwave  expanding ring around the boss (jump to avoid)
	  Volley     several projectiles at random players
	  Summon     spawns minions (EnemyConfig ids)
	  Rain       many small telegraphed circles across the arena

	Radii/ranges (including ArenaRadius) are in BOSS body lengths. Damage is "at equal size" and is
	scaled by size advantage like normal enemies. Health scales with the
	number of participants.
]]

local Types = require(script.Parent.Parent.Types)

type Boss = Types.Boss

local List: { Boss } = {
	{
		Id = "Queen",
		Name = "THE QUEEN",
		Title = "Monarch of the Floor",
		Zone = "FloorWorld",
		Scale = 1.4,
		BaseHealth = 900,
		HealthPerPlayer = 0.6,
		RequiredTier = 3,
		Color = Color3.fromRGB(120, 40, 30),
		Shape = "Insect",
		ArenaRadius = 5,
		ContactDamage = 10,
		Speed = 1.6,
		RewardCooldown = 600,
		Rewards = { Mass = 900, GrowthEnergy = 500, XP = 400, TitanShards = 5, Resources = { DustCores = 8 } },
		FirstKillRewards = { TitanShards = 25, Titles = { "Queenslayer" }, Cosmetics = { "AntTrail" } },
		Phases = {
			{
				HealthBelow = 1.0,
				Name = "The Hive Stirs",
				AttackInterval = 2.8,
				SpeedMultiplier = 1,
				Attacks = {
					{ Id = "Bite", Kind = "Sweep", Weight = 3, Telegraph = 0.9, Damage = 18, Radius = 1.6 },
					{
						Id = "CallWorkers",
						Kind = "Summon",
						Weight = 1,
						Telegraph = 1.2,
						Damage = 0,
						Count = 3,
						Minion = "Ant",
					},
				},
			},
			{
				HealthBelow = 0.6,
				Name = "Royal Fury",
				AttackInterval = 2.3,
				SpeedMultiplier = 1.25,
				Attacks = {
					{ Id = "Bite", Kind = "Sweep", Weight = 2, Telegraph = 0.8, Damage = 20, Radius = 1.6 },
					{ Id = "Pounce", Kind = "Slam", Weight = 2, Telegraph = 1.1, Damage = 26, Radius = 1.2 },
					{
						Id = "CallWorkers",
						Kind = "Summon",
						Weight = 1,
						Telegraph = 1.2,
						Damage = 0,
						Count = 4,
						Minion = "Ant",
					},
				},
			},
			{
				HealthBelow = 0.25,
				Name = "Last Stand",
				AttackInterval = 1.8,
				SpeedMultiplier = 1.5,
				Attacks = {
					{ Id = "Pounce", Kind = "Slam", Weight = 2, Telegraph = 0.9, Damage = 28, Radius = 1.3 },
					{
						Id = "AcidRain",
						Kind = "Rain",
						Weight = 2,
						Telegraph = 1.3,
						Damage = 18,
						Radius = 0.7,
						Count = 8,
					},
					{ Id = "Charge", Kind = "Charge", Weight = 1, Telegraph = 1.0, Damage = 30, Radius = 0.8 },
				},
			},
		},
	},
	{
		Id = "Vacuum",
		Name = "VACUUM-01",
		Title = "The Devourer of Crumbs",
		Zone = "Bedroom",
		Scale = 6,
		BaseHealth = 1400,
		HealthPerPlayer = 0.6,
		RequiredTier = 5,
		Color = Color3.fromRGB(60, 60, 70),
		Shape = "Vacuum",
		ArenaRadius = 2.4,
		ContactDamage = 14,
		Speed = 1.2,
		RewardCooldown = 600,
		Rewards = { Mass = 1200, GrowthEnergy = 700, XP = 600, TitanShards = 6, Resources = { DustCores = 15 } },
		FirstKillRewards = { TitanShards = 30, Titles = { "DustBuster" }, Cosmetics = { "VacuumAura" } },
		Phases = {
			{
				HealthBelow = 1.0,
				Name = "Cleaning Cycle",
				AttackInterval = 3,
				SpeedMultiplier = 1,
				Attacks = {
					{ Id = "Ram", Kind = "Charge", Weight = 3, Telegraph = 1.2, Damage = 24, Radius = 0.5 },
					{
						Id = "DustCloud",
						Kind = "Rain",
						Weight = 1,
						Telegraph = 1.4,
						Damage = 14,
						Radius = 0.35,
						Count = 6,
					},
				},
			},
			{
				HealthBelow = 0.55,
				Name = "TURBO MODE",
				AttackInterval = 2.2,
				SpeedMultiplier = 1.5,
				Attacks = {
					{ Id = "Ram", Kind = "Charge", Weight = 2, Telegraph = 0.9, Damage = 26, Radius = 0.5 },
					{ Id = "Suction", Kind = "Shockwave", Weight = 2, Telegraph = 1.2, Damage = 20, Radius = 3 },
					{ Id = "DebrisVolley", Kind = "Volley", Weight = 1, Telegraph = 0.8, Damage = 12, Count = 5 },
				},
			},
			{
				HealthBelow = 0.2,
				Name = "OVERHEATING",
				AttackInterval = 1.7,
				SpeedMultiplier = 1.7,
				Attacks = {
					{ Id = "Ram", Kind = "Charge", Weight = 2, Telegraph = 0.8, Damage = 28, Radius = 0.5 },
					{ Id = "Suction", Kind = "Shockwave", Weight = 1, Telegraph = 1.0, Damage = 22, Radius = 3.4 },
					{
						Id = "DustCloud",
						Kind = "Rain",
						Weight = 2,
						Telegraph = 1.1,
						Damage = 16,
						Radius = 0.35,
						Count = 10,
					},
				},
			},
		},
	},
	{
		Id = "Lawnmower",
		Name = "THE LAWNMOWER",
		Title = "Terror of the Grass Forest",
		Zone = "Backyard",
		Scale = 20,
		BaseHealth = 2000,
		HealthPerPlayer = 0.6,
		RequiredTier = 8,
		Color = Color3.fromRGB(200, 40, 40),
		Shape = "Mower",
		ArenaRadius = 3.5,
		ContactDamage = 18,
		Speed = 1.5,
		RewardCooldown = 600,
		Rewards = { Mass = 1500, GrowthEnergy = 900, XP = 900, TitanShards = 8, Resources = { NatureEssence = 20 } },
		FirstKillRewards = { TitanShards = 40, Titles = { "GrassSurvivor" }, Cosmetics = { "CloverTrail" } },
		Phases = {
			{
				HealthBelow = 1.0,
				Name = "Engine Start",
				AttackInterval = 2.8,
				SpeedMultiplier = 1,
				Attacks = {
					{ Id = "MowLine", Kind = "Charge", Weight = 3, Telegraph = 1.2, Damage = 28, Radius = 0.6 },
					{ Id = "ClippingSpray", Kind = "Volley", Weight = 2, Telegraph = 0.8, Damage = 12, Count = 6 },
				},
			},
			{
				HealthBelow = 0.5,
				Name = "Full Throttle",
				AttackInterval = 2.0,
				SpeedMultiplier = 1.4,
				Attacks = {
					{ Id = "MowLine", Kind = "Charge", Weight = 3, Telegraph = 0.9, Damage = 30, Radius = 0.6 },
					{
						Id = "RockKick",
						Kind = "Rain",
						Weight = 2,
						Telegraph = 1.1,
						Damage = 18,
						Radius = 0.4,
						Count = 9,
					},
					{ Id = "Backfire", Kind = "Shockwave", Weight = 1, Telegraph = 1.0, Damage = 22, Radius = 2.5 },
				},
			},
		},
	},
	{
		Id = "Guardian",
		Name = "GUARDIAN MK-IV",
		Title = "Vale Industries Security",
		Zone = "Downtown",
		Scale = 110,
		BaseHealth = 3000,
		HealthPerPlayer = 0.6,
		RequiredTier = 11,
		Color = Color3.fromRGB(80, 160, 255),
		Shape = "Mech",
		ArenaRadius = 2,
		ContactDamage = 20,
		Speed = 1.1,
		RewardCooldown = 600,
		Rewards = { Mass = 2000, GrowthEnergy = 1200, XP = 1400, TitanShards = 12, Resources = { Scrap = 40 } },
		FirstKillRewards = { TitanShards = 60, Titles = { "MachineBreaker" }, Cosmetics = { "CircuitAura" } },
		Phases = {
			{
				HealthBelow = 1.0,
				Name = "Threat Assessment",
				AttackInterval = 2.6,
				SpeedMultiplier = 1,
				Attacks = {
					{ Id = "Missiles", Kind = "Volley", Weight = 3, Telegraph = 1.0, Damage = 16, Count = 6 },
					{ Id = "Slam", Kind = "Slam", Weight = 2, Telegraph = 1.2, Damage = 28, Radius = 0.9 },
				},
			},
			{
				HealthBelow = 0.6,
				Name = "Lethal Force",
				AttackInterval = 2.1,
				SpeedMultiplier = 1.2,
				Attacks = {
					{ Id = "Missiles", Kind = "Volley", Weight = 2, Telegraph = 0.9, Damage = 18, Count = 8 },
					{ Id = "LaserSweep", Kind = "Sweep", Weight = 2, Telegraph = 1.0, Damage = 26, Radius = 2.5 },
					{
						Id = "Drones",
						Kind = "Summon",
						Weight = 1,
						Telegraph = 1.2,
						Damage = 0,
						Count = 3,
						Minion = "SecurityDrone",
					},
				},
			},
			{
				HealthBelow = 0.25,
				Name = "Core Exposed",
				AttackInterval = 1.6,
				SpeedMultiplier = 1.4,
				Attacks = {
					{
						Id = "Orbital",
						Kind = "Rain",
						Weight = 3,
						Telegraph = 1.1,
						Damage = 22,
						Radius = 0.5,
						Count = 12,
					},
					{ Id = "Overload", Kind = "Shockwave", Weight = 2, Telegraph = 1.0, Damage = 30, Radius = 3 },
				},
			},
		},
	},
	{
		Id = "Colossus",
		Name = "THE COLOSSUS",
		Title = "The First Titan",
		Zone = "TitanWilderness",
		Scale = 420,
		BaseHealth = 5000,
		HealthPerPlayer = 0.6,
		RequiredTier = 14,
		Color = Color3.fromRGB(170, 120, 255),
		Shape = "Colossus",
		ArenaRadius = 1.5,
		ContactDamage = 24,
		Speed = 0.9,
		RewardCooldown = 900,
		Rewards = { Mass = 3000, GrowthEnergy = 1800, XP = 2500, TitanShards = 25, Resources = { TitanCells = 60 } },
		FirstKillRewards = {
			TitanShards = 150,
			Titles = { "Colossus" },
			Cosmetics = { "ColossusAura", "StarfallTrail" },
		},
		Phases = {
			{
				HealthBelow = 1.0,
				Name = "Awakening",
				AttackInterval = 2.8,
				SpeedMultiplier = 1,
				Attacks = {
					{ Id = "Quake", Kind = "Shockwave", Weight = 2, Telegraph = 1.4, Damage = 26, Radius = 3 },
					{ Id = "Fist", Kind = "Slam", Weight = 3, Telegraph = 1.2, Damage = 32, Radius = 0.9 },
				},
			},
			{
				HealthBelow = 0.66,
				Name = "Titanfall",
				AttackInterval = 2.2,
				SpeedMultiplier = 1.2,
				Attacks = {
					{
						Id = "Meteor",
						Kind = "Rain",
						Weight = 3,
						Telegraph = 1.2,
						Damage = 24,
						Radius = 0.6,
						Count = 12,
					},
					{ Id = "Fist", Kind = "Slam", Weight = 2, Telegraph = 1.0, Damage = 34, Radius = 1 },
					{
						Id = "Guardians",
						Kind = "Summon",
						Weight = 1,
						Telegraph = 1.4,
						Damage = 0,
						Count = 2,
						Minion = "TitanGuardian",
					},
				},
			},
			{
				HealthBelow = 0.33,
				Name = "World's End",
				AttackInterval = 1.7,
				SpeedMultiplier = 1.4,
				Attacks = {
					{ Id = "Quake", Kind = "Shockwave", Weight = 2, Telegraph = 1.0, Damage = 30, Radius = 3.4 },
					{
						Id = "Meteor",
						Kind = "Rain",
						Weight = 2,
						Telegraph = 1.0,
						Damage = 26,
						Radius = 0.6,
						Count = 16,
					},
					{ Id = "Beam", Kind = "Sweep", Weight = 2, Telegraph = 1.0, Damage = 32, Radius = 3 },
				},
			},
		},
	},
}

local byId: { [string]: Boss } = {}
for _, def in List do
	assert(byId[def.Id] == nil, "duplicate boss " .. def.Id)
	byId[def.Id] = def
end

local BossConfig = {
	List = List,
	-- A fight resets if no living participant is inside the arena for this long.
	ResetAfterEmpty = 12,
	RespawnDelay = 45,
	-- Minimum share of the fight's duration a player must be present (or
	-- minimum damage share) to earn rewards: stops last-second tagging.
	MinParticipation = 0.25,
	MinDamageShare = 0.03,
	-- After the reward cooldown has not elapsed, repeat kills still pay this fraction.
	RepeatRewardFraction = 0.25,
	-- Players attacking from outside the arena deal no damage.
	ArenaDamageMargin = 1.15,
	MaxBossTime = 600,
}

function BossConfig.get(id: string): Boss?
	return byId[id]
end

return BossConfig
