--!strict
--[[
	LevelConfig
	Milestone rewards for player Level (separate from size). Every level grants
	Skill Points (Formulas/Progression.skillPointsForLevel); these milestones
	add extra feature unlocks and treats so levelling always feels meaningful.
]]

export type Milestone = { Level: number, Text: string, Reward: { TitanShards: number?, Cosmetics: { string }?, Titles: { string }? }, Unlock: string? }

local Milestones: { Milestone } = {
	{ Level = 2, Text = "Skill Tree unlocked", Reward = { TitanShards = 1 }, Unlock = "SkillTree" },
	{ Level = 3, Text = "Daily objectives unlocked", Reward = { TitanShards = 1 }, Unlock = "Daily" },
	{ Level = 5, Text = "Cosmetics unlocked", Reward = { TitanShards = 3, Cosmetics = { "BasicTrail" } }, Unlock = "Cosmetics" },
	{ Level = 8, Text = "Party system unlocked", Reward = { TitanShards = 3 }, Unlock = "Party" },
	{ Level = 10, Text = "Free Soft Glow aura", Reward = { TitanShards = 5, Cosmetics = { "GlowAura" } } },
	{ Level = 15, Text = "Mint name color", Reward = { TitanShards = 5, Cosmetics = { "MintName" } } },
	{ Level = 20, Text = "Dust Burst landing", Reward = { TitanShards = 8, Cosmetics = { "DustLanding" } } },
	{ Level = 30, Text = "Ember Trail", Reward = { TitanShards = 10, Cosmetics = { "EmberTrail" } } },
	{ Level = 40, Text = "Spark Steps", Reward = { TitanShards = 12, Cosmetics = { "SparkStep" } } },
	{ Level = 50, Text = "Wind Dash", Reward = { TitanShards = 15, Cosmetics = { "WindDash" } } },
	{ Level = 75, Text = "Spiral Growth", Reward = { TitanShards = 20, Cosmetics = { "SpiralGrowth" } } },
	{ Level = 100, Text = "Prism Trail", Reward = { TitanShards = 40, Cosmetics = { "RainbowTrail" } } },
}

local LevelConfig = { Milestones = Milestones }

function LevelConfig.milestoneAt(level: number): Milestone?
	for _, m in Milestones do
		if m.Level == level then
			return m
		end
	end
	return nil
end

return LevelConfig
