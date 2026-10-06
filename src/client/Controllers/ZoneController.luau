--!strict
--[[
	ZoneController
	Knows which zone the local player is in (by FEET position, matching the
	server) and drives everything zone-flavoured on the client: ambience and
	music, lighting preset, the zone banner, and size gates.

	Size gates are real collidable barriers. Once the player's tier meets a
	gate's RequiredTier, the gate is made non-collidable LOCALLY (the server
	still enforces zone access through ZoneService, so a cheater who removes
	gates gains nothing but a trip back to safety).
]]

local CollectionService = game:GetService("CollectionService")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ZoneConfig = require(Shared.Config.ZoneConfig)
local SizeConfig = require(Shared.Config.SizeConfig)
local Signal = require(Shared.Util.Signal)

local Client = script.Parent.Parent
local Net = require(Client.Net)
local Bus = require(Client.UI.Bus)
local Probe = require(Client.Movement.Probe)
local MovementController = require(script.Parent.MovementController)
local DataController = require(script.Parent.DataController)
local AudioController = require(script.Parent.AudioController)

local ZoneController = {}

-- (newZoneId, oldZoneId?)
ZoneController.ZoneChanged = Signal.new() :: Signal.Signal<string, string?>

local currentZone: string? = nil
local gateTier = -1
local lastCheck = 0

function ZoneController:GetZone(): string?
	return currentZone
end

local function applyGate(gate: Instance, tier: number)
	if not gate:IsA("BasePart") then
		return
	end
	local required = (gate:GetAttribute("RequiredTier") :: number?) or 1
	local open = tier >= required
	gate.CanCollide = not open
	gate.LocalTransparencyModifier = if open then 0.7 else 0
end

local function refreshGates()
	local tier = DataController:GetTier()
	gateTier = tier
	for _, gate in CollectionService:GetTagged("Gate") do
		applyGate(gate, tier)
	end
	Probe.refresh()
end

-- Is the player allowed in this zone at their current tier?
function ZoneController:CanEnter(zoneId: string): boolean
	local zone = ZoneConfig.get(zoneId)
	return zone ~= nil and DataController:GetTier() >= zone.RequiredTier
end

local function update()
	local root = MovementController:GetRoot()
	if not root then
		return
	end
	local feet = root.Position - Vector3.new(0, MovementController:GetHeight() * 0.5, 0)
	local zone = ZoneConfig.zoneAt(feet)
	if zone and zone.Id ~= currentZone then
		local old = currentZone
		currentZone = zone.Id
		AudioController:SetZone(zone.Id)
		ZoneController.ZoneChanged:Fire(zone.Id, old)
	end
end

function ZoneController:Init()
	Net.onSignal("Gate", function(payload)
		if type(payload) == "table" then
			Bus.toast(
				string.format(
					"%s needs %s size — keep growing! You were moved back to safety.",
					tostring(payload.Zone),
					tostring(payload.Requires)
				),
				"Warning"
			)
		end
	end)
	CollectionService:GetInstanceAddedSignal("Gate"):Connect(function(gate)
		applyGate(gate, DataController:GetTier())
		Probe.refresh()
	end)
	DataController.Changed:Connect(function(key)
		if key == "Progress" and DataController:GetTier() ~= gateTier then
			refreshGates()
		end
	end)
	DataController.Loaded:Connect(refreshGates)
end

function ZoneController:Start()
	if DataController:IsLoaded() then
		refreshGates()
	end
	RunService.Heartbeat:Connect(function()
		local now = os.clock()
		if now - lastCheck >= 0.25 then
			lastCheck = now
			update()
		end
	end)
end

-- Describes the tier needed for a zone (for map tooltips).
function ZoneController:RequirementText(zoneId: string): string
	local zone = ZoneConfig.get(zoneId)
	if not zone then
		return ""
	end
	return "Requires " .. SizeConfig.getTier(zone.RequiredTier).Name
end

return ZoneController
