--!strict
--[[
	StatisticsService
	Lifetime counters (Stats in the save): playtime, distance, jumps, kills...
	Replication of the Stats table is throttled because some counters change
	every frame-ish (distance).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Players = game:GetService("Players")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local MathUtil = require(Shared.Util.MathUtil)
local Signal = require(Shared.Util.Signal)
local GameConfig = require(Shared.Config.GameConfig)

local PlayerDataService = require(script.Parent.PlayerDataService)

local StatisticsService = {}

-- (player, key, newValue)
StatisticsService.Changed = Signal.new() :: Signal.Signal<Player, string, number>

local dirty: { [Player]: boolean } = {}
local lastDistanceSample: { [Player]: Vector3 } = {}

function StatisticsService:Get(player: Player, key: string): number
	local data = PlayerDataService:Get(player)
	if not data then
		return 0
	end
	return (data.Stats :: any)[key] or 0
end

function StatisticsService:Increment(player: Player, key: string, amount: number?)
	local data = PlayerDataService:Get(player)
	local delta = amount or 1
	if not data or not MathUtil.isFinite(delta) or delta <= 0 then
		return
	end
	local stats = data.Stats :: any
	stats[key] = math.min((stats[key] or 0) + delta, GameConfig.MaxCurrency)
	dirty[player] = true
	StatisticsService.Changed:Fire(player, key, stats[key])
end

function StatisticsService:SetMax(player: Player, key: string, value: number)
	local data = PlayerDataService:Get(player)
	if not data or not MathUtil.isFinite(value) then
		return
	end
	local stats = data.Stats :: any
	if value > (stats[key] or 0) then
		stats[key] = value
		dirty[player] = true
		StatisticsService.Changed:Fire(player, key, value)
	end
end

function StatisticsService:Start()
	-- Playtime is accounted at save time so it is exact even on crashes of
	-- the client (server clock based).
	local sessionMark: { [Player]: number } = {}
	PlayerDataService.Loaded:Connect(function(player)
		sessionMark[player] = os.clock()
	end)
	PlayerDataService:AddBeforeSave(function(player, data)
		local mark = sessionMark[player]
		if mark then
			local now = os.clock()
			;(data.Stats :: any).Playtime += now - mark
			sessionMark[player] = now
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		dirty[player] = nil
		lastDistanceSample[player] = nil
		task.delay(30, function()
			sessionMark[player] = nil
		end)
	end)

	-- Distance sampling + throttled replication.
	task.spawn(function()
		while true do
			task.wait(2)
			for _, player in Players:GetPlayers() do
				local character = player.Character
				local root = character and character:FindFirstChild("HumanoidRootPart") :: BasePart?
				if root then
					local pos = root.Position
					local last = lastDistanceSample[player]
					lastDistanceSample[player] = pos
					if last then
						local moved = (Vector3.new(pos.X, 0, pos.Z) - Vector3.new(last.X, 0, last.Z)).Magnitude
						-- Ignore teleports (fast travel, respawns) in the statistic.
						local scale = (player:GetAttribute("Scale") :: number?) or 1
						if moved > 0.01 and moved < 2500 * math.max(scale, 1) then
							StatisticsService:Increment(player, "Distance", moved)
						end
					end
				end
				if dirty[player] then
					dirty[player] = nil
					PlayerDataService:Changed(player, "Stats")
				end
			end
		end
	end)
end

return StatisticsService
