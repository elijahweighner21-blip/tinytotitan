--!strict
--[[
	FastTravelService
	Stations (tag "FastTravelStation", attribute StationId = zone id) unlock
	when the player physically reaches them; unlocks are permanent (saved).
	Travel is validated server-side: unlocked station, zone requirement met,
	player alive, not in a blocking activity (challenge run, boss fight —
	registered by those services through :AddBlocker), feature unlocked by
	size, and per-player cooldown measured on the server clock.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ZoneConfig = require(Shared.Config.ZoneConfig)
local SizeConfig = require(Shared.Config.SizeConfig)
local ScaleMath = require(Shared.Formulas.ScaleMath)
local Guard = require(Shared.Util.Guard)

local ServerRoot = script.Parent.Parent
local Net = require(ServerRoot.Net)
local GameEvents = require(ServerRoot.GameEvents)
local PlayerDataService = require(script.Parent.PlayerDataService)
local ProgressionService = require(script.Parent.ProgressionService)
local CharacterService = require(script.Parent.CharacterService)
local StatService = require(script.Parent.StatService)
local ScaleService = require(script.Parent.ScaleService)

local FastTravelService = {}

local FEATURE_TIER = 4 -- stations work from Bug-Sized; Fast Travel menu text says Child for long hops
local BASE_COOLDOWN = 30

type Station = { Id: string, Position: Vector3, Radius: number }
local stations: { [string]: Station } = {}
local lastTravel: { [Player]: number } = {}
local blockers: { (player: Player) -> string? } = {}

function FastTravelService:AddBlocker(fn: (player: Player) -> string?)
	table.insert(blockers, fn)
end

function FastTravelService:GetStations(): { [string]: Station }
	return stations
end

local function unlock(player: Player, stationId: string)
	local data = PlayerDataService:Get(player)
	if not data or data.FastTravel[stationId] then
		return
	end
	data.FastTravel[stationId] = true
	PlayerDataService:Changed(player, "FastTravel")
	local zone = ZoneConfig.get(stationId)
	Net.signal(player, "Notify", { Text = "Fast travel unlocked: " .. (if zone then zone.Name else stationId), Kind = "Success" })
end

local function register(part: Instance)
	if not part:IsA("BasePart") then
		return
	end
	local id = part:GetAttribute("StationId")
	if type(id) ~= "string" then
		return
	end
	stations[id] = { Id = id, Position = part.Position, Radius = math.max(part.Size.X, part.Size.Z) * 0.5 + 6 }
end

function FastTravelService:Init()
	for _, part in CollectionService:GetTagged("FastTravelStation") do
		register(part)
	end
	CollectionService:GetInstanceAddedSignal("FastTravelStation"):Connect(register)

	Net.onRequest("FastTravel", Guard.shape({ Station = Guard.id() }), function(player, payload)
		local data = PlayerDataService:Get(player)
		local station = stations[payload.Station]
		local zone = ZoneConfig.get(payload.Station)
		if not data or not station or not zone then
			return { ok = false, err = "Unknown station" }
		end
		if not data.FastTravel[station.Id] then
			return { ok = false, err = "Visit this station first" }
		end
		local tier = ProgressionService:GetTier(player)
		if tier < FEATURE_TIER then
			return { ok = false, err = "Fast travel unlocks at " .. SizeConfig.getTier(FEATURE_TIER).Name }
		end
		if tier < zone.RequiredTier then
			return { ok = false, err = "Requires " .. SizeConfig.getTier(zone.RequiredTier).Name }
		end
		if not CharacterService:IsAlive(player) then
			return { ok = false, err = "You can't travel right now" }
		end
		for _, blocker in blockers do
			local reason = blocker(player)
			if reason then
				return { ok = false, err = reason }
			end
		end
		local cooldown = BASE_COOLDOWN * (1 - StatService:Get(player, "TravelCooldownReduction"))
		local now = os.clock()
		local last = lastTravel[player]
		if last and now - last < cooldown then
			return { ok = false, err = string.format("Fast travel ready in %ds", math.ceil(cooldown - (now - last))) }
		end
		lastTravel[player] = now
		CharacterService:SafeTeleport(player, station.Position + Vector3.new(0, 1, 0), "FastTravel")
		CharacterService:SetRespawnPoint(player, station.Position, station.Id)
		GameEvents.fire("FastTraveled", player, station.Id)
		return { ok = true, cooldown = cooldown }
	end)
end

function FastTravelService:Start()
	Players.PlayerRemoving:Connect(function(player)
		lastTravel[player] = nil
	end)
	-- Proximity unlock: cheap distance checks against a handful of stations.
	task.spawn(function()
		while true do
			task.wait(1)
			for _, player in Players:GetPlayers() do
				local root = CharacterService:GetRoot(player)
				local data = PlayerDataService:Get(player)
				if root and data then
					local reach = ScaleMath.height(ScaleService:GetScale(player))
					for id, station in stations do
						if not data.FastTravel[id] and (root.Position - station.Position).Magnitude <= station.Radius + reach then
							unlock(player, id)
							CharacterService:SetRespawnPoint(player, station.Position, id)
						end
					end
				end
			end
		end
	end)
end

return FastTravelService
