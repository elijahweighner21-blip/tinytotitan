--!strict
--[[
	Types
	Shared type definitions for config entries and save data. Configs are typed
	against these so a typo in a quest/upgrade definition is caught statically.
]]

export type CurrencyId = "Mass" | "GrowthEnergy" | "TitanShards" | "AscensionPoints" | "SkillPoints" | "ExplorationTokens"
export type ResourceId = "DustCores" | "SugarCrystals" | "NatureEssence" | "Scrap" | "TitanCells"

-- A bundle of things granted together. All fields optional.
export type Reward = {
	Mass: number?,
	XP: number?,
	GrowthEnergy: number?,
	TitanShards: number?,
	SkillPoints: number?,
	ExplorationTokens: number?,
	AscensionPoints: number?,
	Resources: { [string]: number }?,
	Items: { [string]: number }?,
	Cosmetics: { string }?,
	Titles: { string }?,
	Boosts: { [string]: number }?, -- boost id -> seconds
}

export type SizeTier = {
	Index: number,
	Id: string,
	Name: string,
	Scale: number,
	MassRequired: number,
	Color: Color3,
	Flavor: string,
	Unlocks: { string },
}

export type Zone = {
	Id: string,
	Name: string,
	Order: number,
	RequiredTier: number,
	RecommendedTiers: { number },
	RewardScale: number,
	Resource: string?,
	Center: Vector3,
	Size: Vector3,
	Spawn: Vector3,
	MapColor: Color3,
	Description: string,
	Ambience: string,
	Lighting: string,
}

export type UpgradeEffect = {
	Stat: string,
	PerLevel: number,
	Mode: "Add" | "Mult",
}

export type Upgrade = {
	Id: string,
	Category: string,
	Name: string,
	Description: string,
	Icon: string,
	MaxLevel: number,
	BaseCost: number,
	CostGrowth: number,
	Currency: string,
	Effect: UpgradeEffect,
	RequiredTier: number?,
	ResourceCost: { Resource: string, Every: number, Amount: number }?,
	Order: number,
}

export type Skill = {
	Id: string,
	Branch: string,
	Name: string,
	Description: string,
	Icon: string,
	Position: Vector2,
	Prerequisites: { string },
	Cost: { SkillPoints: number?, TitanShards: number?, Resources: { [string]: number }? },
	Requirements: { Tier: number?, Level: number?, Achievement: string?, Boss: string? },
	Grants: { Ability: string?, Stats: { [string]: number }? },
}

export type Ability = {
	Id: string,
	Name: string,
	Description: string,
	Kind: "Movement" | "Combat" | "Titan" | "Utility",
	Cooldown: number,
	EnergyCost: number,
	RequiresSkill: string?,
	ServerExecuted: boolean,
	Key: string?,
	Icon: string,
}

export type QuestObjective = {
	Type: string,
	Target: string?,
	Count: number,
	Text: string,
	Marker: string?,
}

export type Quest = {
	Id: string,
	Name: string,
	Category: string,
	Zone: string?,
	Description: string,
	Giver: string?,
	Prerequisites: { string }?,
	RequiredTier: number?,
	RequiredLevel: number?,
	Objectives: { QuestObjective },
	Rewards: Reward,
	AutoStart: boolean?,
	NextQuest: string?,
	Story: string?,
}

export type Challenge = {
	Id: string,
	Name: string,
	Type: string,
	Zone: string,
	Description: string,
	RequiredTier: number,
	MaxTier: number?,
	TimeLimit: number,
	Thresholds: { Bronze: number, Silver: number, Gold: number, Titan: number },
	LowerIsBetter: boolean,
	MinPlausibleTime: number?,
	Rewards: { Bronze: Reward, Silver: Reward, Gold: Reward, Titan: Reward },
	Leaderboard: boolean,
	Cooldown: number,
}

export type Enemy = {
	Id: string,
	Name: string,
	Zone: string,
	Scale: number,
	Health: number,
	Damage: number,
	Speed: number,
	AttackRange: number,
	AttackCooldown: number,
	DetectRange: number,
	Behavior: string,
	Rewards: Reward,
	Color: Color3,
	Shape: string,
	XPWeight: number?,
}

export type BossAttack = {
	Id: string,
	Kind: string,
	Weight: number,
	Telegraph: number,
	Damage: number,
	Radius: number?,
	Count: number?,
	Minion: string?,
}

export type BossPhase = {
	HealthBelow: number,
	Name: string,
	Attacks: { BossAttack },
	AttackInterval: number,
	SpeedMultiplier: number,
}

export type Boss = {
	Id: string,
	Name: string,
	Title: string,
	Zone: string,
	Scale: number,
	BaseHealth: number,
	HealthPerPlayer: number,
	Phases: { BossPhase },
	RequiredTier: number,
	Rewards: Reward,
	FirstKillRewards: Reward,
	RewardCooldown: number,
	Color: Color3,
	Shape: string,
	ArenaRadius: number,
	ContactDamage: number,
	Speed: number,
}

export type Cosmetic = {
	Id: string,
	Name: string,
	Category: string,
	Rarity: string,
	Description: string,
	Colors: { Color3 },
	Style: string,
	Source: string,
	Price: { Currency: string, Amount: number }?,
	Limited: { Start: number, End: number, Event: string }?,
}

export type Achievement = {
	Id: string,
	Name: string,
	Description: string,
	Category: string,
	Condition: { Stat: string?, Value: number?, Tier: number?, Event: string?, Count: number? },
	Rewards: Reward,
	Hidden: boolean?,
}

export type PlayerSettings = {
	MusicVolume: number,
	SfxVolume: number,
	AmbientVolume: number,
	CameraShake: number,
	Particles: number,
	DamageNumbers: boolean,
	UIScale: number,
	MotionEffects: boolean,
	ScreenFlashes: boolean,
	FovEffects: boolean,
	PerformancePreset: string,
	HideOtherEffects: boolean,
	SprintToggle: boolean,
	FieldOfView: number,
	ShowTitles: boolean,
}

return {}
