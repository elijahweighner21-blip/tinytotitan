--!strict
--[[
	BoostService
	Timed boosts (2× Mass, 2× Growth Energy, 2× XP, 2× Luck).

	Clock: ACTIVE PLAYTIME. Remaining seconds are stored in the save and only
	tick down while the player is in a server, so a purchased hour is always a
	full hour of play. Because the remaining time lives in the same record as
	everything else, reconnecting, teleporting or a server crash can neither
	duplicate nor erase a boost. Buying more of the same boost EXTENDS it (up
	to MaxStackSeconds); it never multiplies further.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MonetizationConfig = require(Shared.Config.MonetizationConfig)
local RewardConfig = require(Shared.Config.RewardConfig)
local MathUtil = require(Shared.Util.MathUtil)
local Signal = require(Shared.Util.Signal)
local RewardMath = require(Shared.Formulas.RewardMath)

local PlayerDataService = require(script.Parent.PlayerDataService)

local BoostService = {}

-- (player, boostId, remainingSeconds)
BoostService.Changed = Signal.new() :: Signal.Signal<Player, string, number>

function BoostService:Add(player: Player, boostId: string, seconds: number): boolean
	local def = MonetizationConfig.Boosts[boostId]
	local data = PlayerDataService:Get(player)
	if not def or not data or not MathUtil.isFinite(seconds) or seconds <= 0 then
		return false
	end
	local boosts = data.Boosts :: { [string]: number }
	local remaining = math.min((boosts[boostId] or 0) + seconds, def.MaxStackSeconds)
	boosts[boostId] = remaining
	PlayerDataService:Changed(player, "Boosts")
	BoostService.Changed:Fire(player, boostId, remaining)
	return true
end

function BoostService:Remaining(player: Player, boostId: string): number
	local data = PlayerDataService:Get(player)
	if not data then
		return 0
	end
	return (data.Boosts :: { [string]: number })[boostId] or 0
end

function BoostService:IsActive(player: Player, boostId: string): boolean
	return BoostService:Remaining(player, boostId) > 0
end

-- Currency multipliers for the reward pipeline.
function BoostService:GetModifiers(player: Player): { RewardMath.Modifier }
	local mods: { RewardMath.Modifier } = {}
	local data = PlayerDataService:Get(player)
	if not data then
		return mods
	end
	for id, remaining in data.Boosts :: { [string]: number } do
		local def = MonetizationConfig.Boosts[id]
		if def and remaining > 0 and def.Kind == "Currency" then
			table.insert(mods, {
				Source = "Boost:" .. id,
				Currency = def.Target,
				Kind = "Multiplicative",
				Value = def.Multiplier,
				Group = RewardConfig.Groups.Boost,
			})
		end
	end
	return mods
end

-- Multiplier for stat boosts (Luck).
function BoostService:GetStatMultiplier(player: Player, stat: string): number
	local data = PlayerDataService:Get(player)
	if not data then
		return 1
	end
	local best = 1
	for id, remaining in data.Boosts :: { [string]: number } do
		local def = MonetizationConfig.Boosts[id]
		if def and remaining > 0 and def.Kind == "Stat" and def.Target == stat then
			best = math.max(best, def.Multiplier)
		end
	end
	return best
end

function BoostService:Start()
	-- One loop for all players; decrements by real elapsed time.
	local last = os.clock()
	local replicateTimer = 0
	task.spawn(function()
		while true do
			task.wait(1)
			local now = os.clock()
			local elapsed = math.min(now - last, 5) -- never drain huge chunks after a stall
			last = now
			replicateTimer += elapsed
			local replicate = replicateTimer >= 15
			if replicate then
				replicateTimer = 0
			end
			for _, player in Players:GetPlayers() do
				local data = PlayerDataService:Get(player)
				if data then
					local boosts = data.Boosts :: { [string]: number }
					local changed = false
					for id, remaining in boosts do
						local left = remaining - elapsed
						if left <= 0 then
							boosts[id] = nil
							changed = true
							BoostService.Changed:Fire(player, id, 0)
						else
							boosts[id] = left
						end
					end
					-- Clients count down locally; periodic sync corrects drift.
					if changed or (replicate and next(boosts) ~= nil) then
						PlayerDataService:Changed(player, "Boosts")
					end
				end
			end
		end
	end)
end

return BoostService
