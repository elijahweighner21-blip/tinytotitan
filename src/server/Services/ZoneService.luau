--!strict
--[[
	ZoneService
	Tracks which region each player is in (by FEET position, so giants still
	count as being in the room they stand in) and enforces zone requirements.

	Gates in the world block physically, but exploiters can bypass physics, so
	the server also checks: a player inside a zone they have not unlocked for
	longer than ZoneConfig.TrespassGraceSeconds is returned to safety with a
	clear "Requires: Toy-Sized" message. Lag at a boundary never triggers it.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ZoneConfig = require(Shared.Config.ZoneConfig)
local SizeConfig = require(Shared.Config.SizeConfig)
local ScaleMath = require(Shared.Formulas.ScaleMath)
local Signal = require(Shared.Util.Signal)

local ServerRoot = script.Parent.Parent
local Net = require(ServerRoot.Net)
local GameEvents = require(ServerRoot.GameEvents)
local PlayerDataService = require(script.Parent.PlayerDataService)
local ProgressionService = require(script.Parent.ProgressionService)
local CharacterService = require(script.Parent.CharacterService)
local ScaleService = require(script.Parent.ScaleService)

local ZoneService = {}

-- (player, newZoneId, oldZoneId?)
ZoneService.ZoneChanged = Signal.new() :: Signal.Signal<Player, string, string?>

type State = { zone: string?, trespassSince: number? }
local states: { [Player]: State } = {}

function ZoneService:GetZone(player: Player): string?
	local s = states[player]
	return s and s.zone
end

function ZoneService:FeetPosition(player: Player): Vector3?
	local root = CharacterService:GetRoot(player)
	if not root then
		return nil
	end
	local scale = ScaleService:GetScale(player)
	return root.Position - Vector3.new(0, ScaleMath.height(scale) * 0.5, 0)
end

function ZoneService:CanEnter(player: Player, zoneId: string): boolean
	local zone = ZoneConfig.get(zoneId)
	return zone ~= nil and ProgressionService:GetTier(player) >= zone.RequiredTier
end

local function update(player: Player)
	local feet = ZoneService:FeetPosition(player)
	if not feet then
		return
	end
	local s = states[player]
	if not s then
		s = {}
		states[player] = s
	end
	local zone = ZoneConfig.zoneAt(feet)
	if not zone then
		return
	end
	if zone.Id ~= s.zone then
		local old = s.zone
		s.zone = zone.Id
		player:SetAttribute("Zone", zone.Id)
		ZoneService.ZoneChanged:Fire(player, zone.Id, old)
		GameEvents.fire("ZoneEntered", player, zone.Id)
		local data = PlayerDataService:Get(player)
		if data and zone.Id == "FloorWorld" and data.Progress.HighestTier >= SizeConfig.TitanTier then
			GameEvents.fire("TitanHomecoming", player)
		end
	end
	if ProgressionService:GetTier(player) < zone.RequiredTier then
		local now = os.clock()
		if not s.trespassSince then
			s.trespassSince = now
		elseif now - s.trespassSince > ZoneConfig.TrespassGraceSeconds then
			s.trespassSince = nil
			CharacterService:Rescue(player, "ZoneLocked")
			Net.signal(player, "Gate", {
				Zone = zone.Name,
				Requires = SizeConfig.getTier(zone.RequiredTier).Name,
			})
		end
	else
		s.trespassSince = nil
	end
end

function ZoneService:Start()
	Players.PlayerRemoving:Connect(function(player)
		states[player] = nil
	end)
	task.spawn(function()
		while true do
			task.wait(0.5)
			for _, player in Players:GetPlayers() do
				update(player)
			end
		end
	end)
end

return ZoneService
