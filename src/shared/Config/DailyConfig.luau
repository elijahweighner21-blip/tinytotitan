--!strict
--[[
	DailyConfig
	Daily / weekly objectives and the login streak.

	Objectives are drawn deterministically from the pools using a seed of
	(UserId, day) so a player sees the same objectives on any server, and the
	client never chooses them. Objective `Event` names match GameEvents fired
	on the server (see server/GameEvents).

	Streak rules are deliberately forgiving: missing a single day keeps the
	streak, missing more only knocks it back by the number of missed days.
]]

export type ObjectiveDef = {
	Id: string,
	Text: string,
	Event: string,
	Target: number,
	Reward: { Mass: number?, GrowthEnergy: number?, XP: number?, TitanShards: number? },
	ZoneScaled: boolean,
	MinTier: number,
}

local DailyPool: { ObjectiveDef } = {
	{ Id = "D_Orbs", Text = "Collect %d Growth Orbs", Event = "OrbCollected", Target = 25, Reward = { Mass = 120, GrowthEnergy = 60, XP = 80 }, ZoneScaled = true, MinTier = 1 },
	{ Id = "D_Challenges", Text = "Complete %d challenges", Event = "ChallengeCompleted", Target = 3, Reward = { Mass = 200, GrowthEnergy = 100, XP = 150, TitanShards = 2 }, ZoneScaled = true, MinTier = 2 },
	{ Id = "D_Discover", Text = "Discover %d locations", Event = "Discovered", Target = 2, Reward = { Mass = 160, GrowthEnergy = 80, XP = 120 }, ZoneScaled = true, MinTier = 1 },
	{ Id = "D_Mass", Text = "Earn %s Mass", Event = "MassEarnedScaled", Target = 400, Reward = { GrowthEnergy = 120, XP = 100 }, ZoneScaled = true, MinTier = 1 },
	{ Id = "D_Enemies", Text = "Defeat %d enemies", Event = "EnemyDefeated", Target = 15, Reward = { Mass = 150, GrowthEnergy = 80, XP = 120 }, ZoneScaled = true, MinTier = 2 },
	{ Id = "D_Break", Text = "Break %d objects", Event = "ObjectBroken", Target = 10, Reward = { Mass = 120, GrowthEnergy = 70, XP = 90 }, ZoneScaled = true, MinTier = 2 },
	{ Id = "D_Quests", Text = "Complete %d quests", Event = "QuestCompleted", Target = 2, Reward = { Mass = 220, GrowthEnergy = 110, XP = 160 }, ZoneScaled = true, MinTier = 1 },
	{ Id = "D_Jumps", Text = "Jump %d times", Event = "Jumped", Target = 150, Reward = { Mass = 80, GrowthEnergy = 40, XP = 60 }, ZoneScaled = true, MinTier = 1 },
	{ Id = "D_Dash", Text = "Dash %d times", Event = "Dashed", Target = 40, Reward = { Mass = 100, GrowthEnergy = 50, XP = 70 }, ZoneScaled = true, MinTier = 4 },
	{ Id = "D_Resources", Text = "Gather %d zone resources", Event = "ResourceGathered", Target = 20, Reward = { Mass = 150, GrowthEnergy = 90, XP = 100 }, ZoneScaled = true, MinTier = 3 },
	{ Id = "D_Events", Text = "Join %d world event", Event = "EventJoined", Target = 1, Reward = { Mass = 180, GrowthEnergy = 90, XP = 120, TitanShards = 2 }, ZoneScaled = true, MinTier = 3 },
	{ Id = "D_Upgrades", Text = "Buy %d upgrades", Event = "UpgradeBought", Target = 3, Reward = { Mass = 100, XP = 80 }, ZoneScaled = true, MinTier = 2 },
}

