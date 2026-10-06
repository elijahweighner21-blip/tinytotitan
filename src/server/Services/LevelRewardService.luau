--!strict
--[[
	LevelRewardService
	Grants LevelConfig milestone rewards when a level is reached. Re-checked
	on join (and idempotent via a granted-milestones set in Achievements
	under "Level:<n>"), so a crash between level-up and reward can't lose it.
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local LevelConfig = require(Shared.Config.LevelConfig)

local ServerRoot = script.Parent.Parent
local Net = require(ServerRoot.Net)
local GameEvents = require(ServerRoot.GameEvents)
local PlayerDataService = require(script.Parent.PlayerDataService)
local RewardService = require(script.Parent.RewardService)

local LevelRewardService = {}

local function grantUpTo(player: Player, level: number)
	local data = PlayerDataService:Get(player)
	if not data then
		return
	end
	for _, milestone in LevelConfig.Milestones do
		local key = "Level:" .. milestone.Level
		if milestone.Level <= level and not data.Achievements[key] then
			data.Achievements[key] = os.time()
			PlayerDataService:Changed(player, "Achievements")
			RewardService:Grant(
				player,
				milestone.Reward :: any,
				{ Source = "Level", SourceId = key, Notify = false, Multipliers = false }
			)
			Net.signal(
				player,
				"Notify",
				{ Kind = "Level", Text = "Level " .. milestone.Level .. ": " .. milestone.Text }
			)
		end
	end
end

function LevelRewardService:Start()
	GameEvents.on("LevelUp", function(player, level)
		grantUpTo(player, level)
	end)
	PlayerDataService.Loaded:Connect(function(player, data)
		grantUpTo(player, data.Progress.Level)
	end)
end

return LevelRewardService
