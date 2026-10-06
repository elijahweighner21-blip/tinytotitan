--!strict
--[[
	DailyService
	Daily + weekly objectives and the login streak (rules in DailyConfig /
	Logic/DailyLogic). Objectives roll over at the configured UTC hour, even
	for players who stay online across the reset. Claims are validated
	(complete + unclaimed) and marked claimed in the same step as the reward.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local DailyConfig = require(Shared.Config.DailyConfig)
local GameConfig = require(Shared.Config.GameConfig)
local MonetizationConfig = require(Shared.Config.MonetizationConfig)
local Types = require(Shared.Types)
local Guard = require(Shared.Util.Guard)

local ServerRoot = script.Parent.Parent
local Net = require(ServerRoot.Net)
local GameEvents = require(ServerRoot.GameEvents)
local DailyLogic = require(ServerRoot.Logic.DailyLogic)
local PlayerDataService = require(script.Parent.PlayerDataService)
local RewardService = require(script.Parent.RewardService)
local ProgressionService = require(script.Parent.ProgressionService)
local EntitlementService = require(script.Parent.EntitlementService)

local DailyService = {}

local function today(): number
	return DailyConfig.dayNumber(os.time(), GameConfig.DailyResetHourUtc)
end

local function thisWeek(): number
	return DailyConfig.weekNumber(os.time(), GameConfig.DailyResetHourUtc)
end

local function roll(player: Player)
	local data = PlayerDataService:Get(player)
	if not data then
		return
	end
	local daily = data.Daily
	local day = today()
	local week = thisWeek()
	local highest = data.Progress.HighestTier
	local changed = false
	if daily.Day ~= day then
		daily.Day = day
		daily.Objectives = DailyLogic.pick(DailyConfig.DailyPool, DailyConfig.DailyCount, DailyLogic.dailySeed(player.UserId, day), highest)
		changed = true
	end
	if daily.Week ~= week then
		daily.Week = week
		daily.Weekly = DailyLogic.pick(DailyConfig.WeeklyPool, DailyConfig.WeeklyCount, DailyLogic.weeklySeed(player.UserId, week), highest)
		changed = true
	end
	if daily.LoginDay ~= day then
		daily.Streak = DailyConfig.nextStreak(daily.Streak, daily.LoginDay, day)
		daily.LoginDay = day
		;(data.Stats :: any).Logins += 1
		changed = true
	end
	if changed then
		PlayerDataService:Changed(player, "Daily")
	end
end

local function zoneScale(player: Player): number
	return ProgressionService:GetZoneScale(player)
end

local function objectiveReward(player: Player, def: DailyConfig.ObjectiveDef): Types.Reward
	local reward: any = table.clone(def.Reward :: any)
	if def.ZoneScaled then
		local scale = zoneScale(player)
		if reward.Mass then
			reward.Mass = math.floor(reward.Mass * scale)
		end
		if reward.GrowthEnergy then
			reward.GrowthEnergy = math.floor(reward.GrowthEnergy * scale)
		end
		if reward.XP then
			reward.XP = math.floor(reward.XP * math.sqrt(scale))
		end
	end
	return reward
end

local function streakReward(player: Player, streak: number): Types.Reward
	local list = DailyConfig.StreakRewards
	local base = list[((math.max(1, streak) - 1) % #list) + 1]
	local reward = table.clone(base)
	if reward.GrowthEnergy then
		reward.GrowthEnergy = math.floor(reward.GrowthEnergy * zoneScale(player))
		if EntitlementService:Owns(player, "VIP") then
			reward.GrowthEnergy = math.floor(reward.GrowthEnergy * (1 + MonetizationConfig.VIPPerks.DailyBonus))
		end
	end
	return reward :: any
end

-- "Earn X Mass" objectives are measured in zone-normalised Mass.
local EVENT_AMOUNT: { [string]: (...any) -> (string, number) } = {
	MassEarned = function(_amount: any, scaled: any)
		return "MassEarnedScaled", if type(scaled) == "number" then scaled else 0
	end,
	ResourceGathered = function(_resource: any, amount: any)
		return "ResourceGathered", if type(amount) == "number" then amount else 0
	end,
}

local function onEvent(eventName: string, player: Player, ...: any)
	local data = PlayerDataService:Get(player)
	if not data then
		return
	end
	local name, amount = eventName, 1
	local converter = EVENT_AMOUNT[eventName]
	if converter then
		name, amount = converter(...)
	end
	if amount <= 0 then
		return
	end
	local a = DailyLogic.applyEvent(data.Daily.Objectives, name, amount)
	local b = DailyLogic.applyEvent(data.Daily.Weekly, name, amount)
	if a or b then
		PlayerDataService:Changed(player, "Daily")
	end
end

function DailyService:Init()
	Net.onRequest(
		"ClaimDaily",
		Guard.shape({ Kind = Guard.oneOf({ "Login", "Daily", "Weekly" }), Index = Guard.optional(Guard.integer(1, 10)) }),
		function(player, payload)
			roll(player)
			local data = PlayerDataService:Get(player)
			if not data then
				return { ok = false }
			end
			local daily = data.Daily
			if payload.Kind == "Login" then
				if daily.LoginClaimedDay == daily.LoginDay then
					return { ok = false, err = "Already claimed today" }
				end
				daily.LoginClaimedDay = daily.LoginDay
				PlayerDataService:Changed(player, "Daily")
				RewardService:Grant(player, streakReward(player, daily.Streak), { Source = "LoginStreak", Multipliers = false })
				return { ok = true, streak = daily.Streak }
			end
			local list: { DailyLogic.Slot } = if payload.Kind == "Daily" then daily.Objectives else daily.Weekly
			local slot = list[payload.Index or 0]
			if not DailyLogic.canClaim(slot) then
				return { ok = false, err = "Not complete yet" }
			end
			slot.Claimed = true
			PlayerDataService:Changed(player, "Daily")
			local def = DailyConfig.findObjective(slot.Id)
			if def then
				RewardService:Grant(player, objectiveReward(player, def), { Source = payload.Kind, SourceId = def.Id })
			end
			return { ok = true }
		end
	)
end

function DailyService:Start()
	PlayerDataService.Loaded:Connect(roll)
	GameEvents.onAny(onEvent)
	-- Roll over for players online across the daily reset.
	task.spawn(function()
		while true do
			task.wait(60)
			for _, player in Players:GetPlayers() do
				roll(player)
			end
		end
	end)
end

return DailyService
