--!strict
--[[
	QuestService
	Runs the quest framework (rules in Logic/QuestLogic):
	  * auto-starts story quests when their prerequisites/size are met
	  * advances objectives from GameEvents (server-side events only — the
	    client can never claim objective progress)
	  * completes quests exactly once: the quest is moved from Active to
	    Completed in the same step that grants its rewards, and both land in
	    the same save, so disconnect timing can't duplicate rewards
	  * accept / abandon / track requests with validation
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local QuestConfig = require(Shared.Config.QuestConfig)
local Guard = require(Shared.Util.Guard)

local ServerRoot = script.Parent.Parent
local Net = require(ServerRoot.Net)
local GameEvents = require(ServerRoot.GameEvents)
local QuestLogic = require(ServerRoot.Logic.QuestLogic)
local PlayerDataService = require(script.Parent.PlayerDataService)
local ProgressionService = require(script.Parent.ProgressionService)
local RewardService = require(script.Parent.RewardService)
local StatisticsService = require(script.Parent.StatisticsService)
local ZoneService = require(script.Parent.ZoneService)

local QuestService = {}

local function context(player: Player, data: any): QuestLogic.Context
	return {
		Tier = ProgressionService:GetTier(player),
		Level = data.Progress.Level,
		Discoveries = data.Discoveries,
		Zone = ZoneService:GetZone(player),
	}
end

local function complete(player: Player, questId: string)
	local data = PlayerDataService:Get(player)
	local def = QuestConfig.get(questId)
	if not data or not def or not data.Quests.Active[questId] or data.Quests.Completed[questId] then
		return
	end
	data.Quests.Active[questId] = nil
	data.Quests.Completed[questId] = os.time()
	if data.Quests.Tracked == questId then
		data.Quests.Tracked = def.NextQuest or ""
	end
	PlayerDataService:Changed(player, "Quests")
	local granted = RewardService:Grant(
		player,
		def.Rewards,
		{ Source = "Quest", SourceId = questId, Category = "Quest", Notify = false }
	)
	StatisticsService:Increment(player, "QuestsCompleted")
	Net.signal(player, "QuestComplete", {
		Id = questId,
		Name = def.Name,
		Story = def.Story,
		Next = def.NextQuest,
		Mass = granted.Mass,
		GrowthEnergy = granted.GrowthEnergy,
		XP = granted.XP,
		TitanShards = granted.TitanShards,
		ExplorationTokens = granted.ExplorationTokens,
		Titles = granted.Titles,
		Items = granted.Items,
	})
	GameEvents.fire("QuestCompleted", player, questId)
	GameEvents.fire("Quest:" .. questId, player)
end

local function start(player: Player, questId: string, bypassLimit: boolean): (boolean, string?)
	local data = PlayerDataService:Get(player)
	if not data then
		return false, "Loading"
	end
	local ctx = context(player, data)
	local ok, reason = QuestLogic.isAvailable(questId, data.Quests, ctx)
	if not ok then
		return false, reason
	end
	if not bypassLimit and QuestLogic.activeCount(data.Quests) >= QuestConfig.MaxActive then
		return false, "Too many active quests (max " .. QuestConfig.MaxActive .. ")"
	end
	local active = QuestLogic.newProgress(questId, ctx, os.time())
	data.Quests.Active[questId] = active
	if data.Quests.Tracked == "" or not data.Quests.Active[data.Quests.Tracked] then
		data.Quests.Tracked = questId
	end
	PlayerDataService:Changed(player, "Quests")
	local def = QuestConfig.get(questId)
	Net.signal(player, "QuestUpdate", { Id = questId, Started = true, Name = if def then def.Name else questId })
	if QuestLogic.isComplete(questId, active) then
		complete(player, questId)
	end
	return true, nil
end

local function autoStart(player: Player)
	local data = PlayerDataService:Get(player)
	if not data then
		return
	end
	for _, questId in QuestLogic.autoStartable(data.Quests, context(player, data)) do
		start(player, questId, true)
	end
end

local function refreshState(player: Player)
	local data = PlayerDataService:Get(player)
	if not data then
		return
	end
	local ctx = context(player, data)
	local changed = false
	for questId, active in data.Quests.Active do
		if QuestLogic.applyState(questId, active, ctx) then
			changed = true
		end
	end
	if changed then
		PlayerDataService:Changed(player, "Quests")
	end
	for questId, active in table.clone(data.Quests.Active) do
		if QuestLogic.isComplete(questId, active) then
			complete(player, questId)
		end
	end
	autoStart(player)
end

local function onEvent(eventName: string, player: Player, ...: any)
	if not QuestLogic.EventMap[eventName] then
		return
	end
	local data = PlayerDataService:Get(player)
	if not data then
		return
	end
	local changed = false
	local finished = {}
	for questId, active in data.Quests.Active do
		if QuestLogic.applyEvent(questId, active, eventName, ...) then
			changed = true
			if QuestLogic.isComplete(questId, active) then
				table.insert(finished, questId)
			end
		end
	end
	if changed then
		PlayerDataService:Changed(player, "Quests")
	end
	for _, questId in finished do
		complete(player, questId)
	end
end

function QuestService:StartQuest(player: Player, questId: string): (boolean, string?)
	return start(player, questId, false)
end

-- Quests offered by an NPC with their state for the dialogue UI.
function QuestService:GetGiverQuests(
	player: Player,
	npcId: string
): { { Id: string, Name: string, State: string, Reason: string? } }
	local data = PlayerDataService:Get(player)
	local out = {}
	if not data then
		return out
	end
	local ctx = context(player, data)
	for _, def in QuestConfig.List do
		if def.Giver == npcId then
			local state: string
			local reason: string? = nil
			if data.Quests.Completed[def.Id] then
				state = "Completed"
			elseif data.Quests.Active[def.Id] then
				state = "Active"
			else
				local ok, why = QuestLogic.isAvailable(def.Id, data.Quests, ctx)
				state = if ok then "Available" else "Locked"
				reason = why
			end
			table.insert(out, { Id = def.Id, Name = def.Name, State = state, Reason = reason })
		end
	end
	return out
end

function QuestService:Init()
	Net.onRequest("AcceptQuest", Guard.shape({ Id = Guard.id() }), function(player, payload)
		local ok, reason = start(player, payload.Id, false)
		return { ok = ok, err = reason }
	end)
	Net.onRequest("AbandonQuest", Guard.shape({ Id = Guard.id() }), function(player, payload)
		local data = PlayerDataService:Get(player)
		local def = QuestConfig.get(payload.Id)
		if not data or not def or not data.Quests.Active[payload.Id] then
			return { ok = false, err = "Not active" }
		end
		if QuestConfig.NonAbandonable[def.Category] then
			return { ok = false, err = "Story quests can't be abandoned" }
		end
		data.Quests.Active[payload.Id] = nil
		if data.Quests.Tracked == payload.Id then
			data.Quests.Tracked = ""
		end
		PlayerDataService:Changed(player, "Quests")
		return { ok = true }
	end)
	Net.onAction("TrackQuest", Guard.id(), function(player, questId)
		local data = PlayerDataService:Get(player)
		if data and data.Quests.Active[questId] then
			data.Quests.Tracked = questId
			PlayerDataService:Changed(player, "Quests")
		end
	end)
end

function QuestService:Start()
	GameEvents.onAny(onEvent)
	PlayerDataService.Loaded:Connect(function(player)
		-- Let zone tracking settle first so EnterZone objectives see the zone.
		task.delay(1.5, function()
			if player.Parent then
				refreshState(player)
			end
		end)
	end)
	ProgressionService.TierChanged:Connect(refreshState)
	ProgressionService.LevelChanged:Connect(refreshState)
	GameEvents.on("QuestCompleted", function(player)
		autoStart(player)
	end)
	Players.PlayerRemoving:Connect(function() end)
end

return QuestService
