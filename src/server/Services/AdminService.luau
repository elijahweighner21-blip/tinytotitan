--!strict
--[[
	AdminService
	Developer tools. Authorisation is decided ONLY on the server, per request:
	the UserId must be in GameConfig.Admins, hold the configured group rank,
	or be the owner of a Studio test session (when StudioIsAdmin). The client
	admin panel is merely a convenience; unauthorised requests are rejected
	and logged. Purchase simulation is additionally restricted to Studio.

	Commands: SetMass, AddMass, SetTier, SetLevel, GiveCurrency, GiveResource,
	GiveBoost, Teleport, ResetData, UnlockSkill, StartEvent, StopEvent,
	SpawnBoss, PrintData, Debug, SetPass, TestPurchase, Heal, Stats.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local HttpService = game:GetService("HttpService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local GameConfig = require(Shared.Config.GameConfig)
local SizeConfig = require(Shared.Config.SizeConfig)
local SkillConfig = require(Shared.Config.SkillConfig)
local ZoneConfig = require(Shared.Config.ZoneConfig)
local DataSchema = require(Shared.Data.DataSchema)
local MathUtil = require(Shared.Util.MathUtil)
local Log = require(Shared.Util.Log)
local Guard = require(Shared.Util.Guard)

local ServerRoot = script.Parent.Parent
local Net = require(ServerRoot.Net)
local PlayerDataService = require(script.Parent.PlayerDataService)
local CurrencyService = require(script.Parent.CurrencyService)
local ProgressionService = require(script.Parent.ProgressionService)
local CharacterService = require(script.Parent.CharacterService)
local BoostService = require(script.Parent.BoostService)
local StatService = require(script.Parent.StatService)
local EntitlementService = require(script.Parent.EntitlementService)
local WorldEventService = require(script.Parent.WorldEventService)
local BossService = require(script.Parent.BossService)
local AnalyticsService = require(script.Parent.AnalyticsService)
local AntiExploitService = require(script.Parent.AntiExploitService)
local EnemyService = require(script.Parent.EnemyService)

local AdminService = {}

local admins: { [Player]: boolean } = {}

-- Hook installed by MonetizationService (Studio-only fake receipts).
AdminService.TestPurchase = nil :: ((player: Player, productKey: string) -> (boolean, string?))?

local function checkAdmin(player: Player): boolean
	if table.find(GameConfig.Admins, player.UserId) then
		return true
	end
	if GameConfig.StudioIsAdmin and RunService:IsStudio() then
		return true
	end
	local group = GameConfig.AdminGroup
	if group then
		local ok, groups = pcall(function()
			return game:GetService("GroupService"):GetGroupsAsync(player.UserId)
		end)
		if ok and type(groups) == "table" then
			for _, entry in groups do
				if type(entry) == "table" and entry.Id == group.GroupId and (tonumber(entry.Rank) or 0) >= group.MinRank then
					return true
				end
			end
		end
	end
	return false
end

function AdminService:IsAdmin(player: Player): boolean
	return admins[player] == true
end

local function num(v: any, default: number): number
	return if MathUtil.isFinite(v) then v else default
end

type Command = (caller: Player, target: Player, args: { [string]: any }) -> { [string]: any }

local commands: { [string]: Command } = {}

commands.SetMass = function(_, target, args)
	ProgressionService:SetMass(target, num(args.Value, 0), "Admin")
	return { ok = true }
end

commands.AddMass = function(_, target, args)
	ProgressionService:AddMass(target, math.max(0, num(args.Value, 0)), "Admin")
	return { ok = true }
end

commands.SetTier = function(_, target, args)
	local tier = SizeConfig.getTier(math.floor(num(args.Value, 1)))
	ProgressionService:SetMass(target, tier.MassRequired, "Admin")
	return { ok = true, tier = tier.Name }
end

commands.SetLevel = function(_, target, args)
	local data = PlayerDataService:Get(target)
	if not data then
		return { ok = false }
	end
	data.Progress.Level = math.clamp(math.floor(num(args.Value, 1)), 1, GameConfig.MaxLevel)
	data.Progress.XP = 0
	target:SetAttribute("Level", data.Progress.Level)
	PlayerDataService:Changed(target, "Progress")
	return { ok = true }
end

commands.GiveCurrency = function(_, target, args)
	local currency = tostring(args.Currency)
	local amount = num(args.Value, 0)
	if not CurrencyService:IsCurrency(currency) or currency == "Mass" then
		return { ok = false, err = "Use SetMass for Mass" }
	end
	if amount >= 0 then
		CurrencyService:Add(target, currency, amount, "Admin")
	else
		CurrencyService:Remove(target, currency, -amount, "Admin")
	end
	return { ok = true }
end

commands.GiveResource = function(_, target, args)
	local resource = tostring(args.Resource)
	if not CurrencyService:IsResource(resource) then
		return { ok = false, err = "Unknown resource" }
	end
	CurrencyService:AddResource(target, resource, math.max(1, num(args.Value, 10)), "Admin")
	return { ok = true }
end

commands.GiveBoost = function(_, target, args)
	return { ok = BoostService:Add(target, tostring(args.Boost), math.max(1, num(args.Value, 600))) }
end

commands.Teleport = function(_, target, args)
	local zone = ZoneConfig.get(tostring(args.Zone))
	if not zone then
		return { ok = false, err = "Unknown zone" }
	end
	pcall(function()
		target:RequestStreamAroundAsync(zone.Spawn, 5)
	end)
	return { ok = CharacterService:SafeTeleport(target, zone.Spawn, "Admin") }
end

commands.ResetData = function(_, target)
	PlayerDataService:ResetData(target)
	StatService:Invalidate(target)
	ProgressionService:SetMass(target, 0, "Admin")
	return { ok = true }
end

commands.UnlockSkill = function(_, target, args)
	local data = PlayerDataService:Get(target)
	if not data then
		return { ok = false }
	end
	local id = tostring(args.Id)
	if id == "All" then
		for _, s in SkillConfig.List do
			data.Skills[s.Id] = true
		end
	elseif SkillConfig.get(id) then
		data.Skills[id] = true
	else
		return { ok = false, err = "Unknown skill" }
	end
	PlayerDataService:Changed(target, "Skills")
	StatService:Invalidate(target)
	return { ok = true }
end

commands.StartEvent = function(_, _target, args)
	return { ok = WorldEventService:StartEvent(tostring(args.Id)) }
end

commands.SpawnBoss = function(_, _target, args)
	return { ok = BossService:ForceSpawn(tostring(args.Id)) }
end

commands.PrintData = function(_, target)
	local data = PlayerDataService:Get(target)
	if not data then
		return { ok = false }
	end
	local view = DataSchema.clientView(data :: any)
	local ok, json = pcall(function()
		return HttpService:JSONEncode(view)
	end)
	print("[Admin] data for", target.Name, if ok then json else "(unencodable)")
	return { ok = true, size = if ok then #json else 0 }
end

commands.Debug = function(_, target, args)
	target:SetAttribute("DebugMode", args.Value == true)
	return { ok = true }
end

commands.SetPass = function(_, target, args)
	return { ok = EntitlementService:SetTestOwnership(target, tostring(args.Key), args.Value == true), err = if RunService:IsStudio() then nil else "Studio only" }
end

commands.TestPurchase = function(_, target, args)
	local hook = AdminService.TestPurchase
	if not hook then
		return { ok = false, err = "Unavailable" }
	end
	local ok, err = hook(target, tostring(args.Product))
	return { ok = ok, err = err }
end

commands.Heal = function(_, target)
	local humanoid = target.Character and target.Character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		humanoid.Health = humanoid.MaxHealth
	end
	return { ok = true }
end

commands.Stats = function(_, target)
	return {
		ok = true,
		enemies = EnemyService:Count(),
		event = WorldEventService:GetActive(),
		suspicion = AntiExploitService:GetScore(target),
		analytics = AnalyticsService:Snapshot(),
		mockData = PlayerDataService:IsUsingMock(),
	}
end

function AdminService:Init()
	Net.onRequest(
		"Admin",
		Guard.shape({
			Cmd = Guard.id(24),
			Target = Guard.optional(Guard.integer(1, 1e12)),
			Args = Guard.optional(function(v)
				if type(v) ~= "table" then
					return false, "args must be a table"
				end
				local n = 0
				for k, x in v do
					n += 1
					if n > 8 or type(k) ~= "string" or (type(x) ~= "string" and type(x) ~= "number" and type(x) ~= "boolean") then
						return false, "bad args"
					end
					if type(x) == "string" and #x > 64 then
						return false, "arg too long"
					end
				end
				return true
			end),
		}),
		function(player, payload)
			if not admins[player] then
				Log.warn("Admin", "UNAUTHORISED admin attempt by", player.UserId, payload.Cmd)
				AntiExploitService:Flag(player, "unauthorised admin request", 3)
				return { ok = false, err = "Not authorised" }
			end
			local command = commands[payload.Cmd]
			if not command then
				return { ok = false, err = "Unknown command" }
			end
			local target = if payload.Target then Players:GetPlayerByUserId(payload.Target) else player
			if not target then
				return { ok = false, err = "Target not in server" }
			end
			Log.info("Admin", player.Name, "->", payload.Cmd, "on", target.Name)
			local ok, result = pcall(command, player, target, payload.Args or {})
			if not ok then
				return { ok = false, err = tostring(result) }
			end
			return result
		end
	)
end

function AdminService:Start()
	local function onPlayer(player: Player)
		local isAdmin = checkAdmin(player)
		admins[player] = isAdmin
		player:SetAttribute("IsAdmin", isAdmin)
	end
	Players.PlayerAdded:Connect(onPlayer)
	for _, player in Players:GetPlayers() do
		task.spawn(onPlayer, player)
	end
	Players.PlayerRemoving:Connect(function(player)
		admins[player] = nil
	end)
end

return AdminService