local WeeklyPool: { ObjectiveDef } = {
	{ Id = "W_Challenges", Text = "Complete %d challenges", Event = "ChallengeCompleted", Target = 20, Reward = { Mass = 1500, GrowthEnergy = 800, XP = 1200, TitanShards = 15 }, ZoneScaled = true, MinTier = 2 },
	{ Id = "W_Bosses", Text = "Defeat %d bosses", Event = "BossDefeated", Target = 3, Reward = { Mass = 2000, GrowthEnergy = 1000, XP = 1500, TitanShards = 20 }, ZoneScaled = true, MinTier = 3 },
	{ Id = "W_Orbs", Text = "Collect %d Growth Orbs", Event = "OrbCollected", Target = 300, Reward = { Mass = 1200, GrowthEnergy = 600, XP = 900, TitanShards = 10 }, ZoneScaled = true, MinTier = 1 },
	{ Id = "W_Discover", Text = "Discover %d locations", Event = "Discovered", Target = 8, Reward = { Mass = 1500, GrowthEnergy = 700, XP = 1100, TitanShards = 12 }, ZoneScaled = true, MinTier = 1 },
	{ Id = "W_Enemies", Text = "Defeat %d enemies", Event = "EnemyDefeated", Target = 150, Reward = { Mass = 1400, GrowthEnergy = 700, XP = 1000, TitanShards = 10 }, ZoneScaled = true, MinTier = 2 },
	{ Id = "W_Events", Text = "Join %d world events", Event = "EventJoined", Target = 5, Reward = { Mass = 1500, GrowthEnergy = 800, XP = 1000, TitanShards = 15 }, ZoneScaled = true, MinTier = 3 },
	{ Id = "W_Quests", Text = "Complete %d quests", Event = "QuestCompleted", Target = 8, Reward = { Mass = 1800, GrowthEnergy = 900, XP = 1400, TitanShards = 15 }, ZoneScaled = true, MinTier = 1 },
}

local DailyConfig = {
	DailyPool = DailyPool,
	WeeklyPool = WeeklyPool,
	DailyCount = 3,
	WeeklyCount = 3,
	-- Login streak rewards (cycles after the last entry; day 7 is the big one).
	StreakRewards = {
		{ GrowthEnergy = 100, XP = 50 },
		{ GrowthEnergy = 200, XP = 80 },
		{ TitanShards = 3, XP = 100 },
		{ GrowthEnergy = 400, XP = 150 },
		{ TitanShards = 5, XP = 200 },
		{ GrowthEnergy = 800, XP = 250 },
		{ TitanShards = 15, XP = 500, Boosts = { Mass2x = 900 } },
	} :: { { [string]: any } },
	-- Streak rewards scale with the player's highest zone so they stay relevant.
	StreakZoneScaled = { GrowthEnergy = true },
	GraceDays = 1,
	VIPStreakBonus = 0.25, -- VIP gets +25% Growth Energy on streak rewards
	DailyShopSlots = 6,
}

function DailyConfig.findObjective(id: string): ObjectiveDef?
	for _, d in DailyPool do
		if d.Id == id then
			return d
		end
	end
	for _, d in WeeklyPool do
		if d.Id == id then
			return d
		end
	end
	return nil
end

-- Days since the Unix epoch at the configured reset hour.
function DailyConfig.dayNumber(unix: number, resetHourUtc: number): number
	return (unix - resetHourUtc * 3600) // 86400
end

-- Weeks start on Monday (the epoch was a Thursday, so shift by 3 days).
function DailyConfig.weekNumber(unix: number, resetHourUtc: number): number
	return (DailyConfig.dayNumber(unix, resetHourUtc) + 3) // 7
end

-- New streak value after logging in on `today` when last login was `lastDay`.
function DailyConfig.nextStreak(streak: number, lastDay: number, today: number): number
	if lastDay <= 0 then
		return 1
	end
	local gap = today - lastDay
	if gap <= 0 then
		return math.max(1, streak)
	elseif gap <= 1 + DailyConfig.GraceDays then
		return streak + 1
	end
	return math.max(1, streak - (gap - 1))
end

return DailyConfig
