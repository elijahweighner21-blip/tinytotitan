--!strict
--[[
	TutorialService
	Teach-by-playing onboarding. Steps advance only from server-side
	GameEvents (TutorialConfig), never because the client says so. The
	client reads Tutorial.Step from replicated data to show a one-line hint.
	A small completion reward is granted once.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local TutorialConfig = require(Shared.Config.TutorialConfig)
local Guard = require(Shared.Util.Guard)

local ServerRoot = script.Parent.Parent
local Net = require(ServerRoot.Net)
local GameEvents = require(ServerRoot.GameEvents)
local PlayerDataService = require(script.Parent.PlayerDataService)
local RewardService = require(script.Parent.RewardService)
local StatisticsService = require(script.Parent.StatisticsService)

local TutorialService = {}

local counts: { [Player]: number } = {}

-- Steps can also be satisfied by what the player has already done, so
-- doing things out of order (growing before buying the first upgrade) never
-- leaves the tutorial waiting for an event that already happened.
local ALREADY_DONE: { [string]: (data: any) -> boolean } = {
	Move = function(data)
		return data.Stats.Distance > 0
	end,
	Jump = function(data)
		return data.Stats.Jumps > 0
	end,
	Orb = function(data)
		return data.Stats.OrbsCollected > 0
	end,
	Parkour = function(data)
		return next(data.Discoveries) ~= nil
	end,
	Mass = function(data)
		return data.Stats.OrbsCollected >= 3 or data.Progress.HighestTier >= 2
	end,
	Upgrade = function(data)
		return data.Stats.UpgradesBought > 0
	end,
	Grow = function(data)
		return data.Progress.HighestTier >= 2
	end,
}

local function complete(player: Player, data: any, index: number)
	counts[player] = 0
	data.Tutorial.Step = index
	if index >= #TutorialConfig.Steps then
		data.Tutorial.Done = true
		RewardService:Grant(
			player,
			{ GrowthEnergy = 60, TitanShards = 5, XP = 80 },
			{ Source = "Tutorial", Multipliers = false }
		)
		Net.signal(player, "Notify", { Kind = "Success", Text = "Tutorial complete! Keep growing." })
	end
	PlayerDataService:Changed(player, "Tutorial")
end

local function catchUp(player: Player)
	local data = PlayerDataService:Get(player)
	while data and not data.Tutorial.Done do
		local index = data.Tutorial.Step + 1
		local step = TutorialConfig.Steps[index]
		local check = step and ALREADY_DONE[step.Id]
		if not check or not check(data) then
			return
		end
		complete(player, data, index)
	end
end

local function advance(player: Player, eventName: string)
	local data = PlayerDataService:Get(player)
	if not data or data.Tutorial.Done then
		return
	end
	local index = data.Tutorial.Step + 1
	local step = TutorialConfig.Steps[index]
	if not step then
		return
	end
	if step.Event == eventName then
		counts[player] = (counts[player] or 0) + 1
		if counts[player] >= (step.Count or 1) then
			complete(player, data, index)
		end
	end
	catchUp(player)
end

function TutorialService:Init()
	-- Clients may acknowledge/skip hints; skipping never grants rewards.
	Net.onAction("Tutorial", Guard.shape({ Skip = Guard.boolean() }), function(player, payload)
		local data = PlayerDataService:Get(player)
		if data and payload.Skip and not data.Tutorial.Done then
			data.Tutorial.Done = true
			data.Tutorial.Step = #TutorialConfig.Steps
			PlayerDataService:Changed(player, "Tutorial")
		end
	end)
end

function TutorialService:Start()
	GameEvents.onAny(function(name, player)
		advance(player, name)
	end)
	-- "Moved" is detected server-side from the distance statistic.
	StatisticsService.Changed:Connect(function(player, key)
		if key == "Distance" then
			advance(player, "Moved")
		end
	end)
	PlayerDataService.Loaded:Connect(function(player)
		catchUp(player)
	end)
	game:GetService("Players").PlayerRemoving:Connect(function(player)
		counts[player] = nil
	end)
end

return TutorialService
