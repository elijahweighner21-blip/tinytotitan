--!strict
--[[
	SizeConfig
	The size ladder. MassRequired values are hand-tuned milestones (validated by
	tools/sim/economy.luau); the Scale column is the character scale reached at
	the START of each tier. Inside a tier the scale interpolates smoothly in log
	space toward the next tier, so growth is continuous but big moments still
	happen at tier boundaries.

	World reference: the house is built so a Human-sized player (scale 16) is
	~80 studs tall, i.e. 1 real-world foot ≈ 13.3 studs.
]]

local Types = require(script.Parent.Parent.Types)

type SizeTier = Types.SizeTier

local Tiers: { SizeTier } = {
	{
		Index = 1,
		Id = "Microscopic",
		Name = "Microscopic",
		Scale = 0.2,
		MassRequired = 0,
		Color = Color3.fromRGB(150, 220, 255),
		Flavor = "Dust motes drift past like planets.",
		Unlocks = { "Floor World" },
	},
	{
		Index = 2,
		Id = "Dust",
		Name = "Dust-Sized",
		Scale = 0.28,
		MassRequired = 250,
		Color = Color3.fromRGB(180, 200, 220),
		Flavor = "Carpet fibers tower like a forest.",
		Unlocks = { "Crumb Climbing", "Upgrades" },
	},
	{
		Index = 3,
		Id = "Ant",
		Name = "Ant-Sized",
		Scale = 0.4,
		MassRequired = 700,
		Color = Color3.fromRGB(205, 120, 90),
		Flavor = "Ants look you in the eye now.",
		Unlocks = { "Bedroom", "Skill Tree" },
	},
	{
		Index = 4,
		Id = "Bug",
		Name = "Bug-Sized",
		Scale = 0.6,
		MassRequired = 7000,
		Color = Color3.fromRGB(120, 200, 110),
		Flavor = "The shoe is a hill, not a mountain.",
		Unlocks = { "Challenges", "Daily Objectives" },
	},
	{
		Index = 5,
		Id = "Mouse",
		Name = "Mouse-Sized",
		Scale = 0.9,
		MassRequired = 22000,
		Color = Color3.fromRGB(170, 170, 180),
		Flavor = "Baseboards are just steps.",
		Unlocks = { "Kitchen", "Collections" },
	},
	{
		Index = 6,
		Id = "Toy",
		Name = "Toy-Sized",
		Scale = 1.5,
		MassRequired = 120000,
		Color = Color3.fromRGB(255, 170, 60),
		Flavor = "You could stand next to the action figures.",
		Unlocks = { "Push Objects", "World Events" },
	},
	{
		Index = 7,
		Id = "Pet",
		Name = "Pet-Sized",
		Scale = 3,
		MassRequired = 300000,
		Color = Color3.fromRGB(230, 200, 140),
		Flavor = "The pet door swings open for you.",
		Unlocks = { "Backyard", "Carry Objects" },
	},
	{
		Index = 8,
		Id = "Child",
		Name = "Child-Sized",
		Scale = 7,
		MassRequired = 1200000,
		Color = Color3.fromRGB(120, 180, 255),
		Flavor = "The kitchen table is just a table.",
		Unlocks = { "Fast Travel", "Throw Objects" },
	},
	{
		Index = 9,
		Id = "Human",
		Name = "Human-Sized",
		Scale = 16,
		MassRequired = 1900000,
		Color = Color3.fromRGB(255, 220, 180),
		Flavor = "Wait... this is a normal house.",
		Unlocks = { "Neighborhood", "Shrink Mode" },
	},
	{
		Index = 10,
		Id = "Large",
		Name = "Large",
		Scale = 30,
		MassRequired = 6500000,
		Color = Color3.fromRGB(255, 140, 120),
		Flavor = "Doorways are a squeeze.",
		Unlocks = { "Downtown" },
	},
	{
		Index = 11,
		Id = "Giant",
		Name = "Giant",
		Scale = 60,
		MassRequired = 22000000,
		Color = Color3.fromRGB(255, 90, 90),
		Flavor = "Cars are toys again — just not your toys.",
		Unlocks = { "Titan Abilities" },
	},
	{
		Index = 12,
		Id = "Titan",
		Name = "Titan",
		Scale = 120,
		MassRequired = 48000000,
		Color = Color3.fromRGB(255, 200, 60),
		Flavor = "Houses sit at your ankles.",
		Unlocks = { "Titan City", "Ascension" },
	},
	{
		Index = 13,
		Id = "Colossal",
		Name = "Colossal Titan",
		Scale = 200,
		MassRequired = 140000000,
		Color = Color3.fromRGB(255, 160, 40),
		Flavor = "Skyscrapers are landmarks, not obstacles.",
		Unlocks = { "Titan Wilderness" },
	},
	{
		Index = 14,
		Id = "Mountain",
		Name = "Mountain Titan",
		Scale = 300,
		MassRequired = 500000000,
		Color = Color3.fromRGB(200, 120, 255),
		Flavor = "Clouds part around your shoulders.",
		Unlocks = { "Titan Peak" },
	},
	{
		Index = 15,
		Id = "Worldbreaker",
		Name = "Worldbreaker",
		Scale = 340,
		MassRequired = 1100000000,
		Color = Color3.fromRGB(255, 80, 200),
		Flavor = "The whole world fits in a glance.",
		Unlocks = { "Everything" },
	},
}

local SizeConfig = {
	Tiers = Tiers,
	MaxTier = #Tiers,
	HumanTier = 9,
	TitanTier = 12,
	-- Scale continues to creep upward past the last threshold (capped by
	-- GameConfig.MaxScale) so endgame Mass is never pointless.
	OverflowScalePerDoubling = 0.06,
	-- Server re-applies character scale when it drifts by more than this ratio.
	ScaleApplyThreshold = 0.025,
	ScaleApplyMinInterval = 1.5,
	-- Growth sequence (tier-up) tween duration.
	GrowthSequenceDuration = 2.2,
	GrowthSequenceSteps = 12,
}

function SizeConfig.getTier(index: number): SizeTier
	return Tiers[math.clamp(index, 1, #Tiers)]
end

function SizeConfig.getTierById(id: string): SizeTier?
	for _, tier in Tiers do
		if tier.Id == id then
			return tier
		end
	end
	return nil
end

return SizeConfig
