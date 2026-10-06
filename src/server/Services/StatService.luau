--!strict
--[[
	StatService
	Cached aggregate of every stat bonus (upgrades, skills, ascension tree,
	stat boosts) plus the derived physical numbers for the player's CURRENT
	scale. Services call :Invalidate(player) after changing anything that feeds
	stats; the cache rebuilds lazily.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Stats = require(Shared.Formulas.Stats)
local Signal = require(Shared.Util.Signal)

local PlayerDataService = require(script.Parent.PlayerDataService)
local BoostService = require(script.Parent.BoostService)

local StatService = {}

StatService.Invalidated = Signal.new() :: Signal.Signal<Player>

local cache: { [Player]: Stats.StatTable } = {}

function StatService:GetStats(player: Player): Stats.StatTable
	local cached = cache[player]
	if cached then
		return cached
	end
	local data = PlayerDataService:Get(player)
	if not data then
		return Stats.empty()
	end
	local stats = Stats.compute({
		Upgrades = data.Upgrades,
		Skills = data.Skills,
		AscensionTree = data.Ascension.Tree,
	})
	-- Stat boosts (e.g. 2× Luck) double the luck-type stats, with a floor so a
	-- player without luck upgrades still benefits.
	local luckMult = BoostService:GetStatMultiplier(player, "Luck")
	if luckMult > 1 then
		stats.Luck = math.max(stats.Luck * luckMult, 0.25 * (luckMult - 1))
		stats.GoldenOrbChance = math.min(stats.GoldenOrbChance * luckMult + 0.04 * (luckMult - 1), 0.6)
	end
	cache[player] = stats
	return stats
end

function StatService:Get(player: Player, key: string): number
	return StatService:GetStats(player)[key] or 0
end

function StatService:GetScale(player: Player): number
	return (player:GetAttribute("Scale") :: number?) or 0.2
end

function StatService:GetDerived(player: Player): Stats.Derived
	return Stats.derive(StatService:GetStats(player), StatService:GetScale(player))
end

function StatService:Invalidate(player: Player)
	cache[player] = nil
	StatService.Invalidated:Fire(player)
end

function StatService:Start()
	Players.PlayerRemoving:Connect(function(player)
		cache[player] = nil
	end)
	BoostService.Changed:Connect(function(player, boostId)
		if boostId == "Luck2x" then
			StatService:Invalidate(player)
		end
	end)
	PlayerDataService.Loaded:Connect(function(player)
		StatService:Invalidate(player)
	end)
end

return StatService
