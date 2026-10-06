--!strict
--[[
	AchievementService
	Achievements are evaluated from the player's STATE (stats, tier, level,
	discoveries, records) whenever something relevant changes, so they are
	idempotent and self-healing: a missed event can never lose an
	achievement, and nothing can be granted twice (granted ids are stored
	with a timestamp before rewards are handed out).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local AchievementConfig = require(Shared.Config.AchievementConfig)
local DiscoveryConfig = require(Shared.Config.DiscoveryConfig)
local BossConfig = require(Shared.Config.BossConfig)

local ServerRoot = script.Parent.Parent
local Net = require(ServerRoot.Net)
local GameEvents = require(ServerRoot.GameEvents)
local PlayerDataService = require(script.Parent.PlayerDataService)
local RewardService = require(script.Parent.RewardService)
local StatisticsService = require(script.Parent.StatisticsService)
local ProgressionService = require(script.Parent.ProgressionService)

local AchievementService = {}

local oneShotEvents: { [Player]: { [string]: boolean } } = {}
local pending: { [Player]: boolean } = {}

local zoneDiscoveryTotals: { [string]: number } = {}
for _, d in DiscoveryConfig.List do
	zoneDiscoveryTotals[d.Zone] = (zoneDiscoveryTotals[d.Zone] or 0) + 1
end

local function countDiscoveries(data: any, zone: string?): number
	local n = 0
	for id in data.Discoveries do
		local def = DiscoveryConfig.get(id)
		if def and (not zone or def.Zone == zone) then
			n += 1
		end
	end
	return n
end

local function titanMedals(data: any): number
	local n = 0
	for _, record in data.Challenges do
		if record.Medal >= 4 then
			n += 1
		end
	end
	return n
end

local function allBosses(data: any): boolean
	for _, boss in BossConfig.List do
		local record = data.Bosses[boss.Id]
		if not record or record.Kills <= 0 then
			return false
		end
	end
	return true
end

local function mobilityComplete(data: any): boolean
	local SkillConfig = require(Shared.Config.SkillConfig)
	for _, s in SkillConfig.List do
		if s.Branch == "Mobility" and not data.Skills[s.Id] then
			return false
		end
	end
	return true
end

local function conditionMet(player: Player, data: any, ach: AchievementConfig.Achievement): boolean
	local c = ach.Condition
	if c.Stat then
		return (data.Stats[c.Stat] or 0) >= (c.Value or 0)
	elseif c.Tier then
		return data.Progress.HighestTier >= c.Tier
	elseif c.Level then
		return data.Progress.Level >= c.Level
	elseif c.Discoveries then
		if c.Zone then
			local total = zoneDiscoveryTotals[c.Zone] or 0
			local need = if c.Discoveries == 0 then total else c.Discoveries
			return need > 0 and countDiscoveries(data, c.Zone) >= need
		end
		return countDiscoveries(data, nil) >= c.Discoveries
	elseif c.Event then
		local event = c.Event
		local count = c.Count or 1
		if event == "Ascended" then
			return data.Ascension.Count >= count
		elseif event == "TitanMedal" then
			return titanMedals(data) >= count
		elseif event == "AllBosses" then
			return allBosses(data)
		elseif event == "MobilityComplete" then
			return mobilityComplete(data)
		elseif string.sub(event, 1, 6) == "Quest:" then
			return data.Quests.Completed[string.sub(event, 7)] ~= nil
		elseif string.sub(event, 1, 6) == "Medal:" then
			local id, medal = string.match(event, "^Medal:([%w_]+):(%d)$")
			local record = id and data.Challenges[id]
			return record ~= nil and record.Medal >= tonumber(medal :: string)
		end
		local seen = oneShotEvents[player]
		return seen ~= nil and seen[event] == true
	end
	return false
end

local function evaluate(player: Player)
	pending[player] = nil
	local data = PlayerDataService:Get(player)
	if not data then
		return
	end
	for _, ach in AchievementConfig.List do
		if not data.Achievements[ach.Id] and conditionMet(player, data, ach) then
			data.Achievements[ach.Id] = os.time()
			PlayerDataService:Changed(player, "Achievements")
			RewardService:Grant(player, ach.Rewards :: any, { Source = "Achievement", SourceId = ach.Id, Notify = false, Multipliers = false })
			Net.signal(player, "Achievement", { Id = ach.Id, Name = ach.Name, Description = ach.Description, Rewards = ach.Rewards })
			GameEvents.fire("Achievement", player, ach.Id)
		end
	end
end

-- Debounced evaluation (many stats change in bursts).
function AchievementService:Queue(player: Player)
	if pending[player] then
		return
	end
	pending[player] = true
	task.delay(0.5, function()
		if player.Parent then
			evaluate(player)
		else
			pending[player] = nil
		end
	end)
end

function AchievementService:Start()
	PlayerDataService.Loaded:Connect(function(player)
		AchievementService:Queue(player)
	end)
	StatisticsService.Changed:Connect(function(player)
		AchievementService:Queue(player)
	end)
	ProgressionService.TierChanged:Connect(function(player)
		AchievementService:Queue(player)
	end)
	ProgressionService.LevelChanged:Connect(function(player)
		AchievementService:Queue(player)
	end)
	for _, name in { "Discovered", "ChallengeCompleted", "BossDefeated", "QuestCompleted", "Ascended", "SkillUnlocked", "TitanMedal" } do
		GameEvents.on(name, function(player)
			AchievementService:Queue(player)
		end)
	end
	GameEvents.on("TitanHomecoming", function(player)
		local seen: { [string]: boolean } = oneShotEvents[player] or {}
		oneShotEvents[player] = seen
		seen.TitanHomecoming = true
		AchievementService:Queue(player)
	end)
	Players.PlayerRemoving:Connect(function(player)
		oneShotEvents[player] = nil
		pending[player] = nil
	end)
end

return AchievementService
