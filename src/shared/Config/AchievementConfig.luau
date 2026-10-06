--!strict
--[[
	AchievementConfig
	Achievements are evaluated by AchievementService whenever a relevant stat
	or event changes. Condition forms:
	  { Stat = "<Stats key>", Value = n }       a lifetime statistic reaches n
	  { Tier = n }                              highest size tier reaches n
	  { Level = n }                             player level reaches n
	  { Event = "<GameEvents name>", Count = n } (Count defaults to 1)
	  { Discoveries = n, Zone = "Id"? }        discoveries (optionally per zone, n = 0 means all)
]]

export type Condition = {
	Stat: string?,
	Value: number?,
	Tier: number?,
	Level: number?,
	Event: string?,
	Count: number?,
	Discoveries: number?,
	Zone: string?,
	Boss: string?,
}

export type Achievement = {
	Id: string,
	Name: string,
	Description: string,
	Category: string,
	Condition: Condition,
	Rewards: { TitanShards: number?, XP: number?, Titles: { string }?, Cosmetics: { string }? },
	Hidden: boolean?,
}

local List: { Achievement } = {
	-- Growth
	{ Id = "FirstGrowth", Name = "First Growth", Description = "Grow for the first time.", Category = "Growth", Condition = { Tier = 2 }, Rewards = { TitanShards = 2, XP = 50, Titles = { "TinyExplorer" } } },
	{ Id = "AntSized", Name = "Ant-Sized", Description = "Reach Ant-Sized.", Category = "Growth", Condition = { Tier = 3 }, Rewards = { TitanShards = 3, XP = 100, Titles = { "AntSized" } } },
	{ Id = "ToySized", Name = "Toy Story", Description = "Reach Toy-Sized.", Category = "Growth", Condition = { Tier = 6 }, Rewards = { TitanShards = 5, XP = 300 } },
	{ Id = "HumanSized", Name = "Human-Sized", Description = "Reach Human-Sized.", Category = "Growth", Condition = { Tier = 9 }, Rewards = { TitanShards = 10, XP = 1000, Titles = { "NeighborhoodGiant" } } },
	{ Id = "GiantSized", Name = "Giant", Description = "Reach Giant.", Category = "Growth", Condition = { Tier = 11 }, Rewards = { TitanShards = 15, XP = 2000, Titles = { "CityCrusher" } } },
	{ Id = "TitanSized", Name = "Titan", Description = "Reach Titan.", Category = "Growth", Condition = { Tier = 12 }, Rewards = { TitanShards = 25, XP = 4000, Titles = { "Titan" } } },
	{ Id = "Worldbreaker", Name = "Worldbreaker", Description = "Reach the final size tier.", Category = "Growth", Condition = { Tier = 15 }, Rewards = { TitanShards = 60, XP = 10000 } },
	{ Id = "MillionMass", Name = "Million Mass", Description = "Earn 1,000,000 Mass in total.", Category = "Growth", Condition = { Stat = "TotalMassEarned", Value = 1e6 }, Rewards = { TitanShards = 10, XP = 1500, Titles = { "Millionaire" } } },
	{ Id = "BillionMass", Name = "Billion Mass", Description = "Earn 1,000,000,000 Mass in total.", Category = "Growth", Condition = { Stat = "TotalMassEarned", Value = 1e9 }, Rewards = { TitanShards = 50, XP = 8000 } },
	{ Id = "FirstAscension", Name = "First Ascension", Description = "Ascend for the first time.", Category = "Growth", Condition = { Event = "Ascended" }, Rewards = { TitanShards = 25, XP = 2000, Titles = { "Ascended" }, Cosmetics = { "AscendedName" } } },
	{ Id = "FiveAscensions", Name = "Eternal", Description = "Ascend 5 times.", Category = "Growth", Condition = { Event = "Ascended", Count = 5 }, Rewards = { TitanShards = 60, XP = 6000 } },
	{ Id = "Level10", Name = "Seasoned", Description = "Reach level 10.", Category = "Growth", Condition = { Level = 10 }, Rewards = { TitanShards = 5, XP = 0 } },
	{ Id = "Level50", Name = "Veteran", Description = "Reach level 50.", Category = "Growth", Condition = { Level = 50 }, Rewards = { TitanShards = 25 } },
	-- Exploration
	{ Id = "FirstDiscovery", Name = "Explorer", Description = "Discover your first location.", Category = "Exploration", Condition = { Discoveries = 1 }, Rewards = { TitanShards = 1, XP = 50 } },
	{ Id = "Discoverer25", Name = "Cartographer", Description = "Discover 25 locations.", Category = "Exploration", Condition = { Discoveries = 25 }, Rewards = { TitanShards = 10, XP = 1200 } },
	{ Id = "BedroomComplete", Name = "Room Conqueror", Description = "Discover every Bedroom location.", Category = "Exploration", Condition = { Discoveries = 0, Zone = "Bedroom" }, Rewards = { TitanShards = 8, XP = 600, Titles = { "RoomConqueror" } } },
	{ Id = "KitchenConqueror", Name = "Kitchen Conqueror", Description = "Discover every Kitchen location.", Category = "Exploration", Condition = { Discoveries = 0, Zone = "Kitchen" }, Rewards = { TitanShards = 10, XP = 900, Titles = { "KitchenConqueror" } } },
	{ Id = "Secrets10", Name = "Secret Seeker", Description = "Find 10 secrets.", Category = "Exploration", Condition = { Stat = "SecretsFound", Value = 10 }, Rewards = { TitanShards = 10, XP = 800 } },
	{ Id = "Secrets25", Name = "Secret Keeper", Description = "Find 25 secrets.", Category = "Exploration", Condition = { Stat = "SecretsFound", Value = 25 }, Rewards = { TitanShards = 25, XP = 2000, Titles = { "SecretKeeper" }, Cosmetics = { "SecretAura" } } },
	{ Id = "Secrets100", Name = "100 Secrets", Description = "Find 100 secrets and collectibles.", Category = "Exploration", Condition = { Stat = "CollectiblesFound", Value = 100 }, Rewards = { TitanShards = 40, XP = 4000 } },
	{ Id = "Orbs100", Name = "Crumb Hunter", Description = "Collect 100 Growth Orbs.", Category = "Exploration", Condition = { Stat = "OrbsCollected", Value = 100 }, Rewards = { TitanShards = 3, XP = 300, Titles = { "CrumbHunter" } } },
	{ Id = "Orbs1000", Name = "Orb Maniac", Description = "Collect 1,000 Growth Orbs.", Category = "Exploration", Condition = { Stat = "OrbsCollected", Value = 1000 }, Rewards = { TitanShards = 15, XP = 1500 } },
	{ Id = "Marathon", Name = "Marathon", Description = "Travel 1,000,000 studs.", Category = "Exploration", Condition = { Stat = "Distance", Value = 1e6 }, Rewards = { TitanShards = 10, XP = 1000 } },
	-- Movement
	{ Id = "Jumper", Name = "Bouncy", Description = "Jump 1,000 times.", Category = "Movement", Condition = { Stat = "Jumps", Value = 1000 }, Rewards = { TitanShards = 3, XP = 300 } },
	{ Id = "Dasher", Name = "Blink", Description = "Dash 500 times.", Category = "Movement", Condition = { Stat = "Dashes", Value = 500 }, Rewards = { TitanShards = 5, XP = 500 } },
	{ Id = "MaxMovement", Name = "Maximum Movement", Description = "Unlock every Mobility skill.", Category = "Movement", Condition = { Event = "MobilityComplete" }, Rewards = { TitanShards = 15, XP = 1500 } },
	-- Challenges
	{ Id = "FirstChallenge", Name = "Challenger", Description = "Complete a challenge.", Category = "Challenges", Condition = { Stat = "ChallengesCompleted", Value = 1 }, Rewards = { TitanShards = 2, XP = 100 } },
	{ Id = "Challenges50", Name = "Competitor", Description = "Complete 50 challenges.", Category = "Challenges", Condition = { Stat = "ChallengesCompleted", Value = 50 }, Rewards = { TitanShards = 15, XP = 1500 } },
	{ Id = "RoofRunner", Name = "Roof Runner", Description = "Earn Gold or better in Rooftop Rush.", Category = "Challenges", Condition = { Event = "Medal:RooftopRush:3" }, Rewards = { TitanShards = 10, XP = 800, Titles = { "RoofRunner" } } },
	{ Id = "TitanMedals10", Name = "Speedrunner", Description = "Earn 10 Titan medals.", Category = "Challenges", Condition = { Event = "TitanMedal", Count = 10 }, Rewards = { TitanShards = 30, XP = 3000, Titles = { "Speedrunner" }, Cosmetics = { "SpeedTrail" } } },
	-- Combat
	{ Id = "FirstBlood", Name = "Squish", Description = "Defeat an enemy.", Category = "Combat", Condition = { Stat = "EnemiesDefeated", Value = 1 }, Rewards = { TitanShards = 1, XP = 50 } },
	{ Id = "Enemies500", Name = "Exterminator", Description = "Defeat 500 enemies.", Category = "Combat", Condition = { Stat = "EnemiesDefeated", Value = 500 }, Rewards = { TitanShards = 15, XP = 2000 } },
	{ Id = "BossSlayer", Name = "Boss Slayer", Description = "Defeat a boss.", Category = "Combat", Condition = { Stat = "BossesDefeated", Value = 1 }, Rewards = { TitanShards = 5, XP = 500 } },
	{ Id = "AllBosses", Name = "Giant Killer", Description = "Defeat every boss.", Category = "Combat", Condition = { Event = "AllBosses" }, Rewards = { TitanShards = 50, XP = 6000 } },
	{ Id = "Wrecker", Name = "Wrecking Ball", Description = "Break 200 objects.", Category = "Combat", Condition = { Stat = "ObjectsBroken", Value = 200 }, Rewards = { TitanShards = 8, XP = 900 } },
	-- Quests / social
	{ Id = "Quests10", Name = "Helpful", Description = "Complete 10 quests.", Category = "Quests", Condition = { Stat = "QuestsCompleted", Value = 10 }, Rewards = { TitanShards = 5, XP = 500 } },
	{ Id = "StoryComplete", Name = "The End?", Description = "Complete the main story.", Category = "Quests", Condition = { Event = "Quest:ColossusAwakens" }, Rewards = { TitanShards = 50, XP = 5000, Titles = { "Worldbreaker" } } },
	{ Id = "EventJoiner", Name = "Party Animal", Description = "Take part in 10 world events.", Category = "Quests", Condition = { Stat = "EventsJoined", Value = 10 }, Rewards = { TitanShards = 10, XP = 1000 } },
	{ Id = "Homecoming", Name = "Never Forgot", Description = "Return to the Floor World as a Titan.", Category = "Exploration", Condition = { Event = "TitanHomecoming" }, Rewards = { TitanShards = 15, XP = 1500, Titles = { "NeverForgot" } }, Hidden = true },
}

local byId: { [string]: Achievement } = {}
for _, a in List do
	assert(byId[a.Id] == nil, "duplicate achievement " .. a.Id)
	byId[a.Id] = a
end

local AchievementConfig = {
	List = List,
	Categories = { "Growth", "Exploration", "Movement", "Challenges", "Combat", "Quests" },
}

function AchievementConfig.get(id: string): Achievement?
	return byId[id]
end

return AchievementConfig
