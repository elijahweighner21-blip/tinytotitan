--!strict
--[[
	AscensionConfig
	Prestige. The `Resets` and `Keeps` lists are the single source of truth:
	the confirmation dialog renders them and AscensionService resets exactly the
	data paths listed in `ResetPaths` — nothing else — so the UI can never
	promise something the server does not do.
]]

export type Node = {
	Id: string,
	Name: string,
	Description: string,
	Icon: string,
	MaxRank: number,
	Cost: number,
	CostGrowth: number,
	Stat: string,
	PerRank: number,
	Position: Vector2,
	Requires: { string },
}

local AscensionConfig = {
	RequiredTier = 12,
	MaxAscensions = 1000,

	-- Human-readable lists shown before confirming.
	Resets = {
		"Mass and size (back to Microscopic)",
		"Growth Energy",
		"Stat upgrade levels",
		"Zone resources (Dust Cores, Sugar Crystals, ...)",
		"Learned skills (all Skill Points are refunded)",
		"Progress on non-story quests in progress",
	},
	Keeps = {
		"Level, XP and Skill Points",
		"Titan Shards and Ascension Points",
		"Cosmetics, titles and achievements",
		"Collectibles, discoveries and fast travel unlocks",
		"Completed story quests and boss records",
		"Game Passes, boosts and everything bought with Robux",
		"Statistics and leaderboard records",
	},

	-- Data paths reset by AscensionService (top-level keys / nested keys).
	ResetPaths = {
		{ "Currencies", "Mass" },
		{ "Currencies", "GrowthEnergy" },
		{ "Upgrades" },
		{ "Resources" },
		{ "Skills" },
		{ "Progress", "RunMass" },
		{ "Progress", "Tier" },
	},

	-- Points: rewards going deeper than the minimum.
	BasePoints = 10,
	PointsPerTierAbove = 6,
	PointsMassExponent = 0.35,
	PointsMassDivisor = 4.8e7, -- the Titan threshold: ascending right at Titan gives +4

	-- Ascension tree ---------------------------------------------------------
	Tree = {
		{
			Id = "PermanentMass",
			Name = "Eternal Growth",
			Description = "+10% permanent Mass per rank.",
			Icon = "🟢",
			MaxRank = 20,
			Cost = 3,
			CostGrowth = 1.25,
			Stat = "MassGain",
			PerRank = 0.10,
			Position = Vector2.new(2, 0),
			Requires = {},
		},
		{
			Id = "PermanentEnergy",
			Name = "Eternal Energy",
			Description = "+10% permanent Growth Energy per rank.",
			Icon = "🔋",
			MaxRank = 20,
			Cost = 3,
			CostGrowth = 1.25,
			Stat = "GrowthEnergyGain",
			PerRank = 0.10,
			Position = Vector2.new(1, 1),
			Requires = { "PermanentMass" },
		},
		{
			Id = "Swiftness",
			Name = "Swiftness",
			Description = "+5% movement speed per rank.",
			Icon = "💨",
			MaxRank = 5,
			Cost = 5,
			CostGrowth = 1.4,
			Stat = "WalkSpeed",
			PerRank = 0.05,
			Position = Vector2.new(3, 1),
			Requires = { "PermanentMass" },
		},
		{
			Id = "ResourceGain",
			Name = "Harvester",
			Description = "+5% zone resources per rank.",
			Icon = "💎",
			MaxRank = 10,
			Cost = 4,
			CostGrowth = 1.3,
			Stat = "ResourceGain",
			PerRank = 0.05,
			Position = Vector2.new(0, 2),
			Requires = { "PermanentEnergy" },
		},
		{
			Id = "StartDoubleJump",
			Name = "Muscle Memory",
			Description = "Start every run with Double Jump and Slide (ignores size requirement).",
			Icon = "⏫",
			MaxRank = 1,
			Cost = 8,
			CostGrowth = 1,
			Stat = "StartSkills",
			PerRank = 1,
			Position = Vector2.new(2, 2),
			Requires = { "PermanentEnergy", "Swiftness" },
		},
		{
			Id = "ShardFinder",
			Name = "Shard Seeker",
			Description = "+10% Titan Shards from gameplay per rank.",
			Icon = "🔷",
			MaxRank = 10,
			Cost = 6,
			CostGrowth = 1.35,
			Stat = "ShardGain",
			PerRank = 0.10,
			Position = Vector2.new(4, 2),
			Requires = { "Swiftness" },
		},
		{
			Id = "RareDrops",
			Name = "Fortune's Favor",
			Description = "+5% rare drop chance per rank.",
			Icon = "🍀",
			MaxRank = 10,
			Cost = 5,
			CostGrowth = 1.3,
			Stat = "Luck",
			PerRank = 0.05,
			Position = Vector2.new(1, 3),
			Requires = { "ResourceGain" },
		},
		{
			Id = "CheaperUpgrades",
			Name = "Bargain Hunter",
			Description = "-4% upgrade costs per rank.",
			Icon = "🏷️",
			MaxRank = 10,
			Cost = 6,
			CostGrowth = 1.35,
			Stat = "UpgradeDiscount",
			PerRank = 0.04,
			Position = Vector2.new(3, 3),
			Requires = { "StartDoubleJump" },
		},
		{
			Id = "QuestBonus",
			Name = "Legend",
			Description = "+10% quest rewards per rank.",
			Icon = "📜",
			MaxRank = 10,
			Cost = 4,
			CostGrowth = 1.3,
			Stat = "QuestRewards",
			PerRank = 0.10,
			Position = Vector2.new(0, 4),
			Requires = { "RareDrops" },
		},
		{
			Id = "HeadStart",
			Name = "Head Start",
			Description = "Start each run with 2,000 Growth Energy per rank.",
			Icon = "🎒",
			MaxRank = 5,
			Cost = 6,
			CostGrowth = 1.5,
			Stat = "StartEnergy",
			PerRank = 2000,
			Position = Vector2.new(2, 4),
			Requires = { "StartDoubleJump" },
		},
		{
			Id = "AscendedAura",
			Name = "Ascended Aura",
			Description = "Unlocks the Ascended aura cosmetic.",
			Icon = "🌟",
			MaxRank = 1,
			Cost = 15,
			CostGrowth = 1,
			Stat = "CosmeticAscendedAura",
			PerRank = 1,
			Position = Vector2.new(4, 4),
			Requires = { "ShardFinder" },
		},
		{
			Id = "XPBoost",
			Name = "Wisdom",
			Description = "+10% XP per rank.",
			Icon = "🎓",
			MaxRank = 10,
			Cost = 4,
			CostGrowth = 1.3,
			Stat = "XPGain",
			PerRank = 0.10,
			Position = Vector2.new(1, 5),
			Requires = { "QuestBonus" },
		},
		{
			Id = "TitanHeart",
			Name = "Titan Heart",
			Description = "+8% max Energy and regeneration per rank.",
			Icon = "❤️",
			MaxRank = 10,
			Cost = 5,
			CostGrowth = 1.3,
			Stat = "EnergyBoth",
			PerRank = 0.08,
			Position = Vector2.new(3, 5),
			Requires = { "CheaperUpgrades", "HeadStart" },
		},
	} :: { Node },
}

function AscensionConfig.getNode(id: string): Node?
	for _, node in AscensionConfig.Tree do
		if node.Id == id then
			return node
		end
	end
	return nil
end

-- Points granted for ascending with the given highest tier and run Mass.
function AscensionConfig.pointsFor(tier: number, runMass: number): number
	if tier < AscensionConfig.RequiredTier then
		return 0
	end
	local tierBonus = (tier - AscensionConfig.RequiredTier) * AscensionConfig.PointsPerTierAbove
	local massBonus =
		math.floor((math.max(0, runMass) / AscensionConfig.PointsMassDivisor) ^ AscensionConfig.PointsMassExponent * 4)
	return AscensionConfig.BasePoints + tierBonus + massBonus
end

function AscensionConfig.nodeCost(node: { Cost: number, CostGrowth: number }, rank: number): number
	return math.floor(node.Cost * node.CostGrowth ^ rank + 0.5)
end

return AscensionConfig
