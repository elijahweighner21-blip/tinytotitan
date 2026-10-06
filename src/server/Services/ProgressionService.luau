--!strict
--[[
	ProgressionService
	Mass -> size tier, XP -> level. Tier is always DERIVED from Mass (never
	trusted from save data), so re-tuning thresholds in SizeConfig can never
	leave a player in an inconsistent state.

	  :AddMass(player, amount, source)   (post-multiplier amounts only;
	                                      RewardService is the normal caller)
	  :AddXP(player, amount, source)
	  :SetMass(player, mass, source)     admin / ascension
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Progression = require(Shared.Formulas.Progression)
local SizeConfig = require(Shared.Config.SizeConfig)
local ZoneConfig = require(Shared.Config.ZoneConfig)
local GameConfig = require(Shared.Config.GameConfig)
local MathUtil = require(Shared.Util.MathUtil)
local Signal = require(Shared.Util.Signal)

local ServerRoot = script.Parent.Parent
local Net = require(ServerRoot.Net)
local GameEvents = require(ServerRoot.GameEvents)
local PlayerDataService = require(script.Parent.PlayerDataService)
local CurrencyService = require(script.Parent.CurrencyService)
local StatisticsService = require(script.Parent.StatisticsService)

local ProgressionService = {}

-- (player, newTier, oldTier)
ProgressionService.TierChanged = Signal.new() :: Signal.Signal<Player, number, number>
-- (player, newLevel, levelsGained)
ProgressionService.LevelChanged = Signal.new() :: Signal.Signal<Player, number, number>

function ProgressionService:GetTier(player: Player): number
	local data = PlayerDataService:Get(player)
	return if data then data.Progress.Tier else 1
end

function ProgressionService:GetLevel(player: Player): number
	local data = PlayerDataService:Get(player)
	return if data then data.Progress.Level else 1
end

-- Reward scale of the most advanced zone the player can enter. Used to
-- normalise "earn X Mass" objectives so they stay meaningful at every size.
function ProgressionService:GetZoneScale(player: Player): number
	return ZoneConfig.highestUnlocked(ProgressionService:GetTier(player)).RewardScale
end

local function evaluateTier(player: Player, celebrate: boolean)
	local data = PlayerDataService:Get(player)
	if not data then
		return
	end
	local progress = data.Progress
	local newTier = Progression.tierForMass(data.Currencies.Mass)
	local oldTier = progress.Tier
	player:SetAttribute("NaturalScale", Progression.scaleForMass(data.Currencies.Mass))
	if newTier == oldTier then
		return
	end
	progress.Tier = newTier
	if newTier > progress.HighestTier then
		progress.HighestTier = newTier
	end
	player:SetAttribute("Tier", newTier)
	PlayerDataService:Changed(player, "Progress")
	ProgressionService.TierChanged:Fire(player, newTier, oldTier)
	if newTier > oldTier and celebrate then
		local tier = SizeConfig.getTier(newTier)
		Net.signal(player, "TierUp", { Tier = newTier, OldTier = oldTier, Name = tier.Name, Unlocks = tier.Unlocks })
		GameEvents.fire("TierUp", player, newTier, oldTier)
	end
end

function ProgressionService:AddMass(player: Player, amount: number, source: string): boolean
	if not MathUtil.isFinite(amount) or amount <= 0 then
		return false
	end
	local data = PlayerDataService:Get(player)
	if not data then
		return false
	end
	local headroom = GameConfig.MaxMass - data.Currencies.Mass
	amount = math.min(amount, headroom)
	if amount <= 0 then
		return false
	end
	if not CurrencyService:Add(player, "Mass", amount, source) then
		return false
	end
	data.Progress.RunMass = math.min(data.Progress.RunMass + amount, GameConfig.MaxMass)
	StatisticsService:Increment(player, "TotalMassEarned", amount)
	GameEvents.fire("MassEarned", player, amount, amount / ProgressionService:GetZoneScale(player))
	return true
end

function ProgressionService:SetMass(player: Player, mass: number, source: string)
	CurrencyService:Set(player, "Mass", math.clamp(mass, 0, GameConfig.MaxMass), source)
end

function ProgressionService:AddXP(player: Player, amount: number, _source: string)
	local data = PlayerDataService:Get(player)
	if not data or not MathUtil.isFinite(amount) or amount <= 0 then
		return
	end
	local progress = data.Progress
	local before = progress.Level
	local level, xp, gained = Progression.applyXP(progress.Level, progress.XP, amount)
	progress.Level = level
	progress.XP = xp
	PlayerDataService:Changed(player, "Progress")
	if gained > 0 then
		local points = 0
		for l = before + 1, level do
			points += Progression.skillPointsForLevel(l)
		end
		CurrencyService:Add(player, "SkillPoints", points, "LevelUp")
		player:SetAttribute("Level", level)
		Net.signal(player, "LevelUp", { Level = level, SkillPoints = points })
		ProgressionService.LevelChanged:Fire(player, level, gained)
		for l = before + 1, level do
			GameEvents.fire("LevelUp", player, l)
		end
	end
end

function ProgressionService:Start()
	CurrencyService.Changed:Connect(function(player, currency)
		if currency == "Mass" then
			evaluateTier(player, true)
		end
	end)
	PlayerDataService.Loaded:Connect(function(player, data)
		player:SetAttribute("Level", data.Progress.Level)
		player:SetAttribute("Tier", data.Progress.Tier)
		-- Silent re-derivation on join (handles re-tuned thresholds).
		evaluateTier(player, false)
		StatisticsService:SetMax(player, "HighestScale", Progression.scaleForMass(data.Currencies.Mass))
	end)
	ProgressionService.TierChanged:Connect(function(player)
		local data = PlayerDataService:Get(player)
		if data then
			StatisticsService:SetMax(player, "HighestScale", Progression.scaleForMass(data.Currencies.Mass))
		end
	end)
	Players.PlayerRemoving:Connect(function() end)
end

return ProgressionService
