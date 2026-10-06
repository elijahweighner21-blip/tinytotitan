--!strict
--[[
	WorldEventConfig
	Randomised server-wide events. WorldEventService picks one every
	Interval (weighted, respecting MinTier = "someone on the server is at least
	this big") and runs the matching handler. Each handler owns a Trove so the
	event always cleans up after itself, even if it errors.
]]

export type WorldEvent = {
	Id: string,
	Name: string,
	Description: string,
	Duration: number,
	Weight: number,
	MinTier: number,
	Zones: { string }?, -- candidate zones (nil = anywhere players are)
	Color: Color3,
	Icon: string,
	Params: { [string]: any },
}

local List: { WorldEvent } = {
	{
		Id = "GrowthSurge",
		Name = "Growth Surge",
		Description = "All Mass gains +50% server-wide!",
		Duration = 180,
		Weight = 3,
		MinTier = 1,
		Color = Color3.fromRGB(120, 255, 140),
		Icon = "🌱",
		Params = { MassBonus = 0.5 },
	},
	{
		Id = "GoldenCrumb",
		Name = "The Golden Crumb",
		Description = "A golden crumb has appeared somewhere. Everyone who finds it is rewarded!",
		Duration = 150,
		Weight = 3,
		MinTier = 1,
		Color = Color3.fromRGB(255, 210, 60),
		Icon = "🥐",
		Params = { RewardWeight = 6 },
	},
	{
		Id = "BugInvasion",
		Name = "Bug Invasion",
		Description = "Bugs are swarming! Defeat them for bonus rewards.",
		Duration = 150,
		Weight = 2,
		MinTier = 2,
		Zones = { "FloorWorld", "Bedroom", "Kitchen", "Backyard" },
		Color = Color3.fromRGB(200, 120, 60),
		Icon = "🐜",
		Params = { Count = 14, RewardMultiplier = 2 },
	},
	{
		Id = "MeteorFragment",
		Name = "Meteor Fragment",
		Description = "A shard meteor is falling! Get to the crash site.",
		Duration = 120,
		Weight = 2,
		MinTier = 4,
		Color = Color3.fromRGB(90, 200, 255),
		Icon = "☄️",
		Params = { Shards = 5, RewardWeight = 5 },
	},
	{
		Id = "SupplyCrate",
		Name = "Supply Drop",
		Description = "A supply crate is parachuting in. Break it open!",
		Duration = 120,
		Weight = 2,
		MinTier = 3,
		Color = Color3.fromRGB(255, 170, 60),
		Icon = "📦",
		Params = { Hits = 12, RewardWeight = 4 },
	},
	{
		Id = "PowerOutage",
		Name = "Power Outage",
		Description = "The lights are out! Glowing orbs appear in the dark.",
		Duration = 120,
		Weight = 2,
		MinTier = 2,
		Zones = { "FloorWorld", "Bedroom", "Kitchen" },
		Color = Color3.fromRGB(120, 120, 255),
		Icon = "🔌",
		Params = { Orbs = 25 },
	},
	{
		Id = "RarePortal",
		Name = "Rare Portal",
		Description = "A portal to a bonus pocket dimension has opened!",
		Duration = 120,
		Weight = 1,
		MinTier = 5,
		Color = Color3.fromRGB(200, 100, 255),
		Icon = "🌀",
		Params = { Orbs = 30, RewardWeight = 3 },
	},
	{
		Id = "TitanStorm",
		Name = "Titan Storm",
		Description = "Lightning strikes charge the ground with Titan Cells. Avoid the strikes, collect the cells!",
		Duration = 150,
		Weight = 2,
		MinTier = 12,
		Zones = { "TitanCity", "TitanWilderness" },
		Color = Color3.fromRGB(255, 240, 120),
		Icon = "⛈️",
		Params = { Strikes = 30, Cells = 3 },
	},
}

local byId: { [string]: WorldEvent } = {}
for _, e in List do
	byId[e.Id] = e
end

local WorldEventConfig = {
	List = List,
	FirstEventDelay = 240,
	IntervalMin = 420,
	IntervalMax = 660,
	ParticipationRewardWeight = 1.5,
}

function WorldEventConfig.get(id: string): WorldEvent?
	return byId[id]
end

return WorldEventConfig
