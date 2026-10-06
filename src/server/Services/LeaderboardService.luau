--!strict
--[[
	LeaderboardService
	Global leaderboards on OrderedDataStores. Values only ever come from the
	server: lifetime stats from the validated save, challenge records from
	ChallengeService's own timing. Writes are throttled per player and use
	UpdateAsync keeping the best value; reads are cached and refreshed on an
	interval so clients never trigger DataStore requests.

	Boards: TotalMass, Level, Ascensions, Bosses, Discoveries and one per
	leaderboard challenge (times stored in milliseconds, ascending).
	Purchases cannot raise any board (Robux rewards never add Mass/XP).
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local ChallengeConfig = require(Shared.Config.ChallengeConfig)
local Guard = require(Shared.Util.Guard)
local Log = require(Shared.Util.Log)

local ServerRoot = script.Parent.Parent
local Net = require(ServerRoot.Net)
local PlayerDataService = require(script.Parent.PlayerDataService)
local ChallengeService = require(script.Parent.ChallengeService)

local LeaderboardService = {}

type Board = { Id: string, Name: string, Ascending: boolean, Store: OrderedDataStore?, Read: ((data: any) -> number)? }
type Row = { Rank: number, UserId: number, Name: string, Value: number }

local boards: { [string]: Board } = {}
local cache: { [string]: { Rows: { Row }, UpdatedAt: number } } = {}
local names: { [number]: string } = {}
local lastSubmit: { [Player]: number } = {}
local enabled = true

local function store(name: string): OrderedDataStore?
	local ok, result = pcall(function()
		return DataStoreService:GetOrderedDataStore("TT_LB_" .. name)
	end)
	return if ok then result else nil
end

local function addBoard(id: string, label: string, ascending: boolean, read: ((data: any) -> number)?)
	boards[id] = { Id = id, Name = label, Ascending = ascending, Store = store(id), Read = read }
end

local function nameFor(userId: number): string
	local cached = names[userId]
	if cached then
		return cached
	end
	local ok, result = pcall(function()
		return Players:GetNameFromUserIdAsync(userId)
	end)
	local name = if ok then result else ("Player " .. userId)
	names[userId] = name
	return name
end

local function write(board: Board, userId: number, value: number)
	local s = board.Store
	if not s or not enabled then
		return
	end
	local intValue = math.floor(math.clamp(value, 0, 2 ^ 52))
	pcall(function()
		s:UpdateAsync(tostring(userId), function(old: any): any
			if type(old) == "number" then
				if board.Ascending and old > 0 and old <= intValue then
					return nil
				elseif not board.Ascending and old >= intValue then
					return nil
				end
			end
			return intValue
		end)
	end)
end

local function submitStats(player: Player)
	local data = PlayerDataService:Get(player)
	if not data then
		return
	end
	lastSubmit[player] = os.clock()
	for _, board in boards do
		if board.Read then
			local value = board.Read(data)
			if value > 0 then
				write(board, player.UserId, value)
			end
		end
	end
end

local function refresh(board: Board)
	local s = board.Store
	if not s or not enabled then
		return
	end
	local ok, pages = pcall(function()
		return s:GetSortedAsync(board.Ascending, GameConfig.LeaderboardSize, if board.Ascending then 1 else nil)
	end)
	if not ok or not pages then
		return
	end
	local rows: { Row } = {}
	local okPage, page = pcall(function()
		return (pages :: DataStorePages):GetCurrentPage()
	end)
	if okPage then
		for rank, entry in page do
			local userId = tonumber(entry.key) or 0
			table.insert(rows, { Rank = rank, UserId = userId, Name = nameFor(userId), Value = entry.value })
		end
	end
	cache[board.Id] = { Rows = rows, UpdatedAt = os.time() }
end

function LeaderboardService:Init()
	addBoard("TotalMass", "Largest Mass", false, function(d)
		return d.Stats.TotalMassEarned
	end)
	addBoard("Level", "Highest Level", false, function(d)
		return d.Progress.Level
	end)
	addBoard("Ascensions", "Most Ascensions", false, function(d)
		return d.Ascension.Count
	end)
	addBoard("Bosses", "Boss Completions", false, function(d)
		return d.Stats.BossesDefeated
	end)
	addBoard("Discoveries", "Discoveries", false, function(d)
		local n = 0
		for _ in d.Discoveries do
			n += 1
		end
		return n
	end)
	for _, def in ChallengeConfig.List do
		if def.Leaderboard then
			addBoard("Challenge_" .. def.Id, def.Name, def.LowerIsBetter, nil)
		end
	end
	ChallengeService.SubmitRecord = function(player, challengeId, score)
		local board = boards["Challenge_" .. challengeId]
		if board then
			-- Times in ms (ascending); scores ×100 (descending).
			write(board, player.UserId, if board.Ascending then score * 1000 else score * 100)
		end
	end
	Net.onRequest("GetLeaderboard", Guard.shape({ Board = Guard.id(64) }), function(_player, payload)
		local board = boards[payload.Board]
		if not board then
			return { ok = false, err = "Unknown board" }
		end
		local entry = cache[board.Id]
		return {
			ok = true,
			Board = board.Id,
			Name = board.Name,
			Ascending = board.Ascending,
			Rows = if entry then entry.Rows else {},
			UpdatedAt = if entry then entry.UpdatedAt else 0,
			Boards = (function()
				local list = {}
				for id, b in boards do
					table.insert(list, { Id = id, Name = b.Name })
				end
				table.sort(list, function(a, b)
					return a.Id < b.Id
				end)
				return list
			end)(),
		}
	end)
end

function LeaderboardService:Start()
	if RunService:IsStudio() and PlayerDataService:IsUsingMock() then
		enabled = false
		Log.info("Leaderboard", "disabled in Studio without DataStore access")
		return
	end
	Players.PlayerRemoving:Connect(function(player)
		submitStats(player)
		lastSubmit[player] = nil
	end)
	task.spawn(function()
		while true do
			for _, player in Players:GetPlayers() do
				if os.clock() - (lastSubmit[player] or 0) >= GameConfig.LeaderboardSubmitInterval then
					submitStats(player)
				end
			end
			task.wait(30)
		end
	end)
	task.spawn(function()
		while true do
			for _, board in boards do
				refresh(board)
				task.wait(2) -- spread reads to respect request budgets
			end
			task.wait(GameConfig.LeaderboardRefreshInterval)
		end
	end)
end

return LeaderboardService
