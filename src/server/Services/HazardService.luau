--!strict
--[[
	HazardService
	Environmental hazards (water droplets, traffic, storm strikes). Damage is
	RELATIVE to size: a droplet is deadly to an ant and harmless to a child,
	so hazards automatically fade into scenery as the player grows.
]]

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ScaleMath = require(Shared.Formulas.ScaleMath)

local ServerRoot = script.Parent.Parent
local Net = require(ServerRoot.Net)
local CombatService = require(script.Parent.CombatService)
local ScaleService = require(script.Parent.ScaleService)

local HazardService = {}

local lastHit: { [Player]: { [Instance]: number } } = {}
local connections: { [Instance]: RBXScriptConnection } = {}

local COOLDOWN = 1

function HazardService:DamageFromHazard(
	player: Player,
	hazardSize: number,
	baseDamage: number,
	name: string,
	position: Vector3?
)
	local height = ScaleMath.height(ScaleService:GetScale(player))
	local ratio = hazardSize / height
	if ratio < 0.15 then
		return -- far too small to matter
	end
	local damage = baseDamage * math.clamp(ratio ^ 0.8, 0, 1.5)
	if CombatService:DamagePlayer(player, damage, name) and position then
		Net.fxTo(player, "Splash", { P = position })
	end
end

local function hook(part: Instance)
	if not part:IsA("BasePart") or connections[part] then
		return
	end
	part.CanTouch = true
	connections[part] = part.Touched:Connect(function(hit)
		local character = hit.Parent
		local player = character and Players:GetPlayerFromCharacter(character)
		if not player then
			return
		end
		local now = os.clock()
		local hits = lastHit[player]
		if not hits then
			hits = {}
			lastHit[player] = hits
		end
		if (hits[part] or 0) > now then
			return
		end
		hits[part] = now + COOLDOWN
		local damage = (part:GetAttribute("Damage") :: number?) or 10
		HazardService:DamageFromHazard(player, part.Size.Magnitude * 0.6, damage, part.Name, part.Position)
	end)
end

local function unhook(part: Instance)
	local conn = connections[part]
	if conn then
		conn:Disconnect()
		connections[part] = nil
	end
end

function HazardService:Start()
	for _, part in CollectionService:GetTagged("Hazard") do
		hook(part)
	end
	CollectionService:GetInstanceAddedSignal("Hazard"):Connect(hook)
	CollectionService:GetInstanceRemovedSignal("Hazard"):Connect(unhook)
	Players.PlayerRemoving:Connect(function(player)
		lastHit[player] = nil
	end)
end

return HazardService
